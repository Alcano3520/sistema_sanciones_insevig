import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart' if (dart.library.html) 'dart:html';

// 🆕 Imports condicionales para Hive (solo móvil)
import 'package:hive_flutter/hive_flutter.dart' if (dart.library.html) 'dart:html' as hive;

import '../models/empleado_model.dart';
import '../models/sancion_model.dart';

/// 💾 Base de datos offline usando Hive SOLO para móvil
/// En web: todos los métodos retornan listas vacías/false
class OfflineDatabase {
  static OfflineDatabase? _instance;
  static OfflineDatabase get instance => _instance ??= OfflineDatabase._();
  
  OfflineDatabase._();

  bool _isInitialized = false;
  
  // Nombres de las cajas Hive
  static const String empleadosBoxName = 'empleados_offline';
  static const String sancionesBoxName = 'sanciones_offline';
  static const String syncQueueBoxName = 'sync_queue';
  static const String metadataBoxName = 'metadata';

  /// Inicializar base de datos (solo en móvil)
  Future<bool> initialize() async {
    if (kIsWeb) {
      print('🌐 Web: Skip inicialización offline database');
      _isInitialized = true;
      return true; // En web no hay DB offline
    }

    try {
      print('💾 Inicializando Hive para móvil...');
      
      // Obtener directorio de la app en móvil
      final directory = await getApplicationDocumentsDirectory();
      await Hive.initFlutter(directory.path);

      // Registrar adapters para los modelos
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(EmpleadoModelAdapter());
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(SancionModelAdapter());
      }

      // Abrir las cajas necesarias
      await _openBoxes();

      _isInitialized = true;
      print('✅ Hive inicializado correctamente en móvil');
      
      // Mostrar estadísticas iniciales
      await _printStats();
      
      return true;
    } catch (e) {
      print('❌ Error inicializando Hive: $e');
      return false;
    }
  }

  /// Abrir todas las cajas Hive
  Future<void> _openBoxes() async {
    if (kIsWeb) return;

    try {
      // Abrir caja de empleados
      if (!Hive.isBoxOpen(empleadosBoxName)) {
        await Hive.openBox<EmpleadoModel>(empleadosBoxName);
      }

      // Abrir caja de sanciones
      if (!Hive.isBoxOpen(sancionesBoxName)) {
        await Hive.openBox<SancionModel>(sancionesBoxName);
      }

      // Abrir caja de cola de sincronización
      if (!Hive.isBoxOpen(syncQueueBoxName)) {
        await Hive.openBox<Map<String, dynamic>>(syncQueueBoxName);
      }

      // Abrir caja de metadata
      if (!Hive.isBoxOpen(metadataBoxName)) {
        await Hive.openBox<dynamic>(metadataBoxName);
      }

      print('📦 Todas las cajas Hive abiertas correctamente');
    } catch (e) {
      print('❌ Error abriendo cajas Hive: $e');
      rethrow;
    }
  }

  /// Verificar si está inicializado
  bool get isInitialized => _isInitialized;

  /// =============================================
  /// 👥 OPERACIONES EMPLEADOS
  /// =============================================

  /// Obtener caja de empleados
  Box<EmpleadoModel>? get empleadosBox {
    if (kIsWeb || !_isInitialized) return null;
    try {
      return Hive.box<EmpleadoModel>(empleadosBoxName);
    } catch (e) {
      print('❌ Error obteniendo caja empleados: $e');
      return null;
    }
  }

  /// Guardar empleados en local
  Future<bool> saveEmpleados(List<EmpleadoModel> empleados) async {
    if (kIsWeb || !_isInitialized) return false;

    try {
      final box = empleadosBox;
      if (box == null) return false;

      // Limpiar y guardar todos los empleados
      await box.clear();
      
      final empleadosMap = <String, EmpleadoModel>{};
      for (var empleado in empleados) {
        empleadosMap[empleado.cod.toString()] = empleado;
      }
      
      await box.putAll(empleadosMap);
      
      print('💾 ${empleados.length} empleados guardados en Hive');
      return true;
    } catch (e) {
      print('❌ Error guardando empleados: $e');
      return false;
    }
  }

  /// Obtener todos los empleados
  List<EmpleadoModel> getEmpleados() {
    if (kIsWeb || !_isInitialized) return [];

    try {
      final box = empleadosBox;
      if (box == null) return [];
      
      return box.values.toList();
    } catch (e) {
      print('❌ Error obteniendo empleados: $e');
      return [];
    }
  }

  /// Buscar empleados por query
  List<EmpleadoModel> searchEmpleados(String query) {
    if (kIsWeb || !_isInitialized) return [];

    try {
      final empleados = getEmpleados();
      final queryLower = query.toLowerCase();
      
      return empleados.where((empleado) {
        return empleado.searchText.contains(queryLower) ||
               empleado.cod.toString().contains(query);
      }).toList();
    } catch (e) {
      print('❌ Error buscando empleados: $e');
      return [];
    }
  }

  /// Obtener empleado por código
  EmpleadoModel? getEmpleadoByCod(int cod) {
    if (kIsWeb || !_isInitialized) return null;

    try {
      final box = empleadosBox;
      if (box == null) return null;
      
      return box.get(cod.toString());
    } catch (e) {
      print('❌ Error obteniendo empleado $cod: $e');
      return null;
    }
  }

  /// =============================================
  /// 📋 OPERACIONES SANCIONES
  /// =============================================

  /// Obtener caja de sanciones
  Box<SancionModel>? get sancionesBox {
    if (kIsWeb || !_isInitialized) return null;
    try {
      return Hive.box<SancionModel>(sancionesBoxName);
    } catch (e) {
      print('❌ Error obteniendo caja sanciones: $e');
      return null;
    }
  }

  /// Guardar sanción en local
  Future<bool> saveSancion(SancionModel sancion) async {
    if (kIsWeb || !_isInitialized) return false;

    try {
      final box = sancionesBox;
      if (box == null) return false;

      await box.put(sancion.id, sancion);
      print('💾 Sanción ${sancion.id.substring(0, 8)} guardada en Hive');
      
      return true;
    } catch (e) {
      print('❌ Error guardando sanción: $e');
      return false;
    }
  }

  /// Obtener todas las sanciones
  List<SancionModel> getSanciones() {
    if (kIsWeb || !_isInitialized) return [];

    try {
      final box = sancionesBox;
      if (box == null) return [];
      
      return box.values.toList();
    } catch (e) {
      print('❌ Error obteniendo sanciones: $e');
      return [];
    }
  }

  /// Obtener sanciones por supervisor
  List<SancionModel> getSancionesBySupervisor(String supervisorId) {
    if (kIsWeb || !_isInitialized) return [];

    try {
      final sanciones = getSanciones();
      return sanciones.where((s) => s.supervisorId == supervisorId).toList();
    } catch (e) {
      print('❌ Error obteniendo sanciones del supervisor: $e');
      return [];
    }
  }

  /// Eliminar sanción
  Future<bool> deleteSancion(String sancionId) async {
    if (kIsWeb || !_isInitialized) return false;

    try {
      final box = sancionesBox;
      if (box == null) return false;

      await box.delete(sancionId);
      print('🗑️ Sanción $sancionId eliminada de Hive');
      
      return true;
    } catch (e) {
      print('❌ Error eliminando sanción: $e');
      return false;
    }
  }

  /// =============================================
  /// 🔄 COLA DE SINCRONIZACIÓN
  /// =============================================

  /// Obtener caja de sync queue
  Box<Map<String, dynamic>>? get syncQueueBox {
    if (kIsWeb || !_isInitialized) return null;
    try {
      return Hive.box<Map<String, dynamic>>(syncQueueBoxName);
    } catch (e) {
      print('❌ Error obteniendo caja sync queue: $e');
      return null;
    }
  }

  /// Agregar operación a la cola de sincronización
  Future<bool> addToSyncQueue(String operation, Map<String, dynamic> data) async {
    if (kIsWeb || !_isInitialized) return false;

    try {
      final box = syncQueueBox;
      if (box == null) return false;

      final queueItem = {
        'operation': operation,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
        'attempts': 0,
      };

      await box.add(queueItem);
      print('📤 Operación "$operation" añadida a cola de sync');
      
      return true;
    } catch (e) {
      print('❌ Error añadiendo a sync queue: $e');
      return false;
    }
  }

  /// Obtener operaciones pendientes de sync
  List<Map<String, dynamic>> getPendingSyncOperations() {
    if (kIsWeb || !_isInitialized) return [];

    try {
      final box = syncQueueBox;
      if (box == null) return [];
      
      return box.values.cast<Map<String, dynamic>>().toList();
    } catch (e) {
      print('❌ Error obteniendo operaciones pendientes: $e');
      return [];
    }
  }

  /// Limpiar cola de sync
  Future<bool> clearSyncQueue() async {
    if (kIsWeb || !_isInitialized) return false;

    try {
      final box = syncQueueBox;
      if (box == null) return false;

      await box.clear();
      print('🧹 Cola de sync limpiada');
      
      return true;
    } catch (e) {
      print('❌ Error limpiando sync queue: $e');
      return false;
    }
  }

  /// =============================================
  /// 📊 METADATA Y ESTADÍSTICAS
  /// =============================================

  /// Guardar metadata
  Future<bool> saveMetadata(String key, dynamic value) async {
    if (kIsWeb || !_isInitialized) return false;

    try {
      final box = Hive.box(metadataBoxName);
      await box.put(key, value);
      return true;
    } catch (e) {
      print('❌ Error guardando metadata: $e');
      return false;
    }
  }

  /// Obtener metadata
  T? getMetadata<T>(String key, [T? defaultValue]) {
    if (kIsWeb || !_isInitialized) return defaultValue;

    try {
      final box = Hive.box(metadataBoxName);
      return box.get(key, defaultValue: defaultValue);
    } catch (e) {
      print('❌ Error obteniendo metadata: $e');
      return defaultValue;
    }
  }

  /// Imprimir estadísticas
  Future<void> _printStats() async {
    if (kIsWeb) return;

    try {
      final empleadosCount = getEmpleados().length;
      final sancionesCount = getSanciones().length;
      final pendingSyncCount = getPendingSyncOperations().length;

      print('📊 ESTADÍSTICAS HIVE:');
      print('   👥 Empleados: $empleadosCount');
      print('   📋 Sanciones: $sancionesCount');
      print('   ⏳ Sync pendiente: $pendingSyncCount');
    } catch (e) {
      print('❌ Error obteniendo estadísticas: $e');
    }
  }

  /// Limpiar toda la base de datos offline
  Future<bool> clearAllData() async {
    if (kIsWeb || !_isInitialized) return false;

    try {
      await empleadosBox?.clear();
      await sancionesBox?.clear();
      await syncQueueBox?.clear();
      await Hive.box(metadataBoxName).clear();
      
      print('🧹 Toda la base de datos offline limpiada');
      return true;
    } catch (e) {
      print('❌ Error limpiando base de datos: $e');
      return false;
    }
  }

  /// Cerrar base de datos
  Future<void> dispose() async {
    if (kIsWeb) return;

    try {
      await Hive.close();
      _isInitialized = false;
      print('💾 Hive cerrado correctamente');
    } catch (e) {
      print('❌ Error cerrando Hive: $e');
    }
  }
}

/// =============================================
/// 🏗️ ADAPTERS HIVE PARA MODELOS
/// =============================================

/// Adapter para EmpleadoModel
class EmpleadoModelAdapter extends TypeAdapter<EmpleadoModel> {
  @override
  final int typeId = 0;

  @override
  EmpleadoModel read(BinaryReader reader) {
    return EmpleadoModel.fromMap(Map<String, dynamic>.from(reader.readMap()));
  }

  @override
  void write(BinaryWriter writer, EmpleadoModel obj) {
    writer.writeMap(obj.toMap());
  }
}

/// Adapter para SancionModel
class SancionModelAdapter extends TypeAdapter<SancionModel> {
  @override
  final int typeId = 1;

  @override
  SancionModel read(BinaryReader reader) {
    return SancionModel.fromMap(Map<String, dynamic>.from(reader.readMap()));
  }

  @override
  void write(BinaryWriter writer, SancionModel obj) {
    writer.writeMap(obj.toMap());
  }
}