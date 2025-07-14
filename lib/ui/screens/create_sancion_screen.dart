import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:signature/signature.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../core/providers/auth_provider.dart';
import '../../core/models/sancion_model.dart';
import '../../core/models/empleado_model.dart';
import '../../core/services/sancion_service.dart';
import '../../core/services/empleado_service.dart';
import '../widgets/empleado_search_field.dart';

/// Pantalla para crear nueva sanción - EXACTAMENTE como tu PantallaSancion de Kivy
/// Incluye todos los campos: fecha, hora, puesto, agente, tipo, observaciones, foto, firma
class CreateSancionScreen extends StatefulWidget {
  const CreateSancionScreen({super.key});

  @override
  State<CreateSancionScreen> createState() => _CreateSancionScreenState();
}

class _CreateSancionScreenState extends State<CreateSancionScreen> {
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

  // Variables de estado - igual que tu Kivy
  EmpleadoModel? _empleadoSeleccionado;
  String _tipoSancion = '';
  DateTime _fecha = DateTime.now();
  TimeOfDay _hora = TimeOfDay.now();
  File? _fotoSeleccionada;
  int? _horasExtras;
  bool _pendiente = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _puestoController.dispose();
    _agenteController.dispose();
    _observacionesController.dispose();
    _observacionesAdicionalesController.dispose();
    _signatureController.dispose();
    super.dispose();
  }

  /// Autocompletar campos cuando se selecciona un empleado - CORREGIDO
  void _autocompletarCampos(EmpleadoModel empleado) {
    // 🔥 PUESTO: Usar DEPARTAMENTO (nomdep) como prioridad principal
    String puesto = '';

    if (empleado.nomdep != null && empleado.nomdep!.isNotEmpty) {
      puesto = empleado.nomdep!; // 🎯 PRIORIDAD 1: Departamento (nomdep)
    } else if (empleado.seccion != null && empleado.seccion!.isNotEmpty) {
      puesto = empleado.seccion!; // Prioridad 2: Sección específica
    } else if (empleado.nomcargo != null && empleado.nomcargo!.isNotEmpty) {
      puesto = 'Área ${empleado.nomcargo}'; // Prioridad 3: Basado en cargo
    } else {
      puesto = 'Puesto General'; // Por defecto
    }

    _puestoController.text = puesto;

    // 🔥 AGENTE: Usar el NOMBRE DEL EMPLEADO SELECCIONADO, no el supervisor
    String agente =
        empleado.displayName; // 🎯 El empleado es quien comete la falta
    _agenteController.text = agente;

    // Información adicional en consola para debug
    print('📋 Autocompletado CORREGIDO:');
    print('   Empleado: ${empleado.displayName}');
    print('   Puesto (nomdep): $puesto');
    print('   Agente (empleado): $agente');
    print('   Departamento disponible: ${empleado.nomdep}');
    print('   Sección disponible: ${empleado.seccion}');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('COMPROBANTE DE MÉRITOS'), // Igual que tu Kivy
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.save_outlined),
            onPressed: () => _guardarSancion('borrador'),
            tooltip: 'Guardar borrador',
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
              // Información del Empleado (búsqueda como tu autocompletado de Kivy)
              _buildSectionCard(
                title: '👤 Información del Empleado',
                child: EmpleadoSearchField(
                  onEmpleadoSelected: (empleado) {
                    setState(() {
                      _empleadoSeleccionado = empleado;

                      // 🔥 AUTOCOMPLETAR CAMPOS CORREGIDO
                      _autocompletarCampos(empleado);
                    });

                    // Feedback visual mejorado y corregido
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.check_circle,
                                    color: Colors.white, size: 20),
                                const SizedBox(width: 8),
                                const Text(
                                  '✅ Empleado seleccionado',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '👤 ${empleado.displayName}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              '🏢 Departamento: ${empleado.nomdep ?? "No definido"}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              '📍 Puesto autocompletado: ${_puestoController.text}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            Text(
                              '🧑‍💼 Agente autocompletado: ${_agenteController.text}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 4),
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.all(16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(height: 16),

              // Detalles de la Sanción (como tu GridLayout de Kivy)
              _buildSectionCard(
                title: '📋 Detalles de la Sanción',
                child: Column(
                  children: [
                    // Fecha y Hora (como tus botones de Kivy)
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

                    // Puesto y Agente (como tu TextInput de Kivy)
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

                    const SizedBox(height: 8),

                    // Botones de autocompletado con descripción corregida
                    Row(
                      children: [
                        TextButton.icon(
                          onPressed: _empleadoSeleccionado != null
                              ? () {
                                  setState(() {
                                    _autocompletarCampos(
                                        _empleadoSeleccionado!);
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                          '🔄 Campos autocompletados:\n'
                                          '📍 Puesto: ${_puestoController.text}\n'
                                          '🧑‍💼 Agente: ${_agenteController.text}'),
                                      backgroundColor: Colors.blue,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              : null,
                          icon: const Icon(Icons.auto_fix_high, size: 16),
                          label: const Text('Autocompletar',
                              style: TextStyle(fontSize: 12)),
                        ),
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _puestoController.clear();
                              _agenteController.clear();
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('🧹 Campos limpiados'),
                                backgroundColor: Colors.orange,
                                duration: Duration(seconds: 1),
                              ),
                            );
                          },
                          icon: const Icon(Icons.clear, size: 16),
                          label: const Text('Limpiar',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),

                    // Información explicativa
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: Colors.blue, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Puesto = Departamento del empleado • Agente = Nombre del empleado',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.blue.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Tipo de Sanción (como tu Spinner de Kivy)
                    _buildTipoSancionSelector(),

                    const SizedBox(height: 16),

                    // Observaciones (como tu TextInput multilínea de Kivy)
                    _buildTextField(
                      controller: _observacionesController,
                      label: 'Observaciones',
                      icon: Icons.note,
                      hint: 'Descripción de la sanción...',
                      maxLines: 3,
                    ),

                    const SizedBox(height: 16),

                    // Observaciones Adicionales (NUEVO CAMPO que pediste)
                    _buildTextField(
                      controller: _observacionesAdicionalesController,
                      label: 'Observaciones Adicionales',
                      icon: Icons.note_add,
                      hint: 'Información adicional...',
                      maxLines: 2,
                    ),

                    const SizedBox(height: 16),

                    // Switch de Pendiente (NUEVO CAMPO que pediste)
                    _buildPendienteSwitch(),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Evidencias - Foto y Firma (como tu CamaraPopup y PadFirma de Kivy)
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

              // Botones de Acción (como tu layout de botones de Kivy)
              _buildActionButtons(),

              const SizedBox(height: 20),
            ],
          ),
        ),
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
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 16),
              ),
            ),
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
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
          labelText: 'Seleccionar sanción',
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

    // Mostrar dialog para horas extras (como en tu Kivy)
    if (tipo == 'HORAS EXTRAS') {
      _showHorasExtrasDialog();
    } else {
      _horasExtras = null;
    }
  }

  void _showHorasExtrasDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
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
        );
      },
    );
  }

  Widget _buildPendienteSwitch() {
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
          const Expanded(
            child: Text(
              'Marcar como pendiente',
              style: TextStyle(fontSize: 16),
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
  }

  Widget _buildFotoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Foto de evidencia',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A8A),
          ),
        ),
        const SizedBox(height: 12),
        if (_fotoSeleccionada != null) ...[
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              image: DecorationImage(
                image: FileImage(_fotoSeleccionada!),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _tomarFoto,
                icon: const Icon(Icons.camera_alt),
                label: Text(
                    _fotoSeleccionada == null ? 'Tomar Foto' : 'Cambiar Foto'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            if (_fotoSeleccionada != null) ...[
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: () => setState(() => _fotoSeleccionada = null),
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

        // Pad de firma (como tu PadFirma de Kivy)
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
                label: const Text('Guardar Borrador'),
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
                label: const Text('Enviar Sanción'),
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
            'Guardando sanción...',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ],
    );
  }

  // Funciones de acción (como en tu Kivy)
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

  Future<void> _tomarFoto() async {
    final picker = ImagePicker();
    final foto = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );

    if (foto != null) {
      setState(() => _fotoSeleccionada = File(foto.path));
    }
  }

  Future<void> _guardarSancion(String status) async {
    if (!_formKey.currentState!.validate()) return;

    if (_empleadoSeleccionado == null) {
      _mostrarError('Debe seleccionar un empleado');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final sancionService = SancionService();

      final sancion = SancionModel(
        supervisorId: authProvider.currentUser!.id,
        empleadoCod: _empleadoSeleccionado!.cod,
        empleadoNombre: _empleadoSeleccionado!
            .displayName, // Usa displayName que siempre retorna String
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
      );

      await sancionService.createSancion(
        sancion: sancion,
        fotoFile: _fotoSeleccionada,
        signatureController:
            _signatureController.isNotEmpty ? _signatureController : null,
      );

      if (mounted) {
        Navigator.pop(context, true); // Regresar con resultado exitoso
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'borrador'
                ? '✅ Borrador guardado correctamente'
                : '📤 Sanción enviada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      _mostrarError('Error al guardar: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('❌ $mensaje'),
        backgroundColor: Colors.red,
      ),
    );
  }
}
