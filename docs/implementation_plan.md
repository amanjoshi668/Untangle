# Untangle — Implementation Plan & Architecture

## Phase Summary
1. **Workspace & Spec Scaffolding:** Monorepo initialized (`untangle_app/`, `untangle_backend/`, `docs/`, `store_assets/`) and tracked at `https://github.com/amanjoshi668/Untangle.git`.
2. **Offline-First Vault & Dual Auth:** `AuthService` (Day-1 Guest Mode + `scrypt` Email/Password + Google SSO) and `VaultStorage` (`untangle_vault_v2_<userId>`, `defaultSeeded` once-only starter, zero-loss Guest→Account migration, real-calendar SuperMemo catch-up).
3. **52-Model Catalog & 8 Interactive Canvas Engines:** Full structured dataset for *The Decision Book* (`#01`–`#52`) rendered via 8 specialized touch-ergonomic engines (`E1`–`E8`) with live Takeaway synthesis and compact `?` writeup popovers.
4. **Stateless Cloud Run API & `$0.00` Hybrid AI:** Express server (`server.js`) with in-memory + PostgreSQL support and `gemini-2.5-flash-lite` proxy (`2.8 s` timeout, seamless on-device fallback).
5. **Native Android Bridges & Closed-Loop Bug Triage:** Kotlin `MethodChannel` (`AlarmManager.setAndAllowWhileIdle` + SAF export) and server-reconciled `BugReportRecord` + `triage_bugs.js`.
6. **Release Gate:** `flutter analyze` (`0` issues), `flutter test` (`360×800` CUJ suite `100%` passing), and signed release `.aab`, `.apk`, and Web PWA builds.
