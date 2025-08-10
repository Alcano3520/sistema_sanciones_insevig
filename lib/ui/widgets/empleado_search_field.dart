import 'package:flutter/material.dart';
import '../../core/models/empleado_model.dart';
import '../../core/offline/empleado_repository.dart'; // 🔥 CAMBIO: Repository en vez de Service

/// Widget de búsqueda de empleados con autocompletado
/// Replica la funcionalidad de búsqueda de tu app Kivy
/// 🔥 ACTUALIZADO para usar EmpleadoRepository con funcionalidad offline
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
  final EmpleadoRepository _empleadoRepository =
      EmpleadoRepository.instance; // 🔥 CAMBIO

  List<EmpleadoModel> _resultados = [];
  bool _isSearching = false;
  bool _showResults = false;
  EmpleadoModel? _empleadoSeleccionado;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Campo de búsqueda
        TextFormField(
          controller: _controller,
          decoration: InputDecoration(
            labelText: 'Buscar empleado',
            hintText:
                widget.hintText ?? 'Nombre, cédula, cargo o departamento...',
            prefixIcon: _isSearching
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.search, color: Color(0xFF1E3A8A)),
            suffixIcon: _controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: _clearSearch,
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1E3A8A), width: 2),
            ),
          ),
          onChanged: _onSearchChanged,
          validator: (value) {
            if (_empleadoSeleccionado == null) {
              return 'Debe seleccionar un empleado';
            }
            return null;
          },
        ),

        // Empleado seleccionado
        if (_empleadoSeleccionado != null) ...[
          const SizedBox(height: 12),
          _buildEmpleadoSeleccionado(),
        ],

        // Resultados de búsqueda
        if (_showResults && _resultados.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildResultsList(),
        ],

        // Mensaje cuando no hay resultados
        if (_showResults &&
            _resultados.isEmpty &&
            !_isSearching &&
            _controller.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          _buildNoResults(),
        ],
      ],
    );
  }

  Widget _buildEmpleadoSeleccionado() {
    final empleado = _empleadoSeleccionado!;

    // Función auxiliar para obtener iniciales de forma segura
    String getInitials(String? fullName) {
      if (fullName == null || fullName.isEmpty) return 'NN';

      final words = fullName.trim().split(' ');
      if (words.length >= 2) {
        return '${words[0][0]}${words[1][0]}'.toUpperCase();
      } else if (words.isNotEmpty && words[0].isNotEmpty) {
        return words[0][0].toUpperCase();
      }
      return 'NN';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: Colors.green,
            child: Text(
              getInitials(empleado.displayName),
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
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Cód: ${empleado.cod} • ${empleado.nomcargo ?? 'Sin cargo'}',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                Text(
                  empleado.nomdep ?? 'Sin departamento',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
                if (empleado.cedula != null && empleado.cedula!.isNotEmpty)
                  Text(
                    'CI: ${empleado.cedula}',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.red),
            onPressed: _clearSelection,
            tooltip: 'Quitar selección',
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: _resultados.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final empleado = _resultados[index];
          return _buildEmpleadoTile(empleado);
        },
      ),
    );
  }

  Widget _buildEmpleadoTile(EmpleadoModel empleado) {
    // Función auxiliar para obtener iniciales de forma segura
    String getInitials(String? fullName) {
      if (fullName == null || fullName.isEmpty) return 'NN';

      final words = fullName.trim().split(' ');
      if (words.length >= 2) {
        return '${words[0][0]}${words[1][0]}'.toUpperCase();
      } else if (words.isNotEmpty && words[0].isNotEmpty) {
        return words[0][0].toUpperCase();
      }
      return 'NN';
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: const Color(0xFF1E3A8A),
        child: Text(
          getInitials(empleado.displayName),
          style: const TextStyle(color: Colors.white, fontSize: 12),
        ),
      ),
      title: Text(
        empleado.displayName,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Cód: ${empleado.cod} • ${empleado.nomcargo ?? 'Sin cargo'}'),
          Text(
            empleado.nomdep ?? 'Sin departamento',
            style: const TextStyle(fontSize: 12),
          ),
          if (empleado.cedula != null && empleado.cedula!.isNotEmpty)
            Text(
              'CI: ${empleado.cedula}',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
        ],
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: () => _selectEmpleado(empleado),
    );
  }

  Widget _buildNoResults() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_off, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sin resultados',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'No se encontraron empleados con: "${_controller.text}"',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _onSearchChanged(String query) {
    if (query.length >= 2) {
      _searchEmpleados(query);
    } else {
      setState(() {
        _showResults = false;
        _resultados = [];
      });
    }
  }

  Future<void> _searchEmpleados(String query) async {
    setState(() {
      _isSearching = true;
      _showResults = true;
    });

    try {
      // 🔥 CAMBIO: Usando repository en vez de service
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

        // 🔥 NUEVO: Mostrar si estamos offline
        final isOffline = e.toString().contains('offline') ||
            e.toString().contains('SocketException');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isOffline ? Icons.wifi_off : Icons.error_outline,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isOffline
                        ? 'Modo offline: mostrando resultados guardados'
                        : 'Error buscando empleados: $e',
                  ),
                ),
              ],
            ),
            backgroundColor: isOffline ? Colors.orange : Colors.red,
          ),
        );
      }
    }
  }

  void _selectEmpleado(EmpleadoModel empleado) {
    setState(() {
      _empleadoSeleccionado = empleado;
      _controller.text =
          empleado.displayName; // Usa displayName que siempre retorna String
      _showResults = false;
      _resultados = [];
    });

    // Ocultar el teclado
    FocusScope.of(context).unfocus();

    // Notificar al widget padre
    widget.onEmpleadoSelected(empleado);
  }

  void _clearSearch() {
    setState(() {
      _controller.clear();
      _showResults = false;
      _resultados = [];
    });
  }

  void _clearSelection() {
    setState(() {
      _empleadoSeleccionado = null;
      _controller.clear();
      _showResults = false;
      _resultados = [];
    });
  }
}
