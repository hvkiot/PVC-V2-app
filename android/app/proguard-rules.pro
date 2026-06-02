# Flutter-specific ProGuard rules
# Keep Flutter engine classes
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }

# Keep annotations
-keepattributes *Annotation*

# Keep Bluetooth related classes (flutter_blue_plus)
-keep class com.boskokg.flutter_blue_plus.** { *; }

# Don't warn about missing classes in optional dependencies
-dontwarn com.google.android.play.core.**
-dontwarn com.google.firebase.**
