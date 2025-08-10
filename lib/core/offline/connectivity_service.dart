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
      final result = await connectivity.checkConnectivity();
      _updateConnectionStatus(result);
      connectivity.onConnectivityChanged.listen(_updateConnectionStatus);
      _isInitialized = true;
      print('📡 ConnectivityService inicializado en móvil');
    } catch (e) {
      print('⚠️ Error inicializando conectividad: $e');
      _isConnected = true;
    }
  }

  void _updateConnectionStatus(ConnectivityResult result) {
    if (kIsWeb) return;
    
    final wasConnected = _isConnected;
    _isConnected = result != ConnectivityResult.none;
    
    if (wasConnected != _isConnected) {
      print('📡 Conectividad cambió: ${_isConnected ? "🟢 ONLINE" : "🔴 OFFLINE"}');
      _connectionController?.add(_isConnected);
    }
  }

  Future<bool> checkRealConnection() async {
    if (kIsWeb) return true;
    
    try {
      final connectivity = Connectivity();
      final result = await connectivity.checkConnectivity();
      return result != ConnectivityResult.none;
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