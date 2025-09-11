-- =========================================================
-- setup_mini.sql (Full-house, with Prospect Archiving)
-- =========================================================

PRAGMA foreign_keys = ON;

-- =======================
-- Sponsors
-- =======================
CREATE TABLE IF NOT EXISTS sponsors (
    gat_id          TEXT NOT NULL,
    city_id         TEXT NOT NULL,
    company_id      TEXT NOT NULL,
    sponsor_name    TEXT NOT NULL,
    contract_date   TEXT NOT NULL,   -- YYYY-MM-DD
    expiration_date TEXT NOT NULL,   -- YYYY-MM-DD
    created_at      TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at      TEXT DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (gat_id, city_id, company_id)
);

CREATE TRIGGER IF NOT EXISTS trg_sponsors_updated
AFTER UPDATE ON sponsors
FOR EACH ROW
BEGIN
    UPDATE sponsors
    SET updated_at = CURRENT_TIMESTAMP
    WHERE gat_id = OLD.gat_id AND city_id = OLD.city_id AND company_id = OLD.company_id;
END;

-- =======================
-- Prospects (with archiving)
-- =======================
CREATE TABLE IF NOT EXISTS prospects (
    gat_id            TEXT NOT NULL,
    city_id           TEXT NOT NULL,
    company_id        TEXT NOT NULL,
    prospect_name     TEXT NOT NULL,
    contract_date     TEXT,                 -- placeholder
    expiration_date   TEXT,                 -- placeholder
    lifecycle_status  TEXT NOT NULL DEFAULT 'active' CHECK (lifecycle_status IN ('active','archived')),
    archived_at       TEXT,                 -- set when archived
    created_at        TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at        TEXT DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (gat_id, city_id, company_id)
);

CREATE INDEX IF NOT EXISTS idx_prospects_status ON prospects (lifecycle_status);

CREATE TRIGGER IF NOT EXISTS trg_prospects_updated
AFTER UPDATE ON prospects
FOR EACH ROW
BEGIN
    UPDATE prospects
    SET updated_at = CURRENT_TIMESTAMP
    WHERE gat_id = OLD.gat_id AND city_id = OLD.city_id AND company_id = OLD.company_id;
END;

