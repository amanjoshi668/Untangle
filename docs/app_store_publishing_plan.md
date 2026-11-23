# Untangle — App Store Publishing Plan

1. **Pre-flight:** `flutter analyze` (0 issues) → `flutter test` (all CUJs pass at 360×800) → bump `version:` in `pubspec.yaml` for every upload.
2. **Build:** `flutter build appbundle --release --dart-define=UNTANGLE_API_URL=<cloud run url>` → `build/app/outputs/bundle/release/app-release.aab`.
3. **Play Console:** create app "Untangle", upload AAB to **Closed testing** (personal accounts: 20 testers × 14 days), then promote to Production.
4. **Listing:** copy from `store_assets/PLAY_STORE_LISTING.md`; icon `store_assets/icon_512.png`; feature graphic `store_assets/feature_graphic_1024x500.png`; phone & tablet screenshots (light + dark).
5. **Data safety:** declare optional account data (name, email), user-generated content (decisions) synced only when signed in, optional bug-report data; encrypted in transit; user can request deletion.
6. **Post-upload:** add Play App Signing SHA-1 to the Android OAuth client so Google Sign-In works on Play-installed builds.

> **Content/IP note:** the technique names and ideas come from *The Decision Book* (Krogerus & Tschäppeler). All in-app writeups are original paraphrases, but before a public release consider contacting the publisher (W. W. Norton) or clearly positioning the app as an independent companion, and avoid using the book's title or cover in store assets.
