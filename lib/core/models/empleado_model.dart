import 'package:flutter/material.dart';

/// Modelo de empleado basado en tu tabla real de Supabase
/// Estructura exacta de tu tabla public.empleados
class EmpleadoModel {
  final int id;
  final int cod;
  final String? nombres;
  final String? apellidos;
  final String? cedula;
  final String? nombresCompletos;
  final String? nomcargo;
  final String? codCargo;
  final double? sueldo;
  final String? nomdep;
  final String? codDepartamento;
  final String? seccion;
  final String? codSeccion;
  final String? fechaIngreso;
  final String? fechaSalida;
  final String? estado;
  final String? cuentaAhorros;
  final String? cuentaCorriente;
  final String? cuentaBancaria;
  final String? banco;
  final String? direccion;
  final String? telefono;
  final String? genero;
  final String? fechaNacimiento;
  final String? estadoCivil;
  final String? tipoSangre;
  final bool esActivo;
  final bool esLiquidado;
  final bool esSuspendido;
  final String? hashDatos;
  final DateTime? fechaActualizacion;
  final String? version;
  final DateTime createdAt;
  final DateTime updatedAt;

  EmpleadoModel({
    required this.id,
    required this.cod,
    this.nombres,
    this.apellidos,
    this.cedula,
    this.nombresCompletos,
    this.nomcargo,
    this.codCargo,
    this.sueldo,
    this.nomdep,
    this.codDepartamento,
    this.seccion,
    this.codSeccion,
    this.fechaIngreso,
    this.fechaSalida,
    this.estado,
    this.cuentaAhorros,
    this.cuentaCorriente,
    this.cuentaBancaria,
    this.banco,
    this.direccion,
    this.telefono,
    this.genero,
    this.fechaNacimiento,
    this.estadoCivil,
    this.tipoSangre,
    this.esActivo = false,
    this.esLiquidado = false,
    this.esSuspendido = false,
    this.hashDatos,
    this.fechaActualizacion,
    this.version,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Crear desde Map (desde tu Supabase real)
  factory EmpleadoModel.fromMap(Map<String, dynamic> map) {
    return EmpleadoModel(
      id: map['id']?.toInt() ?? 0,
      cod: map['cod']?.toInt() ?? 0,
      nombres: map['nombres'],
      apellidos: map['apellidos'],
      cedula: map['cedula'],
      nombresCompletos: map['nombres_completos'] ??
          (map['nombres'] != null || map['apellidos'] != null
              ? '${map['nombres'] ?? ''} ${map['apellidos'] ?? ''}'.trim()
              : null),
      nomcargo: map['nomcargo'],
      codCargo: map['cod_cargo'],
      sueldo: map['sueldo'] != null
          ? double.tryParse(map['sueldo'].toString())
          : null,
      nomdep: map['nomdep'],
      codDepartamento: map['cod_departamento'],
      seccion: map['seccion'],
      codSeccion: map['cod_seccion'],
      fechaIngreso: map['fecha_ingreso'],
      fechaSalida: map['fecha_salida'],
      estado: map['estado'],
      cuentaAhorros: map['cuenta_ahorros'],
      cuentaCorriente: map['cuenta_corriente'],
      cuentaBancaria: map['cuenta_bancaria'],
      banco: map['banco'],
      direccion: map['direccion'],
      telefono: map['telefono'],
      genero: map['genero'],
      fechaNacimiento: map['fecha_nacimiento'],
      estadoCivil: map['estado_civil'],
      tipoSangre: map['tipo_sangre'],
      esActivo: map['es_activo'] ?? false,
      esLiquidado: map['es_liquidado'] ?? false,
      esSuspendido: map['es_suspendido'] ?? false,
      hashDatos: map['hash_datos'],
      fechaActualizacion: map['fecha_actualizacion'] != null
          ? DateTime.tryParse(map['fecha_actualizacion'])
          : null,
      version: map['version'],
      createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  /// Convertir a Map (para enviar a Supabase si es necesario)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cod': cod,
      'nombres': nombres,
      'apellidos': apellidos,
      'cedula': cedula,
      'nombres_completos': nombresCompletos,
      'nomcargo': nomcargo,
      'cod_cargo': codCargo,
      'sueldo': sueldo,
      'nomdep': nomdep,
      'cod_departamento': codDepartamento,
      'seccion': seccion,
      'cod_seccion': codSeccion,
      'fecha_ingreso': fechaIngreso,
      'fecha_salida': fechaSalida,
      'estado': estado,
      'cuenta_ahorros': cuentaAhorros,
      'cuenta_corriente': cuentaCorriente,
      'cuenta_bancaria': cuentaBancaria,
      'banco': banco,
      'direccion': direccion,
      'telefono': telefono,
      'genero': genero,
      'fecha_nacimiento': fechaNacimiento,
      'estado_civil': estadoCivil,
      'tipo_sangre': tipoSangre,
      'es_activo': esActivo,
      'es_liquidado': esLiquidado,
      'es_suspendido': esSuspendido,
      'hash_datos': hashDatos,
      'fecha_actualizacion': fechaActualizacion?.toIso8601String(),
      'version': version,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Para mostrar en UI - nombre completo (CORREGIDO para null safety)
  String get displayName {
    if (nombresCompletos != null && nombresCompletos!.isNotEmpty) {
      return nombresCompletos!;
    }

    final nombreCompleto = '${nombres ?? ''} ${apellidos ?? ''}'.trim();
    if (nombreCompleto.isEmpty) {
      return 'Sin nombre';
    }

    return nombreCompleto;
  }

  /// Para mostrar información del cargo
  String get displayInfo => nomcargo ?? 'Sin cargo';

  /// Para mostrar departamento
  String get displayDepartment => nomdep ?? 'Sin departamento';

  /// Texto completo para búsqueda
  String get searchText => [
        nombresCompletos,
        nombres,
        apellidos,
        cedula,
        nomcargo,
        nomdep,
        cod.toString(),
        estado,
        telefono,
      ].where((e) => e != null && e.isNotEmpty).join(' ').toLowerCase();

  /// Para autocompletado (campos esenciales)
  Map<String, dynamic> toAutocompleteMap() {
    return {
      'id': id,
      'cod': cod,
      'nombres_completos': displayName,
      'nomcargo': nomcargo ?? '',
      'nomdep': nomdep ?? '',
      'cedula': cedula,
      'estado': estado,
      'es_activo': esActivo,
      'telefono': telefono,
      'seccion': seccion,
    };
  }

  /// Estado del empleado (activo, inactivo, suspendido, etc.)
  String get estadoDisplay {
    if (esSuspendido) return '🔒 Suspendido';
    if (esLiquidado) return '📋 Liquidado';
    if (!esActivo) return '❌ Inactivo';
    return '✅ Activo';
  }

  /// Color del estado
  Color get estadoColor {
    if (esSuspendido) return const Color(0xFFFF5722); // Rojo oscuro
    if (esLiquidado) return const Color(0xFF9E9E9E); // Gris
    if (!esActivo) return const Color(0xFFF44336); // Rojo
    return const Color(0xFF4CAF50); // Verde
  }

  /// Información completa para mostrar en detalles
  String get infoCompleta {
    final buffer = StringBuffer();
    buffer.writeln('Código: $cod');
    buffer.writeln('Nombre: $displayName');
    if (cedula != null && cedula!.isNotEmpty) buffer.writeln('Cédula: $cedula');
    buffer.writeln('Cargo: ${nomcargo ?? 'N/A'}');
    buffer.writeln('Departamento: ${nomdep ?? 'N/A'}');
    if (seccion != null && seccion!.isNotEmpty)
      buffer.writeln('Sección: $seccion');
    buffer.writeln('Estado: $estadoDisplay');
    if (telefono != null && telefono!.isNotEmpty)
      buffer.writeln('Teléfono: $telefono');
    if (fechaIngreso != null && fechaIngreso!.isNotEmpty)
      buffer.writeln('Fecha Ingreso: $fechaIngreso');
    return buffer.toString();
  }

  /// Validar si el empleado puede ser sancionado
  bool get puedeSerSancionado {
    return esActivo && !esLiquidado && !esSuspendido;
  }

  /// Razón por la cual no puede ser sancionado
  String? get razonNoSancionable {
    if (!esActivo) return 'Empleado inactivo';
    if (esLiquidado) return 'Empleado liquidado';
    if (esSuspendido) return 'Empleado suspendido';
    return null;
  }

  @override
  String toString() {
    return 'EmpleadoModel(cod: $cod, nombre: $displayName, cargo: $nomcargo, activo: $esActivo)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EmpleadoModel && other.cod == cod;
  }

  @override
  int get hashCode => cod.hashCode;
}
