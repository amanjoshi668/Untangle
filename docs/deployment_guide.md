# Untangle — Deployment Guide

## 1. Backend (Cloud Run)
```bash
cd untangle_backend
# One-time: create secrets
printf '%s' "$(openssl rand -hex 32)" | gcloud secrets create JWT_SECRET --data-file=-
printf '%s' "postgres://USER:PASS@/untangle?host=/cloudsql/PROJECT:REGION:INSTANCE" | gcloud secrets create DATABASE_URL --data-file=-
printf '%s' "<free-tier Gemini key>" | gcloud secrets create GEMINI_API_KEY --data-file=-
printf '%s' "<OAuth web client id>" | gcloud secrets create GOOGLE_CLIENT_ID --data-file=-

GCP_PROJECT_ID=<your-project> GCP_REGION=us-central1 ./deploy_cloudshell.sh
```
Attach the Cloud SQL instance to the service (`--add-cloudsql-instances`) if using Postgres. Without `DATABASE_URL` the API still runs (in-memory, non-persistent).

## 2. Point the app at the API
```bash
cd untangle_app
flutter build apk --release --dart-define=UNTANGLE_API_URL=https://untangle-api-xxxx.run.app
flutter build appbundle --release --dart-define=UNTANGLE_API_URL=https://untangle-api-xxxx.run.app
flutter build web --release --dart-define=UNTANGLE_API_URL=https://untangle-api-xxxx.run.app
```
Without the define, the app defaults to `http://localhost:8080` and works fully offline (guest vault, local accounts, deterministic recommender).

## 3. Google Sign-In
- OAuth **Web** client: add the Cloud Run URL and `http://localhost` to Authorized JavaScript origins.
- OAuth **Android** client: package `com.amanjoshi.untangle_app` + upload-key and Play App Signing SHA-1.

## 4. Release signing
`untangle_app/android/key.properties` (gitignored) points at `upload-keystore.jks` (gitignored, kept at repo root locally). **Back up the keystore and passwords** — losing them blocks future Play updates.
