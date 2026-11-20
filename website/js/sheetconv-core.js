/*
 * XPENC SheetConv — the pure conversion core.
 *
 * Turns spreadsheet rows (array of arrays, as SheetJS hands them back with
 * `header: 1, raw: true`) into a backup file the app's
 * "Settings > Backup > Import from file" accepts — i.e. exactly the shape
 * `AppDatabase.exportAll()` writes and `AppDatabase.importAll()` reads
 * (lib/data/database.dart). Rows are inserted there by raw snake_case column
 * name, so every NOT NULL column without a default must be present here or the
 * whole import rolls back.
 *
 * No DOM, no network. Runs in the browser (window.SheetConv) and in Node
 * (module.exports) so the output can be checked against the real importer
 * (test/sheetconv_import_test.dart).
 */
(function (root) {
  'use strict';

  // Must match AppDatabase.backupFormatVersion / schemaVersion. importAll
  // refuses a formatVersion newer than its own; schemaVersion is informational.
  var FORMAT_VERSION = 1;
  var SCHEMA_VERSION = 77;

  var MODES = ['basic', 'medium', 'pro'];

  // ── Field catalogue ───────────────────────────────────────────────────────
  // `hints` are matched against a normalised header (lowercase, letters and
  // digits only). Exact matches win over "contains" matches.
  var FIELDS = [
    { key: 'date', label: 'Date', mode: 'basic', required: true,
      hints: ['date', 'txndate', 'transactiondate', 'valuedate', 'postingdate', 'day', 'dt', 'when', 'on'] },
    { key: 'income', label: 'Income (money in)', mode: 'basic',
      hints: ['income', 'credit', 'credits', 'deposit', 'deposits', 'received', 'moneyin', 'in', 'cr', 'earning', 'earnings', 'inflow', 'creditamount', 'depositamount'] },
    { key: 'expense', label: 'Expense (money out)', mode: 'basic',
      hints: ['expense', 'expenses', 'debit', 'debits', 'withdrawal', 'withdrawals', 'spent', 'spend', 'spending', 'paid', 'moneyout', 'out', 'dr', 'expenditure', 'outflow', 'debitamount', 'withdrawalamount'] },
    { key: 'amount', label: 'Amount (one column)', mode: 'basic',
      hints: ['amount', 'amt', 'value', 'sum', 'rs', 'inr', 'price', 'cost', 'total', 'money'] },
    { key: 'type', label: 'Type (Income / Expense / …)', mode: 'basic',
      hints: ['type', 'txntype', 'transactiontype', 'kind', 'incomeexpense', 'drcr', 'crdr', 'direction', 'flow', 'nature'] },
    { key: 'category', label: 'Category', mode: 'basic',
      hints: ['category', 'categories', 'cat', 'head', 'expensehead', 'purpose', 'group', 'subcategory', 'section'] },
    { key: 'note', label: 'Note / Description', mode: 'basic',
      hints: ['note', 'notes', 'description', 'desc', 'details', 'detail', 'narration', 'particulars', 'remarks', 'remark', 'memo', 'item', 'items', 'comment', 'comments', 'reason', 'title'] },
    { key: 'account', label: 'Account', mode: 'medium',
      hints: ['account', 'accounts', 'acct', 'accountname', 'bank', 'wallet', 'paidfrom', 'paymentmode', 'paymentmethod', 'mode', 'source', 'paidvia', 'via', 'method', 'fromaccount', 'from'] },
    { key: 'toAccount', label: 'To account (transfers)', mode: 'medium',
      hints: ['toaccount', 'to', 'destination', 'transferto', 'target', 'toacct'] },
    { key: 'payee', label: 'Payee / Merchant', mode: 'medium',
      hints: ['payee', 'merchant', 'shop', 'vendor', 'store', 'paidto', 'party', 'partyname', 'receiver', 'beneficiary', 'place'] },
    { key: 'tags', label: 'Tags', mode: 'medium',
      hints: ['tags', 'tag', 'labels', 'label', 'hashtags'] },
    { key: 'person', label: 'Person (lent / borrowed)', mode: 'pro',
      hints: ['person', 'people', 'friend', 'lentto', 'borrowedfrom', 'contact', 'who', 'withwhom', 'personname', 'lender', 'borrower'] },
  ];

  var FIELD_BY_KEY = {};
  FIELDS.forEach(function (f) { FIELD_BY_KEY[f.key] = f; });

  function modeRank(m) { return MODES.indexOf(m); }

  /** Fields a mode can map (a mode includes every lower mode's fields). */
  function fieldsForMode(mode) {
    return FIELDS.filter(function (f) { return modeRank(f.mode) <= modeRank(mode); });
  }

  // Row kinds a Type-column value can map to, and which mode unlocks each.
  var KINDS = [
    { key: 'income', label: 'Income', mode: 'basic' },
    { key: 'expense', label: 'Expense', mode: 'basic' },
    { key: 'transfer', label: 'Transfer between accounts', mode: 'medium' },
    { key: 'personOut', label: 'Gave money to a person (lent / repaid)', mode: 'pro' },
    { key: 'personIn', label: 'Got money from a person (borrowed / got back)', mode: 'pro' },
    { key: 'auto', label: 'Decide from the amount', mode: 'basic' },
    { key: 'skip', label: 'Skip these rows', mode: 'basic' },
  ];

  function kindsForMode(mode) {
    return KINDS.filter(function (k) { return modeRank(k.mode) <= modeRank(mode); });
  }

  // ── Small helpers ─────────────────────────────────────────────────────────

  function norm(s) {
    return String(s == null ? '' : s).toLowerCase().replace(/[^a-z0-9]+/g, '');
  }

  function cellText(v) {
    if (v == null) return '';
    if (v instanceof Date) return isoDate(v);
    return String(v).replace(/\s+/g, ' ').trim();
  }

  /** A header cell as a label: a word Excel wrapped with a hyphen at a
   *  manual line break ("Entertain-\nment") is joined back up. */
  function headerText(v) {
    return cellText(String(v == null ? '' : v).replace(/(\w)-[ \t]*\r?\n\s*(\w)/g, '$1$2'));
  }

  function isEmptyRow(row) {
    if (!row) return true;
    for (var i = 0; i < row.length; i++) if (cellText(row[i]) !== '') return false;
    return true;
  }

  function pad2(n) { return (n < 10 ? '0' : '') + n; }

  function isoDate(d) {
    return d.getFullYear() + '-' + pad2(d.getMonth() + 1) + '-' + pad2(d.getDate());
  }

  /** A local wall-clock ISO string with no zone — what Dart's
   *  `DateTime.toIso8601String()` writes for a local DateTime, and what
   *  `DateTime.parse` reads back as local time. Noon keeps a date-only value
   *  on the right calendar day whatever the phone's timezone does. */
  function isoLocal(y, m, d, hh, mm, ss) {
    return y + '-' + pad2(m) + '-' + pad2(d) + 'T' + pad2(hh == null ? 12 : hh) + ':' +
      pad2(mm || 0) + ':' + pad2(ss || 0) + '.000';
  }

  function nowIsoLocal(now) {
    var d = now || new Date();
    return isoLocal(d.getFullYear(), d.getMonth() + 1, d.getDate(), d.getHours(), d.getMinutes(), d.getSeconds());
  }

  function clip(s, max) {
    s = String(s || '').trim();
    return s.length > max ? s.slice(0, max).trim() : s;
  }

  function titleCase(s) {
    return s.replace(/\S+/g, function (w) {
      return w.length <= 3 && w === w.toUpperCase() ? w : w.charAt(0).toUpperCase() + w.slice(1);
    });
  }

  // ── Amounts ───────────────────────────────────────────────────────────────

  /**
   * "₹1,23,456.50", "(500)", "-500", "500 Dr", "Rs. 20", 20 → a number
   * (negative = money out), or null when the cell holds no amount at all.
   */
  function parseAmount(v) {
    if (v == null || v === '') return null;
    if (typeof v === 'number') return isFinite(v) ? v : null;
    if (typeof v === 'boolean' || v instanceof Date) return null;
    var s = String(v).trim();
    if (!s || s === '-' || s === '—') return null;
    var neg = false;
    if (/^\(.*\)$/.test(s)) { neg = true; s = s.slice(1, -1).trim(); }
    var suffix = s.match(/\s*\b(dr|cr|debit|credit)\.?$/i);
    if (suffix) {
      if (/^d/i.test(suffix[1])) neg = !neg;
      s = s.slice(0, suffix.index).trim();
    }
    s = s.replace(/(rs\.?|inr|usd|eur|gbp|aed)/gi, '').replace(/[₹$€£¥\s,'_]/g, '');
    if (s.charAt(0) === '-') { neg = !neg; s = s.slice(1); }
    else if (s.charAt(s.length - 1) === '-') { neg = !neg; s = s.slice(0, -1); }
    if (s.charAt(0) === '+') s = s.slice(1);
    if (!/^(\d+\.?\d*|\.\d+)$/.test(s)) return null;
    var n = parseFloat(s);
    if (!isFinite(n)) return null;
    return neg ? -n : n;
  }

  /** Money is stored as integer paise (minor units) — never a float. */
  function toPaise(n) { return Math.round(Math.abs(n) * 100); }

  // ── Dates ─────────────────────────────────────────────────────────────────

  var MONTHS = { jan: 1, feb: 2, mar: 3, apr: 4, may: 5, jun: 6, jul: 7, aug: 8, sep: 9, sept: 9, oct: 10, nov: 11, dec: 12 };

  function monthFromName(s) {
    s = String(s).toLowerCase();
    return MONTHS[s] || MONTHS[s.slice(0, 3)] || null;
  }

  function fullYear(y) {
    y = parseInt(y, 10);
    if (y >= 100) return y;
    var cur = new Date().getFullYear() % 100;
    return y <= cur + 1 ? 2000 + y : 1900 + y;
  }

  function validYmd(y, m, d) {
    if (!(y >= 1900 && y <= 2200 && m >= 1 && m <= 12 && d >= 1 && d <= 31)) return false;
    var t = new Date(y, m - 1, d);
    return t.getFullYear() === y && t.getMonth() === m - 1 && t.getDate() === d;
  }

  /** Excel's serial day number (1900 system) → {y,m,d,hh,mm,ss}. The
   *  1899-12-30 epoch absorbs Lotus's fake 29 Feb 1900 for every real date. */
  function fromSerial(n) {
    if (!(n > 0 && n < 2958466)) return null;
    var ms = Math.round((n * 86400) ) * 1000;
    var t = new Date(Date.UTC(1899, 11, 30) + ms);
    return { y: t.getUTCFullYear(), m: t.getUTCMonth() + 1, d: t.getUTCDate(),
      hh: t.getUTCHours(), mm: t.getUTCMinutes(), ss: t.getUTCSeconds() };
  }

  function parseTime(rest) {
    var t = String(rest || '').match(/(\d{1,2}):(\d{2})(?::(\d{2}))?\s*(am|pm)?/i);
    if (!t) return null;
    var hh = parseInt(t[1], 10), mm = parseInt(t[2], 10), ss = t[3] ? parseInt(t[3], 10) : 0;
    if (t[4]) { var pm = /p/i.test(t[4]); if (hh === 12) hh = pm ? 12 : 0; else if (pm) hh += 12; }
    if (hh > 23 || mm > 59 || ss > 59) return null;
    return { hh: hh, mm: mm, ss: ss };
  }

  /**
   * Any date a hand-kept sheet is likely to hold → {y,m,d,hh,mm,ss} or null.
   * `order` resolves "03/04/2026": 'dmy' (India/UK) or 'mdy' (US).
   */
  function parseDate(v, order) {
    if (v == null || v === '') return null;
    if (v instanceof Date) {
      if (isNaN(v.getTime())) return null;
      return { y: v.getFullYear(), m: v.getMonth() + 1, d: v.getDate(), hh: v.getHours(), mm: v.getMinutes(), ss: v.getSeconds() };
    }
    if (typeof v === 'number') return fromSerial(v);
    var s = String(v).trim();
    if (!s) return null;
    if (/^\d{5}(\.\d+)?$/.test(s)) return fromSerial(parseFloat(s));
    var m, y, mo, d;
    // 2026-01-31, 2026/1/31, 2026.01.31
    if ((m = s.match(/^(\d{4})[-\/.](\d{1,2})[-\/.](\d{1,2})(.*)$/))) {
      y = +m[1]; mo = +m[2]; d = +m[3];
    // 31/01/2026, 01-31-26
    } else if ((m = s.match(/^(\d{1,2})[-\/.](\d{1,2})[-\/.](\d{2,4})(.*)$/))) {
      var a = +m[1], b = +m[2];
      y = fullYear(m[3]);
      if (order === 'mdy') { mo = a; d = b; } else { d = a; mo = b; }
      // A value that only fits the other order (13/01 under mdy) — take it.
      if (mo > 12 && d <= 12) { var tmp = mo; mo = d; d = tmp; }
    // 31 Jan 2026, 31-Jan-26, 31st January, 2026
    } else if ((m = s.match(/^(\d{1,2})(?:st|nd|rd|th)?[\s\-\/.,]*([A-Za-z]{3,9})[\s\-\/.,]*(\d{2,4})(.*)$/))) {
      d = +m[1]; mo = monthFromName(m[2]); y = fullYear(m[3]);
    // Jan 31, 2026 / January 31 2026
    } else if ((m = s.match(/^([A-Za-z]{3,9})[\s\-\/.,]*(\d{1,2})(?:st|nd|rd|th)?[\s,\-\/.]+(\d{2,4})(.*)$/))) {
      mo = monthFromName(m[1]); d = +m[2]; y = fullYear(m[3]);
    } else {
      return null;
    }
    if (!validYmd(y, mo, d)) return null;
    var t = parseTime(m[4]);
    return { y: y, m: mo, d: d, hh: t ? t.hh : null, mm: t ? t.mm : 0, ss: t ? t.ss : 0 };
  }

  /** Looks at every "a/b/yyyy" string in the date column to decide DMY vs MDY. */
  function detectDateOrder(values) {
    var dmy = 0, mdy = 0, numeric = 0;
    values.forEach(function (v) {
      if (typeof v !== 'string') return;
      var m = v.trim().match(/^(\d{1,2})[-\/.](\d{1,2})[-\/.](\d{2,4})/);
      if (!m) return;
      numeric++;
      if (+m[1] > 12) dmy++;
      if (+m[2] > 12) mdy++;
    });
    if (mdy > dmy) return { order: 'mdy', sure: true, numeric: numeric };
    if (dmy > 0) return { order: 'dmy', sure: true, numeric: numeric };
    return { order: 'dmy', sure: numeric === 0, numeric: numeric };
  }

  // ── Header detection & column mapping ─────────────────────────────────────

  function looksLikeData(v) {
    if (typeof v === 'number' || v instanceof Date) return true;
    var s = cellText(v);
    return parseAmount(s) !== null || parseDate(s, 'dmy') !== null;
  }

  /** The row (within the first 25) that looks most like a header: the most
   *  text cells, ideally ones matching known field names. Title rows such as
   *  "My Expenses 2026" above the real header lose to it. */
  function detectHeaderRow(aoa) {
    var best = 0, bestScore = -1;
    var limit = Math.min(aoa.length, 25);
    for (var r = 0; r < limit; r++) {
      var row = aoa[r] || [];
      var text = 0, known = 0;
      for (var c = 0; c < row.length; c++) {
        var s = cellText(row[c]);
        if (!s) continue;
        if (!looksLikeData(row[c])) {
          text++;
          if (matchScore(norm(s)) > 0) known++;
        }
      }
      var score = text + known * 2;
      if (text >= 2 && score > bestScore) { bestScore = score; best = r; }
    }
    return best;
  }

  function matchScore(h, field) {
    var list = field ? [field] : FIELDS;
    var top = 0;
    list.forEach(function (f) {
      f.hints.forEach(function (hint) {
        if (h === hint) top = Math.max(top, 3);
        else if (hint.length >= 4 && h.indexOf(hint) !== -1) top = Math.max(top, 2);
        else if (h.length >= 4 && hint.indexOf(h) === 0) top = Math.max(top, 1);
      });
    });
    return top;
  }

  /** Best-effort column → field mapping over ALL fields (the mode filter is
   *  applied later), each column used at most once. {field: colIndex | -1}. */
  function autoMap(headers) {
    var candidates = [];
    headers.forEach(function (h, col) {
      var n = norm(h);
      if (!n) return;
      FIELDS.forEach(function (f, order) {
        var s = matchScore(n, f);
        if (s > 0) candidates.push({ field: f.key, col: col, score: s, order: order });
      });
    });
    candidates.sort(function (a, b) { return b.score - a.score || a.order - b.order || a.col - b.col; });
    var mapping = {}, usedCols = {};
    FIELDS.forEach(function (f) { mapping[f.key] = -1; });
    candidates.forEach(function (c) {
      if (mapping[c.field] !== -1 || usedCols[c.col]) return;
      mapping[c.field] = c.col;
      usedCols[c.col] = true;
    });
    // One amount shape at a time: separate in/out columns beat a lone
    // "Amount", except that "Amount" + "Type" is its own complete shape.
    if ((mapping.income !== -1 || mapping.expense !== -1) && mapping.amount !== -1 && mapping.type !== -1) {
      mapping.income = -1; mapping.expense = -1;
    }
    return mapping;
  }

  /** Columns = one column per category (the amount sits under its
   *  category's header); split = separate Income/Expense columns;
   *  typed = Amount + Type; signed = Amount alone (negative = expense). */
  function amountLayout(mapping, columnRoles) {
    if (hasRoles(columnRoles)) return 'columns';
    if (mapping.income >= 0 || mapping.expense >= 0) return 'split';
    if (mapping.amount >= 0) return mapping.type >= 0 ? 'typed' : 'signed';
    return 'none';
  }

  function hasRoles(roles) {
    if (!roles) return false;
    for (var k in roles) if (roles[k] && roles[k] !== 'ignore') return true;
    return false;
  }

  // ── One column per category ("wide" sheets) ───────────────────────────────
  //
  // Plenty of hand-kept sheets look like: Date | Description | Groceries |
  // Fuel | Eating Out | … | Bank Interest — every category is its own column
  // and a row's amount sits under the category it belongs to.

  /** Columns whose filled cells are (almost) all amounts. Empty columns count
   *  too — a category nobody has spent in yet is still a category. */
  function numericColumns(rows, width, exclude) {
    var out = [];
    for (var c = 0; c < width; c++) {
      if (exclude && exclude[c]) continue;
      var filled = 0, nums = 0;
      for (var r = 0; r < rows.length; r++) {
        var v = (rows[r] || [])[c];
        if (v == null || v === '') continue;
        filled++;
        if (parseAmount(v) !== null) nums++;
      }
      if (filled === 0 || nums / filled >= 0.8) out.push({ col: c, filled: nums });
    }
    return out;
  }

  var ROLES = [
    { key: 'expense', label: 'Expense category' },
    { key: 'income', label: 'Income category' },
    { key: 'trip', label: 'Trip / event → Travel + tag' },
    { key: 'ignore', label: 'Ignore this column' },
  ];

  var INCOME_RE = /income|interest|dividend|refund|salary|wage|profit|cash ?back|rebate|reimburs|pension|bonus|earning|received|\breturns?\b|tax back|allowance|stipend/i;
  // Totals, running balances and a second-currency copy of an amount
  // ("USD Amount") would double-count if imported.
  var IGNORE_RE = /^(sub ?)?totals?\b|\bgrand total\b|\bbalance\b|\brunning\b|\bamount\b|\b(usd|eur|gbp|nzd|cad|sgd|jpy|aud|inr|foreign|fx)\b/i;
  var TRIP_RE = /\b(19|20)\d{2}\b/;

  /**
   * Guesses what each category column is. `colors` (optional) holds each
   * header cell's fill: sheets like this often colour income headers
   * differently, so a colour group that is mostly income-named columns
   * makes every column in it income — even "Dog Sitting".
   */
  function guessColumnRoles(headers, cols, colors) {
    var roles = {};
    var incomeGroup = {};
    if (colors) {
      var groups = {};
      cols.forEach(function (c) {
        var key = colors[c] || '';
        (groups[key] = groups[key] || []).push(c);
      });
      var keys = Object.keys(groups);
      if (keys.length >= 2) {
        keys.forEach(function (k) {
          var g = groups[k];
          var hits = g.filter(function (c) { return INCOME_RE.test(headerText(headers[c])); }).length;
          if (k && hits >= 1 && hits / g.length >= 0.4) g.forEach(function (c) { incomeGroup[c] = true; });
        });
      }
    }
    cols.forEach(function (c) {
      var h = headerText(headers[c]);
      if (!h || /^column [a-z]+$/i.test(h) || IGNORE_RE.test(h)) roles[c] = 'ignore';
      else if (incomeGroup[c] || INCOME_RE.test(h)) roles[c] = 'income';
      else if (TRIP_RE.test(h)) roles[c] = 'trip';
      else roles[c] = 'expense';
    });
    return roles;
  }

  /** Is this a one-column-per-category sheet? Returns the detected roles, or
   *  null. Five or more amount columns is far past what a plain ledger has
   *  (Debit / Credit / Balance). */
  function detectWide(headers, rows, mapping, colors) {
    var exclude = {};
    ['date', 'note'].forEach(function (k) { if (mapping[k] >= 0) exclude[mapping[k]] = true; });
    var numeric = numericColumns(rows, headers.length, exclude).filter(function (x) {
      return headerText(headers[x.col]) !== '';
    });
    var used = numeric.filter(function (x) { return x.filled > 0; });
    if (numeric.length < 5 || used.length < 2) return null;
    return guessColumnRoles(headers, numeric.map(function (x) { return x.col; }), colors);
  }

  // ── Type column values ────────────────────────────────────────────────────

  function guessKind(value) {
    var s = String(value || '').toLowerCase().trim();
    var n = norm(s);
    if (!n) return 'auto';
    if (/(^|\b)(lent|lend|lending|gave|given|give|loangiven|repaid to|paid back|payback)/.test(s) || /^(lent|lend|gave|given|loangiven)/.test(n)) return 'personOut';
    if (/(borrow|got back|received back|returned|loan taken|loantaken|repayment received)/.test(s)) return 'personIn';
    if (/(transfer|trf|self|contra|move|moved|withdraw to cash|atm)/.test(s)) return 'transfer';
    if (/^(income|credit|cr|in|inflow|received|receipt|deposit|salary|earning|earned|revenue|refund|plus|c)$/.test(n) || s === '+' || /(income|credit|deposit|received|earning)/.test(s)) return 'income';
    if (/^(expense|expenses|debit|dr|out|outflow|spent|spend|paid|payment|purchase|withdrawal|bill|minus|d|exp)$/.test(n) || s === '-' || /(expense|debit|spent|paid|purchase|withdraw|payment)/.test(s)) return 'expense';
    return 'auto';
  }

  function typeValues(rows, col) {
    var seen = {}, out = [];
    if (col < 0) return out;
    rows.forEach(function (r) {
      var v = cellText(r[col]);
      var k = v.toLowerCase();
      if (!v) return;
      if (!seen[k]) { seen[k] = { value: v, count: 0 }; out.push(seen[k]); }
      seen[k].count++;
    });
    return out.sort(function (a, b) { return b.count - a.count; });
  }

  // ── Analysis & mode suggestion ────────────────────────────────────────────

  function distinct(rows, col) {
    var set = {};
    if (col < 0) return [];
    rows.forEach(function (r) {
      var v = cellText(r[col]);
      if (v) set[v.toLowerCase()] = v;
    });
    return Object.keys(set).map(function (k) { return set[k]; });
  }

  /**
   * Reads the sheet and recommends a mode, with human-readable reasons.
   * Signals: how many accounts, whether transfers/people appear, extras
   * (payee/tags) and sheer size.
   */
  function analyze(headers, rows, colors) {
    var mapping = autoMap(headers);
    var columnRoles = mapping.date >= 0 ? detectWide(headers, rows, mapping, colors) : null;
    if (columnRoles) {
      // Headers like "Other Income", "USD Amount" or "Bank Interest" are
      // categories here, not the Income / Amount / Account fields — only
      // text columns keep a field.
      var roleCols = {};
      Object.keys(columnRoles).forEach(function (c) { roleCols[c] = true; });
      FIELDS.forEach(function (f) {
        var keep = ['date', 'note', 'account', 'payee', 'tags', 'person'].indexOf(f.key) !== -1;
        if (!keep || roleCols[mapping[f.key]]) mapping[f.key] = -1;
      });
    }
    // A "Type"-ish header whose values aren't recognisable kinds (say it
    // holds "Monthly" / "Fixed") isn't a type column — drop it rather than
    // let it steer every row.
    if (mapping.type >= 0) {
      var known = 0, total = 0;
      typeValues(rows, mapping.type).forEach(function (t) {
        total += t.count;
        if (guessKind(t.value) !== 'auto') known += t.count;
      });
      if (total === 0 || known / total < 0.5) mapping.type = -1;
    }
    var accounts = distinct(rows, mapping.account);
    var toAccounts = distinct(rows, mapping.toAccount);
    var persons = distinct(rows, mapping.person);
    var categories = distinct(rows, mapping.category);
    var tVals = typeValues(rows, mapping.type);
    var kindCounts = { transfer: 0, personOut: 0, personIn: 0 };
    tVals.forEach(function (t) {
      var k = guessKind(t.value);
      if (kindCounts[k] != null) kindCounts[k] += t.count;
    });
    var personRows = kindCounts.personOut + kindCounts.personIn;
    var dateInfo = detectDateOrder(mapping.date >= 0 ? rows.map(function (r) { return r[mapping.date]; }) : []);

    var reasons = [];
    var suggestion = 'basic';
    function bump(mode, why) {
      if (modeRank(mode) > modeRank(suggestion)) suggestion = mode;
      reasons.push({ mode: mode, text: why });
    }

    if (personRows > 0 || (persons.length > 0 && mapping.type >= 0)) {
      bump('pro', personRows > 0
        ? personRows + ' row' + (personRows === 1 ? '' : 's') + ' look like money lent or borrowed — Pro keeps a ledger per person.'
        : 'A person column was found — Pro tracks who owes whom.');
    }
    if (accounts.length >= 2) bump('medium', accounts.length + ' different accounts (' + accounts.slice(0, 3).join(', ') + (accounts.length > 3 ? '…' : '') + ') — Medium keeps a real balance for each.');
    if (kindCounts.transfer > 0 || toAccounts.length > 0) bump('medium', 'Transfers between accounts found — they need Medium so they are not counted as spending.');
    if (mapping.payee >= 0) bump('medium', 'A payee / merchant column was found.');
    if (mapping.tags >= 0) bump('medium', 'A tags column was found.');
    if (columnRoles) {
      var roleCount = { expense: 0, income: 0, trip: 0, ignore: 0 };
      var firstTrip = null;
      Object.keys(columnRoles).forEach(function (c) {
        roleCount[columnRoles[c]]++;
        if (columnRoles[c] === 'trip' && firstTrip == null) firstTrip = c;
      });
      reasons.push({ mode: 'basic', text: 'Each category has its own column (' + (roleCount.expense + roleCount.income + roleCount.trip) +
        ' of them) — every filled cell becomes one transaction in that column\'s category.' });
      if (roleCount.trip) bump('medium', roleCount.trip + ' trip / event columns (like "' + clip(headerText(headers[firstTrip]), 30) +
        '") — Medium imports them as Travel with a tag per trip, instead of ' + roleCount.trip + ' extra categories.');
      categories = { length: roleCount.expense + roleCount.income };
    }
    if (rows.length > 1500 || categories.length > 20) bump('medium', rows.length + ' rows across ' + categories.length + ' categories — budgets and stats in Medium will help at this size.');
    if (suggestion === 'basic') {
      reasons.push({ mode: 'basic', text: accounts.length === 1
        ? 'One account and plain income / expense rows — Basic keeps it simple.'
        : 'Plain income / expense rows with no accounts — Basic keeps it simple.' });
    }

    return {
      mapping: mapping,
      columnRoles: columnRoles || {},
      layout: amountLayout(mapping, columnRoles),
      suggestion: suggestion,
      reasons: reasons,
      dateOrder: dateInfo.order,
      dateOrderSure: dateInfo.sure,
      stats: {
        rows: rows.length,
        accounts: accounts.length,
        categories: categories.length,
        persons: persons.length,
        transfers: kindCounts.transfer,
        personRows: personRows,
      },
    };
  }

  // ── Accounts, categories, icons ───────────────────────────────────────────

  var PALETTE = [0xFF3B82F6, 0xFFF97316, 0xFF16A34A, 0xFFA855F7, 0xFFEC4899, 0xFF06B6D4, 0xFFEAB308,
    0xFFEF4444, 0xFF14B8A6, 0xFF8B5CF6, 0xFF84CC16, 0xFF0EA5E9, 0xFFF43F5E, 0xFF64748B, 0xFF78716C];

  var ACCOUNT_TYPES = [
    { key: 'cash', label: 'Cash', icon: 'cash' },
    { key: 'bank', label: 'Bank', icon: 'bank' },
    { key: 'card', label: 'Credit card', icon: 'card' },
    { key: 'prepaidBalance', label: 'Prepaid / Wallet', icon: 'prepaid_balance' },
    { key: 'payLater', label: 'Pay later', icon: 'pay_later' },
  ];
  var ACCOUNT_ICON = {};
  ACCOUNT_TYPES.forEach(function (t) { ACCOUNT_ICON[t.key] = t.icon; });

  function guessAccountType(name) {
    var s = String(name || '').toLowerCase();
    if (/\bcash\b|hand|pocket|petty/.test(s)) return 'cash';
    if (/pay ?later|lazypay|simpl|postpaid|bnpl/.test(s)) return 'payLater';
    if (/credit|\bcard\b|\bcc\b|amex|visa|mastercard|rupay card/.test(s)) return 'card';
    if (/wallet|paytm|amazon ?pay|prepaid|mobikwik|freecharge|gift ?card|meal ?card|sodexo|pluxee/.test(s)) return 'prepaidBalance';
    return 'bank';
  }

  // The app's own starting categories (AppDatabase._seedDefaultAccountsAndCategories),
  // so an imported ledger looks like a fresh install plus the sheet's own.
  var DEFAULT_CATEGORIES = [
    ['Salary', 'income', 'salary', 0xFF16A34A], ['Profit', 'income', 'profit', 0xFF0EA5E9],
    ['Gift', 'income', 'gift', 0xFFA855F7], ['Cash', 'income', 'cash', 0xFF22C55E],
    ['Interest', 'income', 'interest', 0xFF14B8A6], ['Refund', 'income', 'refund', 0xFF64748B],
    ['Rent', 'expense', 'rent', 0xFFDC2626], ['Food', 'expense', 'food', 0xFFF97316],
    ['Groceries', 'expense', 'groceries', 0xFF84CC16], ['Transport', 'expense', 'transport', 0xFF3B82F6],
    ['Bills', 'expense', 'bills', 0xFF8B5CF6], ['Shopping', 'expense', 'shopping', 0xFFEC4899],
    ['Health', 'expense', 'health', 0xFFEF4444], ['Entertainment', 'expense', 'entertainment', 0xFF06B6D4],
    ['EMI', 'expense', 'emi', 0xFF78716C],
  ];

  // Keyword → icon key. Every key here exists in lib/core/app_icons.dart.
  var ICON_RULES = [
    [/salary|wage|payroll|stipend/, 'salary'], [/interest|fd\b|dividend/, 'interest'], [/refund|cashback|reimburse/, 'refund'],
    [/gift|bonus/, 'gift'], [/profit|business|freelanc|side ?hustle|sale/, 'profit'],
    [/rent|lease/, 'rent'], [/grocer|vegetable|fruit|kirana|mart|milk|dairy/, 'groceries'],
    [/coffee|tea|chai/, 'coffee'], [/cafe|canteen/, 'cafe'], [/swiggy|zomato|fast ?food|snack/, 'fastfood'],
    [/breakfast/, 'breakfast'], [/lunch/, 'lunch'], [/dinner/, 'dinner'], [/pizza/, 'pizza'],
    [/bakery|bread/, 'bakery'], [/ice ?cream|dessert|sweet/, 'icecream'], [/bar|alcohol|beer|drink|liquor/, 'bar'],
    [/food|restaurant|dining|eat|meal|hotel food/, 'food'],
    [/fuel|petrol|diesel|cng/, 'fuel'], [/taxi|cab|uber|ola|rapido|auto ?rickshaw/, 'taxi'],
    [/train|railway|irctc/, 'train'], [/metro|subway/, 'subway'], [/parking|toll|fastag/, 'parking'],
    [/car ?service|car ?repair|mechanic/, 'car_repair'], [/\bcar\b/, 'car'], [/bike|cycle/, 'bike'], [/scooter|two ?wheeler/, 'scooter'],
    [/bus|transport|travel ?local|commute/, 'transport'], [/flight|trip|travel|vacation|holiday|tour/, 'travel'],
    [/hotel|stay|airbnb|oyo/, 'hotel'],
    [/electric|power|light bill|mseb|bescom/, 'electricity'], [/water/, 'water'], [/wifi|internet|broadband|jio|airtel|fiber/, 'wifi'],
    [/gas|lpg|cylinder/, 'gas'], [/mobile|phone|recharge/, 'phone'], [/bill|utility|utilities/, 'bills'],
    [/netflix|prime|hotstar|spotify|youtube|subscription|ott|stream/, 'streaming'],
    [/movie|cinema|theatre|theater|show/, 'theater'], [/game|gaming/, 'gaming'], [/music|concert/, 'music'],
    [/entertain|fun|party|outing/, 'entertainment'],
    [/doctor|hospital|clinic|consult/, 'doctor'], [/medicine|pharma|chemist|medical/, 'pharmacy'],
    [/gym|fitness|yoga|sport/, 'fitness'], [/salon|spa|parlour|parlor|haircut|grooming/, 'spa'], [/health/, 'health'],
    [/insurance|lic|premium/, 'insurance'], [/tax|gst|tds/, 'tax'], [/emi|loan|installment|instalment/, 'emi'],
    [/school|college|fees|tuition|course|education|exam|book/, 'education'],
    [/cloth|apparel|dress|shoe|fashion/, 'clothing'], [/jewel|gold|silver/, 'jewelry'],
    [/amazon|flipkart|myntra|meesho|shopping|shop/, 'shopping'], [/electronic|gadget|laptop/, 'laptop'],
    [/house|home|maintenance|society/, 'house'], [/repair|plumb/, 'repair'], [/clean|maid|laundry|dhobi/, 'cleaning'],
    [/furniture/, 'furniture'], [/baby|kid|child/, 'baby'], [/family|parents|home send/, 'family'],
    [/pet|dog|cat food/, 'pets'], [/donat|charity|temple|church|mosque|puja|pooja/, 'donation'],
    [/invest|sip|mutual|stock|share|saving/, 'savings'], [/transfer/, 'transfer'],
  ];

  function guessCategoryIcon(name) {
    var s = String(name || '').toLowerCase();
    for (var i = 0; i < ICON_RULES.length; i++) if (ICON_RULES[i][0].test(s)) return ICON_RULES[i][1];
    return 'other';
  }

  function splitCategoryPath(raw) {
    var parts = String(raw).split(/\s*(?:>|›|»|::|:)\s*/).map(function (p) { return p.trim(); }).filter(Boolean);
    return parts.length ? parts : [String(raw).trim()];
  }

  function splitTags(raw) {
    return String(raw || '').split(/[,;|#]+/).map(function (t) { return t.trim(); }).filter(Boolean);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  /**
   * Collects the account names the sheet uses (for the account editor).
   */
  function collectAccounts(rows, mapping, mode, defaultAccountName) {
    var names = {};
    var list = [];
    function add(n) {
      n = clip(n, 60);
      if (!n) return;
      var k = n.toLowerCase();
      if (!names[k]) { names[k] = true; list.push(n); }
    }
    add(defaultAccountName || 'Cash');
    if (modeRank(mode) >= modeRank('medium')) {
      if (mapping.account >= 0) rows.forEach(function (r) { add(cellText(r[mapping.account])); });
      if (mapping.toAccount >= 0) rows.forEach(function (r) { add(cellText(r[mapping.toAccount])); });
    }
    return list;
  }

  /**
   * The conversion itself.
   *
   * opts = {
   *   headers, rows,               // rows = data rows only (after the header)
   *   firstRowNumber,              // sheet row number of rows[0], for messages
   *   mode: 'basic'|'medium'|'pro',
   *   mapping: {field: col|-1},
   *   typeMap: {lowercased type value: kind},
   *   dateOrder: 'dmy'|'mdy',
   *   currency: 'INR',
   *   defaultAccountName: 'Cash',
   *   accountSettings: {lowercased name: {type, opening}},
   *   subcategories: bool,        // pro: "Food > Dining" → parent/child
   *   now: Date,
   * }
   * → { backup, summary }
   */
  function build(opts) {
    var mode = MODES.indexOf(opts.mode) >= 0 ? opts.mode : 'basic';
    var allowed = {};
    fieldsForMode(mode).forEach(function (f) { allowed[f.key] = true; });
    var map = {};
    FIELDS.forEach(function (f) {
      var c = opts.mapping && opts.mapping[f.key];
      map[f.key] = allowed[f.key] && typeof c === 'number' && c >= 0 ? c : -1;
    });
    var columnRoles = {};
    Object.keys(opts.columnRoles || {}).forEach(function (c) {
      var r = opts.columnRoles[c];
      if (r && r !== 'ignore') columnRoles[c] = r;
    });
    var layout = amountLayout(map, columnRoles);
    var roleCols = Object.keys(columnRoles).map(Number).filter(function (c) { return c !== map.date && c !== map.note; });
    var headersList = opts.headers || [];
    var typeMap = opts.typeMap || {};
    var allowedKinds = {};
    kindsForMode(mode).forEach(function (k) { allowedKinds[k.key] = true; });
    var dateOrder = opts.dateOrder === 'mdy' ? 'mdy' : 'dmy';
    var rows = opts.rows || [];
    var firstRow = opts.firstRowNumber || 2;
    var now = nowIsoLocal(opts.now);
    var defaultAccountName = clip(opts.defaultAccountName || 'Cash', 60) || 'Cash';
    var accountSettings = opts.accountSettings || {};
    var multiAccount = modeRank(mode) >= modeRank('medium');

    var out = {
      accounts: [], categories: [], transactions: [], persons: [], personEntries: [],
      tags: [], transactionTags: [],
    };
    var skipped = [];
    function skip(i, why) { skipped.push({ row: firstRow + i, reason: why }); }

    if (map.date < 0) throw new Error('Pick the column that holds the date.');
    if (layout === 'none') throw new Error('Pick an Income / Expense column, or an Amount column.');
    var tagsAllowed = modeRank(mode) >= modeRank('medium');

    // Accounts
    var accountIdByKey = {};
    function accountId(name) {
      name = clip(name, 60) || defaultAccountName;
      var key = name.toLowerCase();
      if (accountIdByKey[key]) return accountIdByKey[key];
      var s = accountSettings[key] || {};
      var type = s.type || (key === defaultAccountName.toLowerCase() && opts.defaultAccountType ? opts.defaultAccountType : guessAccountType(name));
      if (!ACCOUNT_ICON[type]) type = 'bank';
      var opening = toSignedPaise(s.opening);
      var id = out.accounts.length + 1;
      var row = {
        id: id, name: name, type: type, color_value: PALETTE[(id - 1) % PALETTE.length],
        icon_key: ACCOUNT_ICON[type], opening_balance: opening, current_balance: opening,
        is_archived: false, sort_order: id - 1, created_at: now,
      };
      if (type === 'card') row.card_kind = 'credit';
      out.accounts.push(row);
      accountIdByKey[key] = id;
      return id;
    }
    function toSignedPaise(v) {
      var n = typeof v === 'number' ? v : parseAmount(v);
      return n == null ? 0 : Math.round(n * 100);
    }
    var defaultAccountId = accountId(defaultAccountName);

    // Categories
    var categoryIdByKey = {};
    var sortByKind = { income: 0, expense: 0 };
    function addCategory(name, kind, icon, color, parentId) {
      var id = out.categories.length + 1;
      out.categories.push({
        id: id, name: name, kind: kind, color_value: color, icon_key: icon,
        is_archived: false, sort_order: sortByKind[kind]++, parent_id: parentId == null ? null : parentId,
      });
      return id;
    }
    DEFAULT_CATEGORIES.forEach(function (c) {
      categoryIdByKey[c[1] + '|' + c[0].toLowerCase()] = addCategory(c[0], c[1], c[2], c[3], null);
    });
    var colorCursor = 0;
    function categoryId(raw, kind) {
      var text = clip(raw, 200);
      if (!text) text = kind === 'income' ? 'Other income' : 'Other';
      var path = opts.subcategories && mode === 'pro' ? splitCategoryPath(text) : [text];
      path = path.slice(0, 2).map(function (p) { return clip(p, 40); }).filter(Boolean);
      var parent = null, id = null;
      for (var i = 0; i < path.length; i++) {
        var key = kind + '|' + (parent == null ? '' : parent + '/') + path[i].toLowerCase();
        // A top-level name that matches a default category reuses it.
        if (parent == null) key = kind + '|' + path[i].toLowerCase();
        id = categoryIdByKey[key];
        if (!id) {
          var icon = guessCategoryIcon(path[i]);
          if (icon === 'other' && parent != null) icon = out.categories[parent - 1].icon_key;
          id = addCategory(path[i], kind, icon, PALETTE[colorCursor++ % PALETTE.length], parent);
          categoryIdByKey[key] = id;
        }
        parent = id;
      }
      return id;
    }

    // Persons
    var personIdByKey = {};
    function personId(name) {
      name = clip(name, 60);
      var key = name.toLowerCase();
      if (personIdByKey[key]) return personIdByKey[key];
      var id = out.persons.length + 1;
      out.persons.push({ id: id, name: name, is_archived: false, is_settled: false, created_at: now });
      personIdByKey[key] = id;
      return id;
    }

    // Tags
    var tagIdByKey = {};
    function tagId(name) {
      name = clip(name, 30);
      var key = name.toLowerCase();
      if (tagIdByKey[key]) return tagIdByKey[key];
      var id = out.tags.length + 1;
      out.tags.push({ id: id, name: name, color_value: PALETTE[(id + 4) % PALETTE.length] });
      tagIdByKey[key] = id;
      return id;
    }

    var totals = { income: 0, expense: 0, transfer: 0, personOut: 0, personIn: 0 };
    var counts = { income: 0, expense: 0, transfer: 0, personOut: 0, personIn: 0 };
    var minDate = null, maxDate = null;

    function pushTx(i, tx, tagsRaw, extraTag) {
      tx.id = out.transactions.length + 1;
      tx.created_at = now;
      tx.updated_at = now;
      out.transactions.push(tx);
      totals[tx.type] += tx.amount;
      counts[tx.type]++;
      var tagList = (tagsRaw && map.tags >= 0 ? splitTags(tagsRaw) : []).concat(extraTag ? [extraTag] : []);
      if (tagList.length) {
        var seen = {};
        tagList.forEach(function (t) {
          var id = tagId(t);
          if (seen[id]) return;
          seen[id] = true;
          out.transactionTags.push({ transaction_id: tx.id, tag_id: id });
        });
      }
      return tx.id;
    }

    rows.forEach(function (row, i) {
      if (isEmptyRow(row)) return;
      var rawDate = row[map.date];
      var dt = parseDate(rawDate, dateOrder);
      if (!dt) {
        var shown = cellText(rawDate);
        skip(i, shown ? 'Could not read the date "' + clip(shown, 30) + '"' : 'No date');
        return;
      }
      var dateOnly = dt.hh == null || (dt.hh === 0 && !dt.mm && !dt.ss);
      var dateIso = dateOnly ? isoLocal(dt.y, dt.m, dt.d) : isoLocal(dt.y, dt.m, dt.d, dt.hh, dt.mm, dt.ss);
      var dayKey = dt.y + '-' + pad2(dt.m) + '-' + pad2(dt.d);

      var note = map.note >= 0 ? clip(cellText(row[map.note]), 500) : '';
      var catRaw = map.category >= 0 ? cellText(row[map.category]) : '';
      var payee = map.payee >= 0 ? clip(cellText(row[map.payee]), 80) : '';
      var tagsRaw = map.tags >= 0 ? cellText(row[map.tags]) : '';
      var accId = multiAccount && map.account >= 0 ? accountId(cellText(row[map.account]) || defaultAccountName) : defaultAccountId;

      // Which kind(s) of movement this row is, with an absolute paise amount.
      var typeRaw = map.type >= 0 ? cellText(row[map.type]) : '';
      var forced = typeRaw ? (typeMap[typeRaw.toLowerCase()] || guessKind(typeRaw)) : 'auto';
      if (forced !== 'auto' && !allowedKinds[forced]) {
        skip(i, '"' + clip(typeRaw, 24) + '" rows need ' + (forced === 'transfer' ? 'Medium' : 'Pro') + ' mode');
        return;
      }
      if (forced === 'skip') { skip(i, 'Type "' + clip(typeRaw, 24) + '" is set to skip'); return; }

      var moves = []; // [{kind, paise, cat?, tag?}]
      if (layout === 'columns') {
        // Every filled cell is its own transaction. A negative under an
        // expense column is a refund: money in, same category name.
        roleCols.forEach(function (c) {
          var v = parseAmount(row[c]);
          if (!v) return;
          var role = columnRoles[c];
          var name = clip(headerText(headersList[c]), 200) || 'Other';
          var base = role === 'income' ? 'income' : 'expense';
          var kind = v > 0 ? base : (base === 'income' ? 'expense' : 'income');
          if (role === 'trip' && tagsAllowed) moves.push({ kind: kind, paise: toPaise(v), cat: 'Travel', tag: name });
          else moves.push({ kind: kind, paise: toPaise(v), cat: name });
        });
      } else if (layout === 'split') {
        var inc = map.income >= 0 ? parseAmount(row[map.income]) : null;
        var exp = map.expense >= 0 ? parseAmount(row[map.expense]) : null;
        if (forced === 'auto' || forced === 'income' || forced === 'expense') {
          // The column decides the direction, not the sign: "-450" or
          // "(450)" under Expense is just how many sheets write money out.
          if (inc) moves.push({ kind: 'income', paise: toPaise(inc) });
          if (exp) moves.push({ kind: 'expense', paise: toPaise(exp) });
        } else {
          var any = inc || exp;
          if (any) moves.push({ kind: forced, paise: toPaise(any) });
        }
      } else {
        var amt = parseAmount(row[map.amount]);
        if (amt) {
          var kind = forced === 'auto' ? (amt < 0 ? 'expense' : 'income') : forced;
          moves.push({ kind: kind, paise: toPaise(amt) });
        }
      }
      moves = moves.filter(function (m) { return m.paise > 0; });
      if (!moves.length) { skip(i, 'No amount'); return; }

      var ok = false;
      moves.forEach(function (m) {
        if (m.kind === 'income' || m.kind === 'expense') {
          pushTx(i, {
            type: m.kind, amount: m.paise, account_id: accId, to_account_id: null,
            category_id: categoryId(m.cat != null ? m.cat : catRaw, m.kind), person_id: null, date: dateIso,
            note: note || null, payee: payee || null,
          }, tagsRaw, m.tag);
          ok = true;
        } else if (m.kind === 'transfer') {
          var toName = map.toAccount >= 0 ? cellText(row[map.toAccount]) : '';
          if (!toName) { skip(i, 'Transfer with no "To account"'); return; }
          var toId = accountId(toName);
          if (toId === accId) { skip(i, 'Transfer to the same account'); return; }
          pushTx(i, {
            type: 'transfer', amount: m.paise, account_id: accId, to_account_id: toId,
            category_id: null, person_id: null, date: dateIso, note: note || null, payee: null,
          }, tagsRaw);
          ok = true;
        } else { // personOut / personIn
          var who = map.person >= 0 ? cellText(row[map.person]) : '';
          if (!who && payee) who = payee;
          if (!who) { skip(i, 'Lent / borrowed row with no person'); return; }
          var pid = personId(who);
          var pname = out.persons[pid - 1].name;
          var txId = pushTx(i, {
            type: m.kind, amount: m.paise, account_id: accId, to_account_id: null,
            category_id: null, person_id: pid, date: dateIso,
            note: note || (m.kind === 'personOut' ? 'Gave to ' + pname : 'Received from ' + pname),
            payee: null,
          }, tagsRaw);
          // Mirrors AppDatabase.addPersonEntry: money out → they owe me.
          out.personEntries.push({
            id: out.personEntries.length + 1, person_id: pid,
            direction: m.kind === 'personOut' ? 'theyOwe' : 'iOwe',
            amount: m.paise, date: dateIso, note: note || null,
            account_id: accId, transaction_id: txId, created_at: now,
          });
          ok = true;
        }
      });
      if (ok) {
        if (!minDate || dayKey < minDate) minDate = dayKey;
        if (!maxDate || dayKey > maxDate) maxDate = dayKey;
      }
    });

    // Balance the app will compute on import (AppDatabase.recalculateBalances):
    // opening balance + every flow. Written here too so the file is coherent
    // even before that recalculation runs.
    var bal = {};
    out.accounts.forEach(function (a) { bal[a.id] = a.opening_balance; });
    out.transactions.forEach(function (t) {
      if (t.type === 'income' || t.type === 'personIn') bal[t.account_id] += t.amount;
      else if (t.type === 'expense' || t.type === 'personOut') bal[t.account_id] -= t.amount;
      else if (t.type === 'transfer') { bal[t.account_id] -= t.amount; bal[t.to_account_id] += t.amount; }
    });
    out.accounts.forEach(function (a) { a.current_balance = bal[a.id]; });

    // People: what each person owes net (positive = they owe you).
    var personNet = {};
    out.personEntries.forEach(function (e) {
      personNet[e.person_id] = (personNet[e.person_id] || 0) + (e.direction === 'theyOwe' ? e.amount : -e.amount);
    });

    var backup = {
      formatVersion: FORMAT_VERSION,
      schemaVersion: SCHEMA_VERSION,
      exportedAt: now,
      generator: 'xpenc.in/sheetconv',
      accounts: out.accounts,
      currencyRates: [],
      categories: out.categories,
      recurringRules: [],
      transactions: out.transactions,
      budgets: [],
      persons: out.persons,
      personEntries: out.personEntries,
      reminders: [],
      merchantRules: [],
      // importAll wipes sender_rules and never reseeds them, so carry the
      // app's shipped bank templates (kSeedSenderRules) across.
      senderRules: SEED_SENDER_RULES.map(function (r, i) {
        return { id: i + 1, sender_pattern: r[0], bank_name: r[1], enabled: true };
      }),
      tags: out.tags,
      transactionTags: out.transactionTags,
      recurringRuleTags: [],
      tagGroups: [],
      tagGroupTags: [],
      transactionSplits: [],
      transactionLinks: [],
      goalDetails: [],
      creditCardDetails: [],
      allocations: [],
      shoppingLists: [],
      shoppingItems: [],
      pendingTxns: [],
      budgetAlerts: [],
      settings: [{
        id: 1,
        currency_code: /^[A-Z]{3}$/.test(opts.currency || '') ? opts.currency : 'INR',
        onboarded: true,
        app_mode: mode,
      }],
    };

    return {
      backup: backup,
      summary: {
        mode: mode,
        layout: layout,
        transactions: out.transactions.length,
        counts: counts,
        totals: totals,
        skipped: skipped,
        accounts: out.accounts.map(function (a) {
          return { name: a.name, type: a.type, opening: a.opening_balance, balance: a.current_balance };
        }),
        categories: out.categories.length - DEFAULT_CATEGORIES.length,
        persons: out.persons.map(function (p) { return { name: p.name, net: personNet[p.id] || 0 }; }),
        tags: out.tags.length,
        firstDate: minDate,
        lastDate: maxDate,
      },
    };
  }

  var SEED_SENDER_RULES = [
    ['IPPB', 'India Post Payments Bank'], ['IPPBNK', 'India Post Payments Bank'], ['YESBNK', 'Yes Bank'],
    ['HDFCBK', 'HDFC Bank'], ['ICICIB', 'ICICI Bank'], ['SBIINB', 'State Bank of India'],
    ['SBIUPI', 'State Bank of India'], ['AXISBK', 'Axis Bank'], ['KOTAKB', 'Kotak Mahindra Bank'],
    ['PNBSMS', 'Punjab National Bank'],
  ];

  /** Same name scheme the app gives its own backups (BackupService.backupFileName). */
  function backupFileName(d) {
    d = d || new Date();
    return pad2(d.getDate()) + pad2(d.getMonth() + 1) + pad2(d.getFullYear() % 100) + 'XPENCEBACKUP.json';
  }

  var api = {
    FORMAT_VERSION: FORMAT_VERSION,
    SCHEMA_VERSION: SCHEMA_VERSION,
    MODES: MODES,
    FIELDS: FIELDS,
    FIELD_BY_KEY: FIELD_BY_KEY,
    KINDS: KINDS,
    ACCOUNT_TYPES: ACCOUNT_TYPES,
    fieldsForMode: fieldsForMode,
    kindsForMode: kindsForMode,
    modeRank: modeRank,
    norm: norm,
    cellText: cellText,
    isEmptyRow: isEmptyRow,
    headerText: headerText,
    ROLES: ROLES,
    numericColumns: numericColumns,
    guessColumnRoles: guessColumnRoles,
    hasRoles: hasRoles,
    parseAmount: parseAmount,
    parseDate: parseDate,
    detectDateOrder: detectDateOrder,
    detectHeaderRow: detectHeaderRow,
    autoMap: autoMap,
    amountLayout: amountLayout,
    guessKind: guessKind,
    typeValues: typeValues,
    analyze: analyze,
    guessAccountType: guessAccountType,
    collectAccounts: collectAccounts,
    build: build,
    backupFileName: backupFileName,
    titleCase: titleCase,
  };

  if (typeof module !== 'undefined' && module.exports) module.exports = api;
  else root.SheetConv = api;
})(typeof window !== 'undefined' ? window : this);
