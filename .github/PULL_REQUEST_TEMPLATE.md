# What & why

<!-- Link the issue this addresses. PRs without a linked issue are fine for docs/website. -->

Closes #

## Changes

-

## Money-honesty checklist

<!-- Delete rows that don't apply — but read them first. These are the invariants
     from CONTRIBUTING.md; tests guard most of them. -->

- [ ] No `double` used for money — amounts stay integer paise
- [ ] Transfers / person movements still excluded from income, expense & budgets
- [ ] Nothing posts to the ledger without user confirmation
- [ ] Schema change? `schemaVersion` bumped + migration + old-backup restore test

## Verification

- [ ] `flutter analyze` clean
- [ ] `flutter test` green (new behavior has new tests)
- [ ] Release-related change: `bash tool/verify_apk.sh` passes on a release build
