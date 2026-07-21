# XPENC Wiki

**XPENC** is an offline-first personal finance app. Your ledger, budgets and
dues live on your device — nothing is ever uploaded. This wiki documents each
release and how to upgrade safely.

> **Latest release: 1.2.0** — subcategories, dues & owes on the dashboard, all
> world currencies, and one-tap import to move to a new phone.
> Read the [1.2.0 Release Notes](Release-Notes-1.2.0.md).

## Pages

- **[Release Notes — 1.2.0](Release-Notes-1.2.0.md)** — what's new, how each
  feature works.
- **[Upgrade Guide](Upgrade-Guide.md)** — how updating works, moving to a new
  phone, and keeping your data safe.

## Quick links

- Website: <https://getxpenc.vercel.app>
- Download the latest APKs: <https://github.com/PATILYASHH/XPENC/releases/latest>
- Privacy policy: <https://getxpenc.vercel.app/privacy>
- Report a bug or request a feature:
  <https://github.com/PATILYASHH/XPENC/issues/new/choose>
- Full changelog: [CHANGELOG.md](https://github.com/PATILYASHH/XPENC/blob/master/CHANGELOG.md)

## Good to know

- **Offline by design.** XPENC requests no internet and no SMS permission. Your
  data leaves the phone only when *you* export or share it.
- **Your data survives updates.** The database migrates itself in place, so
  installing a newer version over an older one keeps everything. See the
  [Upgrade Guide](Upgrade-Guide.md).
- **Money is exact.** Every amount is stored as an integer number of minor
  units (paise/cents) — never a floating-point number.
