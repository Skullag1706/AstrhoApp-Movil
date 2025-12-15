import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/agenda.dart';

import 'package:astrhoapp/core/services/api_service.dart';
import 'package:astrhoapp/core/utils/colors.dart';
import 'package:astrhoapp/shared/widgets/app_header.dart';

class AgendaDetailScreen extends StatefulWidget {
  final Agenda agenda;
  final String? token;
  final Map<dynamic, dynamic>? user;

  const AgendaDetailScreen({
    super.key,
    required this.agenda,
    this.token,
    this.user,
  });

  @override
  State<AgendaDetailScreen> createState() => _AgendaDetailScreenState();
}

class _AgendaDetailScreenState extends State<AgendaDetailScreen> {
  late ApiService _apiService;
  List<Servicio> _serviciosCatalog = [];
  List<Cliente> _clientesCatalog = [];
  List<Empleado> _empleadosCatalog = [];
  Cliente? _currentUserClient;
  bool _isLoadingPrices = true;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(token: widget.token);
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // Cargar servicios
    try {
      final servicios = await _apiService.getServicios();
      if (mounted) {
        setState(() {
          _serviciosCatalog = servicios;
        });
      }
    } catch (e) {
      print('Error al cargar servicios: $e');
    }

    // Cargar clientes (puede fallar por permisos)
    try {
      final clientes = await _apiService.getClientes();
      if (mounted) {
        setState(() {
          _clientesCatalog = clientes;
        });
      }
    } catch (e) {
      print('Error al cargar clientes (posible restricción de permisos): $e');
    }

    // Cargar empleados
    try {
      final empleados = await _apiService.getEmpleados();
      if (mounted) {
        setState(() {
          _empleadosCatalog = empleados;
        });
      }
    } catch (e) {
      print('Error al cargar empleados: $e');
    }

