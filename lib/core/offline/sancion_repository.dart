import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:signature/signature.dart';
import '../models/sancion_model.dart';
import '../services/sancion_service.dart';
import 'offline_manager.dart';

/// 🔄 Repository wrapper para SancionService
/// Maneja todas las operaciones CRUD de sanciones con soporte offline
/// En web: pasa todas las llamadas directamente al service original
/// En móvil: usa OfflineManager para funcionalidad offline completa
/// ✅ CORREGIDO: Agregados métodos jerárquicos para aprobaciones
class SancionRepository {
  static SancionRepository? _instance;
  static SancionRepository get instance => _instance ??= SancionRepository._();

  SancionRepository._();

  final SancionService _sancionService = SancionService();
  final OfflineManager _offlineManager = OfflineManager.instance;

  /// =============================================
  /// 🔍 CREAR SANCIONES
  /// =============================================

  /// Crear nueva sanción
  /// Web: Directo a SancionService sin cambios
  /// Móvil: Online/offline con sincronización automática
  Future<String?> createSancion({
    required SancionModel sancion,
    File? fotoFile,
    SignatureController? signatureController,
  }) async {
    if (kIsWeb) {
      // 🌐 Web: comportamiento original sin cambios
      return await _sancionService.createSancion(
        sancion: sancion,
        fotoFile: fotoFile,
        signatureController: signatureController,
      );
    }

    // 📱 Móvil: usar OfflineManager que maneja online/offline automáticamente
    return await _offlineManager.createSancion(
      sancion: sancion,
      fotoFile: fotoFile,
      signatureController: signatureController,
    );
  }

  /// =============================================
  /// ✅ NUEVOS MÉTODOS JERÁRQUICOS
  /// =============================================

  /// ✅ NUEVO: Aprobar sanción por gerencia con código de descuento
  Future<bool> aprobarConCodigoGerencia(
    String sancionId,
    String codigo,
    String comentarios,
    String reviewedBy,
  ) async {
    try {
      // Siempre intentar online primero
      final success = await _sancionService.aprobarConCodigoGerencia(
        sancionId,
        codigo,
        comentarios,
        reviewedBy,
      );

      if (!kIsWeb && success) {
        // En móvil: actualizar cache local también
        await _updateLocalSancionAfterApproval(
          sancionId,
          'aprobado',
          '$codigo - $comentarios',
          reviewedBy,
        );
      }

      return success;
    } catch (e) {
      print('❌ Error aprobando con código: $e');

      if (!kIsWeb) {
        // En móvil: agregar a cola de sincronización
        await _offlineManager.database.addToSyncQueue('aprobar_gerencia', {
          'sancion_id': sancionId,
          'codigo': codigo,
          'comentarios': comentarios,
          'reviewed_by': reviewedBy,
        });

        // Actualizar localmente
        await _updateLocalSancionAfterApproval(
          sancionId,
          'aprobado',
          '$codigo - $comentarios',
          reviewedBy,
        );

        return true; // Exitoso localmente
      }

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
      // Siempre intentar online primero
      final success = await _sancionService.revisionRrhh(
        sancionId,
        accion,
        comentariosRrhh,
        reviewedBy,
        nuevosComentariosGerencia: nuevosComentariosGerencia,
      );

      if (!kIsWeb && success) {
        // En móvil: actualizar cache local también
        await _updateLocalSancionAfterRrhhReview(
          sancionId,
          accion,
          comentariosRrhh,
          reviewedBy,
          nuevosComentariosGerencia,
        );
      }

      return success;
    } catch (e) {
      print('❌ Error en revisión RRHH: $e');

      if (!kIsWeb) {
        // En móvil: agregar a cola de sincronización
        await _offlineManager.database.addToSyncQueue('revision_rrhh', {
          'sancion_id': sancionId,
          'accion': accion,
          'comentarios_rrhh': comentariosRrhh,
          'reviewed_by': reviewedBy,
          'nuevos_comentarios_gerencia': nuevosComentariosGerencia,
        });

        // Actualizar localmente
        await _updateLocalSancionAfterRrhhReview(
          sancionId,
          accion,
          comentariosRrhh,
          reviewedBy,
          nuevosComentariosGerencia,
        );

        return true; // Exitoso localmente
      }

      return false;
    }
  }

