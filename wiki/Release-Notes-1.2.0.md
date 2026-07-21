# Release Notes — XPENC 1.2.0

_Released 2026-07-21_

The first **feature** release since 1.1.0. Four things: subcategories, dues &
owes on the dashboard, every world currency, and importing a backup to move to a
new phone. It's fully backward compatible — updating over an existing install
keeps every account, transaction and setting. See the
[Upgrade Guide](Upgrade-Guide.md) before you install.

---

## 1. Subcategories

Categories can now nest **one level deep**: a top-level parent (e.g. *Food*)
with children under it (*Groceries*, *Restaurants*). This mirrors how tools like
Financisto group spending.

**How it works**

- **Create one:** go to **More → Categories**, tap the **＋** on any category to
  add a subcategory under it, or open the editor and choose a **Parent
  category**. The tree is exactly two levels deep — a subcategory can't have its
  own children.
- **Tag a transaction:** in *Add transaction*, open the category picker and tap a
  parent to drill into its subcategories. Pick a specific child, or choose
  **All \<parent\>** to tag the parent directly. The field shows the full path,
  e.g. *Food › Groceries*.
- **Roll-up:** a child's spending counts toward its parent everywhere it
  matters — the dashboard *Spending* card, the Stats pie, and "Top category".
- **Budgets:** a budget set on a **parent** covers its whole subtree (its own
  spend plus every child's). A budget on a child tracks just that child.
- **Archiving:** archiving a parent also archives its subcategories (you're told
  how many first). As always, nothing is deleted — archiving only hides a
  category from new entries, so past reports stay intact.

**Nothing to migrate.** Every category you already have becomes a top-level
category. Add subcategories whenever you like.

---

## 2. Dues & owes on the dashboard

A new **People** section on the dashboard surfaces money in motion between you
and other people:

- Two headline figures — **You'll get** (money owed to you) and **You'll pay**
  (money you owe).
- The people with an outstanding balance, biggest first, each showing whether
  they *owe you* or *you owe* them, and how much.
- Tap through to a person, or **See all** to open the full Persons screen.

The section stays hidden when nothing is outstanding, so a dashboard for someone
who never lends or borrows stays clean. Remember: **lending isn't spending** —
money you've lent is still yours, just held by someone else, so it never counts
as an expense.

---

## 3. All world currencies

XPENC used to render only the rupee. Now you can pick from **~90 world
currencies** — including the **Bangladeshi Taka (৳)**.

**How it works**

- **Change it:** go to **Settings → Currency** and search by name, code or
  symbol. The whole app reformats **instantly** — even amounts already on
  screen.
- **Hide the symbol:** the **Show currency symbol** switch renders amounts as
  plain numbers (e.g. `1,250.50`). Use it if your currency's symbol isn't one we
  carry — you still get the right decimals and digit grouping.
- **Sensible formatting:** each currency shows the right number of decimals
  (2 for most, 0 for yen-like currencies), and groups digits its own way — the
  rupee in lakhs (`1,00,000`), others in thousands (`100,000`).

Your money is unchanged under the hood — amounts are stored as minor units
(hundredths) regardless of currency, so switching never rewrites your ledger.

---

## 4. Import a backup — move to a new phone

Exporting your data already worked (share a backup, or **More → Download Data →
Export JSON/CSV**). 1.2.0 adds the other half: **bringing a backup in**.

- **More → Backup & Restore → Import from file** lets you pick **any** backup
  file — including one the app didn't create, e.g. carried over from another
  phone.
- Before replacing anything, XPENC saves a **safety copy** of your current data,
  so a mistaken import can be undone by restoring that copy.
- The import is **all-or-nothing**: a wrong, corrupt, or non-XPENC file changes
  nothing and tells you why.

**Moving to a new phone, end to end**

1. On the **old** phone: **More → Download Data → Export JSON** (or back up, then
   share the backup).
2. Send the file across — any way you like (it never leaves your phone until you
   choose to share it).
3. On the **new** phone: install XPENC, then **More → Backup & Restore → Import
   from file** and pick the file.

Your accounts, transactions, budgets, persons, subcategories **and** your chosen
currency all come across.

---

## Also in this release

- Spending breakdowns now group by top-level category (a consequence of
  subcategories).
- `share_plus` was pinned just below its latest major so it can share a native
  dependency with the new file picker — no behavioural change.

## Upgrading

Short version: **you don't need to reinstall** — the database migrates itself in
place. But **export a backup first** anyway. The full walkthrough, including the
one case that forces an uninstall, is in the [Upgrade Guide](Upgrade-Guide.md).
