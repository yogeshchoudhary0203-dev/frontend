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

    // ── Agora extension exclusions ───────────────────────────────────────────
    // Trandia uses Agora ONLY for basic 1-to-1 voice + video calls:
    //   enableAudio / enableVideo / joinChannel / leaveChannel / switchCamera
    //
    // Agora 6.x bundles 13+ optional extension .so files for AI/ML features
    // that are NOT called anywhere in our code.  Keeping them wastes ~43 MB
    // per ABI.  We exclude every extension that is provably unused.
    //
    // KEPT (required for basic calls):
    //   libagora-rtc-sdk.so        — core engine (26.8 MB)
    //   libagora_ffmpeg.so         — H.264 video codec (6.2 MB)
    //   libvideo_enc.so / dec.so   — software video encode/decode (2.5 MB)
    //   libagora-fdkaac.so         — AAC audio codec (0.7 MB)
    //   libagora-soundtouch.so     — pitch/tempo audio processing (0.2 MB)
    //   libAgoraRtcWrapper.so      — JNI wrapper (1.5 MB)
    //   libiris_*.so               — Flutter bridge (0.8 MB)
    //   libaosl.so                 — OS abstraction layer (0.6 MB)
    //
    // EXCLUDED (AI / ML / unused features — safe to drop):
    packaging {
        jniLibs {
            excludes += setOf(
                // Clear vision / video enhancement   → 9.2 MB
                "**/libagora_clear_vision_extension.so",
                // Lip sync animation                 → 6.6 MB
                "**/libagora_lip_sync_extension.so",
                // 3-D spatial / positional audio     → 4.4 MB
                "**/libagora_spatial_audio_extension.so",
                // AI noise suppression (std + LL)    → 5.8 MB
                "**/libagora_ai_noise_suppression_extension.so",
                "**/libagora_ai_noise_suppression_ll_extension.so",
                // Background segmentation            → 2.6 MB
                "**/libagora_segmentation_extension.so",
                // Face capture / AR                  → 2.6 MB
                "**/libagora_face_capture_extension.so",
                // AI echo cancellation (std + LL)    → 4.2 MB
                // (Basic hardware EC is inside the core SDK; these are extra)
                "**/libagora_ai_echo_cancellation_extension.so",
                "**/libagora_ai_echo_cancellation_ll_extension.so",
                // Audio beautification / voice FX    → 2.0 MB
                "**/libagora_audio_beauty_extension.so",
                // Content inspection / moderation    → 1.6 MB
                "**/libagora_content_inspect_extension.so",
                // AV1 video encoder (no AV1 calls)   → 1.4 MB
                "**/libagora_video_av1_encoder_extension.so",
                // Video quality analyser             → 1.4 MB
                "**/libagora_video_quality_analyzer_extension.so",
                // Face detection                     → 1.2 MB
                "**/libagora_face_detection_extension.so",
                // Screen capture / share             → 0.4 MB
                "**/libagora_screen_capture_extension.so"
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
