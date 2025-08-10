import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// 📡 Servicio de detectar conectividad SOLO para móvil
class ConnectivityService {
  static ConnectivityService? _instance;
  static ConnectivityService get instance => _instance ??= ConnectivityService._();
  
  ConnectivityService._();

  StreamController<bool>? _connectionController;
  bool _isConnected = true;
  bool _isInitialized = false;

  Stream<bool> get connectionStream {
    if (kIsWeb) {
      return Stream.value(true);
    }
    
    _connectionController ??= StreamController<bool>.broadcast();
    
    if (!_isInitialized) {
      _initializeConnectivity();
    }
    
    return _connectionController!.stream;
  }

  bool get isConnected {
    if (kIsWeb) return true;
    return _isConnected;
  }

  Future<void> _initializeConnectivity() async {
    if (kIsWeb) return;
    
    try {
      final connectivity = Connectivity();
      
      // Verificar conexión inicial
      final List<ConnectivityResult> results = await connectivity.checkConnectivity();
      _updateConnectionStatus(results);
      
      // Escuchar cambios
      connectivity.onConnectivityChanged.listen((List<ConnectivityResult> results) {
        _updateConnectionStatus(results);
      });
      
      _isInitialized = true;
      print('📡 ConnectivityService inicializado en móvil');
    } catch (e) {
      print('⚠️ Error inicializando conectividad: $e');
      _isConnected = true;
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    if (kIsWeb) return;
    
    final wasConnected = _isConnected;
    
    // 🔥 CORREGIDO: Verificar si hay alguna conexión disponible
    _isConnected = results.any((result) => 
      result == ConnectivityResult.wifi ||
      result == ConnectivityResult.mobile ||
      result == ConnectivityResult.ethernet ||
      result == ConnectivityResult.vpn ||
      result == ConnectivityResult.bluetooth ||
      result == ConnectivityResult.other
    );
    
    // Solo notificar si cambió el estado
    if (wasConnected != _isConnected) {
      print('📡 Conectividad cambió: ${_isConnected ? "🟢 ONLINE" : "🔴 OFFLINE"}');
      print('   Tipos de conexión: ${results.map((r) => r.toString()).join(", ")}');
      _connectionController?.add(_isConnected);
    }
  }

  Future<bool> checkRealConnection() async {
    if (kIsWeb) return true;
    
    try {
      final connectivity = Connectivity();
      final List<ConnectivityResult> results = await connectivity.checkConnectivity();
      
      // 🔥 IMPORTANTE: Verificar cualquier tipo de conexión
      final hasConnection = results.any((result) => 
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.ethernet ||
        result == ConnectivityResult.vpn ||
        result == ConnectivityResult.bluetooth ||
        result == ConnectivityResult.other
      );
      
      print('📡 Conectividad real: ${results.map((r) => r.toString()).join(", ")} -> ${hasConnection ? "ONLINE" : "OFFLINE"}');
      return hasConnection;
    } catch (e) {
      print('📡 Error verificando conexión real: $e');
      return false;
    }
  }

  // 🆕 Método para forzar actualización del estado
  Future<void> forceCheck() async {
    if (kIsWeb) return;
    
    try {
      final connectivity = Connectivity();
      final results = await connectivity.checkConnectivity();
      _updateConnectionStatus(results);
    } catch (e) {
      print('📡 Error en verificación forzada: $e');
    }
  }

  void dispose() {
    _connectionController?.close();
    _connectionController = null;
    _isInitialized = false;
  }
}