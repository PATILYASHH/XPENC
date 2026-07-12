<div align="center">

<img src="branding/xpenc_icon_512.png" width="112" alt="XPENC">

# XPENC

**Money, tracked honestly.**

Offline-first personal finance for Android — income, expense, transfers,
budgets, persons and bank-message auto-capture. Everything lives in a local
SQLite database on the phone. Nothing is ever uploaded.

</div>

---

## Why it exists

Most expense apps quietly lie to you. They blur *where money sits* with *what it
was for*, count a transfer between your own accounts as income, or double-count
a UPI payment because the bank sent two SMS. XPENC treats the ledger as the
single source of truth and enforces one invariant everywhere:

> **Net worth = the sum of all account balances.** A transfer leaves it
> unchanged, income raises it, expense lowers it. If the numbers ever disobey
> that, it's a bug.

Amounts are integer **paise**, never doubles — floats corrupt money math.
Lending is not spending, and being repaid is not earning, so person movements
are excluded from budgets and income/expense reports.

See [structure.md](structure.md) for the full design.

## Brand

| Asset | Path |
|---|---|
| Master icon (1024, 512) | `branding/xpenc_icon_1024.png` |
| Scalable source | `branding/xpenc_icon.svg` |
| Favicon (multi-size .ico) | `branding/favicon.ico` |
| Web / PWA icons | `branding/icon_192.png`, `apple_touch_icon_180.png` |

Every asset — launcher icons, adaptive icon, Android 13 themed icon, splash
marks and favicons — is generated from one geometric definition:

```sh
python tool/generate_icons.py
```

Nothing is hand-drawn, so the icons cannot drift out of sync with each other.
The in-app logo (`lib/core/branding/brand_mark.dart`) redraws the same geometry
as a `CustomPainter`, so it stays sharp at any size and follows the theme.

## Running

```sh
flutter pub get
flutter run
```

## Tests

```sh
rm -rf build/native_assets   # Flutter/Windows native-assets bug
flutter analyze
flutter test
```

The widget tests render every screen against a real in-memory database at a real
phone size (360 × 800 dp) and fail on a layout overflow, so they catch what
`flutter analyze` cannot. `test/branding_test.dart` additionally fails the build
if `AppInfo.version` ever drifts from the `version:` line in `pubspec.yaml`.

## Shipping an APK

```sh
flutter build apk --release --split-per-abi
bash tool/verify_apk.sh build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

`verify_apk.sh` **must pass.** It is the only thing standing between you and
shipping another APK with no `libsqlite3.so` — a failure no unit test can see,
because every test overrides the database with an in-memory one.

## Code generation

The database classes in `lib/data/database.g.dart` are generated from
`lib/data/tables.dart` by drift. After changing a table you must regenerate:

```sh
dart run build_runner build --force-jit --delete-conflicting-outputs
```

**`--force-jit` is required.** Without it build_runner tries to AOT-compile its
build script, which fails on this SDK with `'dart compile' does not support
build hooks, use 'dart build' instead` — a transitive dependency (`objective_c`,
via a plugin) ships build hooks that the AOT snapshot step rejects. `--force-jit`
skips the snapshot and runs the build script directly.

### Changing the schema

1. Edit `lib/data/tables.dart`.
2. Bump `schemaVersion` in `lib/data/database.dart`.
3. Add the `onUpgrade` step (`m.addColumn(...)`, `m.createTable(...)`).
4. Regenerate (above).
5. Check restore: `importAll` skips columns it does not recognise, so an older
   backup keeps working. Add a test for it — `test/theme_test.dart` has one.

## Privacy

Bank SMS are read on-device, parsed on-device, and stored on-device. The app
requests `READ_SMS` and deliberately **not** `RECEIVE_SMS`: it scans the inbox
when you open it rather than running a background broadcast receiver. No message,
transaction or balance ever leaves the phone. There is no server.

## Developer

**Yash Patil**

- GitHub — [@PATILYASHH](https://github.com/PATILYASHH)
- LinkedIn — [in/patilyasshh](https://www.linkedin.com/in/patilyasshh/)

© 2026 Yash Patil
