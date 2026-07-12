# Contributing to XPENC

Thanks for your interest in making XPENC better. This guide covers everything
from setting up the toolchain to what a good PR looks like.

> **New here?** The single best document to read first is
> [structure.md](structure.md) — the full design doc: mental model, data model,
> every decision and why it was made.

---

## Ways to contribute

| You want to… | Start here |
|---|---|
| Report a bug | [Open a bug report](../../issues/new?template=bug_report.yml) |
| Request a feature | [Open a feature request](../../issues/new?template=feature_request.yml) |
| **Add SMS support for your bank** ⭐ | [Bank support request](../../issues/new?template=bank_support.yml) — the most valuable "good first issue" |
| Improve docs / website | PRs welcome, no issue needed |
| Fix a bug / build a feature | Comment on the issue first so work isn't duplicated |

---

## Development setup

**Toolchain:** Flutter `3.38.9` · Dart `3.10.8` (see [structure.md §Toolchain](structure.md))

```sh
git clone https://github.com/PATILYASHH/XPENC.git
cd XPENC
flutter pub get
flutter run
```

### Running tests

```sh
# Windows only: work around a Flutter native-assets bug before each test run
rm -rf build/native_assets

flutter analyze
flutter test
```

The widget tests render every screen against a real in-memory database at a
real phone size (360 × 800 dp) and fail on layout overflows — they catch what
`flutter analyze` cannot.

### Code generation (drift)

After changing any table in `lib/data/tables.dart`:

```sh
dart run build_runner build --force-jit --delete-conflicting-outputs
```

**`--force-jit` is required** — without it build_runner fails with
`'dart compile' does not support build hooks` on this SDK.

### Changing the database schema

1. Edit `lib/data/tables.dart`.
2. Bump `schemaVersion` in `lib/data/database.dart`.
3. Add the `onUpgrade` migration step.
4. Regenerate (above).
5. Verify old backups still restore — `importAll` skips unknown columns; add a test.

---

## The rules that keep the money honest

These are invariants, not preferences. PRs that break them will not be merged,
and most of them are guarded by tests:

1. **Amounts are integer paise.** Never `double`. `₹12.50` is stored as `1250`.
2. **Net worth = Σ account balances.** Transfers keep it unchanged; income
   raises it; expense lowers it.
3. **Transfers and person (due/owe) movements are neither income nor expense.**
   They must never appear in budgets or income/expense reports.
4. **Debit cards & UPI are linked instruments, not accounts.** They spend their
   bank's money and hold no balance of their own — otherwise rupees get counted twice.
5. **Auto-Approve only fires from a learned rule** (exact match), never a fresh
   guess — and **Undo must reverse the posted transaction**, not just hide the card.
6. **Nothing auto-posts silently.** Cash Reminders confirm with the user;
   see structure.md §9 for why Auto Spend is parked.
7. **SMS never leaves the device.** All parsing is on-device. No network calls.

### Pinned dependencies — do not bump casually

| Package | Pinned | Why |
|---|---|---|
| `drift` / `drift_dev` / `drift_flutter` / `sqlite3_flutter_libs` | 2.31.0 / 0.2.8 / 0.5.24 | drift ≥ 2.32 silently drops `libsqlite3.so` from Android release builds (see structure.md — "the crash that shipped") |
| `flutter_riverpod` | 2.6.1 | 3.x forces Dart ≥ 3.11, which breaks `drift_dev` on this SDK |

If you believe a pin can be lifted, open an issue with evidence
(`tool/verify_apk.sh` passing on a release build) rather than a drive-by bump.

---

## Adding a bank SMS template

The highest-impact contribution. Parsing lives in Dart (rule + regex engine,
templates in config — not code):

1. Collect **redacted** samples of your bank's debit/credit SMS
   (replace account digits, amounts and names — keep the structure).
2. Add the sender IDs + patterns to the bank templates.
3. Add parser tests: amount, direction (Money In / Money Out), account hint
   (`A/c XX1234`), merchant, and — critically — **dedupe** (UPI often sends
   two SMS for one payment).
4. Noise must be discarded: OTPs, promos, balance-only and declined messages.

---

## Pull request checklist

- [ ] One logical change per PR; small is beautiful.
- [ ] `flutter analyze` — clean.
- [ ] `flutter test` — all green (new behavior comes with new tests).
- [ ] No new dependencies without discussion in an issue first.
- [ ] Commit messages follow [Conventional Commits](https://www.conventionalcommits.org/):
      `feat: …`, `fix: …`, `docs: …`, `test: …`, `refactor: …`, `chore: …`
- [ ] If you touched anything release-related: `flutter build apk --release --split-per-abi`
      then `bash tool/verify_apk.sh` must pass.

PRs run CI automatically (`.github/workflows/ci.yml`). A maintainer reviews,
may request changes, and merges with a squash.

## Releases

Versioning and the tag → GitHub Actions → Release pipeline are documented in
[docs/RELEASING.md](docs/RELEASING.md). Contributors never need to cut releases —
maintainers do that by pushing a `v*` tag.

## Code of conduct

Participation is governed by the [Code of Conduct](CODE_OF_CONDUCT.md).
Be kind; assume good intent.

## License

By contributing you agree that your contributions are licensed under the
[MIT License](LICENSE).
