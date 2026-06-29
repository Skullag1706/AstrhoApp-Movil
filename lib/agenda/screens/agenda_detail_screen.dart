import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/agenda.dart';
import 'appointment_flow_screen.dart';

import 'package:astrhoapp/core/services/api_service.dart';
import 'package:astrhoapp/core/utils/colors.dart';
import 'package:astrhoapp/core/widgets/custom_alert.dart';

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
  bool _showingSuccessDialog = false;
  late Agenda _currentAgenda;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(token: widget.token);
    _currentAgenda = widget.agenda;
    _loadAgendaAndInitialData();
  }

  Future<void> _loadAgendaAndInitialData() async {
    // Primero recargar la cita desde el servidor para asegurar que está actualizada
    if (_currentAgenda.agendaId != null) {
      try {
        print('📥 Recargando datos de la cita desde el servidor...');
        final updatedAgenda = await _apiService.getAgendaById(_currentAgenda.agendaId!);
        if (mounted) {
          setState(() {
            _currentAgenda = updatedAgenda;
          });
        }
      } catch (e) {
        print('⚠️ Error al recargar cita: $e');
      }
    }
    
    // Luego cargar el resto de datos
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

  // Parsear una hora en formato String (ej: "14:30:00") a DateTime
  DateTime _parseTime(String timeString) {
    try {
      final parts = timeString.split(':');
      final hour = int.parse(parts[0]);
      final minute = parts.length > 1 ? int.parse(parts[1]) : 0;
      return DateTime(2000, 1, 1, hour, minute);
    } catch (e) {
      print('Error parseando hora "$timeString": $e');
      return DateTime(2000, 1, 1, 0, 0);
    }
  }

  // Formatear DateTime para mostrar al usuario
  String _formatDateTimeForDisplay(DateTime dateTime) {
    final formatter = DateFormat('dd/MM/yyyy HH:mm', 'es_CO');
    return formatter.format(dateTime);
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
    print('========================================');
    print('👤 USUARIO PRESIONA CONFIRMAR CITA');
    print('========================================');
    print('agendaId: ${_currentAgenda.agendaId}');
    print('nombreEstado actual: ${_currentAgenda.nombreEstado}');
    
    if (_currentAgenda.agendaId == null) {
      print('❌ agendaId es null');
      CustomAlert.showError(context, 'No se puede identificar la cita');
      return;
    }
    
    print('✅ agendaId válido: ${_currentAgenda.agendaId}');
    
    // Mostrar diálogo de confirmación personalizado
    final confirmacion = await CustomAlert.showConfirmDialog(
      context,
      title: 'Confirmar Cita',
      message: '¿Deseas confirmar esta cita? Una vez confirmada, será visible para el cliente.',
      confirmText: 'Sí, Confirmar',
      cancelText: 'Cancelar',
      isDangerous: false,
    );

    if (confirmacion != true) {
      print('❌ Usuario canceló la confirmación');
      return;
    }

    print('⚠️ Usuario confirmó - Ejecutando confirmarCita()...');
    
    setState(() {
      _isLoading = true;
    });
    try {
      print('📞 Llamando a _apiService.confirmarCita()...');
      final agendaActualizada = await _apiService.confirmarCita(_currentAgenda.agendaId!);
      print('✅ Respuesta recibida: ${agendaActualizada.nombreEstado}');
      if (mounted) {
        setState(() {
          _currentAgenda = agendaActualizada;
          _isLoading = false;
        });
        
        // Mostrar pantalla de éxito
        _showStatusChangeSuccessScreen('Confirmado', 'Cita confirmada exitosamente');
      }
    } catch (e) {
      print('❌ Error en _confirmarCita: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        CustomAlert.showError(context, 'Error al confirmar: $e');
      }
    }
    print('========================================');
  }

  Future<void> _completarCita() async {
    print('========================================');
    print('👤 USUARIO PRESIONA COMPLETAR CITA');
    print('========================================');
    print('agendaId: ${_currentAgenda.agendaId}');
    print('nombreEstado actual: ${_currentAgenda.nombreEstado}');
    
    if (_currentAgenda.agendaId == null) {
      print('❌ agendaId es null');
      CustomAlert.showError(context, 'No se puede identificar la cita');
      return;
    }

    print('✅ agendaId válido: ${_currentAgenda.agendaId}');
    
    // Verificar si la cita aún no ha pasado
    final fechaHoraActual = DateTime.now();
    final fechaCita = _currentAgenda.fechaCita;
    final horaCita = _parseTime(_currentAgenda.horaInicio);
    
    final fechaHoraCita = DateTime(
      fechaCita.year,
      fechaCita.month,
      fechaCita.day,
      horaCita.hour,
      horaCita.minute,
    );
    
    print('Fecha/Hora actual: $fechaHoraActual');
    print('Fecha/Hora cita: $fechaHoraCita');
    print('¿La cita ya pasó? ${fechaHoraActual.isAfter(fechaHoraCita)}');
    
    if (fechaHoraActual.isBefore(fechaHoraCita)) {
      print('❌ Cita aún no ha pasado, no se puede completar');
      CustomAlert.showError(
        context, 
        'No se puede completar una cita que aún no ha comenzado.\n\nFecha y hora de la cita: ${_formatDateTimeForDisplay(fechaHoraCita)}',
      );
      return;
    }
    
    print('✅ La cita ya ha pasado, se puede completar');
    
    // Mostrar diálogo de confirmación personalizado
    final confirmacion = await CustomAlert.showConfirmDialog(
      context,
      title: 'Completar Cita',
      message: '¿Deseas marcar esta cita como completada?',
      confirmText: 'Sí, Completar',
      cancelText: 'Cancelar',
      isDangerous: false,
    );

    if (confirmacion != true) {
      print('❌ Usuario canceló la completación');
      return;
    }

    print('⚠️ Usuario confirmó - Ejecutando completarCita()...');
    
    setState(() {
      _isLoading = true;
    });
    try {
      print('📞 Llamando a _apiService.completarCita()...');
      final agendaActualizada = await _apiService.completarCita(_currentAgenda.agendaId!);
      print('✅ Respuesta recibida: ${agendaActualizada.nombreEstado}');
      if (mounted) {
        setState(() {
          _currentAgenda = agendaActualizada;
          _isLoading = false;
        });
        
        // Mostrar pantalla de éxito
        _showStatusChangeSuccessScreen('Completado', 'Cita completada exitosamente');
      }
    } catch (e) {
      print('❌ Error en _completarCita: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        CustomAlert.showError(context, 'Error al completar: $e');
      }
    }
    print('========================================');
  }

  Future<void> _cancelarCita() async {
    print('========================================');
    print('👤 USUARIO PRESIONA CANCELAR CITA');
    print('========================================');
    print('agendaId: ${_currentAgenda.agendaId}');
    
    if (_currentAgenda.agendaId == null) {
      print('❌ agendaId es null');
      CustomAlert.showError(context, 'No se puede identificar la cita');
      return;
    }
    
    print('✅ agendaId válido: ${_currentAgenda.agendaId}');
    
    // Mostrar diálogo de confirmación personalizado (marcado como peligroso)
    final confirmacion = await CustomAlert.showConfirmDialog(
      context,
      title: 'Cancelar Cita',
      message: '¿Estás seguro de que deseas cancelar esta cita? Esta acción no se puede deshacer.',
      confirmText: 'Sí, Cancelar Cita',
      cancelText: 'No, Mantener',
      isDangerous: true,
    );

    if (confirmacion != true) {
      print('❌ Usuario canceló la cancelación');
      return;
    }

    print('⚠️ Usuario confirmó - Ejecutando cancelarCita()...');
    
    setState(() {
      _isLoading = true;
    });
    try {
      print('📞 Llamando a _apiService.cancelarCita()...');
      final agendaActualizada = await _apiService.cancelarCita(_currentAgenda.agendaId!);
      print('✅ Respuesta recibida: ${agendaActualizada.nombreEstado}');
      
      if (mounted) {
        setState(() {
          _currentAgenda = agendaActualizada;
          _isLoading = false;
        });
        
        // Mostrar pantalla de éxito
        _showStatusChangeSuccessScreen('Cancelado', 'Cita cancelada exitosamente');
      }
    } catch (e) {
      print('❌ Error en _cancelarCita: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        CustomAlert.showError(context, 'Error al cancelar: $e');
      }
    }
    print('========================================');
  }
  
  // Mostrar pantalla de éxito al cambiar estado
  void _showStatusChangeSuccessScreen(String nuevoEstado, String mensaje) {
    setState(() {
      _showingSuccessDialog = true;
    });
    
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.3), // Fondo semi-transparente
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icono de éxito
                Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAD8FF),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Icon(
                        Icons.check_circle_outline,
                        size: 70,
                        color: Color(0xFF7926F7),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF7926F7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check, color: Colors.white, size: 24),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                
                // Título
                Text(
                  "¡$nuevoEstado!",
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 12),
                
                // Mensaje
                Text(
                  mensaje,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 32),
                
                // Botón cerrar
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7926F7),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () {
                      setState(() {
                        _showingSuccessDialog = false;
                      });
                      Navigator.pop(context); // Cerrar diálogo
                      Navigator.pop(context, _currentAgenda); // Volver a mis citas con agenda actualizada
                    },
                    child: const Text(
                      'Entendido',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).then((_) {
      // Asegurar que la bandera se resetea cuando el diálogo se cierra
      if (mounted) {
        setState(() {
          _showingSuccessDialog = false;
        });
      }
    });
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
      // Cuando regresa de AppointmentFlowScreen
      if (result == 'refresh') {
        print('📋 Reprogramación completada, cerrando para recargar...');
        // Retornar 'refresh_and_close' para indicar que debe recargar y cerrar
        Navigator.pop(context, 'refresh_and_close');
      }
    });
  }

  // Verificar rol
  bool get _isCliente => widget.user != null && widget.user!['rol']?.toString().toLowerCase() == 'cliente';
  bool get _isAsistente => widget.user != null && (widget.user!['rol']?.toString().toLowerCase() == 'asistente' || widget.user!['rol']?.toString().toLowerCase() == 'empleado');

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
                  
                  // Botones de acción (ocultos mientras se muestra el diálogo de éxito)
                  if (!_showingSuccessDialog && !_estaCancelado && !_estaCompletado) ...[
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
                    if (_estaConfirmado && !_isCliente && !_isAsistente) ...[
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
                    if (!_isAsistente) ...[
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
