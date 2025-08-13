import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:signature/signature.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:path/path.dart' as path;

import '../models/sancion_model.dart';

/// 🔥 Servicio principal para gestión de sanciones
/// Maneja todas las operaciones CRUD con Supabase
/// 🆕 EXTENDIDO CON SISTEMA DE APROBACIONES Y CÓDIGOS DE DESCUENTO
class SancionService {
  static final SupabaseClient _supabase = Supabase.instance.client;
  static const String _tableName = 'sanciones';
  static const String _bucketName = 'sanciones-files';

  /// =============================================
  /// 🏗️ CREAR SANCIONES
  /// =============================================

  /// Crear nueva sanción con archivos adjuntos
  Future<String?> createSancion({
    required SancionModel sancion,
    File? fotoFile,
    SignatureController? signatureController,
  }) async {
    try {
      print('🏗️ Iniciando creación de sanción...');
      
      // Generar ID único
      final sancionId = const Uuid().v4();
      
      // Preparar datos base
      final sancionData = sancion.copyWith(
        id: sancionId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ).toMap();

      // Subir archivos si existen
      if (fotoFile != null) {
        final fotoUrl = await _uploadFoto(sancionId, fotoFile);
        sancionData['foto_url'] = fotoUrl;
        print('📸 Foto subida: $fotoUrl');
      }

      if (signatureController != null) {
        final firmaPath = await _uploadFirma(sancionId, signatureController);
        sancionData['firma_path'] = firmaPath;
        print('✍️ Firma subida: $firmaPath');
      }

      // Insertar en base de datos
      await _supabase.from(_tableName).insert(sancionData);
      
      print('✅ Sanción creada exitosamente: $sancionId');
      return sancionId;
    } catch (e) {
      print('❌ Error creando sanción: $e');
      rethrow;
    }
  }

  /// =============================================
  /// 📖 CONSULTAR SANCIONES
  /// =============================================

  /// Obtener mis sanciones (del supervisor actual)
  Future<List<SancionModel>> getMySanciones(String supervisorId) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select('''
            id, supervisor_id, empleado_cod, empleado_nombre, puesto, agente,
            fecha, hora, tipo_sancion, observaciones, observaciones_adicionales,
            pendiente, foto_url, firma_path, horas_extras, status,
            comentarios_gerencia, comentarios_rrhh, fecha_revision, reviewed_by,
            created_at, updated_at
          ''')
          .eq('supervisor_id', supervisorId)
          .order('created_at', ascending: false);

