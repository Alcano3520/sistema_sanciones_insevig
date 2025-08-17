import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/empleado_model.dart';

/// Servicio para empleados - USA EL PROYECTO empleados-insevig
/// Conecta específicamente con tu proyecto de empleados via API
class EmpleadoService {
  // 📊 Cliente específico del proyecto empleados-insevig
  SupabaseClient get _empleadosClient => SupabaseConfig.empleadosClient;

  /// Buscar empleados por texto con autocompletado
  /// CORREGIDO para obtener más de 1000 empleados
  Future<List<EmpleadoModel>> searchEmpleados(String query) async {
    try {
      if (query.trim().isEmpty) {
        return [];
      }

      print(
          '🔍 [EMPLEADOS API] Buscando: "$query" en proyecto empleados-insevig');

      // 🔥 ESTRATEGIA SIMPLIFICADA Y CORREGIDA
      final response = await _empleadosClient
          .from('empleados')
          .select('*') // Simplificado
          .or('nombres_completos.ilike.%$query%,nombres.ilike.%$query%,apellidos.ilike.%$query%,cedula.ilike.%$query%,nomcargo.ilike.%$query%,nomdep.ilike.%$query%,cod.eq.${int.tryParse(query) ?? -1}') // Todo en una línea
          .eq('es_activo', true)
          .eq('es_liquidado', false)
          .neq('es_suspendido', true)
          .order('nombres_completos')
          .limit(100);

      print(
          '✅ [EMPLEADOS API] Encontrados ${response.length} empleados activos');

      // Filtrar y limitar en el cliente para mejor control
      final empleadosFiltrados = response
          .map<EmpleadoModel>((json) => EmpleadoModel.fromMap(json))
          .where((empleado) => empleado.puedeSerSancionado)
          .toList();

      // 🔥 NUEVO: Ordenar priorizando los que empiezan con el término buscado
      empleadosFiltrados.sort((a, b) {
        final queryLower = query.toLowerCase();
        final aStartsWith = a.displayName.toLowerCase().startsWith(queryLower);
        final bStartsWith = b.displayName.toLowerCase().startsWith(queryLower);
        
        // Si uno empieza con el query y el otro no, priorizar el que empieza
        if (aStartsWith && !bStartsWith) return -1;
        if (!aStartsWith && bStartsWith) return 1;
        
        // Si ambos empiezan o ambos no empiezan, ordenar alfabéticamente
        return a.displayName.compareTo(b.displayName);
      });

      // Limitar después del ordenamiento
      final resultadosFinales = empleadosFiltrados.take(100).toList();

      print(
          '🎯 [EMPLEADOS API] Empleados disponibles para sanción: ${resultadosFinales.length}');

      return resultadosFinales;
    } catch (e) {
      print('❌ [EMPLEADOS API] Error en búsqueda: $e');

      // Búsqueda de respaldo con método diferente
      try {
        print('🔄 [EMPLEADOS API] Intentando búsqueda de respaldo...');

        // Usar múltiples consultas pequeñas en lugar de una grande
        final responses = <List<dynamic>>[];

        // Búsqueda por nombre
        final byName = await _empleadosClient
            .from('empleados')
            .select('*')
            .ilike('nombres_completos', '%$query%')
            .eq('es_activo', true)
            .limit(50);
        responses.add(byName);

        // Búsqueda por código si es numérico
        if (int.tryParse(query) != null) {
          final byCod = await _empleadosClient
              .from('empleados')
              .select('*')
              .eq('cod', int.parse(query))
              .eq('es_activo', true);
          responses.add(byCod);
        }

        // Búsqueda por cédula
        final byCedula = await _empleadosClient
            .from('empleados')
            .select('*')
            .ilike('cedula', '%$query%')
            .eq('es_activo', true)
            .limit(25);
        responses.add(byCedula);

        // Combinar resultados únicos
        final allResults = <Map<String, dynamic>>[];
        final seen = <int>{};

        for (var response in responses) {
          for (var item in response) {
            final cod = item['cod'] as int;
            if (!seen.contains(cod)) {
              seen.add(cod);
              allResults.add(item);
            }
          }
        }

        print(
            '✅ [EMPLEADOS API] Búsqueda de respaldo: ${allResults.length} resultados únicos');

        final empleadosRespaldo = allResults
            .map<EmpleadoModel>((json) => EmpleadoModel.fromMap(json))
            .toList();

        // 🔥 NUEVO: Aplicar el mismo ordenamiento a la búsqueda de respaldo
        empleadosRespaldo.sort((a, b) {
          final queryLower = query.toLowerCase();
          final aStartsWith = a.displayName.toLowerCase().startsWith(queryLower);
          final bStartsWith = b.displayName.toLowerCase().startsWith(queryLower);
          
          if (aStartsWith && !bStartsWith) return -1;
          if (!aStartsWith && bStartsWith) return 1;
          return a.displayName.compareTo(b.displayName);
        });

        return empleadosRespaldo;
      } catch (e2) {
        print('❌ [EMPLEADOS API] Error en búsqueda de respaldo: $e2');
        return [];
      }
    }
  }

