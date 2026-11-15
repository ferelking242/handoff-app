# Flutter and plugin classes are referenced only from the generated
# registrant, so the default shrinking rules need these keeps.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class dev.aivos.openhands.** { *; }

# flutter_local_notifications uses reflection to rebuild scheduled
# notifications after a reboot.
-keep class com.dexterous.** { *; }

# Flutter's deferred-components engine references Play Core classes that are
# only present when the app uses Play Store dynamic delivery. We do not, so the
# references are dead code R8 can safely ignore.
-dontwarn com.google.android.play.core.**

# Keep annotations the plugins rely on at runtime.
-keepattributes *Annotation*, Signature, InnerClasses, EnclosingMethod
