PRAGMA foreign_keys=ON;
BEGIN;

-- Lookup for tri-state gatekeeping
CREATE TABLE IF NOT EXISTS gate_status_lu(
  code INTEGER PRIMARY KEY,
  name TEXT UNIQUE NOT NULL
);
INSERT OR IGNORE INTO gate_status_lu(code,name) VALUES
  (0,'pending'),
  (1,'permitted'),
  (2,'held_elsewhere');

-- Gatekeeping table
CREATE TABLE IF NOT EXISTS gatekeeping(
  entity_type TEXT NOT NULL DEFAULT 'prospect',
  entity_guid  TEXT NOT NULL,
  status       INTEGER NOT NULL DEFAULT 0 CHECK(status IN (0,1,2)),
  source       TEXT,
  note         TEXT,
  updated_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  PRIMARY KEY (entity_type, entity_guid),
  FOREIGN KEY (status) REFERENCES gate_status_lu(code)
);

CREATE INDEX IF NOT EXISTS idx_gatekeeping_status     ON gatekeeping(status);
CREATE INDEX IF NOT EXISTS idx_gatekeeping_updated_at ON gatekeeping(updated_at);

-- Outbox for notifications
CREATE TABLE IF NOT EXISTS event_outbox(
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  topic        TEXT NOT NULL,
  entity_type  TEXT NOT NULL,
  entity_guid  TEXT NOT NULL,
  status       INTEGER,
  payload      TEXT,
  created_at   TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
  delivered_at TEXT
);

-- Notify on INSERT
CREATE TRIGGER IF NOT EXISTS trg_gatekeeping_notify_insert
AFTER INSERT ON gatekeeping
BEGIN
  INSERT INTO event_outbox(topic,entity_type,entity_guid,status,payload)
  VALUES('gatekeeping.changed', NEW.entity_type, NEW.entity_guid, NEW.status, NULL);
END;

-- Notify on UPDATE (status change)
CREATE TRIGGER IF NOT EXISTS trg_gatekeeping_notify_update
AFTER UPDATE OF status ON gatekeeping
FOR EACH ROW
WHEN NEW.status <> OLD.status
BEGIN
  INSERT INTO event_outbox(topic,entity_type,entity_guid,status,payload)
  VALUES('gatekeeping.changed', NEW.entity_type, NEW.entity_guid, NEW.status, NULL);
END;

-- Convenience view
CREATE VIEW IF NOT EXISTS v_gatekeeping_permitted AS
  SELECT * FROM gatekeeping WHERE status = 1;

COMMIT;
