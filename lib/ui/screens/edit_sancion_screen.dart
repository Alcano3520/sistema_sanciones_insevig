import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:flutter/foundation.dart'; // Para kIsWeb

import '../../core/providers/auth_provider.dart';
import '../../core/models/sancion_model.dart';
import '../../core/offline/sancion_repository.dart';
import '../../core/models/empleado_model.dart';
import '../../core/offline/empleado_repository.dart';
import '../../core/services/sancion_service.dart';
import '../../core/services/empleado_service.dart';
import '../widgets/empleado_search_field.dart';

/// Pantalla para EDITAR sanción existente
/// ACTUALIZADA con compresión automática de imágenes
/// Permite modificar borradores y cambiar su status
class EditSancionScreen extends StatefulWidget {
  final SancionModel sancion;

  const EditSancionScreen({
    super.key,
    required this.sancion,
  });

  @override
  State<EditSancionScreen> createState() => _EditSancionScreenState();
}

class _EditSancionScreenState extends State<EditSancionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _puestoController = TextEditingController();
  final _agenteController = TextEditingController();
  final _observacionesController = TextEditingController();
  final _observacionesAdicionalesController = TextEditingController();
  final _signatureController = SignatureController(
    penStrokeWidth: 2,
    penColor: Colors.blue,
    exportBackgroundColor: Colors.white,
  );

  // Variables de estado
  EmpleadoModel? _empleadoSeleccionado;
  String _tipoSancion = '';
  DateTime _fecha = DateTime.now();
  TimeOfDay _hora = TimeOfDay.now();
  File? _fotoSeleccionada;
  int? _horasExtras;
  bool _pendiente = true;
  bool _isLoading = false;
  bool _isProcessingImage = false; // 🆕 Para mostrar estado de compresión

  @override
  void initState() {
    super.initState();
    _cargarDatosSancion();
  }

  @override
  void dispose() {
    _puestoController.dispose();
    _agenteController.dispose();
    _observacionesController.dispose();
    _observacionesAdicionalesController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  /// Cargar los datos de la sanción existente
  Future<void> _cargarDatosSancion() async {
    final sancion = widget.sancion;

    // Cargar datos básicos
    _puestoController.text = sancion.puesto;
    _agenteController.text = sancion.agente;
    _observacionesController.text = sancion.observaciones ?? '';
    _observacionesAdicionalesController.text =
        sancion.observacionesAdicionales ?? '';

    _tipoSancion = sancion.tipoSancion;
    _fecha = sancion.fecha;
    _pendiente = sancion.pendiente;
    _horasExtras = sancion.horasExtras;

    // Parsear la hora
    try {
      final timeParts = sancion.hora.split(':');
      if (timeParts.length >= 2) {
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        _hora = TimeOfDay(hour: hour, minute: minute);
      }
    } catch (e) {
      print('Error parseando hora: $e');
      _hora = TimeOfDay.now();
    }

    // Cargar empleado
    await _cargarEmpleado(sancion.empleadoCod);

    setState(() {});
  }

  /// Cargar datos del empleado
  Future<void> _cargarEmpleado(int empleadoCod) async {
    try {
      final empleadoRepository = EmpleadoRepository.instance;
      final empleado = await empleadoRepository.getEmpleadoByCod(empleadoCod);

      if (empleado != null) {
        setState(() {
          _empleadoSeleccionado = empleado;
        });
      }
    } catch (e) {
      print('Error cargando empleado: $e');
    }
  }

  /// Autocompletar campos cuando se selecciona un empleado
  void _autocompletarCampos(EmpleadoModel empleado) {
    String puesto = '';

    if (empleado.nomdep != null && empleado.nomdep!.isNotEmpty) {
      puesto = empleado.nomdep!;
    } else if (empleado.seccion != null && empleado.seccion!.isNotEmpty) {
      puesto = empleado.seccion!;
    } else if (empleado.nomcargo != null && empleado.nomcargo!.isNotEmpty) {
      puesto = 'Área ${empleado.nomcargo}';
    } else {
      puesto = 'Puesto General';
    }

    _puestoController.text = puesto;
    _agenteController.text = empleado.displayName;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('EDITAR SANCIÓN'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: () => _guardarSancion('borrador'),
            tooltip: 'Guardar cambios',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Banner de edición
              _buildEditBanner(),

              const SizedBox(height: 16),

              // Información del Empleado
              _buildSectionCard(
                title: '👤 Información del Empleado',
                child: _empleadoSeleccionado != null
                    ? _buildEmpleadoInfo()
                    : EmpleadoSearchField(
                        onEmpleadoSelected: (empleado) {
                          setState(() {
                            _empleadoSeleccionado = empleado;
                            _autocompletarCampos(empleado);
                          });
                        },
                      ),
              ),

              const SizedBox(height: 16),

              // Detalles de la Sanción
              _buildSectionCard(
                title: '📋 Detalles de la Sanción',
                child: Column(
                  children: [
                    // Fecha y Hora
                    Row(
                      children: [
                        Expanded(
                          child: _buildDateTimeSelector(
                            'Fecha: ${_fecha.day}/${_fecha.month}/${_fecha.year}',
                            Icons.calendar_today,
                            () => _selectDate(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildDateTimeSelector(
                            'Hora: ${_hora.format(context)}',
                            Icons.access_time,
                            () => _selectTime(),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Puesto y Agente
                    Row(
                      children: [
                        Expanded(
                          child: _buildTextField(
                            controller: _puestoController,
                            label: 'Puesto',
                            icon: Icons.location_on,
                            hint: 'Departamento del empleado',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildTextField(
                            controller: _agenteController,
                            label: 'Agente',
                            icon: Icons.person,
                            hint: 'Nombre del empleado',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Tipo de Sanción
                    _buildTipoSancionSelector(),

                    const SizedBox(height: 16),

                    // Observaciones
                    _buildTextField(
                      controller: _observacionesController,
                      label: 'Observaciones',
                      icon: Icons.note,
                      hint: 'Descripción de la sanción...',
                      maxLines: 3,
                    ),

                    const SizedBox(height: 16),

                    // Observaciones Adicionales
                    _buildTextField(
                      controller: _observacionesAdicionalesController,
                      label: 'Observaciones Adicionales',
                      icon: Icons.note_add,
                      hint: 'Información adicional...',
                      maxLines: 2,
                    ),

                    const SizedBox(height: 16),

                    // Switch de Pendiente
                    _buildPendienteSwitch(),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Evidencias
              _buildSectionCard(
                title: '📷 Evidencias',
                child: Column(
                  children: [
                    _buildFotoSection(),
                    const SizedBox(height: 16),
                    _buildFirmaSection(),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Botones de Acción
              _buildActionButtons(),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit, color: Colors.orange, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Editando Sanción',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'ID: ${widget.sancion.id.substring(0, 8)}... • Estado: ${widget.sancion.statusText}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpleadoInfo() {
    final empleado = _empleadoSeleccionado!;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.blue,
            child: Text(
              empleado.displayName.split(' ').take(2).map((e) => e[0]).join(),
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  empleado.displayName,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Text(
                  'Cód: ${empleado.cod} • ${empleado.nomcargo ?? 'Sin cargo'}',
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                Text(
                  empleado.nomdep ?? 'Sin departamento',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _empleadoSeleccionado = null;
              });
            },
            icon: const Icon(Icons.change_circle, size: 16),
            label: const Text('Cambiar', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildDateTimeSelector(
      String text, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFF1E3A8A)),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF1E3A8A)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 2),
        ),
      ),
      validator: maxLines == 1
          ? (value) {
              if (value?.isEmpty ?? true) {
                return 'Este campo es obligatorio';
              }
              return null;
            }
          : null,
    );
  }

  Widget _buildTipoSancionSelector() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonFormField<String>(
        value: _tipoSancion.isEmpty ? null : _tipoSancion,
        decoration: const InputDecoration(
          labelText: 'Tipo de sanción',
          prefixIcon: Icon(Icons.warning, color: Color(0xFF1E3A8A)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.all(16),
        ),
        items: SancionModel.tiposSancion.map((tipo) {
          return DropdownMenuItem(
            value: tipo,
            child: Text(_getTipoSancionLabel(tipo)),
          );
        }).toList(),
        onChanged: (value) => _onTipoSancionChanged(value!),
        validator: (value) {
          if (value?.isEmpty ?? true) {
            return 'Debe seleccionar un tipo de sanción';
          }
          return null;
        },
      ),
    );
  }

  String _getTipoSancionLabel(String tipo) {
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
    return '${sancionModel.tipoSancionEmoji} $tipo';
  }

  void _onTipoSancionChanged(String tipo) {
    setState(() => _tipoSancion = tipo);

    if (tipo == 'HORAS EXTRAS') {
      _showHorasExtrasDialog();
    } else {
      _horasExtras = null;
    }
  }

  void _showHorasExtrasDialog() {
    final controller = TextEditingController();
    if (_horasExtras != null) {
      controller.text = _horasExtras.toString();
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ingresar Horas Extras'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Número de horas',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() => _horasExtras = int.tryParse(controller.text));
              }
              Navigator.pop(context);
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  Widget _buildPendienteSwitch() {
    // 🔒 SOLO GERENCIA Y RRHH PUEDEN CAMBIAR ESTO
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.currentUser!;

        // Si es supervisor, NO mostrar el switch
        if (user.isSupervisor) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(
                  _pendiente ? Icons.pending_actions : Icons.check_circle,
                  color: _pendiente ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Estado: ${_pendiente ? "PENDIENTE" : "PROCESADO"}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Solo Gerencia/RRHH puede cambiar este estado',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        // Si es Gerencia/RRHH, mostrar el switch
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              const Icon(Icons.pending_actions, color: Color(0xFF1E3A8A)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Estado de Procesamiento',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _pendiente
                          ? 'Marcar como PROCESADO'
                          : 'Marcar como PENDIENTE',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _pendiente,
                onChanged: (value) => setState(() => _pendiente = value),
                activeColor: const Color(0xFF1E3A8A),
              ),
            ],
          ),
        );
      },
    );
  }

  // 🔥 MÉTODO _buildFotoSection() SIMPLIFICADO - SOLUCIÓN DEFINITIVA
  Widget _buildFotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Foto de evidencia',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(width: 8),
            if (kIsWeb)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: const Text(
                  'Web',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (_isProcessingImage) ...[
              const SizedBox(width: 12),
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              const Text(
                'Optimizando...',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),

        // LUGAR 1 - Foto existente de la sanción (Image.network normal)
        if (widget.sancion.fotoUrl != null && _fotoSeleccionada == null) ...[
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                widget.sancion.fotoUrl!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Colors.grey),
                        Text('Error cargando imagen'),
                      ],
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // LUGAR 2 - Nueva foto seleccionada (PLACEHOLDER SIMPLE)
        if (_fotoSeleccionada != null) ...[
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Center(
                child: Icon(
                  Icons.image,
                  size: 48,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Mensaje informativo
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 16),
                SizedBox(width: 8),
                Text(
                  'Nueva imagen seleccionada correctamente',
                  style: TextStyle(fontSize: 12, color: Colors.green),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isProcessingImage ? null : _tomarFoto,
                icon: _isProcessingImage
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Icon(kIsWeb ? Icons.upload_file : Icons.camera_alt),
                label: Text(_fotoSeleccionada == null
                    ? (kIsWeb ? 'Seleccionar Imagen' : 'Agregar Foto')
                    : 'Cambiar Imagen'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            if (_fotoSeleccionada != null) ...[
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _isProcessingImage
                    ? null
                    : () => setState(() => _fotoSeleccionada = null),
                icon: const Icon(Icons.delete),
                label: const Text('Eliminar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),

        // 🆕 Información adicional para web
        if (kIsWeb && _fotoSeleccionada == null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 16),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'En la versión web puedes seleccionar imágenes desde tu computadora',
                    style: TextStyle(fontSize: 12, color: Colors.blue),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFirmaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Firma del Sancionado',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A8A),
          ),
        ),
        const SizedBox(height: 12),

        // Mostrar firma existente si la hay
        if (widget.sancion.firmaPath != null &&
            _signatureController.isEmpty) ...[
          Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              color: Colors.white,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                widget.sancion.firmaPath!,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.draw, size: 48, color: Colors.grey),
                      Text('Firma no disponible'),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              setState(() {
                // Aquí podrías cargar la firma existente al pad si fuera necesario
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      '💡 Dibuje una nueva firma para reemplazar la existente'),
                  backgroundColor: Colors.blue,
                ),
              );
            },
            icon: const Icon(Icons.edit),
            label: const Text('Modificar Firma'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ] else ...[
          // Pad de firma
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            child: Signature(
              controller: _signatureController,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _signatureController.clear(),
            icon: const Icon(Icons.clear),
            label: const Text('Limpiar Firma'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed:
                    _isLoading ? null : () => _guardarSancion('borrador'),
                icon: const Icon(Icons.save_outlined),
                label: const Text('Guardar Cambios'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : () => _guardarSancion('enviado'),
                icon: const Icon(Icons.send),
                label: const Text('Guardar y Enviar'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
        if (_isLoading) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(),
          const SizedBox(height: 8),
          const Text(
            'Guardando cambios...',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ],
    );
  }

  Future<void> _selectDate() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fecha,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (fecha != null) {
      setState(() => _fecha = fecha);
    }
  }

  Future<void> _selectTime() async {
    final hora = await showTimePicker(
      context: context,
      initialTime: _hora,
    );
    if (hora != null) {
      setState(() => _hora = hora);
    }
  }

  /// 🆕 MÉTODO MEJORADO: Tomar foto con compresión y feedback
  Future<void> _tomarFoto() async {
    try {
      setState(() => _isProcessingImage = true);

      final picker = ImagePicker();
      XFile? foto;

      // 🔥 DETECTAR PLATAFORMA
      if (kIsWeb) {
        // EN WEB: Seleccionar archivo
        foto = await picker.pickImage(
          source: ImageSource.gallery, // Galería en web
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 80,
        );

        if (foto != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text('📸 Imagen seleccionada correctamente'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        // EN MÓVIL: Mostrar opciones
        final ImageSource? source = await _showImageSourceDialog();

        if (source != null) {
          foto = await picker.pickImage(
            source: source,
            maxWidth: 1024,
            maxHeight: 1024,
            imageQuality: 80,
          );
        }
      }

      if (foto != null && mounted) {
        // Mostrar indicador de procesamiento
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                ),
                SizedBox(width: 12),
                Text('📸 Procesando y optimizando imagen...'),
              ],
            ),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
        );

        // Convertir XFile a File
        final file = File(foto.path);

        // Pre-validar la imagen
        final sancionRepository = SancionRepository.instance;
        final validation = await sancionRepository.validateImage(file);

        if (validation['valid']) {
          final info = validation['info'] as Map<String, dynamic>;
          final needsCompression = validation['needsCompression'] as bool;
          final originalSize = info['size'] ?? 0;
          final estimatedSize =
              validation['estimatedCompressedSize'] ?? originalSize;

          setState(() => _fotoSeleccionada = file);

          if (mounted) {
            // Mostrar información de optimización
            if (needsCompression) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.compress, color: Colors.white, size: 16),
                          SizedBox(width: 8),
                          Text('🎯 Imagen optimizada automáticamente',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('📊 Original: ${_formatBytes(originalSize)}',
                          style: const TextStyle(fontSize: 12)),
                      Text('📉 Optimizada: ~${_formatBytes(estimatedSize)}',
                          style: const TextStyle(fontSize: 12)),
                      Text(
                          '💾 Ahorro: ~${((originalSize - estimatedSize) / originalSize * 100).round()}%',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  duration: const Duration(seconds: 4),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 8),
                      Text('✅ Imagen agregada (ya optimizada)'),
                    ],
                  ),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          }
        } else {
          // Error de validación
          _mostrarError('Error procesando imagen: ${validation['error']}');
        }
      }
    } catch (e) {
      _mostrarError('Error al seleccionar imagen: $e');
    } finally {
      if (mounted) {
        setState(() => _isProcessingImage = false);
      }
    }
  }

  // 🆕 Agregar este método para mostrar opciones en móvil:
  Future<ImageSource?> _showImageSourceDialog() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Seleccionar imagen',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF1E3A8A)),
              title: const Text('Tomar foto'),
              subtitle: const Text('Usar la cámara del dispositivo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading:
                  const Icon(Icons.photo_library, color: Color(0xFF1E3A8A)),
              title: const Text('Seleccionar de galería'),
              subtitle: const Text('Elegir una imagen existente'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ],
        ),
      ),
    );
  }

  /// 🆕 Función auxiliar para formatear bytes
  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = (bytes.bitLength - 1) ~/ 10;
    return '${(bytes / (1 << (i * 10))).toStringAsFixed(1)} ${suffixes[i]}';
  }

  Future<void> _guardarSancion(String status) async {
    if (!_formKey.currentState!.validate()) return;

    if (_empleadoSeleccionado == null) {
      _mostrarError('Debe seleccionar un empleado');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final sancionRepository = SancionRepository.instance;

      // Crear sanción actualizada
      final sancionActualizada = widget.sancion.copyWith(
        empleadoCod: _empleadoSeleccionado!.cod,
        empleadoNombre: _empleadoSeleccionado!.displayName,
        puesto: _puestoController.text.trim(),
        agente: _agenteController.text.trim(),
        fecha: _fecha,
        hora: _hora.format(context),
        tipoSancion: _tipoSancion,
        observaciones: _observacionesController.text.trim().isEmpty
            ? null
            : _observacionesController.text.trim(),
        observacionesAdicionales:
            _observacionesAdicionalesController.text.trim().isEmpty
                ? null
                : _observacionesAdicionalesController.text.trim(),
        pendiente: _pendiente,
        horasExtras: _horasExtras,
        status: status,
        updatedAt: DateTime.now(),
      );

      // 🔥 USAR EL MÉTODO CORREGIDO CON ARCHIVOS Y COMPRESIÓN AUTOMÁTICA
      bool success;

      if (_fotoSeleccionada != null || (_signatureController.isNotEmpty)) {
        // Si hay archivos nuevos, usar el método con archivos (CON COMPRESIÓN)
        success = await sancionRepository.updateSancion(
          sancionActualizada,
          nuevaFoto: _fotoSeleccionada, // Se comprime automáticamente
          nuevaFirma:
              _signatureController.isNotEmpty ? _signatureController : null,
        );
      } else {
        // Si no hay archivos nuevos, usar método simple
        success =
            await sancionRepository.updateSancionSimple(sancionActualizada);
      }

      // 🆕 Limpiar archivos temporales después de guardar
      await sancionRepository.cleanupTempFiles();

      if (success) {
        if (mounted) {
          Navigator.pop(context, true); // Regresar con resultado exitoso
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(status == 'borrador'
                      ? '✅ Cambios guardados correctamente'
                      : '📤 Sanción actualizada y enviada correctamente'),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        _mostrarError('Error al actualizar la sanción');
      }
    } catch (e) {
      print('❌ Error completo en _guardarSancion: $e');
      _mostrarError('Error al guardar: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _mostrarError(String mensaje) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('❌ $mensaje')),
            ],
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
