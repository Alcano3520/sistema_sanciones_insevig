import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/models/sancion_model.dart';
import '../../core/offline/sancion_repository.dart';
import '../widgets/sancion_card.dart'; // ← ESTA LÍNEA DEBE ESTAR
import '../widgets/filtros_dialog.dart'; // ← ESTA LÍNEA DEBE ESTAR
import 'detalle_sancion_screen.dart'; // ← ESTA LÍNEA DEBE ESTAR

/// Pantalla de historial de sanciones - Como tu PantallaHistorial de Kivy
/// Incluye filtros, búsqueda y visualización completa de sanciones
class HistorialSancionesScreen extends StatefulWidget {
  final int? empleadoCod;        // 🔥 NUEVO
  final String? empleadoNombre;  // 🔥 NUEVO
  
  const HistorialSancionesScreen({
    super.key,
    this.empleadoCod,      // 🔥 NUEVO
    this.empleadoNombre,   // 🔥 NUEVO
  });

  @override
  State<HistorialSancionesScreen> createState() =>
      _HistorialSancionesScreenState();
}

class _HistorialSancionesScreenState extends State<HistorialSancionesScreen> {
  final SancionRepository _sancionRepository = SancionRepository.instance;
  final ScrollController _scrollController = ScrollController();

  List<SancionModel> _sanciones = [];
  List<SancionModel> _sancionesFiltradas = [];
  bool _isLoading = true;
  String _searchQuery = '';

  // Filtros (como en tu Kivy)
  String _filtroStatus = 'todos';
  String _filtroTipo = 'todos';
  bool _soloMias = true; // Para supervisores
  bool _soloPendientes = false;
  DateTimeRange? _rangoFechas;

