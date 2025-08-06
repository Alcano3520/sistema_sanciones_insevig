# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# 🆕 REGLAS PARA COMPRESIÓN DE IMÁGENES
-keep class com.github.bumptech.glide.** { *; }
-keep public class * implements com.bumptech.glide.module.GlideModule
-keep public class * extends com.bumptech.glide.module.AppGlideModule
-keep public enum com.bumptech.glide.load.ImageHeaderParser$** {
  **[] $VALUES;
  public *;
}

# Mantener clases de image_picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# Mantener clases de path_provider
-keep class io.flutter.plugins.pathprovider.** { *; }

# 🆕 REGLAS PARA SUPABASE
-keep class io.supabase.** { *; }
-keep class com.supabase.** { *; }

# Mantener enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Mantener anotaciones
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# 🆕 REGLAS ESPECÍFICAS PARA PROCESSING DE IMÁGENES
-dontwarn java.awt.**
-dontwarn javax.imageio.**
-dontwarn sun.awt.image.**

# Mantener clases nativas
-keepclasseswithmembernames class * {
    native <methods>;
}

# No advertir sobre clases faltantes de AWT (no disponibles en Android)
-dontnote java.awt.**
-dontnote javax.swing.**