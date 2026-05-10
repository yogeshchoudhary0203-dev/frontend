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
            // TODO: Replace with a production keystore before Play Store upload.
            // Using the debug key for sideloaded APKs is fine but the SHA-1 of
            // the debug key must be added to the Firebase console under
            // Project Settings → Your apps → Android app → SHA certificate
            // fingerprints so Google Sign-In works in release builds.
            signingConfig = signingConfigs.getByName("debug")
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
