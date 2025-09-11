// init-db.js
// Usage: node init-db.js setup_mini.sql
const fs = require('fs');
const path = require('path');
const Database = require('better-sqlite3');

const dbPath = process.env.LS_MINI_DB_PATH || path.resolve(process.cwd(), 'mini.db');
const sqlPath = process.argv[2] || path.resolve(process.cwd(), 'setup_mini.sql');

if (!fs.existsSync(sqlPath)) {
  console.error('SQL file not found:', sqlPath);
  process.exit(1);
}

const sql = fs.readFileSync(sqlPath, 'utf8');
const db = new Database(dbPath);
db.exec(sql);

const tables = db.prepare("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;").all();
console.log('Initialized DB at:', dbPath);
console.log('Tables:', tables.map(t => t.name));
