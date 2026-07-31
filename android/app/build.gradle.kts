plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "app.arteria.blm"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "app.arteria.blm"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // Rename build outputs from the default `app-<variant>.apk` to
    // `Arteria.apk`. Each variant gets its own folder
    // (build/outputs/apk/release/, build/outputs/apk/debug/) so there is
    // no naming collision between variants.
    //
    // Note: Flutter's CLI separately copies the gradle output into
    // build/app/outputs/flutter-apk/ using a hardcoded `app-{variant}.apk`
    // name that ignores gradle's outputFileName. The `doLast` block below
    // adds a second copy with the Arteria.apk name so both locations have
    // a properly-named release artifact.
    applicationVariants.all {
        val variantName = name
        outputs.all {
            if (this is com.android.build.gradle.internal.api.BaseVariantOutputImpl) {
                outputFileName = "Arteria.apk"
            }
        }
        assembleProvider.get().doLast {
            val gradleApk = file("$buildDir/outputs/apk/$variantName/Arteria.apk")
            val flutterApkDir = file("$buildDir/outputs/flutter-apk")
            if (gradleApk.exists() && flutterApkDir.exists()) {
                gradleApk.copyTo(
                    flutterApkDir.resolve("Arteria.apk"),
                    overwrite = true,
                )
            }
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
