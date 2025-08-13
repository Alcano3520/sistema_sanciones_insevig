import 'package:uuid/uuid.dart';

/// Modelo principal de sanción - idéntico a tu aplicación Kivy
/// Con los nuevos campos: pendiente y observaciones_adicionales
/// ✅ CORREGIDO: Constructor con ID opcional (requerido por el sistema)
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
  final String? observacionesAdicionales; // NUEVO CAMPO
  final bool pendiente; // NUEVO CAMPO
  final String? fotoUrl;
  final String? firmaPath;
  final int? horasExtras; // Solo para HORAS EXTRAS
  final String status;
  final String? comentariosGerencia;
  final String? comentariosRrhh;
  final DateTime? fechaRevision;
  final String? reviewedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// ✅ CORREGIDO: Constructor con ID opcional
  SancionModel({
    String? id, // ← Hacer opcional para evitar errores
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
    this.pendiente = true,
    this.fotoUrl,
    this.firmaPath,
    this.horasExtras,
    this.status = 'borrador',
    this.comentariosGerencia,
    this.comentariosRrhh,
    this.fechaRevision,
    this.reviewedBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : id = id ?? const Uuid().v4(), // ← Si no se proporciona ID, generar uno
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  /// Crear desde Map (desde Supabase)
  factory SancionModel.fromMap(Map<String, dynamic> map) {
    return SancionModel(
      id: map['id'] ?? const Uuid().v4(),
      supervisorId: map['supervisor_id'] ?? '',
      empleadoCod: map['empleado_cod'] ?? 0,
      empleadoNombre: map['empleado_nombre'] ?? '',
      puesto: map['puesto'] ?? '',
      agente: map['agente'] ?? '',
      fecha: DateTime.tryParse(map['fecha'] ?? '') ?? DateTime.now(),
      hora: map['hora'] ?? '',
      tipoSancion: map['tipo_sancion'] ?? '',
      observaciones: map['observaciones'],
      observacionesAdicionales: map['observaciones_adicionales'],
      pendiente: map['pendiente'] ?? true,
      fotoUrl: map['foto_url'],
      firmaPath: map['firma_path'],
      horasExtras: map['horas_extras'],
      status: map['status'] ?? 'borrador',
      comentariosGerencia: map['comentarios_gerencia'],
      comentariosRrhh: map['comentarios_rrhh'],
      fechaRevision: map['fecha_revision'] != null
          ? DateTime.tryParse(map['fecha_revision'])
          : null,
      reviewedBy: map['reviewed_by'],
      createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  /// Convertir a Map (para enviar a Supabase)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'supervisor_id': supervisorId,
      'empleado_cod': empleadoCod,
      'empleado_nombre': empleadoNombre,
      'puesto': puesto,
      'agente': agente,
      'fecha': fecha.toIso8601String().split('T')[0], // Solo fecha YYYY-MM-DD
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

  /// ✅ CORREGIDO: Tipos de sanción disponibles (idénticos a tu Kivy)
  static const List<String> tiposSancion = [
    'FALTA',
    'ATRASO',
    'PERMISO',
    'DORMIDO',
    'MALA URBANIDAD',
    'FALTA DE RESPETO',
    'MAL UNIFORMADO',
    'ABANDONO DE PUESTO',
    'MAL SERVICIO DE GUARDIA',
    'INCUMPLIMIENTO DE POLITICAS',
    'MAL USO DEL EQUIPO DE DOTACIÓN',
    'HORAS EXTRAS',
    'FRANCO TRABAJADO'
  ];

  /// Obtener emoji para el tipo de sanción
  String get tipoSancionEmoji {
    switch (tipoSancion) {
      case 'FALTA':
        return '❌';
      case 'ATRASO':
        return '⏰';
      case 'PERMISO':
        return '📋';
      case 'DORMIDO':
        return '😴';
      case 'MALA URBANIDAD':
        return '🗣️';
      case 'FALTA DE RESPETO':
        return '😠';
      case 'MAL UNIFORMADO':
        return '👔';
      case 'ABANDONO DE PUESTO':
        return '🏃';
      case 'MAL SERVICIO DE GUARDIA':
        return '🛡️';
      case 'INCUMPLIMIENTO DE POLITICAS':
        return '📋';
      case 'MAL USO DEL EQUIPO DE DOTACIÓN':
        return '⚠️';
      case 'HORAS EXTRAS':
        return '⏱️';
      case 'FRANCO TRABAJADO':
        return '📅';
      default:
        return '⚠️';
    }
  }

  /// Color del status
  String get statusColor {
    switch (status) {
      case 'borrador':
        return 'orange';
      case 'enviado':
        return 'blue';
      case 'aprobado':
        return 'green';
      case 'rechazado':
        return 'red';
      default:
        return 'grey';
    }
  }

  /// Texto del status
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
    return '${fecha.day}/${fecha.month}/${fecha.year}';
  }

  /// Descripción completa para mostrar
  String get descripcionCompleta {
    final buffer = StringBuffer();
    buffer.write('$tipoSancionEmoji $tipoSancion');

    if (horasExtras != null) {
      buffer.write(' ($horasExtras hrs)');
    }

    if (observaciones != null && observaciones!.isNotEmpty) {
      buffer.write(' - ${observaciones!}');
    }

    return buffer.toString();
  }

  /// Validar si la sanción está completa
  bool get isValid {
    return empleadoCod > 0 &&
        empleadoNombre.isNotEmpty &&
        puesto.isNotEmpty &&
        agente.isNotEmpty &&
        tipoSancion.isNotEmpty;
  }

  /// Validar si requiere horas extras
  bool get requiresHorasExtras => tipoSancion == 'HORAS EXTRAS';

  /// ✅ NUEVO: Verificar si puede ser aprobada por gerencia
  bool get canBeApprovedByGerencia => status == 'enviado';

  /// ✅ NUEVO: Verificar si puede ser revisada por RRHH
  bool get canBeReviewedByRrhh => status == 'aprobado' && comentariosGerencia != null;

  /// ✅ NUEVO: Obtener código de descuento si existe
  String? get codigoDescuento {
    if (comentariosGerencia == null) return null;
    
    final comentario = comentariosGerencia!;
    if (comentario.startsWith('D') && comentario.contains('%')) {
      final partes = comentario.split(' - ');
      if (partes.isNotEmpty) {
        return partes[0]; // Devolver solo el código (ej: "D10%")
      }
    }
    
    return null;
  }

  /// ✅ NUEVO: Obtener comentario sin código
  String? get comentarioSinCodigo {
    if (comentariosGerencia == null) return null;
    
    final comentario = comentariosGerencia!;
    if (comentario.contains(' - ')) {
      final partes = comentario.split(' - ');
      if (partes.length > 1) {
        return partes.sublist(1).join(' - '); // Todo después del primer " - "
      }
    }
    
    return comentario; // Si no tiene formato de código, devolver completo
  }

  /// Crear copia con modificaciones
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
      observacionesAdicionales:
          observacionesAdicionales ?? this.observacionesAdicionales,
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

  @override
  String toString() {
    return 'SancionModel(id: $id, empleado: $empleadoNombre, tipo: $tipoSancion, status: $status)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SancionModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}