# Releasing XPENC

How a version goes from code to a downloadable APK on the website.
Only maintainers do this; contributors never need to.

## Versioning

XPENC follows [Semantic Versioning](https://semver.org): `MAJOR.MINOR.PATCH`.

| Bump | When |
|---|---|
| **MAJOR** | Backup/DB format breaks compatibility, or the money model changes |
| **MINOR** | New feature (new screen, new bank template, new export format) |
| **PATCH** | Bug fix, parser fix, UI polish |

The Android `versionCode` is the `+N` build number in `pubspec.yaml` —
increment it on **every** release, it can never go backwards.

## The pipeline

```
bump version → commit → tag vX.Y.Z → push tag
        └─► GitHub Actions (.github/workflows/release.yml)
                ├─ tag == pubspec version?   (hard gate)
                ├─ flutter analyze + test    (116+ tests)
                ├─ flutter build apk --release --split-per-abi
                ├─ tool/verify_apk.sh        (libsqlite3.so gate — never skip)
                └─ GitHub Release: xpenc-arm64-v8a.apk · xpenc-armeabi-v7a.apk
                                   · xpenc-x86_64.apk · SHA256SUMS.txt
        └─► website Download buttons point at /releases/latest/download/…
            so they update automatically. Nothing to deploy.
```

## Step by step

1. **Bump the version** in `pubspec.yaml`:

   ```yaml
   version: 1.1.0+3   # name +buildNumber — bump BOTH appropriately
   ```

2. **Mirror it** in `AppInfo.version` / `AppInfo.buildNumber`
   (`lib/core/branding/app_info.dart`). `test/branding_test.dart` fails if they drift —
   run `flutter test test/branding_test.dart` to check.

3. **Update `CHANGELOG.md`** — move entries from `[Unreleased]` into a new
   `[X.Y.Z] — YYYY-MM-DD` section and update the compare links at the bottom.

4. **Commit and tag:**

   ```sh
   git add pubspec.yaml lib/core/branding CHANGELOG.md
   git commit -m "chore(release): v1.1.0"
   git tag v1.1.0
   git push origin master --tags
   ```

5. **Watch the action** — the *Release APK* workflow must go green. If
   `verify_apk.sh` fails, the release is not published; fix, delete the tag,
   re-tag.

6. **Verify** — https://github.com/PATILYASHH/XPENC/releases/latest should show
   the new tag with 4 assets, and the website's version badge (fetched from the
   GitHub API) updates by itself.

## Asset names are a contract

The website links to `releases/latest/download/xpenc-arm64-v8a.apk` (and
`…-armeabi-v7a.apk`). **Never rename the release assets** in
`release.yml` without updating `website/index.html` in the same PR.

## Website deployment

The site lives in `website/` and is deployed on Vercel as project
`yash-projects/xpenc`, production domain **https://getxpenc.vercel.app**
(`xpenc.vercel.app` was already taken by another user). Deployment protection
is disabled on this project so the site is public.

To redeploy after editing the site:

```sh
cd website
vercel deploy --prod --yes
```

Optionally connect the repo in the Vercel dashboard (Root Directory: `website`,
Framework: Other, no build command) so pushes to `master` deploy automatically.

If the production domain ever changes, update the `og:url` / `og:image` meta
tags in `website/index.html` and the GitHub repo homepage.
