import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

/**
 * Upload key for Google Play (never in Git). Read from the environment
 * (CI: ANDROID_KEYSTORE_PATH, ANDROID_KEYSTORE_PASSWORD, ANDROID_KEY_ALIAS,
 * ANDROID_KEY_PASSWORD) or from android/key.properties (local Mac:
 * storeFile, storePassword, keyAlias, keyPassword). See docs/RELEASE_BETA.md.
 */
val uploadKey: Map<String, String>? = run {
    val env = System.getenv()
    if (!env["ANDROID_KEYSTORE_PATH"].isNullOrBlank()) {
        mapOf(
            "storeFile" to env.getValue("ANDROID_KEYSTORE_PATH"),
            "storePassword" to env["ANDROID_KEYSTORE_PASSWORD"].orEmpty(),
            "keyAlias" to env["ANDROID_KEY_ALIAS"].orEmpty(),
            "keyPassword" to env["ANDROID_KEY_PASSWORD"].orEmpty(),
        )
    } else {
        val file = rootProject.file("key.properties")
        if (!file.exists()) {
            null
        } else {
            val properties = Properties().apply { FileInputStream(file).use { load(it) } }
            properties.stringPropertyNames().associateWith { properties.getProperty(it) }
        }
    }
}

android {
    // Code namespace (R, BuildConfig, MainActivity); independent of the
    // store identity below and not visible to Google Play.
    namespace = "com.example.mybrev_flutter"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // Temporary Google Play test identity «MyBrev Test». Bound to the
        // Play Console app after the first upload: never rename it.
        applicationId = "by.mybrev.playtest2026"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (uploadKey != null) {
            create("upload") {
                storeFile = file(uploadKey.getValue("storeFile"))
                storePassword = uploadKey["storePassword"]
                keyAlias = uploadKey["keyAlias"]
                keyPassword = uploadKey["keyPassword"]
            }
        }
    }

    buildTypes {
        release {
            // Without an upload key (a developer Mac without key.properties,
            // the Codemagic debug workflow) a release build is debug-signed so
            // `flutter run --release` works; such a bundle is refused by the
            // release lane (fastlane android) and by Google Play.
            signingConfig = signingConfigs.findByName("upload")
                ?: signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
