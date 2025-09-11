-- ============================================
-- GEO CODES (Countries & Cities) — migration
-- Targets: SQLite (mini.db)
-- ============================================

PRAGMA foreign_keys = ON;

-- ---------
-- COUNTRIES
-- id: PK, cc: 2-letter code (unique, case-insensitive), name
-- ---------
CREATE TABLE IF NOT EXISTS country (
  id          INTEGER PRIMARY KEY,
  cc          TEXT    NOT NULL COLLATE NOCASE CHECK (length(cc) = 2),
  name        TEXT    NOT NULL,
  created_at  TEXT    NOT NULL DEFAULT (datetime('now')),
  updated_at  TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_country_cc ON country(UPPER(cc));

CREATE TRIGGER IF NOT EXISTS trg_country_updated
AFTER UPDATE OF cc, name ON country
FOR EACH ROW BEGIN
  UPDATE country SET updated_at = datetime('now') WHERE id = NEW.id;
END;

-- ----
-- CITIES
-- id: PK, country_id FK -> country.id, name, abbr
-- Enforce uniqueness per country (name, abbr) case-insensitive.
-- ----
CREATE TABLE IF NOT EXISTS city (
  id          INTEGER PRIMARY KEY,
  country_id  INTEGER NOT NULL REFERENCES country(id) ON DELETE CASCADE,
  name        TEXT    NOT NULL COLLATE NOCASE,
  abbr        TEXT    NOT NULL COLLATE NOCASE,
  created_at  TEXT    NOT NULL DEFAULT (datetime('now')),
  updated_at  TEXT    NOT NULL DEFAULT (datetime('now')),
  CHECK (length(abbr) BETWEEN 2 AND 8)
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_city_country_name ON city(country_id, UPPER(name));
CREATE UNIQUE INDEX IF NOT EXISTS ux_city_country_abbr ON city(country_id, UPPER(abbr));

CREATE TRIGGER IF NOT EXISTS trg_city_updated
AFTER UPDATE OF name, abbr ON city
FOR EACH ROW BEGIN
  UPDATE city SET updated_at = datetime('now') WHERE id = NEW.id;
END;

-- ----------
-- CONVENIENCE VIEWS
-- ----------
-- v_city_codes: join with country + show all fields you care about
CREATE VIEW IF NOT EXISTS v_city_codes AS
SELECT
  c.id          AS country_id,
  c.cc          AS country_cc,
  c.name        AS country_name,
  ci.id         AS city_id,
  ci.name       AS city_name,
  ci.abbr       AS city_abbr
FROM country c
JOIN city    ci ON ci.country_id = c.id;

-- v_city_by_cc: quick list of cities for a given country code
CREATE VIEW IF NOT EXISTS v_city_by_cc AS
SELECT
  c.cc          AS country_cc,
  ci.name       AS city_name,
  ci.abbr       AS city_abbr
FROM country c
JOIN city    ci ON ci.country_id = c.id;

-- ----------
-- UPSERT HELPERS (examples)
-- ----------
-- Upsert a country by cc (2-letter)
-- Usage: bind :cc, :name
-- INSERT INTO country(cc, name) VALUES(:cc, :name)
-- ON CONFLICT(cc) DO UPDATE SET name = excluded.name;

-- Upsert a city by (country cc + city name)
-- Usage: bind :cc, :city, :abbr
-- INSERT INTO city(country_id, name, abbr)
-- SELECT id, :city, :abbr FROM country WHERE UPPER(cc) = UPPER(:cc)
-- ON CONFLICT(country_id, name) DO UPDATE SET abbr = excluded.abbr;

-- ----------
-- SEED (optional — edit as you like)
-- ----------
INSERT INTO country(cc, name) VALUES
 ('SA','Saudi Arabia'),
 ('JO','Jordan'),
 ('AE','United Arab Emirates'),
 ('US','United States')
ON CONFLICT(cc) DO UPDATE SET name=excluded.name;

-- Cities (examples)
INSERT INTO city(country_id, name, abbr)
SELECT id, 'RIYADH', 'RYD' FROM country WHERE cc='SA'
ON CONFLICT(country_id, name) DO UPDATE SET abbr=excluded.abbr;

INSERT INTO city(country_id, name, abbr)
SELECT id, 'JEDDAH', 'JED' FROM country WHERE cc='SA'
ON CONFLICT(country_id, name) DO UPDATE SET abbr=excluded.abbr;

INSERT INTO city(country_id, name, abbr)
SELECT id, 'AMMAN', 'AMM' FROM country WHERE cc='JO'
ON CONFLICT(country_id, name) DO UPDATE SET abbr=excluded.abbr;

INSERT INTO city(country_id, name, abbr)
SELECT id, 'NEW YORK', 'NYC' FROM country WHERE cc='US'
ON CONFLICT(country_id, name) DO UPDATE SET abbr=excluded.abbr;

-- ============================================
-- END
-- ============================================
