# Google Play release checklist

The GitHub-releases pipeline ([docs/RELEASING.md](../RELEASING.md)) stays as-is.
Play is an **additional** channel with its own artifact (AAB, not APK) and its own gates.

---

## ⚠️ Blockers found in the current repo (fix before first upload)

1. **No upload keystore yet.** The gradle config in
   [android/app/build.gradle.kts](../../android/app/build.gradle.kts) already
   signs with `android/key.properties` when it exists and falls back to debug
   signing when it doesn't — but until the keystore is generated ("Signing
   setup" below), every release build is debug-signed and Play rejects it.
2. **Personal dev accounts created after 13 Nov 2023 cannot publish straight to
   production.** Google requires a closed test with **≥ 12 testers opted in for 14
   consecutive days** before you can apply for production access
   ([policy](https://support.google.com/googleplay/android-developer/answer/14151465)).
   Recruit testers early — friends, college, r/AndroidClosedTesting-style communities.

## One-time setup

### 1. Developer account
- [ ] Register at [play.google.com/console](https://play.google.com/console) — $25 one-time, ID verification required.
- [ ] Personal account is fine (no D-U-N-S needed); the 12-tester rule above applies.

### 2. Signing setup

- [ ] Generate the upload keystore (**keep it out of git, back it up twice** — losing it is recoverable only via Play support since Play App Signing holds the real app key, but don't test that):

```powershell
keytool -genkey -v -keystore $env:USERPROFILE\xpenc-upload.jks `
  -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

- [ ] Create `android/key.properties` (already gitignored via `android/.gitignore` lines 12–14, along with `*.jks`):

```properties
storePassword=<password>
keyPassword=<password>
keyAlias=upload
storeFile=C:/Users/admin/xpenc-upload.jks
```

- [x] `android/app/build.gradle.kts` — **already wired up** (falls back to debug
  signing when `key.properties` is absent, so contributor builds keep working):

```kotlin
import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    // ...
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = keystoreProperties["storeFile"]?.let { file(it) }
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

- [ ] Enroll in **Play App Signing** when creating the app (default for new apps): Google
  keeps the app signing key, your keystore is only the *upload* key.
- [ ] Re-point the GitHub `release.yml` APKs at the same upload key (secrets:
  base64-encoded keystore + passwords) so sideload builds stop being debug-signed.

> **Sideload → Play migration caveat:** existing GitHub-APK installs (debug-signed) have
> a different signature from both future GitHub builds and Play builds — Android will
> refuse to update over them. Users migrate by: in-app JSON backup → uninstall →
> install from Play → restore. Put that in the release notes of the first Play version.

### 3. Create the app in Play Console
- [ ] App name `XPENC: Expense Tracker`, default language English (India), **App**, **Free**.
  (Free is permanent — a free app can never become paid.)
- [ ] Package `com.yash.xpenc` is fixed forever after first upload.

### 4. Fill every console section (copy from these docs)
- [ ] Store listing → [store-listing.md](store-listing.md) (incl. icon, feature graphic, ≥4 screenshots)
- [ ] App content declarations → [declarations.md](declarations.md)
- [ ] Data safety → [data-safety.md](data-safety.md)
- [ ] Content rating → [content-rating.md](content-rating.md)
- [ ] Countries: all (or start with India + a few, expand later)

## Per-release

- [ ] Bump `version:` in `pubspec.yaml` — the `+N` build number is Play's `versionCode`
  and **must strictly increase** on every upload.
- [ ] `flutter analyze` and `flutter test` pass.
- [ ] Build the Play artifact (AAB is mandatory on Play; APKs remain for GitHub):

```sh
flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab
```

- [ ] Target API check: new apps and updates must target **API 35 today, API 36 from
  31 Aug 2026** ([policy](https://support.google.com/googleplay/android-developer/answer/11926878)).
  Verified 12 Jul 2026: current toolchain builds with **targetSdk 36** ✅ (minSdk 24).
  Re-confirm on the built artifact after any Flutter upgrade:

```sh
# Android SDK build-tools required
aapt2 dump badging build/app/outputs/flutter-apk/app-arm64-v8a-release.apk | grep targetSdk
```

- [ ] `bash tool/verify_apk.sh` still gates the GitHub APKs (checks libsqlite3 + confirms
  no SMS permissions). Play's **pre-launch report** covers the AAB — read it, it runs
  the app on real devices and flags crashes/accessibility issues.
- [ ] Upload AAB: **Internal testing** first (instant, up to 100 testers) → sanity-check
  install/upgrade → promote to **Closed testing**.
- [ ] First release only: keep ≥ 12 testers opted in for 14 consecutive days, answer the
  production-access questions, then apply for production.
- [ ] Production: use a **staged rollout** (start 10–20%), watch Android vitals + crash
  rate for a couple of days, then 100%.
- [ ] Release notes ≤ 500 chars (template in [store-listing.md](store-listing.md)).

## Review-rejection insurance

Most common Finance-adjacent rejection causes, pre-answered here:
- Data safety vs privacy policy mismatch → both say "nothing collected"; keep in sync in the same PR.
- Debug-signed artifact → fixed by signing setup.
- Broken privacy policy URL → it's static on Vercel; check it loads before each submission.
- Restricted permission (SMS) → not requested; `tool/verify_apk.sh` fails the build if it returns.
- Financial-services documentation demands → see the "Financial features" rationale in [declarations.md](declarations.md).
