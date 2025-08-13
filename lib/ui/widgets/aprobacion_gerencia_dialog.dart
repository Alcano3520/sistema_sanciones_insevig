import 'package:flutter/material.dart';
import '../../core/models/sancion_model.dart';

/// Widget especializado para aprobación de sanciones por parte de Gerencia
/// Incluye sistema de códigos de descuento predefinidos
/// Flujo: Supervisor crea → **GERENCIA APRUEBA CON CÓDIGO** → RRHH procesa
class AprobacionGerenciaDialog extends StatefulWidget {
  final SancionModel sancion;
  final Function(String codigo, String comentario) onApprove;
  final Function(String comentario) onReject;

  const AprobacionGerenciaDialog({
    super.key,
    required this.sancion,
    required this.onApprove,
    required this.onReject,
  });

  @override
  State<AprobacionGerenciaDialog> createState() => _AprobacionGerenciaDialogState();
}

class _AprobacionGerenciaDialogState extends State<AprobacionGerenciaDialog> {
  String _codigoSeleccionado = 'D05%';
  final _comentarioController = TextEditingController();
  bool _aprobar = true;

  /// Códigos de descuento predefinidos para Gerencia
  static const Map<String, String> codigosDescuento = {
    'D00%': 'Sin descuento (sanción completa)',
    'D05%': 'Descuento 5% (falta menor)',
    'D10%': 'Descuento 10% (circunstancias atenuantes)',
    'D15%': 'Descuento 15% (buen historial laboral)',
    'D20%': 'Descuento 20% (caso especial)',
    'LIBRE': 'Comentario libre sin código',
  };

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(
            _aprobar ? Icons.check_circle : Icons.cancel,
            color: _aprobar ? Colors.green : Colors.red,
            size: 28,
          ),
          const SizedBox(width: 12),
          const Text('Aprobación Gerencia'),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Resumen de sanción
              _buildResumenSancion(),

              const SizedBox(height: 20),

              // Toggle Aprobar/Rechazar
              const Text(
                'Decisión:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('Aprobar'),
                    icon: Icon(Icons.check_circle),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('Rechazar'),
                    icon: Icon(Icons.cancel),
                  ),
                ],
                selected: {_aprobar},
                onSelectionChanged: (Set<bool> newSelection) {
                  setState(() => _aprobar = newSelection.first);
                },
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: _aprobar 
                      ? Colors.green.withOpacity(0.2) 
                      : Colors.red.withOpacity(0.2),
                  selectedForegroundColor: _aprobar ? Colors.green : Colors.red,
                ),
              ),

              const SizedBox(height: 20),

              // Si aprueba: selector de código descuento
              if (_aprobar) ...[
                const Text(
                  'Código de Descuento:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _codigoSeleccionado,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: codigosDescuento.entries.map((entry) =>
                        DropdownMenuItem(
                          value: entry.key,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                entry.key,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A8A),
                                ),
                              ),
                              Text(
                                entry.value,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        )).toList(),
                    onChanged: (value) => setState(() => _codigoSeleccionado = value!),
                  ),
                ),

                const SizedBox(height: 16),

                // Vista previa del código seleccionado
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
                      const Text(
                        'Código seleccionado:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        codigosDescuento[_codigoSeleccionado]!,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),
              ],

              // Campo comentarios
              Text(
                _aprobar ? 'Comentarios adicionales:' : 'Motivo del rechazo (obligatorio):',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _comentarioController,
                maxLines: 3,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: _aprobar
                      ? 'Justificación del código seleccionado...'
                      : 'Explique por qué se rechaza...',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                ),
              ),

              if (_aprobar) ...[
                const SizedBox(height: 12),
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
                      const Text(
                        'Formato final:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getFormatoFinal(),
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),

      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          onPressed: _procesarAprobacion,
          icon: Icon(_aprobar ? Icons.check_circle : Icons.cancel),
          label: Text(_aprobar ? 'Aprobar' : 'Rechazar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _aprobar ? Colors.green : Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }

  /// Construir resumen visual de la sanción
  Widget _buildResumenSancion() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.sancion.tipoSancionEmoji,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.sancion.tipoSancion,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      widget.sancion.empleadoNombre,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Detalles de la sanción
          _buildDetalleItem(Icons.person, 'Empleado', widget.sancion.empleadoNombre),
          _buildDetalleItem(Icons.badge, 'Código', '#${widget.sancion.empleadoCod}'),
          _buildDetalleItem(Icons.work, 'Puesto', widget.sancion.puesto),
          _buildDetalleItem(Icons.calendar_today, 'Fecha', widget.sancion.fechaFormateada),
          _buildDetalleItem(Icons.access_time, 'Hora', widget.sancion.hora),
          _buildDetalleItem(Icons.security, 'Agente', widget.sancion.agente),

          if (widget.sancion.observaciones != null && widget.sancion.observaciones!.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildDetalleItem(Icons.note, 'Observaciones', widget.sancion.observaciones!),
          ],

          if (widget.sancion.horasExtras != null) ...[
            const SizedBox(height: 8),
            _buildDetalleItem(Icons.schedule, 'Horas Extras', '${widget.sancion.horasExtras} hrs'),
          ],
        ],
      ),
    );
  }

  /// Widget para mostrar un detalle de la sanción
  Widget _buildDetalleItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 16,
            color: Colors.grey.shade600,
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Obtener formato final del comentario
  String _getFormatoFinal() {
    if (!_aprobar) return _comentarioController.text.isEmpty ? '[motivo del rechazo]' : _comentarioController.text;

    if (_codigoSeleccionado == 'LIBRE') {
      return _comentarioController.text.isEmpty ? '[su comentario libre]' : _comentarioController.text;
    }

    final comentario = _comentarioController.text.isEmpty ? '[su comentario]' : _comentarioController.text;
    return '$_codigoSeleccionado - $comentario';
  }

  /// Procesar la aprobación o rechazo
  void _procesarAprobacion() {
    // Validar comentarios obligatorios para rechazo
    if (!_aprobar && _comentarioController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 8),
              Text('Los comentarios son obligatorios para rechazar'),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validar comentarios para códigos específicos (opcional pero recomendado)
    if (_aprobar && _codigoSeleccionado != 'LIBRE' && _comentarioController.text.trim().isEmpty) {
      final shouldContinue = showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirmar sin comentarios'),
          content: Text('¿Está seguro de aprobar con código $_codigoSeleccionado sin comentarios adicionales?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Continuar'),
            ),
          ],
        ),
      );

      if (shouldContinue != true) return;
    }

    Navigator.pop(context);

    if (_aprobar) {
      widget.onApprove(_codigoSeleccionado, _comentarioController.text.trim());
    } else {
      widget.onReject(_comentarioController.text.trim());
    }
  }

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }
}