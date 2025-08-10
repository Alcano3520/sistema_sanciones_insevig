import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

import '../models/empleado_model.dart';
import '../models/sancion_model.dart';
import '../services/empleado_service.dart';
import '../services/sancion_service.dart';
import 'offline_database.dart';
import 'connectivity_service.dart';

/// 🎯 Controlador principal de funcionalidad offline
/// Coordina sincronización, detecta conectividad y maneja fallbacks
/// SOLO activo en móvil - en web todos los métodos son pass-through
class OfflineManager {
  static OfflineManager? _instance;
  static OfflineManager get instance => _instance ??= OfflineManager._();
  
  OfflineManager._();

  final OfflineDatabase _db = OfflineDatabase.instance;
  final ConnectivityService _connectivity = ConnectivityService.instance;
  
  bool _isInitialized = false;
  bool _isSyncing = false;
  StreamSubscription<bool>? _connectivitySubscription;

  /// Inicializar offline manager
  Future<bool> initialize() async {
    if (kIsWeb) {
      print('🌐 Web: OfflineManager en modo pass-through');
      _isInitialized = true;
      return true;
    }

    try {
      print('🎯 Inicializando OfflineManager para móvil...');

      // 1. Inicializar base de datos offline
      final dbInitialized = await _db.initialize();
      if (!dbInitialized) {
        print('❌ Falló inicialización de DB offline');
        return false;
      }

      // 2. Configurar listener de conectividad para auto-sync
      _setupConnectivityListener();

      // 3. Intentar sincronización inicial si hay conexión
      if (_connectivity.isConnected) {
        _backgroundSync();
      }

      _isInitialized = true;
      print('✅ OfflineManager inicializado correctamente');
      
      return true;
    } catch (e) {
      print('❌ Error inicializando OfflineManager: $e');
      return false;
    }
  }

  /// Configurar listener de conectividad
  void _setupConnectivityListener() {
    if (kIsWeb) return;

    _connectivitySubscription = _connectivity.connectionStream.listen((isConnected) {
      print('🎯 OfflineManager: Conectividad cambió a ${isConnected ? "ONLINE" : "OFFLINE"}');
      
      if (isConnected && !_isSyncing) {
        // Al reconectar, intentar sincronización automática
        print('🔄 Iniciando sincronización automática...');
        _backgroundSync();
      }
    });
  }

  /// =============================================
  /// 👥 EMPLEADOS CON FALLBACK OFFLINE
  /// =============================================

  /// Buscar empleados (online first, offline fallback)
  Future<List<EmpleadoModel>> searchEmpleados(String query) async {
    if (kIsWeb) {
      // 🌐 Web: usar servicio directo sin cambios
      return await EmpleadoService().searchEmpleados(query);
    }

    try {
      if (_connectivity.isConnected) {
        // 📱 Móvil ONLINE: obtener de Supabase y actualizar cache
        print('🌐 Buscando empleados online: "$query"');
        
        final empleadosOnline = await EmpleadoService().searchEmpleados(query);
        
        // Actualizar cache local con resultados (sin bloquear)
        if (empleadosOnline.isNotEmpty) {
          _updateEmpleadosCache(empleadosOnline);
        }
        
        return empleadosOnline;
      } else {
        // 📱 Móvil OFFLINE: buscar en cache local
        print('📱 Buscando empleados offline: "$query"');
        
        final empleadosOffline = _db.searchEmpleados(query);
        
        if (empleadosOffline.isEmpty) {
          print('⚠️ No hay empleados en cache local para: "$query"');
        }
        
        return empleadosOffline;
      }
    } catch (e) {
      print('❌ Error buscando empleados, fallback a offline: $e');
      
      // Fallback: intentar cache local si falla online
      return _db.searchEmpleados(query);
    }
  }

