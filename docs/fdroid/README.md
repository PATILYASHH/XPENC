# F-Droid submission kit

Everything needed to get XPENC onto [F-Droid](https://f-droid.org), verified against
the [inclusion policy](https://f-droid.org/en/docs/Inclusion_Policy/), the
[Flutter build template](https://gitlab.com/fdroid/fdroiddata/-/blob/master/templates/build-flutter.yml)
and the [fastlane metadata spec](https://f-droid.org/docs/All_About_Descriptions_Graphics_and_Screenshots/)
(July 2026).

## Inclusion-criteria audit — XPENC passes

| Criterion | Status |
|---|---|
| FLOSS license | ✅ MIT, `LICENSE` at repo root |
| No Google Play Services / Firebase / Crashlytics | ✅ none — pure Flutter + androidx |
| No proprietary dependencies | ✅ all pub packages are BSD/MIT/Apache (riverpod, drift, go_router, fl_chart, intl, flutter_local_notifications, timezone, flutter_slidable, sqlite3_flutter_libs, path_provider, share_plus, url_launcher) |
| No ads / trackers / analytics | ✅ zero; release builds have **no INTERNET permission** |
| No binary blobs in the repo | ✅ verified — no .jar/.aar/.so/.ttf tracked (`branding/fonts/` is gitignored) |
| Flutter SDK prebuilt binaries | ✅ explicitly permitted by F-Droid policy |
| Buildable from source | ✅ `flutter build apk` from a clean checkout; `pubspec.lock` committed, recipe uses `--enforce-lockfile` |
| Tagged releases | ✅ `v*` tags, automated by `.github/workflows/release.yml` |
| Unique application id | ✅ `com.yash.xpenc` |

No anti-features apply (no NonFreeNet, no NonFreeDep, no Ads, no Tracking).

## What lives where

| Piece | Location | Consumed by |
|---|---|---|
| App texts (title, summary, description) | `fastlane/metadata/android/en-US/*.txt` | F-Droid reads these **from this repo** at the tagged commit |
| Per-release changelogs | `fastlane/metadata/android/en-US/changelogs/<versionCode>.txt` | F-Droid "What's new" |
| Icon + feature graphic | `fastlane/metadata/android/en-US/images/` | F-Droid app page |
| Screenshots | `…/images/phoneScreenshots/` | ❌ still to capture (same set as Play) |
| Build recipe (draft) | [`metadata-com.yash.xpenc.yml`](metadata-com.yash.xpenc.yml) | copied into the **fdroiddata** repo, not this one |

## versionCode contract (important)

`pubspec.yaml` `version: X.Y.Z+N` → `flutter build apk --split-per-abi` emits:

| ABI | versionCode |
|---|---|
| armeabi-v7a | N + 1000 |
| arm64-v8a | N + 2000 |
| x86_64 | N + 4000 |

Verified with aapt on the 1.1.0+2 build (1002 / 2002 / 4002). The recipe's
`VercodeOperation` encodes exactly this. **On every release**, add
`changelogs/<N>.txt` plus copies named `<N+1000>.txt`, `<N+2000>.txt`,
`<N+4000>.txt` (see the 1.1.0 files for the pattern).

## How to submit (one-time)

0. **Tag `v1.1.1` first.** F-Droid reads the fastlane texts/images from the
   commit it builds, and the existing `v1.1.0` tag predates them. The repo is
   already prepared for this: `pubspec.yaml` is `1.1.1+3`, the fastlane
   screenshots/changelogs are in place, and the recipe below is already set to
   `commit: v1.1.1` with versionCodes `1003/2003/4003`. All that's left is
   `git tag v1.1.1 && git push origin master v1.1.1`.
1. Create a [GitLab](https://gitlab.com) account.
2. Fork [fdroiddata](https://gitlab.com/fdroid/fdroiddata), branch `com.yash.xpenc`.
3. Copy [`metadata-com.yash.xpenc.yml`](metadata-com.yash.xpenc.yml) to
   `metadata/com.yash.xpenc.yml` in the fork; **delete the header comments**.
4. Commit with message `New app: XPENC`, push, open a merge request. The MR
   template has a checklist; the CI pipeline runs `fdroid lint` + a test build —
   fix anything it flags.
5. Alternative low-effort path: open a
   [Request-for-Packaging issue](https://gitlab.com/fdroid/rfp/-/issues) and let a
   volunteer write the recipe. Slower; the direct MR is preferred since the
   recipe is already drafted.

Review can take anywhere from days to a couple of months depending on volunteer
load — respond promptly to reviewer comments on the MR. Once merged, the app
appears on f-droid.org after the next build cycle (typically a few days).

## Maintenance after acceptance

- **Releases are picked up automatically**: `AutoUpdateMode: Version` +
  `UpdateCheckMode: Tags` watch the repo's `v*` tags and read the version from
  `pubspec.yaml`. Tag → F-Droid builds it. No MR needed per release.
- **Except** when the Flutter version changes: the recipe pins
  `flutter@3.38.9`; a Flutter upgrade needs a one-line MR to fdroiddata (or a
  reviewer may switch the recipe to extract the version from
  `.github/workflows/release.yml` — accept that suggestion if offered).
- Keep the fastlane texts in sync with the Play listing when copy changes.

## Signature caveat (put in release notes when F-Droid goes live)

F-Droid builds from source and signs with **F-Droid's key**. That is a third
signature (GitHub APKs = upload key, Play = Play App Signing key). Android
refuses cross-signature updates, so a user switching stores must:
in-app JSON backup → uninstall → install from the new store → restore.

Reproducible builds (which would let F-Droid ship the developer-signed APK)
are possible with Flutter but finicky; revisit only if users ask.

## Re-do when…

- **Bank-SMS capture returns** — update `full_description.txt` and the
  changelog; F-Droid has no permission-review gate like Play, but the
  description must stay honest.
- Any dependency with a non-FLOSS license is added — it will fail the
  fdroiddata scanner and the app gets dropped.
- The version scheme in `pubspec.yaml` or the ABI split set changes — the
  `VercodeOperation` lines must change with it.
