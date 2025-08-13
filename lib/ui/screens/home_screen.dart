import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/offline/sancion_repository.dart';
import '../../core/offline/empleado_repository.dart';
import '../../core/offline/connectivity_service.dart';
import '../../core/offline/offline_manager.dart';
import '../../core/models/sancion_model.dart'; // ✅ AGREGADO: Import del modelo
import 'create_sancion_screen.dart';
import 'historial_sanciones_screen.dart';

/// Pantalla principal después del login
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Repositories
  final SancionRepository _sancionRepository = SancionRepository.instance;
  final EmpleadoRepository _empleadoRepository = EmpleadoRepository.instance;

  Map<String, dynamic> _stats = {};
  Map<String, int> _empleadoStats = {};
  bool _isLoading = true;
  bool _isOnline = true;
  StreamSubscription<bool>? _connectivitySubscription;

  // Variable para test de persistencia
  String? _lastTestValue;

  @override
  void initState() {
    super.initState();
    _loadData();
    _listenToConnectivity();
    if (kDebugMode) {
      _loadTestValue(); // Solo cargar en debug
    }
  }

  // ✅ AGREGADO: Listener para recargar cuando regrese de otras pantallas
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Solo recargar si no es la primera vez (evitar doble carga inicial)
    if (!_isLoading) {
      print('🔄 didChangeDependencies: Recargando estadísticas...');
      _loadEstadisticas();
    }
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  // Cargar valor de test anterior
  Future<void> _loadTestValue() async {
    if (kIsWeb) return;

    try {
      final box = await Hive.openBox('test_persistence');
      final value = box.get('test_key');
      if (value != null && mounted) {
        setState(() => _lastTestValue = value);
        print('🔍 Valor de test anterior encontrado: $value');
      }
    } catch (e) {
      print('❌ Error cargando valor de test: $e');
    }
  }

  // Escuchar cambios en la conectividad
  void _listenToConnectivity() {
    if (kIsWeb) return;

    _connectivitySubscription =
        ConnectivityService.instance.connectionStream.listen((isConnected) {
      if (mounted) {
        setState(() => _isOnline = isConnected);

        // Si volvemos online, intentar sincronizar
        if (isConnected && !_isOnline) {
          _syncPendingData();
        }
      }
    });
  }

  // Sincronizar datos pendientes
  Future<void> _syncPendingData() async {
    try {
      final offlineManager = OfflineManager.instance;
      final stats = offlineManager.getOfflineStats();
      final pendingCount = stats['pending_sync'] ?? 0;

      if (pendingCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Text('Sincronizando $pendingCount sanciones pendientes...'),
              ],
            ),
            backgroundColor: Colors.blue,
            duration: const Duration(seconds: 3),
          ),
        );

        final success = await offlineManager.syncNow();
        if (success) {
          await _loadData(); // Recargar estadísticas

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('✅ Sincronización completada'),
                backgroundColor: Colors.green,
              ),
            );
          }
        }
      }
    } catch (e) {
      print('❌ Error sincronizando: $e');
    }
  }

  // ✅ REEMPLAZAR COMPLETAMENTE el método _loadData()
  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser!;

      print('📊 Cargando datos para ${user.role} (${user.fullName})...');

      // ✅ LÓGICA CORREGIDA ESPECÍFICA POR ROL
      if (user.isSupervisor) {
        // ✅ SUPERVISOR: Usar método especial que carga solo SUS sanciones
        _stats = await _calcularEstadisticasParaRol(user.role);
      } else {
        // ✅ GERENCIA/RRHH: Usar método que carga todas las sanciones del sistema
        _stats = await _calcularEstadisticasParaRol(user.role);
      }

      _empleadoStats = await _empleadoRepository.getEstadisticasEmpleados();

      // Actualizar estado de conectividad
      _isOnline = ConnectivityService.instance.isConnected;
      
      print('📊 Estadísticas cargadas para ${user.role}:');
      print('   - Enviadas: ${_stats['enviadas']}');
      print('   - Aprobadas: ${_stats['aprobadas']}');
      print('   - Pendientes: ${_stats['pendientes']}');
      print('   - Alcance: ${_stats['alcance']}');
    } catch (e) {
      print('❌ Error cargando datos: $e');

      // Si hay error, probablemente estamos offline
      if (e.toString().contains('SocketException') ||
          e.toString().contains('Failed host lookup')) {
        setState(() => _isOnline = false);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // ✅ REEMPLAZAR COMPLETAMENTE el método _loadEstadisticas()
  Future<void> _loadEstadisticas() async {
    try {
      print('📊 Recargando estadísticas...');
      
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser!;

      // ✅ LÓGICA UNIFICADA: Todos los roles usan el método corregido
      Map<String, dynamic> newStats = await _calcularEstadisticasParaRol(user.role);
      final newEmpleadoStats = await _empleadoRepository.getEstadisticasEmpleados();

      if (mounted) {
        setState(() {
          _stats = newStats;
          _empleadoStats = newEmpleadoStats;
        });
        
        print('✅ Estadísticas actualizadas para ${user.role}:');
        print('   - Enviadas: ${_stats['enviadas']}');
        print('   - Aprobadas: ${_stats['aprobadas']}');
        print('   - Pendientes: ${_stats['pendientes']} ← ${_stats['descripcion_pendientes']}');
        print('   - Alcance: ${_stats['alcance']}');
      }
    } catch (e) {
      print('❌ Error recargando estadísticas: $e');
    }
  }

  // ✅ CORREGIR: Método para calcular estadísticas - SUPERVISOR ESPECÍFICO
  Future<Map<String, dynamic>> _calcularEstadisticasParaRol(String role) async {
    print('🎯 Calculando estadísticas específicas para rol: $role');

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser!;

    // ✅ DIFERENCIAL CRÍTICO: Supervisor vs Gerencia/RRHH
    List<SancionModel> sanciones;
    
    if (user.isSupervisor) {
      // ✅ SUPERVISOR: Solo SUS propias sanciones
      sanciones = await _sancionRepository.getMySanciones(user.id);
      print('👤 SUPERVISOR: Cargando solo mis sanciones (${sanciones.length})');
    } else {
      // ✅ GERENCIA/RRHH: Todas las sanciones del sistema
      sanciones = await _sancionRepository.getAllSanciones();
      print('🏢 ${role.toUpperCase()}: Cargando todas las sanciones (${sanciones.length})');
    }

    // Contadores base
    int borradores = 0;
    int enviadas = 0;
    int aprobadas = 0;
    int rechazadas = 0;
    int procesadas = 0;
    int anuladas = 0;

    // Contar por status
    for (var sancion in sanciones) {
      switch (sancion.status.toLowerCase()) {
        case 'borrador':
          borradores++;
          break;
        case 'enviado':
          enviadas++;
          break;
        case 'aprobado':
          aprobadas++;
          break;
        case 'rechazado':
          rechazadas++;
          break;
        case 'procesado':
          procesadas++;
          break;
        case 'anulado':
          anuladas++;
          break;
      }
    }

    // ✅ LÓGICA ESPECÍFICA POR ROL PARA PENDIENTES
    int pendientes;
    String descripcionPendientes;
    
    switch (role.toLowerCase()) {
      case 'supervisor':
        // ✅ SUPERVISOR: Solo las ENVIADAS son pendientes para él
        // Las aprobadas ya no están bajo su control
        pendientes = enviadas;
        descripcionPendientes = 'Mis sanciones enviadas esperando aprobación';
        print('👨‍💼 SUPERVISOR - Pendientes = $pendientes (solo mis enviadas)');
        break;
        
      case 'gerencia':
        // ✅ GERENCIA: Solo las ENVIADAS (status='enviado')
        pendientes = enviadas;
        descripcionPendientes = 'Sanciones enviadas esperando mi aprobación';
        print('🏢 GERENCIA - Pendientes = $pendientes (solo enviadas del sistema)');
        break;
        
      case 'rrhh':
        // ✅ RRHH: Solo las APROBADAS (status='aprobado')
        pendientes = aprobadas;
        descripcionPendientes = 'Sanciones aprobadas esperando procesamiento';
        print('👥 RRHH - Pendientes = $pendientes (solo aprobadas del sistema)');
        break;
        
      default:
        // ✅ OTROS ROLES: Total pendientes
        pendientes = enviadas + aprobadas;
        descripcionPendientes = 'Total sanciones en proceso';
        print('🔄 OTROS - Pendientes = $pendientes (enviadas + aprobadas)');
    }

    // ✅ AGREGAR: Estadísticas adicionales para debug
    final resultado = {
      'borradores': borradores,
      'enviadas': enviadas,
      'aprobadas': aprobadas,
      'rechazadas': rechazadas,
      'procesadas': procesadas,
      'anuladas': anuladas,
      'pendientes': pendientes,
      'descripcion_pendientes': descripcionPendientes,
      'total': sanciones.length,
      
      // ✅ DEBUG: Información adicional
      'es_supervisor': user.isSupervisor,
      'alcance': user.isSupervisor ? 'Solo mis sanciones' : 'Todas las sanciones',
      'usuario_id': user.id,
    };

    print('📊 Resultado final para $role: $resultado');
    return resultado;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Banner de debug - SOLO EN MODO DESARROLLO
          if (!kIsWeb && kDebugMode) _buildOfflineDebugBanner(),

          // Contenido principal
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadEstadisticas, // ✅ CAMBIADO: usar método específico
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Banner de estado offline (producción)
                          if (!_isOnline && !kDebugMode) _buildOfflineBanner(),

                          _buildWelcomeCard(),
                          const SizedBox(height: 20),
                          _buildStatsSection(),
                          const SizedBox(height: 20),
                          _buildActionsSection(),
                          const SizedBox(height: 20),
                          _buildRecentActivity(),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
      // Solo el botón principal de Nueva Sanción
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  // Banner de debug para ver estado del sistema offline
  Widget _buildOfflineDebugBanner() {
    final offlineStats = OfflineManager.instance.getOfflineStats();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(8),
      color: Colors.grey.shade800,
      child: Row(
        children: [
          const Icon(Icons.developer_mode, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'DEBUG: ${offlineStats['mode']} | '
              'Cache: ${offlineStats['empleados_cached']} emp | '
              'Pending: ${offlineStats['pending_sync']} | '
              'Last Value: ${_lastTestValue ?? 'none'}',
              style: const TextStyle(color: Colors.white, fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }

  // Banner indicando modo offline (producción)
  Widget _buildOfflineBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.wifi_off, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Modo Offline',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const Text(
                  'Los cambios se sincronizarán cuando haya conexión',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange,
                  ),
                ),
                FutureBuilder<Map<String, dynamic>>(
                  future:
                      Future.value(OfflineManager.instance.getOfflineStats()),
                  builder: (context, snapshot) {
                    if (snapshot.hasData &&
                        (snapshot.data!['pending_sync'] ?? 0) > 0) {
                      return Text(
                        '${snapshot.data!['pending_sync']} sanciones pendientes de sincronizar',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.orange),
            onPressed: _loadEstadisticas, // ✅ CAMBIADO: usar método específico
            tooltip: 'Intentar reconectar',
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const FittedBox(
        fit: BoxFit.scaleDown,
        child: Text('Sistema de Sanciones - INSEVIG'),
      ),
      backgroundColor: const Color(0xFF1E3A8A),
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        // Icono de sincronización manual
        if (!kIsWeb)
          IconButton(
            icon: const Icon(Icons.sync),
            onPressed: _syncPendingData,
            tooltip: 'Sincronizar ahora',
          ),
        // ✅ BOTÓN DE REFRESH MANUAL MEJORADO
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadEstadisticas, // ✅ CAMBIADO: usar método específico
          tooltip: 'Actualizar estadísticas',
        ),
        // Menú con más opciones
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: _handleMenuSelection,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: [
                  Icon(Icons.refresh, size: 20),
                  SizedBox(width: 8),
                  Text('Actualizar'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.person, size: 20),
                  SizedBox(width: 8),
                  Text('Mi Perfil'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'configuracion',
              child: Row(
                children: [
                  Icon(Icons.settings, size: 20),
                  SizedBox(width: 8),
                  Text('Configuración'),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'logout',
              child: Row(
                children: [
                  Icon(Icons.logout, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Cerrar Sesión', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWelcomeCard() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.currentUser!;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white.withOpacity(0.2),
                child: Text(
                  user.initials,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Información del usuario
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bienvenido/a',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      user.fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${user.roleEmoji} ${user.roleDescription}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                    if (user.department != null)
                      Text(
                        user.department!,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ✅ CORREGIR: Widget de estadísticas - LAYOUT ESPECÍFICO POR ROL
  Widget _buildStatsSection() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser!;
    final isGerencia = user.role.toLowerCase() == 'gerencia';
    final isSupervisor = user.isSupervisor;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Estadísticas',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            // ✅ BOTÓN DEBUG MEJORADO
            if (kDebugMode)
              IconButton(
                icon: const Icon(Icons.info_outline, size: 20),
                onPressed: _mostrarDebugEstadisticas,
                tooltip: 'Debug estadísticas',
              ),
          ],
        ),
        const SizedBox(height: 12),

        // ✅ LAYOUT ESPECÍFICO POR ROL
        if (isSupervisor) ...[
          // ✅ LAYOUT PARA SUPERVISOR
          Row(
            children: [
              Expanded(
                  child: _buildStatCard('📝', 'Borradores',
                      _stats['borradores'] ?? 0, Colors.orange)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildStatCard('📤', 'Enviadas',
                      _stats['enviadas'] ?? 0, Colors.blue)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _buildStatCard('✅', 'Aprobadas',
                      _stats['aprobadas'] ?? 0, Colors.green)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildStatCard('⚠️', 'Esperando', // ✅ SUPERVISOR: "Esperando" aprobación
                      _stats['pendientes'] ?? 0, Colors.amber)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _buildStatCard('❌', 'Rechazadas',
                      _stats['rechazadas'] ?? 0, Colors.red)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildStatCard('👥', 'Empleados',
                      _empleadoStats['total'] ?? 0, Colors.indigo)),
            ],
          ),
        ] else if (isGerencia) ...[
          // ✅ LAYOUT PARA GERENCIA
          Row(
            children: [
              Expanded(
                  child: _buildStatCard('📝', 'Borradores',
                      _stats['borradores'] ?? 0, Colors.orange)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildStatCard('⚠️', 'Por Aprobar', // ✅ GERENCIA: "Por Aprobar"
                      _stats['pendientes'] ?? 0, Colors.amber)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _buildStatCard('✅', 'Aprobadas',
                      _stats['aprobadas'] ?? 0, Colors.green)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildStatCard('❌', 'Rechazadas',
                      _stats['rechazadas'] ?? 0, Colors.red)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _buildStatCard('✅', 'Procesadas',
                      _stats['procesadas'] ?? 0, Colors.green.shade300)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildStatCard('👥', 'Empleados',
                      _empleadoStats['total'] ?? 0, Colors.indigo)),
            ],
          ),
        ] else ...[
          // ✅ LAYOUT PARA RRHH Y OTROS
          Row(
            children: [
              Expanded(
                  child: _buildStatCard('📝', 'Borradores',
                      _stats['borradores'] ?? 0, Colors.orange)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildStatCard('📤', 'Enviadas',
                      _stats['enviadas'] ?? 0, Colors.blue)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _buildStatCard('✅', 'Aprobadas',
                      _stats['aprobadas'] ?? 0, Colors.green)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildStatCard('❌', 'Rechazadas',
                      _stats['rechazadas'] ?? 0, Colors.red)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _buildStatCard('⚠️', _getTituloPendientes(),
                      _stats['pendientes'] ?? 0, Colors.amber)),
              const SizedBox(width: 12),
              Expanded(
                  child: _buildStatCard('👥', 'Empleados',
                      _empleadoStats['total'] ?? 0, Colors.indigo)),
            ],
          ),
        ],
      ],
    );
  }

  // ✅ NUEVO: Título dinámico para pendientes según rol
  String _getTituloPendientes() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final role = authProvider.currentUser?.role ?? '';
    
    switch (role.toLowerCase()) {
      case 'gerencia':
        return 'Por Aprobar'; // ✅ Más claro para gerencia
      case 'rrhh':
        return 'Por Procesar';
      case 'supervisor':
        return 'Esperando'; // ✅ CORREGIDO: Solo las enviadas esperando aprobación
      default:
        return 'Pendientes';
    }
  }

  Widget _buildStatCard(String emoji, String label, int count, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 8),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActionsSection() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.currentUser!;

        // Detectar si es móvil o web
        final isMobile = MediaQuery.of(context).size.width < 600;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Acciones Rápidas',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(height: 12),

            // Grid adaptativo
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: isMobile ? 1.3 : 1.5,
              children: [
                if (user.canCreateSanciones)
                  _buildActionCard(
                    '📝',
                    'Nueva Sanción',
                    'Registrar sanción',
                    () => _createNewSancion(),
                  ),
                _buildActionCard(
                  '📋',
                  'Ver Historial',
                  'Sanciones anteriores',
                  () => _viewHistory(),
                ),
                if (user.canViewAllSanciones)
                  _buildActionCard(
                    '📊',
                    'Reportes',
                    'Generar reportes',
                    () => _viewReports(),
                  ),
                _buildActionCard(
                  '👥',
                  'Empleados',
                  'Buscar empleados',
                  () => _searchEmployees(),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionCard(
      String emoji, String title, String subtitle, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 28),
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 2),
            Flexible(
              child: Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Actividad Reciente',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A8A),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'Próximamente se mostrarán las últimas sanciones registradas',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFloatingActionButton() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (!authProvider.currentUser!.canCreateSanciones) {
          return const SizedBox.shrink();
        }

        return FloatingActionButton.extended(
          onPressed: _createNewSancion,
          backgroundColor: const Color(0xFF1E3A8A),
          label: const Text('Nueva Sanción'),
          icon: const Icon(Icons.add),
        );
      },
    );
  }

  // Acciones de la interfaz
  void _createNewSancion() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const CreateSancionScreen(),
      ),
    ).then((result) {
      if (result == true) {
        print('🔄 Regresó de crear sanción, recargando estadísticas...');
        _loadEstadisticas(); // ✅ CAMBIADO: usar método específico
      }
    });
  }

  // ✅ MÉTODO CRÍTICO MODIFICADO: Navegación al historial con recarga
  void _viewHistory() {
    print('🔄 Navegando al historial...');
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HistorialSancionesScreen(),
      ),
    ).then((_) {
      // ✅ AGREGADO: Recargar estadísticas al volver del historial
      print('🔄 Regresó del historial, recargando estadísticas...');
      _loadEstadisticas();
    });
  }

  void _viewReports() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🚧 Reportes - Próximamente'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _searchEmployees() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🚧 Búsqueda de empleados - Próximamente'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'refresh':
        _loadEstadisticas(); // ✅ CAMBIADO: usar método específico
        break;
      case 'profile':
        _showProfile();
        break;
      case 'configuracion':
        _mostrarConfiguracion();
        break;
      case 'logout':
        _logout();
        break;
    }
  }

  // Método para mostrar la configuración
  void _mostrarConfiguracion() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Configuración'),
            backgroundColor: const Color(0xFF1E3A8A),
          ),
          body: ListView(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Herramientas de Sistema',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.storage, color: Colors.orange),
                title: const Text('Estado del Cache Offline'),
                subtitle: FutureBuilder<int>(
                  future: Future.value(
                      OfflineManager.instance.database.getEmpleados().length),
                  builder: (context, snapshot) {
                    return Text('${snapshot.data ?? 0} empleados guardados');
                  },
                ),
                onTap: () {
                  Navigator.pop(context);
                  _verificarCacheDetallado();
                },
              ),
              ListTile(
                leading: const Icon(Icons.sync, color: Colors.blue),
                title: const Text('Sincronizar Datos'),
                subtitle: const Text('Forzar sincronización con servidor'),
                onTap: () async {
                  Navigator.pop(context);
                  final success = await OfflineManager.instance.syncNow();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(success
                          ? '✅ Sincronización completada'
                          : '❌ Error al sincronizar'),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                  
                  // ✅ AGREGADO: Recargar estadísticas después de sincronizar
                  if (success) {
                    _loadEstadisticas();
                  }
                },
              ),
              if (kDebugMode) ...[
                const Divider(),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Herramientas de Desarrollo',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.bug_report, color: Colors.purple),
                  title: const Text('Test Modo Offline'),
                  subtitle: const Text('Verificar funcionamiento offline'),
                  onTap: () {
                    Navigator.pop(context);
                    _runOfflineTest();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.save, color: Colors.orange),
                  title: const Text('Test de Persistencia'),
                  subtitle: const Text('Verificar guardado de datos'),
                  onTap: () {
                    Navigator.pop(context);
                    _testPersistence();
                  },
                ),
              ],
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Información',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('Acerca de'),
                subtitle: const Text('Sistema de Sanciones v1.0.0'),
                trailing:
                    const Text('INSEVIG', style: TextStyle(color: Colors.grey)),
              ),
              ListTile(
                leading: const Icon(Icons.developer_mode),
                title: const Text('Desarrollado por'),
                subtitle: const Text('Pereira Systems'),
                trailing:
                    const Text('2025', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      // ✅ AGREGADO: Recargar al volver de configuración
      print('🔄 Regresó de configuración, recargando estadísticas...');
      _loadEstadisticas();
    });
  }

  void _showProfile() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser!;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mi Perfil'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nombre: ${user.fullName}'),
            Text('Email: ${user.email}'),
            Text('Rol: ${user.roleDescription}'),
            if (user.department != null)
              Text('Departamento: ${user.department}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  // ✅ ACTUALIZAR: Debug con más detalles
  void _mostrarDebugEstadisticas() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser!;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.bug_report, color: Colors.purple),
            SizedBox(width: 8),
            Text('Debug Estadísticas'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Usuario: ${user.fullName}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('Rol: ${user.role}'),
                    Text('Es supervisor: ${user.isSupervisor}'),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              const Text(
                'Estadísticas mostradas:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              
              ..._stats.entries.where((e) => e.key != 'descripcion_pendientes').map((entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${entry.key}:'),
                    Text(
                      '${entry.value}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              )),
              
              const SizedBox(height: 12),
              
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.amber),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '⚠️ Lógica de "Pendientes":',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _stats['descripcion_pendientes'] ?? 'No definida',
                      style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _loadEstadisticas(); // Recargar
            },
            child: const Text('Recargar'),
          ),
        ],
      ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<AuthProvider>(context, listen: false).signOut();
              Navigator.pushReplacementNamed(context, '/login');
            },
            child: const Text('Cerrar Sesión',
                style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // Test de persistencia
  Future<void> _testPersistence() async {
    if (kIsWeb) return;

    try {
      final testId = 'test_${DateTime.now().millisecondsSinceEpoch}';

      final box = await Hive.openBox('test_persistence');
      await box.put('test_key', testId);
      await box.flush();

      print('✅ Guardado: $testId');

      final saved = box.get('test_key');
      print('📖 Leído inmediatamente: $saved');

      setState(() => _lastTestValue = testId);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('🧪 Test de Persistencia'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Prueba de persistencia Hive:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('💾 Nuevo valor guardado:\n$testId'),
              const SizedBox(height: 8),
              if (_lastTestValue != null && _lastTestValue != testId)
                Text('📖 Valor anterior:\n$_lastTestValue',
                    style: const TextStyle(color: Colors.green)),
              const SizedBox(height: 16),
              const Text(
                '🔄 Cierra completamente la app y vuelve a abrir para verificar que el valor persiste.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await box.delete('test_key');
                await box.flush();
                setState(() => _lastTestValue = null);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🧹 Valor de test eliminado'),
                    backgroundColor: Colors.orange,
                  ),
                );
              },
              child: const Text('Limpiar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('❌ Error en test de persistencia: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Método para test offline
  Future<void> _runOfflineTest() async {
    print('\n🧪 TEST MODO OFFLINE:');

    final offline = OfflineManager.instance;
    print('📊 Stats: ${offline.getOfflineStats()}');

    final connectivity = ConnectivityService.instance;
    print('📡 Conectividad: ${connectivity.isConnected}');

    print('\n🔍 Probando búsqueda offline...');
    try {
      final empleados = await _empleadoRepository.searchEmpleados('a');
      print('✅ Resultados: ${empleados.length} empleados');
      if (empleados.isNotEmpty) {
        print(
            '   Primeros 3: ${empleados.take(3).map((e) => e.displayName).join(", ")}');
      }
    } catch (e) {
      print('❌ Error en búsqueda: $e');
    }

    final db = offline.database;
    final cached = db.getEmpleados();
    print('\n💾 En cache local:');
    print('   - Total: ${cached.length}');
    if (cached.isNotEmpty) {
      print(
          '   - Primeros 3: ${cached.take(3).map((e) => e.displayName).join(", ")}');
    }

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('🧪 Test Offline'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('📦 Cache: ${cached.length} empleados'),
                Text(
                    '🔍 Búsqueda "a": ${cached.where((e) => e.displayName.toLowerCase().contains('a')).length} resultados'),
                Text(
                    '📡 Conectividad: ${connectivity.isConnected ? "ONLINE" : "OFFLINE"}'),
                const Divider(),
                const Text('Estadísticas completas:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...offline.getOfflineStats().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('${e.key}: ${e.value}',
                          style: const TextStyle(fontSize: 12)),
                    )),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                _verificarCacheDetallado();
                Navigator.pop(context);
              },
              child: const Text('Ver más detalles'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    }
  }

  // Método de verificación detallada
  void _verificarCacheDetallado() {
    final offline = OfflineManager.instance;

    print('\n📊 VERIFICACIÓN DETALLADA DEL CACHE:');
    print('╔═══════════════════════════════════════╗');

    final todosEmpleados = offline.database.getEmpleados();
    print('📦 Total empleados en cache: ${todosEmpleados.length}');

    print('\n👥 Primeros 5 empleados en cache:');
    todosEmpleados.take(5).forEach((emp) {
      print('   ${emp.cod} - ${emp.displayName} - ${emp.nomdep ?? "Sin dept"}');
    });

    print('\n🔍 Búsqueda manual de "vera":');
    final testVera = offline.database.searchEmpleados('vera');
    print('   Encontrados: ${testVera.length}');
    if (testVera.isNotEmpty) {
      testVera.take(3).forEach((emp) {
        print(
            '   ✓ ${emp.displayName} (${emp.cod}) - ${emp.nomcargo ?? "Sin cargo"}');
      });
    }

    print('\n🔍 Búsqueda manual de "zambrano":');
    final testZambrano = offline.database.searchEmpleados('zambrano');
    print('   Encontrados: ${testZambrano.length}');
    if (testZambrano.isNotEmpty) {
      testZambrano.take(3).forEach((emp) {
        print('   ✓ ${emp.displayName} (${emp.cod})');
      });
    }

    print('\n📈 Estadísticas del cache:');
    final stats = offline.getOfflineStats();
    stats.forEach((key, value) {
      print('   $key: $value');
    });

    print('╚═══════════════════════════════════════╝\n');

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Cache verificado: ${todosEmpleados.length} empleados\n'
          'Búsqueda "vera": ${testVera.length} resultados\n'
          'Ver consola para detalles completos',
        ),
        duration: const Duration(seconds: 4),
        backgroundColor: Colors.blue,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }
}