-- =======================
-- Contact Grid (belongs to either parent)
-- =======================
CREATE TABLE IF NOT EXISTS contact_grid (
    gat_id        TEXT NOT NULL,
    city_id       TEXT NOT NULL,
    company_id    TEXT NOT NULL,
    contact_id    INTEGER PRIMARY KEY AUTOINCREMENT,
    contact_name  TEXT NOT NULL,
    role_title    TEXT,
    email         TEXT,
    phone         TEXT,
    notes         TEXT,
    created_at    TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at    TEXT DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_contacts_company ON contact_grid (gat_id, city_id, company_id);
CREATE INDEX IF NOT EXISTS idx_contacts_name    ON contact_grid (contact_name);

CREATE TRIGGER IF NOT EXISTS trg_contacts_updated
AFTER UPDATE ON contact_grid
FOR EACH ROW
BEGIN
    UPDATE contact_grid
    SET updated_at = CURRENT_TIMESTAMP
    WHERE contact_id = OLD.contact_id;
END;

-- Guard: contacts must belong to Prospects OR Sponsors
CREATE TRIGGER IF NOT EXISTS trg_contacts_guard_insert
BEFORE INSERT ON contact_grid
FOR EACH ROW
BEGIN
    SELECT CASE
        WHEN NOT EXISTS (SELECT 1 FROM prospects WHERE gat_id=NEW.gat_id AND city_id=NEW.city_id AND company_id=NEW.company_id)
         AND NOT EXISTS (SELECT 1 FROM sponsors  WHERE gat_id=NEW.gat_id AND city_id=NEW.city_id AND company_id=NEW.company_id)
        THEN RAISE(ABORT,'No matching Prospects or Sponsors parent for contact_grid row')
    END;
END;

CREATE TRIGGER IF NOT EXISTS trg_contacts_guard_update_company
BEFORE UPDATE OF gat_id, city_id, company_id ON contact_grid
FOR EACH ROW
BEGIN
    SELECT CASE
        WHEN NOT EXISTS (SELECT 1 FROM prospects WHERE gat_id=NEW.gat_id AND city_id=NEW.city_id AND company_id=NEW.company_id)
         AND NOT EXISTS (SELECT 1 FROM sponsors  WHERE gat_id=NEW.gat_id AND city_id=NEW.city_id AND company_id=NEW.company_id)
        THEN RAISE(ABORT,'Updated contact no longer linked to any parent (Prospects or Sponsors)')
    END;
END;

-- Cascade delete contacts only when the LAST parent disappears
CREATE TRIGGER IF NOT EXISTS trg_contacts_cascade_on_prospect_delete
AFTER DELETE ON prospects
FOR EACH ROW
BEGIN
    DELETE FROM contact_grid
    WHERE gat_id=OLD.gat_id AND city_id=OLD.city_id AND company_id=OLD.company_id
      AND NOT EXISTS (SELECT 1 FROM sponsors WHERE gat_id=OLD.gat_id AND city_id=OLD.city_id AND company_id=OLD.company_id);
END;

CREATE TRIGGER IF NOT EXISTS trg_contacts_cascade_on_sponsor_delete
AFTER DELETE ON sponsors
FOR EACH ROW
BEGIN
    DELETE FROM contact_grid
    WHERE gat_id=OLD.gat_id AND city_id=OLD.city_id AND company_id=OLD.company_id
      AND NOT EXISTS (SELECT 1 FROM prospects WHERE gat_id=OLD.gat_id AND city_id=OLD.city_id AND company_id=OLD.company_id);
END;

-- =======================
-- Views
-- =======================
CREATE VIEW IF NOT EXISTS ALL_COMPANIES AS
SELECT gat_id, city_id, company_id,
       prospect_name AS company_name,
       'prospect'    AS company_type,
       lifecycle_status,
       created_at, updated_at
FROM prospects
UNION ALL
SELECT gat_id, city_id, company_id,
       sponsor_name  AS company_name,
       'sponsor'     AS company_type,
       'n/a'         AS lifecycle_status,
       created_at, updated_at
FROM sponsors;

CREATE VIEW IF NOT EXISTS ACTIVE_PROSPECTS AS
SELECT *
FROM prospects
WHERE lifecycle_status='active';

-- =======================
-- SAMPLE WORKFLOWS
-- =======================

-- 1) Insert a new Prospect (active)
-- INSERT INTO prospects (gat_id, city_id, company_id, prospect_name)
-- VALUES ('GAT001','DE-BER-1101','COMP123','Berlin Medical Supplies');

-- 2) Add contacts (valid while company exists in Prospects or Sponsors)
-- INSERT INTO contact_grid (gat_id, city_id, company_id, contact_name, role_title, email, phone)
-- VALUES ('GAT001','DE-BER-1101','COMP123','Dr. Anna Müller','Chief Medical Officer','anna.mueller@example.com','+49-30-1234567');

-- 3) Promote Prospect → Sponsor (Archive Prospect, DO NOT DELETE)
-- BEGIN TRANSACTION;
-- INSERT INTO sponsors (gat_id, city_id, company_id, sponsor_name, contract_date, expiration_date)
-- SELECT gat_id, city_id, company_id, prospect_name, DATE('now'), DATE('now','+1 year')
-- FROM prospects
-- WHERE gat_id='GAT001' AND city_id='DE-BER-1101' AND company_id='COMP123';
--
-- UPDATE prospects
-- SET lifecycle_status='archived', archived_at=DATE('now')
-- WHERE gat_id='GAT001' AND city_id='DE-BER-1101' AND company_id='COMP123';
-- COMMIT;

-- 4) Reopen an Archived Prospect (work in sales again)
-- UPDATE prospects
-- SET lifecycle_status='active', archived_at=NULL
-- WHERE gat_id='GAT001' AND city_id='DE-BER-1101' AND company_id='COMP123' AND lifecycle_status='archived';

-- 5) Lists
-- SELECT * FROM ACTIVE_PROSPECTS WHERE city_id='DE-BER-1101';
-- SELECT * FROM ALL_COMPANIES     WHERE gat_id='GAT001' AND company_id='COMP123';

-- =========================================================
-- End of setup_mini.sql
-- =========================================================
