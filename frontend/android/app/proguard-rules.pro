# =====================================================================
# KharchaSplit ProGuard / R8 rules
#
# Read by android/app/build.gradle.kts when isMinifyEnabled = true.
# `proguard-android-optimize.txt` (Android default) is applied first.
# =====================================================================

# ---- Flutter framework ------------------------------------------------
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.plugin.editing.** { *; }
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# ---- Kotlin -----------------------------------------------------------
-keep class kotlin.Metadata { *; }
-keepclassmembers class kotlinx.** { *; }

# ---- Firebase / Google Play Services ---------------------------------
# firebase_messaging, firebase_core, firebase_crashlytics (when added)
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# ---- flutter_local_notifications (uses reflection) -------------------
-keep class com.dexterous.** { *; }
-keep class * extends android.app.Service { <init>(); }
-keep class * extends android.content.BroadcastReceiver { <init>(); }

# ---- image_picker (Glide may be referenced) --------------------------
-keep public class * implements com.bumptech.glide.module.GlideModule
-keep public class * extends com.bumptech.glide.module.AppGlideModule
-keep class com.bumptech.glide.GeneratedAppGlideModuleImpl

# ---- flutter_contacts -------------------------------------------------
-keep class co.quis.flutter_contacts.** { *; }

# ---- Play Core (deferred components) ---------------------------------
# Flutter's embedding references com.google.android.play.core.* even when
# the app does NOT use deferred components. R8 fails the build otherwise.
# We don't ship a play-core dependency, so just silence the warnings.
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# ---- url_launcher / share_plus / connectivity_plus ------------------
-keep class io.flutter.plugins.urllauncher.** { *; }
-keep class dev.fluttercommunity.plus.** { *; }

# ---- pdf / printing --------------------------------------------------
-keep class net.nfet.flutter.** { *; }

# ---- Models serialized via dart:convert ------------------------------
# We don't use Java-side reflection on model classes (Flutter handles JSON
# in Dart), so no specific keep rules needed for models. If you ever add
# json_serializable / Hive native, add per-class keeps here.

# ---- Strip log calls in release --------------------------------------
# Removes android.util.Log.d/v/i calls so release APKs don't ship verbose
# debug noise. Errors + warnings are kept for Crashlytics.
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# ---- Generic safety nets --------------------------------------------
-dontwarn javax.annotation.**
-dontwarn org.codehaus.mojo.animal_sniffer.*
