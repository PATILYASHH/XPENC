import java.util.Base64
import java.util.Properties
import java.io.FileInputStream
import com.android.build.gradle.internal.api.ApkVariantOutputImpl

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Play upload signing. The real keystore config lives in android/key.properties
// (gitignored — see docs/playstore/release-checklist.md). When it is absent
// (contributor machines, CI without secrets) release builds fall back to debug
// signing so `flutter run --release` keeps working; such builds cannot be
// uploaded to Play or ship as GitHub release assets.
// What `flutter build … --dart-define=K=V` passed — Flutter hands them to
// Gradle base64-encoded, comma-separated, as the `dart-defines` property.
val dartDefines: Map<String, String> =
    (project.findProperty("dart-defines") as String?)
        ?.split(",")
        ?.mapNotNull { encoded ->
            val decoded = try {
                String(Base64.getDecoder().decode(encoded))
            } catch (e: IllegalArgumentException) {
                return@mapNotNull null
            }
            val parts = decoded.split("=", limit = 2)
            if (parts.size == 2) parts[0] to parts[1] else null
        }
        ?.toMap()
        ?: emptyMap()

// Auto money tracking (Settings → Advanced Features) needs READ_SMS, and the
// permission is what Google acts on, not whether the feature is switched
// on: Play Protect blocks browser/file-manager installs of an APK that
// requests it (India and other regions), and Play only accepts it with an
// approved SMS declaration. So it's a per-build decision, off by default:
// a release build gets src/sms/AndroidManifest.xml only when built with
// `--dart-define=XPENC_SMS=on`. Debug builds always have it (src/debug).
// test/native_channel_test.dart guards which release builds pass it.
val smsCapture = dartDefines["XPENC_SMS"] == "on"

val keystorePropertiesFile = rootProject.file("key.properties")
val hasReleaseKeystore = keystorePropertiesFile.exists()
val keystoreProperties = Properties().apply {
    if (hasReleaseKeystore) load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.yash.xpenc"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications (uses java.time APIs on older
        // Android). Without this, :app:checkDebugAarMetadata fails.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // The app's permanent identity on Android. Play Store listings are keyed
        // on it, so it can never be changed after the first upload — and to a
        // device a new applicationId is simply a different app, installed
        // side by side, with its own empty private data directory.
        applicationId = "com.yash.xpenc"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // The Android Gradle Plugin embeds a "Dependency metadata" signing block in
    // every APK by default. F-Droid's scanner rejects it (opaque, non-auditable
    // dependency info), so leave it out. No effect on the app itself.
    dependenciesInfo {
        includeInApk = false
        includeInBundle = false
    }

    if (smsCapture) {
        sourceSets.getByName("release").manifest.srcFile("src/sms/AndroidManifest.xml")
    }

    signingConfigs {
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            // See proguard-rules.pro.
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// F-Droid Flutter versionCode scheme: base versionCode * 10 + ABI index
// (armeabi-v7a=1, arm64-v8a=2, x86_64=3), overriding Flutter's default
// split-per-abi offsets so the codes stay small and ordered and match the
// VercodeOperation in the fdroiddata recipe. Requested in F-Droid review.
val abiCodes = mapOf("armeabi-v7a" to 1, "arm64-v8a" to 2, "x86_64" to 3)
android.applicationVariants.configureEach {
    val variant = this
    variant.outputs.forEach { output ->
        val abiId = output.filters.find { it.filterType == "ABI" }?.identifier
        val abiVersionCode = abiCodes[abiId]
        if (abiVersionCode != null) {
            (output as ApkVariantOutputImpl).versionCodeOverride =
                variant.versionCode * 10 + abiVersionCode
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
