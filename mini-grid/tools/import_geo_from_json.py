import argparse, json, os, sqlite3

p = argparse.ArgumentParser()
p.add_argument("--db", required=True)
p.add_argument("--countries", required=True)
p.add_argument("--cities", default="")
a = p.parse_args()

def load_json(path):
    if not path or not os.path.exists(path): return None
    with open(path, "r", encoding="utf-8-sig") as f:
        return json.load(f)

con = sqlite3.connect(a.db)
cur = con.cursor()

# Ensure tables & unique indexes exist (matches our upserts)
cur.executescript("""
PRAGMA foreign_keys=ON;
CREATE TABLE IF NOT EXISTS country(
  id INTEGER PRIMARY KEY,
  cc TEXT NOT NULL COLLATE NOCASE CHECK (length(cc)=2),
  name TEXT NOT NULL
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_country_cc ON country(cc COLLATE NOCASE);

CREATE TABLE IF NOT EXISTS city(
  id INTEGER PRIMARY KEY,
  country_id INTEGER NOT NULL REFERENCES country(id) ON DELETE CASCADE,
  name TEXT NOT NULL COLLATE NOCASE,
  abbr TEXT NOT NULL COLLATE NOCASE,
  CHECK(length(abbr) BETWEEN 2 AND 8)
);
CREATE UNIQUE INDEX IF NOT EXISTS ux_city_country_name ON city(country_id, name COLLATE NOCASE);
CREATE UNIQUE INDEX IF NOT EXISTS ux_city_country_abbr ON city(country_id, abbr COLLATE NOCASE);
""")

# --- import countries ---
raw_c = load_json(a.countries)
count_c = 0
if raw_c is not None:
    if isinstance(raw_c, list):
        items = [(str(x.get("cc","")).upper(), str(x.get("name",""))) for x in raw_c if x]
    else:  # map {"SA":"Saudi Arabia",...}
        items = [(k.upper(), str(v)) for k,v in (raw_c or {}).items()]
    for cc, name in items:
        if len(cc)==2 and name:
            cur.execute("""INSERT INTO country(cc,name) VALUES(?,?)
                           ON CONFLICT(cc) DO UPDATE SET name=excluded.name""", (cc, name))
            count_c += 1

# --- import cities (optional) ---
raw_ct = load_json(a.cities)
count_ct = 0
if raw_ct:
    rows = []
    if isinstance(raw_ct, list):
        for x in raw_ct:
            rows.append((str(x.get("cc","")).upper(), str(x.get("name","")).upper(), str(x.get("abbr","")).upper()))
    else:  # {"SA":{"RIYADH":"RYD",...}, ...}
        for cc, m in (raw_ct or {}).items():
            for name, abbr in (m or {}).items():
                rows.append((str(cc).upper(), str(name).upper(), str(abbr).upper()))
    for cc, name, abbr in rows:
        if not (cc and name and abbr): continue
        cur.execute("SELECT id FROM country WHERE UPPER(cc)=UPPER(?)", (cc,))
        r = cur.fetchone()
        if r:
            cur.execute("""INSERT INTO city(country_id,name,abbr) VALUES(?,?,?)
                           ON CONFLICT(country_id,name) DO UPDATE SET abbr=excluded.abbr""",
                        (r[0], name, abbr))
            count_ct += 1

con.commit()

# sample output
cur.execute("SELECT cc,name FROM country ORDER BY name LIMIT 8")
print("Countries sample:", cur.fetchall())
cur.execute("""SELECT c.cc, ci.name, ci.abbr
              FROM country c JOIN city ci ON ci.country_id=c.id
              ORDER BY c.cc, ci.name LIMIT 8""")
print("Cities sample   :", cur.fetchall())

con.close()
print(f"Imported/updated {count_c} countries, {count_ct} cities.")
