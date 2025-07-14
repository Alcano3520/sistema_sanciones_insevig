import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseConfig {
  // ===============================================
  // 📊 PROYECTO DE EMPLEADOS (empleados-insevig)
  // ===============================================
  static const String empleadosUrl = 'https://buzcapcwmksasrtjofae.supabase.co';
  static const String empleadosAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ1emNhcGN3bWtzYXNydGpvZmFlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDk5OTY4MzcsImV4cCI6MjA2NTU3MjgzN30.RjxEf5JmhoxfHL6QoncwHM5smQaoWq9ipVlrK_i2mPA';

  // ===============================================
  // 📝 PROYECTO DE SANCIONES (sistema-sanciones-insevig)
  // ===============================================
  static const String sancionesUrl = 'https://syxzopyevfuwymmltbwn.supabase.co';
  static const String sancionesAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InN5eHpvcHlldmZ1d3ltbWx0YnduIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTIzNjkwMzYsImV4cCI6MjA2Nzk0NTAzNn0.fnxkNI4Hm4GgTAR8p1gsyeI8XPbmtDl0dF9PqxiMxsM';

  // ===============================================
  // CLIENTES SUPABASE SEPARADOS
  // ===============================================
  static SupabaseClient? _empleadosClient;
  static SupabaseClient? _sancionesClient;

  /// Inicializar ambos proyectos Supabase
  static Future<void> initialize() async {
    try {
      print('🔄 Inicializando conexión dual Supabase...');

      // Inicializar proyecto principal (sanciones) - para auth
      await Supabase.initialize(
        url: sancionesUrl,
        anonKey: sancionesAnonKey,
        debug: true,
      );

      // Crear cliente específico para empleados
      _empleadosClient = SupabaseClient(
        empleadosUrl,
        empleadosAnonKey,
      );

      // Cliente para sanciones (usa el principal)
      _sancionesClient = Supabase.instance.client;

      print('✅ Supabase dual inicializado correctamente');
      print('📊 Cliente empleados: ${empleadosUrl.substring(8, 20)}...');
      print('📝 Cliente sanciones: ${sancionesUrl.substring(8, 20)}...');

      // Verificar ambas conexiones
      await _testBothConnections();
    } catch (e) {
      print('❌ Error inicializando Supabase dual: $e');
      rethrow;
    }
  }

  /// Cliente para el proyecto de empleados
  static SupabaseClient get empleadosClient {
    if (_empleadosClient == null) {
      throw Exception(
          'Cliente de empleados no inicializado. Llama a SupabaseConfig.initialize() primero.');
    }
    return _empleadosClient!;
  }

  /// Cliente para el proyecto de sanciones (y auth)
  static SupabaseClient get sancionesClient {
    if (_sancionesClient == null) {
      throw Exception(
          'Cliente de sanciones no inicializado. Llama a SupabaseConfig.initialize() primero.');
    }
    return _sancionesClient!;
  }

  /// Cliente principal (para mantener compatibilidad)
  static SupabaseClient get client => sancionesClient;

  /// Auth (siempre del proyecto sanciones)
  static GoTrueClient get auth => sancionesClient.auth;

  /// Verificar conexión con ambos proyectos
  static Future<bool> testConnection() async {
    try {
      return await _testBothConnections();
    } catch (e) {
      print('❌ Error en test de conexión: $e');
      return false;
    }
  }

  /// Verificar ambas conexiones separadamente
  static Future<bool> _testBothConnections() async {
    bool empleadosOk = false;
    bool sancionesOk = false;

    // Test conexión empleados
    try {
      final empleadosResponse = await empleadosClient
          .from('empleados')
          .select('count')
          .eq('es_activo', true)
          .limit(1);

      empleadosOk = empleadosResponse.isNotEmpty;
      print(
          '📊 Empleados: ${empleadosOk ? "✅ OK" : "❌ Error"} (${empleadosResponse.length} registros)');
    } catch (e) {
      print('📊 Empleados: ❌ Error - $e');
    }

    // Test conexión sanciones (verificar si existen las tablas)
    try {
      final sancionesResponse =
          await sancionesClient.from('profiles').select('count').limit(1);

      sancionesOk = true; // Si no da error, está OK
      print('📝 Sanciones: ✅ OK (tabla profiles accesible)');
    } catch (e) {
      print('📝 Sanciones: ⚠️  Tablas no encontradas - $e');
      // No es crítico si las tablas de sanciones no existen aún
      sancionesOk = true;
    }

    final todoBien = empleadosOk && sancionesOk;
    print('🔗 Conexión dual: ${todoBien ? "✅ Exitosa" : "❌ Con problemas"}');

    return todoBien;
  }

  /// Obtener estadísticas de empleados del proyecto correcto
  static Future<Map<String, dynamic>> getEmpleadosStats() async {
    try {
      final response = await empleadosClient
          .from('empleados')
          .select('es_activo, es_liquidado, es_suspendido, nomdep, nomcargo');

      final stats = {
        'total': response.length,
        'activos': 0,
        'inactivos': 0,
        'departamentos': <String>{}.length,
        'cargos': <String>{}.length,
      };

      final departamentos = <String>{};
      final cargos = <String>{};

      for (var emp in response) {
        if (emp['es_activo'] == true) {
          stats['activos'] = (stats['activos'] as int) + 1;
        } else {
          stats['inactivos'] = (stats['inactivos'] as int) + 1;
        }

        if (emp['nomdep'] != null) departamentos.add(emp['nomdep']);
        if (emp['nomcargo'] != null) cargos.add(emp['nomcargo']);
      }

      stats['departamentos'] = departamentos.length;
      stats['cargos'] = cargos.length;

      return stats;
    } catch (e) {
      print('❌ Error obteniendo stats de empleados: $e');
      return {
        'total': 0,
        'activos': 0,
        'inactivos': 0,
        'departamentos': 0,
        'cargos': 0
      };
    }
  }

  /// Verificar si un empleado existe (cross-project)
  static Future<bool> empleadoExiste(int cod) async {
    try {
      final response = await empleadosClient
          .from('empleados')
          .select('cod')
          .eq('cod', cod)
          .eq('es_activo', true)
          .single();

      return response['cod'] != null;
    } catch (e) {
      print('❌ Error verificando empleado $cod: $e');
      return false;
    }
  }

  /// Debug: Mostrar información de configuración
  static void mostrarConfiguracion() {
    print('🔧 CONFIGURACIÓN SUPABASE DUAL:');
    print('📊 Empleados: ${empleadosUrl.substring(8, 25)}...');
    print('📝 Sanciones: ${sancionesUrl.substring(8, 25)}...');
    print(
        '🔑 Clientes inicializados: ${_empleadosClient != null && _sancionesClient != null}');
  }
}
