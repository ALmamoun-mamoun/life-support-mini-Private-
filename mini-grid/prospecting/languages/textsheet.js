
/*! textsheet.js — load phrases from a CSV and pick a language column.
   Usage in a page:
     <script src="languages/textsheet.js"></script>
     <script>
       TextSheet.load('languages/strings.csv','en').then(dict => {
         document.title = TextSheet.t(dict, 'app_title');
       });
     </script>
*/
(function (global) {
  function splitCsvLine(line) {
    // minimal CSV parsing: commas, quotes, escaped quotes ("")
    var out = [], cur = '', q = false;
    for (var i = 0; i < line.length; i++) {
      var ch = line[i];
      if (q) {
        if (ch === '"' && line[i + 1] === '"') { cur += '"'; i++; }
        else if (ch === '"') { q = false; }
        else { cur += ch; }
      } else {
        if (ch === ',') { out.push(cur); cur = ''; }
        else if (ch === '"') { q = true; }
        else { cur += ch; }
      }
    }
    out.push(cur);
    return out;
  }

  function parseCsv(text) {
    var lines = text.replace(/\r\n/g, '\n').replace(/\r/g, '\n').split('\n');
    // drop blank trailing lines
    while (lines.length && !lines[lines.length - 1].trim()) lines.pop();
    if (!lines.length) return { headers: [], rows: [] };
    var headers = splitCsvLine(lines[0]).map(function (h) { return h.trim(); });
    var rows = [];
    for (var i = 1; i < lines.length; i++) {
      if (!lines[i].trim()) continue;
      rows.push(splitCsvLine(lines[i]));
    }
    return { headers: headers, rows: rows };
  }

  function indexOfHeader(headers, name) {
    for (var i = 0; i < headers.length; i++) if (headers[i] === name) return i;
    return -1;
  }

  function buildDict(csv, lang) {
    var hiKey = indexOfHeader(csv.headers, 'key');
    var hiLang = indexOfHeader(csv.headers, lang);
    if (hiLang < 0) {
      // fallback order: en_plain, en, first non-key column
      hiLang = indexOfHeader(csv.headers, 'en_plain');
      if (hiLang < 0) hiLang = indexOfHeader(csv.headers, 'en');
      if (hiLang < 0) hiLang = (csv.headers[0] === 'key' ? 1 : 0);
    }
    var dict = {};
    for (var i = 0; i < csv.rows.length; i++) {
      var row = csv.rows[i];
      var k = row[hiKey] || '';
      var v = row[hiLang] || '';
      dict[k] = v;
    }
    return dict;
  }

  function format(str, params) {
    if (!params) return str;
    return String(str).replace(/\{(\w+)\}/g, function (_, name) {
      return (name in params) ? params[name] : '{' + name + '}';
    });
  }

  function load(path, lang) {
    return fetch(path, { cache: 'no-store' })
      .then(function (r) {
        if (!r.ok) throw new Error('HTTP ' + r.status);
        return r.text();
      })
      .then(function (text) {
        var csv = parseCsv(text);
        var dict = buildDict(csv, lang || 'en');
        return dict;
      });
  }

  function t(dict, key, params) {
    var s = (dict && dict[key]) || '';
    return format(s, params);
  }

  global.TextSheet = { load: load, t: t };
})(window);
