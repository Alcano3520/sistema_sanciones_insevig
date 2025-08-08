import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/sancion_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/sancion_service.dart';
import '../screens/edit_sancion_screen.dart'; // 🆕 IMPORT AGREGADO

/// Widget de tarjeta para mostrar una sanción en la lista
/// Similar a como mostraba cada sanción en tu PantallaHistorial de Kivy
class SancionCard extends StatelessWidget {
  final SancionModel sancion;
  final VoidCallback onTap;
  final VoidCallback? onStatusChanged;

  const SancionCard({
    super.key,
    required this.sancion,
    required this.onTap,
    this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header con empleado y status
              _buildHeader(context),

              const SizedBox(height: 12),

              // Información principal
              _buildMainInfo(),

              const SizedBox(height: 12),

              // Footer con fecha, hora y acciones
              _buildFooter(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        // Avatar del empleado
        CircleAvatar(
          backgroundColor: _getStatusColor(),
          radius: 20, // Reducido de 24
          child: Text(
            sancion.empleadoNombre.split(' ').take(2).map((e) => e[0]).join(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14, // Reducido
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Información del empleado - EXPANDIDO CORRECTAMENTE
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sancion.empleadoNombre,
                style: const TextStyle(
                  fontSize: 14, // Reducido de 16
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Cód: ${sancion.empleadoCod}',
                style: const TextStyle(
                  fontSize: 11, // Reducido de 12
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 8), // Espacio antes del badge

        // Status badge
        _buildStatusBadge(),
      ],
    );
  }

  Widget _buildStatusBadge() {
    Color color;
    IconData icon;

    switch (sancion.status) {
      case 'borrador':
        color = Colors.orange;
        icon = Icons.edit;
        break;
      case 'enviado':
        color = Colors.blue;
        icon = Icons.send;
        break;
      case 'aprobado':
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case 'rechazado':
        color = Colors.red;
        icon = Icons.cancel;
        break;
      default:
        color = Colors.grey;
        icon = Icons.info;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            sancion.statusText,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tipo de sanción con emoji
        Row(
          children: [
            Text(
              sancion.tipoSancionEmoji,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                sancion.tipoSancion,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ),
            // Indicador de pendiente
            if (sancion.pendiente)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'PENDIENTE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber,
                  ),
                ),
              ),
          ],
        ),

        const SizedBox(height: 8),

        // Puesto y agente
        Row(
          children: [
            const Icon(Icons.location_on, size: 16, color: Colors.grey),
            const SizedBox(width: 4),
            Text(
              sancion.puesto,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
            const SizedBox(width: 16),
            const Icon(Icons.person, size: 16, color: Colors.grey),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                sancion.agente,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),

        // Observaciones (si existen)
        if (sancion.observaciones != null &&
            sancion.observaciones!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.note, size: 16, color: Colors.grey),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sancion.observaciones!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],

        // Horas extras (si aplica)
        if (sancion.horasExtras != null) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${sancion.horasExtras} horas extras',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      children: [
        // Fecha y hora
        Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          sancion.fechaFormateada,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(width: 12),
        Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          sancion.hora,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),

        const Spacer(),

        // Indicadores de archivos
        Row(
          children: [
            if (sancion.fotoUrl != null)
              Container(
                margin: const EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.camera_alt,
                  size: 16,
                  color: Colors.green.shade600,
                ),
              ),
            if (sancion.firmaPath != null)
              Container(
                margin: const EdgeInsets.only(right: 4),
                child: Icon(
                  Icons.draw,
                  size: 16,
                  color: Colors.blue.shade600,
                ),
              ),
          ],
        ),

        // Menú de acciones
        _buildActionsMenu(context),
      ],
    );
  }

  Widget _buildActionsMenu(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final user = authProvider.currentUser!;
        final canEdit =
            user.id == sancion.supervisorId && sancion.status == 'borrador';
        final canApprove = user.canApprove && sancion.status == 'enviado';
        final canTogglePendiente = user.canApprove;

        if (!canEdit && !canApprove && !canTogglePendiente) {
          return const SizedBox.shrink();
        }

        return PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, size: 18, color: Colors.grey.shade600),
          onSelected: (action) => _handleAction(context, action),
          itemBuilder: (context) => [
            if (canEdit)
              const PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, size: 18, color: Color(0xFF1E3A8A)),
                    SizedBox(width: 8),
                    Text('Editar'),
                  ],
                ),
              ),
            if (canApprove) ...[
              const PopupMenuItem(
                value: 'approve',
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.green, size: 18),
                    SizedBox(width: 8),
                    Text('Aprobar'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'reject',
                child: Row(
                  children: [
                    Icon(Icons.cancel, color: Colors.red, size: 18),
                    SizedBox(width: 8),
                    Text('Rechazar'),
                  ],
                ),
              ),
            ],
            if (canTogglePendiente)
              PopupMenuItem(
                value: sancion.pendiente ? 'resolver' : 'pendiente',
                child: Row(
                  children: [
                    Icon(
                      sancion.pendiente ? Icons.check : Icons.pending_actions,
                      color: sancion.pendiente ? Colors.green : Colors.orange,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(sancion.pendiente
                        ? 'Marcar como resuelto'
                        : 'Marcar como pendiente'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'share',
              child: Row(
                children: [
                  Icon(Icons.share, size: 18),
                  SizedBox(width: 8),
                  Text('Compartir'),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Color _getStatusColor() {
    switch (sancion.status) {
      case 'borrador':
        return Colors.orange;
      case 'enviado':
        return Colors.blue;
      case 'aprobado':
        return Colors.green;
      case 'rechazado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _handleAction(BuildContext context, String action) async {
    final sancionService = SancionService();

    switch (action) {
      case 'edit':
        // 🔥 NAVEGACIÓN A PANTALLA DE EDICIÓN IMPLEMENTADA
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditSancionScreen(sancion: sancion),
          ),
        );

        // Si se editó exitosamente, recargar el historial
        if (result == true && onStatusChanged != null) {
          onStatusChanged!();

          // Mostrar confirmación
          if (context.mounted) {
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
        break;

      case 'approve':
        _showApprovalDialog(context, true);
        break;

      case 'reject':
        _showApprovalDialog(context, false);
        break;

      case 'pendiente':
      case 'resolver':
        try {
          final newPendiente = action == 'pendiente';
          await sancionService.togglePendiente(sancion.id, newPendiente);

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(
                      newPendiente ? Icons.pending_actions : Icons.check_circle,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(newPendiente
                        ? '⏳ Sanción marcada como pendiente'
                        : '✅ Sanción marcada como resuelta'),
                  ],
                ),
                backgroundColor: newPendiente ? Colors.orange : Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
            onStatusChanged?.call();
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 8),
                    Text('❌ Error: $e'),
                  ],
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
        break;

      case 'share':
        _shareSancion(context);
        break;
    }
  }

  void _showApprovalDialog(BuildContext context, bool approve) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              approve ? Icons.check_circle : Icons.cancel,
              color: approve ? Colors.green : Colors.red,
            ),
            const SizedBox(width: 8),
            Text(approve ? 'Aprobar Sanción' : 'Rechazar Sanción'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(approve
                ? '¿Estás seguro de aprobar esta sanción?'
                : '¿Estás seguro de rechazar esta sanción?'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                labelText:
                    'Comentarios ${approve ? '(opcional)' : '(obligatorio)'}',
                border: const OutlineInputBorder(),
                hintText: approve
                    ? 'Comentarios opcionales sobre la aprobación...'
                    : 'Explica por qué se rechaza la sanción...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (!approve && controller.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content:
                        Text('Los comentarios son obligatorios para rechazar'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context);

              try {
                final sancionService = SancionService();
                final authProvider =
                    Provider.of<AuthProvider>(context, listen: false);

                await sancionService.changeStatus(
                  sancion.id,
                  approve ? 'aprobado' : 'rechazado',
                  comentarios: controller.text.trim().isEmpty
                      ? null
                      : controller.text.trim(),
                  reviewedBy: authProvider.currentUser!.id,
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(
                            approve ? Icons.check_circle : Icons.cancel,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(approve
                              ? '✅ Sanción aprobada correctamente'
                              : '❌ Sanción rechazada correctamente'),
                        ],
                      ),
                      backgroundColor: approve ? Colors.green : Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  onStatusChanged?.call();
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.white),
                          const SizedBox(width: 8),
                          Text('❌ Error: $e'),
                        ],
                      ),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: approve ? Colors.green : Colors.red,
              foregroundColor: Colors.white,
            ),
            icon: Icon(approve ? Icons.check_circle : Icons.cancel),
            label: Text(approve ? 'Aprobar' : 'Rechazar'),
          ),
        ],
      ),
    );
  }

  void _shareSancion(BuildContext context) {
    final texto = '''
📋 SANCIÓN - ${sancion.tipoSancion}
=====================================
👤 Empleado: ${sancion.empleadoNombre} (${sancion.empleadoCod})
📅 Fecha: ${sancion.fechaFormateada} ${sancion.hora}
📍 Puesto: ${sancion.puesto}
🧑‍💼 Agente: ${sancion.agente}
📊 Status: ${sancion.statusText}
${sancion.pendiente ? '⏳ Estado: PENDIENTE' : '✅ Estado: RESUELTO'}

${sancion.observaciones != null ? '📝 Observaciones: ${sancion.observaciones}\n' : ''}${sancion.observacionesAdicionales != null ? '📝 Obs. Adicionales: ${sancion.observacionesAdicionales}\n' : ''}${sancion.horasExtras != null ? '⏱️ Horas extras: ${sancion.horasExtras}\n' : ''}
🔗 ID: ${sancion.id}
📅 Creada: ${sancion.createdAt.day}/${sancion.createdAt.month}/${sancion.createdAt.year}

--- Sistema de Sanciones INSEVIG ---
    '''
        .trim();

    // Mostrar en un dialog con opción de copiar
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.share, color: Color(0xFF1E3A8A)),
            SizedBox(width: 8),
            Text('Compartir Sanción'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Información preparada para compartir:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: SelectableText(
                  texto,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              // Aquí podrías implementar la funcionalidad de copiar al portapapeles
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.content_copy, color: Colors.white),
                      SizedBox(width: 8),
                      Text('📋 Información lista para compartir'),
                    ],
                  ),
                  backgroundColor: Colors.blue,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.content_copy),
            label: const Text('Copiar'),
          ),
        ],
      ),
    );
  }
}
