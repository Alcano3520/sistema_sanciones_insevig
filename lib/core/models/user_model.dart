import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/user_model.dart';

/// Provider para manejar autenticación y estado del usuario
/// Corregido para usar la tabla 'profiles' correctamente
class AuthProvider with ChangeNotifier {
  final SupabaseClient _supabase = SupabaseConfig.client;

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;
  bool _isInitialized = false;

  // Getters
  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _currentUser != null;
  bool get isInitialized => _isInitialized;

  AuthProvider() {
    _initialize();
  }

  /// Inicializar el provider verificando sesión existente
  Future<void> _initialize() async {
    try {
      _setLoading(true);

      // Verificar si hay sesión activa
      final session = _supabase.auth.currentSession;

      if (session != null) {
        await _loadUserProfile(session.user.id);
      }

      // Escuchar cambios de autenticación
      _supabase.auth.onAuthStateChange.listen((data) {
        final event = data.event;
        final session = data.session;

        switch (event) {
          case AuthChangeEvent.signedIn:
            if (session?.user != null) {
              _loadUserProfile(session!.user.id);
            }
            break;
          case AuthChangeEvent.signedOut:
            _currentUser = null;
            notifyListeners();
            break;
          default:
            break;
        }
      });

      _isInitialized = true;
    } catch (e) {
      _setError('Error inicializando autenticación: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Cargar perfil del usuario desde la tabla PROFILES (no usuarios)
  Future<void> _loadUserProfile(String userId) async {
    try {
      print('🔍 Cargando perfil para usuario ID: $userId');
      
      // ✅ CORREGIDO: Usar 'profiles' en lugar de 'usuarios'
      final profileData = await _supabase
          .from('profiles')  // ✅ Tabla correcta
          .select('*')
          .eq('id', userId)
          .single();

      // ✅ USAR fromMap (más simple que fromSupabase)
      _currentUser = UserModel.fromMap(profileData);
      _clearError();
      notifyListeners();

      print('✅ Usuario cargado: ${_currentUser?.fullName} (${_currentUser?.role})');
    } catch (e) {
      print('❌ Error cargando perfil desde PROFILES: $e');
      _setError('Error cargando perfil del usuario');
    }
  }

  /// Iniciar sesión con email y contraseña
  Future<bool> signIn(String email, String password) async {
    try {
      _setLoading(true);
      _clearError();

      print('🔑 Intentando login con: $email');

      // 1. Autenticar con Supabase Auth
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      if (response.user != null) {
        // 2. ✅ CORREGIDO: Cargar datos desde 'profiles'
        await _loadUserProfile(response.user!.id);
        print('✅ Login exitoso para: ${_currentUser?.fullName}');
        return true;
      } else {
        _setError('Error en las credenciales');
        return false;
      }
    } on AuthException catch (e) {
      print('❌ AuthException: ${e.message}');
      _setError(_getAuthErrorMessage(e.message));
      return false;
    } catch (e) {
      print('❌ Error general en signIn: $e');
      _setError('Error de conexión: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Registrar nuevo usuario (para administradores)
  Future<bool> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? department,
  }) async {
    try {
      _setLoading(true);
      _clearError();

      print('📝 Registrando usuario: $email');

      // 1. Crear usuario en Supabase Auth
      final response = await _supabase.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
      );

      if (response.user != null) {
        // 2. ✅ CORREGIDO: Crear perfil en la tabla 'profiles'
        await _supabase.from('profiles').insert({
          'id': response.user!.id,
          'email': email.trim().toLowerCase(),
          'full_name': fullName.trim(),
          'role': role,
          'department': department?.trim(),
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        print('✅ Usuario registrado exitosamente en profiles');
        return true;
      } else {
        _setError('Error al registrar usuario');
        return false;
      }
    } on AuthException catch (e) {
      print('❌ AuthException en signUp: ${e.message}');
      _setError(_getAuthErrorMessage(e.message));
      return false;
    } catch (e) {
      print('❌ Error general en signUp: $e');
      _setError('Error registrando usuario: $e');
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
      print('👋 Sesión cerrada');
    } catch (e) {
      print('❌ Error cerrando sesión: $e');
      _setError('Error cerrando sesión: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Actualizar perfil del usuario en la tabla PROFILES
  Future<bool> updateProfile({
    String? fullName,
    String? department,
    String? avatarUrl,
  }) async {
    if (_currentUser == null) return false;

    try {
      _setLoading(true);

      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (fullName != null) updateData['full_name'] = fullName.trim();
      if (department != null) updateData['department'] = department.trim();
      if (avatarUrl != null) updateData['avatar_url'] = avatarUrl;

      // ✅ CORREGIDO: Actualizar en 'profiles'
      await _supabase
          .from('profiles')  // ✅ Tabla correcta
          .update(updateData)
          .eq('id', _currentUser!.id);

      // Recargar perfil actualizado
      await _loadUserProfile(_currentUser!.id);

      print('✅ Perfil actualizado en profiles');
      return true;
    } catch (e) {
      print('❌ Error actualizando perfil: $e');
      _setError('Error actualizando perfil: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Cambiar contraseña del usuario actual
  Future<bool> changePassword(String newPassword) async {
    try {
      _setLoading(true);
      _clearError();

      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      print('✅ Contraseña cambiada exitosamente');
      return true;
    } on AuthException catch (e) {
      print('❌ AuthException cambiando contraseña: ${e.message}');
      _setError(_getAuthErrorMessage(e.message));
      return false;
    } catch (e) {
      print('❌ Error cambiando contraseña: $e');
      _setError('Error cambiando contraseña: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Enviar email de recuperación de contraseña
  Future<bool> sendPasswordReset(String email) async {
    try {
      _setLoading(true);
      _clearError();

      await _supabase.auth.resetPasswordForEmail(email.trim().toLowerCase());

      print('✅ Email de recuperación enviado a: $email');
      return true;
    } on AuthException catch (e) {
      print('❌ AuthException en password reset: ${e.message}');
      _setError(_getAuthErrorMessage(e.message));
      return false;
    } catch (e) {
      print('❌ Error enviando email de recuperación: $e');
      _setError('Error enviando email: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Refrescar datos del usuario actual desde la base de datos
  Future<void> refreshCurrentUser() async {
    if (_currentUser != null) {
      await _loadUserProfile(_currentUser!.id);
    }
  }

  /// Verificar permisos del usuario actual
  bool hasPermission(String permission) {
    if (_currentUser == null) return false;

    switch (permission) {
      case 'create_sanciones':
        return _currentUser!.canCreateSanciones;
      case 'approve_sanciones':
        return _currentUser!.canApprove;
      case 'view_all_sanciones':
        return _currentUser!.canViewAllSanciones;
      case 'admin':
        return _currentUser!.role == 'admin';
      case 'supervisor':
        return _currentUser!.role == 'supervisor' || _currentUser!.role == 'admin';
      default:
        return false;
    }
  }

  /// Verificar si el usuario actual es administrador
  bool get isAdmin => _currentUser?.role == 'admin';

  /// Verificar si el usuario actual es supervisor
  bool get isSupervisor => _currentUser?.role == 'supervisor' || isAdmin;

  /// Métodos privados para manejo de estado
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  void _setError(String error) {
    _errorMessage = error;
    notifyListeners();
  }

  void _clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Convertir errores de Supabase a mensajes amigables en español
  String _getAuthErrorMessage(String error) {
    final errorLower = error.toLowerCase();
    
    if (errorLower.contains('invalid login credentials')) {
      return 'Email o contraseña incorrectos';
    }
    if (errorLower.contains('email not confirmed')) {
      return 'Por favor confirma tu email';
    }
    if (errorLower.contains('user not found')) {
      return 'Usuario no encontrado';
    }
    if (errorLower.contains('invalid email')) {
      return 'Email inválido';
    }
    if (errorLower.contains('password') && errorLower.contains('short')) {
      return 'La contraseña debe tener al menos 6 caracteres';
    }
    if (errorLower.contains('email') && errorLower.contains('registered')) {
      return 'Este email ya está registrado';
    }
    if (errorLower.contains('too many requests')) {
      return 'Demasiados intentos. Intenta más tarde';
    }
    if (errorLower.contains('network')) {
      return 'Error de conexión. Verifica tu internet';
    }
    
    return 'Error de autenticación: $error';
  }

  /// Obtener datos para mostrar en UI
  Map<String, dynamic> get userStats {
    if (_currentUser == null) return {};

    return {
      'name': _currentUser!.fullName,
      'role': _currentUser!.roleDescription,
      'email': _currentUser!.email,
      'department': _currentUser!.department ?? 'N/A',
      'initials': _currentUser!.initials,
      'roleEmoji': _currentUser!.roleEmoji,
      'canCreateSanciones': _currentUser!.canCreateSanciones,
      'canApprove': _currentUser!.canApprove,
      'canViewAll': _currentUser!.canViewAllSanciones,
    };
  }

  /// Limpiar errores manualmente
  void clearError() => _clearError();

  /// Verificar conexión con la base de datos
  Future<bool> testConnection() async {
    try {
      await _supabase.from('profiles').select('id').limit(1);
      return true;
    } catch (e) {
      print('❌ Error de conexión: $e');
      return false;
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}