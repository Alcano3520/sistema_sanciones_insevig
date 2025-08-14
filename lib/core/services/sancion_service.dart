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
/// 🔥 MEJORADO: Estadísticas por rol y manejo de pendientes
/// 🔧 ACTUALIZADO: Consultas con JOIN para mostrar nombres de supervisores
class SancionService {
  /// ✅ CORREGIDO: Getter público para que sea accesible desde otros servicios
  SupabaseClient get supabase => SupabaseConfig.sancionesClient;

  // Mantenemos el getter privado para compatibilidad interna
  SupabaseClient get _supabase => SupabaseConfig.sancionesClient;

  /// 🔧 NUEVA CONSTANTE: Query base con JOIN para nombres de supervisores
  static const String _selectWithSupervisor = '*, profiles!sanciones_supervisor_id_fkey(full_name)';

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
          .select(_selectWithSupervisor)  // 🔧 ACTUALIZADO: Incluir JOIN
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
          .select(_selectWithSupervisor);  // 🔧 ACTUALIZADO: Incluir JOIN

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
          .select(_selectWithSupervisor);  // 🔧 ACTUALIZADO: Incluir JOIN

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

  /// ✅ ACTUALIZADO: Aprobar sanción por gerencia con código de descuento
  Future<bool> aprobarConCodigoGerencia(
    String sancionId,
    String codigo,
    String comentarios,
    String reviewedBy,
  ) async {
    try {
      print('🎯 Aprobando sanción $sancionId con código $codigo...');
      
      final comentarioFinal = codigo == 'LIBRE' 
        ? comentarios
        : '$codigo - $comentarios';
        
      // 🔥 El campo 'pendiente' se actualizará a false automáticamente
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

  /// ✅ ACTUALIZADO: Revisión RRHH con capacidad de modificar decisión gerencia
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
          // 🔥 Marcar como no pendiente al confirmar RRHH
          updateData['pendiente'] = false;
          break;
        case 'modificar':
          if (nuevosComentariosGerencia != null) {
            updateData['comentarios_gerencia'] = nuevosComentariosGerencia;
          }
          updateData['pendiente'] = false;
          break;
        case 'anular':
          updateData['status'] = 'rechazado';
          updateData['pendiente'] = false;
          break;
        case 'procesar':
          // Procesar sin cambios, solo comentarios RRHH
          updateData['pendiente'] = false;
          break;
      }

      await _supabase
          .from('sanciones')
          .update(updateData)
          .eq('id', sancionId);

      print('✅ Revisión RRHH completada exitosamente');
      print('   Pendiente actualizado a: false');
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
          print('🎯 Sanciones para gerencia (enviadas): ${sanciones.length}');
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
        .select(_selectWithSupervisor)  // 🔧 ACTUALIZADO: Incluir JOIN
        .eq('status', status)
        .order('created_at', ascending: true);
        
    return response.map<SancionModel>((json) => SancionModel.fromMap(json)).toList();
  }

