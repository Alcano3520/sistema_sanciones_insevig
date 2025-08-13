import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/models/sancion_model.dart';
import '../../core/offline/sancion_repository.dart';

/// Widget para mostrar una sanción en formato card
/// Incluye funcionalidades de aprobar, rechazar y gestionar según el rol
/// ✅ CORREGIDO: Agregados callbacks para sistema jerárquico
/// ✅ NUEVO: Muestra información del supervisor para gerencia/RRHH
class SancionCard extends StatelessWidget {
  final SancionModel sancion;
  final VoidCallback? onTap;
  final VoidCallback? onStatusChanged;
  
  // ✅ NUEVOS CALLBACKS PARA SISTEMA JERÁRQUICO
  final VoidCallback? onApprobar;
  final VoidCallback? onRechazar; 
  final VoidCallback? onRevisionRrhh;

  const SancionCard({
    super.key,
    required this.sancion,
    this.onTap,
    this.onStatusChanged,
    // ✅ Nuevos parámetros opcionales
    this.onApprobar,
    this.onRechazar,
    this.onRevisionRrhh,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final currentUser = authProvider.currentUser;
        if (currentUser == null) return const SizedBox.shrink();

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: _getStatusColor().withOpacity(0.3),
              width: 1,
            ),
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header con tipo de sanción y status
                  Row(
                    children: [
                      // Emoji y tipo
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _getStatusColor().withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          sancion.tipoSancionEmoji,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              sancion.tipoSancion,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              sancion.empleadoNombre,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Status badge
                      _buildStatusBadge(),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Información principal
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoColumn('Empleado', '${sancion.empleadoNombre} (#${sancion.empleadoCod})'),
                      ),
                      Expanded(
                        child: _buildInfoColumn('Fecha', sancion.fechaFormateada),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoColumn('Puesto', sancion.puesto),
                      ),
                      Expanded(
                        child: _buildInfoColumn('Agente', sancion.agente),
                      ),
                    ],
                  ),

                  // ✅ NUEVO: Información del supervisor (solo para gerencia/RRHH)
                  _buildSupervisorInfo(currentUser),

                  // Observaciones si existen
                  if (sancion.observaciones != null && sancion.observaciones!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Observaciones: ${sancion.observaciones}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontStyle: FontStyle.italic,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // ✅ MOSTRAR COMENTARIOS DE GERENCIA SI EXISTEN
                  if (sancion.comentariosGerencia != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.blue.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.business, size: 16, color: Colors.blue),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Gerencia: ${sancion.comentariosGerencia}',
                              style: const TextStyle(fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // ✅ MOSTRAR COMENTARIOS DE RRHH SI EXISTEN
                  if (sancion.comentariosRrhh != null) ...[
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.admin_panel_settings, size: 16, color: Colors.green),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'RRHH: ${sancion.comentariosRrhh}',
                              style: const TextStyle(fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // ✅ BOTONES DE ACCIÓN ESPECÍFICOS POR ROL
                  _buildActionButtons(currentUser),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// ✅ NUEVO: Construir información del supervisor (solo para gerencia/RRHH)
  Widget _buildSupervisorInfo(dynamic currentUser) {
    // Solo mostrar para gerencia y RRHH
    if (currentUser == null || !currentUser.canApprove) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.indigo.withOpacity(0.05),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.indigo.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Colors.indigo.withOpacity(0.2),
            child: Text(
              sancion.supervisorInitials,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.indigo,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.supervisor_account,
            size: 14,
            color: Colors.indigo.withOpacity(0.7),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              sancion.supervisorDisplay,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Colors.indigo,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ NUEVO: Construir botones de acción según el rol y contexto
  Widget _buildActionButtons(dynamic currentUser) {
    final canApprove = currentUser.canApprove;
    final role = currentUser.role;

    // Si es modo aprobación y hay callbacks específicos, mostrar botones jerárquicos
    if (canApprove) {
      // Para GERENCIA: botones de aprobar/rechazar si está en modo aprobación
      if (role == 'gerencia' && onApprobar != null && sancion.canBeApprovedByGerencia) {
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onRechazar,
                icon: const Icon(Icons.cancel, size: 16),
                label: const Text('Rechazar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: onApprobar,
                icon: const Icon(Icons.check_circle, size: 16),
                label: const Text('Aprobar con Código'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        );
      }

      // Para RRHH: botón de revisión si está en modo aprobación
      if (role == 'rrhh' && onRevisionRrhh != null && sancion.canBeReviewedByRrhh) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onRevisionRrhh,
            icon: const Icon(Icons.admin_panel_settings, size: 16),
            label: const Text('Revisión RRHH'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E3A8A),
              foregroundColor: Colors.white,
            ),
          ),
        );
      }
    }

    // Botones estándar para otros casos
    return _buildStandardActionButtons(currentUser);
  }

  /// Botones de acción estándar (los que ya existían)
  Widget _buildStandardActionButtons(dynamic currentUser) {
    final canEdit = sancion.supervisorId == currentUser.id && sancion.status == 'borrador';
    final canChangeStatus = currentUser.canChangeStatus;
    final canTogglePendiente = currentUser.canApprove || sancion.supervisorId == currentUser.id;

    final buttons = <Widget>[];

    // Botón de editar (solo borradores propios)
    if (canEdit) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: () => _editSancion(),
          icon: const Icon(Icons.edit, size: 16),
          label: const Text('Editar'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF1E3A8A),
          ),
        ),
      );
    }

    // Botón de cambiar status
    if (canChangeStatus && sancion.status == 'borrador') {
      buttons.add(
        ElevatedButton.icon(
          onPressed: () => _changeStatus('enviado'),
          icon: const Icon(Icons.send, size: 16),
          label: const Text('Enviar'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
      );
    }

    // Botón toggle pendiente
    if (canTogglePendiente) {
      buttons.add(
        OutlinedButton.icon(
          onPressed: () => _togglePendiente(),
          icon: Icon(
            sancion.pendiente ? Icons.check_circle : Icons.pending,
            size: 16,
          ),
          label: Text(sancion.pendiente ? 'Marcar Resuelto' : 'Marcar Pendiente'),
          style: OutlinedButton.styleFrom(
            foregroundColor: sancion.pendiente ? Colors.green : Colors.orange,
          ),
        ),
      );
    }

    if (buttons.isEmpty) {
      return const SizedBox.shrink();
    }

    if (buttons.length == 1) {
      return SizedBox(
        width: double.infinity,
        child: buttons.first,
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: buttons,
    );
  }

  Widget _buildInfoColumn(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildStatusBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (sancion.pendiente) ...[
            const Icon(Icons.pending, size: 12, color: Colors.white),
            const SizedBox(width: 4),
          ],
          Text(
            sancion.statusText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
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

  // Métodos de acción
  void _editSancion() {
    // Implementar navegación a edición
    print('Editar sanción: ${sancion.id}');
  }

  Future<void> _changeStatus(String newStatus) async {
    try {
      final repository = SancionRepository.instance;
      
      final success = await repository.changeStatus(
        sancion.id,
        newStatus,
        reviewedBy: sancion.supervisorId,
      );

      if (success) {
        onStatusChanged?.call();
      }
    } catch (e) {
      print('Error cambiando status: $e');
    }
  }

  Future<void> _togglePendiente() async {
    try {
      final repository = SancionRepository.instance;
      
      final success = await repository.togglePendiente(
        sancion.id,
        !sancion.pendiente,
      );

      if (success) {
        onStatusChanged?.call();
      }
    } catch (e) {
      print('Error toggle pendiente: $e');
    }
  }
}