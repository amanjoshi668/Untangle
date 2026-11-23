const express = require('express');
const cors = require('cors');
const crypto = require('crypto');
const fs = require('fs');
const path = require('path');
const https = require('https');
const jwt = require('jsonwebtoken');
const { Pool } = require('pg');
const { OAuth2Client } = require('google-auth-library');

const app = express();
app.use(cors());
app.use(express.json({ limit: '2mb' }));

const PORT = process.env.PORT || 8080;
const JWT_SECRET = process.env.JWT_SECRET || 'untangle-dev-local-secret-change-in-prod';
const GOOGLE_CLIENT_ID = process.env.GOOGLE_CLIENT_ID || '';
const GEMINI_API_KEY = process.env.GEMINI_API_KEY || '';
const googleClient = GOOGLE_CLIENT_ID ? new OAuth2Client(GOOGLE_CLIENT_ID) : null;

// Database configuration (Cloud SQL Unix socket or DATABASE_URL, with zero-DB in-memory fallback)
let pool = null;
if (process.env.DATABASE_URL) {
  pool = new Pool({ connectionString: process.env.DATABASE_URL });
} else if (process.env.INSTANCE_CONNECTION_NAME && process.env.DB_USER && process.env.DB_NAME) {
  pool = new Pool({
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    host: `/cloudsql/${process.env.INSTANCE_CONNECTION_NAME}`,
  });
}

// In-memory fallback stores so server boots cleanly anywhere without a DB
const memUsers = new Map();       // email -> user
const memUsersById = new Map();   // id -> user
const memSnapshots = new Map();   // userId -> snapshot
const memDecisions = new Map();   // userId -> Map(decisionId -> decision)
const memBugs = [];               // bug rows
const mobileOAuthSessions = new Map(); // sessionId -> { createdAt, jwt, user }

async function initDb() {
  if (!pool) return;
  try {
    const schema = fs.readFileSync(path.join(__dirname, 'schema.sql'), 'utf8');
    await pool.query(schema);
    console.log('PostgreSQL schema verified.');
  } catch (err) {
    console.error('PostgreSQL unavailable, falling back to in-memory store:', err.message);
    pool = null;
  }
}

// Password hashing via built-in scrypt
function hashPassword(password) {
  const salt = crypto.randomBytes(16).toString('hex');
  const derived = crypto.scryptSync(password, salt, 64).toString('hex');
  return `${salt}:${derived}`;
}

function verifyPassword(password, stored) {
  if (!stored || !stored.includes(':')) return false;
  const [salt, key] = stored.split(':');
  const derived = crypto.scryptSync(password, salt, 64);
  const keyBuf = Buffer.from(key, 'hex');
  if (derived.length !== keyBuf.length) return false;
  return crypto.timingSafeEqual(derived, keyBuf);
}

function signToken(user) {
  return jwt.sign({ id: user.id, email: user.email, name: user.name }, JWT_SECRET, { expiresIn: '30d' });
}

function authenticateToken(req, res, next) {
  const authHeader = req.headers.authorization || '';
  const token = authHeader.startsWith('Bearer ') ? authHeader.slice(7) : null;
  if (!token) return res.status(401).json({ error: 'Authentication required' });
  try {
    req.user = jwt.verify(token, JWT_SECRET);
    return next();
  } catch (_) {
    return res.status(401).json({ error: 'Invalid or expired session token' });
  }
}

// Health & Privacy endpoints
app.get('/health', (_req, res) => {
  res.json({
    status: 'ok',
    service: 'untangle-backend',
    storage: pool ? 'postgres' : 'in-memory',
    aiConfigured: Boolean(GEMINI_API_KEY),
    timestamp: new Date().toISOString(),
  });
});

