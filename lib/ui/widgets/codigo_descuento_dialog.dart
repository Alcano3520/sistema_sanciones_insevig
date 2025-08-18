import 'package:flutter/material.dart';
import '../../core/models/sancion_model.dart';

/// 🆕 WIDGET PARA SELECCIONAR CÓDIGOS DE DESCUENTO SALARIAL
/// ✅ FIXED: Solucionado problema de renderizado en Windows Desktop
class CodigoDescuentoDialog extends StatefulWidget {
  final SancionModel sancion;
  final bool aprobar;
  final Function(String codigoCompleto) onConfirm;

  const CodigoDescuentoDialog({
    super.key,
    required this.sancion,
    required this.aprobar,
    required this.onConfirm,
  });

  @override
  State<CodigoDescuentoDialog> createState() => _CodigoDescuentoDialogState();
}

class _CodigoDescuentoDialogState extends State<CodigoDescuentoDialog> {
  final _comentariosController = TextEditingController();
  final _porcentajeCustomController = TextEditingController();
  
  String _codigoSeleccionado = 'D05%';
  bool _usarCustom = false;
  
  // 📋 CÓDIGOS PREDEFINIDOS DEL SISTEMA
  final List<Map<String, dynamic>> _codigosPredefinidos = [
    {
      'codigo': 'SIN_DESC', 
      'label': '✅ Sin descuento', 
      'descripcion': 'Aprobar sin descuento salarial',
      'color': Colors.blue,
      'icon': Icons.check_circle,
    },
    {
      'codigo': 'D05%', 
      'label': '💰 5% descuento', 
      'descripcion': 'Descuento del 5% del sueldo mensual',
      'color': Colors.orange,
      'icon': Icons.percent,
    },
    {
      'codigo': 'D10%', 
      'label': '💰 10% descuento', 
      'descripcion': 'Descuento del 10% del sueldo mensual',
      'color': Colors.deepOrange,
      'icon': Icons.percent,
    },
    {
      'codigo': 'D15%', 
      'label': '💰 15% descuento', 
      'descripcion': 'Descuento del 15% del sueldo mensual',
      'color': Colors.red,
      'icon': Icons.percent,
    },
    {
      'codigo': 'D20%', 
      'label': '💰 20% descuento', 
      'descripcion': 'Descuento del 20% del sueldo mensual',
      'color': Colors.redAccent,
      'icon': Icons.percent,
    },
    {
      'codigo': 'CUSTOM', 
      'label': '🎯 Personalizado', 
      'descripcion': 'Definir porcentaje específico',
      'color': Colors.purple,
      'icon': Icons.tune,
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Theme(
      // 🛠️ FORZAR TEMA MATERIAL PARA WINDOWS
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: const Color(0xFF1E3A8A),
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black87,
        ),
        radioTheme: RadioThemeData(
          fillColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF1E3A8A);
            }
            return Colors.grey;
          }),
        ),
      ),
      child: AlertDialog(
        backgroundColor: Colors.white, // 🛠️ FORZAR FONDO BLANCO
        surfaceTintColor: Colors.white, // 🛠️ QUITAR TINT EN WINDOWS
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              widget.aprobar ? Icons.approval : Icons.cancel,
              color: widget.aprobar ? Colors.green : Colors.red,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.aprobar ? 'Aprobar con Código' : 'Rechazar Sanción',
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.black87, // 🛠️ FORZAR COLOR
                ),
              ),
            ),
          ],
        ),
        
        content: Container(
          width: double.maxFinite,
          constraints: const BoxConstraints(maxHeight: 600),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 📄 RESUMEN DE LA SANCIÓN
                _buildResumenSancion(),
                
                const SizedBox(height: 20),
                
                if (widget.aprobar) ...[
                  // 🎯 SELECTOR DE CÓDIGOS DE DESCUENTO
                  const Text(
                    '💼 Seleccionar código de descuento:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  _buildSelectorCodigos(),
                  
                  const SizedBox(height: 16),
                  
                  // 🎛️ CAMPO PERSONALIZADO SI ES NECESARIO
                  if (_usarCustom) _buildCampoPersonalizado(),
                  
                  const SizedBox(height: 16),
                ],
                
                // 💬 CAMPO DE COMENTARIOS
                _buildCampoComentarios(),
                
                if (!widget.aprobar) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Los comentarios son obligatorios para rechazar',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
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
            style: TextButton.styleFrom(
              foregroundColor: Colors.black87, // 🛠️ FORZAR COLOR
            ),
            child: const Text('Cancelar'),
          ),
          
          ElevatedButton.icon(
            onPressed: _confirmarAccion,
            icon: Icon(widget.aprobar ? Icons.check_circle : Icons.cancel),
            label: Text(widget.aprobar ? 'Aprobar' : 'Rechazar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.aprobar ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// 📄 RESUMEN DE LA SANCIÓN
  Widget _buildResumenSancion() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.grey.shade50,
            Colors.grey.shade100,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                widget.sancion.tipoSancionEmoji,
                style: const TextStyle(fontSize: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.sancion.tipoSancion,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 16,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          _buildInfoRow('👤', 'Empleado', widget.sancion.empleadoNombre),
          _buildInfoRow('🆔', 'Código', widget.sancion.empleadoCod.toString()),
          _buildInfoRow('🏢', 'Puesto', widget.sancion.puesto),
          _buildInfoRow('🧑‍💼', 'Agente', widget.sancion.agente),
          _buildInfoRow('📅', 'Fecha', '${widget.sancion.fechaFormateada} ${widget.sancion.hora}'),
          
          if (widget.sancion.observaciones != null && widget.sancion.observaciones!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '📝 Observaciones:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: 12,
                      color: Colors.black87, // 🛠️ FORZAR COLOR
                    ),
                  ),
                  Text(
                    widget.sancion.observaciones!,
                    style: const TextStyle(
                      fontSize: 12, 
                      fontStyle: FontStyle.italic,
                      color: Colors.black87, // 🛠️ FORZAR COLOR
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInfoRow(String emoji, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w500, 
              fontSize: 13,
              color: Colors.black87, // 🛠️ FORZAR COLOR
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87, // 🛠️ FORZAR COLOR
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// 🎯 SELECTOR DE CÓDIGOS DE DESCUENTO
  Widget _buildSelectorCodigos() {
    return Column(
      children: _codigosPredefinidos.map((item) {
        final codigo = item['codigo'] as String;
        final isSelected = _codigoSeleccionado == codigo;
        final color = item['color'] as Color;
        final icon = item['icon'] as IconData;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
            color: isSelected ? color.withOpacity(0.1) : Colors.white, // 🛠️ FORZAR FONDO
            boxShadow: isSelected ? [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                setState(() {
                  _codigoSeleccionado = codigo;
                  _usarCustom = codigo == 'CUSTOM';
                });
              },
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // 🛠️ RADIO BUTTON PERSONALIZADO PARA WINDOWS
                    Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? color : Colors.grey,
                          width: 2,
                        ),
                        color: isSelected ? color : Colors.transparent,
                      ),
                      child: isSelected 
                          ? const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Icon(
                      icon,
                      color: isSelected ? color : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['label'],
                            style: TextStyle(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              color: isSelected ? color : Colors.black87, // 🛠️ FORZAR COLOR
                            ),
                          ),
                          Text(
                            item['descripcion'],
                            style: TextStyle(
                              fontSize: 12,
                              color: isSelected ? color.withOpacity(0.8) : Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  /// 🎛️ CAMPO PERSONALIZADO
  Widget _buildCampoPersonalizado() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tune, color: Colors.purple, size: 20),
              SizedBox(width: 8),
              Text(
                'Porcentaje personalizado:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _porcentajeCustomController,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.black87), // 🛠️ FORZAR COLOR
            decoration: InputDecoration(
              labelText: 'Porcentaje (%)',
              labelStyle: const TextStyle(color: Colors.purple), // 🛠️ FORZAR COLOR
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Colors.purple, width: 2),
              ),
              hintText: 'Ej: 25, 30, 50...',
              hintStyle: TextStyle(color: Colors.grey.shade500),
              suffixIcon: const Icon(Icons.percent, color: Colors.purple),
              helperText: 'Ingrese solo el número (sin el símbolo %)',
              helperStyle: TextStyle(color: Colors.grey.shade600),
              fillColor: Colors.white, // 🛠️ FORZAR FONDO BLANCO
              filled: true,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              children: [
                Icon(Icons.info, color: Colors.amber, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Use esta opción para porcentajes no estándar como 25%, 30%, etc.',
                    style: TextStyle(fontSize: 11, color: Colors.amber),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 💬 CAMPO DE COMENTARIOS
  Widget _buildCampoComentarios() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.aprobar 
            ? '💬 Comentarios de gerencia:'
            : '❌ Motivo del rechazo:',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Color(0xFF1E3A8A),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _comentariosController,
          maxLines: 4,
          style: const TextStyle(color: Colors.black87), // 🛠️ FORZAR COLOR
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 2),
            ),
            hintText: widget.aprobar
              ? 'Justificación del código aplicado...\nEj: "Aplicando D10% por reincidencia en atrasos"'
              : 'Explica detalladamente por qué se rechaza la sanción...',
            hintStyle: TextStyle(color: Colors.grey.shade500),
            alignLabelWithHint: true,
            contentPadding: const EdgeInsets.all(12),
            fillColor: Colors.white, // 🛠️ FORZAR FONDO BLANCO
            filled: true,
          ),
        ),
      ],
    );
  }

  /// ✅ CONFIRMAR ACCIÓN
  void _confirmarAccion() {
    // 🔍 VALIDACIONES
    if (!widget.aprobar && _comentariosController.text.trim().isEmpty) {
      _showError('Los comentarios son obligatorios para rechazar');
      return;
    }
    
    if (widget.aprobar && _comentariosController.text.trim().isEmpty) {
      _showError('Los comentarios son obligatorios para aprobar');
      return;
    }
    
    if (_usarCustom && _porcentajeCustomController.text.trim().isEmpty) {
      _showError('Debe especificar el porcentaje personalizado');
      return;
    }
    
    if (_usarCustom) {
      final porcentaje = int.tryParse(_porcentajeCustomController.text.trim());
      if (porcentaje == null || porcentaje < 0 || porcentaje > 100) {
        _showError('El porcentaje debe ser un número entre 0 y 100');
        return;
      }
    }

    // 🔨 CONSTRUIR CÓDIGO COMPLETO
    String codigoFinal;
    if (widget.aprobar) {
      if (_usarCustom) {
        final porcentaje = _porcentajeCustomController.text.trim();
        codigoFinal = 'D${porcentaje}%|${_comentariosController.text.trim()}';
      } else {
        codigoFinal = '$_codigoSeleccionado|${_comentariosController.text.trim()}';
      }
    } else {
      codigoFinal = 'RECHAZADO|${_comentariosController.text.trim()}';
    }

    // ✅ CONFIRMAR ACCIÓN
    widget.onConfirm(codigoFinal);
    Navigator.pop(context);
  }

  /// ⚠️ MOSTRAR ERROR
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _comentariosController.dispose();
    _porcentajeCustomController.dispose();
    super.dispose();
  }
}