plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

def localProperties = new Properties()
def localPropertiesFile = rootProject.file('local.properties')
if (localPropertiesFile.exists()) {
    localPropertiesFile.withReader('UTF-8') { reader ->
        localProperties.load(reader)
    }
}

def flutterVersionCode = localProperties.getProperty('flutter.versionCode')
if (flutterVersionCode == null) {
    flutterVersionCode = '1'
}

def flutterVersionName = localProperties.getProperty('flutter.versionName')
if (flutterVersionName == null) {
    flutterVersionName = '1.0'
}

android {
    // 🔥 SOLUCIÓN AL ERROR NDK
    ndkVersion = "27.0.12077973"
    
    namespace = "com.insevig.sistema_sanciones_insevig"
    compileSdk = 34
    
    // 🆕 CONFIGURACIÓN MEJORADA PARA COMPRESIÓN
    packagingOptions {
        pickFirst '**/libc++_shared.so'
        pickFirst '**/libjsc.so'
        exclude 'META-INF/DEPENDENCIES'
        exclude 'META-INF/LICENSE'
        exclude 'META-INF/LICENSE.txt'
        exclude 'META-INF/NOTICE'
        exclude 'META-INF/NOTICE.txt'
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = '1.8'
    }

    defaultConfig {
        applicationId = "com.insevig.sistema_sanciones_insevig"
        // 🔥 VERSIÓN MÍNIMA PARA COMPATIBILIDAD
        minSdk = 21  // API 21 (Android 5.0) para máxima compatibilidad
        targetSdk = 34
        versionCode = flutterVersionCode.toInteger()
        versionName = flutterVersionName
        
        // 🆕 CONFIGURACIÓN ADICIONAL PARA IMÁGENES
        multiDexEnabled = true
        
        // Permitir HTTP en debug (útil para desarrollo local)
        buildConfigField "boolean", "ALLOW_HTTP", "true"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.debug
            
            // 🔥 OPTIMIZACIONES PARA RELEASE
            minifyEnabled = true
            shrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            
            // Configuración para imágenes en producción
            buildConfigField "boolean", "ALLOW_HTTP", "false"
        }
        
        debug {
            applicationIdSuffix = ".debug"
            debuggable = true
            minifyEnabled = false
            shrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.window:window:1.0.0")
    implementation("androidx.window:window-java:1.0.0")
    
    // 🆕 DEPENDENCIAS PARA MANEJO DE IMÁGENES
    implementation 'androidx.exifinterface:exifinterface:1.3.6'
    implementation 'androidx.core:core-ktx:1.12.0'
    
    // Para compatibilidad con versiones anteriores de Android
    implementation 'androidx.appcompat:appcompat:1.6.1'
    implementation 'androidx.activity:activity-ktx:1.8.2'
}