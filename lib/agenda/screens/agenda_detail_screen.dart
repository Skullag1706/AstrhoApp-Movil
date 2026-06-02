import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/agenda.dart';
import 'appointment_flow_screen.dart';

import 'package:astrhoapp/core/services/api_service.dart';
import 'package:astrhoapp/core/utils/colors.dart';

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
  bool _isLoading = false;
  late Agenda _currentAgenda;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(token: widget.token);
    _currentAgenda = widget.agenda;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // Cargar servicios
    try {
      final servicios = await _apiService.getServiciosLegacy();
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
      if (_currentAgenda.documentoCliente == documento || documento.isEmpty) {
        // A. Nombre explícito en agenda
        if (_currentAgenda.nombreCliente != null &&
            _currentAgenda.nombreCliente!.isNotEmpty) {
          return _currentAgenda.nombreCliente!;
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
      if (_currentAgenda.nombreCliente != null &&
          _currentAgenda.nombreCliente!.isNotEmpty) {
        return _currentAgenda.nombreCliente!;
      }
      return documento;
    }

    try {
      final cliente = _clientesCatalog.firstWhere(
        (c) => c.documentoCliente == documento,
      );
      return cliente.nombre;
    } catch (e) {
      if (_currentAgenda.nombreCliente != null &&
          _currentAgenda.nombreCliente!.isNotEmpty) {
        return _currentAgenda.nombreCliente!;
      }
      return documento;
    }
  }

  String _getPaymentMethodName() {
    final nombre = _currentAgenda.nombreMetodoPago;

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
    if (servicioAgenda.precio > 0) return servicioAgenda.precio;

    if (_serviciosCatalog.isNotEmpty) {
      try {
        final servicioFull = _serviciosCatalog.firstWhere(
          (s) => s.servicioId == servicioAgenda.servicioId,
        );
        return servicioFull.precio;
      } catch (e) {
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
    if (_currentAgenda.servicios == null) return 0;
    return _currentAgenda.servicios!.fold(
      0.0,
      (sum, s) => sum + _getRealPrice(s),
    );
  }

  // Métodos para cambiar el estado
  Future<void> _confirmarCita() async {
    if (_currentAgenda.agendaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se puede identificar la cita')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    try {
      final agendaActualizada = await _apiService.confirmarCita(_currentAgenda.agendaId!);
      if (mounted) {
        setState(() {
          _currentAgenda = agendaActualizada;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cita confirmada exitosamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _completarCita() async {
    if (_currentAgenda.agendaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se puede identificar la cita')),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    try {
      final agendaActualizada = await _apiService.completarCita(_currentAgenda.agendaId!);
      if (mounted) {
        setState(() {
          _currentAgenda = agendaActualizada;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cita completada exitosamente')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _cancelarCita() async {
    if (_currentAgenda.agendaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se puede identificar la cita')),
      );
      return;
    }
    
    final confirmacion = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar Cita'),
        content: const Text('¿Estás seguro de que quieres cancelar esta cita?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí'),
          ),
        ],
      ),
    );

    if (confirmacion == true) {
      setState(() {
        _isLoading = true;
      });
      try {
        final agendaActualizada = await _apiService.cancelarCita(_currentAgenda.agendaId!);
        if (mounted) {
          setState(() {
            _currentAgenda = agendaActualizada;
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cita cancelada exitosamente')),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  // Método para reprogramar cita
  void _reprogramarCita() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppointmentFlowScreen(
          token: widget.token,
          user: widget.user,
          agendaToEdit: _currentAgenda,
        ),
      ),
    ).then((result) {
      if (result != null && result is Agenda) {
        setState(() {
          _currentAgenda = result;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cita reprogramada exitosamente')),
        );
      }
    });
  }

  // Verificar rol
  bool get _isCliente => widget.user != null && widget.user!['rol']?.toString().toLowerCase() == 'cliente';

  // Verificar estados
  bool get _estaPendiente => _currentAgenda.nombreEstado?.toLowerCase().contains('pendiente') == true;
  bool get _estaConfirmado => _currentAgenda.nombreEstado?.toLowerCase().contains('confirmado') == true;
  bool get _estaCompletado => _currentAgenda.nombreEstado?.toLowerCase().contains('completado') == true;
  bool get _estaCancelado => _currentAgenda.nombreEstado?.toLowerCase().contains('cancelado') == true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBackground,
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
              ),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // Estado badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _estaConfirmado
                          ? AppColors.statusConfirmed
                          : _estaCompletado
                              ? AppColors.statusCompleted
                              : _estaCancelado
                                  ? AppColors.statusCancelled
                                  : AppColors.statusPending,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _currentAgenda.nombreEstado ?? 'Sin estado',
                      style: const TextStyle(
                        color: AppColors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Información principal
                  Text(
                    _currentAgenda.servicios != null && _currentAgenda.servicios!.isNotEmpty
                        ? _currentAgenda.servicios!.first.nombre
                        : 'Consulta general',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  // Tarjeta de fecha y hora
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.lightPurpleBackground,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primaryPurple,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.calendar_today,
                            color: AppColors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('EEEE, d \'de\' MMMM', 'es_ES').format(_currentAgenda.fechaCita),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textGray,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _currentAgenda.horaInicio,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryPurple,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Detalles
                  _buildDetailCard(
                    icon: Icons.person,
                    label: 'Cliente',
                    value: _getClientName(_currentAgenda.documentoCliente),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailCard(
                    icon: Icons.badge,
                    label: 'Empleado',
                    value: _getEmployeeName(_currentAgenda.documentoEmpleado),
                  ),
                  const SizedBox(height: 12),
                  _buildDetailCard(
                    icon: Icons.payment,
                    label: 'Método de Pago',
                    value: _getPaymentMethodName(),
                  ),
                  
                  if (_currentAgenda.observaciones != null && _currentAgenda.observaciones!.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildDetailCard(
                      icon: Icons.note,
                      label: 'Observaciones',
                      value: _currentAgenda.observaciones!,
                    ),
                  ],
                  
                  // Servicios
                  if (_currentAgenda.servicios != null && _currentAgenda.servicios!.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    const Text(
                      'Servicios',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._currentAgenda.servicios!.map((servicio) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.scaffoldBackground,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  servicio.nombre,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textDark,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Text(
                                _formatCurrency(_getRealPrice(servicio)),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryPurple,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.lightPurpleBackground,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textDark,
                            ),
                          ),
                          _isLoadingPrices
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
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
                    ),
                  ],
                  
                  const SizedBox(height: 24),
                  
                  // Botones de acción
                  if (!_estaCancelado && !_estaCompletado) ...[
                    if (!_isCliente && _estaPendiente) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.statusConfirmed,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: _isLoading ? null : _confirmarCita,
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'Confirmar Cita',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if ((_estaPendiente || _estaConfirmado) && !_isCliente) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.statusCompleted,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: _isLoading ? null : _completarCita,
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : const Text(
                                  'Completar Cita',
                                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_estaPendiente) ...[
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.primaryPurple),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: _isLoading ? null : _reprogramarCita,
                          child: _isLoading
                              ? const CircularProgressIndicator()
                              : const Text(
                                  'Reprogramar Cita',
                                  style: TextStyle(
                                    color: AppColors.primaryPurple,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.statusCancelled),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: _isLoading ? null : _cancelarCita,
                        child: _isLoading
                            ? const CircularProgressIndicator(color: AppColors.statusCancelled)
                            : const Text(
                                'Cancelar Cita',
                                style: TextStyle(
                                  color: AppColors.statusCancelled,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(gradient: AppColors.primaryGradient),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.white),
              onPressed: () => Navigator.pop(context, _currentAgenda),
            ),
            const Text(
              'Detalle de Cita',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.scaffoldBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.lightPurpleBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primaryPurple, size: 20),
          ),
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
                    fontSize: 14,
                    color: AppColors.textDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