  @override
  void initState() {
    super.initState();
    _loadSanciones();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // Barra de búsqueda y filtros
          _buildSearchAndFilters(),

          // Estadísticas rápidas
          if (!_isLoading) _buildQuickStats(),

          // Lista de sanciones
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _sancionesFiltradas.isEmpty
                    ? _buildEmptyState()
                    : _buildSancionesList(),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      // 🔥 NUEVO: Mostrar nombre del empleado si hay filtro
      title: widget.empleadoNombre != null 
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Historial de Sanciones',
                style: TextStyle(fontSize: 18),
              ),
              Text(
                widget.empleadoNombre!,
                style: const TextStyle(
                  fontSize: 14, 
                  fontWeight: FontWeight.normal,
                  color: Colors.white70,
                ),
              ),
            ],
          )
        : const Text('Historial de Sanciones'),
      backgroundColor: const Color(0xFF1E3A8A),
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        // 🔥 NUEVO: Si hay filtro, botón para quitarlo
        if (widget.empleadoCod != null)
          IconButton(
            icon: const Icon(Icons.clear),
            tooltip: 'Ver todas las sanciones',
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const HistorialSancionesScreen(),
                ),
              );
            },
          ),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: _loadSanciones,
          tooltip: 'Actualizar',
        ),
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: _showFiltrosDialog,
          tooltip: 'Filtros avanzados',
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'export',
              child: Row(
                children: [
                  Icon(Icons.download),
                  SizedBox(width: 8),
                  Text('Exportar'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'stats',
              child: Row(
                children: [
                  Icon(Icons.analytics),
                  SizedBox(width: 8),
                  Text('Estadísticas'),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
          // 🔥 NUEVO: Mostrar indicador si hay filtro por empleado
          if (widget.empleadoCod != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.blue.shade700),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Mostrando sanciones de: ${widget.empleadoNombre}',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HistorialSancionesScreen(),
                        ),
                      );
                    },
                    child: Text(
                      'Ver todas',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Campo de búsqueda
          TextField(
            decoration: InputDecoration(
              hintText: 'Buscar por empleado, tipo, observaciones...',
              prefixIcon: const Icon(Icons.search, color: Color(0xFF1E3A8A)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                        });
                        _aplicarFiltros();
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide:
                    const BorderSide(color: Color(0xFF1E3A8A), width: 2),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
              _aplicarFiltros();
            },
          ),

          const SizedBox(height: 12),

          // Filtros rápidos
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip(
                  'Todos',
                  _filtroStatus == 'todos',
                  () => _setFiltroStatus('todos'),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Borradores',
                  _filtroStatus == 'borrador',
                  () => _setFiltroStatus('borrador'),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Enviadas',
                  _filtroStatus == 'enviado',
                  () => _setFiltroStatus('enviado'),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Aprobadas',
                  _filtroStatus == 'aprobado',
                  () => _setFiltroStatus('aprobado'),
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Pendientes',
                  _soloPendientes,
                  () => _toggleSoloPendientes(),
                  color: Colors.orange,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap,
      {Color? color}) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      backgroundColor: Colors.grey.shade200,
      selectedColor: (color ?? const Color(0xFF1E3A8A)).withOpacity(0.2),
      checkmarkColor: color ?? const Color(0xFF1E3A8A),
      labelStyle: TextStyle(
        color: isSelected
            ? (color ?? const Color(0xFF1E3A8A))
            : Colors.grey.shade700,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
    );
  }

  Widget _buildQuickStats() {
    final total = _sanciones.length;
    final pendientes = _sanciones.where((s) => s.pendiente).length;
    final ultimaSemana = _sanciones
        .where((s) => s.createdAt
            .isAfter(DateTime.now().subtract(const Duration(days: 7))))
        .length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total', total, Icons.assignment, Colors.blue),
          Container(width: 1, height: 30, color: Colors.grey.shade300),
          _buildStatItem(
              'Pendientes', pendientes, Icons.pending_actions, Colors.orange),
          Container(width: 1, height: 30, color: Colors.grey.shade300),
          _buildStatItem(
              'Esta semana', ultimaSemana, Icons.date_range, Colors.green),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, int count, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 18,
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
        ),
      ],
    );
  }

  Widget _buildSancionesList() {
    return RefreshIndicator(
      onRefresh: _loadSanciones,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _sancionesFiltradas.length,
        itemBuilder: (context, index) {
          final sancion = _sancionesFiltradas[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SancionCard(
              sancion: sancion,
              onTap: () => _verDetalle(sancion),
              onStatusChanged: _onSancionStatusChanged,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    String mensaje;
    String submensaje;
    IconData icono;

    if (_searchQuery.isNotEmpty) {
      icono = Icons.search_off;
      mensaje = 'Sin resultados';
      submensaje = 'No se encontraron sanciones con: "$_searchQuery"';
    } else if (widget.empleadoCod != null && _sanciones.isEmpty) {
      icono = Icons.assignment_outlined;
      mensaje = 'Sin sanciones';
      submensaje = '${widget.empleadoNombre} no tiene sanciones registradas';
    } else if (_filtroStatus != 'todos' || _soloPendientes) {
      icono = Icons.filter_list_off;
      mensaje = 'Sin sanciones';
      submensaje = 'No hay sanciones que coincidan con los filtros aplicados';
    } else {
      icono = Icons.assignment_outlined;
      mensaje = 'No hay sanciones registradas';
      submensaje = 'Registra tu primera sanción usando el botón +';
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icono,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            mensaje,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            submensaje,
            style: const TextStyle(
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
          if (_searchQuery.isNotEmpty ||
              _filtroStatus != 'todos' ||
              _soloPendientes) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _limpiarFiltros,
              icon: const Icon(Icons.clear_all),
              label: const Text('Limpiar filtros'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (!authProvider.currentUser!.canCreateSanciones) {
          return const SizedBox.shrink();
        }

        return FloatingActionButton(
          onPressed: _crearNuevaSancion,
          backgroundColor: const Color(0xFF1E3A8A),
          child: const Icon(Icons.add),
        );
      },
    );
  }

  // Funciones de carga y filtrado
  Future<void> _loadSanciones() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser!;

      List<SancionModel> sanciones;

      // 🔥 NUEVO: Si hay filtro por empleado
      if (widget.empleadoCod != null) {
        sanciones = await _sancionRepository.getSancionesByEmpleado(widget.empleadoCod!);
      } else {
        // Lógica existente
        if (user.canViewAllSanciones && !_soloMias) {
          // Gerencia/RRHH pueden ver todas
          sanciones = await _sancionRepository.getAllSanciones();
        } else {
          // Supervisores solo ven las suyas
          sanciones = await _sancionRepository.getMySanciones(user.id);
        }
      }

      if (mounted) {
        setState(() {
          _sanciones = sanciones;
          _isLoading = false;
        });
        _aplicarFiltros();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error cargando sanciones: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _aplicarFiltros() {
    setState(() {
      _sancionesFiltradas = _sanciones.where((sancion) {
        // Filtro por búsqueda
        if (_searchQuery.isNotEmpty) {
          final query = _searchQuery.toLowerCase();
          final coincide = sancion.empleadoNombre
                  .toLowerCase()
                  .contains(query) ||
              sancion.tipoSancion.toLowerCase().contains(query) ||
              (sancion.observaciones?.toLowerCase().contains(query) ?? false) ||
              (sancion.observacionesAdicionales
                      ?.toLowerCase()
                      .contains(query) ??
                  false) ||
              sancion.puesto.toLowerCase().contains(query) ||
              sancion.agente.toLowerCase().contains(query);

          if (!coincide) return false;
        }

        // Filtro por status
        if (_filtroStatus != 'todos' && sancion.status != _filtroStatus) {
          return false;
        }

        // Filtro por tipo
        if (_filtroTipo != 'todos' && sancion.tipoSancion != _filtroTipo) {
          return false;
        }

        // Filtro solo pendientes
        if (_soloPendientes && !sancion.pendiente) {
          return false;
        }

        // Filtro por rango de fechas
        if (_rangoFechas != null) {
          final fechaSancion = sancion.fecha;
          if (fechaSancion.isBefore(_rangoFechas!.start) ||
              fechaSancion.isAfter(_rangoFechas!.end)) {
            return false;
          }
        }

        return true;
      }).toList();

      // Ordenar por fecha de creación (más reciente primero)
      _sancionesFiltradas.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    });
  }

  // Acciones de filtros
  void _setFiltroStatus(String status) {
    setState(() {
      _filtroStatus = status;
      if (status != 'todos') {
        _soloPendientes =
            false; // Limpiar filtro de pendientes si se selecciona otro status
      }
    });
    _aplicarFiltros();
  }

  void _toggleSoloPendientes() {
    setState(() {
      _soloPendientes = !_soloPendientes;
      if (_soloPendientes) {
        _filtroStatus =
            'todos'; // Limpiar filtro de status si se selecciona pendientes
      }
    });
    _aplicarFiltros();
  }

  void _limpiarFiltros() {
    setState(() {
      _searchQuery = '';
      _filtroStatus = 'todos';
      _filtroTipo = 'todos';
      _soloPendientes = false;
      _rangoFechas = null;
    });
    _aplicarFiltros();
  }

  // Acciones de la interfaz
  void _showFiltrosDialog() {
    showDialog(
      context: context,
      builder: (context) => FiltrosDialog(
        filtroTipo: _filtroTipo,
        soloMias: _soloMias,
        rangoFechas: _rangoFechas,
        canViewAll: Provider.of<AuthProvider>(context, listen: false)
            .currentUser!
            .canViewAllSanciones,
        onFiltrosChanged: (tipo, soloMias, rango) {
          setState(() {
            _filtroTipo = tipo;
            _soloMias = soloMias;
            _rangoFechas = rango;
          });
          _aplicarFiltros();
        },
      ),
    );
  }

  void _verDetalle(SancionModel sancion) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetalleSancionScreen(sancion: sancion),
      ),
    ).then((updated) {
      if (updated == true) {
        _loadSanciones(); // Recargar si hubo cambios
      }
    });
  }

  void _crearNuevaSancion() {
    Navigator.pushNamed(context, '/create_sancion').then((result) {
      if (result == true) {
        _loadSanciones();
      }
    });
  }

  void _onSancionStatusChanged() {
    _loadSanciones(); // Recargar cuando cambie el status de una sanción
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'export':
        _exportarDatos();
        break;
      case 'stats':
        _mostrarEstadisticas();
        break;
    }
  }

  void _exportarDatos() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🚧 Exportar datos - Próximamente'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _mostrarEstadisticas() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🚧 Estadísticas detalladas - Próximamente'),
        backgroundColor: Colors.orange,
      ),
    );
  }
}