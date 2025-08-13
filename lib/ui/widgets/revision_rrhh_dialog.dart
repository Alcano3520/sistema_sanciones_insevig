import 'package:flutter/material.dart';
import '../../core/models/sancion_model.dart';

/// Widget especializado para revisión de sanciones por parte de RRHH
/// RRHH tiene poder supremo: puede confirmar, modificar o anular decisiones de gerencia
/// Flujo: Supervisor crea → Gerencia aprueba → **RRHH REVISA Y PROCESA**
class RevisionRrhhDialog extends StatefulWidget {
  final SancionModel sancion;
  final Function(String accion, String? comentariosRrhh, String? nuevosComentariosGerencia) onRevision;

  const RevisionRrhhDialog({
    super.key,
    required this.sancion,
    required this.onRevision,
  });

  @override
  State<RevisionRrhhDialog> createState() => _RevisionRrhhDialogState();
}

class _RevisionRrhhDialogState extends State<RevisionRrhhDialog> {
  String _accionSeleccionada = 'confirmar';
  final _comentariosRrhhController = TextEditingController();
  final _nuevosComentariosGerenciaController = TextEditingController();

  /// Códigos de descuento disponibles para modificación
  static const Map<String, String> codigosDescuento = {
    'D00%': 'Sin descuento (sanción completa)',
    'D05%': 'Descuento 5% (falta menor)',
    'D10%': 'Descuento 10% (circunstancias atenuantes)',
    'D15%': 'Descuento 15% (buen historial laboral)',
    'D20%': 'Descuento 20% (caso especial)',
    'LIBRE': 'Comentario libre sin código',
  };

  @override
  void initState() {
    super.initState();
    // Pre-llenar comentarios gerencia existentes para modificar
    _nuevosComentariosGerenciaController.text = widget.sancion.comentariosGerencia ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E3A8A).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.admin_panel_settings,
              color: Color(0xFF1E3A8A),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          const Text('Revisión RRHH'),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: MediaQuery.of(context).size.width * 0.9,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Mostrar decisión actual de gerencia
              _buildDecisionGerencia(),

              const SizedBox(height: 20),

