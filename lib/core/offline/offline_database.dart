import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';

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
      print('💾 Inicializando OfflineDatabase para móvil...');

      // 🔥 NO inicializar Hive aquí - ya se hace en main.dart
      // Solo registrar adapters y abrir boxes

      // Registrar adapters para los modelos
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(EmpleadoModelAdapter());
        print('✅ Adapter EmpleadoModel registrado');
      }
      if (!Hive.isAdapterRegistered(1)) {
        Hive.registerAdapter(SancionModelAdapter());
        print('✅ Adapter SancionModel registrado');
      }

      // Abrir las cajas necesarias
      await _openBoxes();

      _isInitialized = true;
      print('✅ OfflineDatabase inicializada correctamente');

      // Mostrar estadísticas iniciales
      await _printStats();

      return true;
    } catch (e) {
      print('❌ Error inicializando OfflineDatabase: $e');
      print('Stacktrace: ${StackTrace.current}');
      return false;
    }
  }

  /// Abrir todas las cajas Hive
  Future<void> _openBoxes() async {
    if (kIsWeb) return;

    try {
      // 🔥 VERIFICAR PATH
      final directory = await getApplicationDocumentsDirectory();
      print('📁 Directorio Hive: ${directory.path}');

      // Abrir caja de empleados
      if (!Hive.isBoxOpen(empleadosBoxName)) {
        await Hive.openBox<EmpleadoModel>(empleadosBoxName);
        print('📦 Caja empleados abierta');
      }

      // Abrir caja de sanciones
      if (!Hive.isBoxOpen(sancionesBoxName)) {
        await Hive.openBox<SancionModel>(sancionesBoxName);
        print('📦 Caja sanciones abierta');
      }

      // Abrir caja de cola de sincronización
      if (!Hive.isBoxOpen(syncQueueBoxName)) {
        await Hive.openBox(syncQueueBoxName);
        print('📦 Caja sync queue abierta');
      }

      // Abrir caja de metadata
      if (!Hive.isBoxOpen(metadataBoxName)) {
        await Hive.openBox<dynamic>(metadataBoxName);
        print('📦 Caja metadata abierta');
      }

      print('📦 Todas las cajas Hive abiertas correctamente');

      // 🔥 VERIFICAR que las boxes existen
      print('📦 Estado de las boxes:');
      print(
          '   - Empleados: ${empleadosBox?.isOpen ?? false} (${empleadosBox?.length ?? 0} items)');
      print(
          '   - Sanciones: ${sancionesBox?.isOpen ?? false} (${sancionesBox?.length ?? 0} items)');
      print(
          '   - SyncQueue: ${syncQueueBox?.isOpen ?? false} (${syncQueueBox?.length ?? 0} items)');
      print(
          '   - Metadata: ${Hive.box(metadataBoxName).isOpen} (${Hive.box(metadataBoxName).length} items)');
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

      // 🔥 CRÍTICO: Forzar escritura a disco
      await box.flush();

      print('💾 ${empleados.length} empleados guardados y persistidos en Hive');
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

      final empleados = box.values.toList();
      print('📖 Leyendo ${empleados.length} empleados de Hive');
      return empleados;
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

      if (query.trim().isEmpty) {
        return empleados.take(20).toList();
      }

      final queryLower = query.toLowerCase().trim();
      final palabras =
          queryLower.split(' ').where((p) => p.isNotEmpty).toList();

      // 🔥 Búsqueda más flexible que funciona con cualquier orden de palabras
      final resultados = empleados.where((empleado) {
        // Crear texto de búsqueda combinando todos los campos
        final searchableText = [
          empleado.nombresCompletos,
          empleado.nombres,
          empleado.apellidos,
          empleado.cedula,
          empleado.nomcargo,
          empleado.nomdep,
          empleado.cod.toString(),
        ].where((field) => field != null).join(' ').toLowerCase();

        // Si es una sola palabra, buscar normalmente
        if (palabras.length == 1) {
          return searchableText.contains(queryLower);
        }

        // Si son múltiples palabras, verificar que todas estén presentes
        // sin importar el orden
        final todasLasPalabrasPresentes =
            palabras.every((palabra) => searchableText.contains(palabra));

        if (!todasLasPalabrasPresentes) {
          return false;
        }

        // Verificación adicional: comprobar si las palabras están juntas
        // en cualquier orden
        if (palabras.length == 2) {
          // Buscar "palabra1 palabra2" o "palabra2 palabra1"
          final ordenNormal = palabras.join(' ');
          final ordenInvertido = palabras.reversed.join(' ');

          return searchableText.contains(ordenNormal) ||
              searchableText.contains(ordenInvertido);
        }

        return true;
      }).toList();

      // Ordenar los resultados por relevancia
      resultados.sort((a, b) {
        final aName = a.displayName.toLowerCase();
        final bName = b.displayName.toLowerCase();

        // Prioridad 1: Coincidencia exacta
        final aExact = aName == queryLower;
        final bExact = bName == queryLower;
        if (aExact && !bExact) return -1;
        if (!aExact && bExact) return 1;

        // Prioridad 2: Empieza con la búsqueda
        final aStartsWith = aName.startsWith(queryLower);
        final bStartsWith = bName.startsWith(queryLower);
        if (aStartsWith && !bStartsWith) return -1;
        if (!aStartsWith && bStartsWith) return 1;

        // Prioridad 3: Contiene la búsqueda completa (en cualquier orden)
        if (palabras.length >= 2) {
          final ordenNormal = palabras.join(' ');
          final ordenInvertido = palabras.reversed.join(' ');

          final aContieneOrdenNormal = aName.contains(ordenNormal);
          final bContieneOrdenNormal = bName.contains(ordenNormal);
          final aContieneOrdenInvertido = aName.contains(ordenInvertido);
          final bContieneOrdenInvertido = bName.contains(ordenInvertido);

          final aContieneAlgunOrden =
              aContieneOrdenNormal || aContieneOrdenInvertido;
          final bContieneAlgunOrden =
              bContieneOrdenNormal || bContieneOrdenInvertido;

          if (aContieneAlgunOrden && !bContieneAlgunOrden) return -1;
          if (!aContieneAlgunOrden && bContieneAlgunOrden) return 1;
        }

        return a.displayName.compareTo(b.displayName);
      });

      return resultados.take(50).toList();
    } catch (e) {
      print('❌ Error buscando empleados en cache: $e');
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

      // 🔥 CRÍTICO: Usar await y flush
      await box.put(sancion.id, sancion);
      await box.flush(); // Forzar escritura a disco

      print(
          '💾 Sanción ${sancion.id.substring(0, 8)} guardada y persistida en Hive');
      print('   Total sanciones en cache: ${box.length}');

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

      final sanciones = box.values.toList();
      print('📖 Leyendo ${sanciones.length} sanciones de Hive');
      return sanciones;
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
      final filtered =
          sanciones.where((s) => s.supervisorId == supervisorId).toList();
      print(
          '📖 Encontradas ${filtered.length} sanciones del supervisor $supervisorId');
      return filtered;
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
      await box.flush(); // 🔥 Forzar escritura

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
  Box? get syncQueueBox {
    if (kIsWeb || !_isInitialized) return null;
    try {
      return Hive.box(syncQueueBoxName);
    } catch (e) {
      print('❌ Error obteniendo caja sync queue: $e');
      return null;
    }
  }

  /// Agregar operación a la cola de sincronización
  Future<bool> addToSyncQueue(
      String operation, Map<String, dynamic> data) async {
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

      // 🔥 Generar key única basada en timestamp
      final key = 'sync_${DateTime.now().millisecondsSinceEpoch}_${operation}';
      await box.put(key, queueItem);
      await box.flush(); // 🔥 Forzar escritura

      print('📤 Operación "$operation" añadida a cola de sync');
      print('   Key: $key');
      print('   Total en cola: ${box.length}');

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

      final operations = <Map<String, dynamic>>[];

      for (var value in box.values) {
        if (value is Map) {
          // Convertir a Map<String, dynamic>
          operations.add(Map<String, dynamic>.from(value));
        }
      }

      print('📋 ${operations.length} operaciones pendientes de sync');
      return operations;
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
      await box.flush(); // 🔥 Forzar escritura

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
      await box.flush(); // 🔥 Forzar escritura

      print('💾 Metadata "$key" guardada: $value');
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
      final value = box.get(key, defaultValue: defaultValue);
      print('📖 Metadata "$key": $value');
      return value;
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

      print('\n📊 ESTADÍSTICAS HIVE:');
      print('   👥 Empleados: $empleadosCount');
      print('   📋 Sanciones: $sancionesCount');
      print('   ⏳ Sync pendiente: $pendingSyncCount');
      print('   📁 Path: ${(await getApplicationDocumentsDirectory()).path}');
      print('');
    } catch (e) {
      print('❌ Error obteniendo estadísticas: $e');
    }
  }

  /// Limpiar toda la base de datos offline
  Future<bool> clearAllData() async {
    if (kIsWeb || !_isInitialized) return false;

    try {
      await empleadosBox?.clear();
      await empleadosBox?.flush();

      await sancionesBox?.clear();
      await sancionesBox?.flush();

      await syncQueueBox?.clear();
      await syncQueueBox?.flush();

      await Hive.box(metadataBoxName).clear();
      await Hive.box(metadataBoxName).flush();

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
      // NO cerrar Hive completamente, solo las referencias
      _isInitialized = false;
      print('💾 OfflineDatabase disposed (Hive permanece abierto)');
    } catch (e) {
      print('❌ Error en dispose: $e');
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
    final map = Map<String, dynamic>.from(reader.readMap());
    return EmpleadoModel.fromMap(map);
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
    final map = Map<String, dynamic>.from(reader.readMap());
    return SancionModel.fromMap(map);
  }

  @override
  void write(BinaryWriter writer, SancionModel obj) {
    writer.writeMap(obj.toMap());
  }
}
