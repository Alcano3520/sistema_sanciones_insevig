import 'package:flutter/material.dart';
import '../../core/models/sancion_model.dart';

/// Widget especializado para aprobación de sanciones por parte de Gerencia
/// ✅ FIXED: Solucionado problema de renderizado en Windows Desktop
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
  String _codigoSeleccionado = 'LIBRE';
  final _comentarioController = TextEditingController();
  bool _aprobar = true;

  /// Códigos de descuento predefinidos para Gerencia
  static const Map<String, String> codigosDescuento = {
    'D00%': 'Sin descuento',
    'D05%': 'Descuento 5%',
    'D10%': 'Descuento 10%',
    'D15%': 'Descuento 15%',
    'D20%': 'Descuento 20%',
    'LIBRE': 'Comentario libre',
  };

  @override
  Widget build(BuildContext context) {
    return Theme(
      // 🛠️ FORZAR TEMA MATERIAL PARA WINDOWS
      data: Theme.of(context).copyWith(
        // Asegurar colores para desktop
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: const Color(0xFF1E3A8A),
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black87,
        ),
        // Tema específico para dropdown
        dropdownMenuTheme: DropdownMenuThemeData(
          textStyle: const TextStyle(
            color: Colors.black87,
            fontSize: 14,
          ),
          menuStyle: MenuStyle(
            backgroundColor: WidgetStateProperty.all(Colors.white),
            surfaceTintColor: WidgetStateProperty.all(Colors.white),
          ),
        ),
      ),
      child: AlertDialog(
        backgroundColor: Colors.white, // 🛠️ FORZAR FONDO BLANCO
        surfaceTintColor: Colors.white, // 🛠️ QUITAR TINT EN WINDOWS
        title: Row(
          children: [
            Icon(
              _aprobar ? Icons.check_circle : Icons.cancel,
              color: _aprobar ? Colors.green : Colors.red,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text(
              'Aprobación Gerencia',
              style: TextStyle(color: Colors.black87), // 🛠️ FORZAR COLOR
            ),
          ],
        ),
        content: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          width: MediaQuery.of(context).size.width * 0.75,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildResumenSancion(),
                const SizedBox(height: 8),

                // Toggle Aprobar/Rechazar
                const Text(
                  'Decisión:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87, // 🛠️ FORZAR COLOR
                  ),
                ),
                const SizedBox(height: 6),
                
                // 🛠️ REEMPLAZAR SegmentedButton POR CUSTOM BUTTONS PARA WINDOWS
                _buildDecisionButtons(),

                const SizedBox(height: 8),

                // Si aprueba: selector de código descuento
                if (_aprobar) ...[
                  const Text(
                    'Código de Descuento:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87, // 🛠️ FORZAR COLOR
                    ),
                  ),
                  const SizedBox(height: 6),
                  
                  // 🛠️ DROPDOWN PERSONALIZADO PARA WINDOWS
                  _buildDropdownPersonalizado(),

                  const SizedBox(height: 8),

                  // Vista previa del código seleccionado
                  _buildVistaPrevia(),

                  const SizedBox(height: 8),
                ],

                // Campo comentarios
                Text(
                  _aprobar 
                      ? (_codigoSeleccionado == 'LIBRE' 
                          ? 'Comentarios (opcional):' 
                          : 'Comentarios adicionales:')
                      : 'Motivo del rechazo (obligatorio):',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.black87, // 🛠️ FORZAR COLOR
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _comentarioController,
                  maxLines: 2,
                  style: const TextStyle(color: Colors.black87), // 🛠️ FORZAR COLOR
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: _aprobar
                        ? (_codigoSeleccionado == 'LIBRE' 
                            ? 'Comentario libre (opcional)...' 
                            : 'Justificación del código seleccionado...')
                        : 'Explique por qué se rechaza...',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                    contentPadding: const EdgeInsets.all(8),
                    fillColor: Colors.white, // 🛠️ FORZAR FONDO BLANCO
                    filled: true,
                  ),
                ),

                if (_aprobar) ...[
                  const SizedBox(height: 8),
                  _buildFormatoFinal(),
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
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _procesarAprobacion,
            style: ElevatedButton.styleFrom(
              backgroundColor: _aprobar ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: Text(_aprobar ? 'Aprobar' : 'Rechazar'),
          ),
        ],
      ),
    );
  }

  // 🛠️ BOTONES PERSONALIZADOS PARA DECISIÓN (REEMPLAZO DE SegmentedButton)
  Widget _buildDecisionButtons() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => setState(() => _aprobar = true),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: _aprobar ? Colors.green.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                border: Border.all(
                  color: _aprobar ? Colors.green : Colors.grey,
                  width: _aprobar ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle,
                    color: _aprobar ? Colors.green : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Aprobar',
                    style: TextStyle(
                      color: _aprobar ? Colors.green : Colors.grey,
                      fontWeight: _aprobar ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: InkWell(
            onTap: () => setState(() => _aprobar = false),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: !_aprobar ? Colors.red.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
                border: Border.all(
                  color: !_aprobar ? Colors.red : Colors.grey,
                  width: !_aprobar ? 2 : 1,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cancel,
                    color: !_aprobar ? Colors.red : Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Rechazar',
                    style: TextStyle(
                      color: !_aprobar ? Colors.red : Colors.grey,
                      fontWeight: !_aprobar ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // 🛠️ DROPDOWN PERSONALIZADO PARA WINDOWS
  Widget _buildDropdownPersonalizado() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.white, // 🛠️ FORZAR FONDO BLANCO
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          canvasColor: Colors.white, // 🛠️ FONDO DEL DROPDOWN
        ),
        child: DropdownButtonFormField<String>(
          value: _codigoSeleccionado,
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          style: const TextStyle(
            color: Colors.black87, // 🛠️ FORZAR COLOR DEL TEXTO
            fontSize: 14,
          ),
          dropdownColor: Colors.white, // 🛠️ FONDO DEL MENU
          items: codigosDescuento.entries.map((entry) =>
              DropdownMenuItem(
                value: entry.key,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    '${entry.key} - ${entry.value}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF1E3A8A), // 🛠️ FORZAR COLOR
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )).toList(),
          onChanged: (value) => setState(() => _codigoSeleccionado = value!),
          icon: const Icon(
            Icons.arrow_drop_down,
            color: Color(0xFF1E3A8A), // 🛠️ FORZAR COLOR DEL ICONO
          ),
        ),
      ),
    );
  }

  // 🛠️ VISTA PREVIA MEJORADA
  Widget _buildVistaPrevia() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _codigoSeleccionado == 'LIBRE' 
                ? 'Modalidad seleccionada:' 
                : 'Código seleccionado:',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: Colors.blue,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            codigosDescuento[_codigoSeleccionado]!,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87, // 🛠️ FORZAR COLOR
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // 🛠️ FORMATO FINAL MEJORADO
  Widget _buildFormatoFinal() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Formato final:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 11,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            _getFormatoFinal(),
            style: const TextStyle(
              fontSize: 11,
              fontFamily: 'monospace',
              color: Colors.black87, // 🛠️ FORZAR COLOR
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Construir resumen visual de la sanción
  Widget _buildResumenSancion() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  widget.sancion.tipoSancionEmoji,
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.sancion.tipoSancion,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.black87, // 🛠️ FORZAR COLOR
                      ),
                    ),
                    Text(
                      widget.sancion.empleadoNombre,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

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
                color: Colors.black87, // 🛠️ FORZAR COLOR
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
          ? '(sin comentarios)' 
          : _comentarioController.text;
    }

    final comentario = _comentarioController.text.isEmpty 
        ? '[escriba su comentario]' 
        : _comentarioController.text;
    return '$_codigoSeleccionado - $comentario';
  }

  /// Procesar la aprobación o rechazo
  void _procesarAprobacion() {
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

    if (_aprobar && _codigoSeleccionado != 'LIBRE' && _comentarioController.text.trim().isEmpty) {
      showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white, // 🛠️ FORZAR FONDO
          surfaceTintColor: Colors.white,
          title: const Text(
            'Confirmar sin comentarios',
            style: TextStyle(color: Colors.black87),
          ),
          content: Text(
            '¿Está seguro de aprobar con código $_codigoSeleccionado sin comentarios adicionales?',
            style: const TextStyle(color: Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              style: TextButton.styleFrom(foregroundColor: Colors.black87),
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

  /// Finalizar el proceso de aprobación
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