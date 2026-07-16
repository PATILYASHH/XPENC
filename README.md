<div align="center">

<img src="branding/xpenc_banner.svg" width="720" alt="XPENC — Money, tracked honestly.">

<br><br>


[![F-Droid](https://img.shields.io/f-droid/v/com.yash.xpenc?label=F-Droid&logo=fdroid&logoColor=white&color=white&labelColor=black)](https://f-droid.org/packages/com.yash.xpenc/)
[![Release](https://img.shields.io/github/v/release/PATILYASHH/XPENC?label=release&color=white&labelColor=black)](https://github.com/PATILYASHH/XPENC/releases/latest)
[![CI](https://github.com/PATILYASHH/XPENC/actions/workflows/ci.yml/badge.svg)](https://github.com/PATILYASHH/XPENC/actions/workflows/ci.yml)
[![Release APK](https://github.com/PATILYASHH/XPENC/actions/workflows/release.yml/badge.svg)](https://github.com/PATILYASHH/XPENC/actions/workflows/release.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-white?labelColor=black)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-3.38.9-02569B?logo=flutter&logoColor=white&labelColor=black)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/platform-Android%207.0%2B-3DDC84?logo=android&logoColor=white&labelColor=black)](https://github.com/PATILYASHH/XPENC/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/PATILYASHH/XPENC/total?color=white&labelColor=black)](https://github.com/PATILYASHH/XPENC/releases)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-34c77b?labelColor=black)](CONTRIBUTING.md)
[![Sponsor](https://img.shields.io/badge/Sponsor-PATILYASHH-ea4aaa?logo=githubsponsors&logoColor=white&labelColor=black)](https://github.com/sponsors/PATILYASHH)

**Offline-first personal finance for Android.**
Income, expenses, transfers, budgets and dues —
everything lives in a local SQLite database on your phone. Nothing is ever uploaded.

[<img src="https://fdroid.gitlab.io/artwork/badge/get-it-on.png" alt="Get it on F-Droid" height="70">](https://f-droid.org/packages/com.yash.xpenc/)

[**🌐 Website**](https://getxpenc.vercel.app) · [**⬇️ Download APK**](https://github.com/PATILYASHH/XPENC/releases/latest) · [**🐛 Report a bug**](../../issues/new?template=bug_report.yml) · [**✨ Request a feature**](../../issues/new?template=feature_request.yml) · [**🏦 Add your bank**](../../issues/new?template=bank_support.yml)

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

📐 The complete design doc — mental model, data model, every decision and the
adversarial audit that hardened it — is in [structure.md](structure.md).

## Features

| | |
|---|---|
| 💳 **Honest accounts** | Cash / Bank / Card with real balances. Debit cards & UPI are *linked instruments* — they spend their bank's money, so rupees are never counted twice. Credit cards carry their own (negative = owed) balance. |
| 🔁 **Income · Expense · Transfer** | Three transaction types, kept strictly apart. Transfers never pollute budgets or reports. |
| 🎯 **Budgets** | Per-category with period windows, live progress, and once-per-period alerts at 80% and overspend. |
| 📩 **Bank-SMS auto-capture** — *coming soon* | Shipped in 1.0, paused in 1.1: the `READ_SMS` permission made Google Play Protect block direct APK installs. The on-device pipeline (parser · dedupe · review cards · Auto-Approve with real Undo) is intact and returns in a Play-compliant form. |
| 👥 **Persons — dues & loans** | They-owe / I-owe with running balances, partial settlements, optional real account movement. |
| 📅 **Calendar & cash reminders** | Day-wise in/out grid; EMI/bill reminders that post *nothing* until you confirm. |
| 📊 **Insights** | Category pie, income vs expense, net-worth trend, per-account reports — one chart engine, many views. |
| 💾 **Backup & export** | Symmetric JSON backup/restore + CSV shaped for accountants / Tally. |
| 🖤 **Monochrome UI** | Material 3, One UI–inspired, true-black AMOLED dark theme. |

## Download

### F-Droid — recommended

[**f-droid.org/packages/com.yash.xpenc**](https://f-droid.org/packages/com.yash.xpenc/)

You get automatic updates, and F-Droid builds the app **from this source tree
themselves** — nobody has to trust a binary I uploaded. The right ABI is picked
for your phone automatically.

### Direct APK

Or grab it from [**Releases**](https://github.com/PATILYASHH/XPENC/releases/latest)
/ the [website](https://getxpenc.vercel.app#download):

| Your phone | Asset |
|---|---|
| Most phones (~2017+) | [`xpenc-arm64-v8a.apk`](https://github.com/PATILYASHH/XPENC/releases/latest/download/xpenc-arm64-v8a.apk) |
| Older 32-bit phones | [`xpenc-armeabi-v7a.apk`](https://github.com/PATILYASHH/XPENC/releases/latest/download/xpenc-armeabi-v7a.apk) |
| Emulators | [`xpenc-x86_64.apk`](https://github.com/PATILYASHH/XPENC/releases/latest/download/xpenc-x86_64.apk) |

Every release ships `SHA256SUMS.txt` — verify your download. APKs are built,
tested and gated by [GitHub Actions](.github/workflows/release.yml); the
[release process](docs/RELEASING.md) is fully automated from a version tag.

> **Switching between F-Droid and a direct APK?** They're signed with different
> keys, so Android won't update one over the other. Migrate with
> **Backup → export JSON**, uninstall, install from the new source, then restore.

## Privacy

Everything is stored on-device in the app's private SQLite database. Since
1.1.0 the app requests **no SMS permission at all** — the only runtime
permission is notifications. No transaction or balance ever leaves the phone.
**There is no server.**
Full policy: [PRIVACY.md](PRIVACY.md) · live at [getxpenc.vercel.app/privacy](https://getxpenc.vercel.app/privacy).
See [SECURITY.md](SECURITY.md) for the vulnerability disclosure policy.

## Tech stack

| Concern | Choice |
|---|---|
| Framework | Flutter 3.38.9 · Dart 3.10.8 |
| State | Riverpod |
| Database | Drift (SQLite), local-first, reactive queries |
| Routing | go_router |
| Charts | fl_chart |
| Notifications | flutter_local_notifications + timezone |

> ⚠️ Several packages are **deliberately pinned** (drift 2.31.0, riverpod 2.6.1, …).
> Do not bump them without reading the "Pinned dependencies" section of
> [CONTRIBUTING.md](CONTRIBUTING.md) — one of those bumps once shipped an APK
> that crashed on first open.

## Building from source

```sh
git clone https://github.com/PATILYASHH/XPENC.git
cd XPENC
flutter pub get
flutter run
```

### Tests

```sh
rm -rf build/native_assets   # Windows only: Flutter native-assets bug
flutter analyze
flutter test
```

The widget tests render every screen against a real in-memory database at a real
phone size (360 × 800 dp) and fail on a layout overflow, so they catch what
`flutter analyze` cannot. `test/branding_test.dart` additionally fails the build
if `AppInfo.version` ever drifts from the `version:` line in `pubspec.yaml`.

### Shipping an APK

```sh
flutter build apk --release --split-per-abi
bash tool/verify_apk.sh build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
```

`verify_apk.sh` **must pass.** It is the only thing standing between you and
shipping an APK with no `libsqlite3.so` — a failure no unit test can see,
because every test overrides the database with an in-memory one.

### Code generation

Database classes are generated from `lib/data/tables.dart` by drift. After
changing a table:

```sh
dart run build_runner build --force-jit --delete-conflicting-outputs
```

**`--force-jit` is required** — without it build_runner fails with
`'dart compile' does not support build hooks` on this SDK. Schema-change
steps are in [CONTRIBUTING.md](CONTRIBUTING.md#changing-the-database-schema).

## Brand

<img src="branding/xpenc_icon_512.png" width="72" align="right" alt="XPENC icon">

Every asset — launcher icons, adaptive icon, Android 13 themed icon, splash
marks, favicons and the website icons — is generated from **one geometric
definition**:

```sh
python tool/generate_icons.py
```

Nothing is hand-drawn, so the icons cannot drift out of sync. The in-app logo
(`lib/core/branding/brand_mark.dart`) redraws the same geometry as a
`CustomPainter`, so it stays sharp at any size and follows the theme.

## Project structure

```
lib/
  core/          theme, Money type, branding, notifications
  data/          drift database, tables, DAOs, seed data
  domain/        entities, repository interfaces
  features/      one folder per screen (dashboard, transactions, budgets, …)
website/         landing page (Vercel)
tool/            icon generator, APK verification gate
.github/         CI + release workflows, issue & PR templates
docs/            releasing / maintainer docs
```

## Contributing

Contributions are very welcome — the highest-impact one is
[**adding an SMS template for your bank**](../../issues/new?template=bank_support.yml)
(config + regex, no app internals needed).

- 📖 [CONTRIBUTING.md](CONTRIBUTING.md) — setup, invariants, PR checklist
- 🤝 [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md)
- 🔒 [SECURITY.md](SECURITY.md) — private vulnerability reporting
- 📦 [CHANGELOG.md](CHANGELOG.md) · [docs/RELEASING.md](docs/RELEASING.md) — SemVer, `v*` tags, automated releases

## Sponsor

XPENC is free, open source, and has no ads, no trackers and no paid tier — and
it stays that way. If it keeps your money honest, you can fund the work:

[![Sponsor XPENC](https://img.shields.io/badge/♥%20Sponsor-PATILYASHH-ea4aaa?style=for-the-badge&logo=githubsponsors&logoColor=white&labelColor=black)](https://github.com/sponsors/PATILYASHH)

Not in a position to sponsor? A ⭐, a bug report, or
[an SMS template for your bank](../../issues/new?template=bank_support.yml)
helps just as much.

## Developer

**Yash Patil** — GitHub [@PATILYASHH](https://github.com/PATILYASHH) · LinkedIn [in/patilyasshh](https://www.linkedin.com/in/patilyasshh/)

## License

[MIT](LICENSE) © 2026 Yash Patil

<div align="center">
<sub>If XPENC keeps your money honest, a ⭐ keeps the project alive.</sub>
</div>
