// connectivity_service.dart - VERSIÓN CORREGIDA
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

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
      // 🔥 CAMBIO: checkConnectivity ahora retorna List<ConnectivityResult>
      final results = await connectivity.checkConnectivity();
      _updateConnectionStatus(results);
      
      // 🔥 CAMBIO: onConnectivityChanged ahora emite List<ConnectivityResult>
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

  // 🔥 CAMBIO: Actualizar para manejar List<ConnectivityResult>
  void _updateConnectionStatus(List<ConnectivityResult> results) {
    if (kIsWeb) return;
    
    final wasConnected = _isConnected;
    
    // Verificar si hay alguna conexión activa
    _isConnected = results.contains(ConnectivityResult.wifi) ||
                   results.contains(ConnectivityResult.mobile) ||
                   results.contains(ConnectivityResult.ethernet) ||
                   results.contains(ConnectivityResult.vpn) ||
                   results.contains(ConnectivityResult.bluetooth) ||
                   results.contains(ConnectivityResult.other);
    
    // Solo está offline si contiene none
    if (results.contains(ConnectivityResult.none)) {
      _isConnected = false;
    }
    
    if (wasConnected != _isConnected) {
      print('📡 Conectividad cambió: ${_isConnected ? "🟢 ONLINE" : "🔴 OFFLINE"}');
      print('   Tipos de conexión: $results');
      _connectionController?.add(_isConnected);
    }
  }

  Future<bool> checkRealConnection() async {
    if (kIsWeb) return true;
    
    try {
      final connectivity = Connectivity();
      // 🔥 CAMBIO: Manejar List<ConnectivityResult>
      final results = await connectivity.checkConnectivity();
      
      final hasConnection = !results.contains(ConnectivityResult.none) &&
                           (results.contains(ConnectivityResult.wifi) ||
                            results.contains(ConnectivityResult.mobile) ||
                            results.contains(ConnectivityResult.ethernet));
      
      print('📡 Verificación de conexión: $results -> ${hasConnection ? "ONLINE" : "OFFLINE"}');
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