
-- Life-Support DB Schema v1 (SQLite)
PRAGMA foreign_keys = ON;

-- ===== core records =====
CREATE TABLE IF NOT EXISTS records (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  guid TEXT NOT NULL UNIQUE,
  owner_agent_id TEXT,
  source_url TEXT,
  source_name TEXT,
  date_collected TEXT,
  raw_content TEXT,
  status TEXT CHECK(status IN ('new','processed','linked','archived')) DEFAULT 'new',
  content_hash TEXT,
  to_seek INTEGER NOT NULL DEFAULT 0,                  -- 0/1
  seek_priority INTEGER DEFAULT 0 CHECK(seek_priority BETWEEN 0 AND 5),
  seek_status TEXT DEFAULT 'queued' CHECK(seek_status IN ('queued','in_progress','paused','done')),
  next_action_at TEXT,
  last_attempt_at TEXT,
  attempts INTEGER NOT NULL DEFAULT 0,
  version INTEGER NOT NULL DEFAULT 0,
  created_at TEXT DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE INDEX IF NOT EXISTS idx_records_guid ON records(guid);
CREATE INDEX IF NOT EXISTS idx_records_hash ON records(content_hash);
CREATE INDEX IF NOT EXISTS idx_records_seek ON records(to_seek, seek_status, seek_priority, next_action_at);
CREATE INDEX IF NOT EXISTS idx_records_owner ON records(owner_agent_id);

-- auto-update updated_at
CREATE TRIGGER IF NOT EXISTS trg_records_updated_at
AFTER UPDATE ON records
FOR EACH ROW
BEGIN
  UPDATE records SET updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE id = NEW.id;
END;

-- ===== record notes =====
CREATE TABLE IF NOT EXISTS record_notes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  guid TEXT NOT NULL UNIQUE,
  record_guid TEXT NOT NULL,
  note_text TEXT,
  author TEXT,
  version INTEGER NOT NULL DEFAULT 0,
  created_at TEXT DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
  FOREIGN KEY(record_guid) REFERENCES records(guid) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_record_notes_record ON record_notes(record_guid);

CREATE TRIGGER IF NOT EXISTS trg_record_notes_updated_at
AFTER UPDATE ON record_notes
FOR EACH ROW
BEGIN
  UPDATE record_notes SET updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE id = NEW.id;
END;

-- ===== record history =====
CREATE TABLE IF NOT EXISTS record_history (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  guid TEXT NOT NULL UNIQUE,
  record_guid TEXT NOT NULL,
  change_type TEXT,
  details TEXT,
  created_at TEXT DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
  FOREIGN KEY(record_guid) REFERENCES records(guid) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_record_history_record ON record_history(record_guid);

-- ===== link: record_doctors =====
CREATE TABLE IF NOT EXISTS record_doctors (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  guid TEXT NOT NULL UNIQUE,
  record_guid TEXT NOT NULL,
  doctor_guid TEXT NOT NULL,
  created_at TEXT DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
  FOREIGN KEY(record_guid) REFERENCES records(guid) ON DELETE CASCADE
);
CREATE INDEX IF NOT EXISTS idx_record_doctors_record ON record_doctors(record_guid);
CREATE INDEX IF NOT EXISTS idx_record_doctors_doctor ON record_doctors(doctor_guid);

-- ===== assignments =====
CREATE TABLE IF NOT EXISTS assignments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  guid TEXT NOT NULL UNIQUE,
  target_guid TEXT NOT NULL,
  assignee_agent_id TEXT NOT NULL,
  scope TEXT,
  created_at TEXT DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
  updated_at TEXT DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TRIGGER IF NOT EXISTS trg_assignments_updated_at
AFTER UPDATE ON assignments
FOR EACH ROW
BEGIN
  UPDATE assignments SET updated_at = STRFTIME('%Y-%m-%dT%H:%M:%fZ','now') WHERE id = NEW.id;
END;

-- ===== change log =====
CREATE TABLE IF NOT EXISTS change_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  entity TEXT NOT NULL,
  entity_guid TEXT NOT NULL,
  op TEXT NOT NULL,                -- 'upsert'|'delete'
  version INTEGER NOT NULL,
  author_agent_id TEXT,
  changes_json TEXT NOT NULL,
  ts TEXT DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
);
CREATE INDEX IF NOT EXISTS idx_change_log_entity ON change_log(entity, entity_guid, version);

-- ===== inbox/outbox =====
CREATE TABLE IF NOT EXISTS outbox (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  bundle_guid TEXT NOT NULL,
  status TEXT CHECK(status IN ('queued','exported')) DEFAULT 'queued',
  created_at TEXT DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now'))
);

CREATE TABLE IF NOT EXISTS inbox (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  bundle_guid TEXT NOT NULL,
  status TEXT CHECK(status IN ('received','applied','error')) DEFAULT 'received',
  created_at TEXT DEFAULT (STRFTIME('%Y-%m-%dT%H:%M:%fZ','now')),
  error TEXT
);

-- ===== views =====
CREATE VIEW IF NOT EXISTS v_seek_queue AS
SELECT guid, source_name, source_url, seek_priority, seek_status, next_action_at
FROM records
WHERE to_seek=1 AND seek_status IN ('queued','in_progress')
ORDER BY COALESCE(next_action_at,'9999-12-31'), seek_priority DESC, guid;
