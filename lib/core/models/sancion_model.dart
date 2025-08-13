import 'package:intl/intl.dart';

/// 📋 Modelo de datos para Sanciones
/// Representa una sanción laboral completa con todos sus campos
/// 🆕 EXTENDIDO CON SISTEMA DE CÓDIGOS DE DESCUENTO Y APROBACIONES
class SancionModel {
  final String id;
  final String supervisorId;
  final int empleadoCod;
  final String empleadoNombre;
  final String puesto;
  final String agente;
  final DateTime fecha;
  final String hora;
  final String tipoSancion;
  final String? observaciones;
  final String? observacionesAdicionales;
  final bool pendiente;
  final String? fotoUrl;
  final String? firmaPath;
  final int? horasExtras;
  final String status;
  final String? comentariosGerencia; // 🆕 Para códigos de descuento
  final String? comentariosRrhh;    // 🆕 Para procesamiento RRHH
  final DateTime? fechaRevision;
  final String? reviewedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SancionModel({
    required this.id,
    required this.supervisorId,
    required this.empleadoCod,
    required this.empleadoNombre,
    required this.puesto,
    required this.agente,
    required this.fecha,
    required this.hora,
    required this.tipoSancion,
    this.observaciones,
    this.observacionesAdicionales,
    required this.pendiente,
    this.fotoUrl,
    this.firmaPath,
    this.horasExtras,
    required this.status,
    this.comentariosGerencia,
    this.comentariosRrhh,
    this.fechaRevision,
    this.reviewedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  /// =============================================
  /// 🏭 FACTORY CONSTRUCTORS
  /// =============================================

  factory SancionModel.fromMap(Map<String, dynamic> map) {
    return SancionModel(
      id: map['id'] ?? '',
      supervisorId: map['supervisor_id'] ?? '',
      empleadoCod: map['empleado_cod']?.toInt() ?? 0,
      empleadoNombre: map['empleado_nombre'] ?? '',
      puesto: map['puesto'] ?? '',
      agente: map['agente'] ?? '',
      fecha: map['fecha'] != null ? DateTime.parse(map['fecha']) : DateTime.now(),
      hora: map['hora'] ?? '',
      tipoSancion: map['tipo_sancion'] ?? '',
      observaciones: map['observaciones'],
      observacionesAdicionales: map['observaciones_adicionales'],
      pendiente: map['pendiente'] ?? true,
      fotoUrl: map['foto_url'],
      firmaPath: map['firma_path'],
      horasExtras: map['horas_extras']?.toInt(),
      status: map['status'] ?? 'borrador',
      comentariosGerencia: map['comentarios_gerencia'],
      comentariosRrhh: map['comentarios_rrhh'],
      fechaRevision: map['fecha_revision'] != null 
          ? DateTime.parse(map['fecha_revision']) 
          : null,
      reviewedBy: map['reviewed_by'],
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at']) 
          : DateTime.now(),
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at']) 
          : DateTime.now(),
    );
  }

  factory SancionModel.empty() {
    return SancionModel(
      id: '',
      supervisorId: '',
      empleadoCod: 0,
      empleadoNombre: '',
      puesto: '',
      agente: '',
      fecha: DateTime.now(),
      hora: '${TimeOfDay.now().hour.toString().padLeft(2, '0')}:${TimeOfDay.now().minute.toString().padLeft(2, '0')}',
      tipoSancion: '',
      pendiente: true,
      status: 'borrador',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// =============================================
  /// 📤 SERIALIZACIÓN
  /// =============================================

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'supervisor_id': supervisorId,
      'empleado_cod': empleadoCod,
      'empleado_nombre': empleadoNombre,
      'puesto': puesto,
      'agente': agente,
      'fecha': fecha.toIso8601String().split('T')[0],
      'hora': hora,
      'tipo_sancion': tipoSancion,
      'observaciones': observaciones,
      'observaciones_adicionales': observacionesAdicionales,
      'pendiente': pendiente,
      'foto_url': fotoUrl,
      'firma_path': firmaPath,
      'horas_extras': horasExtras,
      'status': status,
      'comentarios_gerencia': comentariosGerencia,
      'comentarios_rrhh': comentariosRrhh,
      'fecha_revision': fechaRevision?.toIso8601String(),
      'reviewed_by': reviewedBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toJson() => toMap();

  /// =============================================
  /// 🔄 COPYSWITH
  /// =============================================

  SancionModel copyWith({
    String? id,
    String? supervisorId,
    int? empleadoCod,
    String? empleadoNombre,
    String? puesto,
    String? agente,
    DateTime? fecha,
    String? hora,
    String? tipoSancion,
    String? observaciones,
    String? observacionesAdicionales,
    bool? pendiente,
    String? fotoUrl,
    String? firmaPath,
    int? horasExtras,
    String? status,
    String? comentariosGerencia,
    String? comentariosRrhh,
    DateTime? fechaRevision,
    String? reviewedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SancionModel(
      id: id ?? this.id,
      supervisorId: supervisorId ?? this.supervisorId,
      empleadoCod: empleadoCod ?? this.empleadoCod,
      empleadoNombre: empleadoNombre ?? this.empleadoNombre,
      puesto: puesto ?? this.puesto,
      agente: agente ?? this.agente,
      fecha: fecha ?? this.fecha,
      hora: hora ?? this.hora,
      tipoSancion: tipoSancion ?? this.tipoSancion,
      observaciones: observaciones ?? this.observaciones,
      observacionesAdicionales: observacionesAdicionales ?? this.observacionesAdicionales,
      pendiente: pendiente ?? this.pendiente,
      fotoUrl: fotoUrl ?? this.fotoUrl,
      firmaPath: firmaPath ?? this.firmaPath,
      horasExtras: horasExtras ?? this.horasExtras,
      status: status ?? this.status,
      comentariosGerencia: comentariosGerencia ?? this.comentariosGerencia,
      comentariosRrhh: comentariosRrhh ?? this.comentariosRrhh,
      fechaRevision: fechaRevision ?? this.fechaRevision,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// =============================================
  /// 📊 GETTERS BÁSICOS (ORIGINALES)
  /// =============================================

  /// Texto del status para mostrar en UI
  String get statusText {
    switch (status) {
      case 'borrador':
        return 'Borrador';
      case 'enviado':
        return 'Enviado';
      case 'aprobado':
        return 'Aprobado';
      case 'rechazado':
        return 'Rechazado';
      default:
        return status;
    }
  }

  /// Fecha formateada para mostrar
  String get fechaFormateada {
    return DateFormat('dd/MM/yyyy').format(fecha);
  }

  /// Fecha y hora formateada completa
  String get fechaHoraCompleta {
    return '$fechaFormateada $hora';
  }

  /// Emoji representativo del tipo de sanción
  String get tipoSancionEmoji {
    switch (tipoSancion) {
      case 'FALTA':
        return '❌';
      case 'ATRASO':
        return '⏰';
      case 'PERMISO':
        return '📝';
      case 'DORMIDO':
        return '😴';
      case 'MALA URBANIDAD':
        return '🤬';
      case 'FALTA DE RESPETO':
        return '😠';
      case 'MAL UNIFORMADO':
        return '👔';
      case 'ABANDONO DE PUESTO':
        return '🚶';
      case 'MAL SERVICIO DE GUARDIA':
        return '🛡️';
      case 'INCUMPLIMIENTO DE POLITICAS':
        return '📋';
      case 'MAL USO DEL EQUIPO DE DOTACIÓN':
        return '🔧';
      case 'HORAS EXTRAS':
        return '⏱️';
      case 'FRANCO TRABAJADO':
        return '📅';
      default:
        return '📋';
    }
  }

  /// Verificar si tiene archivos adjuntos
  bool get tieneArchivos {
    return fotoUrl != null || firmaPath != null;
  }

  /// Verificar si está completa para enviar
  bool get puedeEnviar {
    return status == 'borrador' && 
           empleadoNombre.isNotEmpty && 
           tipoSancion.isNotEmpty &&
           puesto.isNotEmpty &&
           agente.isNotEmpty;
  }

  /// Verificar si puede ser editada
  bool get puedeEditar {
    return status == 'borrador';
  }

  /// Verificar si puede ser eliminada
  bool get puedeEliminar {
    return status == 'borrador';
  }

  /// =============================================
  /// 🆕 GETTERS PARA CÓDIGOS DE DESCUENTO
  /// =============================================

  /// Obtener código de descuento aplicado por gerencia
  String? get codigoDescuento {
    if (comentariosGerencia == null) return null;
    
    if (comentariosGerencia!.contains('|')) {
      return comentariosGerencia!.split('|')[0];
    }
    
    return comentariosGerencia;
  }

  /// Obtener comentario de gerencia sin código
  String? get comentarioGerenciaSinCodigo {
    if (comentariosGerencia == null) return null;
    
    if (comentariosGerencia!.contains('|')) {
      final partes = comentariosGerencia!.split('|');
      return partes.length > 1 ? partes[1] : '';
    }
    
    return comentariosGerencia;
  }

  /// Verificar si tiene descuento aplicado
  bool get tieneDescuento {
    final codigo = codigoDescuento;
    return codigo != null && 
           codigo != 'SIN_DESC' && 
           codigo != 'RECHAZADO' &&
           codigo.startsWith('D') && 
           codigo.contains('%');
  }

  /// Obtener porcentaje de descuento
  double? get porcentajeDescuento {
    final codigo = codigoDescuento;
    if (codigo == null || !tieneDescuento) return null;
    
    try {
      // Extraer número de "D15%" -> 15.0
      final numeroStr = codigo.substring(1).replaceAll('%', '');
      return double.parse(numeroStr);
    } catch (e) {
      return null;
    }
  }

  /// Verificar si fue procesado por RRHH
  bool get fueModificadoPorRRHH {
    return comentariosRrhh != null && 
           comentariosRrhh!.startsWith('MODIFICADO');
  }

  /// Verificar si fue anulado por RRHH
  bool get fueAnuladoPorRRHH {
    return status == 'rechazado' && 
           comentariosRrhh != null && 
           comentariosRrhh!.startsWith('ANULADO_RRHH');
  }

  /// Verificar si está pendiente de procesamiento RRHH
  bool get pendienteRRHH {
    return status == 'aprobado' && 
           comentariosGerencia != null &&
           comentariosRrhh == null;
  }

  /// Verificar si fue procesado completamente
  bool get procesamientoCompleto {
    return status == 'aprobado' && 
           comentariosRrhh != null;
  }

  /// Texto descriptivo del estado completo
  String get estadoCompleto {
    switch (status) {
      case 'borrador':
        return 'Borrador';
      case 'enviado':
        return 'Enviado - Pendiente Gerencia';
      case 'aprobado':
        if (comentariosRrhh != null) {
          if (fueModificadoPorRRHH) return 'Procesado (Modificado por RRHH)';
          return 'Procesado por RRHH';
        } else if (comentariosGerencia != null) {
          return 'Aprobado Gerencia - Pendiente RRHH';
        } else {
          return 'Aprobado';
        }
      case 'rechazado':
        if (fueAnuladoPorRRHH) return 'Anulado por RRHH';
        return 'Rechazado';
      default:
        return status;
    }
  }

  /// Obtener información del código aplicado (para mostrar en UI)
  Map<String, dynamic> get infoCodigoDescuento {
    final codigo = codigoDescuento;
    
    if (codigo == null) {
      return {
        'tiene_codigo': false,
        'codigo': null,
        'porcentaje': null,
        'descripcion': 'Sin código aplicado',
        'color': null,
      };
    }

    switch (codigo) {
      case 'SIN_DESC':
        return {
          'tiene_codigo': true,
          'codigo': codigo,
          'porcentaje': 0.0,
          'descripcion': '✅ Sin descuento salarial',
          'color': 'blue',
        };
      case 'RECHAZADO':
        return {
          'tiene_codigo': true,
          'codigo': codigo,
          'porcentaje': null,
          'descripcion': '❌ Rechazado por gerencia',
          'color': 'red',
        };
      default:
        if (tieneDescuento) {
          final porcentaje = porcentajeDescuento;
          return {
            'tiene_codigo': true,
            'codigo': codigo,
            'porcentaje': porcentaje,
            'descripcion': '💰 ${porcentaje?.toInt()}% descuento salarial',
            'color': _getColorForPercentage(porcentaje),
          };
        } else {
          return {
            'tiene_codigo': true,
            'codigo': codigo,
            'porcentaje': null,
            'descripcion': '🎯 Código personalizado: $codigo',
            'color': 'purple',
          };
        }
    }
  }

  /// Obtener color según porcentaje de descuento
  String _getColorForPercentage(double? porcentaje) {
    if (porcentaje == null) return 'grey';
    
    if (porcentaje <= 5) return 'orange';
    if (porcentaje <= 10) return 'deepOrange';
    if (porcentaje <= 15) return 'red';
    if (porcentaje <= 20) return 'redAccent';
    return 'purple'; // Para porcentajes mayores
  }

  /// Obtener información de procesamiento RRHH
  Map<String, dynamic> get infoProcesamientoRRHH {
    if (comentariosRrhh == null) {
      return {
        'fue_procesado': false,
        'tipo_procesamiento': null,
        'comentario_limpio': null,
        'codigo_modificado': null,
      };
    }

    final comentario = comentariosRrhh!;
    
    if (comentario.startsWith('MODIFICADO|')) {
      final partes = comentario.split('|');
      return {
        'fue_procesado': true,
        'tipo_procesamiento': 'modificado',
        'comentario_limpio': partes.length > 2 ? partes[2] : '',
        'codigo_modificado': partes.length > 1 ? partes[1] : null,
      };
    } else if (comentario.startsWith('ANULADO_RRHH|')) {
      return {
        'fue_procesado': true,
        'tipo_procesamiento': 'anulado',
        'comentario_limpio': comentario.replaceFirst('ANULADO_RRHH|', ''),
        'codigo_modificado': null,
      };
    } else {
      return {
        'fue_procesado': true,
        'tipo_procesamiento': 'confirmado',
        'comentario_limpio': comentario,
        'codigo_modificado': null,
      };
    }
  }

  /// Emoji representativo del estado
  String get estadoEmoji {
    switch (status) {
      case 'borrador':
        return '📝';
      case 'enviado':
        return '📤';
      case 'aprobado':
        if (comentariosRrhh != null) {
          if (fueModificadoPorRRHH) return '📝';
          if (fueAnuladoPorRRHH) return '🚫';
          return '✅';
        } else if (comentariosGerencia != null) {
          return '⏳';
        } else {
          return '✅';
        }
      case 'rechazado':
        return '❌';
      default:
        return '❓';
    }
  }

  /// Descripción completa para reportes
  String get descripcionCompleta {
    final buffer = StringBuffer();
    
    buffer.writeln('📋 SANCIÓN: $tipoSancion');
    buffer.writeln('👤 Empleado: $empleadoNombre ($empleadoCod)');
    buffer.writeln('🏢 Puesto: $puesto');
    buffer.writeln('🧑‍💼 Agente: $agente');
    buffer.writeln('📅 Fecha: $fechaFormateada $hora');
    buffer.writeln('📊 Estado: $estadoCompleto');
    
    if (pendiente) {
      buffer.writeln('⏳ Estado: PENDIENTE');
    } else {
      buffer.writeln('✅ Estado: RESUELTO');
    }
    
    if (observaciones != null && observaciones!.isNotEmpty) {
      buffer.writeln('📝 Observaciones: $observaciones');
    }
    
    if (observacionesAdicionales != null && observacionesAdicionales!.isNotEmpty) {
      buffer.writeln('📝 Obs. Adicionales: $observacionesAdicionales');
    }
    
    if (horasExtras != null) {
      buffer.writeln('⏱️ Horas extras: $horasExtras');
    }
    
    // Información de códigos de descuento
    if (comentariosGerencia != null) {
      final info = infoCodigoDescuento;
      buffer.writeln('💼 Gerencia: ${info['descripcion']}');
      if (comentarioGerenciaSinCodigo != null && comentarioGerenciaSinCodigo!.isNotEmpty) {
        buffer.writeln('💬 Comentario Gerencia: $comentarioGerenciaSinCodigo');
      }
    }
    
    // Información de procesamiento RRHH
    if (comentariosRrhh != null) {
      final info = infoProcesamientoRRHH;
      switch (info['tipo_procesamiento']) {
        case 'modificado':
          buffer.writeln('🏢 RRHH: Modificado a ${info['codigo_modificado']}');
          break;
        case 'anulado':
          buffer.writeln('🏢 RRHH: Anulado');
          break;
        case 'confirmado':
          buffer.writeln('🏢 RRHH: Confirmado');
          break;
      }
      
      if (info['comentario_limpio'] != null && info['comentario_limpio'].isNotEmpty) {
        buffer.writeln('💬 Comentario RRHH: ${info['comentario_limpio']}');
      }
    }
    
    buffer.writeln('🔗 ID: $id');
    buffer.writeln('📅 Creada: ${createdAt.day}/${createdAt.month}/${createdAt.year}');
    
    return buffer.toString().trim();
  }

  /// Obtener resumen ejecutivo para reportes
  String get resumenEjecutivo {
    final info = infoCodigoDescuento;
    final procesamientoInfo = infoProcesamientoRRHH;
    
    String resumen = '$tipoSancion - $empleadoNombre';
    
    if (info['tiene_codigo']) {
      resumen += ' | ${info['descripcion']}';
    }
    
    if (procesamientoInfo['fue_procesado']) {
      switch (procesamientoInfo['tipo_procesamiento']) {
        case 'modificado':
          resumen += ' | Modificado por RRHH';
          break;
        case 'anulado':
          resumen += ' | Anulado por RRHH';
          break;
        case 'confirmado':
          resumen += ' | Confirmado por RRHH';
          break;
      }
    } else if (pendienteRRHH) {
      resumen += ' | Pendiente RRHH';
    }
    
    return resumen;
  }

  /// Verificar si requiere atención urgente
  bool get requiereAtencionUrgente {
    // Borradores muy antiguos
    if (status == 'borrador' && 
        DateTime.now().difference(createdAt).inDays > 7) {
      return true;
    }
    
    // Enviadas sin aprobar por más de 3 días
    if (status == 'enviado' && 
        DateTime.now().difference(createdAt).inDays > 3) {
      return true;
    }
    
    // Aprobadas por gerencia sin procesar por RRHH por más de 2 días
    if (pendienteRRHH && 
        fechaRevision != null &&
        DateTime.now().difference(fechaRevision!).inDays > 2) {
      return true;
    }
    
    return false;
  }

  /// Días desde la última acción
  int get diasDesdeUltimaAccion {
    DateTime fechaReferencia;
    
    if (fechaRevision != null) {
      fechaReferencia = fechaRevision!;
    } else {
      fechaReferencia = createdAt;
    }
    
    return DateTime.now().difference(fechaReferencia).inDays;
  }

  /// =============================================
  /// 🛠️ MÉTODOS DE UTILIDAD
  /// =============================================

  /// Comparar con otra sanción
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SancionModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  /// Representación en string para debug
  @override
  String toString() {
    return 'SancionModel(id: $id, empleado: $empleadoNombre, tipo: $tipoSancion, status: $status)';
  }

  /// Validar que la sanción esté completa
  Map<String, String> validar() {
    final errores = <String, String>{};
    
    if (empleadoNombre.isEmpty) {
      errores['empleado'] = 'Debe seleccionar un empleado';
    }
    
    if (tipoSancion.isEmpty) {
      errores['tipo'] = 'Debe seleccionar un tipo de sanción';
    }
    
    if (puesto.isEmpty) {
      errores['puesto'] = 'El puesto es obligatorio';
    }
    
    if (agente.isEmpty) {
      errores['agente'] = 'El agente es obligatorio';
    }
    
    if (hora.isEmpty) {
      errores['hora'] = 'La hora es obligatoria';
    }
    
    return errores;
  }

  /// Verificar si es válida para el estado actual
  bool get esValidaParaEstado {
    final errores = validar();
    return errores.isEmpty;
  }

  /// Obtener próximo estado posible
  List<String> get proximosEstadosPosibles {
    switch (status) {
      case 'borrador':
        return ['enviado'];
      case 'enviado':
        return ['aprobado', 'rechazado'];
      case 'aprobado':
        if (pendienteRRHH) {
          return ['rechazado']; // RRHH puede anular
        }
        return []; // Ya procesado
      case 'rechazado':
        return []; // Estado final
      default:
        return [];
    }
  }

  /// Crear copia para edición
  SancionModel paraEdicion() {
    return copyWith(
      updatedAt: DateTime.now(),
    );
  }

  /// Crear copia lista para envío
  SancionModel paraEnvio() {
    return copyWith(
      status: 'enviado',
      updatedAt: DateTime.now(),
    );
  }

  /// Crear copia aprobada con código
  SancionModel aprobadaConCodigo(String codigoCompleto, String reviewedBy) {
    return copyWith(
      status: 'aprobado',
      comentariosGerencia: codigoCompleto,
      reviewedBy: reviewedBy,
      fechaRevision: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Crear copia rechazada
  SancionModel rechazada(String motivo, String reviewedBy) {
    return copyWith(
      status: 'rechazado',
      comentariosGerencia: 'RECHAZADO|$motivo',
      reviewedBy: reviewedBy,
      fechaRevision: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Crear copia procesada por RRHH
  SancionModel procesadaPorRRHH(String comentariosRrhh, String reviewedBy) {
    return copyWith(
      comentariosRrhh: comentariosRrhh,
      reviewedBy: reviewedBy,
      fechaRevision: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}