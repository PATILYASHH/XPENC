
<div align="center">

<img src="branding/xpenc_banner.svg" width="640" alt="XPENC — Money, tracked honestly.">

[![F-Droid](https://img.shields.io/f-droid/v/com.yash.xpenc?label=F-Droid&logo=fdroid&logoColor=white&color=white&labelColor=black)](https://f-droid.org/packages/com.yash.xpenc/)
[![Release](https://img.shields.io/github/v/release/PATILYASHH/XPENC?label=release&color=white&labelColor=black)](https://github.com/PATILYASHH/XPENC/releases/latest)
[![CI](https://github.com/PATILYASHH/XPENC/actions/workflows/ci.yml/badge.svg)](https://github.com/PATILYASHH/XPENC/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-white?labelColor=black)](LICENSE)
[![Downloads](https://img.shields.io/github/downloads/PATILYASHH/XPENC/total?color=white&labelColor=black)](https://github.com/PATILYASHH/XPENC/releases)

### Offline-first personal finance for Android.
Income, expenses, transfers, budgets and dues — all on-device. Nothing is ever uploaded.

[<img src="https://fdroid.gitlab.io/artwork/badge/get-it-on.png" alt="Get it on F-Droid" height="62">](https://f-droid.org/packages/com.yash.xpenc/)

[🌐 Website](https://xpenc.in) · [⬇️ Download APK](https://github.com/PATILYASHH/XPENC/releases/latest) · [🐛 Report a bug](../../issues/new?template=bug_report.yml) · [✨ Request a feature](../../issues/new?template=feature_request.yml) · [🏦 Add your bank](../../issues/new?template=bank_support.yml)

<a href="https://www.instagram.com/xpenc.in/"><img src="https://cdn.simpleicons.org/instagram/E4405F" width="30" height="30" alt="Instagram"></a>&nbsp;&nbsp;
<a href="https://discord.gg/cCajrhHez"><img src="https://cdn.simpleicons.org/discord/5865F2" width="30" height="30" alt="Discord"></a>&nbsp;&nbsp;
<a href="mailto:feedback.yashpatil@gmail.com?subject=XPENC%20feedback"><img src="https://cdn.simpleicons.org/gmail/D14836" width="30" height="30" alt="Email"></a>&nbsp;&nbsp;
<a href="https://github.com/PATILYASHH/XPENC/discussions"><img src="https://cdn.simpleicons.org/github/181717" width="30" height="30" alt="GitHub Discussions"></a>&nbsp;&nbsp;
<a href="https://www.reddit.com/user/XPENC/"><img src="https://cdn.simpleicons.org/reddit/FF4500" width="30" height="30" alt="Reddit"></a>&nbsp;&nbsp;
<a href="https://testimonial.to/xpenc/"><img src="https://cdn.simpleicons.org/trustpilot/00B67A" width="30" height="30" alt="Feedback"></a>

</div>

> **Net worth = the sum of all account balances.** A transfer leaves it
> unchanged, income raises it, expense lowers it — enforced everywhere, so the
> ledger never lies to you. Amounts are integer **paise**, never floats.
> Full design rationale: [structure.md](structure.md).

## Highlights

- 💳 **Honest accounts** — Cash / Bank / Card / Prepaid, with debit cards & UPI as linked instruments so rupees are never double-counted
- 🎯 **Budgets & Envelope Mode** — per-category caps, live progress, 80%/overspend alerts, opt-in "every rupee has a job"
- 🐷 **Goals & Loans**, 🛍️ **Shopping lists**, 📅 **Calendar & reminders**, 🔒 **PIN + biometric lock**
- 📩 **Share it in** — bank SMS or a payment screenshot, parsed on-device (no `READ_SMS`, no network)
- 👥 **Persons** — dues/loans with running balances, group splits, UPI Pay/Request
- 📊 **Insights** — pie/trend charts, per-account reports, downloadable PDF
- 💾 **Backup & export** — JSON backup + Tally-ready CSV, with auto-backup and retention
- 🎨 **Seven themes**, 📱 **home screen widget**, ➕ customizable bottom nav

Full feature list and every decision behind it: [structure.md](structure.md) · [CHANGELOG.md](CHANGELOG.md)

## Download

**[F-Droid](https://f-droid.org/packages/com.yash.xpenc/)** is recommended — auto-updates, and the app is built **from this source** by F-Droid itself.

Or grab an APK from [Releases](https://github.com/PATILYASHH/XPENC/releases/latest) ([`arm64-v8a`](https://github.com/PATILYASHH/XPENC/releases/latest/download/xpenc-arm64-v8a.apk) for most phones since ~2017). Every release ships `SHA256SUMS.txt`.

> Switching source (F-Droid ↔ direct APK)? They're signed differently, so Android won't update across them — **Backup → export JSON**, uninstall, reinstall, restore.

## Privacy

Everything lives in the app's private on-device SQLite database. No SMS permission, no server, no analytics. [PRIVACY.md](PRIVACY.md) · [xpenc.in/privacy](https://xpenc.in/privacy) · [SECURITY.md](SECURITY.md)

## Contributing

Contributions are welcome — the highest-impact one is [adding an SMS template for your bank](../../issues/new?template=bank_support.yml).

📖 [CONTRIBUTING.md](CONTRIBUTING.md) (setup & PR checklist) · 🤝 [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) · 📦 [docs/RELEASING.md](docs/RELEASING.md)

## Sponsor

XPENC is free, open source, and has no ads, trackers or paid tier.

[![Sponsor XPENC](https://img.shields.io/badge/♥%20Sponsor-PATILYASHH-ea4aaa?style=for-the-badge&logo=githubsponsors&logoColor=white&labelColor=black)](https://github.com/sponsors/PATILYASHH)

Can't sponsor? A ⭐, a bug report, or [a bank SMS template](../../issues/new?template=bank_support.yml) helps just as much.

---

<div align="center">

**[MIT](LICENSE) © 2026 Yash Patil** — GitHub [@PATILYASHH](https://github.com/PATILYASHH) · LinkedIn [in/patilyasshh](https://www.linkedin.com/in/patilyasshh/)

<sub>If XPENC keeps your money honest, a ⭐ keeps the project alive.</sub>

</div>
