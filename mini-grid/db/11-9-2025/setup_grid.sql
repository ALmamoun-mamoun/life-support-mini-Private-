DROP TABLE IF EXISTS prospect;

CREATE TABLE prospect (
    company_id     INTEGER PRIMARY KEY AUTOINCREMENT,
    company_name   TEXT NOT NULL,
    website        TEXT,
    email          TEXT,
    phone          TEXT,
    notes          TEXT,
    status         INTEGER DEFAULT 0,  -- 0=pending, 1=permitted, 2=held elsewhere
    last_edit_date TEXT DEFAULT (date('now')),
    counter        INTEGER DEFAULT 0,
    permit_flag    INTEGER DEFAULT 0   -- 0=OFF, 1=ON
);

DROP TABLE IF EXISTS event_outbox;

CREATE TABLE event_outbox (
    id          INTEGER PRIMARY KEY AUTOINCREMENT,
    company_id  INTEGER,
    action      TEXT,          
    payload     TEXT,          
    created_at  TEXT DEFAULT (datetime('now'))
);