      return (response as List)
          .map((data) => SancionModel.fromMap(data))
          .toList();
    } catch (e) {
      print('❌ Error obteniendo mis sanciones: $e');
      rethrow;
    }
  }

  /// Obtener todas las sanciones (para gerencia/RRHH)
  Future<List<SancionModel>> getAllSanciones() async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select('''
            id, supervisor_id, empleado_cod, empleado_nombre, puesto, agente,
            fecha, hora, tipo_sancion, observaciones, observaciones_adicionales,
            pendiente, foto_url, firma_path, horas_extras, status,
            comentarios_gerencia, comentarios_rrhh, fecha_revision, reviewed_by,
            created_at, updated_at
          ''')
          .order('created_at', ascending: false);

      return (response as List)
          .map((data) => SancionModel.fromMap(data))
          .toList();
    } catch (e) {
      print('❌ Error obteniendo todas las sanciones: $e');
      rethrow;
    }
  }

  /// 🆕 Obtener sanciones para gerencia (enviadas + aprobadas por esta gerencia)
  Future<List<SancionModel>> getSancionesParaGerencia() async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select('''
            id, supervisor_id, empleado_cod, empleado_nombre, puesto, agente,
            fecha, hora, tipo_sancion, observaciones, observaciones_adicionales,
            pendiente, foto_url, firma_path, horas_extras, status,
            comentarios_gerencia, comentarios_rrhh, fecha_revision, reviewed_by,
            created_at, updated_at
          ''')
          .or('status.eq.enviado,and(status.eq.aprobado,comentarios_gerencia.not.is.null)')
          .order('created_at', ascending: false);

      return (response as List)
          .map((data) => SancionModel.fromMap(data))
          .toList();
    } catch (e) {
      print('❌ Error obteniendo sanciones para gerencia: $e');
      rethrow;
    }
  }

  /// 🆕 Obtener sanciones para RRHH (aprobadas por gerencia + procesadas)
  Future<List<SancionModel>> getSancionesParaRRHH() async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select('''
            id, supervisor_id, empleado_cod, empleado_nombre, puesto, agente,
            fecha, hora, tipo_sancion, observaciones, observaciones_adicionales,
            pendiente, foto_url, firma_path, horas_extras, status,
            comentarios_gerencia, comentarios_rrhh, fecha_revision, reviewed_by,
            created_at, updated_at
          ''')
          .eq('status', 'aprobado')
          .not('comentarios_gerencia', 'is', null)
          .order('created_at', ascending: false);

      return (response as List)
          .map((data) => SancionModel.fromMap(data))
          .toList();
    } catch (e) {
      print('❌ Error obteniendo sanciones para RRHH: $e');
      rethrow;
    }
  }

  /// Obtener sanción por ID
  Future<SancionModel?> getSancionById(String id) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select('''
            id, supervisor_id, empleado_cod, empleado_nombre, puesto, agente,
            fecha, hora, tipo_sancion, observaciones, observaciones_adicionales,
            pendiente, foto_url, firma_path, horas_extras, status,
            comentarios_gerencia, comentarios_rrhh, fecha_revision, reviewed_by,
            created_at, updated_at
          ''')
          .eq('id', id)
          .single();

      return SancionModel.fromMap(response);
    } catch (e) {
      print('❌ Error obteniendo sanción por ID: $e');
      return null;
    }
  }

  /// Obtener sanciones por empleado
  Future<List<SancionModel>> getSancionesByEmpleado(int empleadoCod) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select('''
            id, supervisor_id, empleado_cod, empleado_nombre, puesto, agente,
            fecha, hora, tipo_sancion, observaciones, observaciones_adicionales,
            pendiente, foto_url, firma_path, horas_extras, status,
            comentarios_gerencia, comentarios_rrhh, fecha_revision, reviewed_by,
            created_at, updated_at
          ''')
          .eq('empleado_cod', empleadoCod)
          .order('created_at', ascending: false);

      return (response as List)
          .map((data) => SancionModel.fromMap(data))
          .toList();
    } catch (e) {
      print('❌ Error obteniendo sanciones del empleado: $e');
      rethrow;
    }
  }

  /// Obtener sanciones por rango de fechas
  Future<List<SancionModel>> getSancionesByDateRange(
    DateTime fechaInicio,
    DateTime fechaFin,
  ) async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select('''
            id, supervisor_id, empleado_cod, empleado_nombre, puesto, agente,
            fecha, hora, tipo_sancion, observaciones, observaciones_adicionales,
            pendiente, foto_url, firma_path, horas_extras, status,
            comentarios_gerencia, comentarios_rrhh, fecha_revision, reviewed_by,
            created_at, updated_at
          ''')
          .gte('fecha', fechaInicio.toIso8601String().split('T')[0])
          .lte('fecha', fechaFin.toIso8601String().split('T')[0])
          .order('created_at', ascending: false);

      return (response as List)
          .map((data) => SancionModel.fromMap(data))
          .toList();
    } catch (e) {
      print('❌ Error obteniendo sanciones por rango: $e');
      rethrow;
    }
  }

  /// Obtener sanciones pendientes
  Future<List<SancionModel>> getSancionesPendientes() async {
    try {
      final response = await _supabase
          .from(_tableName)
          .select('''
            id, supervisor_id, empleado_cod, empleado_nombre, puesto, agente,
            fecha, hora, tipo_sancion, observaciones, observaciones_adicionales,
            pendiente, foto_url, firma_path, horas_extras, status,
            comentarios_gerencia, comentarios_rrhh, fecha_revision, reviewed_by,
            created_at, updated_at
          ''')
          .eq('pendiente', true)
          .order('created_at', ascending: false);

      return (response as List)
          .map((data) => SancionModel.fromMap(data))
          .toList();
    } catch (e) {
      print('❌ Error obteniendo sanciones pendientes: $e');
      rethrow;
    }
  }

  /// =============================================
  /// ✏️ ACTUALIZAR SANCIONES
  /// =============================================

  /// Actualizar sanción con archivos
  Future<bool> updateSancionWithFiles({
    required SancionModel sancion,
    File? nuevaFoto,
    SignatureController? nuevaFirma,
  }) async {
    try {
      print('✏️ Actualizando sanción: ${sancion.id}');
      
      final sancionData = sancion.copyWith(
        updatedAt: DateTime.now(),
      ).toMap();

      // Actualizar foto si se proporciona una nueva
      if (nuevaFoto != null) {
        // Eliminar foto anterior si existe
        if (sancion.fotoUrl != null) {
          await _deleteFoto(sancion.fotoUrl!);
        }
        
        final fotoUrl = await _uploadFoto(sancion.id, nuevaFoto);
        sancionData['foto_url'] = fotoUrl;
        print('📸 Nueva foto subida: $fotoUrl');
      }

      // Actualizar firma si se proporciona una nueva
      if (nuevaFirma != null) {
        // Eliminar firma anterior si existe
        if (sancion.firmaPath != null) {
          await _deleteFirma(sancion.firmaPath!);
        }
        
        final firmaPath = await _uploadFirma(sancion.id, nuevaFirma);
        sancionData['firma_path'] = firmaPath;
        print('✍️ Nueva firma subida: $firmaPath');
      }

      // Actualizar en base de datos
      await _supabase
          .from(_tableName)
          .update(sancionData)
          .eq('id', sancion.id);

      print('✅ Sanción actualizada exitosamente');
      return true;
    } catch (e) {
      print('❌ Error actualizando sanción: $e');
      rethrow;
    }
  }

  /// Actualizar sanción simple (sin archivos)
  Future<bool> updateSancionSimple(SancionModel sancion) async {
    try {
      final sancionData = sancion.copyWith(
        updatedAt: DateTime.now(),
      ).toMap();

      await _supabase
          .from(_tableName)
          .update(sancionData)
          .eq('id', sancion.id);

      print('✅ Sanción actualizada (simple): ${sancion.id}');
      return true;
    } catch (e) {
      print('❌ Error actualizando sanción simple: $e');
      rethrow;
    }
  }

  /// =============================================
  /// 🔄 CAMBIOS DE ESTADO
  /// =============================================

  /// Cambiar status de sanción
  Future<bool> changeStatus(
    String sancionId,
    String newStatus, {
    String? comentarios,
    String? reviewedBy,
  }) async {
    try {
      final updateData = {
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (comentarios != null) {
        updateData['comentarios_gerencia'] = comentarios;
      }

      if (reviewedBy != null) {
        updateData['reviewed_by'] = reviewedBy;
        updateData['fecha_revision'] = DateTime.now().toIso8601String();
      }

      await _supabase
          .from(_tableName)
          .update(updateData)
          .eq('id', sancionId);

      print('✅ Status cambiado: $sancionId -> $newStatus');
      return true;
    } catch (e) {
      print('❌ Error cambiando status: $e');
      rethrow;
    }
  }

  /// 🆕 Actualizar sanción con procesamiento RRHH específico
  Future<bool> updateSancionRRHH(
    String sancionId,
    String status,
    String comentariosRrhh,
    String reviewedBy,
  ) async {
    try {
      await _supabase
          .from(_tableName)
          .update({
            'status': status,
            'comentarios_rrhh': comentariosRrhh,
            'reviewed_by': reviewedBy,
            'fecha_revision': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', sancionId);

      print('✅ Sanción $sancionId procesada por RRHH: $status');
      return true;
    } catch (e) {
      print('❌ Error procesando sanción por RRHH: $e');
      rethrow;
    }
  }

  /// Marcar sanción como pendiente/resuelta
  Future<bool> togglePendiente(String sancionId, bool pendiente) async {
    try {
      await _supabase
          .from(_tableName)
          .update({
            'pendiente': pendiente,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', sancionId);

      print('✅ Pendiente actualizado: $sancionId -> $pendiente');
      return true;
    } catch (e) {
      print('❌ Error actualizando pendiente: $e');
      rethrow;
    }
  }

  /// =============================================
  /// 🗑️ ELIMINAR SANCIONES
  /// =============================================

  /// Eliminar sanción (solo borradores)
  Future<bool> deleteSancion(String sancionId) async {
    try {
      // Obtener sanción para verificar archivos
      final sancion = await getSancionById(sancionId);
      if (sancion == null) {
        throw Exception('Sanción no encontrada');
      }

      // Solo permitir eliminar borradores
      if (sancion.status != 'borrador') {
        throw Exception('Solo se pueden eliminar sanciones en estado borrador');
      }

      // Eliminar archivos asociados
      if (sancion.fotoUrl != null) {
        await _deleteFoto(sancion.fotoUrl!);
      }
      
      if (sancion.firmaPath != null) {
        await _deleteFirma(sancion.firmaPath!);
      }

      // Eliminar de base de datos
      await _supabase
          .from(_tableName)
          .delete()
          .eq('id', sancionId);

      print('✅ Sanción eliminada: $sancionId');
      return true;
    } catch (e) {
      print('❌ Error eliminando sanción: $e');
      rethrow;
    }
  }

  /// =============================================
  /// 📈 ESTADÍSTICAS
  /// =============================================

  /// Obtener estadísticas de sanciones
  Future<Map<String, dynamic>> getEstadisticas({String? supervisorId}) async {
    try {
      var query = _supabase.from(_tableName).select('status, tipo_sancion, created_at, pendiente');
      
      if (supervisorId != null) {
        query = query.eq('supervisor_id', supervisorId);
      }

      final response = await query;
      final sanciones = response as List;

      final stats = <String, dynamic>{
        'total': sanciones.length,
        'borradores': 0,
        'enviadas': 0,
        'aprobadas': 0,
        'rechazadas': 0,
        'pendientes': 0,
        'resueltas': 0,
        'porTipo': <String, int>{},
        'ultimoMes': 0,
      };

      final ahora = DateTime.now();
      final hace30Dias = ahora.subtract(const Duration(days: 30));

      for (var sancion in sanciones) {
        final status = sancion['status'] as String;
        final tipoSancion = sancion['tipo_sancion'] as String;
        final createdAt = DateTime.parse(sancion['created_at']);
        final pendiente = sancion['pendiente'] as bool? ?? false;

        // Contar por status
        switch (status) {
          case 'borrador':
            stats['borradores']++;
            break;
          case 'enviado':
            stats['enviadas']++;
            break;
          case 'aprobado':
            stats['aprobadas']++;
            break;
          case 'rechazado':
            stats['rechazadas']++;
            break;
        }

        // Contar pendientes
        if (pendiente) {
          stats['pendientes']++;
        } else {
          stats['resueltas']++;
        }

        // Contar por tipo
        final porTipo = stats['porTipo'] as Map<String, int>;
        porTipo[tipoSancion] = (porTipo[tipoSancion] ?? 0) + 1;

        // Último mes
        if (createdAt.isAfter(hace30Dias)) {
          stats['ultimoMes']++;
        }
      }

      return stats;
    } catch (e) {
      print('❌ Error obteniendo estadísticas: $e');
      rethrow;
    }
  }

  /// 🆕 Obtener estadísticas por rol
  Future<Map<String, dynamic>> getEstadisticasByRole() async {
    try {
      // Obtener todas las sanciones con códigos
      final response = await _supabase
          .from(_tableName)
          .select('status, comentarios_gerencia, comentarios_rrhh')
          .not('comentarios_gerencia', 'is', null);

      final sanciones = response as List;
      
      int totalConDescuento = 0;
      int modificadas = 0;
      int anuladas = 0;
      Map<String, int> porCodigo = {};

      for (var sancion in sanciones) {
        final comentariosGerencia = sancion['comentarios_gerencia'] as String?;
        final comentariosRrhh = sancion['comentarios_rrhh'] as String?;
        final status = sancion['status'] as String;

        // Contar con descuento
        if (comentariosGerencia != null && 
            !comentariosGerencia.startsWith('SIN_DESC') &&
            !comentariosGerencia.startsWith('RECHAZADO')) {
          totalConDescuento++;
        }

        // Contar por código
        if (comentariosGerencia != null) {
          final codigo = comentariosGerencia.split('|')[0];
          porCodigo[codigo] = (porCodigo[codigo] ?? 0) + 1;
        }

        // Contar modificadas por RRHH
        if (comentariosRrhh != null && comentariosRrhh.startsWith('MODIFICADO')) {
          modificadas++;
        }

        // Contar anuladas por RRHH
        if (status == 'rechazado' && 
            comentariosRrhh != null && 
            comentariosRrhh.startsWith('ANULADO_RRHH')) {
          anuladas++;
        }
      }

      return {
        'total_con_descuento': totalConDescuento,
        'modificadas': modificadas,
        'anuladas': anuladas,
        'por_codigo': porCodigo,
      };
    } catch (e) {
      print('❌ Error obteniendo estadísticas por rol: $e');
      return {};
    }
  }

  /// 🆕 Obtener sanciones que requieren atención urgente
  Future<List<SancionModel>> getSancionesUrgentes() async {
    try {
      final DateTime hace3Dias = DateTime.now().subtract(const Duration(days: 3));
      final DateTime hace7Dias = DateTime.now().subtract(const Duration(days: 7));

      final response = await _supabase
          .from(_tableName)
          .select('''
            id, supervisor_id, empleado_cod, empleado_nombre, puesto, agente,
            fecha, hora, tipo_sancion, observaciones, observaciones_adicionales,
            pendiente, foto_url, firma_path, horas_extras, status,
            comentarios_gerencia, comentarios_rrhh, fecha_revision, reviewed_by,
            created_at, updated_at
          ''')
          .or(
            'and(status.eq.borrador,created_at.lt.${hace7Dias.toIso8601String()}),'
            'and(status.eq.enviado,created_at.lt.${hace3Dias.toIso8601String()})'
          )
          .order('created_at', ascending: true);

      final sanciones = (response as List)
          .map((data) => SancionModel.fromMap(data))
          .toList();

      // Agregar también las pendientes de RRHH por más de 2 días
      final hace2Dias = DateTime.now().subtract(const Duration(days: 2));
      final responsePendientesRRHH = await _supabase
          .from(_tableName)
          .select('''
            id, supervisor_id, empleado_cod, empleado_nombre, puesto, agente,
            fecha, hora, tipo_sancion, observaciones, observaciones_adicionales,
            pendiente, foto_url, firma_path, horas_extras, status,
            comentarios_gerencia, comentarios_rrhh, fecha_revision, reviewed_by,
            created_at, updated_at
          ''')
          .eq('status', 'aprobado')
          .not('comentarios_gerencia', 'is', null)
          .is_('comentarios_rrhh', null)
          .lt('fecha_revision', hace2Dias.toIso8601String())
          .order('fecha_revision', ascending: true);

      final pendientesRRHH = (responsePendientesRRHH as List)
          .map((data) => SancionModel.fromMap(data))
          .toList();

      // Combinar y eliminar duplicados
      final todasUrgentes = [...sanciones, ...pendientesRRHH];
      final idsVistos = <String>{};
      
      return todasUrgentes.where((sancion) {
        if (idsVistos.contains(sancion.id)) {
          return false;
        }
        idsVistos.add(sancion.id);
        return true;
      }).toList();

    } catch (e) {
      print('❌ Error obteniendo sanciones urgentes: $e');
      return [];
    }
  }

  /// 🆕 Obtener resumen ejecutivo de sanciones
  Future<Map<String, dynamic>> getResumenEjecutivo({
    DateTime? fechaInicio,
    DateTime? fechaFin,
  }) async {
    try {
      fechaInicio ??= DateTime.now().subtract(const Duration(days: 30));
      fechaFin ??= DateTime.now();

      final response = await _supabase
          .from(_tableName)
          .select('''
            status, comentarios_gerencia, comentarios_rrhh, 
            tipo_sancion, created_at, pendiente
          ''')
          .gte('created_at', fechaInicio.toIso8601String())
          .lte('created_at', fechaFin.toIso8601String())
          .order('created_at', ascending: false);

      final sanciones = response as List;
      
      // Contadores principales
      int total = sanciones.length;
      int borradores = 0;
      int enviadas = 0;
      int aprobadas = 0;
      int rechazadas = 0;
      int pendientesRRHH = 0;
      int procesadasRRHH = 0;
      int pendientesAccion = 0;
      int conDescuento = 0;
      
      Map<String, int> porTipo = {};
      Map<String, int> porCodigo = {};

      for (var sancion in sanciones) {
        final status = sancion['status'] as String;
        final comentariosGerencia = sancion['comentarios_gerencia'] as String?;
        final comentariosRrhh = sancion['comentarios_rrhh'] as String?;
        final tipoSancion = sancion['tipo_sancion'] as String;
        final pendiente = sancion['pendiente'] as bool? ?? false;

        // Contar por status
        switch (status) {
          case 'borrador':
            borradores++;
            break;
          case 'enviado':
            enviadas++;
            break;
          case 'aprobado':
            aprobadas++;
            if (comentariosGerencia != null && comentariosRrhh == null) {
              pendientesRRHH++;
            } else if (comentariosRrhh != null) {
              procesadasRRHH++;
            }
            break;
          case 'rechazado':
            rechazadas++;
            break;
        }

        // Contar pendientes de acción
        if (pendiente) {
          pendientesAccion++;
        }

        // Contar por tipo
        porTipo[tipoSancion] = (porTipo[tipoSancion] ?? 0) + 1;

        // Contar con descuento
        if (comentariosGerencia != null && 
            !comentariosGerencia.startsWith('SIN_DESC') &&
            !comentariosGerencia.startsWith('RECHAZADO')) {
          conDescuento++;
          
          // Contar por código
          final codigo = comentariosGerencia.split('|')[0];
          porCodigo[codigo] = (porCodigo[codigo] ?? 0) + 1;
        }
      }

      return {
        'periodo': {
          'inicio': fechaInicio.toIso8601String(),
          'fin': fechaFin.toIso8601String(),
          'dias': fechaFin.difference(fechaInicio).inDays,
        },
        'totales': {
          'total': total,
          'borradores': borradores,
          'enviadas': enviadas,
          'aprobadas': aprobadas,
          'rechazadas': rechazadas,
          'pendientes_rrhh': pendientesRRHH,
          'procesadas_rrhh': procesadasRRHH,
          'pendientes_accion': pendientesAccion,
          'con_descuento': conDescuento,
        },
        'distribucion': {
          'por_tipo': porTipo,
          'por_codigo': porCodigo,
        },
        'metricas': {
          'tasa_aprobacion': total > 0 ? (aprobadas / total * 100).round() : 0,
          'tasa_rechazo': total > 0 ? (rechazadas / total * 100).round() : 0,
          'tasa_descuento': aprobadas > 0 ? (conDescuento / aprobadas * 100).round() : 0,
          'tiempo_promedio_procesamiento': _calcularTiempoPromedioProcesamient(sanciones),
        },
      };
    } catch (e) {
      print('❌ Error obteniendo resumen ejecutivo: $e');
      return {};
    }
  }

  /// Calcular tiempo promedio de procesamiento
  double _calcularTiempoPromedioProcesamient(List sanciones) {
    final procesadas = sanciones.where((s) => 
      s['status'] == 'aprobado' || s['status'] == 'rechazado'
    ).toList();

    if (procesadas.isEmpty) return 0.0;

    double totalDias = 0;
    int contador = 0;

    for (var sancion in procesadas) {
      try {
        final createdAt = DateTime.parse(sancion['created_at']);
        final fechaRevision = sancion['fecha_revision'] != null 
          ? DateTime.parse(sancion['fecha_revision'])
          : DateTime.now();
        
        final dias = fechaRevision.difference(createdAt).inDays;
        totalDias += dias;
        contador++;
      } catch (e) {
        // Ignorar errores de parsing de fechas
      }
    }

    return contador > 0 ? totalDias / contador : 0.0;
  }

  /// 🆕 Obtener alertas del sistema
  Future<List<Map<String, dynamic>>> getAlertas() async {
    try {
      final alertas = <Map<String, dynamic>>[];
      
      // Alertas de sanciones urgentes
      final urgentes = await getSancionesUrgentes();
      if (urgentes.isNotEmpty) {
        alertas.add({
          'tipo': 'urgente',
          'titulo': '⚠️ Sanciones que requieren atención',
          'mensaje': '${urgentes.length} sanciones requieren atención urgente',
          'cantidad': urgentes.length,
          'accion': 'revisar_urgentes',
          'prioridad': 'alta',
        });
      }

      // Alertas de sanciones pendientes RRHH
      final pendientesRRHH = await _supabase
          .from(_tableName)
          .select('id')
          .eq('status', 'aprobado')
          .not('comentarios_gerencia', 'is', null)
          .is_('comentarios_rrhh', null);

      if ((pendientesRRHH as List).isNotEmpty) {
        alertas.add({
          'tipo': 'pendiente_rrhh',
          'titulo': '📋 Pendientes de RRHH',
          'mensaje': '${pendientesRRHH.length} sanciones esperan procesamiento de RRHH',
          'cantidad': pendientesRRHH.length,
          'accion': 'revisar_rrhh',
          'prioridad': 'media',
        });
      }

      // Alertas de borradores antiguos
      final hace7Dias = DateTime.now().subtract(const Duration(days: 7));
      final borradoresAntiguos = await _supabase
          .from(_tableName)
          .select('id')
          .eq('status', 'borrador')
          .lt('created_at', hace7Dias.toIso8601String());

      if ((borradoresAntiguos as List).isNotEmpty) {
        alertas.add({
          'tipo': 'borradores_antiguos',
          'titulo': '📝 Borradores sin enviar',
          'mensaje': '${borradoresAntiguos.length} borradores llevan más de 7 días sin enviar',
          'cantidad': borradoresAntiguos.length,
          'accion': 'revisar_borradores',
          'prioridad': 'baja',
        });
      }

      return alertas;
    } catch (e) {
      print('❌ Error obteniendo alertas: $e');
      return [];
    }
  }

  /// 🆕 Generar reporte detallado para exportación
  Future<Map<String, dynamic>> generarReporteDetallado({
    DateTime? fechaInicio,
    DateTime? fechaFin,
    String? filtroStatus,
    String? filtroTipo,
    List<String>? empleadosCodigos,
  }) async {
    try {
      var query = _supabase.from(_tableName).select('''
        id, supervisor_id, empleado_cod, empleado_nombre, puesto, agente,
        fecha, hora, tipo_sancion, observaciones, observaciones_adicionales,
        pendiente, foto_url, firma_path, horas_extras, status,
        comentarios_gerencia, comentarios_rrhh, fecha_revision, reviewed_by,
        created_at, updated_at
      ''');

      // Aplicar filtros
      if (fechaInicio != null) {
        query = query.gte('created_at', fechaInicio.toIso8601String());
      }
      
      if (fechaFin != null) {
        query = query.lte('created_at', fechaFin.toIso8601String());
      }
      
      if (filtroStatus != null && filtroStatus != 'todos') {
        query = query.eq('status', filtroStatus);
      }
      
      if (filtroTipo != null && filtroTipo != 'todos') {
        query = query.eq('tipo_sancion', filtroTipo);
      }
      
      if (empleadosCodigos != null && empleadosCodigos.isNotEmpty) {
        query = query.in_('empleado_cod', empleadosCodigos);
      }

      final response = await query.order('created_at', ascending: false);

      final sanciones = (response as List)
          .map((data) => SancionModel.fromMap(data))
          .toList();

      // Generar estadísticas del reporte
      final estadisticas = _generarEstadisticasReporte(sanciones);

      return {
        'metadata': {
          'generado_en': DateTime.now().toIso8601String(),
          'total_registros': sanciones.length,
          'filtros_aplicados': {
            'fecha_inicio': fechaInicio?.toIso8601String(),
            'fecha_fin': fechaFin?.toIso8601String(),
            'status': filtroStatus,
            'tipo': filtroTipo,
            'empleados_especificos': empleadosCodigos?.length ?? 0,
          },
        },
        'sanciones': sanciones.map((s) => s.toMap()).toList(),
        'estadisticas': estadisticas,
      };
    } catch (e) {
      print('❌ Error generando reporte detallado: $e');
      rethrow;
    }
  }

  /// Generar estadísticas para reporte
  Map<String, dynamic> _generarEstadisticasReporte(List<SancionModel> sanciones) {
    final stats = <String, dynamic>{};
    
    // Contadores básicos
    stats['total'] = sanciones.length;
    stats['por_status'] = <String, int>{};
    stats['por_tipo'] = <String, int>{};
    stats['por_empleado'] = <String, int>{};
    stats['por_mes'] = <String, int>{};
    stats['con_descuento'] = 0;
    stats['pendientes'] = 0;
    
    for (var sancion in sanciones) {
      // Por status
      stats['por_status'][sancion.status] = 
          (stats['por_status'][sancion.status] ?? 0) + 1;
      
      // Por tipo
      stats['por_tipo'][sancion.tipoSancion] = 
          (stats['por_tipo'][sancion.tipoSancion] ?? 0) + 1;
      
      // Por empleado
      final empleado = '${sancion.empleadoNombre} (${sancion.empleadoCod})';
      stats['por_empleado'][empleado] = 
          (stats['por_empleado'][empleado] ?? 0) + 1;
      
      // Por mes
      final mes = '${sancion.createdAt.year}-${sancion.createdAt.month.toString().padLeft(2, '0')}';
      stats['por_mes'][mes] = (stats['por_mes'][mes] ?? 0) + 1;
      
      // Con descuento
      if (sancion.tieneDescuento) {
        stats['con_descuento']++;
      }
      
      // Pendientes
      if (sancion.pendiente) {
        stats['pendientes']++;
      }
    }
    
    return stats;
  }

  /// =============================================
  /// 📁 GESTIÓN DE ARCHIVOS
  /// =============================================

  /// Subir foto de sanción
  Future<String> _uploadFoto(String sancionId, File fotoFile) async {
    try {
      // Comprimir imagen
      final compressedImage = await _compressImage(fotoFile);
      
      // Generar nombre único
      final fileName = 'fotos/${sancionId}_foto_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // Subir a Supabase Storage
      await _supabase.storage
          .from(_bucketName)
          .uploadBinary(fileName, compressedImage);
      
      // Obtener URL pública
      final publicUrl = _supabase.storage
          .from(_bucketName)
          .getPublicUrl(fileName);
      
      return publicUrl;
    } catch (e) {
      print('❌ Error subiendo foto: $e');
      rethrow;
    }
  }

  /// Subir firma de sanción
  Future<String> _uploadFirma(String sancionId, SignatureController signatureController) async {
    try {
      // Generar imagen de la firma
      final signatureImage = await signatureController.toPngBytes();
      if (signatureImage == null) {
        throw Exception('No se pudo generar la imagen de la firma');
      }
      
      // Generar nombre único
      final fileName = 'firmas/${sancionId}_firma_${DateTime.now().millisecondsSinceEpoch}.png';
      
      // Subir a Supabase Storage
      await _supabase.storage
          .from(_bucketName)
          .uploadBinary(fileName, signatureImage);
      
      // Obtener URL pública
      final publicUrl = _supabase.storage
          .from(_bucketName)
          .getPublicUrl(fileName);
      
      return publicUrl;
    } catch (e) {
      print('❌ Error subiendo firma: $e');
      rethrow;
    }
  }

  /// Comprimir imagen
  Future<Uint8List> _compressImage(File imageFile) async {
    try {
      final compressedImage = await FlutterImageCompress.compressWithFile(
        imageFile.absolute.path,
        quality: 70,
        minWidth: 800,
        minHeight: 600,
      );
      
      return compressedImage ?? imageFile.readAsBytesSync();
    } catch (e) {
      print('⚠️ Error comprimiendo imagen, usando original: $e');
      return imageFile.readAsBytesSync();
    }
  }

  /// Eliminar foto
  Future<void> _deleteFoto(String fotoUrl) async {
    try {
      final fileName = _extractFileNameFromUrl(fotoUrl);
      if (fileName.isNotEmpty) {
        await _supabase.storage
            .from(_bucketName)
            .remove([fileName]);
        print('🗑️ Foto eliminada: $fileName');
      }
    } catch (e) {
      print('⚠️ Error eliminando foto: $e');
    }
  }

  /// Eliminar firma
  Future<void> _deleteFirma(String firmaPath) async {
    try {
      final fileName = _extractFileNameFromUrl(firmaPath);
      if (fileName.isNotEmpty) {
        await _supabase.storage
            .from(_bucketName)
            .remove([fileName]);
        print('🗑️ Firma eliminada: $fileName');
      }
    } catch (e) {
      print('⚠️ Error eliminando firma: $e');
    }
  }

  /// Extraer nombre de archivo de URL
  String _extractFileNameFromUrl(String url) {
    try {
      final uri = Uri.parse(url);
      final segments = uri.pathSegments;
      
      // Buscar el segmento que contiene el nombre del archivo
      for (int i = 0; i < segments.length; i++) {
        if (segments[i] == _bucketName && i + 1 < segments.length) {
          // Reunir todos los segmentos restantes (para manejar subcarpetas)
          return segments.sublist(i + 1).join('/');
        }
      }
      
      return '';
    } catch (e) {
      print('⚠️ Error extrayendo nombre de archivo: $e');
      return '';
    }
  }

  /// =============================================
  /// 🔧 UTILIDADES
  /// =============================================

  /// Validar imagen antes de subir
  Future<Map<String, dynamic>> validateImage(File imageFile) async {
    try {
      final fileSize = await imageFile.length();
      final maxSize = 10 * 1024 * 1024; // 10MB
      
      final extension = path.extension(imageFile.path).toLowerCase();
      final allowedExtensions = ['.jpg', '.jpeg', '.png'];
      
      return {
        'isValid': fileSize <= maxSize && allowedExtensions.contains(extension),
        'fileSize': fileSize,
        'maxSize': maxSize,
        'extension': extension,
        'allowedExtensions': allowedExtensions,
      };
    } catch (e) {
      return {
        'isValid': false,
        'error': e.toString(),
      };
    }
  }

  /// Limpiar archivos temporales
  Future<void> cleanupTempFiles() async {
    try {
      // En web no hay archivos temporales que limpiar
      if (kIsWeb) return;
      
      // Aquí podrías implementar limpieza de archivos temporales en móvil
      print('🧹 Limpieza de archivos temporales completada');
    } catch (e) {
      print('⚠️ Error en limpieza: $e');
    }
  }

  /// Obtener información del servicio
  Map<String, dynamic> getServiceInfo() {
    return {
      'service_name': 'SancionService',
      'table_name': _tableName,
      'bucket_name': _bucketName,
      'features': [
        'CRUD completo',
        'Gestión de archivos',
        'Compresión de imágenes',
        'Sistema de aprobaciones', // 🆕
        'Códigos de descuento',     // 🆕
        'Procesamiento RRHH',       // 🆕
        'Estadísticas avanzadas',   // 🆕
        'Alertas del sistema',      // 🆕
      ],
      'version': '2.0.0', // 🆕 Actualizada
    };
  }
}