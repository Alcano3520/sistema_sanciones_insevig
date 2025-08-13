import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models/sancion_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/sancion_service.dart';
import '../screens/edit_sancion_screen.dart';
import '../widgets/codigo_descuento_dialog.dart'; // 🆕 IMPORT AGREGADO

/// Widget de tarjeta para mostrar una sanción en la lista
/// Similar a como mostraba cada sanción en tu PantallaHistorial de Kivy
/// 🆕 AHORA CON SISTEMA DE CÓDIGOS DE DESCUENTO Y BOTONES POR ROL
class SancionCard extends StatelessWidget {
  final SancionModel sancion;
  final VoidCallback onTap;
  final VoidCallback? onStatusChanged;
  
  // 🆕 NUEVOS PARÁMETROS PARA CONTROL POR ROL
  final bool showCodigoDescuento;
  final bool showProcesamientoRRHH;
  final bool showBotonesGerencia;
  final bool showBotonesRRHH;

  const SancionCard({
    super.key,
    required this.sancion,
    required this.onTap,
    this.onStatusChanged,
    // 🆕 PARÁMETROS OPCIONALES CON DEFAULTS
    this.showCodigoDescuento = false,
    this.showProcesamientoRRHH = false,
    this.showBotonesGerencia = false,
    this.showBotonesRRHH = false,
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

              // 🆕 CÓDIGO DE DESCUENTO (SI APLICA)
              if (showCodigoDescuento) ...[
                _buildCodigoDescuentoSection(),
                const SizedBox(height: 12),
              ],

              // 🆕 PROCESAMIENTO RRHH (SI APLICA)
              if (showProcesamientoRRHH) ...[
                _buildProcesamientoRRHHSection(),
                const SizedBox(height: 12),
              ],

              // 🆕 BOTONES DE GERENCIA (SI APLICA)
              if (showBotonesGerencia) ...[
                _buildBotonesGerencia(context),
                const SizedBox(height: 12),
              ],

              // 🆕 BOTONES DE RRHH (SI APLICA)
              if (showBotonesRRHH) ...[
                _buildBotonesRRHH(context),
                const SizedBox(height: 12),
              ],

              // Footer con fecha, hora y acciones (SIEMPRE AL FINAL)
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
          radius: 20,
          child: Text(
            sancion.empleadoNombre.split(' ').take(2).map((e) => e[0]).join(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
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
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Cód: ${sancion.empleadoCod}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(width: 8),

        // Status badge
        _buildStatusBadge(),
      ],
    );
  }

  Widget _buildStatusBadge() {
    Color color;
    IconData icon;
    String text;

    // 🆕 LÓGICA EXTENDIDA PARA ESTADOS DE APROBACIÓN
    if (sancion.status == 'aprobado') {
      if (sancion.comentariosRrhh != null) {
        // Procesado por RRHH
        color = Colors.blue;
        icon = Icons.verified;
        text = 'Procesado RRHH';
      } else if (sancion.comentariosGerencia != null) {
        // Aprobado por gerencia, pendiente RRHH
        color = Colors.orange;
        icon = Icons.pending_actions;
        text = 'Pendiente RRHH';
      } else {
        // Aprobado normal (sin códigos)
        color = Colors.green;
        icon = Icons.check_circle;
        text = 'Aprobado';
      }
    } else {
      // Estados originales
      switch (sancion.status) {
        case 'borrador':
          color = Colors.orange;
          icon = Icons.edit;
          text = 'Borrador';
          break;
        case 'enviado':
          color = Colors.blue;
          icon = Icons.send;
          text = 'Enviado';
          break;
        case 'rechazado':
          color = Colors.red;
          icon = Icons.cancel;
          text = 'Rechazado';
          break;
        default:
          color = Colors.grey;
          icon = Icons.info;
          text = sancion.status;
      }
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
            text,
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

  // 🆕 MOSTRAR CÓDIGO DE DESCUENTO APLICADO POR GERENCIA
  Widget _buildCodigoDescuentoSection() {
    final comentario = sancion.comentariosGerencia!;
    final codigo = _extraerCodigo(comentario);
    final textoComentario = _extraerComentario(comentario);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_user, color: Colors.green, size: 16),
              const SizedBox(width: 8),
              Text(
                'Aprobado por Gerencia',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.green.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Mostrar código de descuento si no es SIN_DESC
          if (codigo != 'SIN_DESC' && codigo != 'RECHAZADO') ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.percent, size: 14, color: Colors.red),
                  const SizedBox(width: 4),
                  Text(
                    codigo, // D05%, D10%, etc.
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ] else if (codigo == 'SIN_DESC') ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, size: 14, color: Colors.blue),
                  SizedBox(width: 4),
                  Text(
                    'SIN DESCUENTO',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          
          // Comentario de gerencia
          Text(
            textoComentario,
            style: const TextStyle(
              fontSize: 12, 
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // 🆕 MOSTRAR PROCESAMIENTO FINAL DE RRHH
  Widget _buildProcesamientoRRHHSection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.business_center, color: Colors.blue, size: 16),
              const SizedBox(width: 8),
              Text(
                'Procesado por RRHH',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Indicadores de tipo de procesamiento
          if (sancion.comentariosRrhh!.startsWith('MODIFICADO')) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'MODIFICADO',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.purple,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ] else if (sancion.comentariosRrhh!.startsWith('ANULADO_RRHH')) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'ANULADO',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
          
          Text(
            _extraerComentarioRRHH(sancion.comentariosRrhh!),
            style: const TextStyle(
              fontSize: 12, 
              fontStyle: FontStyle.italic,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // 🆕 BOTONES ESPECÍFICOS PARA GERENCIA
  Widget _buildBotonesGerencia(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.admin_panel_settings, color: Colors.amber, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Acción requerida - Gerencia',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _mostrarDialogoCodigoDescuento(context, true),
                  icon: const Icon(Icons.check_circle),
                  label: const Text('APROBAR CON CÓDIGO'),
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
                  onPressed: () => _mostrarDialogoCodigoDescuento(context, false),
                  icon: const Icon(Icons.cancel),
                  label: const Text('RECHAZAR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 🆕 BOTONES ESPECÍFICOS PARA RRHH
  Widget _buildBotonesRRHH(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.business_center, color: Colors.blue, size: 16),
              const SizedBox(width: 8),
              const Text(
                'Acción requerida - RRHH',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          
          // Mostrar código aplicado por gerencia
          if (sancion.comentariosGerencia != null) _buildCodigoDescuentoSection(),
          
          const SizedBox(height: 12),
          
          // Botón principal: Confirmar procesamiento
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _procesarRRHH(context, 'confirmar'),
              icon: const Icon(Icons.verified),
              label: const Text('CONFIRMAR PROCESAMIENTO'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Botones secundarios
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _procesarRRHH(context, 'modificar'),
                  icon: const Icon(Icons.edit),
                  label: const Text('MODIFICAR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _procesarRRHH(context, 'anular'),
                  icon: const Icon(Icons.block),
                  label: const Text('ANULAR'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // FOOTER ORIGINAL (MANTENIDO SIN CAMBIOS)
  Widget _buildFooter(BuildContext context) {
    return Row(
      children: [
        // Fecha y hora - ENVUELTO EN FLEXIBLE
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  sancion.fechaFormateada,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.access_time, size: 14, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                sancion.hora,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),

        const Spacer(),

        // Indicadores de archivos
        if (sancion.fotoUrl != null || sancion.firmaPath != null) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (sancion.fotoUrl != null)
                Icon(
                  Icons.camera_alt,
                  size: 16,
                  color: Colors.green.shade600,
                ),
              if (sancion.fotoUrl != null && sancion.firmaPath != null)
                const SizedBox(width: 4),
              if (sancion.firmaPath != null)
                Icon(
                  Icons.draw,
                  size: 16,
                  color: Colors.blue.shade600,
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],

        // Menú de acciones (SOLO SI NO HAY BOTONES ESPECÍFICOS)
        if (!showBotonesGerencia && !showBotonesRRHH) _buildActionsMenu(context),
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

  // ==========================================
  // 🆕 MÉTODOS AUXILIARES PARA CÓDIGOS
  // ==========================================

  /// Extraer código del formato "D05%|Comentario de gerencia"
  String _extraerCodigo(String comentarioCompleto) {
    if (comentarioCompleto.contains('|')) {
      return comentarioCompleto.split('|')[0];
    }
    return comentarioCompleto;
  }

  /// Extraer comentario sin código
  String _extraerComentario(String comentarioCompleto) {
    if (comentarioCompleto.contains('|')) {
      final partes = comentarioCompleto.split('|');
      return partes.length > 1 ? partes[1] : '';
    }
    return comentarioCompleto;
  }

  /// Extraer comentario de RRHH limpio
  String _extraerComentarioRRHH(String comentarioRRHH) {
    if (comentarioRRHH.startsWith('MODIFICADO|')) {
      final partes = comentarioRRHH.split('|');
      return partes.length > 2 ? partes[2] : '';
    } else if (comentarioRRHH.startsWith('ANULADO_RRHH|')) {
      return comentarioRRHH.replaceFirst('ANULADO_RRHH|', '');
    }
    return comentarioRRHH;
  }

  // ==========================================
  // 🆕 MÉTODOS DE ACCIÓN PARA GERENCIA Y RRHH
  // ==========================================

  /// Mostrar diálogo de código de descuento para gerencia
  void _mostrarDialogoCodigoDescuento(BuildContext context, bool aprobar) {
    showDialog(
      context: context,
      builder: (context) => CodigoDescuentoDialog(
        sancion: sancion,
        aprobar: aprobar,
        onConfirm: (codigoCompleto) async {
          await _confirmarAprobacionGerencia(context, aprobar, codigoCompleto);
        },
      ),
    );
  }

  /// Confirmar aprobación/rechazo por gerencia
  Future<void> _confirmarAprobacionGerencia(
    BuildContext context, 
    bool aprobar, 
    String codigoCompleto
  ) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser!;

      String nuevoStatus = aprobar ? 'aprobado' : 'rechazado';

      // Usar SancionService directamente para cambiar status
      final sancionService = SancionService();
      final success = await sancionService.changeStatus(
        sancion.id,
        nuevoStatus,
        comentarios: codigoCompleto, // Se guarda en comentarios_gerencia
        reviewedBy: user.id,
      );

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  aprobar ? Icons.check_circle : Icons.cancel,
                  color: Colors.white,
                ),
                const SizedBox(width: 8),
                Text(aprobar
                    ? '✅ Sanción aprobada con código'
                    : '❌ Sanción rechazada'),
              ],
            ),
            backgroundColor: aprobar ? Colors.green : Colors.red,
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
  }

  /// Procesar sanción por RRHH
  void _procesarRRHH(BuildContext context, String accion) {
    String titulo;
    String mensaje;
    Color color;
    IconData icon;

    switch (accion) {
      case 'confirmar':
        titulo = 'Confirmar Procesamiento';
        mensaje = '¿Confirmar el procesamiento de esta sanción?';
        color = Colors.blue;
        icon = Icons.verified;
        break;
      case 'modificar':
        titulo = 'Modificar Descuento';
        mensaje = 'Modificar el código de descuento aplicado por gerencia:';
        color = Colors.orange;
        icon = Icons.edit;
        break;
      case 'anular':
        titulo = 'Anular Sanción';
        mensaje = '¿Anular completamente esta sanción?';
        color = Colors.red;
        icon = Icons.block;
        break;
      default:
        return;
    }

    final comentariosController = TextEditingController();
    final nuevoCodigoController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Text(titulo),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(mensaje),
              const SizedBox(height: 16),
              
              // Mostrar código actual de gerencia
              if (sancion.comentariosGerencia != null) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Código actual de gerencia:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                      Text(
                        _extraerCodigo(sancion.comentariosGerencia!),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _extraerComentario(sancion.comentariosGerencia!),
                        style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Campo para nuevo código (solo si es modificar)
              if (accion == 'modificar') ...[
                TextField(
                  controller: nuevoCodigoController,
                  decoration: const InputDecoration(
                    labelText: 'Nuevo código (ej: D25%)',
                    border: OutlineInputBorder(),
                    hintText: 'D05%, D10%, D15%, D20%, SIN_DESC, etc.',
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Campo de comentarios
              TextField(
                controller: comentariosController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Comentarios RRHH ${accion == 'confirmar' ? '(opcional)' : '(obligatorio)'}',
                  border: const OutlineInputBorder(),
                  hintText: accion == 'confirmar' 
                    ? 'Comentarios opcionales del procesamiento...'
                    : 'Justifica la ${accion == 'modificar' ? 'modificación' : 'anulación'}...',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              if (accion != 'confirmar' && comentariosController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Los comentarios son obligatorios'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              if (accion == 'modificar' && nuevoCodigoController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Debe especificar el nuevo código'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              Navigator.pop(context);
              await _ejecutarProcesamientoRRHH(context, accion, comentariosController.text.trim(), nuevoCodigoController.text.trim());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
            ),
            icon: Icon(icon),
            label: Text(titulo),
          ),
        ],
      ),
    );
  }

  /// Ejecutar procesamiento de RRHH
  Future<void> _ejecutarProcesamientoRRHH(
    BuildContext context,
    String accion,
    String comentarios,
    String nuevoCodigo,
  ) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final user = authProvider.currentUser!;

      String statusFinal;
      String comentariosFinales;

      switch (accion) {
        case 'confirmar':
          statusFinal = 'aprobado'; // Mantiene aprobado pero con comentarios RRHH
          comentariosFinales = comentarios.isEmpty ? 'Procesado por RRHH' : comentarios;
          break;
        case 'modificar':
          statusFinal = 'aprobado';
          comentariosFinales = 'MODIFICADO|$nuevoCodigo|$comentarios';
          break;
        case 'anular':
          statusFinal = 'rechazado';
          comentariosFinales = 'ANULADO_RRHH|$comentarios';
          break;
        default:
          return;
      }

      // Usar el campo comentarios_rrhh para guardar el procesamiento
      final sancionService = SancionService();
      
      // Necesitamos un método que actualice comentarios_rrhh específicamente
      // Por ahora simularemos con una actualización directa
      final success = await sancionService.updateSancionRRHH(
        sancion.id,
        statusFinal,
        comentariosFinales,
        user.id,
      );

      if (success && context.mounted) {
        String mensaje;
        switch (accion) {
          case 'confirmar':
            mensaje = '✅ Sanción procesada correctamente';
            break;
          case 'modificar':
            mensaje = '📝 Descuento modificado correctamente';
            break;
          case 'anular':
            mensaje = '🚫 Sanción anulada por RRHH';
            break;
          default:
            mensaje = '✅ Procesamiento completado';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Text(mensaje),
              ],
            ),
            backgroundColor: Colors.green,
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
  }

  // ==========================================
  // 🔧 MÉTODOS ORIGINALES MANTENIDOS
  // ==========================================

  void _handleAction(BuildContext context, String action) async {
    final sancionService = SancionService();

    switch (action) {
      case 'edit':
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditSancionScreen(sancion: sancion),
          ),
        );

        if (result == true && onStatusChanged != null) {
          onStatusChanged!();

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
🏢 Puesto: ${sancion.puesto}
🧑‍💼 Agente: ${sancion.agente}
📊 Status: ${sancion.statusText}
${sancion.pendiente ? '⏳ Estado: PENDIENTE' : '✅ Estado: RESUELTO'}

${sancion.observaciones != null ? '📝 Observaciones: ${sancion.observaciones}\n' : ''}${sancion.observacionesAdicionales != null ? '📝 Obs. Adicionales: ${sancion.observacionesAdicionales}\n' : ''}${sancion.horasExtras != null ? '⏱️ Horas extras: ${sancion.horasExtras}\n' : ''}
🔗 ID: ${sancion.id}
📅 Creada: ${sancion.createdAt.day}/${sancion.createdAt.month}/${sancion.createdAt.year}

--- Sistema de Sanciones INSEVIG ---
    '''
        .trim();

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