  /// ✅ NUEVO: Obtener sanciones aprobadas por gerencia (esperando RRHH)
  Future<List<SancionModel>> _getSancionesAprobadaGerencia() async {
    // ✅ CORREGIDO: Query simplificada para evitar errores de sintaxis
    final response = await _supabase
        .from('sanciones')
        .select(_selectWithSupervisor)  // 🔧 ACTUALIZADO: Incluir JOIN
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

  /// 🔧 ACTUALIZADO: Obtener sanciones del supervisor actual
  Future<List<SancionModel>> getMySanciones(String supervisorId) async {
    try {
      final response = await _supabase
          .from('sanciones')
          .select(_selectWithSupervisor)  // 🔧 ACTUALIZADO: Incluir JOIN
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

  /// 🔧 ACTUALIZADO: Obtener todas las sanciones (para gerencia/RRHH)
  Future<List<SancionModel>> getAllSanciones() async {
    try {
      final response = await _supabase
          .from('sanciones')
          .select(_selectWithSupervisor)  // 🔧 ACTUALIZADO: Incluir JOIN
          .order('created_at', ascending: false);

      return response
          .map<SancionModel>((json) => SancionModel.fromMap(json))
          .toList();
    } catch (e) {
      print('❌ Error obteniendo todas las sanciones: $e');
      return [];
    }
  }

  /// 🔧 ACTUALIZADO: Obtener sanciones por empleado
  Future<List<SancionModel>> getSancionesByEmpleado(int empleadoCod) async {
    try {
      final response = await _supabase
          .from('sanciones')
          .select(_selectWithSupervisor)  // 🔧 ACTUALIZADO: Incluir JOIN
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

  /// 🔧 ACTUALIZADO: Obtener sanciones por fechas
  Future<List<SancionModel>> getSancionesByDateRange(
    DateTime fechaInicio,
    DateTime fechaFin,
  ) async {
    try {
      final response = await _supabase
          .from('sanciones')
          .select(_selectWithSupervisor)  // 🔧 ACTUALIZADO: Incluir JOIN
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

  /// 🔧 ACTUALIZADO: Obtener sanciones pendientes
  Future<List<SancionModel>> getSancionesPendientes() async {
    try {
      final response = await _supabase
          .from('sanciones')
          .select(_selectWithSupervisor)  // 🔧 ACTUALIZADO: Incluir JOIN
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

  /// 🔥 MEJORADO: Cambiar status de sanción con lógica mejorada para pendientes
  Future<bool> changeStatus(
    String sancionId,
    String newStatus, {
    String? comentarios,
    String? reviewedBy,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'status': newStatus,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // 🔥 ACTUALIZADO: Lógica mejorada para el campo 'pendiente'
      switch (newStatus) {
        case 'enviado':
          // Enviado: pendiente de aprobación por gerencia
          updateData['pendiente'] = true;
          break;
          
        case 'aprobado':
          // Aprobado: ya no pendiente (aunque RRHH puede revisar)
          updateData['pendiente'] = false;
          break;
          
        case 'rechazado':
          // 🔥 Rechazado: pendiente de corrección por el supervisor
          updateData['pendiente'] = true;
          break;
          
        case 'borrador':
          // Borrador: no pendiente hasta que se envíe
          updateData['pendiente'] = false;
          break;
      }

      if (comentarios != null) {
        // Si es rechazo, guardar en comentarios_gerencia el motivo
        if (newStatus == 'rechazado') {
          updateData['comentarios_gerencia'] = 'RECHAZADO - $comentarios';
        } else {
          updateData['comentarios_gerencia'] = comentarios;
        }
      }

      if (reviewedBy != null) {
        updateData['reviewed_by'] = reviewedBy;
        updateData['fecha_revision'] = DateTime.now().toIso8601String();
      }

      await _supabase.from('sanciones').update(updateData).eq('id', sancionId);

      print('✅ Status cambiado a $newStatus para sanción $sancionId');
      print('   Pendiente actualizado a: ${updateData['pendiente']}');
      print('   Comentarios: ${updateData['comentarios_gerencia'] ?? 'N/A'}');
      
      return true;
    } catch (e) {
      print('❌ Error cambiando status: $e');
      return false;
    }
  }

  /// 🔥 NUEVO: Método auxiliar para rechazar sanción con motivo
  Future<bool> rechazarSancion(
    String sancionId,
    String motivoRechazo,
    String reviewedBy,
  ) async {
    try {
      print('❌ Rechazando sanción $sancionId...');
      
      return await changeStatus(
        sancionId,
        'rechazado',
        comentarios: motivoRechazo,
        reviewedBy: reviewedBy,
      );
    } catch (e) {
      print('❌ Error rechazando sanción: $e');
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

  /// 🔥 MEJORADO: Obtener estadísticas de sanciones mejoradas por rol
  Future<Map<String, dynamic>> getEstadisticas({String? supervisorId, String? userRole}) async {
    try {
      var query = _supabase.from('sanciones').select(_selectWithSupervisor);  // 🔧 ACTUALIZADO: Incluir JOIN

      if (supervisorId != null && userRole == 'supervisor') {
        // Para supervisores: solo sus sanciones
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

        // Contar por tipo
        final porTipo = stats['porTipo'] as Map<String, int>;
        porTipo[tipo] = (porTipo[tipo] ?? 0) + 1;

        // Último mes
        if (fecha != null && fecha.isAfter(hace30Dias)) {
          stats['ultimoMes'] = (stats['ultimoMes'] as int) + 1;
        }
      }

      // 🔥 NUEVO: Calcular "pendientes" según el rol del usuario
      stats['pendientes'] = _calcularPendientesPorRol(response, userRole, supervisorId);
      
      // Resueltas = aprobadas + rechazadas (sanciones con decisión final)
      stats['resueltas'] = (stats['aprobadas'] as int) + (stats['rechazadas'] as int);

      print('📊 Estadísticas calculadas para rol $userRole:');
      print('   Total: ${stats['total']}');
      print('   Pendientes: ${stats['pendientes']}');
      print('   Borradores: ${stats['borradores']}');
      print('   Enviadas: ${stats['enviadas']}');
      print('   Aprobadas: ${stats['aprobadas']}');
      print('   Rechazadas: ${stats['rechazadas']}');

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

  /// 🔥 NUEVO: Calcular pendientes según el rol
  int _calcularPendientesPorRol(List<dynamic> sanciones, String? userRole, String? supervisorId) {
    int pendientes = 0;

    switch (userRole) {
      case 'supervisor':
        // Para supervisores: sus borradores y rechazadas que debe corregir
        for (var sancion in sanciones) {
          if (sancion['supervisor_id'] == supervisorId) {
            final status = sancion['status'];
            if (status == 'borrador' || status == 'rechazado') {
              pendientes++;
            }
          }
        }
        break;

      case 'gerencia':
        // Para gerencia: sanciones enviadas esperando su aprobación
        for (var sancion in sanciones) {
          if (sancion['status'] == 'enviado') {
            pendientes++;
          }
        }
        break;

      case 'rrhh':
        // Para RRHH: sanciones aprobadas por gerencia que necesitan revisión
        for (var sancion in sanciones) {
          if (sancion['status'] == 'aprobado' && 
              sancion['comentarios_gerencia'] != null && 
              sancion['comentarios_rrhh'] == null) {
            pendientes++;
          }
        }
        break;

      case 'admin':
        // Para admin: todas las sanciones no finalizadas
        for (var sancion in sanciones) {
          final status = sancion['status'];
          if (status == 'borrador' || status == 'enviado') {
            pendientes++;
          }
        }
        break;

      default:
        // Por defecto: contar borradores y enviadas
        for (var sancion in sanciones) {
          final status = sancion['status'];
          if (status == 'borrador' || status == 'enviado') {
            pendientes++;
          }
        }
    }

    return pendientes;
  }

  /// 🔧 ACTUALIZADO: Obtener sanción por ID
  Future<SancionModel?> getSancionById(String id) async {
    try {
      final response = await _supabase
          .from('sanciones')
          .select(_selectWithSupervisor)  // 🔧 ACTUALIZADO: Incluir JOIN
          .eq('id', id)
          .single();

      return SancionModel.fromMap(response);
    } catch (e) {
      print('❌ Error obteniendo sanción $id: $e');
      return null;
    }
  }
}