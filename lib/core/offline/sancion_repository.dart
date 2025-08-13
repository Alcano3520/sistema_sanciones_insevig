import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';
import '../models/sancion_model.dart';
import '../services/sancion_service.dart';
import '../providers/auth_provider.dart';
import 'offline_manager.dart';

/// 📄 Repository wrapper para SancionService
/// Maneja todas las operaciones CRUD de sanciones con soporte offline
/// En web: pasa todas las llamadas directamente al service original
/// En móvil: usa OfflineManager para funcionalidad offline completa
/// 🆕 EXTENDIDO CON SISTEMA DE APROBACIONES Y CÓDIGOS DE DESCUENTO
class SancionRepository {
  static SancionRepository? _instance;
  static SancionRepository get instance => _instance ??= SancionRepository._();

  SancionRepository._();

  final SancionService _sancionService = SancionService();
  final OfflineManager _offlineManager = OfflineManager.instance;

  /// =============================================
  /// 🏗️ CREAR SANCIONES
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
  /// 📖 CONSULTAR SANCIONES
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

  /// 🆕 Obtener sanciones para gerencia (enviadas + aprobadas por esta gerencia)
  Future<List<SancionModel>> getSancionesParaGerencia() async {
    if (kIsWeb) {
      return await _sancionService.getSancionesParaGerencia();
    }

    try {
      final sanciones = await _sancionService.getSancionesParaGerencia();
      
      // Actualizar cache en móvil
      if (!kIsWeb) {
        for (var sancion in sanciones) {
          await _offlineManager.database.saveSancion(sancion);
        }
      }
      
      return sanciones;
    } catch (e) {
      print('❌ Error obteniendo sanciones para gerencia: $e');
      
      if (!kIsWeb) {
        // Fallback: filtrar cache local
        final sancionesLocales = _offlineManager.database.getSanciones();
        return sancionesLocales.where((s) => 
          s.status == 'enviado' || 
          (s.status == 'aprobado' && s.comentariosGerencia != null)
        ).toList();
      }
      
      return [];
    }
  }

