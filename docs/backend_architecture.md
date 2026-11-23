# Untangle — Backend Architecture

## Overview
Stateless Node.js + Express service (`untangle_backend/server.js`) designed for Cloud Run. Boots with **no database** (in-memory fallback) for local dev; uses PostgreSQL via `DATABASE_URL` or the Cloud SQL Unix socket (`/cloudsql/<INSTANCE_CONNECTION_NAME>`) in production. Schema is applied idempotently from `schema.sql` on boot.

## Endpoints
| Method & Path | Purpose |
| :--- | :--- |
| `GET /health` | Liveness + storage mode + whether AI is configured |
| `GET /privacy` | HTML privacy policy (mirrors `docs/PRIVACY_POLICY.md`) |
| `POST /api/v1/auth/register` · `/login` | Email/password with built-in `scrypt`, returns 30-day JWT |
| `POST /api/v1/auth/google` | Verify Google ID token (web), upsert/link by email |
| `POST /api/v1/auth/mobile-google/init` · `GET /auth/mobile-google` · `POST .../complete` · `GET .../poll` | Android external-browser Google sign-in handoff |
| `GET/POST /api/v1/untangle/state` | Full JSONB vault snapshot sync (auth) |
| `GET/POST /api/v1/untangle/decisions` | Granular decision upserts (auth) |
| `POST /api/v1/untangle/ai-parse` | Tier-3 recommender: `gemini-2.5-flash-lite` (2.4 s server timeout) → deterministic fallback |
| `POST/GET /api/v1/bugs` · `PATCH /api/v1/bugs/:id` | Closed-loop bug triage |

## Tables
`users`, `vault_snapshots`, `decisions`, `bug_reports` (see `schema.sql`).

## $0.00 Recommendation Pipeline
1. **Tier 1 (client, 0 ms):** explicit model-name / shorthand match.
2. **Tier 2 (client, <2 ms):** keyword + intent-regex facet scorer over all 52 models, scope-aware.
3. **Tier 3 (server, ≤2.8 s client timeout):** only for inputs ≥10 words when online; free-tier Gemini returns model IDs + one-line rationale; merged with Tier 2, which remains the seamless fallback.

## Ops
- Secrets via Secret Manager: `JWT_SECRET`, `DATABASE_URL`, `GEMINI_API_KEY`, `GOOGLE_CLIENT_ID`.
- `triage_bugs.js list [open|resolved|all]` / `resolve <id> "<notes>"` (uses `UNTANGLE_API_URL`).
