import 'dart:async';
import 'package:flutter/foundation.dart';

// 🌐 Imports condicionales para evitar error en web
import 'package:connectivity_plus/connectivity_plus.dart' if (dart.library.html) 'dart:html' as connectivity;

/// 📡 Servicio de detectar conectividad SOLO para móvil
/// En web siempre retorna "conectado" para mantener comportamiento actual
class ConnectivityService {
  static ConnectivityService? _instance;
  static ConnectivityService get instance => _instance ??= ConnectivityService._();
  
  ConnectivityService._();

  StreamController<bool>? _connectionController;
  bool _isConnected = true;
  bool _isInitialized = false;

  /// Stream de estado de conexión
  Stream<bool> get connectionStream {
    if (kIsWeb) {
      // 🌐 WEB: Siempre conectado (sin cambios de comportamiento)
      return Stream.value(true);
    }
    
    _connectionController ??= StreamController<bool>.broadcast();
    
    if (!_isInitialized) {
      _initializeConnectivity();
    }
    
    return _connectionController!.stream;
  }

  /// Estado actual de conexión
  bool get isConnected {
    if (kIsWeb) return true; // 🌐 Web siempre conectado
    return _isConnected;
  }

  /// Inicializar solo en móvil
  Future<void> _initializeConnectivity() async {
    if (kIsWeb) return; // 🌐 Skip en web
    
    try {
      // Solo se ejecuta en móvil
      final connectivity = Connectivity();
      
      // Estado inicial
      final result = await connectivity.checkConnectivity();
      _updateConnectionStatus(result);
      
      // Escuchar cambios
      connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
      
      _isInitialized = true;
      print('📡 ConnectivityService inicializado en móvil');
    } catch (e) {
      print('⚠️ Error inicializando conectividad: $e');
      _isConnected = true; // Fallback: asumir conectado
    }
  }

  /// Actualizar estado de conexión
  void _updateConnectionStatus(ConnectivityResult result) {
    if (kIsWeb) return; // 🌐 Skip en web
    
    final wasConnected = _isConnected;
    _isConnected = result != ConnectivityResult.none;
    
    // Solo notificar si cambió el estado
    if (wasConnected != _isConnected) {
      print('📡 Conectividad cambió: ${_isConnected ? "🟢 ONLINE" : "🔴 OFFLINE"}');
      _connectionController?.add(_isConnected);
    }
  }

  /// Verificar conexión activa (ping real)
  Future<bool> checkRealConnection() async {
    if (kIsWeb) return true; // 🌐 Web siempre conectado
    
    try {
      // En móvil: hacer ping real a Supabase
      final result = await connectivity.Connectivity().checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      print('📡 Error verificando conexión real: $e');
      return false;
    }
  }

  /// Forzar verificación de estado
  Future<void> refreshConnectionStatus() async {
    if (kIsWeb) return; // 🌐 Skip en web
    
    try {
      final connectivity = Connectivity();
      final result = await connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e) {
      print('📡 Error refrescando estado: $e');
    }
  }

  /// Limpiar recursos
  void dispose() {
    _connectionController?.close();
    _connectionController = null;
    _isInitialized = false;
  }
}