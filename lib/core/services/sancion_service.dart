import 'dart:io';
import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:signature/signature.dart';
import '../config/supabase_config.dart';
import '../models/sancion_model.dart';

/// Servicio principal para manejar sanciones
/// Incluye funcionalidad offline como tu app Kivy
class SancionService {
  SupabaseClient get _supabase => SupabaseConfig.sancionesClient;

  /// Crear nueva sanción (función principal como en Kivy)
  Future<String> createSancion({
    required SancionModel sancion,
    File? fotoFile,
    SignatureController? signatureController,
  }) async {
    try {
      print('📝 Creando sanción para ${sancion.empleadoNombre}...');

      String? fotoUrl;
      String? firmaPath;

      // 1. Subir foto si existe
      if (fotoFile != null) {
        fotoUrl = await _uploadFoto(fotoFile, sancion.id);
        print('📷 Foto subida: $fotoUrl');
      }

      // 2. Subir firma si existe
      if (signatureController != null && signatureController.isNotEmpty) {
        firmaPath = await _uploadFirma(signatureController, sancion.id);
        print('✍️ Firma subida: $firmaPath');
      }

      // 3. Crear sanción con archivos
      final sancionConArchivos = sancion.copyWith(
        fotoUrl: fotoUrl,
        firmaPath: firmaPath,
        updatedAt: DateTime.now(),
      );

      // 4. Guardar en Supabase
      final response = await _supabase
          .from('sanciones')
          .insert(sancionConArchivos.toMap())
          .select()
          .single();

      print('✅ Sanción creada exitosamente: ${response['id']}');
      return response['id'];
    } catch (e) {
      print('❌ Error creando sanción: $e');
      rethrow;
    }
  }

