import 'package:flutter/material.dart';
import '../../core/models/sancion_model.dart';

/// Diálogo de filtros avanzados para el historial de sanciones
class FiltrosDialog extends StatefulWidget {
  final String filtroTipo;
  final bool soloMias;
  final DateTimeRange? rangoFechas;
  final bool canViewAll;
  final Function(String tipo, bool soloMias, DateTimeRange? rango)
      onFiltrosChanged;

  const FiltrosDialog({
    super.key,
    required this.filtroTipo,
    required this.soloMias,
    required this.rangoFechas,
    required this.canViewAll,
    required this.onFiltrosChanged,
  });

  @override
  State<FiltrosDialog> createState() => _FiltrosDialogState();
}

class _FiltrosDialogState extends State<FiltrosDialog> {
  late String _filtroTipo;
  late bool _soloMias;
  DateTimeRange? _rangoFechas;

  @override
  void initState() {
    super.initState();
    _filtroTipo = widget.filtroTipo;
    _soloMias = widget.soloMias;
    _rangoFechas = widget.rangoFechas;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.filter_list, color: Color(0xFF1E3A8A)),
          SizedBox(width: 8),
          Text('Filtros Avanzados'),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filtro por tipo de sanción
              _buildTipoFiltro(),

              const SizedBox(height: 20),

              // Filtro por alcance (solo para gerencia/RRHH)
              if (widget.canViewAll) _buildAlcanceFiltro(),

              const SizedBox(height: 20),

              // Filtro por rango de fechas
              _buildRangoFechasFiltro(),

              const SizedBox(height: 20),

              // Resumen de filtros activos
              _buildResumenFiltros(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _limpiarFiltros,
          child: const Text('Limpiar Todo'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _aplicarFiltros,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E3A8A),
            foregroundColor: Colors.white,
          ),
          child: const Text('Aplicar'),
        ),
      ],
    );
  }

  Widget _buildTipoFiltro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tipo de Sanción',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A8A),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _filtroTipo,
              items: [
                const DropdownMenuItem(
                  value: 'todos',
                  child: Text('Todos los tipos'),
                ),
                ...SancionModel.tiposSancion.map((tipo) {
                  final sancionModel = SancionModel(
                    supervisorId: '',
                    empleadoCod: 0,
                    empleadoNombre: '',
                    puesto: '',
                    agente: '',
                    fecha: DateTime.now(),
                    hora: '',
                    tipoSancion: tipo,
                  );
                  return DropdownMenuItem(
                    value: tipo,
                    child: Text('${sancionModel.tipoSancionEmoji} $tipo'),
                  );
                }),
              ],
              onChanged: (value) {
                setState(() {
                  _filtroTipo = value!;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAlcanceFiltro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Alcance de Búsqueda',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A8A),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              RadioListTile<bool>(
                title: const Text('Solo mis sanciones'),
                subtitle: const Text('Sanciones que yo he creado'),
                value: true,
                groupValue: _soloMias,
                onChanged: (value) {
                  setState(() {
                    _soloMias = value!;
                  });
                },
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFF1E3A8A),
              ),
              RadioListTile<bool>(
                title: const Text('Todas las sanciones'),
                subtitle: const Text('Sanciones de todos los supervisores'),
                value: false,
                groupValue: _soloMias,
                onChanged: (value) {
                  setState(() {
                    _soloMias = value!;
                  });
                },
                contentPadding: EdgeInsets.zero,
                activeColor: const Color(0xFF1E3A8A),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRangoFechasFiltro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Rango de Fechas',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A8A),
          ),
        ),
        const SizedBox(height: 8),

        if (_rangoFechas != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.date_range, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rango seleccionado:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      Text(
                        '${_formatDate(_rangoFechas!.start)} - ${_formatDate(_rangoFechas!.end)}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.clear, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _rangoFechas = null;
                    });
                  },
                  tooltip: 'Quitar filtro de fechas',
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],

        ElevatedButton.icon(
          onPressed: _seleccionarRangoFechas,
          icon: const Icon(Icons.calendar_today),
          label: Text(
              _rangoFechas == null ? 'Seleccionar rango' : 'Cambiar rango'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.grey.shade200,
            foregroundColor: Colors.grey.shade700,
          ),
        ),

        const SizedBox(height: 8),

        // Rangos predefinidos
        Wrap(
          spacing: 8,
          children: [
            _buildRangoPredefinido('Hoy', () => _setRangoPredefinido(0)),
            _buildRangoPredefinido(
                'Esta semana', () => _setRangoPredefinido(7)),
            _buildRangoPredefinido('Este mes', () => _setRangoPredefinido(30)),
            _buildRangoPredefinido(
                'Último trimestre', () => _setRangoPredefinido(90)),
          ],
        ),
      ],
    );
  }

  Widget _buildRangoPredefinido(String label, VoidCallback onTap) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: Colors.grey.shade100,
      side: BorderSide(color: Colors.grey.shade300),
    );
  }

  Widget _buildResumenFiltros() {
    final filtrosActivos = <String>[];

    if (_filtroTipo != 'todos') {
      filtrosActivos.add('Tipo: $_filtroTipo');
    }

    if (widget.canViewAll) {
      filtrosActivos
          .add(_soloMias ? 'Solo mis sanciones' : 'Todas las sanciones');
    }

    if (_rangoFechas != null) {
      filtrosActivos.add(
          'Fechas: ${_formatDate(_rangoFechas!.start)} - ${_formatDate(_rangoFechas!.end)}');
    }

    if (filtrosActivos.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.grey),
            SizedBox(width: 8),
            Text(
              'No hay filtros activos',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Filtros Activos',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A8A),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: filtrosActivos
                .map((filtro) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.check,
                              size: 16, color: Colors.green),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              filtro,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  void _seleccionarRangoFechas() async {
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
      initialDateRange: _rangoFechas,
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

    if (rango != null) {
      setState(() {
        _rangoFechas = rango;
      });
    }
  }

  void _setRangoPredefinido(int dias) {
    final ahora = DateTime.now();
    DateTime inicio;
    DateTime fin;

    if (dias == 0) {
      // "Hoy": desde las 00:00 hasta las 23:59 del día actual
      inicio = DateTime(ahora.year, ahora.month, ahora.day);
      fin = DateTime(ahora.year, ahora.month, ahora.day, 23, 59, 59);
    } else {
      // Otros rangos: desde hace X días a las 00:00 hasta hoy a las 23:59
      inicio = DateTime(ahora.year, ahora.month, ahora.day)
          .subtract(Duration(days: dias));
      fin = DateTime(ahora.year, ahora.month, ahora.day, 23, 59, 59);
    }

    setState(() {
      _rangoFechas = DateTimeRange(
        start: inicio,
        end: fin,
      );
    });
  }

  void _limpiarFiltros() {
    setState(() {
      _filtroTipo = 'todos';
      _soloMias = true;
      _rangoFechas = null;
    });
  }

  void _aplicarFiltros() {
    widget.onFiltrosChanged(_filtroTipo, _soloMias, _rangoFechas);
    Navigator.pop(context);
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