    if (mounted) {
      // Cargar nombre del cliente si no viene en el usuario logueado
      // Cargar nombre del cliente si no viene en el usuario logueado
      if (widget.user != null &&
          widget.user!['rol']?.toString().toLowerCase() == 'cliente') {
        try {
          // Si tenemos usuarioId, intentamos buscar el cliente completo
          if (widget.user!['usuarioId'] != null) {
            final userId = widget.user!['usuarioId'];
            final cliente = await _apiService.getClientePorUsuarioId(userId);
            if (cliente != null && mounted) {
              setState(() {
                _currentUserClient = cliente;
                // También lo agregamos al catálogo por si acaso
                if (!_clientesCatalog.any(
                  (c) => c.documentoCliente == cliente.documentoCliente,
                )) {
                  _clientesCatalog.add(cliente);
                }
              });
            }
          }
        } catch (e) {
          print("Error cargando nombre de cliente fallback: $e");
        }
      }

      if (mounted) {
        setState(() {
          _isLoadingPrices = false;
        });
      }
    }
  }

  String _formatCurrency(double amount) {
    final currencyFormatter = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );
    return currencyFormatter.format(amount);
  }

  String _getClientName(String documento) {
    // Escenario Cliente Logueado
    if (widget.user != null &&
        widget.user!['rol']?.toString().toLowerCase() == 'cliente') {
      // 1. Si el documento coincide O es vacío (caso de bug en API), asumimos que es el usuario
      if (widget.agenda.documentoCliente == documento || documento.isEmpty) {
        // A. Nombre explícito en agenda
        if (widget.agenda.nombreCliente != null &&
            widget.agenda.nombreCliente!.isNotEmpty) {
          return widget.agenda.nombreCliente!;
        }

        // B. Cliente recuperado por ID de usuario (Fallback fuerte)
        if (_currentUserClient != null) {
          return _currentUserClient!.nombre;
        }

        // C. Catálogo (Poco probable si permisos restringidos)
        try {
          if (documento.isNotEmpty) {
            final cliente = _clientesCatalog.firstWhere(
              (c) => c.documentoCliente == documento,
            );
            return cliente.nombre;
          }
        } catch (_) {}

        // D. Nombre en token/login
        if (widget.user!['nombre'] != null &&
            widget.user!['nombre'].toString().isNotEmpty) {
          return widget.user!['nombre'];
        }
      }
    }

    // Escenario General
    if (_clientesCatalog.isEmpty) {
      if (widget.agenda.nombreCliente != null &&
          widget.agenda.nombreCliente!.isNotEmpty) {
        return widget.agenda.nombreCliente!;
      }
      return documento;
    }

    try {
      final cliente = _clientesCatalog.firstWhere(
        (c) => c.documentoCliente == documento,
      );
      return cliente.nombre;
    } catch (e) {
      if (widget.agenda.nombreCliente != null &&
          widget.agenda.nombreCliente!.isNotEmpty) {
        return widget.agenda.nombreCliente!;
      }
      return documento;
    }
  }

  String _getPaymentMethodName() {
    // Simplemente mostrar el nombreMetodoPago que viene en el objeto agenda
    // Si está vacío o es null, mostrar "No especificado"
    final nombre = widget.agenda.nombreMetodoPago;

    if (nombre != null && nombre.isNotEmpty && nombre != 'No especificado') {
      return nombre;
    }

    return 'No especificado';
  }

  String _getEmployeeName(String documento) {
    if (_empleadosCatalog.isEmpty) return documento;
    try {
      final empleado = _empleadosCatalog.firstWhere(
        (e) => e.documentoEmpleado == documento,
      );
      return empleado.nombre;
    } catch (e) {
      return documento;
    }
  }

  double _getRealPrice(Servicio servicioAgenda) {
    // Si el servicio ya trae precio > 0, usarlo
    if (servicioAgenda.precio > 0) return servicioAgenda.precio;

    // Si no, buscar en el catálogo por ID
    if (_serviciosCatalog.isNotEmpty) {
      try {
        final servicioFull = _serviciosCatalog.firstWhere(
          (s) => s.servicioId == servicioAgenda.servicioId,
        );
        return servicioFull.precio;
      } catch (e) {
        // No encontrado por ID, intentar por nombre
        try {
          final servicioFull = _serviciosCatalog.firstWhere(
            (s) =>
                s.nombre.toLowerCase().trim() ==
                servicioAgenda.nombre.toLowerCase().trim(),
          );
          return servicioFull.precio;
        } catch (e) {
          return 0;
        }
      }
    }
    return 0;
  }

  double get _totalCosto {
    if (widget.agenda.servicios == null) return 0;
    return widget.agenda.servicios!.fold(
      0.0,
      (sum, s) => sum + _getRealPrice(s),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.primaryGradient),
        child: SafeArea(
          child: Column(
            children: [
              AppHeader(
                title: 'Detalle de Cita',
                onBackPressed: () => Navigator.pop(context),
              ),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 20),
                  decoration: const BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // Tarjeta de información principal
                      Container(
                        padding: const EdgeInsets.all(20),
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryPurple.withOpacity(
                                      0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.calendar_today,
                                    color: AppColors.primaryPurple,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.agenda.servicios != null &&
                                                widget
                                                    .agenda
                                                    .servicios!
                                                    .isNotEmpty
                                            ? widget
                                                  .agenda
                                                  .servicios!
                                                  .first
                                                  .nombre
                                            : 'Consulta general',
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.textDark,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              widget.agenda.nombreEstado
                                                      ?.toLowerCase()
                                                      .contains('confirmado') ==
                                                  true
                                              ? AppColors.confirmedBlue
                                              : AppColors.pendingOrange,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                        ),
                                        child: Text(
                                          widget.agenda.nombreEstado ??
                                              'Sin estado',
                                          style: const TextStyle(
                                            color: AppColors.white,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 32),
                            _buildDetailRow(
                              icon: Icons.calendar_today,
                              label: 'Fecha',
                              value: DateFormat(
                                'yyyy-MM-dd',
                              ).format(widget.agenda.fechaCita),
                            ),
                            const SizedBox(height: 16),
                            _buildDetailRow(
                              icon: Icons.access_time,
                              label: 'Hora',
                              value: widget.agenda.horaInicio,
                            ),
                            const SizedBox(height: 16),
                            _buildDetailRow(
                              icon: Icons.person,
                              label: 'Cliente',
                              value: _getClientName(
                                widget.agenda.documentoCliente,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildDetailRow(
                              icon: Icons.badge,
                              label: 'Empleado',
                              value: _getEmployeeName(
                                widget.agenda.documentoEmpleado,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildDetailRow(
                              icon: Icons.payment,
                              label: 'Método de Pago',
                              value: _getPaymentMethodName(),
                            ),
                            if (widget.agenda.observaciones != null &&
                                widget.agenda.observaciones!.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              _buildDetailRow(
                                icon: Icons.note,
                                label: 'Observaciones',
                                value: widget.agenda.observaciones!,
                              ),
                            ],
                            if (widget.agenda.servicios != null &&
                                widget.agenda.servicios!.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              const Text(
                                'Servicios:',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(height: 12),
                              ...widget.agenda.servicios!.map(
                                (servicio) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle,
                                        color: AppColors.primaryPurple,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${servicio.nombre} - ${_formatCurrency(_getRealPrice(servicio))}',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: AppColors.textDark,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const Divider(height: 24),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total:',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  _isLoadingPrices
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : Text(
                                          _formatCurrency(_totalCosto),
                                          style: const TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primaryPurple,
                                          ),
                                        ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primaryPurple, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textGray,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textDark,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
