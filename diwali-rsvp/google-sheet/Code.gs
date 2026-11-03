/**
 * Diwali Potluck RSVP → Google Sheet (+ email to host)
 *
 * Paste this into Extensions ▸ Apps Script of the RSVP Google Sheet,
 * then Deploy ▸ New deployment ▸ Web app (Execute as: Me, Who has access: Anyone).
 * Full steps: ../SETUP.md
 *
 * The sheet can be downloaded any time via File ▸ Download ▸ Microsoft Excel (.xlsx).
 */

const HOST_EMAIL = 'anvita8126@gmail.com';
// The host's RSVP spreadsheet:
// https://docs.google.com/spreadsheets/d/1G5hdZNG5Yye6JGH5cOXwhZnxP-gkgCg6nYNS9ceGR1U/edit
const SPREADSHEET_ID = '1G5hdZNG5Yye6JGH5cOXwhZnxP-gkgCg6nYNS9ceGR1U';
const SHEET_NAME = 'RSVPs';

// [form field, column heading] — order here = column order in the sheet
const COLUMNS = [
  ['_timestamp', 'Submitted at'],
  ['name', 'Name'],
  ['email', 'Email'],
  ['phone', 'Phone'],
  ['attending', 'Attending'],
  ['guests', 'Guests (incl. them)'],
  ['guestNames', 'Coming with'],
  ['category', 'Dish type'],
  ['dish', 'Dish name'],
  ['servings', 'Servings'],
  ['dishAlso', 'Dish is also'],
  ['allergens', 'Contains'],
  ['needs', 'Dish needs'],
  ['vegConfirm', 'Vegetarian confirmed'],
  ['games', 'Excited for (games)'],
  ['bringGame', 'Bringing along'],
  ['dietary', 'Own dietary needs'],
  ['help', 'Helping with'],
  ['song', 'Song request'],
  ['message', 'Message'],
];

function doPost(e) {
  const lock = LockService.getScriptLock();
  lock.waitLock(15000);
  try {
    const p = (e && e.parameter) || {};
    if (!p.name) return json_({ ok: false, error: 'Missing name' });

    const sheet = getSheet_();
    const row = COLUMNS.map(([key]) => (key === '_timestamp' ? new Date() : safe_(p[key])));
    sheet.appendRow(row);

    notifyHost_(p, sheet);
    return json_({ ok: true });
  } catch (err) {
    return json_({ ok: false, error: String(err) });
  } finally {
    lock.releaseLock();
  }
}

// Opening the web-app URL in a browser shows this — handy to check the deployment works.
function doGet() {
  return ContentService.createTextOutput('Diwali RSVP endpoint is live 🪔');
}

function getSheet_() {
  const ss = SpreadsheetApp.openById(SPREADSHEET_ID);
  let sheet = ss.getSheetByName(SHEET_NAME);
  if (!sheet) {
    sheet = ss.insertSheet(SHEET_NAME);
  }
  if (sheet.getLastRow() === 0) {
    sheet.appendRow(COLUMNS.map(([, heading]) => heading));
    sheet.getRange(1, 1, 1, COLUMNS.length)
      .setFontWeight('bold').setBackground('#f7b733').setFontColor('#2a1546');
    sheet.setFrozenRows(1);
  }
  return sheet;
}

function notifyHost_(p, sheet) {
  // Running headcount of Yes/Maybe guests
  const idx = (key) => COLUMNS.findIndex(([k]) => k === key);
  const rows = sheet.getLastRow() > 1
    ? sheet.getRange(2, 1, sheet.getLastRow() - 1, COLUMNS.length).getValues()
    : [];
  let yes = 0, maybe = 0;
  rows.forEach((r) => {
    const n = Number(r[idx('guests')]) || 1;
    if (r[idx('attending')] === 'Yes') yes += n;
    if (r[idx('attending')] === 'Maybe') maybe += n;
  });

  const esc = (s) => String(s).replace(/[&<>"]/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
  const table = COLUMNS
    .filter(([key]) => key !== '_timestamp' && p[key])
    .map(([key, heading]) =>
      `<tr><td style="padding:4px 10px;font-weight:bold">${heading}</td><td style="padding:4px 10px">${esc(p[key])}</td></tr>`)
    .join('');

  MailApp.sendEmail({
    to: HOST_EMAIL,
    subject: `🪔 Diwali RSVP: ${p.name} (${p.attending || '?'})`,
    replyTo: p.email || HOST_EMAIL,
    htmlBody:
      `<h2>New RSVP from ${esc(p.name)}</h2>` +
      `<table border="1" cellspacing="0" style="border-collapse:collapse">${table}</table>` +
      `<p><b>Headcount so far:</b> ${yes} coming, ${maybe} maybe.</p>` +
      `<p><a href="${SpreadsheetApp.openById(SPREADSHEET_ID).getUrl()}">Open the RSVP sheet</a></p>`,
  });
}

// Stop spreadsheet formula injection (values starting with = + - @)
function safe_(v) {
  if (v == null) return '';
  const s = String(v);
  return /^[=+\-@]/.test(s) ? "'" + s : s;
}

function json_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj)).setMimeType(ContentService.MimeType.JSON);
}
