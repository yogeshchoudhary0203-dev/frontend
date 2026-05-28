plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.trendia.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Required by flutter_local_notifications
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.trendia.app"

        // BUG FIX #1 — minSdk was flutter.minSdkVersion (= 16 in most Flutter
        // versions).  firebase_messaging v15+ and flutter_local_notifications
        // v17+ both have a hard requirement of minSdk 21.  With minSdk 16:
        //  • The notification channel APIs (Android 8+, API 26) are accessed
        //    through desugaring but FCM and FLN use reflection paths that crash
        //    silently on API 16-20 devices.
        //  • On some devices FCM fails to register the channel "trandia_ch1"
        //    and Android drops every incoming notification without any log.
        //  • requestNotificationsPermission() (API 33) is a no-op below API 21.
        // Setting it explicitly to 21 aligns with every dependency's minimum.
        minSdk = flutter.minSdkVersion

        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // SIZE REDUCTION — Drop x86_64 (emulator-only ABI, never shipped on
        // production devices).  arm64-v8a covers 98%+ of Android devices since
        // 2016; armeabi-v7a covers 32-bit devices.  Removing x86_64 shaves
        // ~25-30 MB from the fat APK because Agora's native .so files are
        // ~8-10 MB per ABI.
        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a")
        }
    }

    buildTypes {
        release {
            // R8 code shrinking — removes unused Java/Kotlin classes from
            // Firebase, Google Sign-In, and other SDKs. Saves 5-12 MB.
            isMinifyEnabled = true
            // Resource shrinking — removes unused Android drawable/layout XML.
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // ── NOTE: ABI splits removed ─────────────────────────────────────────────
    // The `splits { abi { ... } }` block conflicts with Flutter's internal
    // ndk.abiFilters setting ("armeabi-v7a,arm64-v8a,x86_64").  Having both
    // causes a Gradle build error.  Use `flutter build apk --split-per-abi`
    // from the command line to get one APK per architecture instead.

    // Keep all Agora native libraries. The RTC SDK loads several extension
    // libraries dynamically during engine startup, and stripping them can make
    // initialize/joinChannel fail with ERR_NOT_READY (-3) on real devices.
}

dependencies {
    // Required for flutter_local_notifications on Android < API 26
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
