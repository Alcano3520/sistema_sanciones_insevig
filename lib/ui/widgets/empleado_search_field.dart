import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../../core/models/empleado_model.dart';
import '../../core/offline/empleado_repository.dart';
import '../../core/offline/offline_manager.dart';

/// Widget funcional - muestra DEPARTAMENTO
class EmpleadoSearchField extends StatefulWidget {
  final Function(EmpleadoModel) onEmpleadoSelected;
  final String? hintText;

  const EmpleadoSearchField({
    super.key,
    required this.onEmpleadoSelected,
    this.hintText,
  });

  @override
  State<EmpleadoSearchField> createState() => _EmpleadoSearchFieldState();
}

class _EmpleadoSearchFieldState extends State<EmpleadoSearchField> {
  final TextEditingController _controller = TextEditingController();
  final EmpleadoRepository _empleadoRepository = EmpleadoRepository.instance;

  List<EmpleadoModel> _resultados = [];
  bool _isSearching = false;
  EmpleadoModel? _empleadoSeleccionado;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _controller,
          decoration: InputDecoration(
            hintText: 'Buscar empleado...',
            prefixIcon: _isSearching 
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.search),
            border: const OutlineInputBorder(),
          ),
          onChanged: _onSearchChanged,
        ),

        if (_empleadoSeleccionado != null) ...[
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              border: Border.all(color: Colors.green),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              dense: true,
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: Text(
                _empleadoSeleccionado!.displayName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    _empleadoSeleccionado = null;
                    _controller.clear();
                    _resultados = [];
                  });
                },
              ),
            ),
          ),
        ],

        if (_resultados.isNotEmpty && _empleadoSeleccionado == null) ...[
          const SizedBox(height: 8),
          Container(
            height: 120,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListView.builder(
              itemCount: _resultados.length,
              itemBuilder: (context, index) {
                final empleado = _resultados[index];
                return ListTile(
                  dense: true,
                  title: Text(empleado.displayName),
                  subtitle: empleado.nomdep != null ? Text(empleado.nomdep!) : null,
                  onTap: () {
                    setState(() {
                      _empleadoSeleccionado = empleado;
                      _controller.text = empleado.displayName;
                      _resultados = [];
                    });
                    FocusScope.of(context).unfocus();
                    widget.onEmpleadoSelected(empleado);
                  },
                );
              },
            ),
          ),
        ],

        if (_resultados.isEmpty && !_isSearching && _controller.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text('No se encontraron empleados'),
        ],
      ],
    );
  }

  void _onSearchChanged(String query) {
    if (query.length >= 2) {
      _searchEmpleados(query);
    } else {
      setState(() {
        _resultados = [];
      });
    }
  }

  Future<void> _searchEmpleados(String query) async {
    if (!mounted) return;

    setState(() {
      _isSearching = true;
    });

    try {
      final resultados = await _empleadoRepository.searchEmpleados(query);
      if (mounted) {
        setState(() {
          _resultados = resultados;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _resultados = [];
          _isSearching = false;
        });
      }
    }
  }
}

// Widget para debuggear overflow
class OverflowDebugger extends StatelessWidget {
  final Widget child;
  final String label;

  const OverflowDebugger({
    super.key,
    required this.child,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.red, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            color: Colors.red,
            width: double.infinity,
            padding: const EdgeInsets.all(2),
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 8),
              textAlign: TextAlign.center,
            ),
          ),
          child,
        ],
      ),
    );
  }
}

// Versión ultra simple para comparar
class EmpleadoSearchSimple extends StatefulWidget {
  final Function(EmpleadoModel) onEmpleadoSelected;

  const EmpleadoSearchSimple({
    super.key,
    required this.onEmpleadoSelected,
  });

  @override
  State<EmpleadoSearchSimple> createState() => _EmpleadoSearchSimpleState();
}

class _EmpleadoSearchSimpleState extends State<EmpleadoSearchSimple> {
  final TextEditingController _controller = TextEditingController();
  final EmpleadoRepository _empleadoRepository = EmpleadoRepository.instance;
  List<EmpleadoModel> _resultados = [];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: 'Buscar...',
              border: OutlineInputBorder(),
            ),
            onChanged: (query) {
              if (query.length >= 2) {
                _search(query);
              } else {
                setState(() => _resultados = []);
              }
            },
          ),
          
          if (_resultados.isNotEmpty)
            SizedBox(
              height: 100,
              child: ListView(
                children: _resultados.map((empleado) => 
                  TextButton(
                    onPressed: () => widget.onEmpleadoSelected(empleado),
                    child: Text(empleado.displayName),
                  )
                ).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _search(String query) async {
    try {
      final resultados = await _empleadoRepository.searchEmpleados(query);
      if (mounted) setState(() => _resultados = resultados);
    } catch (e) {
      if (mounted) setState(() => _resultados = []);
    }
  }
}

// Contenedores que NO dan overflow
class EmpleadoSearchDialog {
  static Future<EmpleadoModel?> showBottomSheet(BuildContext context) {
    return showModalBottomSheet<EmpleadoModel>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 16,
            left: 16,
            right: 16,
          ),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  const Icon(Icons.search),
                  const SizedBox(width: 8),
                  const Text('Buscar Empleados', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              Expanded(
                child: EmpleadoSearchField(
                  onEmpleadoSelected: (empleado) => Navigator.pop(context, empleado),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<EmpleadoModel?> showAlert(BuildContext context) {
    return showDialog<EmpleadoModel>(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: const EdgeInsets.all(16),
        title: const Text('Buscar Empleados'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: EmpleadoSearchField(
            onEmpleadoSelected: (empleado) => Navigator.pop(context, empleado),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}