app.get('/privacy', (_req, res) => {
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Untangle — Privacy Policy</title>
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; max-width: 720px; margin: 40px auto; padding: 0 20px; line-height: 1.65; color: #1c1917; background: #faf8f5; }
    h1, h2 { color: #18181b; }
    .card { background: #ffffff; border: 1px solid #e7e5e4; border-radius: 16px; padding: 28px; }
  </style>
</head>
<body>
  <div class="card">
    <h1>Untangle — Privacy Policy</h1>
    <p><strong>Effective Date:</strong> November 21, 2026</p>
    <p>Untangle ("Strategic Decision Studio") is built offline-first. You can use all 52 decision-making models without creating an account.</p>
    <h2>1. Data Stored Locally</h2>
    <p>In Guest Mode, your decisions, notes, and reminder preferences stay strictly on your device.</p>
    <h2>2. Optional Account & Cloud Sync</h2>
    <p>If you choose to register with Email/Password or Google Sign-In, we store your name, email address, hashed credentials, and encrypted-in-transit decision vault snapshot solely to synchronize your data across devices.</p>
    <h2>3. Problem-to-Method AI Suggestions</h2>
    <p>Short prompts are matched on-device. When online and entering longer descriptions, text may be sent statelessly to Gemini 2.5 Flash-Lite to recommend relevant models; prompts are never sold or shared with advertisers.</p>
    <h2>4. Notifications & Bug Reports</h2>
    <p>Optional reminder notifications are scheduled locally on your device. Voluntary bug reports include the active screen name, app version, and optional email solely to resolve reported issues.</p>
    <h2>5. Deletion & Export</h2>
    <p>You can export (.md / .json) or delete your decisions at any time inside Settings & Vault, or request account deletion via support.</p>
  </div>
</body>
</html>`);
});

// =========================================================================
// AUTHENTICATION ENDPOINTS (EMAIL/SCRYPT + GOOGLE WEB & MOBILE HANDOFF)
// =========================================================================
app.post('/api/v1/auth/register', async (req, res) => {
  try {
    const email = String(req.body.email || '').trim().toLowerCase();
    const password = String(req.body.password || '');
    const name = String(req.body.name || email.split('@')[0] || 'Explorer').trim();
    if (!email || !email.includes('@') || password.length < 6) {
      return res.status(400).json({ error: 'Valid email and password (min 6 chars) required.' });
    }
    const passwordHash = hashPassword(password);

    if (pool) {
      const existing = await pool.query('SELECT id FROM users WHERE email = $1', [email]);
      if (existing.rows.length > 0) {
        return res.status(409).json({ error: 'An account with this email already exists.' });
      }
      const ins = await pool.query(
        'INSERT INTO users (name, email, password_hash) VALUES ($1, $2, $3) RETURNING id, name, email',
        [name, email, passwordHash]
      );
      const user = ins.rows[0];
      return res.status(201).json({ token: signToken(user), user });
    }

    if (memUsers.has(email)) {
      return res.status(409).json({ error: 'An account with this email already exists.' });
    }
    const user = { id: crypto.randomUUID(), name, email, passwordHash, googleId: null };
    memUsers.set(email, user);
    memUsersById.set(user.id, user);
    return res.status(201).json({ token: signToken(user), user: { id: user.id, name: user.name, email: user.email } });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

app.post('/api/v1/auth/login', async (req, res) => {
  try {
    const email = String(req.body.email || '').trim().toLowerCase();
    const password = String(req.body.password || '');
    if (pool) {
      const q = await pool.query('SELECT id, name, email, password_hash FROM users WHERE email = $1', [email]);
      const row = q.rows[0];
      if (!row || !verifyPassword(password, row.password_hash)) {
        return res.status(401).json({ error: 'Invalid email or password.' });
      }
      const user = { id: row.id, name: row.name, email: row.email };
      return res.json({ token: signToken(user), user });
    }

    const user = memUsers.get(email);
    if (!user || !verifyPassword(password, user.passwordHash)) {
      return res.status(401).json({ error: 'Invalid email or password.' });
    }
    return res.json({ token: signToken(user), user: { id: user.id, name: user.name, email: user.email } });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

async function upsertGoogleUser({ email, name, googleId }) {
  const cleanEmail = email.toLowerCase();
  if (pool) {
    const existing = await pool.query('SELECT id, name, email FROM users WHERE email = $1', [cleanEmail]);
    if (existing.rows.length > 0) {
      await pool.query('UPDATE users SET google_id = COALESCE(google_id, $1) WHERE id = $2', [googleId, existing.rows[0].id]);
      return existing.rows[0];
    }
    const ins = await pool.query(
      'INSERT INTO users (name, email, google_id) VALUES ($1, $2, $3) RETURNING id, name, email',
      [name || cleanEmail.split('@')[0], cleanEmail, googleId]
    );
    return ins.rows[0];
  }
  let user = memUsers.get(cleanEmail);
  if (user) {
    user.googleId = user.googleId || googleId;
  } else {
    user = { id: crypto.randomUUID(), name: name || cleanEmail.split('@')[0], email: cleanEmail, passwordHash: null, googleId };
    memUsers.set(cleanEmail, user);
    memUsersById.set(user.id, user);
  }
  return { id: user.id, name: user.name, email: user.email };
}

async function verifyGoogleCredential(idToken) {
  if (!googleClient) {
    throw new Error('GOOGLE_CLIENT_ID is not configured on backend.');
  }
  const ticket = await googleClient.verifyIdToken({ idToken, audience: GOOGLE_CLIENT_ID });
  const payload = ticket.getPayload();
  if (!payload || !payload.email) throw new Error('Invalid Google token payload');
  return { email: payload.email, name: payload.name || '', googleId: payload.sub };
}

app.post('/api/v1/auth/google', async (req, res) => {
  try {
    const info = await verifyGoogleCredential(String(req.body.idToken || ''));
    const user = await upsertGoogleUser(info);
    return res.json({ token: signToken(user), user });
  } catch (err) {
    return res.status(401).json({ error: err.message });
  }
});

// Mobile Google external-browser handoff
app.post('/api/v1/auth/mobile-google/init', (_req, res) => {
  const sessionId = crypto.randomBytes(18).toString('hex');
  mobileOAuthSessions.set(sessionId, { createdAt: Date.now(), token: null, user: null });
  res.json({ sessionId });
});

app.get('/auth/mobile-google', (req, res) => {
  const session = String(req.query.session || '').replace(/[^a-f0-9]/gi, '');
  res.setHeader('Content-Type', 'text/html; charset=utf-8');
  res.send(`<!DOCTYPE html>
<html><head><meta name="viewport" content="width=device-width,initial-scale=1"/>
<title>Sign in to Untangle</title>
<script src="https://accounts.google.com/gsi/client" async defer></script>
<style>body{font-family:system-ui,sans-serif;display:flex;align-items:center;justify-content:center;min-height:100vh;background:#faf8f5;margin:0}.box{background:#fff;border:1px solid #e5e5e5;padding:28px;border-radius:16px;text-align:center;max-width:340px}</style>
</head><body><div class="box">
  <h2>Untangle Cloud Sync</h2>
  <p id="msg">Sign in with Google to return to the app.</p>
  <div id="g_id_onload" data-client_id="${GOOGLE_CLIENT_ID}" data-callback="onGoogleToken"></div>
  <div class="g_id_signin" data-type="standard"></div>
</div>
<script>
async function onGoogleToken(resp) {
  const r = await fetch('/api/v1/auth/mobile-google/complete', {
    method: 'POST', headers: {'Content-Type':'application/json'},
    body: JSON.stringify({ session: '${session}', idToken: resp.credential })
  });
  document.getElementById('msg').textContent = r.ok
    ? 'Signed in! You may close this tab and return to Untangle.'
    : 'Sign-in could not be verified.';
}
</script></body></html>`);
});

app.post('/api/v1/auth/mobile-google/complete', async (req, res) => {
  try {
    const entry = mobileOAuthSessions.get(String(req.body.session || ''));
    if (!entry) return res.status(404).json({ error: 'Invalid session' });
    const info = await verifyGoogleCredential(String(req.body.idToken || ''));
    const user = await upsertGoogleUser(info);
    entry.token = signToken(user);
    entry.user = user;
    return res.json({ success: true });
  } catch (err) {
    return res.status(401).json({ error: err.message });
  }
});

app.get('/api/v1/auth/mobile-google/poll', (req, res) => {
  const entry = mobileOAuthSessions.get(String(req.query.session || ''));
  if (!entry) return res.status(404).json({ ready: false });
  if (!entry.token) return res.json({ ready: false });
  mobileOAuthSessions.delete(String(req.query.session || ''));
  return res.json({ ready: true, token: entry.token, user: entry.user });
});

// =========================================================================
// VAULT SNAPSHOT & GRANULAR DECISION SYNC
// =========================================================================
app.get('/api/v1/untangle/state', authenticateToken, async (req, res) => {
  try {
    if (pool) {
      const q = await pool.query('SELECT snapshot, updated_at FROM vault_snapshots WHERE user_id = $1', [req.user.id]);
      return res.json({ snapshot: q.rows[0]?.snapshot || null, updatedAt: q.rows[0]?.updated_at || null });
    }
    return res.json({ snapshot: memSnapshots.get(req.user.id) || null });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

app.post('/api/v1/untangle/state', authenticateToken, async (req, res) => {
  try {
    const snapshot = req.body.snapshot || {};
    if (pool) {
      await pool.query(
        `INSERT INTO vault_snapshots (user_id, snapshot, updated_at)
         VALUES ($1, $2::jsonb, NOW())
         ON CONFLICT (user_id) DO UPDATE SET snapshot = EXCLUDED.snapshot, updated_at = NOW()`,
        [req.user.id, JSON.stringify(snapshot)]
      );
      return res.json({ success: true });
    }
    memSnapshots.set(req.user.id, snapshot);
    return res.json({ success: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

app.get('/api/v1/untangle/decisions', authenticateToken, async (req, res) => {
  try {
    if (pool) {
      const q = await pool.query('SELECT id, model_id, title, verdict, payload, updated_at FROM decisions WHERE user_id = $1 ORDER BY updated_at DESC', [req.user.id]);
      return res.json({ decisions: q.rows });
    }
    const userMap = memDecisions.get(req.user.id) || new Map();
    return res.json({ decisions: Array.from(userMap.values()) });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

app.post('/api/v1/untangle/decisions', authenticateToken, async (req, res) => {
  try {
    const { id, modelId, title, verdict = '', payload = {} } = req.body;
    if (!id || !modelId || !title) return res.status(400).json({ error: 'id, modelId, and title required' });
    if (pool) {
      await pool.query(
        `INSERT INTO decisions (user_id, id, model_id, title, verdict, payload, updated_at)
         VALUES ($1, $2, $3, $4, $5, $6::jsonb, NOW())
         ON CONFLICT (user_id, id) DO UPDATE SET model_id = EXCLUDED.model_id, title = EXCLUDED.title, verdict = EXCLUDED.verdict, payload = EXCLUDED.payload, updated_at = NOW()`,
        [req.user.id, id, Number(modelId), String(title), String(verdict), JSON.stringify(payload)]
      );
      return res.json({ success: true });
    }
    if (!memDecisions.has(req.user.id)) memDecisions.set(req.user.id, new Map());
    memDecisions.get(req.user.id).set(id, { id, model_id: Number(modelId), title, verdict, payload, updated_at: new Date().toISOString() });
    return res.json({ success: true });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

// =========================================================================
// $0.00 TIER-3 HYBRID AI PROXY (gemini-2.5-flash-lite + deterministic fallback)
// =========================================================================
function deterministicBackendSuggest(problem) {
  const q = String(problem || '').toLowerCase();
  if (/(two|offer|versus|vs\b|stay or|quit|move|torn|dilemma|either)/.test(q)) {
    return { modelIds: [6, 24, 13], fitReason: 'Weighs what holds you today against what pulls you toward the new path.', suggestedTitle: problem.slice(0, 72) };
  }
  if (/(urgent|busy|overwhelm|tasks|todo|time|focus|priorit)/.test(q)) {
    return { modelIds: [1, 38, 51], fitReason: 'Separates loud urgency from strategic long-term importance.', suggestedTitle: problem.slice(0, 72) };
  }
  if (/(conflict|argue|fight|angry|disagree|negotiate|trust)/.test(q)) {
    return { modelIds: [12, 45, 36], fitReason: 'Maps emotional vs. rational conflict steps toward a third-way consensus.', suggestedTitle: problem.slice(0, 72) };
  }
  if (/(team|employee|manage|delegate|group|hire|morale)/.test(q)) {
    return { modelIds: [46, 49, 47], fitReason: 'Diagnoses team stage and leadership support level.', suggestedTitle: problem.slice(0, 72) };
  }
  if (/(idea|creative|brainstorm|launch|startup|product|market|niche)/.test(q)) {
    return { modelIds: [48, 9, 2], fitReason: 'Evaluates your concept for an uncrowded, viable market gap.', suggestedTitle: problem.slice(0, 72) };
  }
  return { modelIds: [2, 6, 1], fitReason: 'Structures internal strengths and external factors into a clear view.', suggestedTitle: problem.slice(0, 72) };
}

function callGeminiFlashLite(problem) {
  return new Promise((resolve, reject) => {
    const prompt = `You are a concise strategic advisor mapping user dilemmas to the 52 models in The Decision Book (1=Eisenhower, 2=SWOT, 3=BCG, 4=Project Portfolio, 5=Whitmore Goals, 6=Rubber Band Dilemma, 7=Feedback, 8=Family Tree, 9=Morphological/SCAMPER, 10=Gift, 11=Consequences, 12=Conflict Resolution, 13=Crossroads, 14=Flow, 15=Johari, 16=Cognitive Dissonance, 19=Elbaek, 21=Energy, 22=SuperMemo, 24=Personal Performance Job Sail, 26=Potential Trap, 27=Hype Cycle, 31=Swiss Cheese Mistakes, 32=Maslow, 33=Outside the Box, 35=Double-Loop Learning, 36=AI Discussion, 37=Small World, 38=Pareto 80/20, 39=Long Tail, 40=Monte Carlo, 41=Black Swan, 42=The Chasm, 43=Black Box, 45=Prisoners Dilemma, 46=Drexler-Sibbet Team, 47=Team Skills, 48=Gap in Market, 49=Hersey-Blanchard Leadership, 50=Six Thinking Hats, 51=Result Optimisation 3-Loop, 52=Custom Model).
Return ONLY valid JSON: {"modelIds":[int,int,int],"fitReason":"one concise sentence under 18 words","suggestedTitle":"short title under 60 chars"}.
User problem: ${JSON.stringify(String(problem).slice(0, 600))}`;

    const body = JSON.stringify({
      contents: [{ parts: [{ text: prompt }] }],
      generationConfig: { responseMimeType: 'application/json', temperature: 0.2, maxOutputTokens: 160 }
    });

    const req = https.request(
      `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key=${GEMINI_API_KEY}`,
      { method: 'POST', headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(body) }, timeout: 2400 },
      (resp) => {
        let data = '';
        resp.on('data', chunk => { data += chunk; });
        resp.on('end', () => {
          try {
            const parsed = JSON.parse(data);
            const rawText = parsed.candidates?.[0]?.content?.parts?.[0]?.text || '';
            const json = JSON.parse(rawText);
            if (Array.isArray(json.modelIds) && json.modelIds.length >= 1) {
              return resolve(json);
            }
            reject(new Error('Malformed Gemini JSON'));
          } catch (e) {
            reject(e);
          }
        });
      }
    );
    req.on('error', reject);
    req.on('timeout', () => { req.destroy(); reject(new Error('Gemini timeout')); });
    req.write(body);
    req.end();
  });
}

app.post('/api/v1/untangle/ai-parse', async (req, res) => {
  const problem = String(req.body.problem || '').trim();
  if (!problem) return res.status(400).json({ error: 'problem required' });
  if (!GEMINI_API_KEY) {
    return res.json({ source: 'deterministic', ...deterministicBackendSuggest(problem) });
  }
  try {
    const aiRes = await callGeminiFlashLite(problem);
    return res.json({ source: 'gemini-2.5-flash-lite', ...aiRes });
  } catch (_) {
    return res.json({ source: 'deterministic-fallback', ...deterministicBackendSuggest(problem) });
  }
});

// =========================================================================
// CLOSED-LOOP IN-APP BUG TRIAGE ENDPOINTS
// =========================================================================
app.post('/api/v1/bugs', async (req, res) => {
  try {
    const description = String(req.body.description || '').trim();
    if (!description) return res.status(400).json({ error: 'Bug description is required.' });
    const userEmail = String(req.body.userEmail || req.body.user_email || 'anonymous@tester.local').trim().toLowerCase();
    const pageContext = String(req.body.pageContext || req.body.page_context || '').trim();
    const appVersion = String(req.body.appVersion || req.body.app_version || '1.0.0+1').trim();
    const deviceInfo = req.body.deviceInfo || req.body.device_info || {};

    if (pool) {
      const q = await pool.query(
        `INSERT INTO bug_reports (user_email, description, page_context, app_version, device_info)
         VALUES ($1, $2, $3, $4, $5::jsonb)
         RETURNING *`,
        [userEmail, description, pageContext, appVersion, JSON.stringify(deviceInfo)]
      );
      return res.status(201).json({ success: true, bug: q.rows[0] });
    }

    const bug = {
      id: crypto.randomUUID(),
      user_email: userEmail,
      description,
      page_context: pageContext,
      app_version: appVersion,
      device_info: deviceInfo,
      status: 'open',
      resolution_notes: '',
      created_at: new Date().toISOString(),
      resolved_at: null,
    };
    memBugs.unshift(bug);
    return res.status(201).json({ success: true, bug });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

app.get('/api/v1/bugs', async (req, res) => {
  try {
    const status = String(req.query.status || 'open').toLowerCase();
    const limit = Math.min(Number(req.query.limit || 100), 250);
    if (pool) {
      const q = status === 'all'
        ? await pool.query('SELECT * FROM bug_reports ORDER BY created_at DESC LIMIT $1', [limit])
        : await pool.query('SELECT * FROM bug_reports WHERE status = $1 ORDER BY created_at DESC LIMIT $2', [status, limit]);
      return res.json({ bugs: q.rows });
    }
    const filtered = status === 'all' ? memBugs : memBugs.filter(b => b.status === status);
    return res.json({ bugs: filtered.slice(0, limit) });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

app.patch('/api/v1/bugs/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const status = req.body.status ? String(req.body.status) : null;
    const resolutionNotes = req.body.resolutionNotes ?? req.body.resolution_notes ?? null;

    if (pool) {
      const q = await pool.query(
        `UPDATE bug_reports
         SET status = COALESCE($1, status),
             resolution_notes = COALESCE($2, resolution_notes),
             resolved_at = CASE WHEN $1 = 'resolved' THEN NOW() ELSE resolved_at END
         WHERE id = $3
         RETURNING *`,
        [status, resolutionNotes, id]
      );
      if (!q.rows[0]) return res.status(404).json({ error: 'Bug ticket not found' });
      return res.json({ success: true, bug: q.rows[0] });
    }

    const idx = memBugs.findIndex(b => b.id === id);
    if (idx === -1) return res.status(404).json({ error: 'Bug ticket not found' });
    if (status) memBugs[idx].status = status;
    if (resolutionNotes !== null) memBugs[idx].resolution_notes = resolutionNotes;
    if (status === 'resolved') memBugs[idx].resolved_at = new Date().toISOString();
    return res.json({ success: true, bug: memBugs[idx] });
  } catch (err) {
    return res.status(500).json({ error: err.message });
  }
});

if (require.main === module) {
  initDb().then(() => {
    app.listen(PORT, () => {
      console.log(`Untangle API listening on port ${PORT}`);
    });
  });
}

module.exports = app;
