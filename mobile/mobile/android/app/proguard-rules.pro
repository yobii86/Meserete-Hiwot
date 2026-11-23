# Flutter Engine and Embedder
-keep class io.flutter.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.embedding.** { *; }

# Preserve native methods and JNI bindings
-keepclasseswithmembernames class * {
    native <methods>;
}

# Preserve reflection metadata
-keepattributes *Annotation*,EnclosingMethod,InnerClasses,Signature,SourceFile,LineNumberTable

# Audio Services (just_audio, just_audio_background, audio_session, ExoPlayer)
-keep class com.ryanheise.** { *; }
-keep class com.ryanheise.just_audio.** { *; }
-keep class com.ryanheise.audioservice.** { *; }
-keep class androidx.media.** { *; }
-keep class androidx.media3.** { *; }
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.ryanheise.**

# Flutter Local Notifications
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-dontwarn com.dexterous.flutterlocalnotifications.**

# Firebase Messaging & Google Play Services
-keep class com.google.firebase.** { *; }
-keep class io.flutter.plugins.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Mobile Scanner & ML Kit Barcode
-keep class dev.steenbakker.mobile_scanner.** { *; }
-keep class com.google.mlkit.** { *; }
-keep class com.google.android.gms.vision.** { *; }
-dontwarn com.google.mlkit.**

# Pdfrx & PDFium
-keep class com.github.espresso3389.pdfrx.** { *; }
-keep class io.legado.pdfrx.** { *; }
-dontwarn com.github.espresso3389.pdfrx.**

# Local Authentication & Biometrics
-keep class io.flutter.plugins.localauth.** { *; }
-keep class androidx.biometric.** { *; }

# SQLite
-keep class com.tekartik.sqflite.** { *; }

# Image Picker, File Picker & Media
-keep class io.flutter.plugins.imagepicker.** { *; }
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-keep class io.flutter.plugins.videoplayer.** { *; }
-keep class io.flutter.plugins.urllauncher.** { *; }
-keep class io.flutter.plugins.share.** { *; }
-keep class dev.fluttercommunity.plus.** { *; }

# Photo Manager
-keep class com.fluttercandies.photo_manager.** { *; }
-dontwarn com.fluttercandies.photo_manager.**

# WebView & YouTube Player
-keep class io.flutter.plugins.webviewflutter.** { *; }
-keepclassmembers class * extends android.webkit.WebChromeClient {
    *;
}
-keepclassmembers class * extends android.webkit.WebViewClient {
    *;
}
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Desugaring & General Warnings
-dontwarn java.time.**
-dontwarn org.bouncycastle.**
-dontwarn okio.**
-dontwarn com.google.android.play.core.**

