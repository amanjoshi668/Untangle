#!/usr/bin/env node
/**
 * Zero-dependency CLI for Closed-Loop In-App Bug Triage
 * Usage:
 *   node triage_bugs.js list [open|resolved|all]
 *   node triage_bugs.js resolve <uuid> "Fixed in v1.0.1+2: <notes>"
 */
const http = require('http');
const https = require('https');

const BASE_URL = (process.env.UNTANGLE_API_URL || 'http://localhost:8080').replace(/\/$/, '');
const [, , action = 'list', arg1 = 'open', arg2 = ''] = process.argv;

function requestJson(method, urlStr, body) {
  return new Promise((resolve, reject) => {
    const u = new URL(urlStr);
    const lib = u.protocol === 'https:' ? https : http;
    const payload = body ? JSON.stringify(body) : null;
    const req = lib.request(
      u,
      {
        method,
        headers: payload
          ? { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(payload) }
          : {},
      },
      (res) => {
        let raw = '';
        res.on('data', (c) => { raw += c; });
        res.on('end', () => {
          try {
            resolve({ status: res.statusCode, data: JSON.parse(raw || '{}') });
          } catch (_) {
            resolve({ status: res.statusCode, data: { raw } });
          }
        });
      }
    );
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

(async () => {
  if (action === 'list') {
    const status = arg1 || 'open';
    const { data } = await requestJson('GET', `${BASE_URL}/api/v1/bugs?status=${encodeURIComponent(status)}&limit=100`);
    const bugs = data.bugs || [];
    console.log(`=== Untangle Bug Reports (${status.toUpperCase()}) — Total: ${bugs.length} ===`);
    for (const b of bugs) {
      console.log(`- [${b.status}] ${b.id} | ${b.user_email} | ${b.page_context} (${b.app_version})\n  "${b.description}"${b.resolution_notes ? `\n  -> Resolution: ${b.resolution_notes}` : ''}`);
    }
  } else if (action === 'resolve') {
    if (!arg1) {
      console.error('Usage: node triage_bugs.js resolve <uuid> "<resolution notes>"');
      process.exit(1);
    }
    const { status, data } = await requestJson('PATCH', `${BASE_URL}/api/v1/bugs/${arg1}`, {
      status: 'resolved',
      resolutionNotes: arg2 || 'Resolved and verified in latest release.',
    });
    console.log(`HTTP ${status}:`, JSON.stringify(data, null, 2));
  } else {
    console.error(`Unknown command: ${action}`);
    process.exit(1);
  }
})().catch((err) => {
  console.error('Triage CLI error:', err.message);
  process.exit(1);
});
