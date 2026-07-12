# Play Store submission kit

Everything needed to put XPENC on Google Play, verified against Google's current
(July 2026) requirements. Each file maps to one Play Console section — fill them in
this order:

| # | Step | Doc | Console location |
|---|---|---|---|
| 1 | Create dev account, **start recruiting 12 closed-testers now** (14-day rule) | [release-checklist.md](release-checklist.md) | — |
| 2 | Fix release signing (currently debug-signed — hard blocker) | [release-checklist.md](release-checklist.md) | — |
| 3 | Privacy policy — live at [getxpenc.vercel.app/privacy](https://getxpenc.vercel.app/privacy), source [`PRIVACY.md`](../../PRIVACY.md) / [`website/privacy.html`](../../website/privacy.html) | — | App content → Privacy policy |
| 4 | Store listing copy + graphics | [store-listing.md](store-listing.md) | Store presence → Main store listing |
| 5 | Data safety form | [data-safety.md](data-safety.md) | App content → Data safety |
| 6 | Content rating questionnaire | [content-rating.md](content-rating.md) | App content → Content ratings |
| 7 | All other declarations (ads, target audience, financial features, advertising ID, …) | [declarations.md](declarations.md) | App content |
| 8 | Build AAB, internal → closed (14 days, ≥12 testers) → production | [release-checklist.md](release-checklist.md) | Test and release |

## The one-paragraph story (reused everywhere)

> XPENC is an offline-first personal expense tracker. All data lives in a private
> SQLite database on the device; the release build does not request the INTERNET
> permission, so nothing can be transmitted. No accounts, no ads, no analytics, no
> third-party data SDKs. Open source (MIT) at github.com/PATILYASHH/XPENC.

Every form answer derives from that paragraph. If a future feature breaks any clause of
it (SMS capture, sync, donations…), grep this folder — each doc has a "re-do when" section.

## Still to create (not code)

- [x] Feature graphic 1024×500 — `branding/playstore_feature_graphic.png`
      (`python tool/generate_playstore_assets.py`)
- [ ] 4–8 phone screenshots ≥ 1080 px
- [ ] Play Console developer account ($25)
- [ ] Upload keystore + `android/key.properties` — the gradle side is already
      wired up; only the `keytool` step in [release-checklist.md](release-checklist.md) remains
