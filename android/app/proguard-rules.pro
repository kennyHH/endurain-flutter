# Keep default conservative settings for now.
# Add explicit keep rules only when release obfuscation reveals required classes.

# Flutter Core
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Geolocator
-keep class com.baseflow.geolocator.** { *; }

# Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Local Auth
-keep class io.flutter.plugins.localauth.** { *; }

# SQLCipher
-keep class net.sqlcipher.** { *; }
-keep class net.sqlcipher.database.** { *; }

# JNA / FFI
-keep class com.sun.jna.** { *; }
-keepclassmembers class * extends com.sun.jna.* { public *; }

# Endurain MainActivity
-keep class com.dev.endurain.MainActivity { *; }

# Google Play Core / Feature Delivery (Dynamic Features)
# Suppress warnings for missing Play Core classes if not using dynamic features
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

