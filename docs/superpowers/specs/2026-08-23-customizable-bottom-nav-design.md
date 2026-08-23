# Customizable bottom navigation — design spec

Date: 2026-08-23
Status: draft, pending approval

## Background

GitHub #70: a user doesn't use the "Persons" tab and asked to launch
Calendar from that slot instead. Yash (owner) replied on the issue:
"I'll add a customizable bottom nav where users can choose all nav buttons
according to preference." This spec is that feature.

Today's bar (`lib/core/routing/app_shell.dart`) is 5 fixed slots — Dashboard,
Transactions, ➕ (a pushed route, not a tab), Persons, More — backed by a
`StatefulShellRoute.indexedStack` with exactly 4 branches
(`lib/core/routing/app_router.dart`).

## Decisions already made (with the user, before this doc)

- **Dashboard and More stay permanent, non-swappable bar positions** (outer
  slots 1 and 5). More is the only door to Settings/Backup/Categories/etc.,
  so it can't be configured away; Dashboard is the app's home screen and
  stays the fixed landing tab. Neither needs any router/screen change —
  both keep working exactly as they do today.
- Only the **two slots flanking the ➕ button** (today: Transactions,
  Persons) are user-configurable, independently of each other.
- A swapped-in destination becomes a *real* tab: its own shell branch, no
  back arrow, state/scroll preserved when switching away and back — same
  tier as Dashboard/Transactions/Persons/More today, not a shortcut that
  pushes a route with a back button.
- The catalog for those two slots is the "medium" set: Transactions,
  Persons, plus Calendar & Reminders, Budgets, Accounts, Stats, Payees
  (7 total). Dashboard and More are excluded from the catalog — they're
  pinned, never a choice.

## Non-goals

- Touching the Dashboard or More slots at all — they're out of scope, fixed.
- Variable slot count. Always exactly the 2 configurable slots (matches the
  existing 1 + ➕ + 1 layout between the pinned ends). Revisit only if
  actually requested later.
- Reordering/removing the ➕ button itself — it stays fixed dead center.
- Any change to what the More hub itself contains or how it's laid out.

## Catalog & data model

9 branches total, each mapped to a fixed, permanent shell-branch index
(assigned once, never reordered by user configuration):

| id | branch index | label | screen | pinned? |
|---|---|---|---|---|
| `dashboard` | 0 | Dashboard | `DashboardScreen` | yes — slot 1, fixed |
| `transactions` | 1 | Transactions | `TransactionsScreen` | no — catalog |
| `persons` | 2 | Persons | `PersonsScreen` | no — catalog |
| `more` | 3 | More | `MoreScreen` | yes — slot 5, fixed |
| `calendar` | 4 | Calendar | `CalendarScreen` | no — catalog |
| `budgets` | 5 | Budgets | `BudgetsScreen` | no — catalog |
| `accounts` | 6 | Accounts | `AccountsScreen` | no — catalog |
| `stats` | 7 | Stats | `StatsScreen` | no — catalog |
| `payees` | 8 | Payees | `PayeesScreen` | no — catalog |

`dashboard` and `more` are never part of the configurable catalog — they
render at fixed bar positions 1 and 5 unconditionally, sourced directly
from the existing `_tabs` entries, untouched.

Keeping branch indices fixed means existing index-based logic (e.g.
`AppShell._goBranch`'s scroll-to-top special case, hardcoded today as
`branchIndex == 1` for Transactions) keeps working unchanged — only which
catalog item sits in each of the 2 configurable *bar positions* varies,
never the underlying branch wiring.

New `Settings` column, following the existing `themeName` convention (text,
not an enum index, so nothing silently breaks if the catalog is reordered
later):

```dart
/// Comma-separated pair of distinct catalog ids for the two configurable
/// bar slots — left-of-➕ then right-of-➕. Dashboard and More are fixed
/// and never appear here. See `BottomNavCatalog` in app_shell.dart for the
/// valid id set.
TextColumn get bottomNavSlots => text()
    .withDefault(const Constant('transactions,persons'))();
```

Schema v33 → v34, migration via the existing `_addColumnIfMissing` helper
in `lib/data/database.dart`.

Default is `transactions,persons` — identical to today's layout for every
existing user (least-surprise upgrade). Resolving #70 is then just the user
changing their own right-hand slot to `calendar` from the new settings
screen, exactly what the issue asked for.

`AppDatabase` gains `setBottomNavSlots(String left, String right)`
(validates both are in the catalog and distinct from each other, same
house style as other settings setters — no separate repository class).

## Router / shell restructuring

