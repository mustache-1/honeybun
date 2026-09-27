-- Honeybun database (Cloudflare D1)
CREATE TABLE IF NOT EXISTS users (
  id          TEXT PRIMARY KEY,
  email       TEXT NOT NULL UNIQUE,
  name        TEXT NOT NULL,
  pw          TEXT NOT NULL,
  created_at  INTEGER NOT NULL
);

CREATE TABLE IF NOT EXISTS sessions (
  token_hash  TEXT PRIMARY KEY,
  user_id     TEXT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at  INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_sessions_user ON sessions(user_id);

CREATE TABLE IF NOT EXISTS nests (
  id           TEXT PRIMARY KEY,
  name         TEXT NOT NULL DEFAULT '',
  invite_code  TEXT NOT NULL UNIQUE,
  accent       TEXT NOT NULL DEFAULT 'blueberry',
  goal_name    TEXT NOT NULL DEFAULT 'Weekend getaway',
  goal_target  INTEGER NOT NULL DEFAULT 80000,   -- cents
  goal_saved   INTEGER NOT NULL DEFAULT 0,       -- cents
  created_by   TEXT NOT NULL,
  created_at   INTEGER NOT NULL
);

-- one budget per person
CREATE TABLE IF NOT EXISTS members (
  nest_id    TEXT NOT NULL REFERENCES nests(id) ON DELETE CASCADE,
  user_id    TEXT NOT NULL UNIQUE REFERENCES users(id) ON DELETE CASCADE,
  emoji      TEXT NOT NULL,
  color      TEXT NOT NULL,
  joined_at  INTEGER NOT NULL,
  PRIMARY KEY (nest_id, user_id)
);

CREATE TABLE IF NOT EXISTS entries (
  id            TEXT PRIMARY KEY,
  nest_id       TEXT NOT NULL REFERENCES nests(id) ON DELETE CASCADE,
  member_id     TEXT NOT NULL,          -- user id of who paid / got paid
  type          TEXT NOT NULL CHECK (type IN ('income','expense')),
  amount_cents  INTEGER NOT NULL CHECK (amount_cents > 0),
  label         TEXT NOT NULL,
  category      TEXT,
  shared        INTEGER NOT NULL DEFAULT 0,
  date          TEXT NOT NULL,          -- YYYY-MM-DD
  created_by    TEXT NOT NULL,
  created_at    INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_entries_nest_date ON entries(nest_id, date);

-- simple brute-force protection for login / signup / joining
CREATE TABLE IF NOT EXISTS auth_attempts (
  key  TEXT NOT NULL,
  ts   INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_attempts ON auth_attempts(key, ts);