  /// Obtener empleado por código
  Future<EmpleadoModel?> getEmpleadoByCod(int cod) async {
    if (kIsWeb) {
      // 🌐 Web: usar servicio directo
      return await EmpleadoService().getEmpleadoByCod(cod);
    }

    try {
      if (_connectivity.isConnected) {
        // 📱 Móvil ONLINE
        final empleadoOnline = await EmpleadoService().getEmpleadoByCod(cod);
        
        // Actualizar cache
        if (empleadoOnline != null) {
          _updateEmpleadosCache([empleadoOnline]);
        }
        
        return empleadoOnline;
      } else {
        // 📱 Móvil OFFLINE
        return _db.getEmpleadoByCod(cod);
      }
    } catch (e) {
      print('❌ Error obteniendo empleado $cod, fallback a offline: $e');
      return _db.getEmpleadoByCod(cod);
    }
  }

  /// Actualizar cache de empleados (background)
  Future<void> _updateEmpleadosCache(List<EmpleadoModel> empleados) async {
    if (kIsWeb) return;

    try {
      // Obtener empleados existentes en cache
      final existingEmpleados = _db.getEmpleados();
      final existingMap = {for (var e in existingEmpleados) e.cod: e};
      
      // Agregar nuevos empleados al mapa
      for (var empleado in empleados) {
        existingMap[empleado.cod] = empleado;
      }
      
      // Guardar mapa actualizado
      await _db.saveEmpleados(existingMap.values.toList());
    } catch (e) {
      print('❌ Error actualizando cache empleados: $e');
    }
  }

  /// =============================================
  /// 📋 SANCIONES CON FUNCIONALIDAD OFFLINE
  /// =============================================

  /// Crear sanción (online/offline)
  Future<String?> createSancion({
    required SancionModel sancion,
    File? fotoFile,
    dynamic signatureController,
  }) async {
    if (kIsWeb) {
      // 🌐 Web: usar servicio directo
      return await SancionService().createSancion(
        sancion: sancion,
        fotoFile: fotoFile,
        signatureController: signatureController,
      );
    }

    try {
      if (_connectivity.isConnected) {
        // 📱 Móvil ONLINE: crear en Supabase
        print('🌐 Creando sanción online...');
        
        final sancionId = await SancionService().createSancion(
          sancion: sancion,
          fotoFile: fotoFile,
          signatureController: signatureController,
        );
        
        // Guardar también en cache local
        if (sancionId != null) {
          final sancionConId = sancion.copyWith(id: sancionId);
          await _db.saveSancion(sancionConId);
        }
        
        return sancionId;
      } else {
        // 📱 Móvil OFFLINE: guardar localmente y marcar para sync
        print('📱 Creando sanción offline...');
        
        // Guardar en base local
        await _db.saveSancion(sancion);
        
        // Agregar a cola de sincronización
        await _db.addToSyncQueue('create_sancion', {
          'sancion_id': sancion.id,
          'sancion_data': sancion.toMap(),
          'has_foto': fotoFile != null,
          'has_firma': signatureController != null,
          // TODO: Manejar archivos offline (guardar rutas locales)
        });
        
        print('✅ Sanción guardada offline, se sincronizará al reconectar');
        return sancion.id;
      }
    } catch (e) {
      print('❌ Error creando sanción, guardando offline: $e');
      
      // Fallback: guardar offline
      await _db.saveSancion(sancion);
      await _db.addToSyncQueue('create_sancion', {
        'sancion_id': sancion.id,
        'sancion_data': sancion.toMap(),
        'error_online': e.toString(),
      });
      
      return sancion.id;
    }
  }

  /// Obtener sanciones (online first, offline fallback)
  Future<List<SancionModel>> getSanciones(String supervisorId, {bool allSanciones = false}) async {
    if (kIsWeb) {
      // 🌐 Web: usar servicio directo
      final sancionService = SancionService();
      return allSanciones 
        ? await sancionService.getAllSanciones()
        : await sancionService.getMySanciones(supervisorId);
    }

    try {
      if (_connectivity.isConnected) {
        // 📱 Móvil ONLINE: obtener de Supabase y actualizar cache
        print('🌐 Obteniendo sanciones online...');
        
        final sancionService = SancionService();
        final sancionesOnline = allSanciones 
          ? await sancionService.getAllSanciones()
          : await sancionService.getMySanciones(supervisorId);
        
        // Actualizar cache local
        for (var sancion in sancionesOnline) {
          await _db.saveSancion(sancion);
        }
        
        return sancionesOnline;
      } else {
        // 📱 Móvil OFFLINE: obtener de cache local
        print('📱 Obteniendo sanciones offline...');
        
        return allSanciones
          ? _db.getSanciones()
          : _db.getSancionesBySupervisor(supervisorId);
      }
    } catch (e) {
      print('❌ Error obteniendo sanciones, fallback a offline: $e');
      
      // Fallback a cache local
      return allSanciones
        ? _db.getSanciones()
        : _db.getSancionesBySupervisor(supervisorId);
    }
  }

