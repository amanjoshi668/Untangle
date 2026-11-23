CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(120) NOT NULL DEFAULT 'Explorer',
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash TEXT,
    google_id VARCHAR(255),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS vault_snapshots (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    snapshot JSONB NOT NULL DEFAULT '{}'::jsonb,
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS decisions (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    id VARCHAR(120) NOT NULL,
    model_id INT NOT NULL,
    title TEXT NOT NULL,
    verdict TEXT DEFAULT '',
    payload JSONB NOT NULL DEFAULT '{}'::jsonb,
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    PRIMARY KEY (user_id, id)
);

CREATE TABLE IF NOT EXISTS bug_reports (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_email VARCHAR(255) DEFAULT 'anonymous@tester.local',
    description TEXT NOT NULL,
    page_context VARCHAR(100) DEFAULT '',
    app_version VARCHAR(50) DEFAULT '',
    device_info JSONB DEFAULT '{}'::jsonb,
    status VARCHAR(20) DEFAULT 'open',
    resolution_notes TEXT DEFAULT '',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    resolved_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_bug_reports_status ON bug_reports(status);
