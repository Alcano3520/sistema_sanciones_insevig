/// Modelo de usuario del sistema
/// Define quién puede usar la aplicación y sus permisos
class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final String? department;
  final String? avatarUrl;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.department,
    this.avatarUrl,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Crear desde Map (desde Supabase)
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      fullName: map['full_name'] ?? '',
      role: map['role'] ?? '',
      department: map['department'],
      avatarUrl: map['avatar_url'],
      isActive: map['is_active'] ?? true,
      createdAt: DateTime.tryParse(map['created_at'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(map['updated_at'] ?? '') ?? DateTime.now(),
    );
  }

  /// Convertir a Map (para enviar a Supabase)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role,
      'department': department,
      'avatar_url': avatarUrl,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Roles disponibles
  static const String roleSupervisor = 'supervisor';
  static const String roleGerencia = 'gerencia';
  static const String roleRrhh = 'rrhh';
  static const String roleAprobador =
      'aprobador'; // 🆕 ROL ESPECÍFICO PARA APROBAR

  /// Verificadores de rol
  bool get isSupervisor => role == roleSupervisor;
  bool get isGerencia => role == roleGerencia;
  bool get isRrhh => role == roleRrhh;
  bool get isAprobador => role == roleAprobador;

  // 🔥 CAMBIO CRÍTICO: Solo aprobadores específicos pueden aprobar
  bool get canApprove => isAprobador || isGerencia || isRrhh;

  // Supervisores solo pueden crear sanciones
  bool get canCreateSanciones => isSupervisor;

  // Solo gerencia y RRHH pueden ver todas las sanciones
  bool get canViewAllSanciones => isGerencia || isRrhh;

  // 🆕 Nuevo: Solo aprobadores pueden cambiar status
  bool get canChangeStatus => canApprove;

  /// Descripción del rol
  String get roleDescription {
    switch (role) {
      case roleSupervisor:
        return 'Supervisor';
      case roleGerencia:
        return 'Gerencia';
      case roleRrhh:
        return 'Recursos Humanos';
      case roleAprobador:
        return 'Aprobador';
      default:
        return role;
    }
  }

  /// Emoji del rol
  String get roleEmoji {
    switch (role) {
      case roleSupervisor:
        return '👮';
      case roleGerencia:
        return '👔';
      case roleRrhh:
        return '🧑‍💼';
      case roleAprobador:
        return '✅';
      default:
        return '👤';
    }
  }

  /// Nombre completo con rol
  String get displayName => '$fullName ($roleDescription)';

  /// Iniciales para avatar
  String get initials {
    final names = fullName.split(' ');
    if (names.length >= 2) {
      return '${names[0][0]}${names[1][0]}'.toUpperCase();
    } else if (names.isNotEmpty) {
      return names[0][0].toUpperCase();
    }
    return 'U';
  }

  /// Crear copia con modificaciones
  UserModel copyWith({
    String? id,
    String? email,
    String? fullName,
    String? role,
    String? department,
    String? avatarUrl,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      department: department ?? this.department,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'UserModel(id: $id, email: $email, role: $role)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
