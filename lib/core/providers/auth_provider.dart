import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/sancion_model.dart';

/// 👤 Modelo de usuario con sistema de roles y permisos extendido
/// 🆕 SISTEMA DE APROBACIONES Y CÓDIGOS DE DESCUENTO INTEGRADO
class UserModel {
  final String id;
  final String email;
  final String fullName;
  final String role;
  final String? department;
  final String? position;
  final bool isActive;
  final DateTime? lastLogin;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserModel({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.department,
    this.position,
    required this.isActive,
    this.lastLogin,
    required this.createdAt,
    required this.updatedAt,
  });

  /// =============================================
  /// 🏭 FACTORY CONSTRUCTORS
  /// =============================================

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      fullName: map['full_name'] ?? '',
      role: map['role'] ?? 'supervisor',
      department: map['department'],
      position: map['position'],
      isActive: map['is_active'] ?? true,
      lastLogin: map['last_login'] != null 
          ? DateTime.parse(map['last_login']) 
          : null,
      createdAt: map['created_at'] != null 
          ? DateTime.parse(map['created_at']) 
          : DateTime.now(),
      updatedAt: map['updated_at'] != null 
          ? DateTime.parse(map['updated_at']) 
          : DateTime.now(),
    );
  }

  /// =============================================
  /// 📤 SERIALIZACIÓN
  /// =============================================

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'role': role,
      'department': department,
      'position': position,
      'is_active': isActive,
      'last_login': lastLogin?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// =============================================
  /// 🔄 COPYSWITH
  /// =============================================

  UserModel copyWith({
    String? id,
    String? email,
    String? fullName,
    String? role,
    String? department,
    String? position,
    bool? isActive,
    DateTime? lastLogin,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      role: role ?? this.role,
      department: department ?? this.department,
      position: position ?? this.position,
      isActive: isActive ?? this.isActive,
      lastLogin: lastLogin ?? this.lastLogin,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// =============================================
  /// 📊 GETTERS BÁSICOS (ORIGINALES)
  /// =============================================

  /// Verificar si puede crear sanciones
  bool get canCreateSanciones {
    return ['supervisor', 'gerencia', 'aprobador'].contains(role) && isActive;
  }

  /// Verificar si puede aprobar sanciones (método original)
  bool get canApprove {
    return ['gerencia', 'rrhh', 'aprobador'].contains(role) && isActive;
  }

  /// Verificar si puede ver todas las sanciones
  bool get canViewAllSanciones {
    return ['gerencia', 'rrhh', 'aprobador'].contains(role) && isActive;
  }

  /// Verificar si puede generar reportes
  bool get canGenerateReports {
    return isActive; // Todos los usuarios activos pueden generar reportes básicos
  }

  /// Verificar si puede exportar datos
  bool get canExportData {
    return ['gerencia', 'rrhh', 'aprobador'].contains(role) && isActive;
  }

  /// =============================================
  /// 🆕 GETTERS PARA SISTEMA DE APROBACIONES
  /// =============================================

  /// Verificar si puede aprobar con códigos de descuento (Gerencia/Aprobador)
  bool get canApproveWithCodes {
    return ['gerencia', 'aprobador'].contains(role) && isActive;
  }

  /// Verificar si puede procesar decisiones de gerencia (RRHH)
  bool get canProcessGerenciaDecisions {
    return role == 'rrhh' && isActive;
  }

  /// Verificar si puede ver panel de aprobaciones
  bool get canViewApprovalPanel {
    return canApproveWithCodes || canProcessGerenciaDecisions;
  }

  /// Verificar si puede modificar códigos de descuento
  bool get canModifyDiscountCodes {
    return role == 'rrhh' && isActive;
  }

  /// Verificar si puede anular decisiones de gerencia
  bool get canOverrideGerenciaDecisions {
    return role == 'rrhh' && isActive;
  }

  /// Verificar si puede acceder al panel administrativo
  bool get canAccessAdminPanel {
    return role == 'rrhh' && isActive;
  }

  /// Verificar si puede ver estadísticas avanzadas
  bool get canViewAdvancedStats {
    return ['gerencia', 'rrhh', 'aprobador'].contains(role) && isActive;
  }

  /// =============================================
  /// 🎨 GETTERS DE PRESENTACIÓN
  /// =============================================

  /// Obtener texto descriptivo del rol para UI
  String get roleDescription {
    switch (role) {
      case 'supervisor':
        return 'Supervisor';
      case 'gerencia':
        return 'Gerencia';
      case 'rrhh':
        return 'Recursos Humanos';
      case 'aprobador':
        return 'Aprobador';
      default:
        return role.toUpperCase();
    }
  }

  /// Obtener icono representativo del rol
  String get roleIcon {
    switch (role) {
      case 'supervisor':
        return '👨‍💼';
      case 'gerencia':
        return '🏢';
      case 'rrhh':
        return '👥';
      case 'aprobador':
        return '✅';
      default:
        return '👤';
    }
  }

  /// Obtener color representativo del rol
  String get roleColor {
    switch (role) {
      case 'supervisor':
        return 'blue';
      case 'gerencia':
        return 'purple';
      case 'rrhh':
        return 'teal';
      case 'aprobador':
        return 'green';
      default:
        return 'grey';
    }
  }

  /// Obtener descripción completa del usuario
  String get fullDescription {
    final buffer = StringBuffer();
    buffer.write('$roleIcon $fullName');
    
    if (department != null) {
      buffer.write(' - $department');
    }
    
    if (position != null) {
      buffer.write(' ($position)');
    }
    
    return buffer.toString();
  }

  /// =============================================
  /// 🔐 SISTEMA DE PERMISOS
  /// =============================================

  /// Obtener permisos específicos del rol
  Map<String, bool> get rolePermissions {
    switch (role) {
      case 'supervisor':
        return {
          'create_sanciones': true,
          'edit_own_sanciones': true,
          'view_own_sanciones': true,
          'delete_own_borradores': true,
          'approve_sanciones': false,
          'approve_with_codes': false,
          'process_gerencia_decisions': false,
          'view_all_sanciones': false,
          'generate_reports': true,
          'export_data': false,
          'view_advanced_stats': false,
          'access_admin_panel': false,
        };
      
      case 'gerencia':
        return {
          'create_sanciones': true,
          'edit_own_sanciones': true,
          'view_own_sanciones': true,
          'view_all_sanciones': true,
          'delete_own_borradores': true,
          'approve_sanciones': true,
          'approve_with_codes': true,
          'process_gerencia_decisions': false,
          'generate_reports': true,
          'export_data': true,
          'view_advanced_stats': true,
          'access_admin_panel': false,
          'manage_discount_codes': true,
        };
      
      case 'aprobador':
        return {
          'create_sanciones': true,
          'edit_own_sanciones': true,
          'view_own_sanciones': true,
          'view_all_sanciones': true,
          'delete_own_borradores': true,
          'approve_sanciones': true,
          'approve_with_codes': true,
          'process_gerencia_decisions': false,
          'generate_reports': true,
          'export_data': true,
          'view_advanced_stats': true,
          'access_admin_panel': false,
          'manage_discount_codes': true,
        };
      
      case 'rrhh':
        return {
          'create_sanciones': false,
          'edit_own_sanciones': false,
          'view_own_sanciones': false,
          'view_all_sanciones': true,
          'delete_own_borradores': false,
          'approve_sanciones': false,
          'approve_with_codes': false,
          'process_gerencia_decisions': true,
          'modify_discount_codes': true,
          'override_gerencia_decisions': true,
          'generate_reports': true,
          'export_data': true,
          'view_advanced_stats': true,
          'access_admin_panel': true,
          'manage_users': true,
          'view_system_logs': true,
        };
      
      default:
        return {
          'create_sanciones': false,
          'edit_own_sanciones': false,
          'view_own_sanciones': false,
          'view_all_sanciones': false,
          'delete_own_borradores': false,
          'approve_sanciones': false,
          'approve_with_codes': false,
          'process_gerencia_decisions': false,
          'generate_reports': false,
          'export_data': false,
          'view_advanced_stats': false,
          'access_admin_panel': false,
        };
    }
  }

  /// Verificar permiso específico
  bool hasPermission(String permission) {
    if (!isActive) return false;
    return rolePermissions[permission] ?? false;
  }

  /// Obtener lista de acciones disponibles para este rol
  List<String> get availableActions {
    final actions = <String>[];
    final permissions = rolePermissions;
    
    if (permissions['create_sanciones'] == true) {
      actions.add('Crear sanciones');
    }
    
    if (permissions['approve_with_codes'] == true) {
      actions.add('Aprobar con códigos de descuento');
    }
    
    if (permissions['process_gerencia_decisions'] == true) {
      actions.add('Procesar decisiones de gerencia');
    }
    
    if (permissions['view_all_sanciones'] == true) {
      actions.add('Ver todas las sanciones');
    }
    
    if (permissions['generate_reports'] == true) {
      actions.add('Generar reportes');
    }
    
    if (permissions['export_data'] == true) {
      actions.add('Exportar datos');
    }
    
    if (permissions['access_admin_panel'] == true) {
      actions.add('Acceder panel administrativo');
    }
    
    return actions;
  }

  /// Verificar si puede realizar una acción específica en una sanción
  bool canPerformActionOnSancion(String action, SancionModel sancion) {
    if (!isActive) return false;

    switch (action) {
      case 'edit':
        return hasPermission('edit_own_sanciones') && 
               id == sancion.supervisorId && 
               sancion.status == 'borrador';
      
      case 'delete':
        return hasPermission('delete_own_borradores') && 
               id == sancion.supervisorId && 
               sancion.status == 'borrador';
      
      case 'approve_with_code':
        return hasPermission('approve_with_codes') && 
               sancion.status == 'enviado';
      
      case 'process_rrhh':
        return hasPermission('process_gerencia_decisions') && 
               sancion.status == 'aprobado' &&
               sancion.comentariosGerencia != null &&
               sancion.comentariosRrhh == null;
      
      case 'view_details':
        if (hasPermission('view_all_sanciones')) return true;
        if (hasPermission('view_own_sanciones') && id == sancion.supervisorId) return true;
        return false;
      
      case 'toggle_pendiente':
        return hasPermission('approve_sanciones') || 
               hasPermission('process_gerencia_decisions');
      
      default:
        return false;
    }
  }

  /// Obtener mensaje de restricción para acción no permitida
  String getRestrictionMessage(String action) {
    if (!isActive) {
      return 'Tu cuenta está inactiva. Contacta al administrador.';
    }

    switch (action) {
      case 'approve_with_code':
        return 'Solo gerencia y aprobadores pueden aprobar con códigos de descuento';
      case 'process_rrhh':
        return 'Solo RRHH puede procesar decisiones de gerencia';
      case 'view_all_sanciones':
        return 'No tienes permisos para ver todas las sanciones';
      case 'create_sanciones':
        return 'No tienes permisos para crear sanciones';
      case 'export_data':
        return 'No tienes permisos para exportar datos';
      case 'access_admin_panel':
        return 'No tienes permisos para acceder al panel administrativo';
      default:
        return 'No tienes permisos para realizar esta acción';
    }
  }

  /// =============================================
  /// 🎯 MÉTODOS DE VALIDACIÓN ESPECÍFICOS
  /// =============================================

  /// Verificar si puede ver tabs específicos del historial
  bool canViewHistorialTab(String tabType) {
    switch (tabType) {
      case 'gerencia_pendientes':
        return canApproveWithCodes;
      case 'gerencia_aprobadas':
        return canApproveWithCodes;
      case 'rrhh_pendientes':
        return canProcessGerenciaDecisions;
      case 'rrhh_procesadas':
        return canProcessGerenciaDecisions;
      default:
        return true;
    }
  }

  /// Verificar si puede usar filtros avanzados
  bool get canUseAdvancedFilters {
    return canViewAllSanciones;
  }

  /// Verificar si puede generar reportes PDF
  bool get canGeneratePDFReports {
    return canGenerateReports;
  }

  /// Verificar si puede ver estadísticas específicas
  bool canViewStatistic(String statisticType) {
    switch (statisticType) {
      case 'discount_codes':
        return canApproveWithCodes || canProcessGerenciaDecisions;
      case 'processing_times':
        return canViewAdvancedStats;
      case 'user_performance':
        return role == 'rrhh';
      case 'approval_rates':
        return canViewAdvancedStats;
      default:
        return canGenerateReports;
    }
  }

  /// =============================================
  /// 🛠️ MÉTODOS DE UTILIDAD
  /// =============================================

  /// Comparar con otro usuario
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  /// Representación en string para debug
  @override
  String toString() {
    return 'UserModel(id: $id, fullName: $fullName, role: $role, isActive: $isActive)';
  }

  /// Verificar si el usuario es válido
  bool get isValid {
    return id.isNotEmpty && 
           email.isNotEmpty && 
           fullName.isNotEmpty && 
           role.isNotEmpty &&
           isActive;
  }

  /// Obtener tiempo desde último login
  String get timeSinceLastLogin {
    if (lastLogin == null) return 'Nunca';
    
    final now = DateTime.now();
    final difference = now.difference(lastLogin!);
    
    if (difference.inDays > 0) {
      return 'Hace ${difference.inDays} día${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Hace ${difference.inHours} hora${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'Hace ${difference.inMinutes} minuto${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'Ahora mismo';
    }
  }

  /// Crear copia con último login actualizado
  UserModel withLastLogin() {
    return copyWith(
      lastLogin: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}

/// 🔐 Provider de autenticación con gestión de usuarios y roles
/// 🆕 EXTENDIDO CON SISTEMA DE PERMISOS GRANULAR
class AuthProvider extends ChangeNotifier {
  static final SupabaseClient _supabase = Supabase.instance.client;
  
  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  /// =============================================
  /// 📊 GETTERS
  /// =============================================

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isLoggedIn => _currentUser != null && _currentUser!.isActive;
  bool get isActive => _currentUser?.isActive ?? false;

  /// =============================================
  /// 🔑 AUTENTICACIÓN
  /// =============================================

  /// Inicializar provider
  Future<void> initialize() async {
    try {
      _setLoading(true);
      _clearError();

      final session = _supabase.auth.currentSession;
      if (session?.user != null) {
        await _loadUserProfile(session!.user.id);
      }
    } catch (e) {
      _setError('Error inicializando autenticación: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Iniciar sesión
  Future<bool> signIn(String email, String password) async {
    try {
      _setLoading(true);
      _clearError();

      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.user != null) {
        await _loadUserProfile(response.user!.id);
        await _updateLastLogin();
        return true;
      }

      return false;
    } on AuthException catch (e) {
      _setError(_getAuthErrorMessage(e.message));
      return false;
    } catch (e) {
      _setError('Error inesperado: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Cerrar sesión
  Future<void> signOut() async {
    try {
      _setLoading(true);
      await _supabase.auth.signOut();
      _currentUser = null;
      _clearError();
    } catch (e) {
      _setError('Error cerrando sesión: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Cargar perfil de usuario
  Future<void> _loadUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      _currentUser = UserModel.fromMap(response);
      print('✅ Usuario cargado: ${_currentUser!.fullName} (${_currentUser!.role})');
    } catch (e) {
      throw Exception('Error cargando perfil de usuario: $e');
    }
  }

  /// Actualizar último login
  Future<void> _updateLastLogin() async {
    if (_currentUser == null) return;

    try {
      await _supabase
          .from('profiles')
          .update({
            'last_login': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', _currentUser!.id);

      _currentUser = _currentUser!.withLastLogin();
    } catch (e) {
      print('⚠️ Error actualizando último login: $e');
    }
  }

  /// =============================================
  /// 👥 GESTIÓN DE USUARIOS (SOLO RRHH)
  /// =============================================

  /// Obtener todos los usuarios (solo RRHH)
  Future<List<UserModel>> getAllUsers() async {
    if (!(_currentUser?.hasPermission('manage_users') ?? false)) {
      throw Exception('No tienes permisos para gestionar usuarios');
    }

    try {
      final response = await _supabase
          .from('profiles')
          .select()
          .order('full_name', ascending: true);

      return (response as List)
          .map((data) => UserModel.fromMap(data))
          .toList();
    } catch (e) {
      throw Exception('Error obteniendo usuarios: $e');
    }
  }

  /// Actualizar rol de usuario (solo RRHH)
  Future<bool> updateUserRole(String userId, String newRole) async {
    if (!(_currentUser?.hasPermission('manage_users') ?? false)) {
      throw Exception('No tienes permisos para gestionar usuarios');
    }

    try {
      await _supabase
          .from('profiles')
          .update({
            'role': newRole,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      print('✅ Rol actualizado para usuario $userId: $newRole');
      return true;
    } catch (e) {
      throw Exception('Error actualizando rol: $e');
    }
  }

  /// Activar/desactivar usuario (solo RRHH)
  Future<bool> toggleUserStatus(String userId, bool isActive) async {
    if (!(_currentUser?.hasPermission('manage_users') ?? false)) {
      throw Exception('No tienes permisos para gestionar usuarios');
    }

    try {
      await _supabase
          .from('profiles')
          .update({
            'is_active': isActive,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      print('✅ Estado actualizado para usuario $userId: ${isActive ? 'activo' : 'inactivo'}');
      return true;
    } catch (e) {
      throw Exception('Error actualizando estado: $e');
    }
  }

  /// =============================================
  /// 🎯 MÉTODOS DE CONVENIENCIA PARA PERMISOS
  /// =============================================

  /// Verificar si el usuario actual puede realizar una acción
  bool canPerformAction(String action) {
    return _currentUser?.hasPermission(action) ?? false;
  }

  /// Verificar si puede realizar acción en sanción específica
  bool canPerformActionOnSancion(String action, SancionModel sancion) {
    return _currentUser?.canPerformActionOnSancion(action, sancion) ?? false;
  }

  /// Obtener mensaje de restricción
  String getRestrictionMessage(String action) {
    return _currentUser?.getRestrictionMessage(action) ?? 'Usuario no autenticado';
  }

  /// Verificar si puede acceder a una ruta específica
  bool canAccessRoute(String route) {
    if (_currentUser == null || !_currentUser!.isActive) return false;

    switch (route) {
      case '/admin':
        return _currentUser!.canAccessAdminPanel;
      case '/approval_panel':
        return _currentUser!.canViewApprovalPanel;
      case '/advanced_stats':
        return _currentUser!.canViewAdvancedStats;
      case '/user_management':
        return _currentUser!.hasPermission('manage_users');
      default:
        return true; // Rutas públicas
    }
  }

  /// =============================================
  /// 📊 INFORMACIÓN DEL SISTEMA
  /// =============================================

  /// Obtener información del proveedor
  Map<String, dynamic> getProviderInfo() {
    return {
      'provider_name': 'AuthProvider',
      'current_user': _currentUser?.toMap(),
      'is_authenticated': isLoggedIn,
      'user_role': _currentUser?.role,
      'user_permissions': _currentUser?.rolePermissions,
      'available_actions': _currentUser?.availableActions,
      'version': '2.0.0', // 🆕 Actualizada
    };
  }

  /// =============================================
  /// 🛠️ MÉTODOS PRIVADOS
  /// =============================================

  /// Establecer estado de carga
  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  /// Establecer error
  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  /// Limpiar error
  void _clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Obtener mensaje de error amigable
  String _getAuthErrorMessage(String errorMessage) {
    if (errorMessage.contains('Invalid login credentials')) {
      return 'Credenciales incorrectas. Verifica tu email y contraseña.';
    }
    if (errorMessage.contains('Email not confirmed')) {
      return 'Debes confirmar tu email antes de iniciar sesión.';
    }
    if (errorMessage.contains('Too many requests')) {
      return 'Demasiados intentos. Espera unos minutos antes de intentar nuevamente.';
    }
    
    return 'Error de autenticación: $errorMessage';
  }

  /// =============================================
  /// 🎮 MÉTODOS PARA TESTING Y DEBUG
  /// =============================================

  /// Simular usuario para testing (solo en debug)
  void setMockUser(UserModel mockUser) {
    if (kDebugMode) {
      _currentUser = mockUser;
      notifyListeners();
      print('🎭 Usuario simulado establecido: ${mockUser.fullName} (${mockUser.role})');
    }
  }

  /// Limpiar usuario simulado
  void clearMockUser() {
    if (kDebugMode) {
      _currentUser = null;
      notifyListeners();
      print('🎭 Usuario simulado limpiado');
    }
  }

  /// Obtener resumen de permisos para debug
  String getPermissionsSummary() {
    if (_currentUser == null) return 'No hay usuario autenticado';

    final buffer = StringBuffer();
    buffer.writeln('📋 RESUMEN DE PERMISOS - ${_currentUser!.fullName}');
    buffer.writeln('🎭 Rol: ${_currentUser!.roleDescription}');
    buffer.writeln('🟢 Estado: ${_currentUser!.isActive ? 'Activo' : 'Inactivo'}');
    buffer.writeln('');
    buffer.writeln('🔐 PERMISOS:');
    
    final permissions = _currentUser!.rolePermissions;
    permissions.forEach((permission, hasPermission) {
      final icon = hasPermission ? '✅' : '❌';
      buffer.writeln('  $icon $permission');
    });
    
    buffer.writeln('');
    buffer.writeln('🎯 ACCIONES DISPONIBLES:');
    final actions = _currentUser!.availableActions;
    for (var action in actions) {
      buffer.writeln('  • $action');
    }
    
    return buffer.toString();
  }
}