              // Selector de acción RRHH
              const Text(
                'Acción RRHH:',
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
                  value: _accionSeleccionada,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'confirmar',
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 20),
                          SizedBox(width: 8),
                          Text('Confirmar decisión gerencia'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'modificar',
                      child: Row(
                        children: [
                          Icon(Icons.edit, color: Colors.blue, size: 20),
                          SizedBox(width: 8),
                          Text('Modificar código/comentarios gerencia'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'anular',
                      child: Row(
                        children: [
                          Icon(Icons.cancel, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Anular y rechazar sanción'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'procesar',
                      child: Row(
                        children: [
                          Icon(Icons.assignment_turned_in, color: Colors.orange, size: 20),
                          SizedBox(width: 8),
                          Text('Procesar sin cambios'),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _accionSeleccionada = value!),
                ),
              ),

              const SizedBox(height: 16),

              // Información sobre la acción seleccionada
              _buildInfoAccion(),

              const SizedBox(height: 16),

              // Si modifica: permitir editar comentarios gerencia
              if (_accionSeleccionada == 'modificar') ...[
                const Text(
                  'Modificar comentarios gerencia:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),

                // Selector de código rápido
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: codigosDescuento.keys.map((codigo) => 
                    InkWell(
                      onTap: () => _aplicarCodigoRapido(codigo),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A8A).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF1E3A8A).withOpacity(0.3)),
                        ),
                        child: Text(
                          codigo,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ),
                    ),
                  ).toList(),
                ),

                const SizedBox(height: 8),

                TextField(
                  controller: _nuevosComentariosGerenciaController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    hintText: 'D10% - Modificar código o comentario...',
                    labelText: 'Nuevos comentarios gerencia',
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Comentarios RRHH (siempre)
              const Text(
                'Comentarios RRHH:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _comentariosRrhhController,
                maxLines: 3,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: _getHintByAction(),
                  labelText: 'Observaciones RRHH',
                ),
              ),
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
          onPressed: _procesarRevision,
          icon: Icon(_getIconByAction()),
          label: Text(_getLabelByAction()),
          style: ElevatedButton.styleFrom(
            backgroundColor: _getColorByAction(),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ],
    );
  }

  /// Mostrar decisión actual de gerencia
  Widget _buildDecisionGerencia() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.business, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Decisión Gerencia:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          _buildDecisionItem(Icons.info, 'Status', widget.sancion.statusText),
          
          if (widget.sancion.comentariosGerencia != null) ...[
            _buildDecisionItem(Icons.comment, 'Comentarios', widget.sancion.comentariosGerencia!),
            
            // Mostrar código de descuento si existe
            if (widget.sancion.codigoDescuento != null) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Text(
                  'Código: ${widget.sancion.codigoDescuento}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ],
          ],

          _buildDecisionItem(Icons.person, 'Revisado por', widget.sancion.reviewedBy ?? 'N/A'),
          
          if (widget.sancion.fechaRevision != null)
            _buildDecisionItem(Icons.schedule, 'Fecha revisión', 
                '${widget.sancion.fechaRevision!.day}/${widget.sancion.fechaRevision!.month}/${widget.sancion.fechaRevision!.year}'),
        ],
      ),
    );
  }

  /// Widget para mostrar un item de decisión
  Widget _buildDecisionItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: Colors.grey.shade600),
          const SizedBox(width: 6),
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

  /// Información sobre la acción seleccionada
  Widget _buildInfoAccion() {
    String titulo;
    String descripcion;
    Color color;
    IconData icon;

    switch (_accionSeleccionada) {
      case 'confirmar':
        titulo = 'Confirmar Decisión';
        descripcion = 'Se mantendrá la decisión de gerencia tal como está. Solo se agregarán sus comentarios RRHH.';
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'modificar':
        titulo = 'Modificar Decisión';
        descripcion = 'Puede cambiar el código de descuento y/o comentarios de gerencia. La sanción mantendrá status "aprobado".';
        color = Colors.blue;
        icon = Icons.edit;
        break;
      case 'anular':
        titulo = 'Anular Sanción';
        descripcion = 'La sanción será rechazada completamente, anulando la decisión de gerencia. Status cambiará a "rechazado".';
        color = Colors.red;
        icon = Icons.cancel;
        break;
      case 'procesar':
        titulo = 'Procesar Sin Cambios';
        descripcion = 'Se procesará la sanción manteniendo la decisión de gerencia, agregando solo observaciones RRHH.';
        color = Colors.orange;
        icon = Icons.assignment_turned_in;
        break;
      default:
        titulo = 'Acción';
        descripcion = 'Seleccione una acción';
        color = Colors.grey;
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  descripcion,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Aplicar código de descuento rápido
  void _aplicarCodigoRapido(String codigo) {
    if (codigo == 'LIBRE') {
      _nuevosComentariosGerenciaController.text = '';
    } else {
      final comentarioActual = _nuevosComentariosGerenciaController.text;
      final sinCodigo = comentarioActual.contains(' - ') 
          ? comentarioActual.split(' - ').sublist(1).join(' - ')
          : comentarioActual;
      
      _nuevosComentariosGerenciaController.text = sinCodigo.isEmpty 
          ? '$codigo - '
          : '$codigo - $sinCodigo';
    }
  }

  /// Hint según la acción
  String _getHintByAction() {
    switch (_accionSeleccionada) {
      case 'confirmar':
        return 'Procesado según decisión gerencia...';
      case 'modificar':
        return 'Justificación de la modificación...';
      case 'anular':
        return 'Motivo de anulación...';
      case 'procesar':
        return 'Comentarios del procesamiento...';
      default:
        return 'Comentarios RRHH...';
    }
  }

  /// Icono según la acción
  IconData _getIconByAction() {
    switch (_accionSeleccionada) {
      case 'confirmar':
        return Icons.check_circle;
      case 'modificar':
        return Icons.edit;
      case 'anular':
        return Icons.cancel;
      case 'procesar':
        return Icons.assignment_turned_in;
      default:
        return Icons.check;
    }
  }

  /// Label según la acción
  String _getLabelByAction() {
    switch (_accionSeleccionada) {
      case 'confirmar':
        return 'Confirmar';
      case 'modificar':
        return 'Modificar';
      case 'anular':
        return 'Anular';
      case 'procesar':
        return 'Procesar';
      default:
        return 'Procesar';
    }
  }

  /// Color según la acción
  Color _getColorByAction() {
    switch (_accionSeleccionada) {
      case 'confirmar':
        return Colors.green;
      case 'modificar':
        return Colors.blue;
      case 'anular':
        return Colors.red;
      case 'procesar':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  /// Procesar la revisión RRHH
  void _procesarRevision() {
    if (_comentariosRrhhController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 8),
              Text('Los comentarios RRHH son obligatorios'),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Validar modificaciones si es necesario
    if (_accionSeleccionada == 'modificar' && _nuevosComentariosGerenciaController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.warning, color: Colors.white),
              SizedBox(width: 8),
              Text('Debe especificar los nuevos comentarios de gerencia'),
            ],
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.pop(context);

    final comentariosRrhh = _comentariosRrhhController.text.trim();
    final nuevosComentariosGerencia = _accionSeleccionada == 'modificar'
        ? _nuevosComentariosGerenciaController.text.trim()
        : null;

    widget.onRevision(_accionSeleccionada, comentariosRrhh, nuevosComentariosGerencia);
  }

  @override
  void dispose() {
    _comentariosRrhhController.dispose();
    _nuevosComentariosGerenciaController.dispose();
    super.dispose();
  }
}