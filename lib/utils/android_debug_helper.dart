import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

/// Helper específico para debugging en Android
class AndroidDebugHelper {
  static const MethodChannel _channel = MethodChannel('com.insevig.sanciones/native');
  
  /// 🔍 Diagnóstico completo específico para Android
  static Future<Map<String, dynamic>> runAndroidDiagnostic() async {
    if (!Platform.isAndroid) {
      return {'error': 'Este diagnóstico es solo para Android'};
    }

    final results = <String, dynamic>{};
    
    try {
      // 1. Información del dispositivo
      results['device'] = await _getDeviceInfo();
      
      // 2. Estado de permisos
      results['permissions'] = await _checkAllPermissions();
      
      // 3. Configuración de red
      results['network'] = await _checkNetworkConfig();
      
      // 4. Información de build
      results['build'] = _getBuildInfo();
      
      // 5. Estado del emulador
      results['emulator'] = await _checkEmulatorStatus();
      
      print('🔍 === DIAGNÓSTICO ANDROID COMPLETO ===');
      _printDiagnosticResults(results);
      
      return results;
    } catch (e) {
      results['error'] = e.toString();
      return results;
    }
  }

  /// Obtener información del dispositivo Android
  static Future<Map<String, dynamic>> _getDeviceInfo() async {
    try {
      final deviceInfo = await _channel.invokeMethod('getDeviceInfo');
      return Map<String, dynamic>.from(deviceInfo);
    } catch (e) {
      return {
        'model': 'Unknown',
        'version': Platform.operatingSystemVersion,
        'error': e.toString(),
      };
    }
  }

  /// Verificar todos los permisos críticos
  static Future<Map<String, String>> _checkAllPermissions() async {
    final permissions = <Permission, String>{
      Permission.camera: 'Cámara',
      Permission.storage: 'Almacenamiento',
      Permission.manageExternalStorage: 'Almacenamiento Externo',
      Permission.accessMediaLocation: 'Ubicación de Media',
    };

    final results = <String, String>{};
    
    for (final entry in permissions.entries) {
      try {
        final status = await entry.key.status;
        results[entry.value] = _getPermissionStatusText(status);
      } catch (e) {
        results[entry.value] = 'Error: $e';
      }
    }
    
    return results;
  }

