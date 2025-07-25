import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/sancion_service.dart';
import '../../core/services/empleado_service.dart';
import 'create_sancion_screen.dart'; // Añadir esta línea
import 'historial_sanciones_screen.dart'; // Añadir esta lí

/// Pantalla principal después del login
/// Equivalente a tu pantalla principal de Kivy pero modernizada
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic> _stats = {};
  Map<String, int> _empleadoStats = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final sancionService = SancionService();
      final empleadoService = EmpleadoService();

      // Cargar estadísticas según el rol
      if (authProvider.currentUser!.isSupervisor) {
        _stats = await sancionService.getEstadisticas(
          supervisorId: authProvider.currentUser!.id,
        );
      } else {
        _stats = await sancionService.getEstadisticas();
      }

      _empleadoStats = await empleadoService.getEstadisticasEmpleados();
    } catch (e) {
      print('❌ Error cargando datos: $e');
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Sistema de Sanciones - INSEVIG'),
      backgroundColor: const Color(0xFF1E3A8A),
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadData,
          tooltip: 'Actualizar datos',
        ),
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: _showNotifications,
          tooltip: 'Notificaciones',
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: _handleMenuSelection,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'profile',
              child: Row(
                children: [
                  Icon(Icons.person_outline),
                  SizedBox(width: 8),
                  Text('Mi Perfil'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'settings',
              child: Row(
                children: [
                  Icon(Icons.settings_outlined),
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
                  Icon(Icons.logout, color: Colors.red),
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
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.5,
              children: [
                if (user.canCreateSanciones)
                  _buildActionCard(
                    '📝',
                    'Nueva Sanción',
                    'Registrar una nueva sanción',
                    () => _createNewSancion(),
                  ),
                _buildActionCard(
                  '📋',
                  'Ver Historial',
                  'Ver sanciones anteriores',
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
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
}