- `/dashboard`, `/transactions`, `/persons`, and `/more` (plus all of
  More's existing nested routes) are **completely untouched** — Dashboard
  and More being pinned means neither needs any restructuring at all.
- 5 new top-level `StatefulShellBranch`es added at new paths distinct from
  their `/more/*` siblings (which stay exactly as they are, for the
  unconditional "reach it via the More hub" path): `/calendar`, `/budgets`,
  `/accounts`, `/stats`, `/payees`. Each builder passes `embedded: true` to
  the screen (see below). This is a deliberate dual-path — e.g. Calendar is
  reachable both as a configured tab (preserved state, no back arrow) and,
  unconditionally, via the More hub's existing "Calendar & Reminders" tile
  (fresh each time, with a back arrow) — same as today, unaffected.
- go_router only builds a branch's navigator on first visit, so the catalog
  branches a given user doesn't currently have configured into a slot cost
  nothing at startup — no eager preload needed.

## Screen changes (embeddable mode)

`AccountsScreen` and `PayeesScreen` already render `Scaffold(body: ...)`
with no `appBar` — they're already shell-branch-shaped and need **no
change** beyond the new route/branch wiring.

`CalendarScreen`, `BudgetsScreen`, and `StatsScreen` each currently render
their own `Scaffold(appBar: AppBar(title: ..., actions: [...]), body: ...)`.
Each gains a constructor `embedded` bool (default `false`, preserving every
existing call site under `/more/*` byte-for-byte):

```dart
const CalendarScreen({this.embedded = false, super.key});
```

and their `build` splits into the shared body content plus:

```dart
if (embedded) return bodyContent;
return Scaffold(appBar: AppBar(...), body: bodyContent);
```

The 3 screens' existing AppBar actions move into `AppShell`'s `_TopBar`
per-tab actions switch (same place Transactions' search/filter and Persons'
archive/add-person actions already live) so they still appear when the
screen is a tab:

- Calendar: "Today" (conditional) + "New reminder"
- Budgets: "Download budget statement"
- Stats: "Download report"

## AppShell changes

- Bar layout stays `[Dashboard, slotLeft, ➕, slotRight, More]` — visually
  identical structure to today, just the middle two positions are now
  data-driven instead of the literal `_tabs[1]`/`_tabs[2]`.
- `slotLeft`/`slotRight` are resolved at build time from
  `Settings.bottomNavSlots`, through a static `BottomNavCatalog` map
  (`id -> (icon, activeIcon, label, branchIndex)`) covering the 7 catalog
  ids. Dashboard and More keep coming straight from the existing hardcoded
  `_tabs` entries, unchanged.
- `_TopBar._titles`/`_tabActions` extend from a 4-case to a 9-case switch
  (indexed by branch index, same as today — unaffected by which catalog
  item currently occupies a slot).
- Edge case: if the user reconfigures a slot while sitting on the branch
  that used to occupy it, redirect to Dashboard (mirrors what would
  otherwise be a tab with no bar button pointing at it).

## Settings UI

New screen, reachable from the More hub's "Setup" group (a
`_Item(Icons.dashboard_customize_outlined, 'Customize bottom nav', route: '/more/bottom-nav', ...)`
tile, alongside Settings):

- Shows the bar layout schematically: Dashboard and More labeled as fixed
  (no picker, just a disabled-looking row so it's clear they can't be
  changed), with the two configurable rows in between.
- Each configurable row opens a bottom-sheet picker (same visual idiom as
  `ThemePickerSheet` — radio-style list, checkmark on current) restricted
  to the 7 catalog ids, excluding whichever one the *other* configurable
  slot currently uses (so the result is always 2 distinct ids — no dedup
  logic needed elsewhere).
- No reordering needed — with only 2 configurable slots, "which item goes
  left vs. right" is just picking per-row, not a drag operation.
- Saves through `AppDatabase.setBottomNavSlots` on every change (no separate
  "Save" button, matching how every other settings toggle in this app
  persists immediately).

## Testing

- `test/smoke_test.dart`: unaffected if it doesn't assert exact tab
  contents (default keeps today's layout byte-for-byte); update only if it
  does.
- New test: changing a slot's picker updates `Settings.bottomNavSlots` and
  is reflected in `AppShell`'s rendered bar on next build; Dashboard/More
  positions never change.
- New test: a branch no longer in the visible set, while currently active,
  redirects to Dashboard.
- Existing behavior for Budgets/Stats/Calendar's *pushed* (`embedded: false`)
  path — reached via `/more/*` — must be unaffected; existing tests for
  those screens should pass unchanged since that's the default constructor
  value.

## Migration/back-compat summary

Purely additive: one new `Settings` column with a safe default, 5 new
routes/branches, no existing route removed, no existing table changed,
`/more/*` deep links untouched, Dashboard/Transactions/Persons/More all
byte-for-byte unchanged in their own screen code. Existing users see an
*identical* bar after upgrade (default reproduces today's layout exactly);
#70 is resolved by the reporter opening the new settings screen and putting
Calendar in their right-hand slot themselves.