  /// Obtener empleado específico por código
  Future<EmpleadoModel?> getEmpleadoByCod(int cod) async {
    try {
      print('🔍 [EMPLEADOS API] Obteniendo empleado cod: $cod');

      final response = await _empleadosClient
          .from('empleados')
          .select('*')
          .eq('cod', cod)
          .eq('es_activo', true)
          .single();

      print(
          '✅ [EMPLEADOS API] Empleado encontrado: ${response['nombres_completos']}');
      return EmpleadoModel.fromMap(response);
    } catch (e) {
      print('❌ [EMPLEADOS API] Error obteniendo empleado $cod: $e');
      return null;
    }
  }

  /// Obtener empleados por departamento
  Future<List<EmpleadoModel>> getEmpleadosByDepartamento(
      String departamento) async {
    try {
      print('🔍 [EMPLEADOS API] Buscando en departamento: $departamento');

      final response = await _empleadosClient
          .from('empleados')
          .select('*')
          .eq('nomdep', departamento)
          .eq('es_activo', true)
          .eq('es_liquidado', false)
          .order('nombres_completos');
      // Sin límite para obtener todos del departamento

      print(
          '✅ [EMPLEADOS API] Encontrados ${response.length} empleados en $departamento');

      return response
          .map<EmpleadoModel>((json) => EmpleadoModel.fromMap(json))
          .toList();
    } catch (e) {
      print(
          '❌ [EMPLEADOS API] Error obteniendo empleados por departamento: $e');
      return [];
    }
  }

  /// Obtener todos los empleados activos con paginación mejorada
  Future<List<EmpleadoModel>> getAllEmpleadosActivos() async {
    try {
      print('📊 [EMPLEADOS API] Obteniendo TODOS los empleados activos...');

      // 🔥 ESTRATEGIA MEJORADA: Usar rangos en lugar de límites
      final List<EmpleadoModel> todosLosEmpleados = [];
      int offset = 0;
      const int batchSize = 500; // Lotes más pequeños para evitar timeouts

      while (true) {
        print('📊 [EMPLEADOS API] Cargando lote desde $offset...');

        final response = await _empleadosClient
            .from('empleados')
            .select('*')
            .eq('es_activo', true)
            .eq('es_liquidado', false)
            .neq('es_suspendido', true)
            .order('cod') // Ordenar por código para consistencia
            .range(offset, offset + batchSize - 1);

        if (response.isEmpty) {
          print('📊 [EMPLEADOS API] No hay más registros en offset $offset');
          break;
        }

        final empleados = response
            .map<EmpleadoModel>((json) => EmpleadoModel.fromMap(json))
            .toList();

        todosLosEmpleados.addAll(empleados);

        print(
            '📊 [EMPLEADOS API] Total acumulado: ${todosLosEmpleados.length} empleados');

        // Si obtuvimos menos registros que el tamaño del lote, es el último
        if (response.length < batchSize) {
          print('📊 [EMPLEADOS API] Último lote completado');
          break;
        }

        offset += batchSize;

        // Pausa para evitar rate limiting
        await Future.delayed(const Duration(milliseconds: 100));
      }

      print(
          '✅ [EMPLEADOS API] TOTAL FINAL: ${todosLosEmpleados.length} empleados activos');
      return todosLosEmpleados;
    } catch (e) {
      print('❌ [EMPLEADOS API] Error obteniendo todos los empleados: $e');
      return [];
    }
  }