  /// 🆕 Obtener sanciones para RRHH (aprobadas por gerencia + procesadas)
  Future<List<SancionModel>> getSancionesParaRRHH() async {
    if (kIsWeb) {
      return await _sancionService.getSancionesParaRRHH();
    }

    try {
      final sanciones = await _sancionService.getSancionesParaRRHH();
      
      // Actualizar cache en móvil
      if (!kIsWeb) {
        for (var sancion in sanciones) {
          await _offlineManager.database.saveSancion(sancion);
        }
      }
      
      return sanciones;
    } catch (e) {
      print('❌ Error obteniendo sanciones para RRHH: $e');
      
      if (!kIsWeb) {
        // Fallback: filtrar cache local
        final sancionesLocales = _offlineManager.database.getSanciones();
        return sancionesLocales.where((s) => 
          s.status == 'aprobado' && s.comentariosGerencia != null
        ).toList();
      }
      
      return [];
    }
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
  /// ✏️ ACTUALIZAR SANCIONES
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
  /// 🔄 CAMBIOS DE ESTADO
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

  /// 🆕 Aprobar sanción con código de descuento (GERENCIA)
  Future<bool> aprobarConCodigo(
    String sancionId,
    String codigoCompleto,
    String reviewedBy,
  ) async {
    try {
      final success = await _sancionService.changeStatus(
        sancionId,
        'aprobado', // Status aprobado con códigos en comentarios_gerencia
        comentarios: codigoCompleto, // Guarda en comentarios_gerencia
        reviewedBy: reviewedBy,
      );

      if (!kIsWeb && success) {
        // Actualizar cache local
        final sancionesLocales = _offlineManager.database.getSanciones();
        final sancionIndex = sancionesLocales.indexWhere((s) => s.id == sancionId);

        if (sancionIndex != -1) {
          final sancionActualizada = sancionesLocales[sancionIndex].copyWith(
            status: 'aprobado',
            comentariosGerencia: codigoCompleto,
            reviewedBy: reviewedBy,
            fechaRevision: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          await _offlineManager.database.saveSancion(sancionActualizada);
        }
      }

      return success;
    } catch (e) {
      print('❌ Error aprobando con código: $e');

      if (!kIsWeb) {
        // Agregar a cola de sincronización
        await _offlineManager.database.addToSyncQueue('aprobar_con_codigo', {
          'sancion_id': sancionId,
          'codigo_completo': codigoCompleto,
          'reviewed_by': reviewedBy,
        });

        // Actualizar localmente
        final sancionesLocales = _offlineManager.database.getSanciones();
        final sancionIndex = sancionesLocales.indexWhere((s) => s.id == sancionId);

        if (sancionIndex != -1) {
          final sancionActualizada = sancionesLocales[sancionIndex].copyWith(
            status: 'aprobado',
            comentariosGerencia: codigoCompleto,
            reviewedBy: reviewedBy,
            fechaRevision: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          await _offlineManager.database.saveSancion(sancionActualizada);
          return true;
        }
      }

      return false;
    }
  }

  /// 🆕 Procesar sanción por RRHH (confirmar, modificar o anular)
  Future<bool> procesarRRHH(
    String sancionId,
    String accion, // 'confirmar', 'modificar', 'anular'
    String comentariosRrhh,
    String reviewedBy,
    {String? nuevoCodigo}
  ) async {
    try {
      String statusFinal;
      String comentariosFinales = comentariosRrhh;
      
      switch (accion) {
        case 'confirmar':
          statusFinal = 'aprobado'; // Mantiene aprobado
          break;
        case 'modificar':
          statusFinal = 'aprobado';
          comentariosFinales = 'MODIFICADO|$nuevoCodigo|$comentariosRrhh';
          break;
        case 'anular':
          statusFinal = 'rechazado';
          comentariosFinales = 'ANULADO_RRHH|$comentariosRrhh';
          break;
        default:
          return false;
      }

      // Usar método especializado para RRHH
      final success = await _sancionService.updateSancionRRHH(
        sancionId,
        statusFinal,
        comentariosFinales,
        reviewedBy,
      );

      if (!kIsWeb && success) {
        // Actualizar cache local
        final sancionesLocales = _offlineManager.database.getSanciones();
        final sancionIndex = sancionesLocales.indexWhere((s) => s.id == sancionId);

        if (sancionIndex != -1) {
          final sancionActualizada = sancionesLocales[sancionIndex].copyWith(
            status: statusFinal,
            comentariosRrhh: comentariosFinales,
            reviewedBy: reviewedBy,
            fechaRevision: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          await _offlineManager.database.saveSancion(sancionActualizada);
        }
      }

      return success;
    } catch (e) {
      print('❌ Error procesando RRHH: $e');

      if (!kIsWeb) {
        // Agregar a cola de sincronización
        await _offlineManager.database.addToSyncQueue('procesar_rrhh', {
          'sancion_id': sancionId,
          'accion': accion,
          'comentarios_rrhh': comentariosRrhh,
          'reviewed_by': reviewedBy,
          'nuevo_codigo': nuevoCodigo,
        });

        return true; // Exitoso localmente
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
  /// 🗑️ ELIMINAR SANCIONES
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
  /// 📊 CONSULTAS ESPECIALES
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
  /// 📈 ESTADÍSTICAS
  /// =============================================

  /// Obtener estadísticas de sanciones
  Future<Map<String, dynamic>> getEstadisticas({String? supervisorId}) async {
    try {
      return await _sancionService.getEstadisticas(supervisorId: supervisorId);
    } catch (e) {
      print('❌ Error obteniendo estadísticas: $e');

      if (!kIsWeb) {
        // Fallback: calcular estadísticas de cache local
        var sanciones = _offlineManager.database.getSanciones();

        if (supervisorId != null) {
          sanciones =
              sanciones.where((s) => s.supervisorId == supervisorId).toList();
        }

        final stats = {
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
          // Contar por status
          switch (sancion.status) {
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
          if (sancion.pendiente) {
            stats['pendientes'] = (stats['pendientes'] as int) + 1;
          } else {
            stats['resueltas'] = (stats['resueltas'] as int) + 1;
          }

          // Contar por tipo
          final porTipo = stats['porTipo'] as Map<String, int>;
          porTipo[sancion.tipoSancion] =
              (porTipo[sancion.tipoSancion] ?? 0) + 1;

          // Último mes
          if (sancion.createdAt.isAfter(hace30Dias)) {
            stats['ultimoMes'] = (stats['ultimoMes'] as int) + 1;
          }
        }

        return stats;
      }

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

  /// 🆕 Obtener estadísticas por rol
  Future<Map<String, dynamic>> getEstadisticasByRole() async {
    try {
      // Esta función necesitaría acceso al contexto para obtener el usuario actual
      // Como workaround, calculamos estadísticas localmente
      if (kIsWeb) {
        return await _sancionService.getEstadisticasByRole();
      }

      // En móvil, calcular estadísticas de cache local
      final sancionesLocales = _offlineManager.database.getSanciones();
      
      return {
        'total_con_descuento': _contarConDescuento(sancionesLocales),
        'modificadas': _contarModificadas(sancionesLocales),
        'anuladas': _contarAnuladas(sancionesLocales),
        'por_codigo': _contarPorCodigo(sancionesLocales),
      };
    } catch (e) {
      print('❌ Error obteniendo estadísticas por rol: $e');
      return {};
    }
  }

  // 🆕 MÉTODOS AUXILIARES PARA ESTADÍSTICAS
  int _contarConDescuento(List<SancionModel> sanciones) {
    return sanciones.where((s) => 
      s.comentariosGerencia != null && 
      !s.comentariosGerencia!.startsWith('SIN_DESC') &&
      !s.comentariosGerencia!.startsWith('RECHAZADO')
    ).length;
  }

  int _contarModificadas(List<SancionModel> sanciones) {
    return sanciones.where((s) => 
      s.comentariosRrhh != null && 
      s.comentariosRrhh!.startsWith('MODIFICADO')
    ).length;
  }

  int _contarAnuladas(List<SancionModel> sanciones) {
    return sanciones.where((s) => 
      s.status == 'rechazado' && 
      s.comentariosRrhh != null && 
      s.comentariosRrhh!.startsWith('ANULADO_RRHH')
    ).length;
  }

  Map<String, int> _contarPorCodigo(List<SancionModel> sanciones) {
    final conteo = <String, int>{};
    
    for (var sancion in sanciones) {
      if (sancion.comentariosGerencia != null) {
        final codigo = sancion.comentariosGerencia!.split('|')[0];
        conteo[codigo] = (conteo[codigo] ?? 0) + 1;
      }
    }
    
    return conteo;
  }

  /// =============================================
  /// 🔧 MÉTODOS DE DESARROLLO Y DEBUG
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
  /// 🎯 MÉTODOS DE INFORMACIÓN OFFLINE
  /// =============================================

  /// Obtener información del estado del repository
  Map<String, dynamic> getRepositoryInfo() {
    final info = {
      'platform': kIsWeb ? 'web' : 'mobile',
      'offline_supported': !kIsWeb,
      'service_class': 'SancionRepository',
      'approval_system': 'enabled', // 🆕
      'discount_codes': 'enabled', // 🆕
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
  /// 🎮 MODO DE DESARROLLO
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