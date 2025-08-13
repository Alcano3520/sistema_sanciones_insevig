import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models/sancion_model.dart';

/// 🆕 DIÁLOGO PARA PROCESAMIENTO FINAL POR RRHH
/// Permite a RRHH confirmar, modificar o anular decisiones de gerencia
class ProcesamientoRRHHDialog extends StatefulWidget {
  final SancionModel sancion;
  final String accion; // 'confirmar', 'modificar', 'anular'
  final Function(String comentarios, String? nuevoCodigo) onConfirm;

  const ProcesamientoRRHHDialog({
    super.key,
    required this.sancion,
    required this.accion,
    required this.onConfirm,
  });

  @override
  State<ProcesamientoRRHHDialog> createState() => _ProcesamientoRRHHDialogState();
}

class _ProcesamientoRRHHDialogState extends State<ProcesamientoRRHHDialog> {
  final _comentariosController = TextEditingController();
  final _porcentajeController = TextEditingController();
  
  String _nuevoCodigo = 'SIN_DESC';
  bool _usarCustom = false;

  // 🎯 CÓDIGOS DISPONIBLES PARA MODIFICACIÓN
  final List<Map<String, dynamic>> _codigosDisponibles = [
    {
      'codigo': 'SIN_DESC', 
      'label': 'Sin descuento', 
      'color': Colors.green,
      'icon': Icons.check_circle,
    },
    {
      'codigo': 'D05%', 
      'label': '5% descuento', 
      'color': Colors.yellow.shade700,
      'icon': Icons.money_off,
    },
    {
      'codigo': 'D10%', 
      'label': '10% descuento', 
      'color': Colors.orange,
      'icon': Icons.money_off,
    },
    {
      'codigo': 'D15%', 
      'label': '15% descuento', 
      'color': Colors.deepOrange,
      'icon': Icons.money_off,
    },
    {
      'codigo': 'D20%', 
      'label': '20% descuento', 
      'color': Colors.red,
      'icon': Icons.money_off,
    },
    {
      'codigo': 'CUSTOM', 
      'label': 'Personalizado', 
      'color': Colors.purple,
      'icon': Icons.tune,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: _buildTitle(),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.9,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 📋 Información de la sanción y decisión de gerencia
              _buildInfoSancion(),
              
              const SizedBox(height: 20),
              
              // 🔄 Campos específicos según la acción
              if (widget.accion == 'confirmar') _buildSeccionConfirmar(),
              if (widget.accion == 'modificar') _buildSeccionModificar(),
              if (widget.accion == 'anular') _buildSeccionAnular(),
              
              const SizedBox(height: 16),
              
              // 📝 Campo de comentarios RRHH
              _buildCampoComentarios(),
            ],
          ),
        ),
      ),
      actions: _buildActions(),
    );
  }

  // 🏷️ TÍTULO SEGÚN LA ACCIÓN
  Widget _buildTitle() {
    IconData icon;
    Color color;
    String texto;
    
    switch (widget.accion) {
      case 'confirmar':
        icon = Icons.verified;
        color = Colors.teal;
        texto = 'Confirmar Procesamiento';
        break;
      case 'modificar':
        icon = Icons.edit;
        color = Colors.blue;
        texto = 'Modificar Descuento';
        break;
      case 'anular':
        icon = Icons.block;
        color = Colors.red;
        texto = 'Anular Sanción';
        break;
      default:
        icon = Icons.admin_panel_settings;
        color = Colors.grey;
        texto = 'Procesar';
    }
    
    return Row(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(fontSize: 18),
          ),
        ),
      ],
    );
  }

  // 📋 INFORMACIÓN DE LA SANCIÓN
  Widget _buildInfoSancion() {
    final codigoGerencia = _extraerCodigo(widget.sancion.comentariosGerencia ?? '');
    final comentarioGerencia = _extraerComentario(widget.sancion.comentariosGerencia ?? '');
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Información básica
          Row(
            children: [
              Text(
                widget.sancion.tipoSancionEmoji,
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.sancion.tipoSancion,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('👤 ${widget.sancion.empleadoNombre} (${widget.sancion.empleadoCod})'),
          Text('🏢 ${widget.sancion.puesto}'),
          Text('📅 ${widget.sancion.fechaFormateada} ${widget.sancion.hora}'),
          
          const SizedBox(height: 12),
          const Divider(),
          
          // 💰 Decisión de gerencia
          const Row(
            children: [
              Icon(Icons.approval, color: Colors.green, size: 16),
              SizedBox(width: 8),
              Text(
                'Decisión de Gerencia:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getColorForCodigo(codigoGerencia).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _getColorForCodigo(codigoGerencia).withOpacity(0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _getIconForCodigo(codigoGerencia),
                      color: _getColorForCodigo(codigoGerencia),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      codigoGerencia,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getColorForCodigo(codigoGerencia),
                      ),
                    ),
                    if (widget.sancion.tieneDescuento && widget.sancion.porcentajeDescuento != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${widget.sancion.porcentajeDescuento!.toStringAsFixed(0)}% DESCUENTO',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                if (comentarioGerencia.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    comentarioGerencia,
                    style: const TextStyle(
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ✅ SECCIÓN CONFIRMAR
  Widget _buildSeccionConfirmar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal.withOpacity(0.3)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info, color: Colors.teal),
              SizedBox(width: 8),
              Text(
                'Confirmar Procesamiento',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.teal,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Se confirmará la decisión de gerencia tal como fue aprobada. '
            'El descuento salarial se aplicará según el código establecido.',
            style: TextStyle(fontSize: 13),
          ),
        ],
      ),
    );
  }

  // 🔄 SECCIÓN MODIFICAR
  Widget _buildSeccionModificar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.edit, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                'Modificar Código de Descuento',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Seleccionar nuevo código:',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          
          // Selector de nuevos códigos
          Column(
            children: _codigosDisponibles.map((item) {
              final codigo = item['codigo'] as String;
              final isSelected = _nuevoCodigo == codigo;
              final color = item['color'] as Color;
              final icon = item['icon'] as IconData;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isSelected ? color : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: isSelected ? color.withOpacity(0.1) : null,
                ),
                child: RadioListTile<String>(
                  value: codigo,
                  groupValue: _nuevoCodigo,
                  onChanged: (value) {
                    setState(() {
                      _nuevoCodigo = value!;
                      _usarCustom = value == 'CUSTOM';
                      if (_usarCustom) {
                        _porcentajeController.clear();
                      }
                    });
                  },
                  title: Row(
                    children: [
                      Icon(icon, color: color, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        item['label'],
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? color : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  activeColor: color,
                  dense: true,
                ),
              );
            }).toList(),
          ),
          
          // Campo personalizado para CUSTOM
          if (_usarCustom) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _porcentajeController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(2),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Porcentaje personalizado',
                      border: OutlineInputBorder(),
                      hintText: 'Ej: 25',
                      suffixText: '%',
                      helperText: 'Entre 1% y 50%',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.percent, color: Colors.purple),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // 🚫 SECCIÓN ANULAR
  Widget _buildSeccionAnular() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: Colors.red),
              SizedBox(width: 8),
              Text(
                'Anular Sanción',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'Se anulará completamente la sanción. Esta acción cambiará el estado a "Rechazado" '
            'y no se aplicará ningún descuento salarial.',
            style: TextStyle(fontSize: 13, color: Colors.red),
          ),
        ],
      ),
    );
  }

  // 📝 CAMPO DE COMENTARIOS
  Widget _buildCampoComentarios() {
    String hintText;
    bool obligatorio = true;
    
    switch (widget.accion) {
      case 'confirmar':
        hintText = 'Comentarios sobre el procesamiento (opcional)...\nEj: Procesado según protocolo establecido';
        obligatorio = false;
        break;
      case 'modificar':
        hintText = 'Justificación de la modificación...\nEj: Ajuste según antecedentes del empleado';
        break;
      case 'anular':
        hintText = 'Motivo de la anulación...\nEj: Revisión adicional determina falta de evidencia';
        break;
      default:
        hintText = 'Comentarios...';
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.comment, color: Color(0xFF1E3A8A)),
            const SizedBox(width: 8),
            Text(
              'Comentarios de RRHH:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            if (obligatorio) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(color: Colors.red, fontSize: 16),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _comentariosController,
          maxLines: 4,
          maxLength: 500,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            hintText: hintText,
            hintStyle: TextStyle(
              color: Colors.grey.shade500,
              fontSize: 13,
            ),
          ),
        ),
      ],
    );
  }

  // 🔧 ACCIONES DEL DIÁLOGO
  List<Widget> _buildActions() {
    return [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      
      const SizedBox(width: 8),
      
      ElevatedButton.icon(
        onPressed: _confirmarAccion,
        icon: _getActionIcon(),
        label: Text(_getActionLabel()),
        style: ElevatedButton.styleFrom(
          backgroundColor: _getActionColor(),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
    ];
  }

  Icon _getActionIcon() {
    switch (widget.accion) {
      case 'confirmar':
        return const Icon(Icons.verified);
      case 'modificar':
        return const Icon(Icons.edit);
      case 'anular':
        return const Icon(Icons.block);
      default:
        return const Icon(Icons.check);
    }
  }

  String _getActionLabel() {
    switch (widget.accion) {
      case 'confirmar':
        return 'Confirmar';
      case 'modificar':
        return 'Modificar';
      case 'anular':
        return 'Anular';
      default:
        return 'Procesar';
    }
  }

  Color _getActionColor() {
    switch (widget.accion) {
      case 'confirmar':
        return Colors.teal;
      case 'modificar':
        return Colors.blue;
      case 'anular':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // ✅ CONFIRMAR ACCIÓN
  void _confirmarAccion() {
    // Validaciones
    if (widget.accion != 'confirmar' && _comentariosController.text.trim().isEmpty) {
      _showError('Los comentarios son obligatorios para esta acción');
      return;
    }
    
    if (widget.accion == 'modificar' && _usarCustom && _porcentajeController.text.trim().isEmpty) {
      _showError('Debe especificar el porcentaje personalizado');
      return;
    }

    // Construir nuevo código si es modificación
    String? nuevoCodigo;
    if (widget.accion == 'modificar') {
      if (_usarCustom) {
        final porcentaje = _porcentajeController.text.trim();
        if (porcentaje.isNotEmpty) {
          final value = int.tryParse(porcentaje);
          if (value == null || value < 1 || value > 50) {
            _showError('El porcentaje debe estar entre 1% y 50%');
            return;
          }
          nuevoCodigo = 'D${porcentaje}%';
        }
      } else {
        nuevoCodigo = _nuevoCodigo;
      }
    }

    // Confirmar acción
    widget.onConfirm(_comentariosController.text.trim(), nuevoCodigo);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // 🎨 MÉTODOS AUXILIARES
  Color _getColorForCodigo(String codigo) {
    switch (codigo) {
      case 'SIN_DESC':
        return Colors.green;
      case 'D05%':
        return Colors.yellow.shade700;
      case 'D10%':
        return Colors.orange;
      case 'D15%':
        return Colors.deepOrange;
      case 'D20%':
        return Colors.red;
      default:
        if (codigo.startsWith('D') && codigo.contains('%')) {
          return Colors.purple;
        }
        return Colors.grey;
    }
  }

  IconData _getIconForCodigo(String codigo) {
    if (codigo == 'SIN_DESC') {
      return Icons.check_circle;
    } else if (codigo.startsWith('D') && codigo.contains('%')) {
      return Icons.money_off;
    }
    return Icons.info;
  }

  String _extraerCodigo(String comentarioCompleto) {
    if (comentarioCompleto.contains('|')) {
      return comentarioCompleto.split('|')[0];
    }
    return comentarioCompleto;
  }

  String _extraerComentario(String comentarioCompleto) {
    if (comentarioCompleto.contains('|')) {
      final partes = comentarioCompleto.split('|');
      return partes.length > 1 ? partes[1] : '';
    }
    return '';
  }

  @override
  void dispose() {
    _comentariosController.dispose();
    _porcentajeController.dispose();
    super.dispose();
  }
}