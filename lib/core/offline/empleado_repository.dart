import 'package:flutter/foundation.dart';
import '../models/empleado_model.dart';
import '../services/empleado_service.dart';
import 'offline_manager.dart';

/// 🔄 Repository wrapper para EmpleadoService
/// Actúa como proxy inteligente que decide entre online/offline
/// En web: pasa todas las llamadas directamente al service original
/// En móvil: usa OfflineManager para manejar fallbacks automáticos
class EmpleadoRepository {
  static EmpleadoRepository? _instance;
  static EmpleadoRepository get instance =>
      _instance ??= EmpleadoRepository._();

  EmpleadoRepository._();

  final EmpleadoService _empleadoService = EmpleadoService();
  final OfflineManager _offlineManager = OfflineManager.instance;

  /// =============================================
  /// 🔍 BÚSQUEDA DE EMPLEADOS
  /// =============================================

  /// Buscar empleados con autocompletado
  /// Web: Directo a EmpleadoService
  /// Móvil: Online first, offline fallback automático
  Future<List<EmpleadoModel>> searchEmpleados(String query) async {
    if (kIsWeb) {
      // 🌐 Web: comportamiento original sin cambios
      print('🌐 [WEB] Búsqueda directa online');
      return await _empleadoService.searchEmpleados(query);
    }

    // 🔥 AGREGAR LOGS DE DEBUG
    print('📱 [MOBILE] Búsqueda de empleados: "$query"');
    print(
        '   - OfflineManager inicializado: ${_offlineManager.database.isInitialized}');
    print('   - Modo offline forzado: ${_offlineManager.isOfflineMode}');
    print(
        '   - Conectividad actual: ${!_offlineManager.isOfflineMode ? "ONLINE" : "OFFLINE"}');

    // Ver cache actual
    final cachedEmpleados = _offlineManager.database.getEmpleados();
    print('   - Empleados en cache: ${cachedEmpleados.length}');

    // 📱 Móvil: usar OfflineManager que maneja fallbacks
    try {
      final resultados = await _offlineManager.searchEmpleados(query);
      print('   ✅ Búsqueda exitosa: ${resultados.length} resultados');
      return resultados;
    } catch (e) {
      print('   ❌ Error en búsqueda: $e');

      // Si el error es de red y tenemos cache, usar cache
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup')) {
        print('   🔄 Intentando búsqueda en cache local...');
        final cached = cachedEmpleados
            .where((emp) => emp.searchText.contains(query.toLowerCase()))
            .toList();
        print('   📦 Encontrados en cache: ${cached.length}');
        return cached;
      }

      rethrow;
    }
  }

  /// Obtener empleado específico por código
  Future<EmpleadoModel?> getEmpleadoByCod(int cod) async {
    if (kIsWeb) {
      // 🌐 Web: comportamiento original
      return await _empleadoService.getEmpleadoByCod(cod);
    }

    // 🔥 DEBUG
    print('📱 [MOBILE] Buscando empleado por código: $cod');

    // 📱 Móvil: con cache offline
    return await _offlineManager.getEmpleadoByCod(cod);
  }

  /// =============================================
  /// 📊 MÉTODOS ADICIONALES (Pass-through)
  /// =============================================
  /// Estos métodos mantienen comportamiento original
  /// pero pueden agregar funcionalidad offline en el futuro

  /// Obtener empleados por departamento
  Future<List<EmpleadoModel>> getEmpleadosByDepartamento(
      String departamento) async {
    try {
      // Siempre usar servicio original por ahora
      return await _empleadoService.getEmpleadosByDepartamento(departamento);
    } catch (e) {
      print('❌ Error obteniendo empleados por departamento: $e');

      if (!kIsWeb) {
        // En móvil: fallback a cache local si hay error
        final empleadosCached = _offlineManager.database.getEmpleados();
        return empleadosCached
            .where((emp) => emp.nomdep == departamento)
            .toList();
      }

      return [];
    }
  }

  /// Obtener todos los empleados activos
  Future<List<EmpleadoModel>> getAllEmpleadosActivos() async {
    try {
      print('📥 Obteniendo todos los empleados activos...');
      final empleados = await _empleadoService.getAllEmpleadosActivos();
      print('   ✅ ${empleados.length} empleados obtenidos');

      // En móvil, actualizar cache
      if (!kIsWeb && empleados.isNotEmpty) {
        print('   💾 Actualizando cache local...');
        for (final emp in empleados) {
          //await _offlineManager.database.saveEmpleados([emp]);
        }
        print('   ✅ Cache actualizado');
      }

      return empleados;
    } catch (e) {
      print('❌ Error obteniendo todos los empleados: $e');

      if (!kIsWeb) {
        // Fallback a cache local en móvil
        print('   🔄 Usando cache local...');
        final cached = _offlineManager.database.getEmpleados();
        print('   📦 ${cached.length} empleados en cache');
        return cached;
      }

      return [];
    }
  }

  /// Obtener departamentos únicos
  Future<List<String>> getDepartamentos() async {
    try {
      return await _empleadoService.getDepartamentos();
    } catch (e) {
      print('❌ Error obteniendo departamentos: $e');

      if (!kIsWeb) {
        // Fallback: extraer departamentos de cache local
        final empleados = _offlineManager.database.getEmpleados();
        final departamentos = empleados
            .map((e) => e.nomdep)
            .where((dept) => dept != null && dept.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList();

        departamentos.sort();
        return departamentos;
      }

      return [];
    }
  }

  /// Obtener cargos únicos
  Future<List<String>> getCargos() async {
    try {
      return await _empleadoService.getCargos();
    } catch (e) {
      print('❌ Error obteniendo cargos: $e');

      if (!kIsWeb) {
        // Fallback: extraer cargos de cache local
        final empleados = _offlineManager.database.getEmpleados();
        final cargos = empleados
            .map((e) => e.nomcargo)
            .where((cargo) => cargo != null && cargo.isNotEmpty)
            .cast<String>()
            .toSet()
            .toList();

        cargos.sort();
        return cargos;
      }

      return [];
    }
  }

  /// Verificar si un empleado puede ser sancionado
  Future<bool> puedeSerSancionado(int cod) async {
    try {
      return await _empleadoService.puedeSerSancionado(cod);
    } catch (e) {
      print('❌ Error verificando empleado: $e');

      if (!kIsWeb) {
        // Fallback: verificar en cache local
        final empleado = _offlineManager.database.getEmpleadoByCod(cod);
        return empleado?.puedeSerSancionado ?? false;
      }

      return false;
    }
  }

  /// Obtener estadísticas de empleados
  Future<Map<String, int>> getEstadisticasEmpleados() async {
    try {
      return await _empleadoService.getEstadisticasEmpleados();
    } catch (e) {
      print('❌ Error obteniendo estadísticas: $e');

      if (!kIsWeb) {
        // Fallback: calcular estadísticas de cache local
        final empleados = _offlineManager.database.getEmpleados();

        return {
          'total': empleados.length,
          'activos': empleados.length, // Todos en cache están activos
          'disponibles_sancion':
              empleados.where((e) => e.puedeSerSancionado).length,
          'departamentos': empleados
              .map((e) => e.nomdep)
              .where((d) => d != null)
              .toSet()
              .length,
          'cargos': empleados
              .map((e) => e.nomcargo)
              .where((c) => c != null)
              .toSet()
              .length,
        };
      }

      return {
        'total': 0,
        'activos': 0,
        'disponibles_sancion': 0,
        'departamentos': 0,
        'cargos': 0,
      };
    }
  }

  /// =============================================
  /// 🔧 MÉTODOS DE DESARROLLO Y DEBUG
  /// =============================================

  /// Diagnóstico de empleados (desarrollo)
  Future<void> diagnosticarEmpleados() async {
    if (kIsWeb) {
      // En web: usar método original
      return await _empleadoService.diagnosticarEmpleados();
    }

    // En móvil: diagnóstico extendido con info offline
    print('\n🔍 DIAGNÓSTICO DUAL - EMPLEADOS:');
    print('========================================');

    // Estado del sistema
    print('\n📱 ESTADO DEL SISTEMA:');
    print('   - Plataforma: MÓVIL');
    print(
        '   - OfflineManager inicializado: ${_offlineManager.database.isInitialized}');
    print(
        '   - Modo actual: ${_offlineManager.isOfflineMode ? "OFFLINE" : "ONLINE"}');

    // Diagnóstico online
    if (!_offlineManager.isOfflineMode) {
      try {
        print('\n📊 DIAGNÓSTICO ONLINE:');
        await _empleadoService.diagnosticarEmpleados();
      } catch (e) {
        print('❌ Error en diagnóstico online: $e');
      }
    }

    // Diagnóstico offline
    print('\n💾 DIAGNÓSTICO OFFLINE:');
    final empleadosCached = _offlineManager.database.getEmpleados();
    print('   - Empleados en cache: ${empleadosCached.length}');

    if (empleadosCached.isNotEmpty) {
      final departamentos =
          empleadosCached.map((e) => e.nomdep).where((d) => d != null).toSet();
      final cargos = empleadosCached
          .map((e) => e.nomcargo)
          .where((c) => c != null)
          .toSet();

      print('   - Departamentos únicos: ${departamentos.length}');
      print('   - Cargos únicos: ${cargos.length}');
      print(
          '   - Pueden ser sancionados: ${empleadosCached.where((e) => e.puedeSerSancionado).length}');

      // Mostrar primeros 5 empleados
      print('\n   📋 Primeros 5 empleados en cache:');
      empleadosCached.take(5).forEach((emp) {
        print(
            '      ${emp.cod}: ${emp.displayName} - ${emp.nomdep ?? "Sin dept"}');
      });
    }

    // Estado de sincronización
    final stats = _offlineManager.getOfflineStats();
    print('\n🔄 ESTADO DE SINCRONIZACIÓN:');
    print('   - Modo: ${stats['mode']}');
    print('   - Operaciones pendientes: ${stats['pending_sync']}');
    print('   - Última sync: ${stats['last_sync'] ?? 'Nunca'}');
    print('========================================\n');
  }

  /// Test de conexión
  Future<bool> testConnection() async {
    return await _empleadoService.testConnection();
  }

  /// Búsqueda avanzada
  Future<List<EmpleadoModel>> searchEmpleadosAvanzado({
    String? query,
    String? departamento,
    String? cargo,
    bool soloActivos = true,
  }) async {
    try {
      return await _empleadoService.searchEmpleadosAvanzado(
        query: query,
        departamento: departamento,
        cargo: cargo,
        soloActivos: soloActivos,
      );
    } catch (e) {
      print('❌ Error en búsqueda avanzada: $e');

      if (!kIsWeb) {
        // Fallback: búsqueda avanzada en cache local
        var empleados = _offlineManager.database.getEmpleados();

        // Filtrar por query
        if (query != null && query.isNotEmpty) {
          empleados = empleados
              .where((emp) => emp.searchText.contains(query.toLowerCase()))
              .toList();
        }

        // Filtrar por departamento
        if (departamento != null && departamento.isNotEmpty) {
          empleados =
              empleados.where((emp) => emp.nomdep == departamento).toList();
        }

        // Filtrar por cargo
        if (cargo != null && cargo.isNotEmpty) {
          empleados = empleados.where((emp) => emp.nomcargo == cargo).toList();
        }

        return empleados;
      }

      return [];
    }
  }

  /// =============================================
  /// 🎯 MÉTODOS DE INFORMACIÓN
  /// =============================================

  /// Obtener información del estado del repository
  Map<String, dynamic> getRepositoryInfo() {
    final info = {
      'platform': kIsWeb ? 'web' : 'mobile',
      'offline_supported': !kIsWeb,
      'service_class': 'EmpleadoRepository',
    };

    if (!kIsWeb) {
      // Información adicional para móvil
      final offlineStats = _offlineManager.getOfflineStats();
      info.addAll({
        'current_mode': offlineStats['mode'],
        'cached_empleados': offlineStats['empleados_cached'],
        'pending_sync': offlineStats['pending_sync'],
        'offline_manager_initialized': _offlineManager.database.isInitialized,
      });
    }

    return info;
  }

  /// Forzar sincronización de empleados (solo móvil)
  Future<bool> forceSyncEmpleados() async {
    if (kIsWeb) {
      print('🌐 Web: Sincronización no aplicable');
      return true;
    }

    try {
      print('🔄 Forzando sincronización de empleados...');

      // Primero intentar obtener todos los empleados
      final empleados = await getAllEmpleadosActivos();
      print('   ✅ ${empleados.length} empleados sincronizados');

      // Luego sincronizar cambios pendientes
      final success = await _offlineManager.syncNow();
      print('   🔄 Sincronización general: ${success ? "EXITOSA" : "FALLIDA"}');

      return success;
    } catch (e) {
      print('❌ Error en sincronización forzada: $e');
      return false;
    }
  }

  /// Limpiar cache de empleados (solo móvil)
  Future<bool> clearEmpleadosCache() async {
    if (kIsWeb) {
      print('🌐 Web: Cache no aplicable');
      return true;
    }

    try {
      // Limpiar solo empleados, mantener sanciones
      final empleadosBox = _offlineManager.database.empleadosBox;
      if (empleadosBox != null) {
        await empleadosBox.clear();
        print('🧹 Cache de empleados limpiado');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error limpiando cache de empleados: $e');
      return false;
    }
  }

  /// 🆕 Método de debug completo
  Future<void> runFullDebug() async {
    print('\n🏥 DEBUG COMPLETO - EMPLEADO REPOSITORY');
    print('=======================================');

    // Info del repository
    print('\n📊 INFO DEL REPOSITORY:');
    final info = getRepositoryInfo();
    info.forEach((key, value) {
      print('   - $key: $value');
    });

    // Test de búsqueda
    print('\n🔍 TEST DE BÚSQUEDA:');
    try {
      final test1 = await searchEmpleados('a');
      print('   ✅ Búsqueda "a": ${test1.length} resultados');

      final test2 = await searchEmpleados('jose');
      print('   ✅ Búsqueda "jose": ${test2.length} resultados');
    } catch (e) {
      print('   ❌ Error en búsqueda: $e');
    }

    // Diagnóstico completo
    await diagnosticarEmpleados();

    print('=======================================\n');
  }
}
