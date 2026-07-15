# Flutter / Play Store release — keep plugin and model classes used via reflection.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Play Core (referenced by Flutter deferred components — optional at runtime)
-dontwarn com.google.android.play.core.**

# Gson / JSON models (if used by plugins)
-keepattributes Signature
-keepattributes *Annotation*

# OkHttp / Dio (used by http package stack)
-dontwarn okhttp3.**
-dontwarn okio.**

# Speech / audio plugins
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
