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
import 'package:flutter/foundation.dart';
import '../widgets/image_display_widget.dart';
import '../widgets/empleado_search_field.dart';

/// Pantalla para crear nueva sanción - EXACTAMENTE como tu PantallaSancion de Kivy
/// ACTUALIZADA con compresión automática de imágenes
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
  bool _isProcessingImage = false; // 🆕 Para mostrar estado de compresión

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
        isExpanded: true, // Importante para evitar overflow
        decoration: const InputDecoration(
          labelText: 'Seleccionar sanción',
          prefixIcon: Icon(Icons.warning, color: Color(0xFF1E3A8A)),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        items: SancionModel.tiposSancion.map((tipo) {
          return DropdownMenuItem(
            value: tipo,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 250), // Limitar ancho
              child: Text(
                _getTipoSancionLabel(tipo),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          );
        }).toList(),
        onChanged: (value) => _onTipoSancionChanged(value!),
        validator: (value) {
          if (value?.isEmpty ?? true) {
            return 'Debe seleccionar un tipo de sanción';
          }
          return null;
        },
        // Personalizar el dropdown menu
        dropdownColor: Colors.white,
        menuMaxHeight: 300,
        icon: const Icon(Icons.arrow_drop_down),
        iconSize: 24,
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
            // 🆕 Indicador de plataforma
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
            // Indicador de procesamiento
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

        if (_fotoSeleccionada != null) ...[
          ImageDisplayWidget(
            imageFile: _fotoSeleccionada,
            height: 200,
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
        final sancionService = SancionService();
        final validation = await sancionService.validateImage(file);

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

      // 🆕 Usar el servicio ACTUALIZADO con compresión automática
      await sancionService.createSancion(
        sancion: sancion,
        fotoFile: _fotoSeleccionada, // Se comprime automáticamente
        signatureController:
            _signatureController.isNotEmpty ? _signatureController : null,
      );

      // 🆕 Limpiar archivos temporales después de guardar
      await sancionService.cleanupTempFiles();

      if (mounted) {
        Navigator.pop(context, true); // Regresar con resultado exitoso
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(status == 'borrador'
                    ? '✅ Borrador guardado correctamente'
                    : '📤 Sanción enviada correctamente'),
              ],
            ),
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
