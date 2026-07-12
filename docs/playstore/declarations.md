# App content declarations — exact answers

**Play Console → Monitor and improve → Policy and programs → App content**

Every item on this page must be completed before the first release can go for review.
One-line answers first, detail below where it matters.

| Declaration | Answer |
|---|---|
| Privacy policy | `https://getxpenc.vercel.app/privacy` |
| App access | **All functionality is available without special access** |
| Ads | **No, my app does not contain ads** |
| Content ratings | see [content-rating.md](content-rating.md) |
| Target audience and content | **18 and over** (see below) |
| News apps | **No** — not a news app |
| COVID-19 contact tracing / status apps | **No** |
| Data safety | see [data-safety.md](data-safety.md) |
| Advertising ID | **No, my app does not use advertising ID** (see below) |
| Government apps | **No** — not developed for/with a government |
| Financial features | **My app doesn't provide any financial features** (see below) |
| Health apps | **My app does not have any health features** |
| Account deletion | *(only shown if the app lets users create accounts — XPENC has none, so this section never applies)* |

## App access

XPENC has no login, no paywall, no region lock. Select
*"All functionality in my app is available without any access restrictions"*.
Nothing else to provide — reviewers can open the app and use everything.

## Target audience and content

Select **18 and over** only.

Why not younger: selecting any under-18 group adds Families-policy obligations
(ads restrictions, teacher-approval program, etc.) for zero benefit — an expense
tracker's audience is adults. This selection is about who the app *targets*, not
who may install it.

Follow-up question "Could your app unintentionally appeal to children?" → **No**
(monochrome finance tool: no cartoon characters, no game mechanics).

## Advertising ID (targetSdk 33+ apps must declare)

Answer **No**. None of the app's plugins are ad/analytics SDKs, so the merged manifest
must not contain `com.google.android.gms.permission.AD_ID`. Verify on the release
artifact before submitting — if the permission ever shows up, a plugin snuck it in:

```sh
aapt dump permissions build/app/outputs/flutter-apk/app-arm64-v8a-release.apk | grep -i AD_ID
# expected: no output
```

A "Yes" here with no ads SDK — or a "No" with AD_ID in the manifest — both trigger
rejections.

## Financial features

The form is mandatory for **all** apps ([policy](https://support.google.com/googleplay/android-developer/answer/13849271)).
Select: **"My app doesn't provide any financial features."**

Why that's the truthful answer: Google's Finance policy covers products and services that
manage or move money — loans, banking, payments/wallets, trading, crypto, insurance,
credit monitoring, personalized financial advice. XPENC is a **record-keeping tool**: it
never holds, moves, lends, invests, or advises on money; it has no connection to any
bank or payment network. Bookkeeping/budgeting apps are not on the declared-features
list.

If Play review ever pushes back (Finance category apps get extra scrutiny), reply with
exactly that: offline ledger, no INTERNET permission, no accounts, open source at
github.com/PATILYASHH/XPENC.

## ⚠️ Re-declare when…

- **Bank-SMS capture returns** → SMS is a *restricted permission*: a separate
  "Permissions declaration" form appears, requiring a core-functionality justification
  and a demo video. Plan that release carefully ([policy](https://support.google.com/googleplay/android-developer/answer/10208820)).
- UPI/payment integration, sync, or any monetization is added → Financial features and
  Data safety both change.
