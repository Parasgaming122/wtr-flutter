# Flutter-specific rules.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.webkit.**  { *; }
-keep class io.flutter.plugin.common.**  { *; }
-keep class io.flutter.plugin.platform.**  { *; }

# Rules for Google Play Core library, which were being incorrectly removed by R8.
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep interface com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }
-keep interface com.google.android.play.core.tasks.** { *; }
