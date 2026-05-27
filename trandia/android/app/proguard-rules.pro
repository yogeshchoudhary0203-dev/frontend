# ── Flutter ──────────────────────────────────────────────────────────────────
# Flutter engine classes must never be stripped — it communicates via JNI
# with libflutter.so and uses reflection for platform channels.
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-dontwarn io.flutter.**

# ── Agora RTC ─────────────────────────────────────────────────────────────────
# Agora uses JNI and reflection extensively. Keep all Agora classes.
-keep class io.agora.** { *; }
-dontwarn io.agora.**

# ── Firebase ──────────────────────────────────────────────────────────────────
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ── Google Sign-In ────────────────────────────────────────────────────────────
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }

# ── OkHttp / Okio (used by Firebase) ─────────────────────────────────────────
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# ── Kotlin ────────────────────────────────────────────────────────────────────
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }
-dontwarn kotlin.**
-dontwarn kotlinx.**

# ── Android / Java standard library warnings ─────────────────────────────────
-dontwarn java.lang.invoke.**
-dontwarn javax.annotation.**
-dontwarn sun.misc.**

# ── Keep app entry points (Activities, Services, Receivers) ──────────────────
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider

# ── Keep Parcelable implementations (used by Android system) ─────────────────
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# ── Keep native method declarations (JNI) ────────────────────────────────────
-keepclasseswithmembernames class * {
    native <methods>;
}

# ── Suppress common warnings from transitive deps ────────────────────────────
-dontwarn com.squareup.**
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**
