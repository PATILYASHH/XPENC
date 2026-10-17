# Modes v2 — sandbox, allocations, limits

Builds on `2026-10-17-modes-design.md` (v1, shipped to BETA b7a836e). Asked
for by Yash on 2026-10-17; decisions below were his answers.

## Decisions

| Question | Decision |
|---|---|
| People | Pick the persons who are with you. Inside the mode the Persons tab shows only them, and only what happened in the mode — a fresh start. Their full balances are untouched outside it. |
| ON/OFF | A switch on every mode (list and page). ON by hand or by its dates. One ON at a time. |
| Look while ON | The whole app is the mode: the Dashboard tab is titled with the mode's name and shows only the mode — **left to spend** first, organised around its budget. |
| Templates | Templates can belong to a mode; inside it only its templates show, outside it they never do. |
| Sandbox | Inside the mode every module reads only the mode's data. Nothing from before the mode shows. |
| Accounts | Each mode account gets an **allocation** ("₹5,000 of HDFC for this trip"). While ON its balance reads allocation − what the trip took from it. OFF → the real balance. No allocation → the real balance. |
| Over a limit | Warn and confirm ("₹500 over the Food limit — save anyway?"), never block; alerts at 80% and 100%. |
| Extras | Split with mode people; end-of-mode summary; trip wallet; planned costs. |

## People = the mode's group

Picking persons for a mode makes them the members of its linked group —
creating one named after the mode if there's none. One mechanism then serves
both the trip-only Persons tab and splitting bills (Groups already computes
who owes whom). A linked existing group's members are the mode's people.

`PersonEntries.modeId` (new): an entry made while the mode is ON — by hand,
or as a share of a split — belongs to it even when no money moved (no
transaction). Trip balance of a person = net of their entries in the mode.

## Storage (schema 87)

- `PersonEntries.modeId` (nullable → Modes).
- `TransactionTemplates.modeId` (nullable → Modes).
- `ModeAccounts.allocation` (nullable money).
- `Modes`: `dailyLimit?`, `spendLimit?` (per transaction), `walletAccountId?`
  (→ Accounts), `walletSourceAccountId?` (→ Accounts), `walletAmount?`,
  `alerts` (text, which 80/100% alerts already fired).
- `ModeCategoryLimits(modeId, categoryId, amount)` — any category the mode
  uses, its own included.
- `ModePlannedCosts(id, modeId, name, amount, categoryId?, transactionId?,
  sortOrder)` — paid once `transactionId` is set.
- Backup, import, clear and delete paths include all of it.

## Behaviour

**Left to spend** = budget − spent − unpaid planned costs. Budget is the
mode's own; empty → the sum of its account allocations.

**Daily allowance** (with an end date) = left ÷ days left, today included.
With a daily limit, today's spend is shown against it.

**Limits checked on save** (Add, incl. split payment and change): total
budget, daily limit, the category's limit, the per-spend cap. Over any → one
dialog naming each, "Save anyway" / "Change". Quick add and bank messages
can't ask, so they save and the alert covers them.

**Alerts**: a notification at 80% and 100% of the budget and of each
category limit, once each per mode.

**Mode account balance** = allocation + every mode transaction's movement on
that account (out negative, in positive). Shown on Accounts, the Add pickers
and the mode home while ON.

**Split with mode people** (Add, expense, mode has people): "Split with"
chips; saving posts a group expense in the mode's group — you paid, equal
shares — so each person's share becomes a trip due. Not with split
categories, split payment or change.

**Trip wallet** (setup): "Move ₹X from <account> into a trip wallet when it
starts." Starting creates a cash account "<mode> wallet" and transfers X in
(in the mode, not spent); the wallet is a mode account with allocation X.
Ending offers "Move ₹left back to <account>" on the summary.

**Planned costs**: listed in the editor and on the mode home ("Hotel
₹12,000"); counted as committed; **Mark paid** opens Add prefilled (amount,
category, mode) and links the saved transaction.

**End-of-mode summary** (`/mode/:id/summary`): opens when a mode ends by
hand, and from a notification when its dates end it. Total vs budget, per
day, days, by category, by account, people balances (who owes whom),
planned costs, wallet leftover. Share as PDF or image (share kit).

## Sandbox — what each place shows while focused

| Place | Shows |
|---|---|
| Dashboard | Mode home only; title = mode name |
| Transactions, Calendar, Stats, Payees, search | Mode transactions only |
| Persons | Mode people only, trip balances; Groups: the mode's group only |
| Person page | Only the mode's entries; header = trip balance |
| Accounts | Mode accounts only, allocated balances |
| Budgets | The mode's category limits |
| ➕ templates | The mode's templates only |
| More | The mode's modules (v1) |

Outside the mode nothing is hidden: trip entries count in real balances,
mode templates never show, accounts show real balances.

## Testing

Person entries join the mode (with and without account); trip balances
ignore older entries; allocated balance math; left to spend with planned
costs; daily allowance; limit checks produce the right warnings and never
block; alerts fire once; split posts a group expense with shares in the
mode; wallet start/end transfers; templates scoped both ways; sandbox
screens filtered; summary renders and shares; migration from 86; backup
round trip; 360dp × 1.3.