  /// Actualizar sanción
  Future<bool> updateSancion(SancionModel sancion, {File? nuevaFoto, dynamic nuevaFirma}) async {
    if (kIsWeb) {
      // 🌐 Web: usar servicio directo
      return await SancionService().updateSancionWithFiles(
        sancion: sancion,
        nuevaFoto: nuevaFoto,
        nuevaFirma: nuevaFirma,
      );
    }

    try {
      // Siempre actualizar cache local primero
      await _db.saveSancion(sancion);
      
      if (_connectivity.isConnected) {
        // 📱 Móvil ONLINE: actualizar en Supabase
        print('🌐 Actualizando sanción online...');
        
        final success = await SancionService().updateSancionWithFiles(
          sancion: sancion,
          nuevaFoto: nuevaFoto,
          nuevaFirma: nuevaFirma,
        );
        
        return success;
      } else {
        // 📱 Móvil OFFLINE: marcar para sync
        print('📱 Actualizando sanción offline...');
        
        await _db.addToSyncQueue('update_sancion', {
          'sancion_id': sancion.id,
          'sancion_data': sancion.toMap(),
          'has_nueva_foto': nuevaFoto != null,
          'has_nueva_firma': nuevaFirma != null,
        });
        
        return true; // Siempre exitoso offline
      }
    } catch (e) {
      print('❌ Error actualizando sanción: $e');
      
      // La sanción ya está guardada localmente
      await _db.addToSyncQueue('update_sancion', {
        'sancion_id': sancion.id,
        'sancion_data': sancion.toMap(),
        'error_online': e.toString(),
      });
      
      return true; // Exitoso localmente
    }
  }

  /// =============================================
  /// 🔄 SINCRONIZACIÓN
  /// =============================================

  /// Sincronización manual
  Future<bool> syncNow() async {
    if (kIsWeb) {
      print('🌐 Web: Sync no necesario');
      return true;
    }

    if (!_connectivity.isConnected) {
      print('📱 Sin conexión, no se puede sincronizar');
      return false;
    }

    return await _performSync();
  }

  /// Sincronización en background
  Future<void> _backgroundSync() async {
    if (kIsWeb || _isSyncing) return;

    // Sincronizar sin bloquear la UI
    unawaited(_performSync());
  }

