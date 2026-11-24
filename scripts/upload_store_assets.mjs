#!/usr/bin/env node
/**
 * Keyless Google Play Android Publisher API v3 store-listing graphics uploader
 * (icon, featureGraphic, phoneScreenshots) using IAM Credentials generateAccessToken.
 */
import fs from 'node:fs';
import path from 'node:path';

const SERVICE_ACCOUNT = process.env.PLAY_SERVICE_ACCOUNT_EMAIL || 'play-release-bot@bullet-journal-514307.iam.gserviceaccount.com';
const PACKAGE = process.env.PLAY_PACKAGE || 'com.amanjoshi.untangle_app';
const LANG = 'en-US';
const SCOPE = 'https://www.googleapis.com/auth/androidpublisher';
const IAM_CREDS_BASE = 'https://iamcredentials.googleapis.com/v1/projects/-/serviceAccounts';
const API_BASE = 'https://androidpublisher.googleapis.com/androidpublisher/v3';
const UPLOAD_BASE = 'https://androidpublisher.googleapis.com/upload/androidpublisher/v3';

async function mintToken(userToken) {
  const res = await fetch(`${IAM_CREDS_BASE}/${SERVICE_ACCOUNT}:generateAccessToken`, {
    method: 'POST',
    headers: { Authorization: `Bearer ${userToken}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({ scope: [SCOPE] }),
  });
  const data = await res.json();
  if (!res.ok || !data.accessToken) throw new Error(`IAM token error (${res.status}): ${JSON.stringify(data)}`);
  return data.accessToken;
}

async function apiJson(url, method, token, body) {
  const res = await fetch(url, {
    method,
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  const parsed = text ? JSON.parse(text) : {};
  if (!res.ok) throw new Error(`API ${method} ${url} (${res.status}): ${JSON.stringify(parsed)}`);
  return parsed;
}

async function uploadImage(token, editId, imageType, filePath) {
  const bytes = fs.readFileSync(filePath);
  const url = `${UPLOAD_BASE}/applications/${PACKAGE}/edits/${editId}/listings/${LANG}/${imageType}?uploadType=media`;
  const res = await fetch(url, {
    method: 'POST',
    headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'image/png', 'Content-Length': String(bytes.length) },
    body: bytes,
  });
  const text = await res.text();
  if (!res.ok) throw new Error(`Upload ${imageType} (${path.basename(filePath)}) failed (${res.status}): ${text}`);
  console.log(`Uploaded ${imageType}: ${path.basename(filePath)}`);
}

async function main() {
  const userToken = (process.env.GCLOUD_USER_TOKEN || '').trim();
  if (!userToken) throw new Error('Missing GCLOUD_USER_TOKEN');
  const token = await mintToken(userToken);

  const edit = await apiJson(`${API_BASE}/applications/${PACKAGE}/edits`, 'POST', token, {});
  const editId = edit.id;
  console.log(`Created edit ${editId} for ${PACKAGE}`);

  await uploadImage(token, editId, 'icon', 'store_assets/icon_512.png');
  await uploadImage(token, editId, 'featureGraphic', 'store_assets/feature_graphic_1024x500.png');
  for (const shot of [
    'store_assets/screenshots/phone_1_decide.png',
    'store_assets/screenshots/phone_2_workspace.png',
    'store_assets/screenshots/phone_3_compass.png',
    'store_assets/screenshots/phone_4_journal_dark.png',
  ]) {
    await uploadImage(token, editId, 'phoneScreenshots', shot);
  }

  await apiJson(`${API_BASE}/applications/${PACKAGE}/edits/${editId}:commit`, 'POST', token, {});
  console.log('Committed all store listing graphics to Google Play!');
}

main().catch((e) => {
  console.error(e.message);
  process.exit(1);
});
