# Modes — design

A **mode** is a temporary event — a trip, a wedding, a festival — that the
person switches on, spends in, and switches off. While it's on, XPENC focuses
on it; afterwards it's one line in the everyday app that opens into the whole
story. Agreed with Yash on 2026-10-16/17.

## Decisions

| Question | Decision |
|---|---|
| What is a mode | A temporary event with a start and an end. #170 (permanent Personal/Work spaces) stays separate. |
| Which transactions join | Everything added by hand while it's ON, with a "Part of <mode>" opt-out on Add. Movable in/out later. |
| Outside the mode | Counted in monthly totals and balances, but category breakdowns show the mode as **one slice**; everyday budgets don't count mode spending. |
| UI while ON | Mode home replaces the Dashboard; bottom bar and More show only the mode's modules; a slim top bar ("🧳 Goa Trip · Day 3 · End") with **Exit to full app**. |
| Setup | Dates + budget; allowed accounts/categories; auto-tags; mode-only categories and tags; modules shown; linked Groups trip; default currency. |
| Name | "Modes". The Basic/Medium/Pro setting becomes **"App level"** (label only). |
| Storage | A mode is its own record; a transaction points at it (`modeId`). |

## Rules

- **One mode ON at a time.** A mode is `planned`, `active` or `ended`; an
  ended one can be started again.
- **Joining** (explicit, never implied by the database): the Add screen
  (incl. split-across-accounts), the quick-add notification, detected bank
  messages (approved or auto-filled), and new person entries pass the active
  mode. Auto-rule postings, CSV import, goal/loan payments, corrections and
  backup restores never join. A linked group's expense transactions always
  join that group's mode.
- **Spent** = money out (expenses) in the mode. Transfers and lending can be in
  a mode and show on its page, but don't count toward "spent".
- **Mode-only categories and tags** carry the mode's id: they appear only in
  that mode's pickers, never in everyday lists (Categories, Tags, Budgets,
  pickers), but always resolve by name, so history reads correctly. When a
  mode is deleted they become ordinary archived categories/tags.
- **Limits**: an empty allowed-accounts (or allowed-categories) set means no
  limit. The mode's own categories are always offered.
- **Auto-tags** are pre-selected on Add while ON (removable per transaction).
- **Dates**: a planned mode whose start date has come switches itself on (if
  nothing else is ON); an active mode past its end date switches itself off.
  Checked on launch and resume.
- **Default currency**: when it differs from the parent currency, Add
  pre-fills the foreign-amount annotation with it (GitHub #85).

## Where it shows

- **Transactions tab** — with no search/filter: each mode's transactions
  become one card ("🧳 Goa Trip · 12–18 Oct · 23 spends · −₹18,400") at its
  latest date, opening the mode page. With a search/filter: individual rows,
  each with a mode chip. While a mode is ON (focused): only its transactions.
- **Mode page** (`/mode/:id`) — name, dates, status; spent vs budget, per-day
  average, days; by category; by account; linked group; every transaction;
  Start/End/Edit/Delete.
- **Stats / Dashboard Spending** — mode transactions leave
  `spendByCategoryProvider`; a per-mode total adds one slice per mode, opening
  the mode page. Monthly Money in/out totals are unchanged (they include it).
- **Budgets, Budget detail, Category page** — exclude mode transactions.
- **Account page, statements, Dashboard Recent** — unchanged rows, plus a mode
  chip.
- **Transaction detail** — "Mode" row with Move out / Add to a mode.

## Storage (schema 86)

- `Modes`: id, name, iconKey, colorValue, status (planned/active/ended),
  startDate?, endDate?, startedAt?, endedAt?, budget?, currencyCode?, groupId?
  (→ Groups), navSlots? (`"transactions,persons"`), modules (comma list of
  More module keys; empty = all), createdAt.
- `ModeAccounts(modeId, accountId)`, `ModeCategories(modeId, categoryId)`,
  `ModeTags(modeId, tagId)` — allowed accounts, allowed categories, auto-tags.
- `modeId` (nullable → Modes) on `Transactions`, `Categories`, `Tags`.
- `Settings.activeModeId` (nullable).
- Backup export/import include all of it; `clearAllData` clears it.

## UI pieces

- **More → Modes**: active, planned, ended; **New mode** (start from Trip or
  Blank).
- **Mode editor**: name, icon/colour, dates, budget, currency; accounts;
  categories (+ create mode-only); auto-tags (+ create mode-only); bottom-bar
  slots and More modules; linked group.
- **Mode home** (Dashboard while ON): spent vs budget, days, per day, by
  category, latest spends.
- **Mode bar** (top of every tab while ON): "🧳 Goa Trip · Day 3", End, Exit
  to full app / Back to trip.

## Phases

1. **Core** — storage, migration, backup; mode list/editor/page; start/end;
   joining (+ opt-out, move in/out); pickers limited; mode-only categories and
   tags; auto-tags; Transactions card; Stats/Dashboard slice; budgets
   excluded; chips; "App level" rename.
2. **Focus** — mode home, mode bar, nav slots and More modules, full-app
   toggle.
3. **Extras** — date-driven start/end, budget tracking, linked group, default
   currency.

## Testing

Joining and opt-out; auto-rule postings stay out; move in/out; one card per
mode in Transactions and individual rows under search; Stats slice and budgets
excluding mode spend; monthly totals unchanged; limited pickers; mode-only
categories hidden from everyday lists and still named in history; auto-tags;
date-driven switch; linked-group joining; default currency prefill; migration
from v85; backup round trip; delete detaches; screens at 360dp × 1.3 text.
