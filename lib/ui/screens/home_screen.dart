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
import 'create_sancion_screen.dart';
import 'historial_sanciones_screen.dart';
import '../widgets/empleado_search_field.dart';

/// Pantalla principal después del login
/// 🔥 MEJORADA: Estadísticas por rol y manejo de pendientes
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

  /// 🔥 MEJORADO: Cargar datos con rol del usuario
  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.currentUser!;

      // 🔥 ACTUALIZADO: Pasar el rol del usuario para estadísticas correctas
      if (currentUser.isSupervisor && !currentUser.isAdmin) {
        // Supervisor normal: solo ve sus sanciones
        _stats = await _sancionRepository.getEstadisticas(
          supervisorId: currentUser.id,
          userRole: currentUser.role, // 🔥 NUEVO: Pasar el rol
        );
      } else {
        // Gerencia, RRHH, Admin: ven todas las sanciones
        _stats = await _sancionRepository.getEstadisticas(
          userRole: currentUser.role, // 🔥 NUEVO: Pasar el rol
        );
      }

      _empleadoStats = await _empleadoRepository.getEstadisticasEmpleados();

      // Actualizar estado de conectividad
      _isOnline = ConnectivityService.instance.isConnected;

      // 🔥 NUEVO: Log para debug
      print('📊 Estadísticas cargadas para ${currentUser.role}:');
      print('   Pendientes: ${_stats['pendientes']}');
      print('   Enviadas: ${_stats['enviadas']}');
      print('   Aprobadas: ${_stats['aprobadas']}');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Banner de debug - SOLO EN MODO DESARROLLO
          //if (!kIsWeb && kDebugMode) _buildOfflineDebugBanner(),

          // Contenido principal
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _loadData,
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
            onPressed: _loadData,
            tooltip: 'Intentar reconectar',
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: FittedBox(
        fit: BoxFit.scaleDown,
        child: const Text('Sistema de Sanciones - INSEVIG'),
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

  /// 🔥 MEJORADO: Widget de estadísticas con tooltips y ayuda por rol
  Widget _buildStatsSection() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.currentUser!;

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
                // 🔥 NUEVO: Botón de ayuda
                IconButton(
                  icon: const Icon(Icons.help_outline, size: 20),
                  color: Colors.grey,
                  onPressed: () => _showStatsHelp(user.role),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Estadísticas de sanciones
            Row(
              children: [
                Expanded(
                    child: _buildStatCard('📋', 'Borradores',
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
                    child: _buildStatCardWithTooltip(
                        '⚠️',
                        _getPendientesLabel(user.role),
                        _stats['pendientes'] ?? 0,
                        Colors.amber,
                        _getPendientesTooltip(user.role))),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildStatCard('👥', 'Empleados',
                        _empleadoStats['total'] ?? 0, Colors.indigo)),
              ],
            ),
          ],
        );
      },
    );
  }

  // 🔥 NUEVO: Obtener etiqueta de pendientes según rol
  String _getPendientesLabel(String role) {
    switch (role) {
      case 'supervisor':
        return 'Por Corregir';
      case 'gerencia':
        return 'Por Aprobar';
      case 'rrhh':
        return 'Por Revisar';
      default:
        return 'Pendientes';
    }
  }

  // 🔥 NUEVO: Obtener tooltip de pendientes según rol
  String _getPendientesTooltip(String role) {
    switch (role) {
      case 'supervisor':
        return 'Borradores y rechazadas que debes corregir';
      case 'gerencia':
        return 'Sanciones enviadas esperando tu aprobación';
      case 'rrhh':
        return 'Sanciones aprobadas por gerencia para revisión final';
      case 'admin':
        return 'Todas las sanciones sin decisión final';
      default:
        return 'Sanciones que requieren acción';
    }
  }

  // 🔥 NUEVO: Widget de estadística con tooltip
  Widget _buildStatCardWithTooltip(
      String emoji, String label, int count, Color color, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: Container(
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(emoji, style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 4),
                Icon(Icons.info_outline, size: 12, color: Colors.grey.shade400),
              ],
            ),
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
      ),
    );
  }

  // 🔥 NUEVO: Mostrar ayuda sobre estadísticas
  void _showStatsHelp(String role) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('📊 Explicación de Estadísticas'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Para tu rol de ${_getRoleDescription(role)}:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              _buildHelpItem('📋 Borradores',
                  'Sanciones guardadas pero no enviadas${role == 'supervisor' ? ' (puedes editarlas)' : ''}'),
              _buildHelpItem('📤 Enviadas',
                  'Sanciones enviadas a gerencia para aprobación'),
              _buildHelpItem('✅ Aprobadas', 'Sanciones aprobadas por gerencia'),
              _buildHelpItem('❌ Rechazadas',
                  'Sanciones rechazadas${role == 'supervisor' ? ' (debes corregirlas)' : ''}'),
              const Divider(),
              _buildHelpItem('⚠️ ${_getPendientesLabel(role)}',
                  _getPendientesTooltip(role),
                  highlight: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpItem(String title, String description,
      {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: highlight ? Colors.amber.shade700 : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: highlight ? Colors.amber.shade700 : Colors.grey.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getRoleDescription(String role) {
    switch (role) {
      case 'supervisor':
        return 'Supervisor';
      case 'gerencia':
        return 'Gerencia';
      case 'rrhh':
        return 'Recursos Humanos';
      case 'admin':
        return 'Administrador';
      default:
        return role;
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
        _loadData();
      }
    });
  }

  void _viewHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const HistorialSancionesScreen(),
      ),
    );
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
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '🔍 Buscar Empleados',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: EmpleadoSearchField(
                  onEmpleadoSelected: (empleado) {
                    Navigator.pop(context);
                    // Mostrar información del empleado
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Text(empleado.displayName),
                        content: Text(empleado.infoCompleta),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cerrar'),
                          ),
                        ],
                      ),
                    );
                  },
                  hintText: 'Buscar por nombre, cédula o código...',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleMenuSelection(String value) {
    switch (value) {
      case 'refresh':
        _loadData();
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
    );
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
    print('╔══════════════════════════════════════════════════════════╗');

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

    print('╚══════════════════════════════════════════════════════════╝\n');

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
