import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/sancion_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/sancion_service.dart';
import 'edit_sancion_screen.dart'; // 🆕 IMPORT AGREGADO

/// Pantalla de detalle completo de una sanción
/// Muestra toda la información como en tu app Kivy pero con diseño moderno
class DetalleSancionScreen extends StatefulWidget {
  final SancionModel sancion;

  const DetalleSancionScreen({
    super.key,
    required this.sancion,
  });

  @override
  State<DetalleSancionScreen> createState() => _DetalleSancionScreenState();
}

class _DetalleSancionScreenState extends State<DetalleSancionScreen> {
  late SancionModel _sancion;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _sancion = widget.sancion;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Detalle de Sanción'),
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _compartirSancion,
            tooltip: 'Compartir',
          ),
          _buildActionsMenu(),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con status principal
            _buildHeaderCard(),

            const SizedBox(height: 16),

            // Información del empleado
            _buildEmpleadoCard(),

            const SizedBox(height: 16),

            // Detalles de la sanción
            _buildDetallesSancionCard(),

            const SizedBox(height: 16),

            // Observaciones
            if (_sancion.observaciones != null ||
                _sancion.observacionesAdicionales != null)
              _buildObservacionesCard(),

            const SizedBox(height: 16),

            // Evidencias (foto y firma)
            if (_sancion.fotoUrl != null || _sancion.firmaPath != null)
              _buildEvidenciasCard(),

            const SizedBox(height: 16),

            // Información de seguimiento
            _buildSeguimientoCard(),

            const SizedBox(height: 16),

            // Acciones según el rol
            _buildActionButtons(),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCard() {
    Color statusColor;
    IconData statusIcon;

    switch (_sancion.status) {
      case 'borrador':
        statusColor = Colors.orange;
        statusIcon = Icons.edit;
        break;
      case 'enviado':
        statusColor = Colors.blue;
        statusIcon = Icons.send;
        break;
      case 'aprobado':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rechazado':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [statusColor, statusColor.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  statusIcon,
                  size: 32,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _sancion.statusText.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      'ID: ${_sancion.id.substring(0, 8)}...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              if (_sancion.pendiente)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'PENDIENTE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Tipo de sanción destacado
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Text(
                  _sancion.tipoSancionEmoji,
                  style: const TextStyle(fontSize: 32),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _sancion.tipoSancion,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      if (_sancion.horasExtras != null)
                        Text(
                          '${_sancion.horasExtras} horas extras',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpleadoCard() {
    return _buildInfoCard(
      title: '👤 Información del Empleado',
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: const Color(0xFF1E3A8A),
                child: Text(
                  _sancion.empleadoNombre
                      .split(' ')
                      .take(2)
                      .map((e) => e[0])
                      .join(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _sancion.empleadoNombre,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Código: ${_sancion.empleadoCod}',
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetallesSancionCard() {
    return _buildInfoCard(
      title: '📋 Detalles de la Sanción',
      child: Column(
        children: [
          _buildDetailRow(
              'Fecha:', _sancion.fechaFormateada, Icons.calendar_today),
          const SizedBox(height: 12),
          _buildDetailRow('Hora:', _sancion.hora, Icons.access_time),
          const SizedBox(height: 12),
          _buildDetailRow('Puesto:', _sancion.puesto, Icons.location_on),
          const SizedBox(height: 12),
          _buildDetailRow('Agente:', _sancion.agente, Icons.person),
          const SizedBox(height: 12),
          _buildDetailRow(
              'Tipo:',
              '${_sancion.tipoSancionEmoji} ${_sancion.tipoSancion}',
              Icons.warning),
          if (_sancion.horasExtras != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow('Horas Extras:', '${_sancion.horasExtras} horas',
                Icons.schedule),
          ],
        ],
      ),
    );
  }

  Widget _buildObservacionesCard() {
    return _buildInfoCard(
      title: '📝 Observaciones',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_sancion.observaciones != null &&
              _sancion.observaciones!.isNotEmpty) ...[
            const Text(
              'Observaciones:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(_sancion.observaciones!),
            ),
          ],
          if (_sancion.observacionesAdicionales != null &&
              _sancion.observacionesAdicionales!.isNotEmpty) ...[
            if (_sancion.observaciones != null &&
                _sancion.observaciones!.isNotEmpty)
              const SizedBox(height: 16),
            const Text(
              'Observaciones Adicionales:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade300),
              ),
              child: Text(_sancion.observacionesAdicionales!),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEvidenciasCard() {
    return _buildInfoCard(
      title: '📷 Evidencias',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_sancion.fotoUrl != null) ...[
            const Text(
              'Foto de evidencia:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => _verFotoCompleta(_sancion.fotoUrl!),
              child: Container(
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
                    _sancion.fotoUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline,
                                size: 48, color: Colors.grey),
                            Text('Error cargando imagen'),
                          ],
                        ),
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
          if (_sancion.firmaPath != null) ...[
            if (_sancion.fotoUrl != null) const SizedBox(height: 16),
            const Text(
              'Firma del sancionado:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  _sancion.firmaPath!,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.draw, size: 48, color: Colors.grey),
                          Text('Firma no disponible'),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSeguimientoCard() {
    return _buildInfoCard(
      title: '📊 Información de Seguimiento',
      child: Column(
        children: [
          _buildDetailRow('Creada:', _formatDateTime(_sancion.createdAt),
              Icons.add_circle_outline),
          const SizedBox(height: 12),
          _buildDetailRow('Última actualización:',
              _formatDateTime(_sancion.updatedAt), Icons.update),
          if (_sancion.fechaRevision != null) ...[
            const SizedBox(height: 12),
            _buildDetailRow('Revisada:',
                _formatDateTime(_sancion.fechaRevision!), Icons.verified),
          ],
          if (_sancion.comentariosGerencia != null) ...[
            const SizedBox(height: 12),
            const Text(
              'Comentarios de Gerencia:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.shade300),
              ),
              child: Text(_sancion.comentariosGerencia!),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.currentUser!;
        final canEdit =
            user.id == _sancion.supervisorId && _sancion.status == 'borrador';
        final canApprove = user.canApprove && _sancion.status == 'enviado';
        final canTogglePendiente =
            user.canApprove || user.id == _sancion.supervisorId;

        if (!canEdit && !canApprove && !canTogglePendiente) {
          return const SizedBox.shrink();
        }

        return _buildInfoCard(
          title: '⚡ Acciones',
          child: Column(
            children: [
              if (canEdit) ...[
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _editarSancion,
                    icon: const Icon(Icons.edit),
                    label: const Text('Editar Sanción'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (canApprove) ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _cambiarStatus('aprobado'),
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Aprobar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _cambiarStatus('rechazado'),
                        icon: const Icon(Icons.cancel),
                        label: const Text('Rechazar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
              if (canTogglePendiente)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _togglePendiente,
                    icon: Icon(_sancion.pendiente
                        ? Icons.check
                        : Icons.pending_actions),
                    label: Text(_sancion.pendiente
                        ? 'Marcar como Resuelto'
                        : 'Marcar como Pendiente'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          _sancion.pendiente ? Colors.green : Colors.amber,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildInfoCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A8A),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.grey.shade600),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionsMenu() {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.currentUser!;
        final canDelete =
            user.id == _sancion.supervisorId && _sancion.status == 'borrador';

        return PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert),
          onSelected: _handleMenuAction,
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'refresh',
              child: Row(
                children: [
                  Icon(Icons.refresh),
                  SizedBox(width: 8),
                  Text('Actualizar'),
                ],
              ),
            ),
            if (canDelete)
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Eliminar', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  // Funciones de acción
  void _compartirSancion() {
    final texto = '''
SANCIÓN - ${_sancion.tipoSancion}
==================================
Empleado: ${_sancion.empleadoNombre} (${_sancion.empleadoCod})
Fecha: ${_sancion.fechaFormateada} ${_sancion.hora}
Puesto: ${_sancion.puesto}
Agente: ${_sancion.agente}
Status: ${_sancion.statusText}
Estado: ${_sancion.pendiente ? 'PENDIENTE' : 'RESUELTO'}

${_sancion.observaciones != null ? 'Observaciones: ${_sancion.observaciones}\n' : ''}
${_sancion.observacionesAdicionales != null ? 'Obs. Adicionales: ${_sancion.observacionesAdicionales}\n' : ''}
Creada: ${_formatDateTime(_sancion.createdAt)}
ID: ${_sancion.id}
    '''
        .trim();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('📋 Información preparada para compartir:\n\n$texto'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Cerrar',
          onPressed: () {},
        ),
      ),
    );
  }

  void _verFotoCompleta(String url) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Foto de evidencia'),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(
                url,
                errorBuilder: (context, error, stackTrace) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline,
                            size: 64, color: Colors.white),
                        Text('Error cargando imagen',
                            style: TextStyle(color: Colors.white)),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🔥 FUNCIÓN DE EDITAR ACTUALIZADA - YA NO MUESTRA "PRÓXIMAMENTE"
  void _editarSancion() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditSancionScreen(sancion: _sancion),
      ),
    );

    // Si se editó exitosamente, recargar la sanción
    if (result == true) {
      await _recargarSancion();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('✅ Sanción editada correctamente'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _cambiarStatus(String newStatus) {
    final isApproval = newStatus == 'aprobado';
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isApproval ? 'Aprobar Sanción' : 'Rechazar Sanción'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isApproval
                ? '¿Estás seguro de aprobar esta sanción?'
                : '¿Estás seguro de rechazar esta sanción?'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                labelText:
                    'Comentarios ${isApproval ? '(opcional)' : '(obligatorio)'}',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => _confirmarCambioStatus(newStatus, controller.text),
            child: Text(isApproval ? 'Aprobar' : 'Rechazar'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarCambioStatus(
      String newStatus, String comentarios) async {
    if (newStatus == 'rechazado' && comentarios.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Los comentarios son obligatorios para rechazar'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.pop(context);
    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final sancionService = SancionService();

      await sancionService.changeStatus(
        _sancion.id,
        newStatus,
        comentarios: comentarios.trim().isEmpty ? null : comentarios.trim(),
        reviewedBy: authProvider.currentUser!.id,
      );

      // Recargar la sanción
      final sancionActualizada =
          await sancionService.getSancionById(_sancion.id);
      if (sancionActualizada != null) {
        setState(() {
          _sancion = sancionActualizada;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newStatus == 'aprobado'
                ? '✅ Sanción aprobada correctamente'
                : '✅ Sanción rechazada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _togglePendiente() async {
    setState(() => _isLoading = true);

    try {
      final sancionService = SancionService();
      await sancionService.togglePendiente(_sancion.id, !_sancion.pendiente);

      setState(() {
        _sancion = _sancion.copyWith(pendiente: !_sancion.pendiente);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_sancion.pendiente
                ? '✅ Sanción marcada como pendiente'
                : '✅ Sanción marcada como resuelta'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleMenuAction(String action) {
    switch (action) {
      case 'refresh':
        _recargarSancion();
        break;
      case 'delete':
        _eliminarSancion();
        break;
    }
  }

  Future<void> _recargarSancion() async {
    setState(() => _isLoading = true);

    try {
      final sancionService = SancionService();
      final sancionActualizada =
          await sancionService.getSancionById(_sancion.id);

      if (sancionActualizada != null) {
        setState(() {
          _sancion = sancionActualizada;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Sanción actualizada'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error actualizando: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _eliminarSancion() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Sanción'),
        content: const Text(
          '¿Estás seguro de eliminar esta sanción?\n\n'
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: _confirmarEliminacion,
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmarEliminacion() async {
    Navigator.pop(context); // Cerrar dialog
    setState(() => _isLoading = true);

    try {
      final sancionService = SancionService();
      await sancionService.deleteSancion(_sancion.id);

      if (mounted) {
        Navigator.pop(context, true); // Volver al historial
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Sanción eliminada correctamente'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error eliminando: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
