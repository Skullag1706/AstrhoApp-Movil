import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:astrhoapp/agenda/models/agenda.dart';
import 'package:astrhoapp/core/utils/colors.dart';

class AppointmentCard extends StatelessWidget {
  final Agenda agenda;
  final VoidCallback? onView;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const AppointmentCard({
    super.key,
    required this.agenda,
    this.onView,
    this.onEdit,
    this.onDelete,
  });

  Color getStatusColor() {
    final estado = agenda.nombreEstado?.toLowerCase() ?? '';
    if (estado.contains('confirmado') || estado.contains('confirmada')) {
      return AppColors.confirmedBlue;
    } else if (estado.contains('pendiente')) {
      return AppColors.pendingOrange;
    } else if (estado.contains('cancelado') || estado.contains('cancelada')) {
      return Colors.red;
    } else if (estado.contains('completado') || estado.contains('completada')) {
      return Colors.green;
    }
    return AppColors.textGray;
  }

  Color getStatusBackgroundColor() {
    final estado = agenda.nombreEstado?.toLowerCase() ?? '';
    if (estado.contains('confirmado') || estado.contains('confirmada')) {
      return AppColors.confirmedBlue;
    } else if (estado.contains('pendiente')) {
      return AppColors.pendingOrange;
    } else if (estado.contains('cancelado') || estado.contains('cancelada')) {
      return Colors.red;
    } else if (estado.contains('completado') || estado.contains('completada')) {
      return Colors.green;
    }
    return AppColors.textGray;
  }

  IconData getStatusIcon() {
    final estado = agenda.nombreEstado?.toLowerCase() ?? '';
    if (estado.contains('confirmado') || estado.contains('confirmada')) {
      return Icons.check_circle;
    } else if (estado.contains('pendiente')) {
      return Icons.pending;
    } else if (estado.contains('cancelado') || estado.contains('cancelada')) {
      return Icons.cancel;
    } else if (estado.contains('completado') || estado.contains('completada')) {
      return Icons.check_circle_outline;
    }
    return Icons.calendar_today;
  }

  String getServiceName() {
    if (agenda.servicios != null && agenda.servicios!.isNotEmpty) {
      return agenda.servicios!.first.nombre;
    }
    return 'Consulta general';
  }

  @override
  Widget build(BuildContext context) {
    final statusBgColor = getStatusBackgroundColor();
    final statusIcon = getStatusIcon();
    final serviceName = getServiceName();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icono de estado
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: statusBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(statusIcon, color: AppColors.white, size: 24),
            ),
            const SizedBox(width: 16),
            // Información de la cita
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          serviceName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusBgColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          agenda.nombreEstado ?? 'Sin estado',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: AppColors.primaryPurple,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('yyyy-MM-dd').format(agenda.fechaCita),
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 16,
                        color: AppColors.primaryPurple,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        agenda.horaInicio,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (agenda.nombreEmpleado != null &&
                      agenda.nombreEmpleado!.isNotEmpty)
                    Row(
                      children: [
                        const Icon(
                          Icons.badge_outlined,
                          size: 16,
                          color: AppColors.primaryPurple,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Empleado: ${agenda.nombreEmpleado}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  if (agenda.nombreCliente != null &&
                      agenda.nombreCliente!.isNotEmpty)
                    Row(
                      children: [
                        const Icon(
                          Icons.person_outline,
                          size: 16,
                          color: AppColors.primaryPurple,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Cliente: ${agenda.nombreCliente}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            // Botón de menú
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: AppColors.primaryPurple),
              onSelected: (value) {
                switch (value) {
                  case 'view':
                    onView?.call();
                    break;
                  case 'edit':
                    onEdit?.call();
                    break;
                  case 'delete':
                    onDelete?.call();
                    break;
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                if (onView != null)
                  const PopupMenuItem<String>(
                    value: 'view',
                    child: Row(
                      children: [
                        Icon(Icons.visibility, color: AppColors.primaryPurple),
                        SizedBox(width: 8),
                        Text('Ver detalle'),
                      ],
                    ),
                  ),
                if (onEdit != null)
                  const PopupMenuItem<String>(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, color: AppColors.primaryPurple),
                        SizedBox(width: 8),
                        Text('Editar'),
                      ],
                    ),
                  ),
                if (onDelete != null)
                  const PopupMenuItem<String>(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: AppColors.pendingOrange),
                        SizedBox(width: 8),
                        Text('Eliminar'),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
