# XPENC Privacy Policy

**Effective date:** 12 July 2026
**Applies to:** XPENC for Android (package name `com.yash.xpenc`), version 1.1.0 and later
**Developer:** Yash Patil (individual developer)
**Contact:** banafintech@gmail.com

This policy is published at <https://getxpenc.vercel.app/privacy> and mirrored in the
app's source repository at <https://github.com/PATILYASHH/XPENC/blob/master/PRIVACY.md>.

## The short version

XPENC stores everything on your phone and nothing anywhere else. The app has
**no server, no user accounts, no analytics, no crash reporting, no ads, and no
third-party SDKs that collect data**. Release builds do not request the
`INTERNET` permission, so the app is technically incapable of transmitting your
data anywhere.

## Data the app stores — on your device only

When you use XPENC you create financial records:

- accounts and their balances (cash, bank, cards)
- transactions (income, expenses, transfers) with amounts, dates, categories and notes
- budgets and budget alerts
- persons and dues/loans you record against them
- reminders and calendar entries
- app settings

All of this is stored in a private SQLite database inside the app's private
storage area, which Android sandboxes from other apps. It is **never
transmitted** to the developer or to any third party. The developer has no way
to see, access, or recover it.

## Data the app collects or shares

**None.** XPENC collects no personal data, no financial data, no device
identifiers, no usage analytics, and no diagnostics. Nothing is shared with
anyone, because nothing ever leaves the device. The app's Google Play Data
safety section accordingly declares *no data collected, no data shared*.

## Permissions

| Permission | Why the app requests it |
|---|---|
| `POST_NOTIFICATIONS` (optional, asked at runtime) | To show budget alerts and the bill/EMI reminders you set. If you deny it, the app works normally — you just get no notifications. |
| `RECEIVE_BOOT_COMPLETED` | To re-schedule your local reminders after the phone restarts. |

XPENC requests **no** SMS, location, camera, microphone, contacts, storage, or
internet permission. (The final app package also contains `VIBRATE` — a
standard, install-time permission added by the notifications library so
notifications can vibrate — and an internal Android-library permission scoped
to the app itself. Neither gives access to any of your data.)

## Backups and exports

- **In-app backup/export (JSON and CSV):** these are created only when you tap
  the button, and are handed to the Android share sheet — you choose where the
  file goes (your files, your email, your cloud drive). Exported files contain
  your financial records in readable form, so treat them as sensitive. The
  developer never receives them.
- **Android system backup:** like most Android apps, XPENC's data may be
  included in your device's own backup (for example Google's device backup tied
  to your Google account) if you have that enabled in Android settings. That
  backup is operated by Android/Google under your device settings and Google's
  privacy policy, not by XPENC.

## Data retention and deletion

Your data stays on your device until **you** remove it. You can:

1. delete individual records inside the app,
2. clear the app's data in Android settings (*Apps → XPENC → Storage → Clear data*), or
3. uninstall the app — Android deletes the app's private storage with it.

There is no server-side copy to delete, and no "account" to close.

## Children

XPENC is a personal finance tool intended for adults. It is not directed at
children under 13, and it collects no data from anyone regardless of age.

## The website

The download website <https://getxpenc.vercel.app> is a static page hosted on
Vercel. It runs no analytics or trackers. Like any web host, Vercel may keep
standard access logs (IP address, user agent) to operate the service — see
[Vercel's privacy policy](https://vercel.com/legal/privacy-policy). The page
loads fonts from Google Fonts, an optional 3D effect from the jsDelivr CDN, and
the latest release number from the GitHub API; those requests are made by your
**browser when you visit the website**, never by the Android app.

## Open source

XPENC is open source under the MIT license. Every claim in this policy can be
verified by reading the code: <https://github.com/PATILYASHH/XPENC>.

## Future features: bank-message capture

Version 1.0 offered on-device scanning of bank SMS to pre-fill transactions; it
was removed in version 1.1.0 and the current app requests no SMS permission.
If this feature returns, it will be announced in the release notes, this policy
and the Play Store Data safety section will be updated **before** release, and
processing will remain fully on-device.

## Changes to this policy

Updates are published at <https://getxpenc.vercel.app/privacy> with a new
effective date. Material changes will also be called out in the
[changelog](https://github.com/PATILYASHH/XPENC/blob/master/CHANGELOG.md) and
release notes.

## Contact

Questions or concerns about privacy:

- Email: **banafintech@gmail.com**
- Bug reports: [GitHub issues](https://github.com/PATILYASHH/XPENC/issues)
- Security vulnerabilities: [private reporting](https://github.com/PATILYASHH/XPENC/security) — see [SECURITY.md](SECURITY.md)
