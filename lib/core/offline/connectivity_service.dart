// connectivity_service.dart - VERSIÓN PARA API ANTIGUA
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
      
      // 🔥 API ANTIGUA: checkConnectivity retorna ConnectivityResult (no List)
      final result = await connectivity.checkConnectivity();
      _updateConnectionStatus(result);
      
      // 🔥 API ANTIGUA: onConnectivityChanged emite ConnectivityResult (no List)
      connectivity.onConnectivityChanged.listen((ConnectivityResult result) {
        _updateConnectionStatus(result);
      });
      
      _isInitialized = true;
      print('📡 ConnectivityService inicializado en móvil');
    } catch (e) {
      print('⚠️ Error inicializando conectividad: $e');
      _isConnected = true;
    }
  }

  // 🔥 PARA API ANTIGUA: Manejar ConnectivityResult simple
  void _updateConnectionStatus(ConnectivityResult result) {
    if (kIsWeb) return;
    
    final wasConnected = _isConnected;
    
    // Verificar el tipo de conexión
    _isConnected = result == ConnectivityResult.wifi ||
                   result == ConnectivityResult.mobile ||
                   result == ConnectivityResult.ethernet ||
                   result == ConnectivityResult.vpn ||
                   result == ConnectivityResult.bluetooth ||
                   result == ConnectivityResult.other;
    
    // Solo está offline si es none
    if (result == ConnectivityResult.none) {
      _isConnected = false;
    }
    
    if (wasConnected != _isConnected) {
      print('📡 Conectividad cambió: ${_isConnected ? "🟢 ONLINE" : "🔴 OFFLINE"}');
      print('   Tipo de conexión: $result');
      _connectionController?.add(_isConnected);
    }
  }

  Future<bool> checkRealConnection() async {
    if (kIsWeb) return true;
    
    try {
      final connectivity = Connectivity();
      
      // 🔥 API ANTIGUA: checkConnectivity retorna ConnectivityResult simple
      final result = await connectivity.checkConnectivity();
      
      final hasConnection = result != ConnectivityResult.none &&
                           (result == ConnectivityResult.wifi ||
                            result == ConnectivityResult.mobile ||
                            result == ConnectivityResult.ethernet);
      
      print('📡 Verificación de conexión: $result -> ${hasConnection ? "ONLINE" : "OFFLINE"}');
      return hasConnection;
    } catch (e) {
      print('📡 Error verificando conexión real: $e');
      return false;
    }
  }

  void dispose() {
    _connectionController?.close();
    _connectionController = null;
    _isInitialized = false;
  }
}