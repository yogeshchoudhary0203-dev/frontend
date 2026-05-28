# =============================================================================
# Trandia — R8 ProGuard Rules
# =============================================================================
# RULE: Only keep what R8 cannot infer on its own (JNI, reflection, Android
# framework entry points).  Broad "keep class pkg.** { *; }" rules block R8
# from removing dead code — the single biggest source of unnecessary APK size.
# =============================================================================


# ─── Flutter engine ──────────────────────────────────────────────────────────
# Flutter communicates with the Dart VM via JNI and loads platform-channel
# handlers by class name through reflection.
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugin.** { *; }
-dontwarn io.flutter.**


# ─── Agora RTC Engine ────────────────────────────────────────────────────────
# Agora's Java wrapper is loaded by its native .so files via JNI.
# Every class in io.agora must survive R8 or the engine crashes at init time.
-keep class io.agora.** { *; }
-dontwarn io.agora.**


# ─── Firebase Core ───────────────────────────────────────────────────────────
# Firebase uses a component-registry pattern: it discovers services by reading
# class names from metadata and loading them via Class.forName() at runtime.
# Stripping any of these causes silent startup failures.
-keep class com.google.firebase.FirebaseApp { *; }
-keep class com.google.firebase.auth.** { *; }
-keep class com.google.firebase.messaging.** { *; }
-keep class com.google.firebase.installations.** { *; }
-keep class com.google.firebase.iid.** { *; }
-keep class com.google.firebase.components.** { *; }
-keep class com.google.firebase.provider.** { *; }
-keep class com.google.firebase.platforminfo.** { *; }
-dontwarn com.google.firebase.**


# ─── Google Play Services ────────────────────────────────────────────────────
# Keep only the packages that Firebase + Google Sign-In reference via
# reflection.  Other GMS packages (Maps, Cast, etc.) are not used and
# R8 can trim them freely.
-keep class com.google.android.gms.tasks.** { *; }
-keep class com.google.android.gms.auth.api.signin.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.internal.** { *; }
-keep class com.google.android.gms.measurement.** { *; }
-dontwarn com.google.android.gms.**


# ─── OkHttp / Okio (transitive dependency from Firebase) ─────────────────────
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }


# ─── Kotlin — surgical keeps only ────────────────────────────────────────────
# DO NOT use "keep class kotlin.** { *; }" — that alone wastes 3-8 MB.
# R8 handles most Kotlin code correctly.  Only these specific cases need help:
#
#   kotlin.Metadata   — annotation read by Kotlin reflection at runtime
#   **$WhenMappings   — synthetic classes for `when` on sealed/enum; R8 cannot
#                       always detect they are reachable
#   coroutines volatiles — AtomicReferenceFieldUpdater CAS on volatile fields
#                          requires the field name to survive renaming
-keep class kotlin.Metadata { *; }
-keepclassmembers class **$WhenMappings { *; }
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembers class kotlinx.coroutines.** {
    volatile <fields>;
}
-dontwarn kotlin.**
-dontwarn kotlinx.**


# ─── PointyCastle / BouncyCastle (used by `encrypt` package) ─────────────────
# PointyCastle loads cipher implementations by name via a registry map, so
# the concrete classes must not be renamed or removed.
-keep class org.bouncycastle.** { *; }
-dontwarn org.bouncycastle.**
-dontwarn org.conscrypt.**
-dontwarn org.openjsse.**


# ─── Android framework entry points ──────────────────────────────────────────
# The Android system instantiates these via Class.forName(); R8 cannot see the
# caller so they must be preserved explicitly.
-keep public class * extends android.app.Activity
-keep public class * extends android.app.Application
-keep public class * extends android.app.Service
-keep public class * extends android.content.BroadcastReceiver
-keep public class * extends android.content.ContentProvider


# ─── Parcelable ──────────────────────────────────────────────────────────────
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}


# ─── JNI native methods ───────────────────────────────────────────────────────
-keepclasseswithmembernames class * {
    native <methods>;
}


# ─── Enum ─────────────────────────────────────────────────────────────────────
# Android and Java frameworks look up enum constants by name at runtime.
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}


# ─── Serializable ─────────────────────────────────────────────────────────────
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}


# ─── Suppress common transitive-dependency warnings ──────────────────────────
-dontwarn java.lang.invoke.**
-dontwarn javax.annotation.**
-dontwarn sun.misc.**
-dontwarn com.squareup.**
