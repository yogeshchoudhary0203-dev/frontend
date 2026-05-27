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

    // ── Exclude unused Agora extension .so files ─────────────────────────────
    // agora_rtc_engine ships AI/analytics extensions we don't use in Trandia.
    // Excluding them removes ~80-100 MB from the APK with zero feature loss.
    // Keep: core RTC, audio codecs, video encoder/decoder (needed for calls).
    packaging {
        jniLibs {
            excludes += setOf(
                // AI audio (we don't use AI noise suppression or AI echo cancel)
                "**/libagora_ai_noise_suppression_extension.so",
                "**/libagora_ai_echo_cancellation_extension.so",

                // Audio beauty / voice changer (not used)
                "**/libagora_audio_beauty_extension.so",

                // Video analytics (Agora's internal quality metrics, not needed)
                "**/libagora_video_quality_analyzer_extension.so",

                // Content inspection / AI moderation (not used)
                "**/libagora_content_inspect_extension.so",

                // Screen sharing (we don't share screen)
                "**/libagora_screen_capture_extension.so",

                // Virtual background (not used)
                "**/libagora_virtual_background_extension.so",

                // Face features (not used)
                "**/libagora_face_detection_extension.so",
                "**/libagora_face_capture_extension.so",
                "**/libagora_lips_sync_extension.so",

                // Spatial / 3D audio (not used)
                "**/libagora_spatial_audio_extension.so",

                // DRM (not streaming DRM content)
                "**/libagora_drm_loader_extension.so",

                // ARES (Agora AI super resolution — not needed for calls)
                "**/libagora_ares_extension.so",
            )
        }
    }
}

dependencies {
    // Required for flutter_local_notifications on Android < API 26
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
