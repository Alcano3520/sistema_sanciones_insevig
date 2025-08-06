# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# If your project uses WebView with JS, uncomment the following
# and specify the fully qualified class name to the JavaScript interface
# class:
#-keepclassmembers class fqcn.of.javascript.interface.for.webview {
#   public *;
#}

# Uncomment this to preserve the line number information for
# debugging stack traces.
-keepattributes SourceFile,LineNumberTable

# If you keep the line number information, uncomment this to
# hide the original source file name.
#-renamesourcefileattribute SourceFile

# 🔥 REGLAS ESPECÍFICAS PARA FLUTTER
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# 🔥 SUPABASE
-keep class io.supabase.** { *; }
-dontwarn io.supabase.**

# 🔥 IMAGE PICKER & CAMERA
-keep class io.flutter.plugins.imagepicker.** { *; }
-keep class io.flutter.plugins.camera.** { *; }

# 🔥 SIGNATURE
-keep class io.flutter.plugins.signature.** { *; }

# 🔥 PATH PROVIDER
-keep class io.flutter.plugins.pathprovider.** { *; }

# 🔥 PERMISSIONS
-keep class com.baseflow.permissionhandler.** { *; }

# 🔥 GSON (si se usa para JSON)
-keepattributes Signature
-keepattributes *Annotation*
-dontwarn sun.misc.**
-keep class com.google.gson.** { *; }

# 🔥 OKHTTP & RETROFIT (para conexiones de red)
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-keepnames class okhttp3.internal.publicsuffix.PublicSuffixDatabase

# 🔥 KOTLIN
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings {
    <fields>;
}
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}

# 🔥 ANDROIDX
-keep class androidx.** { *; }
-dontwarn androidx.**

# 🔥 MANTENER CLASSES DE MODELOS (tus modelos personalizados)
-keep class com.insevig.sistema_sanciones_insevig.** { *; }