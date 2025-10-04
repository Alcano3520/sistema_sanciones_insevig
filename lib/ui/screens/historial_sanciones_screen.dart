import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

// 🔥 NUEVAS IMPORTACIONES PARA PDF
import '../../core/services/pdf_service.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';

// ✅ NUEVAS IMPORTACIONES PARA SISTEMA JERÁRQUICO
import '../widgets/aprobacion_gerencia_dialog.dart';
import '../widgets/revision_rrhh_dialog.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/models/sancion_model.dart';
import '../../core/offline/sancion_repository.dart';
import '../widgets/sancion_card.dart';
import '../widgets/filtros_dialog.dart';
import 'detalle_sancion_screen.dart';

/// Pantalla de historial de sanciones - Como tu PantallaHistorial de Kivy
/// Incluye filtros, búsqueda y visualización completa de sanciones
/// 🔥 AHORA CON GENERACIÓN DE REPORTES PDF
/// ✅ SISTEMA JERÁRQUICO: Supervisor → Gerencia → RRHH
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

  // ✅ NUEVAS VARIABLES PARA SISTEMA JERÁRQUICO
  TabController? _tabController;
  int _pendientesGerencia = 0;
  int _pendientesRrhh = 0;
  String _currentUserRole = '';
  bool _modoAprobacion = false;

  @override
  void initState() {
    super.initState();
    _initializeForRole();
    _loadSanciones();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  /// ✅ NUEVO: Inicializar según el rol del usuario
  void _initializeForRole() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser!;
    _currentUserRole = user.role;

    print('🔧 Inicializando para rol: $_currentUserRole');

    // TabController específico por rol
    if (user.canApprove) {
      if (user.role == 'gerencia') {
        _tabController = TabController(length: 2, vsync: this);
        print('👔 TabController gerencia configurado (2 tabs)');
        // Tab 1: Todas, Tab 2: Pendientes para gerencia
      } else if (user.role == 'rrhh') {
        _tabController = TabController(length: 3, vsync: this);
        print('🧑‍💼 TabController RRHH configurado (3 tabs)');
        // Tab 1: Todas, Tab 2: De Gerencia, Tab 3: Pendientes RRHH
      } else if (user.role == 'aprobador') {
        _tabController = TabController(length: 2, vsync: this);
        print('✅ TabController aprobador configurado (2 tabs)');
        // Tab 1: Todas, Tab 2: Pendientes para aprobación
      }

      _tabController?.addListener(() {
        final newIndex = _tabController!.index;
        final wasApprovalMode = _modoAprobacion;

        setState(() {
          _modoAprobacion = newIndex > 0;
        });

        print(
            '📑 Tab cambiado a: $newIndex, Modo aprobación: $_modoAprobacion');

        // Solo recargar si cambió de tab o entró/salió del modo aprobación
        if (wasApprovalMode != _modoAprobacion || _modoAprobacion) {
          _loadSancionesByTab();
        }
      });

      // Cargar contadores iniciales
      _updateContadores();
    }
  }

  /// ✅ NUEVO: Cargar sanciones según tab y rol
  Future<void> _loadSancionesByTab() async {
    if (_tabController == null) return;

    final tabIndex = _tabController!.index;

    setState(() => _isLoading = true);

    try {
      List<SancionModel> sanciones = [];

      switch (_currentUserRole) {
        case 'gerencia':
          if (tabIndex == 1) {
            // ✅ CORREGIDO: SOLO sanciones status='enviado' (pendientes de gerencia)
            print('🔍 Cargando sanciones ENVIADAS para gerencia...');
            sanciones = await _sancionRepository.getSancionesByRol('gerencia');
            print('📋 Encontradas ${sanciones.length} sanciones enviadas');
          } else {
            // Tab "Todas" - cargar todas las sanciones
            sanciones = await _sancionRepository.getAllSanciones();
          }
          break;

        case 'rrhh':
          if (tabIndex == 1) {
            // Cargar sanciones aprobadas por gerencia (esperando RRHH)
            sanciones = await _sancionRepository.getSancionesByRol('rrhh');
          } else if (tabIndex == 2) {
            // Cargar todas las pendientes RRHH (mismo que tab 1 para RRHH)
            sanciones = await _sancionRepository.getSancionesByRol('rrhh');
          } else {
            sanciones = await _sancionRepository.getAllSanciones();
          }
          break;

        case 'aprobador':
          if (tabIndex == 1) {
            // Cargar sanciones pendientes de aprobación
            sanciones = await _sancionRepository.getSancionesPendientes();
          } else {
            sanciones = await _sancionRepository.getAllSanciones();
          }
          break;

        default:
          sanciones = await _sancionRepository.getAllSanciones();
      }

      if (mounted) {
        setState(() {
          _sanciones = sanciones;
          _isLoading = false;
        });

        // ✅ IMPORTANTE: NO aplicar filtros adicionales en modo aprobación
        if (_modoAprobacion) {
          setState(() {
            _sancionesFiltradas =
                sanciones; // Usar directamente las sanciones cargadas
          });
        } else {
          _aplicarFiltros(); // Solo aplicar filtros en modo "Todas"
        }
      }
    } catch (e) {
      print('❌ Error en _loadSancionesByTab: $e');
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

  /// ✅ NUEVO: Actualizar contadores
  Future<void> _updateContadores() async {
    try {
      final contadores =
          await _sancionRepository.getContadoresPorRol(_currentUserRole);
      if (mounted) {
        setState(() {
          _pendientesGerencia = contadores['pendientes_gerencia'] ?? 0;
          _pendientesRrhh = contadores['pendientes_rrhh'] ?? 0;
        });
      }
    } catch (e) {
      print('Error actualizando contadores: $e');
    }
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
          if (!_isLoading && !_modoAprobacion) _buildQuickStats(),

          // ✅ NUEVO: Indicador especial para modo aprobación
          if (!_isLoading && _modoAprobacion) _buildModoAprobacionHeader(),

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

  /// ✅ NUEVO: AppBar específico por rol con tabs
  PreferredSizeWidget _buildAppBar() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser!;

    return AppBar(
      title: Text(_getTitleByRole()),
      backgroundColor: const Color(0xFF1E3A8A),
      foregroundColor: Colors.white,
      elevation: 0,

      // TabBar específico por rol
      bottom: user.canApprove && _tabController != null
          ? TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              tabs: _getTabsByRole(),
            )
          : null,

      actions: [
        // Botón específico para aprobación con códigos
        if (_modoAprobacion && user.role == 'gerencia')
          IconButton(
            icon: const Icon(Icons.percent),
            onPressed: _showCodigosDescuentoInfo,
            tooltip: 'Códigos de descuento',
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
        // 🔥 BOTÓN PDF AGREGADO
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

  /// ✅ NUEVO: Títulos específicos por rol
  String _getTitleByRole() {
    switch (_currentUserRole) {
      case 'gerencia':
        return 'Aprobaciones Gerencia';
      case 'rrhh':
        return 'Gestión RRHH';
      case 'aprobador':
        return 'Aprobaciones';
      default:
        return 'Historial de Sanciones';
    }
  }

  /// ✅ NUEVO: Tabs específicos por rol
  List<Widget> _getTabsByRole() {
    switch (_currentUserRole) {
      case 'gerencia':
        return [
          const Tab(text: 'Todas'),
          Tab(text: 'Pendientes ($_pendientesGerencia)'),
        ];
      case 'rrhh':
        return [
          const Tab(text: 'Todas'),
          Tab(text: 'De Gerencia ($_pendientesGerencia)'),
          Tab(text: 'Pendientes ($_pendientesRrhh)'),
        ];
      case 'aprobador':
        return [
          const Tab(text: 'Todas'),
          Tab(text: 'Pendientes ($_pendientesGerencia)'),
        ];
      default:
        return [const Tab(text: 'Todas')];
    }
  }

  /// ✅ NUEVO: Mostrar información de códigos de descuento
  void _showCodigosDescuentoInfo() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.percent, color: Color(0xFF1E3A8A)),
            SizedBox(width: 8),
            Text('Códigos de Descuento'),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Códigos disponibles:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              _CodigoDescuentoItem('D00%', 'Sin descuento (sanción normal)'),
              _CodigoDescuentoItem('D05%', 'Descuento 5% (falta menor)'),
              _CodigoDescuentoItem(
                  'D10%', 'Descuento 10% (circunstancias atenuantes)'),
              _CodigoDescuentoItem('D15%', 'Descuento 15% (caso especial)'),
              _CodigoDescuentoItem('D20%', 'Descuento 20% (sancion grave)'),
              _CodigoDescuentoItem('LIBRE', 'Comentario libre sin código'),
              SizedBox(height: 16),
              Text(
                'El código se agregará automáticamente a los comentarios con el formato: "D10% - Su comentario"',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
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

    // Calcular inicio de la semana actual (lunes = 1, domingo = 7)
    final ahora = DateTime.now();
    final inicioSemana = ahora.subtract(Duration(days: ahora.weekday - 1));
    final inicioSemanaSinHora = DateTime(
      inicioSemana.year,
      inicioSemana.month,
      inicioSemana.day,
    );

    final ultimaSemana = _sanciones.where((s) {
      final fechaCreacion = DateTime(
        s.createdAt.year,
        s.createdAt.month,
        s.createdAt.day,
      );
      return !fechaCreacion.isBefore(inicioSemanaSinHora);
    }).length;

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

  /// ✅ NUEVO: Header especial para modo aprobación
  Widget _buildModoAprobacionHeader() {
    final total = _sancionesFiltradas.length;
    final roleText = _currentUserRole == 'gerencia' ? 'GERENCIA' : 'RRHH';

    // ✅ DEBUG: Log del estado actual
    print('🎯 Header modo aprobación:');
    print('   - Role: $_currentUserRole');
    print('   - Total filtradas: $total');
    print('   - Pendientes gerencia: $_pendientesGerencia');
    print('   - Modo aprobación: $_modoAprobacion');

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1E3A8A),
            const Color(0xFF3B82F6),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _currentUserRole == 'gerencia'
                  ? Icons.business
                  : Icons.admin_panel_settings,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MODO APROBACIÓN $roleText',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  total > 0
                      ? '$total sanciones pendientes de revisión'
                      : '¡Excelente! No hay sanciones pendientes',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (total > 0) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$total',
                style: const TextStyle(
                  color: Color(0xFF1E3A8A),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
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
              // ✅ NUEVO: Callbacks específicos para aprobación
              onApprobar: _modoAprobacion && _currentUserRole == 'gerencia'
                  ? () => _mostrarDialogoAprobacionGerencia(sancion)
                  : null,
              onRechazar: _modoAprobacion && _currentUserRole == 'gerencia'
                  ? () => _rechazarSancionGerencia(sancion)
                  : null,
              onRevisionRrhh: _modoAprobacion && _currentUserRole == 'rrhh'
                  ? () => _mostrarDialogoRevisionRrhh(sancion)
                  : null,
            ),
          );
        },
      ),
    );
  }

  /// ✅ NUEVO: Mostrar diálogo de aprobación para gerencia
  void _mostrarDialogoAprobacionGerencia(SancionModel sancion) {
    showDialog(
      context: context,
      builder: (context) => AprobacionGerenciaDialog(
        sancion: sancion,
        onApprove: (codigo, comentario) =>
            _aprobarConCodigoGerencia(sancion, codigo, comentario),
        onReject: (comentario) =>
            _rechazarConComentarioGerencia(sancion, comentario),
      ),
    );
  }

  /// ✅ NUEVO: Aprobar sanción con código de descuento
  Future<void> _aprobarConCodigoGerencia(
    SancionModel sancion,
    String codigo,
    String comentario,
  ) async {
    try {
      print('👔 Iniciando aprobación: ${sancion.id} con código $codigo');

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser!.id;

      final success = await _sancionRepository.aprobarConCodigoGerencia(
        sancion.id,
        codigo,
        comentario,
        userId,
      );

      if (success && mounted) {
        print('✅ Aprobación exitosa, iniciando recarga...');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('✅ Sanción aprobada con código $codigo'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1), // ✅ Más rápido
          ),
        );

        // ✅ RECARGA INMEDIATA Y ESPECÍFICA
        await _recargarModoAprobacion();

        print('🎉 Proceso de aprobación completado');
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Error aprobando sanción'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('❌ Error en aprobación: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// ✅ NUEVO: Rechazar sanción con comentario (gerencia)
  Future<void> _rechazarConComentarioGerencia(
    SancionModel sancion,
    String comentario,
  ) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser!.id;

      final success = await _sancionRepository.changeStatus(
        sancion.id,
        'rechazado',
        comentarios: comentario,
        reviewedBy: userId,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.cancel, color: Colors.white),
                SizedBox(width: 8),
                Text('❌ Sanción rechazada por gerencia'),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2), // ✅ Reducido para fluidez
          ),
        );

        // ✅ AUTO-ACTUALIZACIÓN INTELIGENTE
        await _recargarModoAprobacion();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// ✅ NUEVO: Rechazar sanción rápida (gerencia)
  Future<void> _rechazarSancionGerencia(SancionModel sancion) async {
    final comentario = await _showComentarioDialog(
      'Rechazar Sanción',
      'Motivo del rechazo (obligatorio):',
      'Explique por qué se rechaza esta sanción...',
    );

    if (comentario != null && comentario.isNotEmpty) {
      await _rechazarConComentarioGerencia(sancion, comentario);
    }
  }

  /// ✅ NUEVO: Mostrar diálogo de revisión para RRHH
  void _mostrarDialogoRevisionRrhh(SancionModel sancion) {
    showDialog(
      context: context,
      builder: (context) => RevisionRrhhDialog(
        sancion: sancion,
        onRevision: (accion, comentariosRrhh, nuevosComentariosGerencia) =>
            _procesarRevisionRrhh(sancion, accion, comentariosRrhh ?? '',
                nuevosComentariosGerencia),
      ),
    );
  }

  /// ✅ NUEVO: Procesar revisión RRHH
  Future<void> _procesarRevisionRrhh(
    SancionModel sancion,
    String accion,
    String comentariosRrhh,
    String? nuevosComentariosGerencia,
  ) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final userId = authProvider.currentUser!.id;

      final success = await _sancionRepository.revisionRrhh(
        sancion.id,
        accion,
        comentariosRrhh,
        userId,
        nuevosComentariosGerencia: nuevosComentariosGerencia,
      );

      if (success && mounted) {
        String mensaje;
        switch (accion) {
          case 'confirmar':
            mensaje = '✅ Decisión gerencia confirmada por RRHH';
            break;
          case 'modificar':
            mensaje = '✏️ Decisión gerencia modificada por RRHH';
            break;
          case 'anular':
            mensaje = '❌ Sanción anulada por RRHH';
            break;
          case 'procesar':
            mensaje = '📋 Sanción procesada por RRHH';
            break;
          default:
            mensaje = '✅ Revisión RRHH completada';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensaje),
            backgroundColor: accion == 'anular' ? Colors.red : Colors.green,
            duration: const Duration(seconds: 2), // ✅ Reducido para fluidez
          ),
        );

        // ✅ AUTO-ACTUALIZACIÓN INTELIGENTE
        await _recargarModoAprobacion();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error en revisión RRHH: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// ✅ NUEVO: Diálogo genérico para comentarios
  Future<String?> _showComentarioDialog(
    String title,
    String label,
    String hint,
  ) async {
    final controller = TextEditingController();

    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  /// ✅ NUEVO: Recarga inteligente para modo aprobación
  Future<void> _recargarModoAprobacion() async {
    // Indicador visual de actualización (opcional)
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      // Actualizar contadores primero
      await _updateContadores();

      // Si está en modo aprobación, recargar por tab específico
      if (_modoAprobacion && _tabController != null) {
        print('🔄 Recargando modo aprobación - Tab: ${_tabController!.index}');
        await _loadSancionesByTab();
      } else {
        // Si no está en modo aprobación, recarga normal
        await _loadSanciones();
      }
    } finally {
      // Restaurar estado de carga
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
        final user = authProvider.currentUser;

        // ✅ MEJORADO: Gerencia también puede crear sanciones
        if (user == null || !user.canCreateSanciones) {
          return const SizedBox.shrink();
        }

        return FloatingActionButton.extended(
          onPressed: _crearNuevaSancion,
          backgroundColor: const Color(0xFF1E3A8A),
          icon: const Icon(Icons.add, color: Colors.white),
          label: Text(
            _modoAprobacion ? 'Nueva Sanción' : 'Crear Sanción',
            style: const TextStyle(color: Colors.white),
          ),
        );
      },
    );
  }

  // ==========================================
  // 🔥 FUNCIONALIDADES PDF AGREGADAS
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
                    Text('Filtro estado: $_filtroStatus',
                        style: const TextStyle(fontSize: 12)),
                  if (_soloPendientes)
                    const Text('Solo pendientes: Sí',
                        style: TextStyle(fontSize: 12)),
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
              subtitle: Text(
                  '${_sancionesFiltradas.length} sanciones con filtros actuales'),
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
      descripcion:
          'Sanciones del ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
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
        // Comparar solo fechas, no horas
        final fechaSancion = DateTime(
          sancion.fecha.year,
          sancion.fecha.month,
          sancion.fecha.day,
        );
        final inicioRango = DateTime(
          dateRange.start.year,
          dateRange.start.month,
          dateRange.start.day,
        );
        final finRango = DateTime(
          dateRange.end.year,
          dateRange.end.month,
          dateRange.end.day,
        );

        return !fechaSancion.isBefore(inicioRango) &&
            !fechaSancion.isAfter(finRango);
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
        descripcion:
            'Del ${dateRange.start.day}/${dateRange.start.month}/${dateRange.start.year} al ${dateRange.end.day}/${dateRange.end.month}/${dateRange.end.year}',
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
  void _showReportePDFDialog(
      Uint8List pdfBytes, String filename, int totalSanciones) {
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
                Text('🔤 Reporte listo para compartir'),
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
      filtros.add(
          'Rango: ${_rangoFechas!.start.day}/${_rangoFechas!.start.month} - ${_rangoFechas!.end.day}/${_rangoFechas!.end.month}');
    }

    if (filtros.isEmpty) {
      return 'Todas las sanciones';
    }

    return filtros.join(' • ');
  }

  // ==========================================
  // 🔧 FUNCIONES ORIGINALES DE CARGA Y FILTRADO
  // ==========================================

  // Funciones de carga y filtrado
  Future<void> _loadSanciones() async {
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser!;

      print('📋 Cargando sanciones para ${user.role}...');

      List<SancionModel> sanciones;

      if (user.canViewAllSanciones && !_soloMias) {
        // Gerencia/RRHH pueden ver todas
        sanciones = await _sancionRepository.getAllSanciones();
        print('👀 Cargadas ${sanciones.length} sanciones (todas)');
      } else {
        // Supervisores solo ven las suyas
        sanciones = await _sancionRepository.getMySanciones(user.id);
        print('👤 Cargadas ${sanciones.length} sanciones (propias)');
      }

      if (mounted) {
        setState(() {
          _sanciones = sanciones;
          _isLoading = false;
        });
        _aplicarFiltros();
        await _updateContadores();

        print('✅ Carga de sanciones completada');
      }
    } catch (e) {
      print('❌ Error cargando sanciones: $e');
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

        // Filtro por rango de fechas (solo comparar fechas, no horas)
        if (_rangoFechas != null) {
          final fechaSancion = DateTime(
            sancion.fecha.year,
            sancion.fecha.month,
            sancion.fecha.day,
          );
          final inicioRango = DateTime(
            _rangoFechas!.start.year,
            _rangoFechas!.start.month,
            _rangoFechas!.start.day,
          );
          final finRango = DateTime(
            _rangoFechas!.end.year,
            _rangoFechas!.end.month,
            _rangoFechas!.end.day,
          );

          if (fechaSancion.isBefore(inicioRango) ||
              fechaSancion.isAfter(finRango)) {
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
    // ✅ MEJORADO: Usar recarga inteligente también aquí
    if (_modoAprobacion) {
      _recargarModoAprobacion();
    } else {
      _loadSanciones(); // Recargar cuando cambie el status de una sanción
    }
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

/// ✅ NUEVO: Widget auxiliar para mostrar códigos de descuento
class _CodigoDescuentoItem extends StatelessWidget {
  final String codigo;
  final String descripcion;

  const _CodigoDescuentoItem(this.codigo, this.descripcion);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A8A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
              border:
                  Border.all(color: const Color(0xFF1E3A8A).withOpacity(0.3)),
            ),
            child: Text(
              codigo,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: Color(0xFF1E3A8A),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              descripcion,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
