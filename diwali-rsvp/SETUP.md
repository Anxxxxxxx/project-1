# Diwali RSVP – Host Setup

RSVPs go to **anvita8126@gmail.com**. You can choose between two setups:

| | What you get | Setup time |
|---|---|---|
| **A. Email only** (works out of the box) | One email per RSVP, laid out as a table | 1 minute |
| **B. Google Sheet → Excel** (recommended) | Every RSVP saved as a row in a spreadsheet you can download as `.xlsx`, **plus** an email with a running headcount | ~5 minutes |

---

## A. Email only (FormSubmit)

The page already sends RSVPs to `anvita8126@gmail.com`.

1. Open the RSVP page and send **one test RSVP** yourself.
2. Check the inbox (and Spam) for an email from **FormSubmit** and click **Activate Form**.
   You only do this once. Until then, RSVPs are **not** delivered and guests see an error.
3. Done. Every RSVP now arrives in your inbox.

---

## B. Google Sheet you can open in Excel

1. Sign in to Google as `anvita8126@gmail.com` and create a new sheet at <https://sheets.new>.
   Name it something like **Diwali RSVPs**.
2. In the sheet, go to **Extensions ▸ Apps Script**.
3. Delete what's there, paste in the contents of [`google-sheet/Code.gs`](google-sheet/Code.gs), and click 💾 **Save**.
4. Click **Deploy ▸ New deployment**:
   - Click ⚙️ next to "Select type" and choose **Web app**
   - **Execute as:** Me
   - **Who has access:** **Anyone**
   - Click **Deploy**, then **Authorize access** and allow the permissions.
     If Google warns "app isn't verified", click **Advanced ▸ Go to … (unsafe)**. It's your own script.
5. Copy the **Web app URL** (it ends in `/exec`).
6. Open `index.html` and paste it in:
   ```js
   const SHEET_URL = "https://script.google.com/macros/s/XXXXXXXX/exec";
   ```
7. Send a test RSVP. A row should appear in the **RSVPs** tab and an email should arrive.

**Downloading as Excel:** in the sheet, go to **File ▸ Download ▸ Microsoft Excel (.xlsx)**.
You can do this as often as you like, since the sheet keeps updating.

> If you change `Code.gs` later, use **Deploy ▸ Manage deployments ▸ ✏️ Edit ▸ Version: New version**
> so the URL stays the same.

---

## Sharing the page with guests

The page has to be hosted online so guests can open it.
Opening it inside GitHub or a file preview won't run the form.

- **Netlify Drop (easiest):** go to <https://app.netlify.com/drop> and drag the `diwali-rsvp` folder in. You'll get a link to share.
- **GitHub Pages:** in the repo go to **Settings ▸ Pages**, choose this branch and folder, and share the URL it gives you.
  Free GitHub Pages needs a public repo.
