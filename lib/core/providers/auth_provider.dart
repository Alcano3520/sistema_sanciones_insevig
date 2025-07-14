import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';
import '../models/user_model.dart';

/// Provider para manejar autenticación y estado del usuario
/// Similar al sistema de login de tu app Kivy pero más robusto
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

  /// Cargar perfil del usuario desde la base de datos
  Future<void> _loadUserProfile(String userId) async {
    try {
      final response = await _supabase
          .from('profiles')
          .select('*')
          .eq('id', userId)
          .single();

      _currentUser = UserModel.fromMap(response);
      _clearError();
      notifyListeners();

      print(
          '✅ Usuario cargado: ${_currentUser?.fullName} (${_currentUser?.role})');
    } catch (e) {
      print('❌ Error cargando perfil: $e');
      _setError('Error cargando perfil del usuario');
    }
  }

  /// Iniciar sesión con email y contraseña
  Future<bool> signIn(String email, String password) async {
    try {
      _setLoading(true);
      _clearError();

      print('🔑 Intentando login con: $email');

      final response = await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      if (response.user != null) {
        await _loadUserProfile(response.user!.id);
        print('✅ Login exitoso para: ${_currentUser?.fullName}');
        return true;
      } else {
        _setError('Error en las credenciales');
        return false;
      }
    } on AuthException catch (e) {
      _setError(_getAuthErrorMessage(e.message));
      return false;
    } catch (e) {
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

      // 1. Crear usuario en Auth
      final response = await _supabase.auth.signUp(
        email: email.trim(),
        password: password,
      );

      if (response.user != null) {
        // 2. Crear perfil en la tabla profiles
        await _supabase.from('profiles').insert({
          'id': response.user!.id,
          'email': email.trim(),
          'full_name': fullName.trim(),
          'role': role,
          'department': department?.trim(),
        });

        print('✅ Usuario registrado exitosamente');
        return true;
      } else {
        _setError('Error al registrar usuario');
        return false;
      }
    } on AuthException catch (e) {
      _setError(_getAuthErrorMessage(e.message));
      return false;
    } catch (e) {
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
      _setError('Error cerrando sesión: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Actualizar perfil del usuario
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

      await _supabase
          .from('profiles')
          .update(updateData)
          .eq('id', _currentUser!.id);

      // Recargar perfil
      await _loadUserProfile(_currentUser!.id);

      print('✅ Perfil actualizado');
      return true;
    } catch (e) {
      _setError('Error actualizando perfil: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Cambiar contraseña
  Future<bool> changePassword(String newPassword) async {
    try {
      _setLoading(true);
      _clearError();

      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      print('✅ Contraseña cambiada');
      return true;
    } on AuthException catch (e) {
      _setError(_getAuthErrorMessage(e.message));
      return false;
    } catch (e) {
      _setError('Error cambiando contraseña: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Enviar email de recuperación
  Future<bool> sendPasswordReset(String email) async {
    try {
      _setLoading(true);
      _clearError();

      await _supabase.auth.resetPasswordForEmail(email.trim());

      print('✅ Email de recuperación enviado');
      return true;
    } on AuthException catch (e) {
      _setError(_getAuthErrorMessage(e.message));
      return false;
    } catch (e) {
      _setError('Error enviando email: $e');
      return false;
    } finally {
      _setLoading(false);
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
      default:
        return false;
    }
  }

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

  /// Convertir errores de Supabase a mensajes amigables
  String _getAuthErrorMessage(String error) {
    switch (error.toLowerCase()) {
      case 'invalid login credentials':
        return 'Email o contraseña incorrectos';
      case 'email not confirmed':
        return 'Por favor confirma tu email';
      case 'user not found':
        return 'Usuario no encontrado';
      case 'invalid email':
        return 'Email inválido';
      case 'password too short':
        return 'La contraseña debe tener al menos 6 caracteres';
      case 'email already registered':
        return 'Este email ya está registrado';
      default:
        return 'Error de autenticación: $error';
    }
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
    };
  }

  /// Limpiar errores manualmente
  void clearError() => _clearError();

  @override
  void dispose() {
    super.dispose();
  }
}
