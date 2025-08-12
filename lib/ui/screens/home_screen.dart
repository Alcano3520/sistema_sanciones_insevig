import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart'; // 🔥 Importar Hive
import '../../core/providers/auth_provider.dart';
import '../../core/offline/sancion_repository.dart';
import '../../core/offline/empleado_repository.dart';
import '../../core/offline/connectivity_service.dart';
import '../../core/offline/offline_manager.dart';
import 'create_sancion_screen.dart';
import 'historial_sanciones_screen.dart';

/// Pantalla principal después del login
/// Equivalente a tu pantalla principal de Kivy pero modernizada
/// 🔥 ACTUALIZADA para usar repositories con funcionalidad offline
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 🔥 DECLARAR VARIABLES Y REPOSITORIES
  final SancionRepository _sancionRepository = SancionRepository.instance;
  final EmpleadoRepository _empleadoRepository = EmpleadoRepository.instance;

  Map<String, dynamic> _stats = {};
  Map<String, int> _empleadoStats = {};
  bool _isLoading = true;
  bool _isOnline = true;
  StreamSubscription<bool>? _connectivitySubscription;

  // 🔥 NUEVO: Variable para test de persistencia
  String? _lastTestValue;

  @override
  void initState() {
    super.initState();
    _loadData();
    _listenToConnectivity();
    _loadTestValue(); // 🔥 Cargar valor de test anterior
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }

  // 🔥 NUEVO: Cargar valor de test anterior
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

  // 🔥 NUEVO: Escuchar cambios en la conectividad
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

  // 🔥 NUEVO: Sincronizar datos pendientes
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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // 🆕 USAR REPOSITORIES en lugar de services
      if (authProvider.currentUser!.isSupervisor) {
        _stats = await _sancionRepository.getEstadisticas(
          supervisorId: authProvider.currentUser!.id,
        );
      } else {
        _stats = await _sancionRepository.getEstadisticas();
      }

      _empleadoStats = await _empleadoRepository.getEstadisticasEmpleados();

      // 🔥 NUEVO: Actualizar estado de conectividad
      _isOnline = ConnectivityService.instance.isConnected;
    } catch (e) {
      print('❌ Error cargando datos: $e');

      // 🔥 NUEVO: Si hay error, probablemente estamos offline
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
          // 🔥 BANNER DE DEBUG (solo en modo desarrollo)
          if (!kIsWeb && kDebugMode) _buildOfflineDebugBanner(),

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
                          // 🔥 NUEVO: Banner de estado offline
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
      // 🔥 AQUÍ VA EL BOTÓN DE DEBUG - Stack con FAB principal y debug
      floatingActionButton: Stack(
        children: [
          // Botón principal existente
          Positioned(
            bottom: 0,
            right: 0,
            child: _buildFloatingActionButton(),
          ),

          // 🆕 BOTÓN DE TEST DE PERSISTENCIA (solo en debug)
          if (!kIsWeb && kDebugMode)
            Positioned(
              bottom: 70,
              right: 10,
              child: FloatingActionButton(
                mini: true,
                heroTag: "test_persistence_btn",
                backgroundColor: Colors.orange,
                onPressed: _testPersistence,
                child: const Icon(Icons.save, size: 20),
                tooltip: 'Test Persistencia',
              ),
            ),
            
          // 🆕 BOTÓN DE DEBUG OFFLINE (arriba del de persistencia)
          if (!kIsWeb && kDebugMode)
            Positioned(
              bottom: 120,
              right: 10,
              child: FloatingActionButton(
                mini: true,
                heroTag: "debug_btn",
                backgroundColor: Colors.purple,
                onPressed: _runOfflineTest,
                child: const Icon(Icons.bug_report, size: 20),
                tooltip: 'Debug Offline',
              ),
            ),
        ],
      ),
    );
  }

  // 🔥 NUEVO: Test de persistencia
  Future<void> _testPersistence() async {
    if (kIsWeb) return;
    
    try {
      // Test de persistencia
      final testId = 'test_${DateTime.now().millisecondsSinceEpoch}';
      
      // Guardar dato de prueba
      final box = await Hive.openBox('test_persistence');
      await box.put('test_key', testId);
      await box.flush(); // 🔥 Forzar escritura
      
      print('✅ Guardado: $testId');
      
      // Verificar inmediatamente
      final saved = box.get('test_key');
      print('📖 Leído inmediatamente: $saved');
      
      setState(() => _lastTestValue = testId);
      
      // Mostrar diálogo con información
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
                // Limpiar test
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

  // 🔥 NUEVO: Banner de debug para ver estado del sistema offline
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

  // 🔥 NUEVO: Banner indicando modo offline (producción)
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

  // En home_screen.dart - método _buildAppBar()
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      // 🔥 SOLUCIÓN: Hacer el título más flexible
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
              value: 'settings',
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
                  Icon(Icons.logout, size: 20),
                  SizedBox(width: 8),
                  Text('Cerrar Sesión'),
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

  Widget _buildStatsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Estadísticas',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A8A),
          ),
        ),
        const SizedBox(height: 12),

        // Estadísticas de sanciones
        Row(
          children: [
            Expanded(
                child: _buildStatCard('📝', 'Borradores',
                    _stats['borradores'] ?? 0, Colors.orange)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildStatCard(
                    '📤', 'Enviadas', _stats['enviadas'] ?? 0, Colors.blue)),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
                child: _buildStatCard(
                    '✅', 'Aprobadas', _stats['aprobadas'] ?? 0, Colors.green)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildStatCard(
                    '❌', 'Rechazadas', _stats['rechazadas'] ?? 0, Colors.red)),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
                child: _buildStatCard('⚠️', 'Pendientes',
                    _stats['pendientes'] ?? 0, Colors.amber)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildStatCard('👥', 'Empleados',
                    _empleadoStats['total'] ?? 0, Colors.indigo)),
          ],
        ),
      ],
    );
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
              childAspectRatio: isMobile ? 1.3 : 1.5, // Más espacio en móvil
              children: [
                if (user.canCreateSanciones)
                  _buildActionCard(
                    '📝',
                    'Nueva Sanción',
                    'Registrar sanción', // Texto más corto
                    () => _createNewSancion(),
                  ),
                _buildActionCard(
                  '📋',
                  'Ver Historial',
                  'Sanciones anteriores', // Texto más corto
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
        padding: const EdgeInsets.all(12), // Reducido de 16 a 12
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
            // Emoji con tamaño flexible
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 28), // Reducido de 32
              ),
            ),

            const SizedBox(height: 4), // Reducido de 8

            // Título con control de overflow
            Flexible(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 14, // Reducido de 16
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(height: 2), // Reducido de 4

            // Subtítulo con mejor control
            Flexible(
              child: Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11, // Reducido de 12
                  color: Colors.grey,
                  height: 1.2, // Altura de línea ajustada
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
      // Si se guardó una sanción, recargar datos
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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🚧 Búsqueda de empleados - Próximamente'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showNotifications() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🔔 No tienes notificaciones nuevas'),
        backgroundColor: Colors.blue,
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
      case 'settings':
        _showSettings();
        break;
      case 'logout':
        _logout();
        break;
    }
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

  void _showSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('⚙️ Configuración - Próximamente'),
        backgroundColor: Colors.grey,
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
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }

  // 🔥 NUEVO: Método para test offline
  Future<void> _runOfflineTest() async {
    print('\n🧪 TEST MODO OFFLINE:');

    // 1. Estado actual
    final offline = OfflineManager.instance;
    print('📊 Stats: ${offline.getOfflineStats()}');

    // 2. Verificar conectividad
    final connectivity = ConnectivityService.instance;
    print('📡 Conectividad: ${connectivity.isConnected}');

    // 3. Probar búsqueda
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

    // 4. Ver cache
    final db = offline.database;
    final cached = db.getEmpleados();
    print('\n💾 En cache local:');
    print('   - Total: ${cached.length}');
    if (cached.isNotEmpty) {
      print(
          '   - Primeros 3: ${cached.take(3).map((e) => e.displayName).join(", ")}');
    }

    // Mostrar diálogo con resultados
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
                Text('🔍 Búsqueda "a": ${cached.where((e) => e.displayName.toLowerCase().contains('a')).length} resultados'),
                Text('📡 Conectividad: ${connectivity.isConnected ? "ONLINE" : "OFFLINE"}'),
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

  // 🔥 NUEVO: Método de verificación detallada
  void _verificarCacheDetallado() {
    final offline = OfflineManager.instance;

    print('\n📊 VERIFICACIÓN DETALLADA DEL CACHE:');
    print('════════════════════════════════════════');

    // Total en cache
    final todosEmpleados = offline.database.getEmpleados();
    print('📦 Total empleados en cache: ${todosEmpleados.length}');

    // Primeros 5 empleados
    print('\n👥 Primeros 5 empleados en cache:');
    todosEmpleados.take(5).forEach((emp) {
      print('   ${emp.cod} - ${emp.displayName} - ${emp.nomdep ?? "Sin dept"}');
    });

    // Buscar "vera" manualmente
    print('\n🔍 Búsqueda manual de "vera":');
    final testVera = offline.database.searchEmpleados('vera');
    print('   Encontrados: ${testVera.length}');
    if (testVera.isNotEmpty) {
      testVera.take(3).forEach((emp) {
        print(
            '   ✓ ${emp.displayName} (${emp.cod}) - ${emp.nomcargo ?? "Sin cargo"}');
      });
    }

    // Buscar "zambrano"
    print('\n🔍 Búsqueda manual de "zambrano":');
    final testZambrano = offline.database.searchEmpleados('zambrano');
    print('   Encontrados: ${testZambrano.length}');
    if (testZambrano.isNotEmpty) {
      testZambrano.take(3).forEach((emp) {
        print('   ✓ ${emp.displayName} (${emp.cod})');
      });
    }

    // Estadísticas
    print('\n📈 Estadísticas del cache:');
    final stats = offline.getOfflineStats();
    stats.forEach((key, value) {
      print('   $key: $value');
    });

    print('════════════════════════════════════════\n');

    // Mostrar snackbar con resumen
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