import sqlite3
db = r'E:\life-support-mini-grid\db\mini.db'
con = sqlite3.connect(db); con.row_factory = sqlite3.Row
cur = con.cursor()

cols = {r['name'] for r in cur.execute('PRAGMA table_info(prospects)')}
city = 'city_id' if 'city_id' in cols else ('city_code' if 'city_code' in cols else None)
name = 'prospect_name' if 'prospect_name' in cols else ('company_name' if 'company_name' in cols else None)
web  = 'website_url' if 'website_url' in cols else ('website' if 'website' in cols else None)

if not city or not name:
    print({'ok': False, 'error': 'prospects_missing_columns', 'have': sorted(cols)})
    raise SystemExit(1)

web_expr = f"COALESCE(p.{web}, '')" if web else "''"

sql = f'''
DROP VIEW IF EXISTS grid_companies;
CREATE VIEW grid_companies AS
SELECT
  p.gat_id,
  p.{city}      AS city_id,
  p.company_id,
  (p.gat_id || '~' || p.{city} || '~' || p.company_id) AS guid,
  p.{name}      AS company_name,
  {web_expr}    AS website_url
FROM prospects AS p
ORDER BY p.{name} COLLATE NOCASE;
'''
cur.executescript(sql)
con.commit(); con.close()
print({'ok': True, 'city_col': city, 'name_col': name, 'web_used': (web or '')})
