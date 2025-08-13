import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../widgets/codigo_descuento_dialog.dart';
// 🔥 NUEVAS IMPORTACIONES PARA PDF
import '../../core/services/pdf_service.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';

import '../../core/providers/auth_provider.dart';
import '../../core/models/sancion_model.dart';
import '../../core/offline/sancion_repository.dart';
import '../widgets/sancion_card.dart';
import '../widgets/filtros_dialog.dart';
import 'detalle_sancion_screen.dart';

/// Pantalla de historial de sanciones - Como tu PantallaHistorial de Kivy
/// Incluye filtros, búsqueda y visualización completa de sanciones
/// 🆕 AHORA CON GENERACIÓN DE REPORTES PDF + SISTEMA DE APROBACIONES
class HistorialSancionesScreen extends StatefulWidget {
  const HistorialSancionesScreen({super.key});

  @override
  State<HistorialSancionesScreen> createState() =>
      _HistorialSancionesScreenState();
}

class _HistorialSancionesScreenState extends State<HistorialSancionesScreen>
    with SingleTickerProviderStateMixin {
  final SancionRepository _sancionRepository = SancionRepository.instance;
  final ScrollController _scrollController = ScrollController();
  
  // 🆕 CONTROLLER DE TABS
  TabController? _tabController;

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
  
  // 🆕 ESTADÍSTICAS POR ROL
  Map<String, dynamic> _estadisticasRol = {};

  @override
  void initState() {
    super.initState();
    _initializeTabs();
    _loadSanciones();
    _loadEstadisticasRol();
  }

  void _initializeTabs() {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser!;
    
    // Configurar tabs según rol
    if (user.role == 'gerencia' || user.role == 'aprobador') {
      _tabController = TabController(length: 3, vsync: this);
    } else if (user.role == 'rrhh') {
      _tabController = TabController(length: 3, vsync: this);
    } else {
      _tabController = TabController(length: 2, vsync: this); // Supervisor normal
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser!;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // 🆕 TABS POR ROL
          if (_showTabsForRole(user.role)) _buildTabBar(),

          // Barra de búsqueda y filtros
          _buildSearchAndFilters(),

          // 🆕 ESTADÍSTICAS POR ROL
          if (!_isLoading) _buildEstadisticasRole(),

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

  // 🔥 APPBAR MEJORADO CON BOTÓN PDF
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Historial de Sanciones'),
      backgroundColor: const Color(0xFF1E3A8A),
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
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
        // 🆕 BOTÓN PDF AGREGADO
        IconButton(
          icon: const Icon(Icons.picture_as_pdf),
          onPressed: _showPDFOptionsMenu,
          tooltip: 'Generar PDF',
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

  // 🆕 TAB BAR SEGÚN ROL
  Widget _buildTabBar() {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser!;
    
    return Container(
      color: Colors.white,
      child: TabBar(
        controller: _tabController,
        labelColor: const Color(0xFF1E3A8A),
        unselectedLabelColor: Colors.grey,
        indicatorColor: const Color(0xFF1E3A8A),
        tabs: _getTabsForRole(user.role),
        onTap: (index) {
          _onTabChanged(index);
        },
      ),
    );
  }

  List<Widget> _getTabsForRole(String role) {
    switch (role) {
      case 'gerencia':
      case 'aprobador':
        return [
          Tab(text: 'Todas (${_sanciones.length})'),
          Tab(text: 'Pendientes Aprobación (${_getPendientesGerencia()})'),
          Tab(text: 'Mis Aprobadas (${_getAprobadasGerencia()})'),
        ];
      
      case 'rrhh':
        return [
          Tab(text: 'Todas (${_sanciones.length})'),
          Tab(text: 'Pendientes RRHH (${_getPendientesRRHH()})'),
          Tab(text: 'Procesadas (${_getProcesadasRRHH()})'),
        ];
      
      default:
        return [
          Tab(text: 'Todas (${_sanciones.length})'),
          Tab(text: 'Pendientes (${_getPendientesSuper()})'),
        ];
    }
  }

  bool _showTabsForRole(String role) {
    return ['gerencia', 'aprobador', 'rrhh'].contains(role);
  }

  void _onTabChanged(int index) {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser!;
    
    setState(() {
      switch (user.role) {
        case 'gerencia':
        case 'aprobador':
          switch (index) {
            case 0: // Todas
              _filtroStatus = 'todos';
              break;
            case 1: // Pendientes aprobación
              _filtroStatus = 'enviado';
              break;
            case 2: // Mis aprobadas
              _filtroStatus = 'aprobado';
              break;
          }
          break;
        
        case 'rrhh':
          switch (index) {
            case 0: // Todas
              _filtroStatus = 'todos';
              break;
            case 1: // Pendientes RRHH (aprobado sin comentarios_rrhh)
              _filtroStatus = 'aprobado_pendiente_rrhh';
              break;
            case 2: // Procesadas (aprobado con comentarios_rrhh)
              _filtroStatus = 'aprobado_procesado_rrhh';
              break;
          }
          break;
        
        default:
          switch (index) {
            case 0: // Todas
              _filtroStatus = 'todos';
              break;
            case 1: // Pendientes
              _soloPendientes = true;
              break;
          }
      }
    });
    
    _aplicarFiltros();
  }

  // 🆕 CONTADORES ESPECÍFICOS POR ROL
  int _getPendientesGerencia() {
    return _sanciones.where((s) => s.status == 'enviado').length;
  }

  int _getAprobadasGerencia() {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser!;
    return _sanciones.where((s) => 
      s.status == 'aprobado' && s.reviewedBy == user.id
    ).length;
  }

  int _getPendientesRRHH() {
    // Aprobadas por gerencia pero sin procesar por RRHH
    return _sanciones.where((s) => 
      s.status == 'aprobado' && 
      s.comentariosGerencia != null && 
      s.comentariosRrhh == null
    ).length;
  }

  int _getProcesadasRRHH() {
    // Aprobadas y procesadas por RRHH
    return _sanciones.where((s) => 
      s.status == 'aprobado' && 
      s.comentariosRrhh != null
    ).length;
  }

  int _getPendientesSuper() {
    return _sanciones.where((s) => s.pendiente).length;
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        children: [
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
                // 🆕 FILTROS ESPECÍFICOS PARA RRHH
                if (_isRRHHUser()) ...[
                  _buildFilterChip(
                    'Pendientes RRHH',
                    _filtroStatus == 'aprobado_pendiente_rrhh',
                    () => _setFiltroStatus('aprobado_pendiente_rrhh'),
                    color: Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterChip(
                    'Procesadas RRHH',
                    _filtroStatus == 'aprobado_procesado_rrhh',
                    () => _setFiltroStatus('aprobado_procesado_rrhh'),
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 8),
                ],
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

  bool _isRRHHUser() {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser!;
    return user.role == 'rrhh';
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

  // 🆕 ESTADÍSTICAS ESPECÍFICAS POR ROL
  Widget _buildEstadisticasRole() {
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser!;
    
    if (user.role == 'gerencia' || user.role == 'aprobador') {
      return _buildEstadisticasGerencia();
    } else if (user.role == 'rrhh') {
      return _buildEstadisticasRRHH();
    } else {
      return _buildQuickStats(); // Estadísticas originales para supervisores
    }
  }

  Widget _buildEstadisticasGerencia() {
    final pendientes = _getPendientesGerencia();
    final aprobadas = _getAprobadasGerencia();
    final conDescuento = _estadisticasRol['total_con_descuento'] ?? 0;

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
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.admin_panel_settings, color: Color(0xFF1E3A8A)),
              const SizedBox(width: 8),
              const Text(
                'Panel Gerencia',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Pendientes\nAprobación', pendientes, Icons.pending_actions, Colors.orange),
              Container(width: 1, height: 30, color: Colors.grey.shade300),
              _buildStatItem('Mis\nAprobadas', aprobadas, Icons.check_circle, Colors.green),
              Container(width: 1, height: 30, color: Colors.grey.shade300),
              _buildStatItem('Con\nDescuento', conDescuento, Icons.discount, Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEstadisticasRRHH() {
    final pendientesRRHH = _getPendientesRRHH();
    final procesadas = _getProcesadasRRHH();
    final modificadas = _estadisticasRol['modificadas'] ?? 0;
    final anuladas = _estadisticasRol['anuladas'] ?? 0;

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
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.business_center, color: Color(0xFF1E3A8A)),
              const SizedBox(width: 8),
              const Text(
                'Panel RRHH',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Pendientes\nRRHH', pendientesRRHH, Icons.pending_actions, Colors.orange),
              Container(width: 1, height: 30, color: Colors.grey.shade300),
              _buildStatItem('Procesadas', procesadas, Icons.verified, Colors.blue),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Modificadas', modificadas, Icons.edit, Colors.purple),
              Container(width: 1, height: 30, color: Colors.grey.shade300),
              _buildStatItem('Anuladas', anuladas, Icons.block, Colors.red),
            ],
          ),
        ],
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
          textAlign: TextAlign.center,
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
          final user = Provider.of<AuthProvider>(context, listen: false).currentUser!;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SancionCard(
              sancion: sancion,
              onTap: () => _verDetalle(sancion),
              onStatusChanged: _onSancionStatusChanged,
              // 🆕 PARÁMETROS ESPECÍFICOS POR ROL
              showCodigoDescuento: _shouldShowCodigoDescuento(sancion, user),
              showProcesamientoRRHH: _shouldShowProcesamientoRRHH(sancion, user),
              showBotonesGerencia: _shouldShowBotonesGerencia(sancion, user),
              showBotonesRRHH: _shouldShowBotonesRRHH(sancion, user),
            ),
          );
        },
      ),
    );
  }

  // 🆕 LÓGICA DE MOSTRAR ELEMENTOS SEGÚN ROL Y ESTADO
  bool _shouldShowCodigoDescuento(SancionModel sancion, user) {
    return sancion.status == 'aprobado' && sancion.comentariosGerencia != null;
  }

  bool _shouldShowProcesamientoRRHH(SancionModel sancion, user) {
    return sancion.status == 'aprobado' && sancion.comentariosRrhh != null;
  }

  bool _shouldShowBotonesGerencia(SancionModel sancion, user) {
    return (user.role == 'gerencia' || user.role == 'aprobador') && 
           sancion.status == 'enviado';
  }

  bool _shouldShowBotonesRRHH(SancionModel sancion, user) {
    return user.role == 'rrhh' && 
           sancion.status == 'aprobado' && 
           sancion.comentariosGerencia != null &&
           sancion.comentariosRrhh == null;
  }

  Widget _buildEmptyState() {
    String mensaje;
    String submensaje;
    IconData icono;

    if (_searchQuery.isNotEmpty) {
      icono = Icons.search_off;
      mensaje = 'Sin resultados';
      submensaje = 'No se encontraron sanciones con: "$_searchQuery"';
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

  // ==========================================
  // 🔥 FUNCIONALIDADES PDF AGREGADAS (MANTENIDAS ORIGINALES)
  // ==========================================

  /// **Mostrar menú de opciones PDF**
  void _showPDFOptionsMenu() {
    if (_sancionesFiltradas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 8),
              Text('⚠️ No hay sanciones para generar PDF'),
            ],
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Título
            Row(
              children: [
                const Icon(Icons.picture_as_pdf, color: Colors.red, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Generar Reporte PDF',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Información actual
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sanciones actuales: ${_sancionesFiltradas.length}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  if (_filtroStatus != 'todos')
                    Text('Filtro estado: $_filtroStatus', style: const TextStyle(fontSize: 12)),
                  if (_soloPendientes)
                    const Text('Solo pendientes: Sí', style: TextStyle(fontSize: 12)),
                  if (_rangoFechas != null)
                    Text(
                      'Rango: ${_rangoFechas!.start.day}/${_rangoFechas!.start.month} - ${_rangoFechas!.end.day}/${_rangoFechas!.end.month}',
                      style: const TextStyle(fontSize: 12),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Opciones de reporte
            ListTile(
              leading: const Icon(Icons.list_alt, color: Color(0xFF1E3A8A)),
              title: const Text('Reporte Completo'),
              subtitle: Text('${_sancionesFiltradas.length} sanciones con filtros actuales'),
              onTap: () {
                Navigator.pop(context);
                _generarReporteCompleto();
              },
            ),

            const Divider(),

            ListTile(
              leading: const Icon(Icons.today, color: Colors.green),
              title: const Text('Reporte del Día'),
              subtitle: Text('${_getSancionesHoy().length} sanciones de hoy'),
              onTap: () {
                Navigator.pop(context);
                _generarReporteDelDia();
              },
            ),

            const Divider(),

            ListTile(
              leading: const Icon(Icons.date_range, color: Colors.orange),
              title: const Text('Reporte Personalizado'),
              subtitle: const Text('Seleccionar rango específico'),
              onTap: () {
                Navigator.pop(context);
                _generarReportePersonalizado();
              },
            ),

            const SizedBox(height: 20),

            // Botón cerrar
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }

  /// **Generar reporte PDF completo**
  Future<void> _generarReporteCompleto() async {
    await _generarReportePDF(
      sanciones: _sancionesFiltradas,
      titulo: 'REPORTE COMPLETO DE SANCIONES',
      descripcion: _getDescripcionFiltros(),
    );
  }

  /// **Generar reporte del día actual**
  Future<void> _generarReporteDelDia() async {
    final sancionesHoy = _getSancionesHoy();
    
    if (sancionesHoy.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('📅 No hay sanciones registradas hoy'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await _generarReportePDF(
      sanciones: sancionesHoy,
      titulo: 'REPORTE DIARIO DE SANCIONES',
      descripcion: 'Sanciones del ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
    );
  }

  /// **Generar reporte personalizado con selección de fechas**
  Future<void> _generarReportePersonalizado() async {
    final dateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1E3A8A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (dateRange != null) {
      final sancionesEnRango = _sanciones.where((sancion) {
        return sancion.fecha.isAfter(dateRange.start.subtract(const Duration(days: 1))) &&
               sancion.fecha.isBefore(dateRange.end.add(const Duration(days: 1)));
      }).toList();

      if (sancionesEnRango.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📅 No hay sanciones en el rango seleccionado'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      await _generarReportePDF(
        sanciones: sancionesEnRango,
        titulo: 'REPORTE PERSONALIZADO DE SANCIONES',
        descripcion: 'Del ${dateRange.start.day}/${dateRange.start.month}/${dateRange.start.year} al ${dateRange.end.day}/${dateRange.end.month}/${dateRange.end.year}',
      );
    }
  }

  /// **Método principal para generar cualquier reporte PDF**
  Future<void> _generarReportePDF({
    required List<SancionModel> sanciones,
    required String titulo,
    required String descripcion,
  }) async {
    try {
      // Mostrar indicador de carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text(
                'Generando reporte PDF...',
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );

      // Obtener usuario actual para el reporte
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final generadoPor = authProvider.currentUser?.fullName ?? 'Sistema';

      // Generar PDF
      final pdfService = PDFService.instance;
      final pdfBytes = await pdfService.generateReportePDF(
        sanciones,
        titulo: titulo,
        filtros: descripcion,
        generadoPor: generadoPor,
      );
      final filename = pdfService.generateFileName(null, isReport: true);

      // Cerrar indicador de carga
      if (mounted) Navigator.pop(context);

      // Mostrar opciones del PDF generado
      _showReportePDFDialog(pdfBytes, filename, sanciones.length);

    } catch (e) {
      // Cerrar indicador si está abierto
      if (mounted) Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error generando reporte PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// **Mostrar opciones del reporte PDF generado**
  void _showReportePDFDialog(Uint8List pdfBytes, String filename, int totalSanciones) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Título de éxito
            Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Reporte PDF Generado',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 20),

            // Información del reporte
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Archivo: $filename',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  Text(
                    'Total sanciones: $totalSanciones',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    'Tamaño: ${(pdfBytes.length / 1024).toStringAsFixed(1)} KB',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    'Generado: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year} ${DateTime.now().hour}:${DateTime.now().minute.toString().padLeft(2, '0')}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Opciones
            if (!kIsWeb) ...[
              ListTile(
                leading: const Icon(Icons.visibility, color: Color(0xFF1E3A8A)),
                title: const Text('Vista Previa'),
                subtitle: const Text('Ver el reporte antes de descargar'),
                onTap: () async {
                  Navigator.pop(context);
                  await PDFService.instance.previewPDF(pdfBytes, filename);
                },
              ),
              const Divider(),
            ],

            ListTile(
              leading: const Icon(Icons.download, color: Colors.green),
              title: Text(kIsWeb ? 'Descargar' : 'Guardar'),
              subtitle: Text(kIsWeb 
                  ? 'Descargar a tu computadora' 
                  : 'Guardar en dispositivo'),
              onTap: () async {
                Navigator.pop(context);
                await _guardarReportePDF(pdfBytes, filename);
              },
            ),

            const Divider(),

            ListTile(
              leading: const Icon(Icons.share, color: Colors.blue),
              title: const Text('Compartir'),
              subtitle: const Text('Email, WhatsApp, etc.'),
              onTap: () async {
                Navigator.pop(context);
                await _compartirReportePDF(pdfBytes, filename);
              },
            ),

            const SizedBox(height: 20),

            // Botón cerrar
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    );
  }

  /// **Guardar reporte PDF**
  Future<void> _guardarReportePDF(Uint8List pdfBytes, String filename) async {
    try {
      final savedPath = await PDFService.instance.savePDF(pdfBytes, filename);
      
      if (savedPath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.download_done, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(kIsWeb 
                      ? '🔥 Reporte descargado: $filename'
                      : '🔥 Reporte guardado en Documentos'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error guardando reporte: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  /// **Compartir reporte PDF**
  Future<void> _compartirReportePDF(Uint8List pdfBytes, String filename) async {
    try {
      await PDFService.instance.sharePDF(pdfBytes, filename);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.share, color: Colors.white),
                SizedBox(width: 8),
                Text('📤 Reporte listo para compartir'),
              ],
            ),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error compartiendo reporte: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ==========================================
  // 🔧 MÉTODOS AUXILIARES PARA PDF
  // ==========================================

  /// **Obtener sanciones de hoy**
  List<SancionModel> _getSancionesHoy() {
    final hoy = DateTime.now();
    return _sanciones.where((sancion) {
      return sancion.fecha.year == hoy.year &&
             sancion.fecha.month == hoy.month &&
             sancion.fecha.day == hoy.day;
    }).toList();
  }

  /// **Obtener descripción de los filtros actuales**
  String _getDescripcionFiltros() {
    final filtros = <String>[];
    
    if (_filtroStatus != 'todos') {
      filtros.add('Estado: $_filtroStatus');
    }
    
    if (_soloPendientes) {
      filtros.add('Solo pendientes');
    }
    
    if (_rangoFechas != null) {
      filtros.add('Rango: ${_rangoFechas!.start.day}/${_rangoFechas!.start.month} - ${_rangoFechas!.end.day}/${_rangoFechas!.end.month}');
    }
    
    if (filtros.isEmpty) {
      return 'Todas las sanciones';
    }
    
    return filtros.join(' • ');
  }

  // ==========================================
  // 🔧 FUNCIONES ORIGINALES DE CARGA Y FILTRADO + EXTENSIONES
  // ==========================================

  // Funciones de carga y filtrado
  Future<void> _loadSanciones() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser!;

      List<SancionModel> sanciones;

      // 🆕 CARGA ESPECÍFICA POR ROL
      switch (user.role) {
        case 'gerencia':
        case 'aprobador':
          sanciones = await _sancionRepository.getSancionesParaGerencia();
          break;
        case 'rrhh':
          sanciones = await _sancionRepository.getSancionesParaRRHH();
          break;
        default:
          // Supervisor normal
          if (user.canViewAllSanciones && !_soloMias) {
            sanciones = await _sancionRepository.getAllSanciones();
          } else {
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

  // 🆕 CARGAR ESTADÍSTICAS POR ROL
  Future<void> _loadEstadisticasRol() async {
    try {
      final stats = await _sancionRepository.getEstadisticasByRole();
      if (mounted) {
        setState(() {
          _estadisticasRol = stats;
        });
      }
    } catch (e) {
      print('❌ Error cargando estadísticas por rol: $e');
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

        // 🆕 FILTROS ESPECÍFICOS POR ROL Y ESTADO
        switch (_filtroStatus) {
          case 'aprobado_pendiente_rrhh':
            // Aprobado por gerencia pero sin procesar por RRHH
            return sancion.status == 'aprobado' && 
                   sancion.comentariosGerencia != null && 
                   sancion.comentariosRrhh == null;
          
          case 'aprobado_procesado_rrhh':
            // Aprobado y procesado por RRHH
            return sancion.status == 'aprobado' && 
                   sancion.comentariosRrhh != null;
          
          case 'todos':
            break; // No filtrar por status
          
          default:
            // Filtro por status normal
            if (sancion.status != _filtroStatus) {
              return false;
            }
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
        _soloPendientes = false; // Limpiar filtro de pendientes si se selecciona otro status
      }
    });
    _aplicarFiltros();
  }

  void _toggleSoloPendientes() {
    setState(() {
      _soloPendientes = !_soloPendientes;
      if (_soloPendientes) {
        _filtroStatus = 'todos'; // Limpiar filtro de status si se selecciona pendientes
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
        _loadEstadisticasRol(); // 🆕 Recargar estadísticas
      }
    });
  }

  void _crearNuevaSancion() {
    Navigator.pushNamed(context, '/create_sancion').then((result) {
      if (result == true) {
        _loadSanciones();
        _loadEstadisticasRol(); // 🆕 Recargar estadísticas
      }
    });
  }

  void _onSancionStatusChanged() {
    _loadSanciones(); // Recargar cuando cambie el status de una sanción
    _loadEstadisticasRol(); // 🆕 Recargar estadísticas
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