  /// Diagnóstico mejorado para identificar límites de Supabase
  Future<void> diagnosticarEmpleados() async {
    try {
      print('🔍 [DIAGNÓSTICO AVANZADO] Iniciando análisis completo...');

      // 1. Test básico de conexión
      print('\n1️⃣ Probando conexión básica...');
      final testBasic =
          await _empleadosClient.from('empleados').select('count').limit(1);
      print('   ✅ Conexión: OK');

      // 2. Contar TODOS los empleados sin filtros
      print('\n2️⃣ Contando TODOS los empleados...');
      final allEmployees = await _empleadosClient
          .from('empleados')
          .select('es_activo, es_liquidado, es_suspendido');
      print('   📊 Total registros en BD: ${allEmployees.length}');

      // 3. Contar empleados activos
      print('\n3️⃣ Analizando empleados activos...');
      int activos = 0, disponibles = 0;
      for (var emp in allEmployees) {
        final esActivo = emp['es_activo'] ?? false;
        final esLiquidado = emp['es_liquidado'] ?? false;
        final esSuspendido = emp['es_suspendido'] ?? false;

        if (esActivo) {
          activos++;
          if (!esLiquidado && !esSuspendido) {
            disponibles++;
          }
        }
      }
      print('   ✅ Activos: $activos');
      print('   🎯 Disponibles para sanción: $disponibles');

      // 4. Test de límites de consulta
      print('\n4️⃣ Probando límites de consulta...');

      final test500 = await _empleadosClient
          .from('empleados')
          .select('cod')
          .eq('es_activo', true)
          .limit(500);
      print('   📊 Test limit(500): ${test500.length} registros');

      final test1000 = await _empleadosClient
          .from('empleados')
          .select('cod')
          .eq('es_activo', true)
          .limit(1000);
      print('   📊 Test limit(1000): ${test1000.length} registros');

      final test2000 = await _empleadosClient
          .from('empleados')
          .select('cod')
          .eq('es_activo', true)
          .limit(2000);
      print('   📊 Test limit(2000): ${test2000.length} registros');

      // 5. Test sin límite
      print('\n5️⃣ Probando consulta SIN límite...');
      final testNoLimit = await _empleadosClient
          .from('empleados')
          .select('cod')
          .eq('es_activo', true);
      print('   📊 Test SIN limit(): ${testNoLimit.length} registros');

      // 6. Análisis de resultados
      print('\n6️⃣ ANÁLISIS DE RESULTADOS:');
      if (testNoLimit.length == test1000.length && disponibles > 1000) {
        print('   🚨 CONFIRMADO: Límite de 1000 registros por consulta');
        print(
            '   💡 Solución: Usar paginación con range() o múltiples consultas');
      } else if (testNoLimit.length > test1000.length) {
        print('   ✅ Sin límite detectado, consulta SIN limit() funciona');
      } else {
        print('   ℹ️  El límite coincide con los datos disponibles');
      }

      print('\n7️⃣ RECOMENDACIONES:');
      if (disponibles > 1000) {
        print('   🔧 Usar getAllEmpleadosActivos() para obtener todos');
        print(
            '   🔧 Implementar búsqueda sin .limit() para resultados completos');
        print('   🔧 Usar .range() para paginación controlada');
      }
    } catch (e) {
      print('❌ [DIAGNÓSTICO] Error: $e');
    }
  }

