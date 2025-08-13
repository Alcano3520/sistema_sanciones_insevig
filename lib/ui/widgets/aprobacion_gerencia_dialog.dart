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
  String _codigoSeleccionado = 'LIBRE'; // ✅ LIBRE POR DEFECTO
  final _comentarioController = TextEditingController();
  bool _aprobar = true;

  /// Códigos de descuento predefinidos para Gerencia
  static const Map<String, String> codigosDescuento = {
    'D00%': 'Sin descuento',
    'D05%': 'Descuento 5%',
    'D10%': 'Descuento 10%',
    'D15%': 'Descuento 15%',
    'D20%': 'Descuento 20%',
    'LIBRE': 'Comentario libre', // ✅ TEXTO MÁS CORTO
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
      content: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7, // ✅ ALTURA MÁXIMA FIJA
        width: MediaQuery.of(context).size.width * 0.75,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(), // ✅ AGREGADO
          child: Column(
            mainAxisSize: MainAxisSize.min, // ✅ AGREGADO
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Resumen de sanción
              _buildResumenSancion(),

              const SizedBox(height: 8), // ✅ REDUCIDO de 12 a 8

              // Toggle Aprobar/Rechazar
              const Text(
                'Decisión:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6), // ✅ REDUCIDO de 8 a 6
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

              const SizedBox(height: 8), // ✅ REDUCIDO de 12 a 8

              // Si aprueba: selector de código descuento
              if (_aprobar) ...[
                const Text(
                  'Código de Descuento:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6), // ✅ REDUCIDO de 8 a 6
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _codigoSeleccionado,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), // ✅ REDUCIDO vertical de 12 a 8
                    ),
                    items: codigosDescuento.entries.map((entry) =>
                        DropdownMenuItem(
                          value: entry.key,
                          child: Flexible( // ✅ ENVUELTO EN FLEXIBLE
                            child: Text(
                              '${entry.key} - ${entry.value}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF1E3A8A),
                              ),
                              overflow: TextOverflow.ellipsis, // ✅ AGREGADO OVERFLOW
                            ),
                          ),
                        )).toList(),
                    onChanged: (value) => setState(() => _codigoSeleccionado = value!),
                  ),
                ),

                const SizedBox(height: 8), // ✅ REDUCIDO de 12 a 8

                // Vista previa del código seleccionado
                Container(
                  padding: const EdgeInsets.all(6), // ✅ REDUCIDO de 8 a 6
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6), // ✅ REDUCIDO de 8 a 6
                    border: Border.all(color: Colors.blue.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min, // ✅ AGREGADO
                    children: [
                      Text(
                        _codigoSeleccionado == 'LIBRE' 
                            ? 'Modalidad seleccionada:' // ✅ TEXTO DIFERENTE PARA LIBRE
                            : 'Código seleccionado:',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11, // ✅ REDUCIDO de 12 a 11
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 2), // ✅ REDUCIDO de 4 a 2
                      Flexible( // ✅ ENVUELTO EN FLEXIBLE
                        child: Text(
                          codigosDescuento[_codigoSeleccionado]!,
                          style: const TextStyle(fontSize: 12), // ✅ REDUCIDO de 14 a 12
                          maxLines: 1, // ✅ REDUCIDO de 2 a 1
                          overflow: TextOverflow.ellipsis, // ✅ AGREGADO
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8), // ✅ REDUCIDO de 12 a 8
              ],

              // Campo comentarios
              Text(
                _aprobar 
                    ? (_codigoSeleccionado == 'LIBRE' 
                        ? 'Comentarios (opcional):' // ✅ NUEVO: específico para modo libre
                        : 'Comentarios adicionales:')
                    : 'Motivo del rechazo (obligatorio):',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14, // ✅ REDUCIDO de 16 a 14
                ),
              ),
              const SizedBox(height: 6), // ✅ REDUCIDO de 8 a 6
              TextField(
                controller: _comentarioController,
                maxLines: 2, // ✅ REDUCIDO de 3 a 2
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: _aprobar
                      ? (_codigoSeleccionado == 'LIBRE' 
                          ? 'Comentario libre (opcional)...' // ✅ NUEVO: específico para modo libre
                          : 'Justificación del código seleccionado...')
                      : 'Explique por qué se rechaza...',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  contentPadding: const EdgeInsets.all(8), // ✅ AGREGADO PADDING REDUCIDO
                ),
              ),

              if (_aprobar) ...[
                const SizedBox(height: 8), // ✅ REDUCIDO de 12 a 8
                Container(
                  padding: const EdgeInsets.all(6), // ✅ REDUCIDO de 8 a 6
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6), // ✅ REDUCIDO de 8 a 6
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min, // ✅ AGREGADO PARA EVITAR OVERFLOW
                    children: [
                      const Text(
                        'Formato final:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 11, // ✅ REDUCIDO de 12 a 11
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 2), // ✅ REDUCIDO de 4 a 2
                      Flexible( // ✅ ENVUELTO EN FLEXIBLE
                        child: Text(
                          _getFormatoFinal(),
                          style: const TextStyle(
                            fontSize: 11, // ✅ REDUCIDO de 12 a 11
                            fontFamily: 'monospace',
                          ),
                          maxLines: 2, // ✅ REDUCIDO de 3 a 2
                          overflow: TextOverflow.ellipsis, // ✅ AGREGADO OVERFLOW
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
        ElevatedButton( // ✅ CAMBIADO: eliminado .icon
          onPressed: _procesarAprobacion,
          style: ElevatedButton.styleFrom(
            backgroundColor: _aprobar ? Colors.green : Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // ✅ REDUCIDO PADDING
          ),
          child: Text(_aprobar ? 'Aprobar' : 'Rechazar'),
        ),
      ],
    );
  }

  /// Construir resumen visual de la sanción
  Widget _buildResumenSancion() {
    return Container(
      padding: const EdgeInsets.all(12), // ✅ REDUCIDO de 16 a 12
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8), // ✅ REDUCIDO de 12 a 8
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6), // ✅ REDUCIDO de 8 a 6
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6), // ✅ REDUCIDO de 8 a 6
                ),
                child: Text(
                  widget.sancion.tipoSancionEmoji,
                  style: const TextStyle(fontSize: 18), // ✅ REDUCIDO de 20 a 18
                ),
              ),
              const SizedBox(width: 8), // ✅ REDUCIDO de 12 a 8
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.sancion.tipoSancion,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14, // ✅ REDUCIDO de 16 a 14
                      ),
                    ),
                    Text(
                      widget.sancion.empleadoNombre,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12, // ✅ REDUCIDO de 14 a 12
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8), // ✅ REDUCIDO de 12 a 8

          // Detalles de la sanción (solo los esenciales)
          _buildDetalleItem(Icons.person, 'Empleado', widget.sancion.empleadoNombre),
          _buildDetalleItem(Icons.calendar_today, 'Fecha', widget.sancion.fechaFormateada),
          _buildDetalleItem(Icons.access_time, 'Hora', widget.sancion.hora),
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
    if (!_aprobar) {
      return _comentarioController.text.isEmpty 
          ? '[motivo del rechazo]' 
          : _comentarioController.text;
    }

    if (_codigoSeleccionado == 'LIBRE') {
      return _comentarioController.text.isEmpty 
          ? '(sin comentarios)' // ✅ CAMBIADO: mensaje más claro para modo libre vacío
          : _comentarioController.text; // ✅ Solo el comentario, sin "LIBRE -"
    }

    final comentario = _comentarioController.text.isEmpty 
        ? '[escriba su comentario]' 
        : _comentarioController.text;
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

    // ✅ ELIMINADA: Validación de comentarios obligatorios para modo LIBRE
    // Ahora el modo LIBRE permite guardar sin comentarios

    // Validar comentarios para códigos específicos (opcional pero recomendado)
    if (_aprobar && _codigoSeleccionado != 'LIBRE' && _comentarioController.text.trim().isEmpty) {
      showDialog<bool>(
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
              onPressed: () {
                Navigator.pop(context, true);
                _finalizarAprobacion();
              },
              child: const Text('Continuar'),
            ),
          ],
        ),
      );
      return;
    }

    _finalizarAprobacion();
  }

  /// ✅ NUEVO: Finalizar el proceso de aprobación
  void _finalizarAprobacion() {
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