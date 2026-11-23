# Untangle — Strategic Decision Studio

**Untangle** turns all **52 strategic thinking models** from *The Decision Book* into a calm, offline-first cross-platform decision studio for **Android, Web PWA, and Tablet/Desktop Split-View**.

## Two Seamless Ways to Use Untangle
1. **Mode 1 — Tell Your Problem (`Decide`):** Describe any dilemma, priority crunch, or team challenge in plain words. Untangle's `$0.00` 3-tier hybrid recommender matches the best model (plus 2 alternatives) and pre-populates the interactive workspace with zero re-typing.
2. **Mode 2 — Direct 52-Model Library (`Techniques`):** Search, filter by chapter or time (`≤2 min`), or explore the interactive **Page-82 Book Meta-Compass** (`Me ↔ Others` × `Doing ↔ Thinking`) to jump straight into any model.
3. **Compact `?` Technique Popover:** Every technique features a concise plain-English writeup, *How to use* tip, quote, and related models tucked cleanly under a circular **`?` button** so primary screens stay uncluttered.

## Monorepo Layout
- `untangle_app/` — Flutter client (Android `.aab`/`.apk`, Web PWA, responsive `≥900 px` split-view, `360×800` CUJ test suite, native Kotlin `AlarmManager` reminders & SAF `.md`/`.json` export).
- `untangle_backend/` — Stateless Node.js + Express Cloud Run API (`server.js`, PostgreSQL `schema.sql` with zero-DB in-memory fallback, `$0.00` `gemini-2.5-flash-lite` proxy, Dual Auth, and `triage_bugs.js`).
- `docs/` — Product, UX design, backend, deployment, Play Store publishing, privacy policy, and interactive HTML prototype (`docs/mocks/interactive_mocks.html`).
- `store_assets/` — Play Store listing copy, generated app icons (`512`, `1024`), and feature graphic (`1024×500`).

## Quick Start
```bash
# Run Flutter CUJ verification & app
cd untangle_app
flutter analyze
flutter test
flutter run -d chrome

# Run stateless backend locally (works with or without PostgreSQL)
cd ../untangle_backend
npm install
npm start
```