  /// Obtener todos los departamentos únicos
  Future<List<String>> getDepartamentos() async {
    try {
      print('🔍 [EMPLEADOS API] Obteniendo departamentos únicos...');

      final response = await _empleadosClient
          .from('empleados')
          .select('nomdep')
          .not('nomdep', 'is', null)
          .eq('es_activo', true);

      final departamentos = response
          .map((e) => e['nomdep'] as String)
          .where((dept) => dept.trim().isNotEmpty)
          .toSet()
          .toList();

      departamentos.sort();

      print(
          '✅ [EMPLEADOS API] ${departamentos.length} departamentos encontrados');
      return departamentos;
    } catch (e) {
      print('❌ [EMPLEADOS API] Error obteniendo departamentos: $e');
      return [];
    }
  }

  /// Obtener todos los cargos únicos
  Future<List<String>> getCargos() async {
    try {
      print('🔍 [EMPLEADOS API] Obteniendo cargos únicos...');

      final response = await _empleadosClient
          .from('empleados')
          .select('nomcargo')
          .not('nomcargo', 'is', null)
          .eq('es_activo', true);

      final cargos = response
          .map((e) => e['nomcargo'] as String)
          .where((cargo) => cargo.trim().isNotEmpty)
          .toSet()
          .toList();

      cargos.sort();

      print('✅ [EMPLEADOS API] ${cargos.length} cargos encontrados');
      return cargos;
    } catch (e) {
      print('❌ [EMPLEADOS API] Error obteniendo cargos: $e');
      return [];
    }
  }

  /// Verificar si un empleado puede ser sancionado
  Future<bool> puedeSerSancionado(int cod) async {
    try {
      final response = await _empleadosClient
          .from('empleados')
          .select('es_activo, es_liquidado, es_suspendido')
          .eq('cod', cod)
          .single();

      final esActivo = response['es_activo'] ?? false;
      final esLiquidado = response['es_liquidado'] ?? false;
      final esSuspendido = response['es_suspendido'] ?? false;

      final puedeSerSancionado = esActivo && !esLiquidado && !esSuspendido;

      print(
          '🔍 [EMPLEADOS API] Empleado $cod - Puede ser sancionado: $puedeSerSancionado');
      return puedeSerSancionado;
    } catch (e) {
      print('❌ [EMPLEADOS API] Error verificando empleado $cod: $e');
      return false;
    }
  }

  /// Obtener estadísticas detalladas de empleados
  Future<Map<String, int>> getEstadisticasEmpleados() async {
    try {
      print('📊 [EMPLEADOS API] Obteniendo estadísticas detalladas...');

      // Usar el método optimizado para obtener todos los empleados
      final todosLosEmpleados = await getAllEmpleadosActivos();

      final stats = {
        'total': todosLosEmpleados.length,
        'activos': todosLosEmpleados.length, // Ya están filtrados como activos
        'disponibles_sancion':
            todosLosEmpleados.where((e) => e.puedeSerSancionado).length,
        'departamentos': todosLosEmpleados
            .map((e) => e.nomdep)
            .where((d) => d != null)
            .toSet()
            .length,
        'cargos': todosLosEmpleados
            .map((e) => e.nomcargo)
            .where((c) => c != null)
            .toSet()
            .length,
      };

      print('✅ [EMPLEADOS API] Estadísticas reales:');
      print('   Total activos: ${stats['total']}');
      print('   Disponibles para sanción: ${stats['disponibles_sancion']}');
      print('   Departamentos únicos: ${stats['departamentos']}');
      print('   Cargos únicos: ${stats['cargos']}');

      return stats;
    } catch (e) {
      print('❌ [EMPLEADOS API] Error obteniendo estadísticas: $e');
      return {
        'total': 0,
        'activos': 0,
        'disponibles_sancion': 0,
        'departamentos': 0,
        'cargos': 0,
      };
    }
  }

