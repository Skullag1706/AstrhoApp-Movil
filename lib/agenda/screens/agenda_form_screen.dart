import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/agenda.dart';
import 'package:astrhoapp/core/services/api_service.dart';
import 'package:astrhoapp/core/utils/colors.dart';
import 'package:astrhoapp/shared/widgets/app_header.dart';

class AgendaFormScreen extends StatefulWidget {
  final Agenda? agenda;
  final String? token;
  final Map<dynamic, dynamic>? user;

  const AgendaFormScreen({super.key, this.agenda, this.token, this.user});

  @override
  State<AgendaFormScreen> createState() => _AgendaFormScreenState();
}

class _AgendaFormScreenState extends State<AgendaFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late ApiService _apiService;

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  String? _selectedCliente;
  String? _selectedEmpleado;
  int? _selectedMetodoPago;
  int? _selectedEstado;
  String? _observaciones;

  List<Cliente> _clientes = [];
  List<Empleado> _empleados = [];
  List<MetodoPago> _metodosPago = [];
  List<Estado> _estados = [];
  List<Servicio> _serviciosDisponibles = [];
  Set<int> _serviciosSeleccionados = {};
  bool _isLoading = false;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(token: widget.token);
    if (widget.agenda != null) {
      _selectedDate = widget.agenda!.fechaCita;
      _selectedTime = TimeOfDay(
        hour: int.parse(widget.agenda!.horaInicio.split(':')[0]),
        minute: int.parse(widget.agenda!.horaInicio.split(':')[1]),
      );
      _selectedCliente = widget.agenda!.documentoCliente;
      _selectedEmpleado = widget.agenda!.documentoEmpleado;
      // No establecer estado y metodoPago aquí, se establecerán después de cargar los datos
      _observaciones = widget.agenda!.observaciones;
      // Pre-seleccionar servicios del modelo si edita
      if (widget.agenda!.servicios != null &&
          widget.agenda!.servicios!.isNotEmpty) {
        _serviciosSeleccionados = widget.agenda!.servicios!
            .where((s) => s.servicioId > 0)
            .map((s) => s.servicioId)
            .toSet();
        print(
          'Servicios pre-seleccionados al editar: $_serviciosSeleccionados',
        );
      }
    } else {
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
    }
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // Cargar cada lista de forma independiente
    try {
      _clientes = await _apiService.getClientes();
      print('Clientes cargados: ${_clientes.length}');
    } catch (e) {
      print('Error al cargar clientes: $e');
      _clientes = [];
    }

    // Lógica para rol Cliente
    if (widget.user != null &&
        widget.user!["rol"]?.toString().toLowerCase() == "cliente" &&
        widget.user!["usuarioId"] != null) {
      final userId = widget.user!["usuarioId"];
      // Buscar si el cliente ya está en la lista (si se cargó)
      try {
        final clienteEncontrado = _clientes.firstWhere(
          (c) => c.usuarioId == userId,
          orElse: () => Cliente(documentoCliente: '', nombre: ''),
        );

        if (clienteEncontrado.documentoCliente.isNotEmpty) {
          _selectedCliente = clienteEncontrado.documentoCliente;
          _clientes = [clienteEncontrado];
        } else {
          // Si no está en la lista, intentar cargarlo individualmente
          try {
            if (_clientes.isEmpty) {
              final miCliente = await _apiService.getClientePorUsuarioId(
                userId,
              );
              if (miCliente != null) {
                setState(() {
                  _clientes = [miCliente];
                  _selectedCliente = miCliente.documentoCliente;
                });
                print("Cliente cargado individualmente: ${miCliente.nombre}");
              } else {
                print(
                  "Advertencia: No se pudo cargar datos del cliente actual.",
                );
              }
            }
          } catch (e) {
            print("Error intentando cargar cliente fallback: $e");
          }
        }
      } catch (e) {
        print("Error buscando cliente actual: $e");
      }
    }

    try {
      _empleados = await _apiService.getEmpleados();
      print('Empleados cargados: ${_empleados.length}');

      // Lógica para rol Empleado
      if (_isEmployeeUser && widget.user!["usuarioId"] != null) {
        final userId = widget.user!["usuarioId"];
        final empleadoEncontrado = _empleados.firstWhere(
          (e) => e.usuarioId == userId,
          orElse: () => Empleado(documentoEmpleado: '', nombre: ''),
        );

        if (empleadoEncontrado.documentoEmpleado.isNotEmpty) {
          _selectedEmpleado = empleadoEncontrado.documentoEmpleado;
          // Opcionalmente limitamos la lista al propio empleado
          _empleados = [empleadoEncontrado];
          print("Empleado auto-asignado: ${empleadoEncontrado.nombre}");
        } else {
          // Intentar carga individual si no estaba en la lista
          try {
            final miEmpleado = await _apiService.getEmpleadoPorUsuarioId(userId);
            if (miEmpleado != null) {
              setState(() {
                _empleados = [miEmpleado];
                _selectedEmpleado = miEmpleado.documentoEmpleado;
              });
              print("Empleado cargado individualmente: ${miEmpleado.nombre}");
            }
          } catch (e) {
            print("Error cargando empleado individual: $e");
          }
        }
      }
    } catch (e) {
      print('Error al cargar empleados: $e');
      _empleados = [];
    }

    try {
      _metodosPago = await _apiService.getMetodosPago();
    } catch (e) {
      print('Error al cargar métodos de pago: $e');
      _metodosPago = [];
    }

    try {
      _estados = await _apiService.getEstados();
    } catch (e) {
      print('Error al cargar estados: $e');
      _estados = [];
    }

    try {
      _serviciosDisponibles = await _apiService.getServicios();
      print(
        'Servicios cargados en formulario: ${_serviciosDisponibles.length}',
      );
      if (_serviciosDisponibles.isEmpty) {
        print('ADVERTENCIA: No se cargaron servicios desde la API');
      }
    } catch (e) {
      print('Error al cargar servicios: $e');
      _serviciosDisponibles = [];
    }

    // Asegurar que métodos de pago tenga al menos valores por defecto
    if (_metodosPago.isEmpty) {
      _metodosPago = [
        MetodoPago(metodopagoId: 1, nombre: 'Efectivo'),
        MetodoPago(metodopagoId: 2, nombre: 'Transferencia'),
      ];
    }

    // Si estamos editando, establecer los valores después de cargar los datos
    if (widget.agenda != null) {
      // Verificar que el cliente existe en la lista
      // FIX: Solo validar si NO es un usuario cliente. El usuario cliente ya tiene su selección forzada.
      if (!_isClientUser) {
        if (_clientes.any(
          (c) => c.documentoCliente == widget.agenda!.documentoCliente,
        )) {
          _selectedCliente = widget.agenda!.documentoCliente;
        } else {
          _selectedCliente = null;
        }
      } else {
        // Para clientes, si por alguna razón no se seteo el cliente (ej. fallo al cargar usuario),
        // aseguramos que tenga el de la agenda al menos.
        _selectedCliente ??= widget.agenda!.documentoCliente;
      }

      // Verificar que el empleado existe en la lista
      if (_empleados.any(
        (e) => e.documentoEmpleado == widget.agenda!.documentoEmpleado,
      )) {
        _selectedEmpleado = widget.agenda!.documentoEmpleado;
      } else {
        _selectedEmpleado = null;
      }

      // Mapear metodoPago: intentar encontrar por nombre primero, luego por ID
      if (widget.agenda!.nombreMetodoPago != null &&
          widget.agenda!.nombreMetodoPago!.isNotEmpty) {
        try {
          final metodoEncontrado = _metodosPago.firstWhere(
            (m) =>
                m.nombre.toLowerCase().trim() ==
                widget.agenda!.nombreMetodoPago!.toLowerCase().trim(),
            orElse: () => MetodoPago(metodopagoId: 0, nombre: ''),
          );
          if (metodoEncontrado.metodopagoId > 0) {
            _selectedMetodoPago = metodoEncontrado.metodopagoId;
            print(
              'Método de pago encontrado por nombre: ${metodoEncontrado.nombre} (ID: ${metodoEncontrado.metodopagoId})',
            );
          } else {
            // Si no se encuentra por nombre, usar el ID directamente
            if (widget.agenda!.metodopagoId > 0 &&
                _metodosPago.any(
                  (m) => m.metodopagoId == widget.agenda!.metodopagoId,
                )) {
              _selectedMetodoPago = widget.agenda!.metodopagoId;
              print(
                'Método de pago encontrado por ID: ${widget.agenda!.metodopagoId}',
              );
            } else {
              _selectedMetodoPago = null;
              print(
                'No se encontró método de pago. Nombre buscado: ${widget.agenda!.nombreMetodoPago}, ID: ${widget.agenda!.metodopagoId}',
              );
            }
          }
        } catch (e) {
          print('Error al buscar método de pago: $e');
          if (widget.agenda!.metodopagoId > 0 &&
              _metodosPago.any(
                (m) => m.metodopagoId == widget.agenda!.metodopagoId,
              )) {
            _selectedMetodoPago = widget.agenda!.metodopagoId;
          } else {
            _selectedMetodoPago = null;
          }
        }
      } else {
        // Si no hay nombre, usar el ID directamente si existe en la lista
        if (widget.agenda!.metodopagoId > 0 &&
            _metodosPago.any(
              (m) => m.metodopagoId == widget.agenda!.metodopagoId,
            )) {
          _selectedMetodoPago = widget.agenda!.metodopagoId;
          print(
            'Método de pago encontrado por ID: ${widget.agenda!.metodopagoId}',
          );
        } else {
          _selectedMetodoPago = null;
          print(
            'No se encontró método de pago por ID: ${widget.agenda!.metodopagoId}',
          );
        }
      }

      // Establecer estado
      if (widget.agenda != null && widget.agenda!.estadoId != null) {
        // Verificar que el estado existe en la lista
        if (_estados.any((e) => e.estadoId == widget.agenda!.estadoId)) {
          _selectedEstado = widget.agenda!.estadoId;
        } else {
          // Si no existe, intentar buscar por nombre si está disponible o dejar nulo
          if (widget.agenda!.nombreEstado != null &&
              widget.agenda!.nombreEstado!.isNotEmpty) {
            try {
              final estadoEncontrado = _estados.firstWhere(
                (e) =>
                    e.nombre.toLowerCase() ==
                    widget.agenda!.nombreEstado!.toLowerCase(),
                orElse: () => Estado(estadoId: 0, nombre: ''),
              );
              if (estadoEncontrado.estadoId > 0) {
                _selectedEstado = estadoEncontrado.estadoId;
              } else {
                _selectedEstado = null;
              }
            } catch (e) {
              _selectedEstado = null;
            }
          } else {
            _selectedEstado = null;
          }
        }
      }
    }

    if (mounted) {
      setState(() {
        _isLoadingData = false;
      });
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

  bool get _isClientUser {
    return widget.user != null &&
        widget.user!["rol"]?.toString().toLowerCase() == "cliente";
  }

  bool get _isEmployeeUser {
    return widget.user != null &&
        widget.user!["rol"]?.toString().toLowerCase() == "empleado";
  }

  bool get _isAdminUser {
    return widget.user != null &&
        (widget.user!["rol"]?.toString().toLowerCase() == "administrador" ||
         widget.user!["rol"]?.toString().toLowerCase() == "super admin" ||
         widget.user!["rol"]?.toString().toLowerCase() == "superadmin" ||
         widget.user!["rol"]?.toString().toLowerCase() == "super administrador");
  }

  double get _totalCosto {
    return _serviciosDisponibles
        .where((s) => _serviciosSeleccionados.contains(s.servicioId))
        .fold(0.0, (sum, s) => sum + s.precio);
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null && picked != _selectedTime) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _saveAgenda() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (_selectedCliente == null ||
        _selectedEmpleado == null ||
        _selectedMetodoPago == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor completa todos los campos requeridos'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      print(
        'DEBUG Servicios disponibles: ${_serviciosDisponibles
                .map((s) => 'id:${s.servicioId}, nombre:${s.nombre}')
                .join(', ')}',
      );
      print('DEBUG IDs seleccionados: ${_serviciosSeleccionados.join(', ')}');
      // Filtrar servicios seleccionados
      final serviciosSeleccionadosList = _serviciosDisponibles
          .where((s) => _serviciosSeleccionados.contains(s.servicioId))
          .toList();

      print(
        'Servicios seleccionados (IDs): ${_serviciosSeleccionados.toList()}',
      );
      print(
        'Servicios disponibles: ${_serviciosDisponibles.map((s) => '${s.servicioId}: ${s.nombre}').toList()}',
      );
      print(
        'Servicios a enviar: ${serviciosSeleccionadosList.map((s) => '${s.servicioId}: ${s.nombre}').toList()}',
      );
      print('Método de pago seleccionado: $_selectedMetodoPago');

      if (serviciosSeleccionadosList.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debes seleccionar al menos un servicio'),
            backgroundColor: Colors.orange,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Validar que el método de pago existe en la lista
      final metodoPagoValido = _metodosPago.any(
        (m) => m.metodopagoId == _selectedMetodoPago,
      );
      if (!metodoPagoValido) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('El método de pago seleccionado no es válido'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final idsServicios = _serviciosSeleccionados
          .where((id) => id > 0)
          .toList();
      final agenda = Agenda(
        agendaId: widget.agenda?.agendaId,
        documentoCliente: _selectedCliente!,
        documentoEmpleado: _selectedEmpleado!,
        fechaCita: _selectedDate,
        horaInicio:
            '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}:00',
        metodopagoId: _selectedMetodoPago!,
        estadoId: _selectedEstado,
        observaciones: _observaciones,
        servicios: idsServicios
            .map(
              (id) => Servicio(
                servicioId: id,
                nombre: '',
                precio: 0,
                duracion: 0,
                estado: true,
              ),
            )
            .toList(),
      );

      // Verificar el JSON antes de enviar
      final jsonToSend = agenda.toJson();
      print('=== DATOS A ENVIAR ===');
      print('Cliente: $_selectedCliente');
      print('Empleado: $_selectedEmpleado');
      print('Fecha: ${_selectedDate.toIso8601String().split('T')[0]}');
      print(
        'Hora inicio: ${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}:00',
      );
      print('Método de pago ID: $_selectedMetodoPago');
      print(
        'Método de pago nombre: ${_metodosPago.firstWhere((m) => m.metodopagoId == _selectedMetodoPago).nombre}',
      );
      print(
        'Servicios IDs: ${serviciosSeleccionadosList.map((s) => s.servicioId).toList()}',
      );
      print(
        'Servicios nombres: ${serviciosSeleccionadosList.map((s) => s.nombre).toList()}',
      );
      print('JSON completo: ${json.encode(jsonToSend)}');
      print('=====================');

      if (widget.agenda == null) {
        await _apiService.createAgenda(agenda);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cita creada exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        await _apiService.updateAgenda(agenda.agendaId!, agenda);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cita actualizada exitosamente'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      if (mounted) {
        String errorMessage = e.toString();
        if (errorMessage.startsWith('Exception: ')) {
          errorMessage = errorMessage.substring(11);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              errorMessage,
              maxLines: 10,
              overflow: TextOverflow.ellipsis,
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'OK',
              textColor: Colors.white,
              onPressed: () {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
              },
            ),
          ),
        );
      }
    }
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
                title: widget.agenda == null ? 'Nueva Cita' : 'Editar Cita',
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
                  child: _isLoadingData
                      ? const Center(child: CircularProgressIndicator())
                      : Form(
                          key: _formKey,
                          child: ListView(
                            padding: const EdgeInsets.all(20),
                            children: [
                              // Fecha
                              _buildFormField(
                                label: 'Fecha',
                                child: InkWell(
                                  onTap: _selectDate,
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: AppColors.primaryPurple,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          DateFormat(
                                            'yyyy-MM-dd',
                                          ).format(_selectedDate),
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                        const Icon(
                                          Icons.calendar_today,
                                          color: AppColors.primaryPurple,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Hora
                              _buildFormField(
                                label: 'Hora',
                                child: InkWell(
                                  onTap: _selectTime,
                                  child: Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: AppColors.primaryPurple,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          _selectedTime.format(context),
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                        const Icon(
                                          Icons.access_time,
                                          color: AppColors.primaryPurple,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Cliente
                              _buildFormField(
                                label: 'Cliente *',
                                child: _isClientUser
                                    ? Container(
                                        padding: const EdgeInsets.all(16),
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: AppColors.textGray
                                                .withOpacity(0.5),
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          color: Colors.grey[100],
                                        ),
                                        child: Text(
                                          _selectedCliente != null
                                              ? (_clientes.isNotEmpty
                                                    ? _clientes
                                                          .firstWhere(
                                                            (c) =>
                                                                c.documentoCliente ==
                                                                _selectedCliente,
                                                            orElse: () => Cliente(
                                                              documentoCliente:
                                                                  '',
                                                              nombre:
                                                                  widget
                                                                      .agenda
                                                                      ?.nombreCliente ??
                                                                  (widget.user !=
                                                                          null
                                                                      ? widget.user!["nombre"] ??
                                                                            'Cliente Actual'
                                                                      : 'Cliente Actual'),
                                                            ),
                                                          )
                                                          .nombre
                                                    : (widget
                                                              .agenda
                                                              ?.nombreCliente ??
                                                          (widget.user != null
                                                              ? widget.user!["nombre"] ??
                                                                    'Cargando...'
                                                              : 'Cargando...')))
                                              : 'Cargando cliente...',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      )
                                    : _clientes.isEmpty
                                    ? Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: AppColors.textGray,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          color: AppColors.textGray.withOpacity(
                                            0.1,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'No hay clientes disponibles',
                                              style: TextStyle(
                                                color: AppColors.textGray,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Verifica la conexión con la API',
                                              style: TextStyle(
                                                color: AppColors.textGray
                                                    .withOpacity(0.7),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : DropdownButtonFormField<String>(
                                        initialValue:
                                            _selectedCliente != null &&
                                                _clientes.any(
                                                  (c) =>
                                                      c.documentoCliente ==
                                                      _selectedCliente,
                                                )
                                            ? _selectedCliente
                                            : null,
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 12,
                                              ),
                                        ),
                                        hint: const Text(
                                          'Selecciona un cliente',
                                        ),
                                        items: _clientes.map((cliente) {
                                          return DropdownMenuItem(
                                            value: cliente.documentoCliente,
                                            child: Text(cliente.nombre),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedCliente = value;
                                          });
                                        },
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Selecciona un cliente';
                                          }
                                          return null;
                                        },
                                      ),
                              ),
                              const SizedBox(height: 16),
                              // Empleado
                              _buildFormField(
                                label: 'Empleado *',
                                child: _isEmployeeUser
                                    ? Container(
                                        padding: const EdgeInsets.all(16),
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: AppColors.textGray
                                                .withOpacity(0.5),
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          color: Colors.grey[100],
                                        ),
                                        child: Text(
                                          _selectedEmpleado != null
                                              ? (_empleados.isNotEmpty
                                                    ? _empleados
                                                          .firstWhere(
                                                            (e) =>
                                                                e.documentoEmpleado ==
                                                                _selectedEmpleado,
                                                            orElse: () => Empleado(
                                                              documentoEmpleado:
                                                                  '',
                                                              nombre:
                                                                  widget
                                                                      .agenda
                                                                      ?.nombreEmpleado ??
                                                                  'Empleado Actual',
                                                            ),
                                                          )
                                                          .nombre
                                                    : (widget
                                                              .agenda
                                                              ?.nombreEmpleado ??
                                                          'Cargando...'))
                                              : 'Cargando empleado...',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      )
                                    : _empleados.isEmpty
                                    ? Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: AppColors.textGray,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          color: AppColors.textGray.withOpacity(
                                            0.1,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'No hay empleados disponibles',
                                              style: TextStyle(
                                                color: AppColors.textGray,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Verifica la conexión con la API',
                                              style: TextStyle(
                                                color: AppColors.textGray
                                                    .withOpacity(0.7),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : DropdownButtonFormField<String>(
                                        initialValue:
                                            _selectedEmpleado != null &&
                                                _empleados.any(
                                                  (e) =>
                                                      e.documentoEmpleado ==
                                                      _selectedEmpleado,
                                                )
                                            ? _selectedEmpleado
                                            : null,
                                        decoration: InputDecoration(
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 16,
                                                vertical: 12,
                                              ),
                                        ),
                                        hint: const Text(
                                          'Selecciona un empleado',
                                        ),
                                        items: _empleados.map((empleado) {
                                          return DropdownMenuItem(
                                            value: empleado.documentoEmpleado,
                                            child: Text(empleado.nombre),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          setState(() {
                                            _selectedEmpleado = value;
                                          });
                                        },
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Selecciona un empleado';
                                          }
                                          return null;
                                        },
                                      ),
                              ),
                              const SizedBox(height: 16),
                              // Servicios
                              _buildFormField(
                                label: 'Servicios *',
                                child: _serviciosDisponibles.isEmpty
                                    ? Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: AppColors.textGray,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          color: AppColors.textGray.withOpacity(
                                            0.1,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'No hay servicios disponibles',
                                              style: TextStyle(
                                                color: AppColors.textGray,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Verifica la conexión con la API',
                                              style: TextStyle(
                                                color: AppColors.textGray
                                                    .withOpacity(0.7),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: _serviciosDisponibles
                                            .map(
                                              (servicio) => FilterChip(
                                                label: Text(
                                                  '${servicio.nombre} (${_formatCurrency(servicio.precio)})',
                                                ),
                                                selected:
                                                    _serviciosSeleccionados
                                                        .contains(
                                                          servicio.servicioId,
                                                        ),
                                                onSelected: (selected) {
                                                  setState(() {
                                                    if (selected) {
                                                      _serviciosSeleccionados
                                                          .add(
                                                            servicio.servicioId,
                                                          );
                                                    } else {
                                                      _serviciosSeleccionados
                                                          .remove(
                                                            servicio.servicioId,
                                                          );
                                                    }
                                                  });
                                                },
                                                selectedColor: AppColors
                                                    .primaryPink
                                                    .withOpacity(0.25),
                                                checkmarkColor:
                                                    AppColors.primaryPink,
                                                backgroundColor:
                                                    AppColors.white,
                                                side: BorderSide(
                                                  color:
                                                      _serviciosSeleccionados
                                                          .contains(
                                                            servicio.servicioId,
                                                          )
                                                      ? AppColors.primaryPink
                                                      : AppColors.textGray
                                                            .withOpacity(0.3),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                      ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total:',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textDark,
                                    ),
                                  ),
                                  Text(
                                    _formatCurrency(_totalCosto),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryPurple,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Método de pago
                              _buildFormField(
                                label: 'Método de Pago *',
                                child: DropdownButtonFormField<int>(
                                  initialValue:
                                      _selectedMetodoPago != null &&
                                          _metodosPago.any(
                                            (m) =>
                                                m.metodopagoId ==
                                                _selectedMetodoPago,
                                          )
                                      ? _selectedMetodoPago
                                      : null,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                  hint: const Text(
                                    'Selecciona un método de pago',
                                  ),
                                  items: _metodosPago.map((metodo) {
                                    return DropdownMenuItem(
                                      value: metodo.metodopagoId,
                                      child: Text(metodo.nombre),
                                    );
                                  }).toList(),
                                  onChanged: (value) {
                                    setState(() {
                                      _selectedMetodoPago = value;
                                    });
                                  },
                                  validator: (value) {
                                    if (value == null) {
                                      return 'Selecciona un método de pago';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                              // Estado (Solo si es edición)
                              if (widget.agenda != null) ...[
                                _buildFormField(
                                  label: 'Estado',
                                  child: DropdownButtonFormField<int>(
                                    initialValue: _selectedEstado,
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 12,
                                          ),
                                    ),
                                    hint: const Text('Selecciona un estado'),
                                    items: _estados
                                        .where((estado) {
                                          // Siempre mostrar el estado actual si está seleccionado para evitar error de DropdownMenuItem
                                          if (estado.estadoId ==
                                              _selectedEstado) {
                                            return true;
                                          }
                                          // Filtrar para clientes
                                          if (_isClientUser) {
                                            final lowerName = estado.nombre
                                                .toLowerCase();
                                            if (lowerName.contains(
                                                  'confirmada',
                                                ) ||
                                                lowerName.contains(
                                                  'confirmado',
                                                ) ||
                                                lowerName.contains(
                                                  'completada',
                                                ) ||
                                                lowerName.contains(
                                                  'completado',
                                                )) {
                                              return false;
                                            }
                                          }
                                          return true;
                                        })
                                        .map((estado) {
                                          return DropdownMenuItem(
                                            value: estado.estadoId,
                                            child: Text(estado.nombre),
                                          );
                                        })
                                        .toList(),
                                    onChanged: (value) async {
                                      if (value == null) return;

                                      final selectedEstadoObj = _estados
                                          .firstWhere(
                                            (e) => e.estadoId == value,
                                            orElse: () =>
                                                Estado(estadoId: 0, nombre: ''),
                                          );
                                      final nombreLower = selectedEstadoObj
                                          .nombre
                                          .toLowerCase();

                                      if (nombreLower.contains('cancelado') ||
                                          nombreLower.contains('cancelada') ||
                                          nombreLower.contains('completado') ||
                                          nombreLower.contains('completada')) {
                                        final isCancel = nombreLower.contains(
                                          'cancel',
                                        );
                                        final action = isCancel
                                            ? 'cancelar'
                                            : 'completar';
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: Text(
                                              isCancel
                                                  ? 'Confirmar cancelación'
                                                  : 'Confirmar completación',
                                            ),
                                            content: Text(
                                              '¿Estás seguro de que quieres $action esta cita?',
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  false,
                                                ),
                                                child: const Text('No'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(
                                                  context,
                                                  true,
                                                ),
                                                child: const Text('Sí'),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirm == true) {
                                          setState(() {
                                            _selectedEstado = value;
                                          });
                                        } else {
                                          // Si dice que no, forzamos un rebuild para mantener el valor anterior visualmente
                                          // aunque _selectedEstado no cambió, el Dropdown podría haber mostrado la selección temporal
                                          setState(() {});
                                        }
                                      } else {
                                        setState(() {
                                          _selectedEstado = value;
                                        });
                                      }
                                    },
                                    validator: (value) {
                                      if (widget.agenda != null &&
                                          value == null) {
                                        return 'Selecciona un estado';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              // Observaciones
                              _buildFormField(
                                label: 'Observaciones',
                                child: TextFormField(
                                  initialValue: _observaciones,
                                  maxLines: 3,
                                  decoration: InputDecoration(
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    contentPadding: const EdgeInsets.all(16),
                                  ),
                                  onSaved: (value) {
                                    _observaciones = value;
                                  },
                                ),
                              ),
                              const SizedBox(height: 32),
                              // Botón guardar
                              ElevatedButton(
                                onPressed: _isLoading ? null : _saveAgenda,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primaryPurple,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isLoading
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                AppColors.white,
                                              ),
                                        ),
                                      )
                                    : const Text(
                                        'Guardar',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.white,
                                        ),
                                      ),
                              ),
                            ],
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFormField({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark,
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}
