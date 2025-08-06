import java.util.Properties

// 🔥 SINTAXIS KOTLIN DSL CORREGIDA
val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}

val flutterRoot = localProperties.getProperty("flutter.sdk")
    ?: throw GradleException("Flutter SDK not found. Define location with flutter.sdk in the local.properties file.")

val flutterVersionCode = localProperties.getProperty("flutter.versionCode")
val flutterVersionName = localProperties.getProperty("flutter.versionName") ?: "1.0"

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.insevig.sistema_sanciones_insevig"
    compileSdk = 35 // 🔥 ACTUALIZADO A SDK 35
    ndkVersion = "27.0.12077973" // 🆕 NDK actualizado

    // 🔥 HABILITAR buildConfig PRIMERO
    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11 // 🔥 Java 11 (moderno)
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "11" // 🔥 Kotlin también a 11
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    packaging {
        pickFirst("**/libc++_shared.so")
        pickFirst("**/libjsc.so")
        pickFirst("**/libfbjni.so")
        exclude("META-INF/DEPENDENCIES")
        exclude("META-INF/LICENSE")
        exclude("META-INF/LICENSE.txt")
        exclude("META-INF/NOTICE")
        exclude("META-INF/NOTICE.txt")
        
        // 🆕 CONFIGURACIÓN ESPECÍFICA para librerías nativas
        pickFirst("lib/x86/libc++_shared.so")
        pickFirst("lib/x86_64/libc++_shared.so")
        pickFirst("lib/arm64-v8a/libc++_shared.so")
        pickFirst("lib/armeabi-v7a/libc++_shared.so")
    }

    defaultConfig {
        applicationId = "com.insevig.sistema_sanciones_insevig"
        minSdk = 21
        targetSdk = 34 // Mantener 34 para compatibilidad
        versionCode = flutterVersionCode?.toIntOrNull() ?: 1
        versionName = flutterVersionName

        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
        
        // 🔥 CONFIGURAR ARQUITECTURAS SOPORTADAS
        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
        }
        
        // 🆕 Config para HTTP en debug
        buildConfigField("Boolean", "ALLOW_HTTP", "true")
    }

    // 🔥 SIMPLIFICADO: Sin keystore personalizado para desarrollo
    
    // 🆕 CONFIGURACIÓN DE SPLITS (opcional - para APKs más pequeños)
    splits {
        abi {
            isEnable = true
            reset()
            include("armeabi-v7a", "arm64-v8a", "x86", "x86_64")
            isUniversalApk = true // 🔥 CREAR APK UNIVERSAL (incluye todas las arquitecturas)
        }
    }
    
    buildTypes {
        getByName("release") {
            // 🔥 Sin signing personalizado para desarrollo
            // signingConfig = signingConfigs.getByName("debug")
            
            isMinifyEnabled = true
            isShrinkResources = true
            
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            
            buildConfigField("Boolean", "ALLOW_HTTP", "false")
        }

        getByName("debug") {
            isDebuggable = true
            isMinifyEnabled = false
            isShrinkResources = false
            
            buildConfigField("Boolean", "ALLOW_HTTP", "true")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // 🆕 Dependencias para compresión de imágenes y compatibilidad
    implementation("androidx.exifinterface:exifinterface:1.3.6")
    implementation("androidx.core:core-ktx:1.12.0")
    
    // Dependencias Android básicas
    implementation("androidx.appcompat:appcompat:1.6.1")
    implementation("androidx.activity:activity-ktx:1.8.2")
    
    // 🆕 DEPENDENCIA para compatibilidad de arquitecturas
    implementation("androidx.annotation:annotation:1.7.1")
}