  /// Búsqueda avanzada con múltiples filtros
  Future<List<EmpleadoModel>> searchEmpleadosAvanzado({
    String? query,
    String? departamento,
    String? cargo,
    bool soloActivos = true,
  }) async {
    try {
      print(
          '🔍 [EMPLEADOS API] Búsqueda avanzada: query=$query, dept=$departamento, cargo=$cargo');

      var queryBuilder = _empleadosClient.from('empleados').select('*');

      // Filtro por texto
      if (query != null && query.trim().isNotEmpty) {
        // 🔥 ARREGLO: Todo en una sola línea sin saltos
        queryBuilder = queryBuilder.or(
            'nombres_completos.ilike.%$query%,nombres.ilike.%$query%,apellidos.ilike.%$query%,cedula.ilike.%$query%,cod.eq.${int.tryParse(query) ?? -1}');
      }

      // Filtros específicos
      if (departamento != null && departamento.isNotEmpty) {
        queryBuilder = queryBuilder.eq('nomdep', departamento);
      }

      if (cargo != null && cargo.isNotEmpty) {
        queryBuilder = queryBuilder.eq('nomcargo', cargo);
      }

      if (soloActivos) {
        queryBuilder = queryBuilder.eq('es_activo', true);
      }

      final response = await queryBuilder.order('nombres_completos');
      // Sin límite para obtener todos los resultados

      print(
          '✅ [EMPLEADOS API] Búsqueda avanzada: ${response.length} resultados');

      final empleados = response
          .map<EmpleadoModel>((json) => EmpleadoModel.fromMap(json))
          .toList();

      // 🔥 NUEVO: Ordenar priorizando coincidencias si hay query
      if (query != null && query.trim().isNotEmpty) {
        empleados.sort((a, b) {
          final queryLower = query.toLowerCase();
          final aStartsWith = a.displayName.toLowerCase().startsWith(queryLower);
          final bStartsWith = b.displayName.toLowerCase().startsWith(queryLower);
          
          if (aStartsWith && !bStartsWith) return -1;
          if (!aStartsWith && bStartsWith) return 1;
          return a.displayName.compareTo(b.displayName);
        });
      }

      return empleados;
    } catch (e) {
      print('❌ [EMPLEADOS API] Error en búsqueda avanzada: $e');
      return [];
    }
  }

  /// Llama esta función desde el Home para hacer diagnóstico
  Future<void> hacerDiagnostico() async {
    await diagnosticarEmpleados();
  }

  /// Probar la conexión específica con el proyecto de empleados
  Future<bool> testConnection() async {
    try {
      print(
          '🔄 [EMPLEADOS API] Probando conexión con proyecto empleados-insevig...');

      final response = await _empleadosClient
          .from('empleados')
          .select('count')
          .eq('es_activo', true)
          .limit(1);

      final isConnected = response.isNotEmpty;
      print(
          '${isConnected ? "✅" : "❌"} [EMPLEADOS API] Conexión: ${isConnected ? "exitosa" : "fallida"}');

      return isConnected;
    } catch (e) {
      print('❌ [EMPLEADOS API] Error de conexión: $e');
      return false;
    }
  }

  /// Obtener resumen rápido para autocompletado
  Future<Map<String, dynamic>?> getEmpleadoResumen(int cod) async {
    try {
      final response = await _empleadosClient
          .from('empleados')
          .select(
              'cod, nombres_completos, nomcargo, nomdep, es_activo, estado, seccion')
          .eq('cod', cod)
          .single();

      return response;
    } catch (e) {
      print('❌ [EMPLEADOS API] Error obteniendo resumen del empleado $cod: $e');
      return null;
    }
  }

  /// Validar acceso a la API de empleados
  Future<bool> validarAccesoAPI() async {
    try {
      // Hacer una consulta simple para verificar permisos
      await _empleadosClient.from('empleados').select('count').limit(1);

      print('✅ [EMPLEADOS API] Acceso validado correctamente');
      return true;
    } catch (e) {
      print('❌ [EMPLEADOS API] Error de acceso: $e');
      print(
          '💡 [EMPLEADOS API] Verifica que las políticas RLS permitan lectura desde sanciones');
      return false;
    }
  }
}