  /// ✅ NUEVO: Obtener sanciones específicas por rol
  Future<List<SancionModel>> getSancionesByRol(String rol) async {
    try {
      return await _sancionService.getSancionesByRol(rol);
    } catch (e) {
      print('❌ Error obteniendo sanciones por rol: $e');

      if (!kIsWeb) {
        // Fallback: filtrar cache local por rol
        return await _getLocalSancionesByRol(rol);
      }

      return [];
    }
  }

  /// ✅ NUEVO: Obtener contadores para tabs
  Future<Map<String, int>> getContadoresPorRol(String rol) async {
    try {
      return await _sancionService.getContadoresPorRol(rol);
    } catch (e) {
      print('❌ Error obteniendo contadores: $e');

      if (!kIsWeb) {
        // Fallback: calcular contadores de cache local
        return await _getLocalContadoresByRol(rol);
      }

      return {'pendientes_gerencia': 0, 'pendientes_rrhh': 0, 'total': 0};
    }
  }

  /// =============================================
  /// 🔧 MÉTODOS AUXILIARES PARA ACTUALIZACIONES LOCALES
  /// =============================================

  /// Actualizar sanción local después de aprobación gerencia
  Future<void> _updateLocalSancionAfterApproval(
    String sancionId,
    String newStatus,
    String comentarios,
    String reviewedBy,
  ) async {
    if (kIsWeb) return;

    try {
      final sancionesLocales = _offlineManager.database.getSanciones();
      final sancionIndex =
          sancionesLocales.indexWhere((s) => s.id == sancionId);

      if (sancionIndex != -1) {
        final sancionActualizada = sancionesLocales[sancionIndex].copyWith(
          status: newStatus,
          comentariosGerencia: comentarios,
          reviewedBy: reviewedBy,
          fechaRevision: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _offlineManager.database.saveSancion(sancionActualizada);
        print('✅ Sanción local actualizada después de aprobación');
      }
    } catch (e) {
      print('❌ Error actualizando sanción local: $e');
    }
  }

  /// Actualizar sanción local después de revisión RRHH
  Future<void> _updateLocalSancionAfterRrhhReview(
    String sancionId,
    String accion,
    String comentariosRrhh,
    String reviewedBy,
    String? nuevosComentariosGerencia,
  ) async {
    if (kIsWeb) return;

    try {
      final sancionesLocales = _offlineManager.database.getSanciones();
      final sancionIndex =
          sancionesLocales.indexWhere((s) => s.id == sancionId);

      if (sancionIndex != -1) {
        final sancionOriginal = sancionesLocales[sancionIndex];

        // Determinar nuevo status según acción
        String newStatus = sancionOriginal.status;
        if (accion == 'anular') {
          newStatus = 'rechazado';
        }

        final sancionActualizada = sancionOriginal.copyWith(
          status: newStatus,
          comentariosRrhh: comentariosRrhh,
          comentariosGerencia:
              nuevosComentariosGerencia ?? sancionOriginal.comentariosGerencia,
          reviewedBy: reviewedBy,
          fechaRevision: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await _offlineManager.database.saveSancion(sancionActualizada);
        print('✅ Sanción local actualizada después de revisión RRHH');
      }
    } catch (e) {
      print('❌ Error actualizando sanción local RRHH: $e');
    }
  }

  /// Obtener sanciones locales filtradas por rol
  Future<List<SancionModel>> _getLocalSancionesByRol(String rol) async {
    if (kIsWeb) return [];

    try {
      final sancionesLocales = _offlineManager.database.getSanciones();

      switch (rol) {
        case 'gerencia':
          // ✅ CORREGIDO: Solo sanciones enviadas esperando gerencia
          final sancionesEnviadas =
              sancionesLocales.where((s) => s.status == 'enviado').toList();
          print(
              '📱 Local - Sanciones enviadas para gerencia: ${sancionesEnviadas.length}');
          return sancionesEnviadas;

        case 'rrhh':
          // Sanciones aprobadas por gerencia esperando RRHH
          final sancionesParaRrhh = sancionesLocales
              .where((s) =>
                  s.status == 'aprobado' &&
                  s.comentariosGerencia != null &&
                  s.comentariosRrhh == null)
              .toList();
          print('📱 Local - Sanciones para RRHH: ${sancionesParaRrhh.length}');
          return sancionesParaRrhh;

        default:
          return sancionesLocales;
      }
    } catch (e) {
      print('❌ Error obteniendo sanciones locales por rol: $e');
      return [];
    }
  }

  /// Calcular contadores locales por rol
  Future<Map<String, int>> _getLocalContadoresByRol(String rol) async {
    if (kIsWeb)
      return {'pendientes_gerencia': 0, 'pendientes_rrhh': 0, 'total': 0};

    try {
      final sancionesLocales = _offlineManager.database.getSanciones();

      final contadores = <String, int>{
        'pendientes_gerencia': 0,
        'pendientes_rrhh': 0,
        'total': sancionesLocales.length,
      };

      switch (rol) {
        case 'gerencia':
          contadores['pendientes_gerencia'] =
              sancionesLocales.where((s) => s.status == 'enviado').length;
          break;

        case 'rrhh':
          contadores['pendientes_rrhh'] = sancionesLocales
              .where((s) =>
                  s.status == 'aprobado' &&
                  s.comentariosGerencia != null &&
                  s.comentariosRrhh == null)
              .length;
          break;
      }

      return contadores;
    } catch (e) {
      print('❌ Error calculando contadores locales: $e');
      return {'pendientes_gerencia': 0, 'pendientes_rrhh': 0, 'total': 0};
    }
  }

  /// =============================================
  /// 📖 CONSULTAR SANCIONES (MÉTODOS EXISTENTES)
  /// =============================================

  /// Obtener mis sanciones (del supervisor actual)
  Future<List<SancionModel>> getMySanciones(String supervisorId) async {
    if (kIsWeb) {
      // 🌐 Web: comportamiento original
      return await _sancionService.getMySanciones(supervisorId);
    }

    // 📱 Móvil: con cache offline
    return await _offlineManager.getSanciones(supervisorId,
        allSanciones: false);
  }

  /// Obtener todas las sanciones (para gerencia/RRHH)
  Future<List<SancionModel>> getAllSanciones() async {
    if (kIsWeb) {
      // 🌐 Web: comportamiento original
      return await _sancionService.getAllSanciones();
    }

    // 📱 Móvil: con cache offline
    return await _offlineManager.getSanciones('', allSanciones: true);
  }

  /// Obtener sanción por ID
  Future<SancionModel?> getSancionById(String id) async {
    try {
      // Intentar obtener de servicio online primero
      return await _sancionService.getSancionById(id);
    } catch (e) {
      print('❌ Error obteniendo sanción $id online: $e');

      if (!kIsWeb) {
        // Fallback: buscar en cache local
        final sancionesLocales = _offlineManager.database.getSanciones();
        try {
          return sancionesLocales.firstWhere((s) => s.id == id);
        } catch (e) {
          return null;
        }
      }

      return null;
    }
  }

  /// =============================================
  /// ✏️ ACTUALIZAR SANCIONES (MÉTODOS EXISTENTES)
  /// =============================================

  /// Actualizar sanción existente
  Future<bool> updateSancion(
    SancionModel sancion, {
    File? nuevaFoto,
    SignatureController? nuevaFirma,
  }) async {
    if (kIsWeb) {
      // 🌐 Web: comportamiento original
      return await _sancionService.updateSancionWithFiles(
        sancion: sancion,
        nuevaFoto: nuevaFoto,
        nuevaFirma: nuevaFirma,
      );
    }

    // 📱 Móvil: con funcionalidad offline
    return await _offlineManager.updateSancion(
      sancion,
      nuevaFoto: nuevaFoto,
      nuevaFirma: nuevaFirma,
    );
  }

  /// ✅ NUEVO: Método de compatibilidad para sancion_card.dart
  /// Este método evita errores en sancion_card.dart que espera 1 parámetro
  Future<bool> updateSancionRRHH(SancionModel sancion) async {
    return await updateSancionSimple(sancion);
  }

  /// Actualizar sanción simple (sin archivos)
  Future<bool> updateSancionSimple(SancionModel sancion) async {
    if (kIsWeb) {
      // 🌐 Web: comportamiento original
      return await _sancionService.updateSancionSimple(sancion);
    }

    // 📱 Móvil: usar método principal con archivos null
    return await _offlineManager.updateSancion(sancion);
  }

  /// =============================================
  /// 🔄 CAMBIOS DE ESTADO (MÉTODOS EXISTENTES)
  /// =============================================

  /// Cambiar status de sanción (borrador -> enviado -> aprobado/rechazado)
  Future<bool> changeStatus(
    String sancionId,
    String newStatus, {
    String? comentarios,
    String? reviewedBy,
  }) async {
    try {
      // Siempre intentar online primero
      final success = await _sancionService.changeStatus(
        sancionId,
        newStatus,
        comentarios: comentarios,
        reviewedBy: reviewedBy,
      );

      if (!kIsWeb && success) {
        // En móvil: actualizar cache local también
        final sancionesLocales = _offlineManager.database.getSanciones();
        final sancionIndex =
            sancionesLocales.indexWhere((s) => s.id == sancionId);

        if (sancionIndex != -1) {
          final sancionActualizada = sancionesLocales[sancionIndex].copyWith(
            status: newStatus,
            comentariosGerencia: comentarios,
            reviewedBy: reviewedBy,
            fechaRevision: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          await _offlineManager.database.saveSancion(sancionActualizada);
        }
      }

      return success;
    } catch (e) {
      print('❌ Error cambiando status: $e');

      if (!kIsWeb) {
        // En móvil: agregar a cola de sincronización
        await _offlineManager.database.addToSyncQueue('change_status', {
          'sancion_id': sancionId,
          'new_status': newStatus,
          'comentarios': comentarios,
          'reviewed_by': reviewedBy,
        });

        // Actualizar localmente
        final sancionesLocales = _offlineManager.database.getSanciones();
        final sancionIndex =
            sancionesLocales.indexWhere((s) => s.id == sancionId);

        if (sancionIndex != -1) {
          final sancionActualizada = sancionesLocales[sancionIndex].copyWith(
            status: newStatus,
            comentariosGerencia: comentarios,
            reviewedBy: reviewedBy,
            fechaRevision: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          await _offlineManager.database.saveSancion(sancionActualizada);
          return true; // Exitoso localmente
        }
      }

      return false;
    }
  }

  /// Marcar sanción como pendiente/resuelta
  Future<bool> togglePendiente(String sancionId, bool pendiente) async {
    try {
      // Intentar online primero
      final success =
          await _sancionService.togglePendiente(sancionId, pendiente);

      if (!kIsWeb && success) {
        // Actualizar cache local en móvil
        final sancionesLocales = _offlineManager.database.getSanciones();
        final sancionIndex =
            sancionesLocales.indexWhere((s) => s.id == sancionId);

        if (sancionIndex != -1) {
          final sancionActualizada = sancionesLocales[sancionIndex].copyWith(
            pendiente: pendiente,
            updatedAt: DateTime.now(),
          );

          await _offlineManager.database.saveSancion(sancionActualizada);
        }
      }

      return success;
    } catch (e) {
      print('❌ Error toggle pendiente: $e');

      if (!kIsWeb) {
        // Fallback offline en móvil
        await _offlineManager.database.addToSyncQueue('toggle_pendiente', {
          'sancion_id': sancionId,
          'pendiente': pendiente,
        });

        // Actualizar localmente
        final sancionesLocales = _offlineManager.database.getSanciones();
        final sancionIndex =
            sancionesLocales.indexWhere((s) => s.id == sancionId);

        if (sancionIndex != -1) {
          final sancionActualizada = sancionesLocales[sancionIndex].copyWith(
            pendiente: pendiente,
            updatedAt: DateTime.now(),
          );

          await _offlineManager.database.saveSancion(sancionActualizada);
          return true;
        }
      }

      return false;
    }
  }

  /// =============================================
  /// 🗑️ ELIMINAR SANCIONES (MÉTODOS EXISTENTES)
  /// =============================================

  /// Eliminar sanción (solo borradores)
  Future<bool> deleteSancion(String sancionId) async {
    try {
      // Intentar eliminar online primero
      final success = await _sancionService.deleteSancion(sancionId);

      if (!kIsWeb) {
        // En móvil: eliminar de cache local también
        await _offlineManager.database.deleteSancion(sancionId);
      }

      return success;
    } catch (e) {
      print('❌ Error eliminando sanción: $e');

      if (!kIsWeb) {
        // En móvil: eliminar localmente y agregar a cola
        await _offlineManager.database.deleteSancion(sancionId);
        await _offlineManager.database.addToSyncQueue('delete_sancion', {
          'sancion_id': sancionId,
        });

        return true; // Exitoso localmente
      }

      return false;
    }
  }

  /// =============================================
  /// 📊 CONSULTAS ESPECIALES (MÉTODOS EXISTENTES)
  /// =============================================

  /// Obtener sanciones por empleado
  Future<List<SancionModel>> getSancionesByEmpleado(int empleadoCod) async {
    try {
      return await _sancionService.getSancionesByEmpleado(empleadoCod);
    } catch (e) {
      print('❌ Error obteniendo sanciones del empleado: $e');

      if (!kIsWeb) {
        // Fallback: buscar en cache local
        final sancionesLocales = _offlineManager.database.getSanciones();
        return sancionesLocales
            .where((s) => s.empleadoCod == empleadoCod)
            .toList();
      }

      return [];
    }
  }

  /// Obtener sanciones por rango de fechas
  Future<List<SancionModel>> getSancionesByDateRange(
    DateTime fechaInicio,
    DateTime fechaFin,
  ) async {
    try {
      return await _sancionService.getSancionesByDateRange(
          fechaInicio, fechaFin);
    } catch (e) {
      print('❌ Error obteniendo sanciones por rango: $e');

      if (!kIsWeb) {
        // Fallback: filtrar cache local
        final sancionesLocales = _offlineManager.database.getSanciones();
        return sancionesLocales.where((sancion) {
          return sancion.fecha
                  .isAfter(fechaInicio.subtract(const Duration(days: 1))) &&
              sancion.fecha.isBefore(fechaFin.add(const Duration(days: 1)));
        }).toList();
      }

      return [];
    }
  }

  /// Obtener sanciones pendientes
  Future<List<SancionModel>> getSancionesPendientes() async {
    try {
      return await _sancionService.getSancionesPendientes();
    } catch (e) {
      print('❌ Error obteniendo sanciones pendientes: $e');

      if (!kIsWeb) {
        // Fallback: filtrar cache local
        final sancionesLocales = _offlineManager.database.getSanciones();
        return sancionesLocales.where((s) => s.pendiente).toList();
      }

      return [];
    }
  }

  /// =============================================
  /// 📈 ESTADÍSTICAS (MÉTODOS EXISTENTES)
  /// =============================================

  /// Obtener estadísticas de sanciones
  Future<Map<String, dynamic>> getEstadisticas({String? supervisorId}) async {
    try {
      print(
          '📊 Calculando estadísticas${supervisorId != null ? ' para supervisor $supervisorId' : ' globales'}...');

      // Obtener todas las sanciones
      List<SancionModel> sanciones;
      if (supervisorId != null) {
        sanciones = await getMySanciones(supervisorId);
      } else {
        sanciones = await getAllSanciones();
      }

      print('📋 Total sanciones para estadísticas: ${sanciones.length}');

      // ✅ CONTADORES CORREGIDOS CON LÓGICA CLARA
      int borradores = 0;
      int enviadas = 0;
      int aprobadas = 0;
      int rechazadas = 0;
      int procesadas = 0;
      int anuladas = 0;

      // ✅ NUEVO: Contadores específicos por rol
      int pendientesGerencia = 0; // Status 'enviado'
      int pendientesRrhh = 0; // Status 'aprobado'
      int totalPendientes = 0; // Suma de ambos

      // Contar por status exacto
      for (var sancion in sanciones) {
        switch (sancion.status.toLowerCase()) {
          case 'borrador':
            borradores++;
            break;
          case 'enviado':
            enviadas++;
            pendientesGerencia++; // ✅ Estos esperan gerencia
            break;
          case 'aprobado':
            aprobadas++;
            pendientesRrhh++; // ✅ Estos esperan RRHH
            break;
          case 'rechazado':
            rechazadas++;
            break;
          case 'procesado':
            procesadas++;
            break;
          case 'anulado':
            anuladas++;
            break;
          default:
            print('⚠️ Status desconocido: ${sancion.status}');
        }
      }

      // ✅ CÁLCULO CORREGIDO: Pendientes = los que esperan acción
      totalPendientes = pendientesGerencia + pendientesRrhh;

      print('📈 Estadísticas calculadas:');
      print('   - Borradores: $borradores');
      print('   - Enviadas (esperando gerencia): $enviadas');
      print('   - Aprobadas (esperando RRHH): $aprobadas');
      print('   - Rechazadas: $rechazadas');
      print('   - Procesadas: $procesadas');
      print('   - Anuladas: $anuladas');
      print('   - Pendientes Gerencia: $pendientesGerencia');
      print('   - Pendientes RRHH: $pendientesRrhh');
      print('   - Total Pendientes: $totalPendientes');

      return {
        'borradores': borradores,
        'enviadas': enviadas,
        'aprobadas': aprobadas,
        'rechazadas': rechazadas,
        'procesadas': procesadas,
        'anuladas': anuladas,

        // ✅ NUEVO: Pendientes específicos por contexto
        'pendientes': totalPendientes, // Para vista general
        'pendientes_gerencia': pendientesGerencia, // Para gerencia específica
        'pendientes_rrhh': pendientesRrhh, // Para RRHH específica

        // Estadísticas adicionales
        'total': sanciones.length,
        'finalizadas': procesadas + anuladas,
        'en_proceso': totalPendientes,
      };
    } catch (e) {
      print('❌ Error calculando estadísticas: $e');
      throw Exception('Error al calcular estadísticas: $e');
    }
  }

  /// ✅ NUEVO: Método específico para obtener estadísticas por rol del usuario
  Future<Map<String, dynamic>> getEstadisticasParaRol(String userRole,
      {String? userId}) async {
    try {
      print('📊 Calculando estadísticas específicas para rol: $userRole');

      final stats = await getEstadisticas(supervisorId: userId);

      // ✅ PERSONALIZAR según el rol del usuario
      switch (userRole.toLowerCase()) {
        case 'gerencia':
          return {
            ...stats,
            'pendientes': stats[
                'pendientes_gerencia'], // Solo las que gerencia debe aprobar
            'titulo_pendientes': 'Esperando Mi Aprobación',
          };

        case 'rrhh':
          return {
            ...stats,
            'pendientes':
                stats['pendientes_rrhh'], // Solo las que RRHH debe procesar
            'titulo_pendientes': 'Esperando Procesamiento',
          };

        case 'supervisor':
          // Para supervisores, "pendientes" son sus propias sanciones en proceso
          final misSanciones = await getMySanciones(userId!);
          final misPendientes = misSanciones
              .where((s) => s.status == 'enviado' || s.status == 'aprobado')
              .length;

          return {
            ...stats,
            'pendientes': misPendientes,
            'titulo_pendientes': 'Mis Sanciones en Proceso',
          };

        default:
          return {
            ...stats,
            'titulo_pendientes': 'Pendientes Generales',
          };
      }
    } catch (e) {
      print('❌ Error en estadísticas por rol: $e');
      return await getEstadisticas(supervisorId: userId);
    }
  }

  /// =============================================
  /// 🔧 MÉTODOS DE DESARROLLO Y DEBUG (EXISTENTES)
  /// =============================================

  /// Pre-validar imagen antes de subir
  Future<Map<String, dynamic>> validateImage(File imageFile) async {
    // Este método no necesita modificación offline
    return await _sancionService.validateImage(imageFile);
  }

  /// Limpiar archivos temporales
  Future<void> cleanupTempFiles() async {
    await _sancionService.cleanupTempFiles();
  }

  /// =============================================
  /// 🎯 MÉTODOS DE INFORMACIÓN OFFLINE (EXISTENTES)
  /// =============================================

  /// Obtener información del estado del repository
  Map<String, dynamic> getRepositoryInfo() {
    final info = {
      'platform': kIsWeb ? 'web' : 'mobile',
      'offline_supported': !kIsWeb,
      'service_class': 'SancionRepository',
    };

    if (!kIsWeb) {
      final offlineStats = _offlineManager.getOfflineStats();
      info.addAll({
        'current_mode': offlineStats['mode'],
        'cached_sanciones': offlineStats['sanciones_cached'],
        'pending_sync': offlineStats['pending_sync'],
        'is_syncing': offlineStats['is_syncing'],
        'last_sync': offlineStats['last_sync'],
      });
    }

    return info;
  }

  /// Forzar sincronización (solo móvil)
  Future<bool> forceSyncSanciones() async {
    if (kIsWeb) {
      print('🌐 Web: Sincronización no aplicable');
      return true;
    }

    return await _offlineManager.syncNow();
  }

  /// Obtener operaciones pendientes de sincronización
  List<Map<String, dynamic>> getPendingSyncOperations() {
    if (kIsWeb) return [];

    return _offlineManager.database.getPendingSyncOperations();
  }

  /// Limpiar cache de sanciones (solo móvil)
  Future<bool> clearSancionesCache() async {
    if (kIsWeb) {
      print('🌐 Web: Cache no aplicable');
      return true;
    }

    try {
      final sancionesBox = _offlineManager.database.sancionesBox;
      if (sancionesBox != null) {
        await sancionesBox.clear();
        print('🧹 Cache de sanciones limpiado');
        return true;
      }
      return false;
    } catch (e) {
      print('❌ Error limpiando cache de sanciones: $e');
      return false;
    }
  }

  /// Limpiar cola de sincronización
  Future<bool> clearSyncQueue() async {
    if (kIsWeb) return true;

    return await _offlineManager.database.clearSyncQueue();
  }

  /// Obtener estadísticas offline completas
  Map<String, dynamic> getOfflineStats() {
    return _offlineManager.getOfflineStats();
  }

  /// =============================================
  /// 🎮 MODO DE DESARROLLO (EXISTENTES)
  /// =============================================

  /// Simular modo offline (solo para testing)
  void setOfflineMode(bool forceOffline) {
    if (kIsWeb) {
      print('🌐 Web: Modo offline no disponible');
      return;
    }

    // Este método podría usarse para testing
    print(
        '🔧 Modo offline ${forceOffline ? "activado" : "desactivado"} para testing');
  }
}