  /// Verificar configuración de red
  static Future<Map<String, dynamic>> _checkNetworkConfig() async {
    try {
      final networkConfig = await _channel.invokeMethod('checkNetworkSecurity');
      final connectivity = await _testConnectivity();
      
      return {
        'cleartext_permitted': networkConfig['cleartextPermitted'] ?? false,
        'internet_access': connectivity,
        'supabase_empleados': await _testSupabaseConnection('empleados'),
        'supabase_sanciones': await _testSupabaseConnection('sanciones'),
      };
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  /// Información de build
  static Map<String, dynamic> _getBuildInfo() {
    return {
      'debug_mode': kDebugMode,
      'profile_mode': kProfileMode,
      'release_mode': kReleaseMode,
      'platform': Platform.operatingSystem,
      'dart_version': Platform.version,
    };
  }

  /// Verificar si está en emulador
  static Future<Map<String, dynamic>> _checkEmulatorStatus() async {
    final results = <String, dynamic>{};
    
    try {
      final deviceInfo = await _getDeviceInfo();
      final model = deviceInfo['model']?.toString().toLowerCase() ?? '';
      final manufacturer = deviceInfo['manufacturer']?.toString().toLowerCase() ?? '';
      
      final isEmulator = model.contains('sdk') || 
                        model.contains('emulator') ||
                        manufacturer.contains('google') && model.contains('sdk');
      
      results['is_emulator'] = isEmulator;
      results['model'] = model;
      results['manufacturer'] = manufacturer;
      
      if (isEmulator) {
        results['recommendations'] = [
          'Verificar que el AVD tenga Google APIs habilitado',
          'Configurar cámara del emulador: Front/Back Camera = Webcam0',
          'Verificar conexión a internet del emulador',
          'Cold Boot si hay problemas persistentes',
        ];
      }
      
    } catch (e) {
      results['error'] = e.toString();
    }
    
    return results;
  }

  /// Test de conectividad básica
  static Future<bool> _testConnectivity() async {
    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Test conexión específica a Supabase
  static Future<String> _testSupabaseConnection(String project) async {
    try {
      final urls = {
        'empleados': 'buzcapcwmksasrtjofae.supabase.co',
        'sanciones': 'syxzopyevfuwymmltbwn.supabase.co',
      };
      
      if (!urls.containsKey(project)) return 'Proyecto desconocido';
      
      final result = await InternetAddress.lookup(urls[project]!);
      return result.isNotEmpty ? 'Conectado' : 'Sin conexión';
    } catch (e) {
      return 'Error: $e';
    }
  }

  /// Convertir status de permiso a texto legible
  static String _getPermissionStatusText(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return '✅ Concedido';
      case PermissionStatus.denied:
        return '❌ Denegado';
      case PermissionStatus.restricted:
        return '🔒 Restringido';
      case PermissionStatus.limited:
        return '⚠️ Limitado';
      case PermissionStatus.permanentlyDenied:
        return '🚫 Permanentemente Denegado';
      default:
        return '❓ Desconocido';
    }
  }

  /// Imprimir resultados del diagnóstico
  static void _printDiagnosticResults(Map<String, dynamic> results) {
    print('\n📱 INFORMACIÓN DEL DISPOSITIVO:');
    final device = results['device'] as Map<String, dynamic>;
    device.forEach((key, value) => print('   $key: $value'));

    print('\n🔐 ESTADO DE PERMISOS:');
    final permissions = results['permissions'] as Map<String, String>;
    permissions.forEach((key, value) => print('   $key: $value'));

    print('\n🌐 CONFIGURACIÓN DE RED:');
    final network = results['network'] as Map<String, dynamic>;
    network.forEach((key, value) => print('   $key: $value'));

    print('\n🔧 INFORMACIÓN DE BUILD:');
    final build = results['build'] as Map<String, dynamic>;
    build.forEach((key, value) => print('   $key: $value'));

    print('\n📲 ESTADO DEL EMULADOR:');
    final emulator = results['emulator'] as Map<String, dynamic>;
    emulator.forEach((key, value) {
      if (key == 'recommendations' && value is List) {
        print('   Recomendaciones:');
        for (final rec in value) {
          print('     • $rec');
        }
      } else {
        print('   $key: $value');
      }
    });

    print('\n✅ === DIAGNÓSTICO COMPLETADO ===\n');
  }

  /// Generar reporte de problemas con soluciones
  static String generateTroubleshootingReport(Map<String, dynamic> results) {
    final buffer = StringBuffer();
    buffer.writeln('🔧 REPORTE DE SOLUCIÓN DE PROBLEMAS');
    buffer.writeln('═══════════════════════════════════');
    buffer.writeln('Generado: ${DateTime.now()}');
    buffer.writeln();

    // Analizar permisos
    final permissions = results['permissions'] as Map<String, String>;
    final deniedPermissions = permissions.entries
        .where((e) => e.value.contains('Denegado'))
        .map((e) => e.key)
        .toList();

    if (deniedPermissions.isNotEmpty) {
      buffer.writeln('🚨 PERMISOS DENEGADOS:');
      for (final permission in deniedPermissions) {
        buffer.writeln('   ❌ $permission');
      }
      buffer.writeln();
      buffer.writeln('SOLUCIÓN:');
      buffer.writeln('1. Ir a Configuración > Aplicaciones > Sistema Sanciones INSEVIG');
      buffer.writeln('2. Seleccionar "Permisos"');
      buffer.writeln('3. Activar todos los permisos necesarios');
      buffer.writeln();
    }

    // Analizar conectividad
    final network = results['network'] as Map<String, dynamic>;
    if (network['internet_access'] == false) {
      buffer.writeln('🌐 PROBLEMA DE CONECTIVIDAD:');
      buffer.writeln('   ❌ Sin acceso a internet');
      buffer.writeln();
      buffer.writeln('SOLUCIÓN:');
      buffer.writeln('1. Verificar conexión WiFi del emulador');
      buffer.writeln('2. Reiniciar emulador');
      buffer.writeln('3. En AVD Manager: Edit > Advanced > Cold Boot Now');
      buffer.writeln();
    }

    // Analizar emulador
    final emulator = results['emulator'] as Map<String, dynamic>;
    if (emulator['is_emulator'] == true) {
      buffer.writeln('📲 CONFIGURACIÓN DEL EMULADOR:');
      final recommendations = emulator['recommendations'] as List?;
      if (recommendations != null) {
        for (final rec in recommendations) {
          buffer.writeln('   • $rec');
        }
      }
      buffer.writeln();
    }

    return buffer.toString();
  }
}