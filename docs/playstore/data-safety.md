# Data safety form — exact answers

**Play Console → Monitor and improve → Policy and programs → App content → Data safety**

Google's rules ([official guide](https://support.google.com/googleplay/android-developer/answer/10787469)):
every app must complete this form, even one that collects nothing. "Collected" means
**transmitted off the device**. Two exemptions matter for XPENC:

- *On-device processing/storage* — data that never leaves the phone does **not** count as collected.
- *User-initiated sharing* — a user exporting their own file through the Android share
  sheet to a destination **they** choose does not count as collection or sharing by the app.

XPENC stores everything in local SQLite, has no analytics/ads SDKs, and release builds
don't request the `INTERNET` permission — nothing can transmit. So the form is short:

## Answers

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **No** |
| Is your app's data encrypted in transit? | *(not asked when nothing is collected)* |
| Do you provide a way for users to request data deletion? | *(not asked when nothing is collected)* |

Result on the store listing: **"No data collected · No data shared."**

## Privacy policy URL (required regardless)

```
https://getxpenc.vercel.app/privacy
```

Entered under **App content → Privacy policy**. The page must stay publicly reachable —
it deploys automatically from `website/privacy.html` on every push to `master`.

## Why "No" is truthful (keep for audit / review appeals)

| Data in the app | Off-device? |
|---|---|
| Transactions, balances, budgets, persons/dues | Local SQLite in app-private storage. Never transmitted. |
| JSON/CSV backup & export | Created only on user tap, handed to the Android share sheet; user picks destination → user-initiated transfer exemption. |
| Notifications | Generated locally by `flutter_local_notifications`. No push service, no tokens. |
| Crash / usage analytics | None. No Firebase, no Crashlytics, no ad SDK, no analytics SDK. |
| Network access | Release manifest requests no `INTERNET` permission — transmission is technically impossible. |

Third-party SDK check (their data collection would count as ours): Riverpod, Drift,
go_router, fl_chart, intl, flutter_local_notifications, timezone, flutter_slidable,
sqlite3_flutter_libs, path_provider, share_plus, url_launcher — all local-only
libraries; none phones home. `url_launcher` merely opens the system browser
(About screen links); the browser is outside the app.

## ⚠️ Re-do this form when…

- **Bank-SMS capture returns.** Even fully on-device processing must be re-examined; SMS
  is also a restricted permission with its own declaration + video review.
- Any SDK is added that touches the network (analytics, crash reporting, sync, ads).
- The `INTERNET` permission appears in the merged manifest for any reason. Check with:
  `aapt dump permissions app-release.apk` (or `tool/verify_apk.sh`).

A mismatch between this form, the privacy policy, and actual app behavior is a common
rejection/removal reason — keep all three in sync in the same PR.
