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

- All 4 non-➕ slots become freely configurable — not just the Persons slot.
- A swapped-in destination becomes a *real* tab: its own shell branch, no
  back arrow, state/scroll preserved when switching away and back — same
  tier as Dashboard/Transactions/Persons today, not a shortcut that pushes
  a route with a back button.
- The catalog is the "medium" set: today's 4 items plus Calendar & Reminders,
  Budgets, Accounts, Stats, Payees (8 total).
- **More is removed from the catalog entirely.** It's the only door to
  Settings/Backup/Categories/Tags/etc., so if it could be configured away
  a user could lock themselves out of Settings. Instead it becomes a
  permanent icon in the top bar, always present regardless of which 4 tabs
  are configured.

## Non-goals

- Variable slot count. Always exactly 4 configurable slots (matches the
  existing 2 + ➕ + 2 layout). Revisit only if actually requested later.
- Reordering/removing the ➕ button itself — it stays fixed dead center.
- Any change to what the More hub itself contains or how it's laid out.

## Catalog & data model

8 catalog ids, each mapped to a fixed, permanent shell-branch index (assigned
once, never reordered by user configuration — only *visibility and bar
position* are user-configurable):

| id | branch index | label | screen |
|---|---|---|---|
| `dashboard` | 0 | Dashboard | `DashboardScreen` |
| `transactions` | 1 | Transactions | `TransactionsScreen` |
| `persons` | 2 | Persons | `PersonsScreen` |
| `calendar` | 3 | Calendar | `CalendarScreen` |
| `budgets` | 4 | Budgets | `BudgetsScreen` |
| `accounts` | 5 | Accounts | `AccountsScreen` |
| `stats` | 6 | Stats | `StatsScreen` |
| `payees` | 7 | Payees | `PayeesScreen` |

Keeping branch indices fixed means existing index-based logic (e.g.
`AppShell._goBranch`'s scroll-to-top special case, hardcoded today as
`branchIndex == 1` for Transactions) keeps working unchanged — only the
bar's displayed subset/order changes, never the underlying branch wiring.

New `Settings` column, following the existing `themeName` convention (text,
not an enum index, so nothing silently breaks if the catalog is reordered
later):

```dart
/// Ordered, comma-separated list of exactly 4 distinct catalog ids —
/// which bottom-nav slots are visible and in what order. See
/// `BottomNavCatalog` in app_shell.dart for the valid id set.
TextColumn get bottomNavItems => text()
    .withDefault(const Constant('dashboard,transactions,persons,calendar'))();
```

Schema v33 → v34, migration via the existing `_addColumnIfMissing` helper
in `lib/data/database.dart`.

Default is `dashboard,transactions,persons,calendar` — keeps the first 3
slots identical to today for every existing user (least-surprise upgrade)
and fills the old More slot with Calendar, which both resolves #70 as the
new out-of-the-box default *and* leaves every user free to change it.

`AppDatabase` gains `setBottomNavItems(List<String> ids)` (validates length
== 4 and all-distinct-from-catalog, same house style as other settings
setters — no separate repository class).

## Router / shell restructuring

- `/more` stops being a `StatefulShellBranch`. It becomes a plain pushed
  `GoRoute` on `_rootKey` (sibling of `/add`, `/inbox`, etc.) — same tier as
  every screen it already contains. Its existing nested routes
  (`/more/budgets`, `/more/calendar`, `/more/settings`, ...) are **untouched** —
  the More hub keeps working exactly as it does today, unconditionally,
  regardless of nav bar configuration. This is a deliberate dual-path: a
  catalog item reachable via a configured tab *and* still reachable (fresh,
  non-preserved, with a back button) via the More hub, same as Dashboard
  isn't reachable from More today but Budgets already lives happily as a
  push-only screen.
- `MoreScreen` gains its own `Scaffold(appBar: AppBar(title: Text('More'), ...))`
  since it no longer sits inside the shell's shared top bar.
- 5 new top-level `StatefulShellBranch`es added at new paths distinct from
  their `/more/*` siblings: `/calendar`, `/budgets`, `/accounts`, `/stats`,
  `/payees`. Each builder passes `embedded: true` to the screen (see below).
- go_router only builds a branch's navigator on first visit, so the 3-5
  catalog branches a given user never selects cost nothing at startup —
  no eager preload needed.

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

- `_tabs` (today a hardcoded 4-item `const` list) becomes derived at build
  time from `Settings.bottomNavItems`, resolved through a static
  `BottomNavCatalog` map (`id -> (icon, activeIcon, label, branchIndex)`)
  covering all 8 ids.
- The bar renders exactly the user's 4 configured items, in their chosen
  order, around the fixed center ➕ — same `Row` structure as today, just
  built from a variable-length-4 list instead of the literal `_tabs[0..3]`.
- `_TopBar._titles`/`_tabActions` extend from a 4-case to an 8-case switch
  (indexed by branch index, same as today — unaffected by bar order).
- New permanent top-bar icon (a `_TonalIconButton`, same idiom as the
  existing Review Inbox button) pushes `/more`. Always shown, on every tab,
  regardless of configuration.
- Edge case: if the user reconfigures the bar while sitting on a branch
  that's no longer in the visible 4, redirect to the first visible slot's
  branch (mirrors what would otherwise be a tab with no bar button pointing
  at it).

## Settings UI

New screen, reachable from the More hub's "Setup" group (a
`_Item(Icons.dashboard_customize_outlined, 'Customize bottom nav', route: '/more/bottom-nav', ...)`
tile, alongside Settings):

- Lists the 4 active slots in order with drag handles (`ReorderableListView`,
  reorders `bottomNavItems` directly).
- Each row has a "change" action opening a bottom-sheet picker (same visual
  idiom as `ThemePickerSheet` — radio-style list, checkmark on current)
  restricted to the 8 catalog ids, excluding whichever 3 are already used in
  the *other* slots (so the result is always 4 distinct ids — no dedup
  logic needed elsewhere).
- Saves through `AppDatabase.setBottomNavItems` on every change (no separate
  "Save" button, matching how every other settings toggle in this app
  persists immediately).

## Testing

- `test/smoke_test.dart`: update for the new default tab set
  (`dashboard,transactions,persons,calendar`) if it asserts specific tab
  labels/order.
- New test: changing the nav customization screen's picker/reorder updates
  `Settings.bottomNavItems` and is reflected in `AppShell`'s rendered bar on
  next build.
- New test: a branch no longer in the visible set, while currently active,
  redirects to the first visible slot.
- Existing behavior for Budgets/Stats/Calendar's *pushed* (`embedded: false`)
  path — reached via `/more/*` — must be unaffected; existing tests for
  those screens should pass unchanged since that's the default constructor
  value.

## Migration/back-compat summary

Purely additive: one new `Settings` column with a safe default, 5 new
routes/branches, no existing route removed, no existing table changed,
`/more/*` deep links untouched. Existing users see identical top-3 tabs
after upgrade, with Calendar filling the old More slot and More itself one
tap away via the new permanent icon.
