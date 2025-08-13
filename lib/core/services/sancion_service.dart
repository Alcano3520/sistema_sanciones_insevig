import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart'; // 🆕 Para kIsWeb
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:signature/signature.dart';
import '../config/supabase_config.dart';
import '../models/sancion_model.dart';
import '../services/image_compression_service.dart'; // 🆕 NUEVO IMPORT

/// Servicio principal para manejar sanciones
/// ACTUALIZADO con compresión automática de imágenes
/// Incluye funcionalidad offline como tu app Kivy
/// 🆕 COMPATIBLE WEB + ANDROID
/// ✅ CORREGIDO: Getter público para Supabase + métodos jerárquicos
class SancionService {
  /// ✅ CORREGIDO: Getter público para que sea accesible desde otros servicios
  SupabaseClient get supabase => SupabaseConfig.sancionesClient;

  // Mantenemos el getter privado para compatibilidad interna
  SupabaseClient get _supabase => SupabaseConfig.sancionesClient;

  /// Crear nueva sanción (función principal como en Kivy)
  Future<String> createSancion({
    required SancionModel sancion,
    File? fotoFile,
    SignatureController? signatureController,
  }) async {
    try {
      print('🔍 Creando sanción para ${sancion.empleadoNombre}...');

      String? fotoUrl;
      String? firmaPath;

      // 1. Subir foto si existe (CON COMPRESIÓN AUTOMÁTICA) 🆕
      if (fotoFile != null) {
        fotoUrl = await _uploadFotoCompressed(fotoFile, sancion.id);
        print('📷 Foto comprimida y subida: $fotoUrl');
      }

      // 2. Subir firma si existe
      if (signatureController != null && signatureController.isNotEmpty) {
        firmaPath = await _uploadFirma(signatureController, sancion.id);
        print('✏️ Firma subida: $firmaPath');
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

  /// 🆕 MÉTODO UNIVERSAL: Subir foto con compresión (Web + Android compatible)
  Future<String?> _uploadFotoCompressed(File fotoFile, String sancionId) async {
    try {
      print(
          '🔄 [${kIsWeb ? 'WEB' : 'MOBILE'}] Procesando foto para sanción $sancionId...');

      // 1. Comprimir imagen usando el servicio universal
      final compressedFile =
          await ImageCompressionService.compressImage(fotoFile);

      // 2. Generar nombre único para Supabase
      final fileName =
          '${sancionId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final storagePath = 'sanciones/$fileName';

      // 3. Subir según la plataforma
      await _uploadToSupabase(compressedFile, storagePath);

      // 4. Obtener URL pública
      final publicUrl =
          _supabase.storage.from('sancion-photos').getPublicUrl(storagePath);

      print('✅ Foto subida exitosamente: $publicUrl');

      // 5. Limpiar archivo temporal (solo en móvil)
      await _cleanupTempFile(compressedFile, fotoFile);

      return publicUrl;
    } catch (e) {
      print('❌ Error subiendo foto comprimida: $e');

      // 🛡️ FALLBACK: Intentar con imagen original
      return await _uploadFotoOriginalFallback(fotoFile, sancionId);
    }
  }

  /// 🆕 Subir archivo a Supabase según la plataforma
  Future<void> _uploadToSupabase(File file, String storagePath) async {
    final bytes = await file.readAsBytes();

    if (kIsWeb) {
      // WEB: Usar uploadBinary (más confiable en Web)
      print('🌐 Subiendo en Web con uploadBinary...');
      await _supabase.storage
          .from('sancion-photos')
          .uploadBinary(storagePath, bytes);
    } else {
      // ANDROID/iOS: Intentar upload tradicional, fallback a uploadBinary
      print('📱 Subiendo en móvil...');
      try {
        await _supabase.storage
            .from('sancion-photos')
            .upload(storagePath, file);
        print('📱 Subida tradicional exitosa');
      } catch (e) {
        print('⚠️ Upload tradicional falló, usando uploadBinary: $e');
        await _supabase.storage
            .from('sancion-photos')
            .uploadBinary(storagePath, bytes);
        print('📱 UploadBinary exitoso como fallback');
      }
    }
  }

  /// 🆕 Limpiar archivo temporal de forma segura
  Future<void> _cleanupTempFile(File compressedFile, File originalFile) async {
    if (!kIsWeb && compressedFile.path != originalFile.path) {
      try {
        // Solo intentar eliminar si es un archivo físico diferente al original
        if (await compressedFile.exists()) {
          await compressedFile.delete();
          print('🗑️ Archivo temporal eliminado');
        }
      } catch (e) {
        print('⚠️ No se pudo eliminar archivo temporal: $e');
        // No es crítico, continuar
      }
    }
  }

  /// 🆕 FALLBACK: Subir imagen original sin compresión
  Future<String?> _uploadFotoOriginalFallback(
      File fotoFile, String sancionId) async {
    try {
      print('🔄 Intentando subida sin compresión como fallback...');

      final fileName =
          '${sancionId}_${DateTime.now().millisecondsSinceEpoch}_original.jpg';
      final storagePath = 'sanciones/$fileName';

      await _uploadToSupabase(fotoFile, storagePath);

      final publicUrl =
          _supabase.storage.from('sancion-photos').getPublicUrl(storagePath);

      print('✅ Fallback exitoso (sin compresión): $publicUrl');
      return publicUrl;
    } catch (e) {
      print('❌ Error en fallback: $e');
      return null;
    }
  }

  /// 🆕 MÉTODO ACTUALIZADO: Subir firma (sin cambios, pero más robusto)
  Future<String?> _uploadFirma(
      SignatureController controller, String sancionId) async {
    try {
      final signature = await controller.toPngBytes();
      if (signature == null) return null;

      final fileName =
          '${sancionId}_signature_${DateTime.now().millisecondsSinceEpoch}.png';
      final storagePath = 'firmas/$fileName';

      // Usar uploadBinary siempre para firmas (son pequeñas)
      await _supabase.storage
          .from('sancion-signatures')
          .uploadBinary(storagePath, signature);

      final publicUrl = _supabase.storage
          .from('sancion-signatures')
          .getPublicUrl(storagePath);

      print('✅ Firma subida: $publicUrl');
      return publicUrl;
    } catch (e) {
      print('❌ Error subiendo firma: $e');
      return null;
    }
  }

  /// 🔥 ACTUALIZAR SANCIÓN EXISTENTE - MÉTODO CORREGIDO CON COMPRESIÓN
  Future<bool> updateSancion(
    SancionModel sancion, {
    File? nuevaFoto,
    SignatureController? nuevaFirma,
  }) async {
    try {
      print('🔄 Actualizando sanción ${sancion.id}...');

      String? fotoUrl = sancion.fotoUrl;
      String? firmaPath = sancion.firmaPath;

      // 1. Subir nueva foto CON COMPRESIÓN si se proporcionó 🆕
      if (nuevaFoto != null) {
        fotoUrl = await _uploadFotoCompressed(nuevaFoto, sancion.id);
        print('📷 Nueva foto comprimida: $fotoUrl');
      }

      // 2. Subir nueva firma si se proporcionó
      if (nuevaFirma != null && nuevaFirma.isNotEmpty) {
        firmaPath = await _uploadFirma(nuevaFirma, sancion.id);
        print('✏️ Nueva firma subida: $firmaPath');
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

  /// 🔥 MÉTODO AUXILIAR PARA ACTUALIZACIÓN CON ARCHIVOS - ACTUALIZADO CON COMPRESIÓN
  Future<bool> updateSancionWithFiles({
    required SancionModel sancion,
    File? nuevaFoto,
    SignatureController? nuevaFirma,
  }) async {
    try {
      print('🔄 Actualizando sanción con archivos ${sancion.id}...');

      String? fotoUrl = sancion.fotoUrl;
      String? firmaPath = sancion.firmaPath;

      // Subir nueva foto CON COMPRESIÓN si se proporcionó 🆕
      if (nuevaFoto != null) {
        fotoUrl = await _uploadFotoCompressed(nuevaFoto, sancion.id);
        print('📷 Nueva foto comprimida subida: $fotoUrl');
      }

      // Subir nueva firma si se proporcionó
      if (nuevaFirma != null && nuevaFirma.isNotEmpty) {
        firmaPath = await _uploadFirma(nuevaFirma, sancion.id);
        print('✏️ Nueva firma subida: $firmaPath');
      }

      // Crear sanción con URLs actualizadas
      final sancionActualizada = sancion.copyWith(
        fotoUrl: fotoUrl,
        firmaPath: firmaPath,
        updatedAt: DateTime.now(),
      );

      // Actualizar usando el método principal
      return await updateSancionSimple(sancionActualizada);
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

  /// ============================================= 
  /// ✅ NUEVOS MÉTODOS PARA SISTEMA JERÁRQUICO
  /// ============================================= 

  /// ✅ NUEVO: Aprobar sanción por gerencia con código de descuento
  Future<bool> aprobarConCodigoGerencia(
    String sancionId,
    String codigo,
    String comentarios,
    String reviewedBy,
  ) async {
    try {
      print('👔 Aprobando sanción $sancionId con código $codigo...');
      
      final comentarioFinal = codigo == 'LIBRE' 
        ? comentarios
        : '$codigo - $comentarios';
        
      return await changeStatus(
        sancionId,
        'aprobado',
        comentarios: comentarioFinal,
        reviewedBy: reviewedBy,
      );
    } catch (e) {
      print('❌ Error aprobando con código: $e');
      return false;
    }
  }

  /// ✅ NUEVO: Revisión RRHH con capacidad de modificar decisión gerencia
  Future<bool> revisionRrhh(
    String sancionId,
    String accion,
    String comentariosRrhh,
    String reviewedBy, {
    String? nuevosComentariosGerencia,
  }) async {
    try {
      print('🧑‍💼 Revisión RRHH para sanción $sancionId - Acción: $accion');
      
      final updateData = <String, dynamic>{
        'comentarios_rrhh': comentariosRrhh,
        'reviewed_by': reviewedBy,
        'fecha_revision': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Según la acción RRHH
      switch (accion) {
        case 'confirmar':
          // Mantener status actual, solo agregar comentarios RRHH
          break;
        case 'modificar':
          if (nuevosComentariosGerencia != null) {
            updateData['comentarios_gerencia'] = nuevosComentariosGerencia;
          }
          break;
        case 'anular':
          updateData['status'] = 'rechazado';
          break;
        case 'procesar':
          // Procesar sin cambios, solo comentarios RRHH
          break;
      }

      await _supabase
          .from('sanciones')
          .update(updateData)
          .eq('id', sancionId);

      print('✅ Revisión RRHH completada exitosamente');
      return true;
    } catch (e) {
      print('❌ Error en revisión RRHH: $e');
      return false;
    }
  }

  /// ✅ NUEVO: Obtener sanciones específicas por rol
  Future<List<SancionModel>> getSancionesByRol(String rol) async {
    try {
      print('🔍 Consultando sanciones para rol: $rol');
      
      switch (rol) {
        case 'gerencia':
          // Solo sanciones enviadas esperando gerencia
          final sanciones = await _getSancionesByStatus('enviado');
          print('👔 Sanciones para gerencia (enviadas): ${sanciones.length}');
          return sanciones;
        case 'rrhh':
          // Sanciones aprobadas por gerencia esperando RRHH
          final sanciones = await _getSancionesAprobadaGerencia();
          print('🧑‍💼 Sanciones para RRHH (aprobadas por gerencia): ${sanciones.length}');
          return sanciones;
        default:
          final sanciones = await getAllSanciones();
          print('📋 Todas las sanciones: ${sanciones.length}');
          return sanciones;
      }
    } catch (e) {
      print('❌ Error obteniendo sanciones por rol: $e');
      return [];
    }
  }

  /// ✅ NUEVO: Obtener sanciones por status específico
  Future<List<SancionModel>> _getSancionesByStatus(String status) async {
    final response = await _supabase
        .from('sanciones')
        .select('*')
        .eq('status', status)
        .order('created_at', ascending: true);
        
    return response.map<SancionModel>((json) => SancionModel.fromMap(json)).toList();
  }

  /// ✅ NUEVO: Obtener sanciones aprobadas por gerencia (esperando RRHH)
  Future<List<SancionModel>> _getSancionesAprobadaGerencia() async {
    // ✅ CORREGIDO: Query simplificada para evitar errores de sintaxis
    final response = await _supabase
        .from('sanciones')
        .select('*')
        .eq('status', 'aprobado')
        .order('created_at', ascending: true);
    
    // Filtrar en código Dart para evitar problemas con NULL checking en SQL
    final sancionesAprobadas = response
        .map<SancionModel>((json) => SancionModel.fromMap(json))
        .where((sancion) => 
            sancion.comentariosGerencia != null && 
            sancion.comentariosRrhh == null)
        .toList();
        
    return sancionesAprobadas;
  }

  /// ✅ NUEVO: Obtener contadores para tabs
  Future<Map<String, int>> getContadoresPorRol(String rol) async {
    try {
      final contadores = <String, int>{
        'pendientes_gerencia': 0,
        'pendientes_rrhh': 0,
        'total': 0,
      };

      switch (rol) {
        case 'gerencia':
          final sancionesEnviadas = await _getSancionesByStatus('enviado');
          contadores['pendientes_gerencia'] = sancionesEnviadas.length;
          break;
          
        case 'rrhh':
          final sancionesAprobadas = await _getSancionesAprobadaGerencia();
          contadores['pendientes_rrhh'] = sancionesAprobadas.length;
          break;
      }

      return contadores;
    } catch (e) {
      print('❌ Error obteniendo contadores: $e');
      return {'pendientes_gerencia': 0, 'pendientes_rrhh': 0, 'total': 0};
    }
  }

  /// 🆕 NUEVO: Método para pre-validar imagen antes de subir
  Future<Map<String, dynamic>> validateImage(File imageFile) async {
    try {
      final info = await ImageCompressionService.getImageInfo(imageFile);
      final needsCompression =
          await ImageCompressionService.needsCompression(imageFile);

      return {
        'valid': true,
        'info': info,
        'needsCompression': needsCompression,
        'estimatedCompressedSize': needsCompression
            ? (info['size'] ?? 0) * 0.3 // Estimación: ~30% del tamaño original
            : info['size'] ?? 0,
      };
    } catch (e) {
      return {
        'valid': false,
        'error': e.toString(),
      };
    }
  }

  /// 🆕 NUEVO: Limpiar archivos temporales (llamar periódicamente)
  Future<void> cleanupTempFiles() async {
    await ImageCompressionService.cleanupTempFiles();
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
}