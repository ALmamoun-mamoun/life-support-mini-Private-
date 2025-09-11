(() => {
  const API = 'http://127.0.0.1:3001';
  const el  = (id) => document.getElementById(id);

  // paths (relative to /prospecting/)
  const GEO_ROOT     = '../config';
  const COUNTRY_FILE = `${GEO_ROOT}/country_codes.json`;
  const CITY_FILE    = `${GEO_ROOT}/city_codes.json`;

  // caches
  let COUNTRIES = [];        // [{cc,name}]
  let CITY_MAP  = {};        // { "SA": { "RIYADH":"RYD", ... }, ... }

  // local additions for unknown cities (browser memory only)
  const LS_KEY = 'ls_city_abbrs';
  const loadCityLS = () => { try { return JSON.parse(localStorage.getItem(LS_KEY)) || {}; } catch { return {}; } };
  const saveCityLS = (m) => localStorage.setItem(LS_KEY, JSON.stringify(m));

  const statusName = (s) => ({0:'pending',1:'permitted',2:'held_elsewhere'})[s] ?? String(s);

  function ensureUrl(u) {
    const s = String(u || '').trim();
    if (!s) return '';
    if (/^https?:\/\//i.test(s)) return s;
    return 'https://' + s;
  }
  function hostFromUrl(u) {
    try {
      const url = new URL(ensureUrl(u));
      return url.hostname.replace(/^www\./i, '').toLowerCase();
    } catch {
      return String(u || '').trim().toLowerCase();
    }
  }

  // ---------- geo loading ----------
  function normalizeCountries(raw) {
    if (Array.isArray(raw)) return raw.map(x => ({ cc:String(x.cc||'').toUpperCase(), name:String(x.name||'') }));
    return Object.entries(raw || {}).map(([cc,name]) => ({ cc:cc.toUpperCase(), name:String(name||'') }));
  }
  async function loadGeo() {
    const [cRaw, cities] = await Promise.all([
	fetch('/geo/countries').then(r=>r.json()),
	Promise.resolve({}) // cities will be fetched per-country next step

    ]);
    COUNTRIES = normalizeCountries(cRaw).sort((a,b)=>a.name.localeCompare(b.name));
    CITY_MAP  = cities || {};
  }
  function populateCountries() {
    const sel = el('ls-country');
    sel.innerHTML = '<option value="">— choose —</option>' +
      COUNTRIES.map(c => `<option value="${c.cc}">${c.name}</option>`).join('');
  }
  function mergedCitiesForCC(cc) {
    const CC = String(cc||'').toUpperCase();
    const file = CITY_MAP?.[CC] || {};
    const mem  = loadCityLS()?.[CC] || {};
    const keys = Array.from(new Set([...Object.keys(file), ...Object.keys(mem)])).sort();
    return { keys, abbrOf:(CITY)=> (mem[CITY] || file[CITY] || '') };
  }
  function populateCities(cc) {
    const dl = el('ls-cities');
    const { keys } = mergedCitiesForCC(cc);
    dl.innerHTML = keys.map(k => `<option value="${k}"></option>`).join('');
  }

  // ---------- helpers ----------
  function setGatPreview(gat) {
    el('ls-gat').textContent = String(gat);
    updateRecordPreview();
  }
  function gatFromUI() {
    const hasParent = el('ls-has-parent').checked;
    if (!hasParent) return '0000';
    const raw = el('ls-parent-id').value.trim();
    return raw || ''; // validated elsewhere
  }
  function ccFromUI() {
    return (el('ls-cc').value || el('ls-country').value || '').toUpperCase();
  }
  function cityAbbrFromUI() {
    return (el('ls-cityabbr').value || '').toUpperCase();
  }
  function updateRecordPreview() {
    const cc   = ccFromUI() || 'CC';
    const abbr = cityAbbrFromUI() || 'CCC';
    const gat  = gatFromUI() || 'GAT';
    el('ls-record-preview').textContent = `???-${cc}-${abbr}-${gat}`;
  }

  function lookupOrAskCityAbbr(cc, city) {
    const CC   = String(cc || '').toUpperCase();
    const CITY = String(city || '').trim().toUpperCase();
    if (!CC || !CITY) return '';
    const { abbrOf } = mergedCitiesForCC(CC);
    const existing = abbrOf(CITY);
    if (existing) return String(existing).toUpperCase();

    // Ask once; enforce exactly 3 letters
    const proposed = CITY.replace(/[^A-Z]/g,'').slice(0,3).padEnd(3,'X');
    let ans = window.prompt(`3-letter city code for ${CITY} (${CC})`, proposed);
    if (!ans) return '';
    ans = String(ans).toUpperCase().trim();
    if (!/^[A-Z]{3}$/.test(ans)) { alert('City Abbr must be exactly 3 letters.'); return ''; }

    const mem = loadCityLS(); mem[CC] = mem[CC] || {}; mem[CC][CITY] = ans; saveCityLS(mem);
    return ans;
  }

  // Deterministic GUID (stable per country/city/host/name/parent-flag)
  async function makeGuid(hasParent, parentId, cc, cityAbbr, url, name) {
    const key = [
      hasParent ? 'child' : 'parent',
      String(parentId||'0000'),
      String(cc||''),
      String(cityAbbr||''),
      hostFromUrl(url||''),
      String(name||'')
    ].join('|').toUpperCase();
    const buf = new TextEncoder().encode(key);
    const hash = await crypto.subtle.digest('SHA-1', buf);
    const hex  = [...new Uint8Array(hash)].map(b => b.toString(16).padStart(2,'0')).join('');
    const h = hex.slice(0,32);
    return `${h.slice(0,8)}-${h.slice(8,12)}-${h.slice(12,16)}-${h.slice(16,20)}-${h.slice(20,32)}`;
  }

  // ---------- claim ----------
  async function claim() {
    const hasParent = el('ls-has-parent').checked;
    const parentId  = el('ls-parent-id').value.trim();
    const cc        = ccFromUI();
    const city      = el('ls-city').value;
    let   abbr      = cityAbbrFromUI();
    const name      = el('ls-name').value.trim();
    const url       = el('ls-url').value.trim();

    // validations
    if (hasParent) {
      if (!/^[0-9]+$/.test(parentId)) { alert('Parent Company ID must be numeric.'); return; }
    }
    if (!cc || !/^[A-Z]{2}$/.test(cc)) { alert('Country CC must be 2 letters.'); return; }
    if (!city) { alert('City is required.'); return; }
    if (!abbr) {
      abbr = lookupOrAskCityAbbr(cc, city);
      if (!abbr) return;
      el('ls-cityabbr').value = abbr;
    }
    if (!/^[A-Z]{3}$/.test(abbr)) { alert('City Abbr must be exactly 3 letters.'); return; }
    if (!name) { alert('Company / Branch Name is required.'); return; }
    if (!url)  { alert('Company URL is required.'); return; }

    const gat = hasParent ? parentId : '0000';
    setGatPreview(gat); // updates preview line

    el('ls-status').textContent = '…';

    const guid = await makeGuid(hasParent, parentId, cc, abbr, url, name);

    // build a clear note for Main to parse (all keys present)
    const note = [
      `name=${name}`,
      `host=${hostFromUrl(url)}`,
      `cc=${cc}`,
      `city=${String(city).toUpperCase()}`,
      `city_abbr=${abbr}`,
      `has_parent=${hasParent}`,
      `gat_id=${gat}`,
      `record_id_preview=???-${cc}-${abbr}-${gat}`
    ].join(' | ');

    try {
      const r = await fetch(`${API}/gatekeeping/upsert`, {
        method: 'POST',
        headers: {'Content-Type':'application/json'},
        body: JSON.stringify({
          entity_guid: guid,
          status: 'pending',
          source: 'mini',
          note
        })
      });
      const json = await r.json();
      el('ls-guid').textContent   = json.entity_guid || guid;
      el('ls-status').textContent = statusName(json.status);
    } catch (e) {
      console.error(e);
      el('ls-status').textContent = 'error';
      alert('Claim failed. See console.');
    }
  }

  // ---------- wiring ----------
  window.addEventListener('DOMContentLoaded', async () => {
    await loadGeo();
    populateCountries();

    // country change → set CC + repopulate city list + preview
    el('ls-country').addEventListener('change', () => {
      el('ls-cc').value = el('ls-country').value || '';
      populateCities(el('ls-cc').value);
      updateRecordPreview();
    });

    // manual CC edit allowed
    el('ls-cc').addEventListener('input', updateRecordPreview);

    // city change → try lookup abbr and enforce 3 letters
    el('ls-city').addEventListener('change', () => {
      const cc = ccFromUI();
      const city = el('ls-city').value;
      const found = lookupOrAskCityAbbr(cc, city);
      if (found) el('ls-cityabbr').value = found;
      updateRecordPreview();
    });

    // abbr typing → force uppercase & 3
    el('ls-cityabbr').addEventListener('input', () => {
      el('ls-cityabbr').value = el('ls-cityabbr').value.toUpperCase().replace(/[^A-Z]/g,'').slice(0,3);
      updateRecordPreview();
    });

    // parent toggle
    el('ls-has-parent').addEventListener('change', (e) => {
      const on = e.target.checked;
      el('ls-parent-row').style.display = on ? 'block' : 'none';
      if (!on) el('ls-parent-id').value = '';
      setGatPreview(gatFromUI() || (on ? '' : '0000'));
    });

    // parent id input
    el('ls-parent-id').addEventListener('input', () => {
      setGatPreview(gatFromUI());
    });

    // initial preview
    updateRecordPreview();
  });

  // expose
  window.lsClaim = claim;
})();
