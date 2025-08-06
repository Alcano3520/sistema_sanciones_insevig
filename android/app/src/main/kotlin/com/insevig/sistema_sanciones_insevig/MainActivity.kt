package com.insevig.sistema_sanciones_insevig

import android.os.Bundle
import android.view.WindowManager
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    
    private val CHANNEL = "com.insevig.sanciones/native"
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 🔥 Prevenir screenshots en modo release
        if (!BuildConfig.DEBUG_MODE) {
            window.setFlags(
                WindowManager.LayoutParams.FLAG_SECURE,
                WindowManager.LayoutParams.FLAG_SECURE
            )
        }
    }

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 🔥 Canal de comunicación con Flutter
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getDeviceInfo" -> {
                    try {
                        val deviceInfo = mapOf(
                            "model" to android.os.Build.MODEL,
                            "version" to android.os.Build.VERSION.RELEASE,
                            "sdk" to android.os.Build.VERSION.SDK_INT,
                            "manufacturer" to android.os.Build.MANUFACTURER
                        )
                        result.success(deviceInfo)
                    } catch (e: Exception) {
                        result.error("DEVICE_INFO_ERROR", e.message, null)
                    }
                }
                "checkNetworkSecurity" -> {
                    // Verificar configuración de red
                    val networkSecurityConfig = applicationInfo.networkSecurityConfig
                    result.success(mapOf("cleartextPermitted" to (networkSecurityConfig == 0)))
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    override fun getCachedEngineId(): String? {
        return "main_engine"
    }
}