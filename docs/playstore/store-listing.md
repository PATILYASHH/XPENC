# Play Store listing — copy & assets

Everything to paste into **Play Console → Grow → Store presence → Main store listing**.
Character limits are Google's current ones: app name **30**, short description **80**,
full description **4000** ([source](https://support.google.com/googleplay/android-developer/answer/9859152)).

Play's metadata policy forbids ranking claims ("best", "#1", "top"), price/promo text,
emoji or repeated punctuation in the app name, and ALL-CAPS words that aren't the brand.
The copy below is written to comply — edit carefully.

---

## App name (30 chars max)

```
XPENC: Expense Tracker
```

22 characters. Alternative if a plainer name is wanted: `XPENC — Money Tracker` (21).

## Short description (80 chars max)

```
Offline expense tracker: accounts, budgets, dues & insights. No ads, no signup.
```

79 characters.

## Full description (4000 chars max)

```
XPENC is a personal finance app that keeps every rupee on your phone. There is no server, no account to create and no ads — your transactions live in a private database on your device and never leave it.

HONEST NUMBERS
Most expense apps blur where money sits with what it was for. XPENC keeps them apart and enforces one rule everywhere: net worth equals the sum of your account balances. A transfer between your own accounts leaves it unchanged, income raises it, expense lowers it.

• Accounts — Cash, Bank and Card with real balances. Debit cards and UPI are linked instruments that spend their bank's money, so a payment is never counted twice. Credit cards carry their own balance.
• Income, Expense, Transfer — three transaction types kept strictly apart. Transfers never pollute budgets or reports.
• Budgets — per-category budgets with period windows, live progress, and alerts at 80% and on overspend.
• Dues & loans — track what people owe you and what you owe them, with partial settlements and running balances. Lending is not spending, so dues stay out of your budgets and reports.
• Calendar — a day-wise money-in / money-out grid, plus EMI and bill reminders that post nothing until you confirm them.
• Insights — category breakdown, income vs expense, net-worth trend and per-account reports.
• Backup & export — one-tap JSON backup and restore, plus CSV export shaped for accountants.
• True-black design — a clean, monochrome Material 3 interface that is easy on AMOLED screens and on the eyes.

PRIVATE BY ARCHITECTURE
• Works fully offline — the app makes no network calls at all.
• No sign-up, no account, no cloud.
• No analytics, no trackers, no ads.
• The only runtime permission is notifications, used for the budget alerts and reminders you set.
• Backups are files you create and keep — you decide where they go.

ACCURATE BY DESIGN
All money math is done in whole paise, never floating point, so totals are always exact. Transfers, dues and settlements can never double-count a payment or invent income.

OPEN SOURCE
XPENC is open source under the MIT license. You can read every line of code, verify the privacy claims yourself, and contribute at github.com/PATILYASHH/XPENC
```

2,252 characters — comfortable headroom for future features (bank-message capture, when it returns in a Play-compliant form).

## Release notes / "What's new" (500 chars max, per release)

First Play release:

```
First release on Google Play!
• Accounts, income/expense/transfer, budgets with alerts
• Dues & loans with partial settlements
• Calendar view and bill/EMI reminders
• Insights: category breakdown, income vs expense, net-worth trend
• JSON backup/restore and CSV export
• 100% offline — no account, no ads, no data leaves your phone
```

## Categorization

| Field | Value |
|---|---|
| App or game | App |
| Category | **Finance** |
| Tags (pick up to 5 in Console) | Personal finance, Budgeting, Expense tracking |
| Free or paid | Free |
| Contains ads | No |
| In-app purchases | No |

## Contact details (Store settings → Store listing contact details)

| Field | Value |
|---|---|
| Email (required, shown publicly) | patilyasshh@gmail.com |
| Website | https://getxpenc.vercel.app |
| Phone | optional — leave blank |
| External marketing | opt out if unwanted |

## Graphic assets

| Asset | Spec | Status |
|---|---|---|
| App icon | 512×512, 32-bit PNG, ≤ 1 MB | ✅ already generated: `branding/xpenc_icon_512.png` (`python tool/generate_icons.py`) |
| Feature graphic | 1024×500 PNG/JPEG, ≤ 15 MB — **required** | ✅ `branding/playstore_feature_graphic.png` — regenerate with `python tool/generate_playstore_assets.py` |
| Phone screenshots | 2–8 images, PNG/JPEG, ≤ 8 MB each, 16:9 or 9:16. For Play promotion slots: at least 4 at ≥ 1080 px | ❌ capture: Dashboard, Transactions, Budgets, Insights, Persons/Dues, Calendar (360×800 device or emulator, true-black theme) |
| 7" / 10" tablet screenshots | optional but unlocks tablet promotion | ❌ optional |
| Promo video | optional YouTube URL | skip for now |

Screenshot tips that pass review:
- Show real UI with sane demo data (the seed data works). No device frames with claims text, no "download now" banners.
- Don't show other apps' branding or real bank names/numbers.
- Keep status bar clean (use demo mode: `adb shell settings put global sysui_demo_allowed 1`).

## Languages

Start with **English (India)** or **English (United States)** as default. Hindi/Marathi
translations can be added later under "Manage translations".