  /// 🔥 ACTUALIZAR SANCIÓN EXISTENTE - MÉTODO CORREGIDO
  Future<bool> updateSancion(
    SancionModel sancion, {
    File? nuevaFoto,
    SignatureController? nuevaFirma,
  }) async {
    try {
      print('🔄 Actualizando sanción ${sancion.id}...');

      String? fotoUrl = sancion.fotoUrl;
      String? firmaPath = sancion.firmaPath;

      // 1. Subir nueva foto si se proporcionó
      if (nuevaFoto != null) {
        fotoUrl = await _uploadFoto(nuevaFoto, sancion.id);
        print('📷 Nueva foto subida: $fotoUrl');
      }

      // 2. Subir nueva firma si se proporcionó
      if (nuevaFirma != null && nuevaFirma.isNotEmpty) {
        firmaPath = await _uploadFirma(nuevaFirma, sancion.id);
        print('✍️ Nueva firma subida: $firmaPath');
      }

      // 3. Preparar datos para actualización (sin campos que no se pueden cambiar)
      final updateData = {
        'empleado_cod': sancion.empleadoCod,
        'empleado_nombre': sancion.empleadoNombre,
        'puesto': sancion.puesto,
        'agente': sancion.agente,
        'fecha': sancion.fecha
            .toIso8601String()
            .split('T')[0], // Solo fecha YYYY-MM-DD
        'hora': sancion.hora,
        'tipo_sancion': sancion.tipoSancion,
        'observaciones': sancion.observaciones,
        'observaciones_adicionales': sancion.observacionesAdicionales,
        'pendiente': sancion.pendiente,
        'horas_extras': sancion.horasExtras,
        'status': sancion.status,
        'foto_url': fotoUrl,
        'firma_path': firmaPath,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // 4. Actualizar en Supabase
      final response = await _supabase
          .from('sanciones')
          .update(updateData)
          .eq('id', sancion.id)
          .select();

      if (response.isNotEmpty) {
        print('✅ Sanción actualizada exitosamente: ${sancion.id}');
        return true;
      } else {
        print('❌ No se pudo actualizar la sanción: respuesta vacía');
        return false;
      }
    } catch (e) {
      print('❌ Error actualizando sanción: $e');
      print('❌ Detalles del error: ${e.toString()}');
      rethrow;
    }
  }

  /// Subir foto de sanción
  Future<String?> _uploadFoto(File fotoFile, String sancionId) async {
    try {
      final fileName =
          '${sancionId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = 'sanciones/$fileName';

      await _supabase.storage.from('sancion-photos').upload(filePath, fotoFile);

      return _supabase.storage.from('sancion-photos').getPublicUrl(filePath);
    } catch (e) {
      print('❌ Error subiendo foto: $e');
      return null;
    }
  }

  /// Subir firma digital
  Future<String?> _uploadFirma(
      SignatureController controller, String sancionId) async {
    try {
      final signature = await controller.toPngBytes();
      if (signature == null) return null;

      final fileName =
          '${sancionId}_signature_${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = 'firmas/$fileName';

      await _supabase.storage
          .from('sancion-signatures')
          .uploadBinary(filePath, signature);

      return _supabase.storage
          .from('sancion-signatures')
          .getPublicUrl(filePath);
    } catch (e) {
      print('❌ Error subiendo firma: $e');
      return null;
    }
  }

  /// Obtener sanciones del supervisor actual
  Future<List<SancionModel>> getMySanciones(String supervisorId) async {
    try {
      final response = await _supabase
          .from('sanciones')
          .select('*')
          .eq('supervisor_id', supervisorId)
          .order('created_at', ascending: false);

      return response
          .map<SancionModel>((json) => SancionModel.fromMap(json))
          .toList();
    } catch (e) {
      print('❌ Error obteniendo mis sanciones: $e');
      return [];
    }
  }

  /// Obtener todas las sanciones (para gerencia/RRHH)
  Future<List<SancionModel>> getAllSanciones() async {
    try {
      final response = await _supabase
          .from('sanciones')
          .select('*')
          .order('created_at', ascending: false);

      return response
          .map<SancionModel>((json) => SancionModel.fromMap(json))
          .toList();
    } catch (e) {
      print('❌ Error obteniendo todas las sanciones: $e');
      return [];
    }
  }

  /// Obtener sanciones por empleado
  Future<List<SancionModel>> getSancionesByEmpleado(int empleadoCod) async {
    try {
      final response = await _supabase
          .from('sanciones')
          .select('*')
          .eq('empleado_cod', empleadoCod)
          .order('created_at', ascending: false);

      return response
          .map<SancionModel>((json) => SancionModel.fromMap(json))
          .toList();
    } catch (e) {
      print('❌ Error obteniendo sanciones del empleado: $e');
      return [];
    }
  }

  /// Obtener sanciones por fechas
  Future<List<SancionModel>> getSancionesByDateRange(
    DateTime fechaInicio,
    DateTime fechaFin,
  ) async {
    try {
      final response = await _supabase
          .from('sanciones')
          .select('*')
          .gte('fecha', fechaInicio.toIso8601String().split('T')[0])
          .lte('fecha', fechaFin.toIso8601String().split('T')[0])
          .order('created_at', ascending: false);

      return response
          .map<SancionModel>((json) => SancionModel.fromMap(json))
          .toList();
    } catch (e) {
      print('❌ Error obteniendo sanciones por rango: $e');
      return [];
    }
  }

  /// Obtener sanciones pendientes
  Future<List<SancionModel>> getSancionesPendientes() async {
    try {
      final response = await _supabase
          .from('sanciones')
          .select('*')
          .eq('pendiente', true)
          .order('created_at', ascending: false);

      return response
          .map<SancionModel>((json) => SancionModel.fromMap(json))
          .toList();
    } catch (e) {
      print('❌ Error obteniendo sanciones pendientes: $e');
      return [];
    }
  }

  /// Cambiar status de sanción (borrador -> enviado -> aprobado/rechazado)
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

      await _supabase.from('sanciones').update(updateData).eq('id', sancionId);

      print('✅ Status cambiado a $newStatus para sanción $sancionId');
      return true;
    } catch (e) {
      print('❌ Error cambiando status: $e');
      return false;
    }
  }

  /// Marcar sanción como pendiente/resuelta
  Future<bool> togglePendiente(String sancionId, bool pendiente) async {
    try {
      await _supabase.from('sanciones').update({
        'pendiente': pendiente,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', sancionId);

      print('✅ Sanción marcada como ${pendiente ? "pendiente" : "resuelta"}');
      return true;
    } catch (e) {
      print('❌ Error cambiando estado pendiente: $e');
      return false;
    }
  }

  /// Eliminar sanción (solo borradores)
  Future<bool> deleteSancion(String sancionId) async {
    try {
      await _supabase
          .from('sanciones')
          .delete()
          .eq('id', sancionId)
          .eq('status', 'borrador');

      print('✅ Sanción eliminada: $sancionId');
      return true;
    } catch (e) {
      print('❌ Error eliminando sanción: $e');
      return false;
    }
  }

  /// Obtener estadísticas de sanciones
  Future<Map<String, dynamic>> getEstadisticas({String? supervisorId}) async {
    try {
      var query = _supabase.from('sanciones').select('*');

      if (supervisorId != null) {
        query = query.eq('supervisor_id', supervisorId);
      }

      final response = await query;

      final stats = {
        'total': response.length,
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

      for (var sancion in response) {
        final status = sancion['status'];
        final pendiente = sancion['pendiente'] ?? false;
        final fecha = DateTime.tryParse(sancion['created_at'] ?? '');
        final tipo = sancion['tipo_sancion'];

        // Contar por status
        switch (status) {
          case 'borrador':
            stats['borradores'] = (stats['borradores'] as int) + 1;
            break;
          case 'enviado':
            stats['enviadas'] = (stats['enviadas'] as int) + 1;
            break;
          case 'aprobado':
            stats['aprobadas'] = (stats['aprobadas'] as int) + 1;
            break;
          case 'rechazado':
            stats['rechazadas'] = (stats['rechazadas'] as int) + 1;
            break;
        }

        // Contar pendientes
        if (pendiente) {
          stats['pendientes'] = (stats['pendientes'] as int) + 1;
        } else {
          stats['resueltas'] = (stats['resueltas'] as int) + 1;
        }

        // Contar por tipo
        final porTipo = stats['porTipo'] as Map<String, int>;
        porTipo[tipo] = (porTipo[tipo] ?? 0) + 1;

        // Último mes
        if (fecha != null && fecha.isAfter(hace30Dias)) {
          stats['ultimoMes'] = (stats['ultimoMes'] as int) + 1;
        }
      }

      return stats;
    } catch (e) {
      print('❌ Error obteniendo estadísticas: $e');
      return {
        'total': 0,
        'borradores': 0,
        'enviadas': 0,
        'aprobadas': 0,
        'rechazadas': 0,
        'pendientes': 0,
        'resueltas': 0,
        'porTipo': <String, int>{},
        'ultimoMes': 0,
      };
    }
  }

  /// Obtener sanción por ID
  Future<SancionModel?> getSancionById(String id) async {
    try {
      final response =
          await _supabase.from('sanciones').select('*').eq('id', id).single();

      return SancionModel.fromMap(response);
    } catch (e) {
      print('❌ Error obteniendo sanción $id: $e');
      return null;
    }
  }

  /// 🔥 MÉTODO AUXILIAR PARA ACTUALIZACIÓN CON ARCHIVOS
  Future<bool> updateSancionWithFiles({
    required SancionModel sancion,
    File? nuevaFoto,
    SignatureController? nuevaFirma,
  }) async {
    try {
      print('🔄 Actualizando sanción con archivos ${sancion.id}...');

      String? fotoUrl = sancion.fotoUrl;
      String? firmaPath = sancion.firmaPath;

      // Subir nueva foto si se proporcionó
      if (nuevaFoto != null) {
        fotoUrl = await _uploadFoto(nuevaFoto, sancion.id);
        print('📷 Nueva foto subida: $fotoUrl');
      }

      // Subir nueva firma si se proporcionó
      if (nuevaFirma != null && nuevaFirma.isNotEmpty) {
        firmaPath = await _uploadFirma(nuevaFirma, sancion.id);
        print('✍️ Nueva firma subida: $firmaPath');
      }

      // Crear sanción con URLs actualizadas
      final sancionActualizada = sancion.copyWith(
        fotoUrl: fotoUrl,
        firmaPath: firmaPath,
        updatedAt: DateTime.now(),
      );

      // Actualizar usando el método principal
      return await updateSancion(sancionActualizada);
    } catch (e) {
      print('❌ Error actualizando sanción con archivos: $e');
      return false;
    }
  }

  /// 🔥 MÉTODO SIMPLIFICADO PARA DEBUG
  Future<bool> updateSancionSimple(SancionModel sancion) async {
    try {
      print('🔄 [DEBUG] Actualizando sanción simple ${sancion.id}...');
      print('🔄 [DEBUG] Datos a actualizar:');
      print('   - Empleado: ${sancion.empleadoNombre}');
      print('   - Puesto: ${sancion.puesto}');
      print('   - Agente: ${sancion.agente}');
      print('   - Status: ${sancion.status}');

      // Preparar solo los campos esenciales
      final updateData = {
        'empleado_cod': sancion.empleadoCod,
        'empleado_nombre': sancion.empleadoNombre,
        'puesto': sancion.puesto,
        'agente': sancion.agente,
        'fecha': sancion.fecha.toIso8601String().split('T')[0],
        'hora': sancion.hora,
        'tipo_sancion': sancion.tipoSancion,
        'observaciones': sancion.observaciones,
        'observaciones_adicionales': sancion.observacionesAdicionales,
        'pendiente': sancion.pendiente,
        'status': sancion.status,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Solo agregar campos opcionales si no son null
      if (sancion.horasExtras != null) {
        updateData['horas_extras'] = sancion.horasExtras;
      }

      print('🔄 [DEBUG] Datos preparados para Supabase:');
      updateData.forEach((key, value) {
        print('   $key: $value');
      });

      final response = await _supabase
          .from('sanciones')
          .update(updateData)
          .eq('id', sancion.id)
          .select();

      if (response.isNotEmpty) {
        print('✅ [DEBUG] Sanción actualizada exitosamente');
        return true;
      } else {
        print('❌ [DEBUG] Respuesta vacía al actualizar');
        return false;
      }
    } catch (e) {
      print('❌ [DEBUG] Error detallado: $e');
      print('❌ [DEBUG] Tipo de error: ${e.runtimeType}');
      rethrow;
    }
  }
}