  /// Realizar sincronización
  Future<bool> _performSync() async {
    if (_isSyncing) return false;
    
    _isSyncing = true;
    print('🔄 Iniciando sincronización...');

    try {
      // 1. Sincronizar empleados (descargar últimos)
      await _syncEmpleados();

      // 2. Procesar cola de operaciones pendientes
      await _processSyncQueue();

      print('✅ Sincronización completada');
      return true;
    } catch (e) {
      print('❌ Error en sincronización: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  /// Sincronizar empleados (descargar actualizaciones)
  Future<void> _syncEmpleados() async {
    try {
      print('🔄 Sincronizando empleados...');
      
      // Obtener timestamp de última sincronización
      final lastSync = _db.getMetadata<String>('last_empleados_sync');
      
      // Por ahora, obtener todos los empleados activos
      // TODO: Implementar sync incremental basado en timestamp
      final empleadosService = EmpleadoService();
      final empleadosOnline = await empleadosService.getAllEmpleadosActivos();
      
      if (empleadosOnline.isNotEmpty) {
        await _db.saveEmpleados(empleadosOnline);
        await _db.saveMetadata('last_empleados_sync', DateTime.now().toIso8601String());
        
        print('✅ ${empleadosOnline.length} empleados sincronizados');
      }
    } catch (e) {
      print('❌ Error sincronizando empleados: $e');
    }
  }

  /// Procesar cola de sincronización
  Future<void> _processSyncQueue() async {
    try {
      final pendingOperations = _db.getPendingSyncOperations();
      
      if (pendingOperations.isEmpty) {
        print('📝 No hay operaciones pendientes de sync');
        return;
      }
      
      print('🔄 Procesando ${pendingOperations.length} operaciones pendientes...');
      
      for (var operation in pendingOperations) {
        try {
          await _processSingleOperation(operation);
        } catch (e) {
          print('❌ Error procesando operación: $e');
          // Continuar con la siguiente operación
        }
      }
      
      // Si todo salió bien, limpiar cola
      await _db.clearSyncQueue();
      print('✅ Cola de sincronización procesada');
    } catch (e) {
      print('❌ Error procesando cola de sync: $e');
    }
  }

  /// Procesar una operación individual
  Future<void> _processSingleOperation(Map<String, dynamic> operation) async {
    final operationType = operation['operation'] as String;
    final data = operation['data'] as Map<String, dynamic>;
    
    print('🔄 Procesando: $operationType');
    
    switch (operationType) {
      case 'create_sancion':
        await _syncCreateSancion(data);
        break;
      case 'update_sancion':
        await _syncUpdateSancion(data);
        break;
      default:
        print('⚠️ Operación no reconocida: $operationType');
    }
  }

  /// Sincronizar creación de sanción
  Future<void> _syncCreateSancion(Map<String, dynamic> data) async {
    try {
      final sancionData = data['sancion_data'] as Map<String, dynamic>;
      final sancion = SancionModel.fromMap(sancionData);
      
      // TODO: Manejar archivos (foto/firma) offline
      final sancionId = await SancionService().createSancion(sancion: sancion);
      
      if (sancionId != null) {
        // Actualizar sanción local con datos del servidor
        final sancionConId = sancion.copyWith(id: sancionId);
        await _db.saveSancion(sancionConId);
        
        print('✅ Sanción offline sincronizada: $sancionId');
      }
    } catch (e) {
      print('❌ Error sincronizando creación de sanción: $e');
      rethrow;
    }
  }

  /// Sincronizar actualización de sanción
  Future<void> _syncUpdateSancion(Map<String, dynamic> data) async {
    try {
      final sancionData = data['sancion_data'] as Map<String, dynamic>;
      final sancion = SancionModel.fromMap(sancionData);
      
      final success = await SancionService().updateSancionSimple(sancion);
      
      if (success) {
        print('✅ Actualización de sanción sincronizada: ${sancion.id}');
      }
    } catch (e) {
      print('❌ Error sincronizando actualización: $e');
      rethrow;
    }
  }

  /// =============================================
  /// 🎯 GETTERS PÚBLICOS PARA REPOSITORIES
  /// =============================================

  /// Acceso público a la base de datos (para repositories)
  OfflineDatabase get database => _db;

  /// Verificar si está en modo offline
  bool get isOfflineMode => !kIsWeb && !_connectivity.isConnected;

  /// Obtener estadísticas offline
  Map<String, dynamic> getOfflineStats() {
    if (kIsWeb) {
      return {'mode': 'web_only', 'offline_supported': false};
    }

    return {
      'mode': _connectivity.isConnected ? 'online' : 'offline',
      'offline_supported': true,
      'empleados_cached': _db.getEmpleados().length,
      'sanciones_cached': _db.getSanciones().length,
      'pending_sync': _db.getPendingSyncOperations().length,
      'is_syncing': _isSyncing,
      'last_sync': _db.getMetadata<String>('last_empleados_sync'),
    };
  }

  /// Limpiar datos offline
  Future<bool> clearOfflineData() async {
    if (kIsWeb) return true;

    try {
      await _db.clearAllData();
      print('🧹 Datos offline limpiados');
      return true;
    } catch (e) {
      print('❌ Error limpiando datos offline: $e');
      return false;
    }
  }

  /// Dispose
  Future<void> dispose() async {
    await _connectivitySubscription?.cancel();
    await _db.dispose();
    _isInitialized = false;
  }
}

/// Helper para operaciones asíncronas sin await
void unawaited(Future<void> future) {
  // Ejecutar sin bloquear
}