import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing, read from `android/key.properties` — which is gitignored, because a
// keystore password in the repository is the same thing as no keystore at all. See
// `android/key.properties.example` for the four keys and how to make the store.
//
// When the file is absent the release build falls back to the debug key. That is
// deliberate: `flutter run --release` and profiling a release build have to keep working
// on a fresh clone. It is also why `signingConfigIsRelease` exists — a debug-signed APK
// installs fine and looks completely normal, so without something saying so out loud you
// find out at the point where you cannot ship an update over it.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}
val signingConfigIsRelease = keystorePropertiesFile.exists()

android {
    namespace = "com.civortech.world_keeper"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.civortech.world_keeper"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (signingConfigIsRelease) {
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
            signingConfig = if (signingConfigIsRelease) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }

            // Not minified. R8 would strip the reflection dartssh2 and the secure-storage
            // plugin reach through, and the Dart side — which is all of this app — is
            // already tree-shaken and AOT-compiled by the Flutter build. There is nothing
            // here for it to win.
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

// A debug-signed release APK installs, runs and looks completely normal. What it cannot
// do is ever be updated: Android refuses to install a properly-signed build over it, so
// every user would have to uninstall — losing their profiles and their audit log — to
// move across. There is no way to tell from the APK's behaviour, only from its signature.
//
// A warning is not enough here, because Flutter swallows Gradle's output unless you pass
// `-v`. So anything that produces an artifact for other people has to ask for the
// guarantee explicitly, and gets a failed build rather than a shippable-looking file:
//
//     flutter build apk --release -PrequireReleaseSigning
//
// `.github/workflows/release.yml` always passes it. Plain `flutter build apk --release`
// still falls back to the debug key, so a fresh clone can build and run one.
if (project.hasProperty("requireReleaseSigning") && !signingConfigIsRelease) {
    throw GradleException(
        "-PrequireReleaseSigning was passed but android/key.properties does not exist, " +
            "so this build would be signed with the debug key. See " +
            "android/key.properties.example.",
    )
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
