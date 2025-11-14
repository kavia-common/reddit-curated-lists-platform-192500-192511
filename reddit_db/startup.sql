-- Reddit Curated Lists Platform - Minimal PostgreSQL Schema
-- This file is idempotent (uses IF NOT EXISTS and ON CONFLICT patterns)

-- Users: application users
CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    password_hash TEXT,
    display_name TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Reddit accounts linked by users
CREATE TABLE IF NOT EXISTS reddit_accounts (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    reddit_username TEXT,
    oauth_access_token TEXT,
    oauth_refresh_token TEXT,
    token_expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_reddit_accounts_user_id ON reddit_accounts(user_id);

-- Lists: a named, shareable list owned by a user
CREATE TABLE IF NOT EXISTS lists (
    id BIGSERIAL PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    description TEXT,
    public_id TEXT UNIQUE, -- for public sharing
    is_public BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_lists_user_id ON lists(user_id);
CREATE INDEX IF NOT EXISTS idx_lists_public_id ON lists(public_id);

-- List items: subreddits in a list
CREATE TABLE IF NOT EXISTS list_items (
    id BIGSERIAL PRIMARY KEY,
    list_id BIGINT NOT NULL REFERENCES lists(id) ON DELETE CASCADE,
    subreddit_name TEXT NOT NULL,
    position INT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_list_items_list_id ON list_items(list_id);
CREATE UNIQUE INDEX IF NOT EXISTS ux_list_items_list_subreddit ON list_items(list_id, subreddit_name);

-- Posts: scraped posts from subreddits
CREATE TABLE IF NOT EXISTS posts (
    id BIGSERIAL PRIMARY KEY,
    reddit_post_id TEXT NOT NULL UNIQUE,
    subreddit_name TEXT NOT NULL,
    title TEXT NOT NULL,
    author TEXT,
    url TEXT,
    permalink TEXT,
    created_utc TIMESTAMPTZ,
    selftext TEXT,
    preview_json JSONB,
    extra JSONB,
    inserted_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
-- Indexes for querying by subreddit and time
CREATE INDEX IF NOT EXISTS idx_posts_subreddit_created ON posts(subreddit_name, created_utc);
CREATE INDEX IF NOT EXISTS idx_posts_created ON posts(created_utc);

-- list_posts: association of lists to posts (snapshot relationship)
CREATE TABLE IF NOT EXISTS list_posts (
    id BIGSERIAL PRIMARY KEY,
    list_id BIGINT NOT NULL REFERENCES lists(id) ON DELETE CASCADE,
    post_id BIGINT NOT NULL REFERENCES posts(id) ON DELETE CASCADE,
    added_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_list_posts_list_post ON list_posts(list_id, post_id);
CREATE INDEX IF NOT EXISTS idx_list_posts_list_id ON list_posts(list_id);
CREATE INDEX IF NOT EXISTS idx_list_posts_post_id ON list_posts(post_id);

-- list_shares: share links and metadata
CREATE TABLE IF NOT EXISTS list_shares (
    id BIGSERIAL PRIMARY KEY,
    list_id BIGINT NOT NULL REFERENCES lists(id) ON DELETE CASCADE,
    public_id TEXT NOT NULL UNIQUE, -- externally visible share ID
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    expires_at TIMESTAMPTZ,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    view_count BIGINT NOT NULL DEFAULT 0
);
CREATE INDEX IF NOT EXISTS idx_list_shares_list_id ON list_shares(list_id);
CREATE INDEX IF NOT EXISTS idx_list_shares_public_id ON list_shares(public_id);

-- Helpful functional index examples (kept minimal, uncomment if needed)
-- CREATE INDEX IF NOT EXISTS idx_posts_subreddit_lower ON posts((lower(subreddit_name)));

-- Ensure some basic constraints are consistent (idempotent safety)
-- No-op constraints due to IF NOT EXISTS usage above; composite and unique constraints set via unique indexes.
