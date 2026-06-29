import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/agenda.dart';
import 'package:astrhoapp/core/services/api_service.dart';
import 'package:astrhoapp/core/utils/colors.dart';
import 'package:astrhoapp/core/widgets/custom_alert.dart';

// Enumeración para el estado de un slot de tiempo
enum TimeSlotStatus {
  available,   // LIBRE: Disponible para agendar
  reserved,    // RESERVADO: Ocupado por otra cita
  unavailable, // NO DISPONIBLE: Hora pasada o día no laborable
}

// Clase para representar un slot de tiempo con su estado
class TimeSlot {
  final String time;          // Hora en formato 12h (ej: "10:00 AM")
  final TimeSlotStatus status;// Estado del slot
  final DateTime? dateTime;   // DateTime para cálculos

  TimeSlot({
    required this.time,
    required this.status,
    this.dateTime,
  });

  bool get isAvailable => status == TimeSlotStatus.available;
  bool get isReserved => status == TimeSlotStatus.reserved;
  bool get isUnavailable => status == TimeSlotStatus.unavailable;
}

class AppointmentFlowScreen extends StatefulWidget {
  final Agenda? agenda;
  final Agenda? agendaToEdit;
  final String? token;
  final Map<dynamic, dynamic>? user;
  final bool showBackButton;

  const AppointmentFlowScreen({super.key, this.agenda, this.agendaToEdit, this.token, this.user, this.showBackButton = false});

  @override
  State<AppointmentFlowScreen> createState() => _AppointmentFlowScreenState();
}

class _AppointmentFlowScreenState extends State<AppointmentFlowScreen> {
  int currentStep = 0;
  late PageController _pageController; 
  late ApiService _apiService;
  bool isLoading = true;

  // Datos seleccionados
  Cliente? selectedCliente;
  Empleado? selectedEmpleado;
  Set<int> serviciosSeleccionados = {};
  MetodoPago? selectedMetodoPago;
  DateTime? selectedDate;
  String? selectedTime;

  // Datos disponibles
  List<Cliente> clientes = [];
  List<Empleado> empleados = [];
  List<Servicio> serviciosDisponibles = [];
  List<MetodoPago> metodosPago = [];
  List<HorarioEmpleado> horariosEmpleado = [];
  List<Agenda> citasEmpleadoFecha = [];
  List<TimeSlot> availableTimeSlots = [];
  List<String> horasDisponiblesApi = []; // Horas que vienen de la API
  bool loadingHorarios = false;
  
  // Mapa de empleados que tienen horas disponibles
  Map<String, bool> empleadosConHoras = {};

  // Pagination variables
  final int _itemsPerPage = 6;
  int _currentServicePage = 1;
  int _totalServicePages = 1;

  // Displayed items for pagination
  List<Servicio> _displayedServicios = [];
  
  // Search filters
  String _servicioSearchQuery = '';
  List<Servicio> _serviciosFiltered = [];
  late TextEditingController _servicioSearchController;
  
  String _clienteSearchQuery = '';
  List<Cliente> _clientesFiltered = [];
  late TextEditingController _clienteSearchController;
  int _currentClienteFilteredPage = 1;
  int _totalClienteFilteredPages = 1;
  List<Cliente> _displayedClientesFiltered = [];
  
  String _empleadoSearchQuery = '';
  List<Empleado> _empleadosFiltered = [];
  late TextEditingController _empleadoSearchController;
  int _currentEmpleadoFilteredPage = 1;
  int _totalEmpleadoFilteredPages = 1;
  List<Empleado> _displayedEmpleadosFiltered = [];

  // Debounce timers para búsquedas
  Timer? _servicioSearchTimer;
  Timer? _clienteSearchTimer;
  Timer? _empleadoSearchTimer;
  
  // Focus nodes para los campos de búsqueda
  late FocusNode _servicioFocusNode;
  late FocusNode _clienteFocusNode;
  late FocusNode _empleadoFocusNode;

  // Lógica de roles
  bool get isCliente =>
      widget.user?["rol"]?.toString().toLowerCase() == "cliente";

  bool get isAsistente =>
      widget.user?["rol"]?.toString().toLowerCase() == "empleado" ||
      widget.user?["rol"]?.toString().toLowerCase() == "asistente";

  bool get isAdmin =>
      widget.user?["rol"]?.toString().toLowerCase() == "administrador" ||
      widget.user?["rol"]?.toString().toLowerCase() == "super admin" ||
      widget.user?["rol"]?.toString().toLowerCase() == "superadmin" ||
      widget.user?["rol"]?.toString().toLowerCase() == "super administrador";

  @override
  void initState() {
    super.initState();
    _apiService = ApiService(token: widget.token);
    _pageController = PageController(initialPage: 0);
    
    // Inicializar TextEditingControllers
    _servicioSearchController = TextEditingController();
    _servicioSearchController.addListener(_onServiceSearchChanged);
    _clienteSearchController = TextEditingController();
    _clienteSearchController.addListener(_onClienteSearchChanged);
    _empleadoSearchController = TextEditingController();
    _empleadoSearchController.addListener(_onEmpleadoSearchChanged);
    
    // Inicializar FocusNodes
    _servicioFocusNode = FocusNode();
    _clienteFocusNode = FocusNode();
    _empleadoFocusNode = FocusNode();
    
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      // Cargar datos en paralelo
      final futures = <Future>[];
      futures.add(_apiService.getClientes().then((data) => clientes = data));
      futures.add(_apiService.getEmpleados().then((data) {
        empleados = data;
        // Log para ver si agendable viene del servidor
        print('========================================');
        print('EMPLEADOS CARGADOS:');
        for (int i = 0; i < empleados.length; i++) {
          final e = empleados[i];
          print('  - Empleado $i: Nombre=${e.nombre}, agendable=${e.agendable}, estado=${e.estado}');
        }
        print('========================================');
      }));
      // Load ALL services from all pages (API has 5 records per page)
      futures.add(_loadAllServicios());
      futures.add(_apiService.getMetodosPago().then((data) => metodosPago = data));
      
      // Cargar horarios de TODOS los empleados para verificar cuáles tienen horas
      futures.add(_loadEmpleadosHorariosInfo());

      // Esperar a que se carguen los horarios de forma sincrónica
      // NO usar await Future.wait() para todo, porque eso permite que _updatePaginationForEmpleados se ejecute
      // antes de que los horarios estén listos
      
      // Primero cargar datos rápidos
      await Future.wait([
        _apiService.getClientes().then((data) => clientes = data),
        _apiService.getEmpleados().then((data) {
          empleados = data;
          // Log para ver si agendable viene del servidor
          print('========================================');
          print('EMPLEADOS CARGADOS:');
          for (int i = 0; i < empleados.length; i++) {
            final e = empleados[i];
            print('  - Empleado $i: Nombre=${e.nombre}, agendable=${e.agendable}, estado=${e.estado}');
          }
          print('========================================');
        }),
        _loadAllServicios(),
        _apiService.getMetodosPago().then((data) => metodosPago = data),
      ]);
      
      // Cargar horarios de forma sincrónica ANTES de actualizar paginación
      await _loadEmpleadosHorariosInfo();
      
      print('========================================');
      print('SERVICIOS DISPONIBLES CARGADOS:');
      for (int i = 0; i < serviciosDisponibles.length; i++) {
        final s = serviciosDisponibles[i];
        print('  - Servicio $i: ID=${s.servicioId}, Nombre=${s.nombre}, Duracion=${s.duracion}');
      }
      print('========================================');

      // Initialize pagination DESPUÉS de que los horarios estén completamente cargados
      if (mounted) {
        setState(() {
          _updatePaginationForClientes();
          _updatePaginationForEmpleados();
          _updatePaginationForServicios();
        });
      }

      // Si hay una cita para editar, prellenar los datos
      if (widget.agendaToEdit != null) {
        final agenda = widget.agendaToEdit!;

        // Prellenar cliente
        try {
          selectedCliente = clientes.firstWhere(
            (c) => c.documentoCliente == agenda.documentoCliente,
          );
        } catch (_) {}

        // Prellenar empleado
        try {
          selectedEmpleado = empleados.firstWhere(
            (e) => e.documentoEmpleado == agenda.documentoEmpleado,
          );
        } catch (_) {}

        // Prellenar servicios
        if (agenda.servicios != null) {
          serviciosSeleccionados = agenda.servicios!
              .map((s) => s.servicioId)
              .toSet();
        }

        // Prellenar método de pago
        try {
          if (agenda.metodopagoId != null) {
            selectedMetodoPago = metodosPago.firstWhere(
              (m) => m.metodopagoId == agenda.metodopagoId,
            );
          }
        } catch (_) {}

        // Prellenar fecha y hora
        selectedDate = agenda.fechaCita;
        selectedTime = agenda.horaInicio;
      } else {
        // Asignar automáticamente según rol (solo si no estamos editando)
        if (isCliente) {
          final userId = widget.user?["usuarioId"];
          if (userId != null) {
            try {
              selectedCliente = clientes.firstWhere(
                (c) => c.usuarioId == userId,
              );
            } catch (_) {}
          }
        }

        if (isAsistente) {
          final userId = widget.user?["usuarioId"];
          if (userId != null) {
            try {
              selectedEmpleado = empleados.firstWhere(
                (e) => e.usuarioId == userId,
              );
            } catch (_) {}
          }
        }

        // Inicializar fecha y método de pago por defecto
        selectedDate = DateTime.now();
        if (metodosPago.isNotEmpty) {
          selectedMetodoPago = metodosPago.first;
        }
      }

      // Cargar horarios iniciales si hay empleado seleccionado
      if (selectedEmpleado != null) {
        await _loadEmpleadoHorarios();
      }
    } catch (e) {
      print("Error cargando datos iniciales: $e");
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Load all services from all pages (API pagination: 5 records per page)
  Future<void> _loadAllServicios() async {
    try {
      final List<Servicio> allServicios = [];
      int currentPage = 1;
      bool hasMorePages = true;

      while (hasMorePages) {
        final result = await _apiService.getServicios(pagina: currentPage);
        final pageServicios = result['servicios'] as List<Servicio>;
        
        if (pageServicios.isEmpty) {
          hasMorePages = false;
        } else {
          allServicios.addAll(pageServicios);
          final totalPages = result['totalPaginas'] as int;
          
          if (currentPage >= totalPages) {
            hasMorePages = false;
          } else {
            currentPage++;
          }
        }
      }

      // Filtrar solo servicios activos
      serviciosDisponibles = allServicios.where((s) => s.estado == true).toList();
      print('Total servicios cargados: ${allServicios.length}');
      print('Total servicios activos: ${serviciosDisponibles.length}');
    } catch (e) {
      print('Error cargando todos los servicios: $e');
      serviciosDisponibles = [];
    }
  }

  // Pagination helper methods
  void _updatePaginationForClientes() {
    // Filtrar clientes: solo activos y con rol de cliente en su usuario
    final clientesFiltrados = clientes
        .where((c) {
          // 1. Solo mostrar clientes activos
          if (c.estado != true) {
            print('❌ Cliente ${c.nombre} inactivo, no se muestra');
            return false;
          }
          
          // 2. Filtrar por rol del usuario asociado
          // Si el cliente tiene usuarioId, verificar que sea cliente o que el usuario actual sea admin
          if (isAdmin) {
            // Admins ven todos los clientes activos
            return true;
          } else if (isCliente) {
            // Clientes solo ven a sí mismos
            if (widget.user?["usuarioId"] != null && c.usuarioId == widget.user?["usuarioId"]) {
              return true;
            }
            return false;
          } else {
            // Otros roles pueden ver clientes
            return true;
          }
        })
        .toList();
    
    print('👥 Clientes filtrados: ${clientesFiltrados.length} de ${clientes.length}');
    
    // Inicializar lista filtrada con los clientes que pasen el filtro
    _clientesFiltered = List.from(clientesFiltrados);
    
    // También inicializar páginas filtradas
    _totalClienteFilteredPages = (_clientesFiltered.length / _itemsPerPage).ceil();
    if (_totalClienteFilteredPages == 0) _totalClienteFilteredPages = 1;
    _currentClienteFilteredPage = 1;
    _updateDisplayedClientesFiltered();
  }

  void _updatePaginationForServicios() {
    // Inicializar lista filtrada con todos los servicios disponibles
    if (_serviciosFiltered.isEmpty) {
      _serviciosFiltered = List.from(serviciosDisponibles);
    }
    // En el formulario de agendamiento, no usamos paginación
    // Solo mostramos todos los servicios en un scroll
    _totalServicePages = 1;
    _currentServicePage = 1;
    _updateDisplayedServiciosFiltered();
  }

  void _updatePaginationForEmpleados() {
    // Filtrar empleados: solo activos y agendables
    print('========================================');
    print('FILTRANDO EMPLEADOS:');
    print('Total empleados: ${empleados.length}');
    
    final empleadosActivos = empleados
        .where((e) {
          print('  - ${e.nombre}: estado=${e.estado}, agendable=${e.agendable}');
          
          // Solo mostrar empleados activos
          if (e.estado != true) {
            print('    ❌ Inactivo, no se muestra');
            return false;
          }
          
          // Solo mostrar empleados agendables (si agendable es false, no mostrar)
          if (e.agendable == false) {
            print('    ❌ No agendable, no se muestra');
            return false;
          }
          
          print('    ✅ Se muestra');
          
          // Filtrar por rol del usuario asociado
          if (isAdmin) {
            return true;
          } else if (isAsistente) {
            if (widget.user?["usuarioId"] != null && e.usuarioId == widget.user?["usuarioId"]) {
              return true;
            }
            return false;
          } else if (isCliente) {
            return true;
          } else {
            return true;
          }
        })
        .toList();
    
    print('👤 Empleados activos: ${empleadosActivos.length} de ${empleados.length}');
    print('========================================');
    
    _empleadosFiltered = List.from(empleadosActivos);
    _totalEmpleadoFilteredPages = (_empleadosFiltered.length / _itemsPerPage).ceil();
    if (_totalEmpleadoFilteredPages == 0) _totalEmpleadoFilteredPages = 1;
    _currentEmpleadoFilteredPage = 1;
    _updateDisplayedEmpleadosFiltered();
  }

  void _filterServicios(String query) {
    setState(() {
      _servicioSearchQuery = query.toLowerCase();
      if (_servicioSearchQuery.isEmpty) {
        _serviciosFiltered = List.from(serviciosDisponibles);
      } else {
        _serviciosFiltered = serviciosDisponibles
            .where((s) =>
                s.nombre.toLowerCase().contains(_servicioSearchQuery) ||
                (s.descripcion?.toLowerCase().contains(_servicioSearchQuery) ??
                    false))
            .toList();
      }
      _currentServicePage = 1;
      _totalServicePages = (_serviciosFiltered.length / _itemsPerPage).ceil();
      if (_totalServicePages == 0) _totalServicePages = 1;
      _updateDisplayedServiciosFiltered();
    });
  }

  void _updateDisplayedServiciosFiltered() {
    _displayedServicios = List.from(_serviciosFiltered);
  }

  void _filterClientes(String query) {
    setState(() {
      _clienteSearchQuery = query.toLowerCase();
      
      // Filtrar por búsqueda
      List<Cliente> resultado = clientes;
      
      if (_clienteSearchQuery.isNotEmpty) {
        resultado = clientes
            .where((c) =>
                c.nombre.toLowerCase().contains(_clienteSearchQuery) ||
                c.documentoCliente.toLowerCase().contains(_clienteSearchQuery))
            .toList();
      }
      
      // Filtrar por estado y rol
      _clientesFiltered = resultado
          .where((c) {
            // 1. Solo mostrar clientes activos
            if (c.estado != true) {
              return false;
            }
            
            // 2. Filtrar por rol del usuario asociado
            if (isAdmin) {
              return true;
            } else if (isCliente) {
              // Clientes solo ven a sí mismos
              return widget.user?["usuarioId"] != null && c.usuarioId == widget.user?["usuarioId"];
            } else {
              return true;
            }
          })
          .toList();
      
      _currentClienteFilteredPage = 1;
      _totalClienteFilteredPages = (_clientesFiltered.length / _itemsPerPage).ceil();
      if (_totalClienteFilteredPages == 0) _totalClienteFilteredPages = 1;
      _updateDisplayedClientesFiltered();
    });
  }

  void _updateDisplayedClientesFiltered() {
    final start = (_currentClienteFilteredPage - 1) * _itemsPerPage;
    final end = (start + _itemsPerPage).clamp(0, _clientesFiltered.length);
    _displayedClientesFiltered = _clientesFiltered.sublist(start, end);
  }

  // Cargar información de horarios de todos los empleados
  Future<void> _loadEmpleadosHorariosInfo() async {
    try {
      // Si no hay empleados, no hay nada que cargar
      if (empleados.isEmpty) {
        print('⚠️ No hay empleados cargados');
        return;
      }
      
      print('🔄 Cargando horarios de ${empleados.length} empleados...');
      
      for (final empleado in empleados) {
        try {
          final horarios = await _apiService.getHorariosEmpleado(empleado.documentoEmpleado);
          // Un empleado tiene horas si tiene al menos un horario activo
          final tieneHoras = horarios.isNotEmpty && horarios.any((h) => h.estado);
          empleadosConHoras[empleado.documentoEmpleado] = tieneHoras;
          print('✓ ${empleado.nombre} (${empleado.documentoEmpleado}): ${tieneHoras ? 'Tiene horas ✓' : 'Sin horas ✗'}');
        } catch (e) {
          print('⚠️ Error cargando horarios de ${empleado.nombre}: $e');
          // Si hay error, asumir que tiene horas (para no bloquear)
          // El usuario podrá seleccionarlo, y si no tiene horarios disponibles,
          // se mostrará un mensaje al intentar cargar horarios específicos
          empleadosConHoras[empleado.documentoEmpleado] = true;
        }
      }
      
      print('✅ Horarios cargados. Total empleados: ${empleados.length}, Con horas: ${empleadosConHoras.values.where((v) => v).length}');
    } catch (e) {
      print('Error en _loadEmpleadosHorariosInfo: $e');
      // Si hay error general, asumir que todos tienen horas para no bloquear
      for (final empleado in empleados) {
        empleadosConHoras[empleado.documentoEmpleado] = true;
      }
    }
  }

  void _filterEmpleados(String query) {
    setState(() {
      _empleadoSearchQuery = query.toLowerCase();
      
      List<Empleado> resultado = empleados;
      
      if (_empleadoSearchQuery.isNotEmpty) {
        resultado = empleados
            .where((e) =>
                e.nombre.toLowerCase().contains(_empleadoSearchQuery) ||
                e.documentoEmpleado.toLowerCase().contains(_empleadoSearchQuery))
            .toList();
      }
      
      // Filtrar por estado, agendable y rol
      _empleadosFiltered = resultado
          .where((e) {
            // 1. Solo mostrar empleados activos
            if (e.estado != true) {
              return false;
            }
            
            // 2. Solo mostrar empleados que son agendables (if agendable field is set)
            // Si agendable es null, permitir (backward compatibility)
            // Si agendable es false, filtrar (no mostrar)
            if (e.agendable == false) {
              return false;
            }
            
            // 3. Filtrar por rol del usuario asociado
            if (isAdmin) {
              return true;
            } else if (isAsistente) {
              if (widget.user?["usuarioId"] != null && e.usuarioId == widget.user?["usuarioId"]) {
                return true;
              }
              return false;
            } else if (isCliente) {
              return true;
            } else {
              return true;
            }
          })
          .toList();
      
      _currentEmpleadoFilteredPage = 1;
      _totalEmpleadoFilteredPages = (_empleadosFiltered.length / _itemsPerPage).ceil();
      if (_totalEmpleadoFilteredPages == 0) _totalEmpleadoFilteredPages = 1;
      _updateDisplayedEmpleadosFiltered();
    });
  }

  void _updateDisplayedEmpleadosFiltered() {
    final start = (_currentEmpleadoFilteredPage - 1) * _itemsPerPage;
    final end = (start + _itemsPerPage).clamp(0, _empleadosFiltered.length);
    _displayedEmpleadosFiltered = _empleadosFiltered.sublist(start, end);
  }

  void _changeServicePage(int newPage) {
    if (newPage != _currentServicePage && newPage >= 1 && newPage <= _totalServicePages) {
      setState(() {
        _currentServicePage = newPage;
        _updateDisplayedServiciosFiltered();
      });
    }
  }

  void _changeClienteFilteredPage(int newPage) {
    if (newPage != _currentClienteFilteredPage && newPage >= 1 && newPage <= _totalClienteFilteredPages) {
      setState(() {
        _currentClienteFilteredPage = newPage;
        _updateDisplayedClientesFiltered();
      });
    }
  }

  void _changeEmpleadoFilteredPage(int newPage) {
    if (newPage != _currentEmpleadoFilteredPage && newPage >= 1 && newPage <= _totalEmpleadoFilteredPages) {
      setState(() {
        _currentEmpleadoFilteredPage = newPage;
        _updateDisplayedEmpleadosFiltered();
      });
    }
  }

  void _onServiceSearchChanged() {
    _servicioSearchTimer?.cancel();
    _servicioSearchTimer = Timer(const Duration(milliseconds: 300), () {
      _filterServicios(_servicioSearchController.text);
    });
  }

  void _onClienteSearchChanged() {
    _clienteSearchTimer?.cancel();
    _clienteSearchTimer = Timer(const Duration(milliseconds: 300), () {
      _filterClientes(_clienteSearchController.text);
    });
  }

  void _onEmpleadoSearchChanged() {
    _empleadoSearchTimer?.cancel();
    _empleadoSearchTimer = Timer(const Duration(milliseconds: 300), () {
      _filterEmpleados(_empleadoSearchController.text);
    });
  }

  Widget _buildPaginationControls({
    required int currentPage,
    required int totalPages,
    required Function(int) onPageChange,
  }) {
    if (totalPages <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Página $currentPage de $totalPages',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _paginationBtn(
                Icons.first_page,
                currentPage > 1 ? () => onPageChange(1) : null,
              ),
              const SizedBox(width: 4),
              _paginationBtn(
                Icons.chevron_left,
                currentPage > 1 ? () => onPageChange(currentPage - 1) : null,
              ),
              const SizedBox(width: 8),
              ..._buildPageNumbers(currentPage, totalPages, onPageChange),
              const SizedBox(width: 8),
              _paginationBtn(
                Icons.chevron_right,
                currentPage < totalPages ? () => onPageChange(currentPage + 1) : null,
              ),
              const SizedBox(width: 4),
              _paginationBtn(
                Icons.last_page,
                currentPage < totalPages ? () => onPageChange(totalPages) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers(int currentPage, int totalPages, Function(int) onPageChange) {
    List<Widget> pages = [];
    
    int startPage = 1;
    int endPage = totalPages;
    
    if (totalPages > 5) {
      startPage = (currentPage - 2).clamp(1, totalPages - 4);
      endPage = (currentPage + 2).clamp(5, totalPages);
    }
    
    if (startPage > 1) {
      pages.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text('...', style: TextStyle(color: Colors.grey[600], fontSize: 10)),
        ),
      );
    }
    
    for (int i = startPage; i <= endPage; i++) {
      pages.add(const SizedBox(width: 2));
      pages.add(_pageNumber(i, currentPage == i, () => onPageChange(i)));
      pages.add(const SizedBox(width: 2));
    }
    
    if (endPage < totalPages) {
      pages.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text('...', style: TextStyle(color: Colors.grey[600], fontSize: 10)),
        ),
      );
    }
    
    return pages;
  }

  Widget _paginationBtn(IconData icon, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: onTap != null ? Colors.grey[100] : Colors.grey[50],
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: onTap != null ? Colors.grey[300]! : Colors.grey[200]!,
            width: 1,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 14,
          color: onTap != null ? Colors.grey[600] : Colors.grey[300],
        ),
      ),
    );
  }

  Widget _pageNumber(int page, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF7926F7) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: isActive
              ? Border.all(color: const Color(0xFF7926F7), width: 2)
              : Border.all(color: Colors.grey[300]!, width: 1),
        ),
        alignment: Alignment.center,
        child: Text(
          '$page',
          style: TextStyle(
            color: isActive ? Colors.white : Colors.grey[600],
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  // Cargar horarios del empleado seleccionado y citas de la fecha
  Future<void> _loadEmpleadoHorarios() async {
    if (selectedEmpleado == null || selectedDate == null) {
      print('⚠️ No se puede cargar horarios: empleado=$selectedEmpleado, fecha=$selectedDate');
      return;
    }

    print('========================================');
    print('CARGANDO DATOS DEL EMPLEADO');
    print('========================================');
    print('Empleado: ${selectedEmpleado?.nombre}');
    print('Documento: ${selectedEmpleado?.documentoEmpleado}');
    print('Fecha: ${DateFormat('yyyy-MM-dd').format(selectedDate!)}');

    if (!mounted) return;
    
    setState(() {
      loadingHorarios = true;
    });

    try {
      final futures = <Future>[];
      
      // Cargar horarios
      futures.add(_apiService.getHorariosEmpleado(selectedEmpleado!.documentoEmpleado)
          .then((data) {
            print('✅ Horarios cargados: ${data.length}');
            horariosEmpleado = data;
          })
          .catchError((e) {
            print('❌ Error cargando horarios: $e');
            horariosEmpleado = [];
          }));
      
      // Cargar HORAS DISPONIBLES desde la API
      futures.add(_apiService.getHorasDisponibles(
          selectedEmpleado!.documentoEmpleado, selectedDate!)
          .then((horas) {
            print('✅ Horas disponibles desde API: $horas');
            horasDisponiblesApi = horas;
          })
          .catchError((e) {
            print('❌ Error cargando horas disponibles: $e');
            horasDisponiblesApi = [];
          }));
      
      // Cargar TODAS las citas y filtrarlas manualmente (para calcular rangos)
      futures.add(_apiService.getAgendas().then((todasLasCitas) {
        print('✅ Todas las citas cargadas: ${todasLasCitas.length}');
        
        final fechaStr = DateFormat('yyyy-MM-dd').format(selectedDate!);
        final citasFiltradas = todasLasCitas.where((cita) {
          final matchEmpleado = cita.documentoEmpleado == selectedEmpleado!.documentoEmpleado;
          final citaFechaStr = DateFormat('yyyy-MM-dd').format(cita.fechaCita);
          final matchFecha = citaFechaStr == fechaStr;
          return matchEmpleado && matchFecha;
        }).toList();
        
        print('✅ Citas filtradas para empleado y fecha: ${citasFiltradas.length}');
        citasEmpleadoFecha = citasFiltradas;
      })
      .catchError((e) {
        print('❌ Error cargando citas: $e');
        citasEmpleadoFecha = [];
      }));

      await Future.wait(futures);
      
      if (!mounted) return;
      
      print('✅ Todos los datos cargados, calculando slots...');
      _calculateAvailableSlots();
    } catch (e) {
      print("❌ Error cargando horarios del empleado: $e");
      if (mounted) {
        setState(() {
          availableTimeSlots = [];
          loadingHorarios = false;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          loadingHorarios = false;
        });
      }
    }
  }

  // Verificar si el empleado trabaja en un día específico
  bool _doesEmpleadoWorkOnDay(DateTime day) {
    if (horariosEmpleado.isEmpty) return true; // Si no hay horarios, suponer que sí trabaja
    
    final daysOfWeek = [
      'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'
    ];
    final dayIndex = day.weekday - 1; // 0 = lunes, 6 = domingo
    final dayName = daysOfWeek[dayIndex].toLowerCase();
    
    try {
      horariosEmpleado.firstWhere((h) {
        final dia = h.horario?.diaSemana.toLowerCase() ?? '';
        return dia.contains(dayName) || dayName.contains(dia);
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  // Calcular horarios disponibles (RESTRICCIÓN MANUAL 100% PRIORITARIA)
  void _calculateAvailableSlots() {
    print('========================================');
    print('INICIANDO CÁLCULO DE HORARIOS (RESTRICCIÓN MANUAL)');
    print('========================================');
    
    // Verificaciones previas
    if (selectedDate == null) {
      print('⚠️ selectedDate es null, no se pueden calcular slots');
      availableTimeSlots = [];
      setState(() {});
      return;
    }
    
    if (selectedEmpleado == null) {
      print('⚠️ selectedEmpleado es null, no se pueden calcular slots');
      availableTimeSlots = [];
      setState(() {});
      return;
    }
    
    // 0. VERIFICAR TODOS LOS DATOS QUE TENEMOS
    print('--- DATOS DISPONIBLES ---');
    print('selectedEmpleado: ${selectedEmpleado?.nombre}');
    print('Documento: ${selectedEmpleado?.documentoEmpleado}');
    print('selectedDate: ${selectedDate != null ? DateFormat('yyyy-MM-dd').format(selectedDate!) : 'null'}');
    print('citasEmpleadoFecha: ${citasEmpleadoFecha.length} citas');
    print('horariosEmpleado: ${horariosEmpleado.length} horarios');
    print('horasDisponiblesApi: ${horasDisponiblesApi.length} horas');
    
    try {
      // Obtener el día de la semana
      final daysOfWeek = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
      final selectedDayName = daysOfWeek[selectedDate!.weekday - 1].toLowerCase();
      print('Día: $selectedDayName');
      
      // 1. Verificar si el empleado trabaja hoy
      bool empleadoTrabajaHoy = true;
      HorarioEmpleado? horarioDia;
      
      if (horariosEmpleado.isNotEmpty) {
        try {
          horarioDia = horariosEmpleado.firstWhere((h) {
            final dia = h.horario?.diaSemana.toLowerCase() ?? '';
            return dia.contains(selectedDayName) || selectedDayName.contains(dia);
          });
        } catch (_) {
          empleadoTrabajaHoy = false;
        }
      }
      
      if (!empleadoTrabajaHoy) {
        print('El empleado NO trabaja hoy');
        availableTimeSlots = _generateAllDaySlots(TimeSlotStatus.unavailable);
        setState(() {});
        return;
      }
      
    
    print('El empleado SÍ trabaja hoy');
    
    // 2. Obtener horario del día
    DateTime horarioInicio = DateTime(2000, 1, 1, 8, 0);  // 8:00 AM por defecto
    DateTime horarioFin = DateTime(2000, 1, 1, 20, 0);     // 8:00 PM por defecto
    
    if (horarioDia != null && horarioDia.horario != null) {
      horarioInicio = _parseTime(horarioDia.horario!.horaInicio);
      horarioFin = _parseTime(horarioDia.horario!.horaFin);
    }
    print('Horario de trabajo: ${_formatTime12Hour(horarioInicio)} - ${_formatTime12Hour(horarioFin)}');
    
    // Convertir horarioFin a la fecha real del día seleccionado para comparaciones correctas
    final horarioFinEnFechaReal = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      horarioFin.hour,
      horarioFin.minute,
    );
    print('Horario fin convertido a fecha real: ${_formatTime12Hour(horarioFinEnFechaReal)} (${horarioFinEnFechaReal.toString()})');
    
    
    // 3. CALCULAR LOS RANGOS DE LAS CITAS EXISTENTES (CON SU DURACIÓN)
    final rangosCitasExistentes = <DateTimeRange>[];
    print('--- CALCULANDO RANGOS DE CITAS EXISTENTES ---');
    print('  - selectedDate: $selectedDate (${selectedDate != null ? DateFormat('yyyy-MM-dd').format(selectedDate!) : 'null'})');
    print('  - citasEmpleadoFecha.length: ${citasEmpleadoFecha.length}');
    
    for (int i = 0; i < citasEmpleadoFecha.length; i++) {
      final cita = citasEmpleadoFecha[i];
      print('--- Evaluando cita ${i+1} ---');
      print('  - agendaId: ${cita.agendaId}');
      print('  - documentoEmpleado: ${cita.documentoEmpleado}');
      print('  - fechaCita: ${cita.fechaCita} (${DateFormat('yyyy-MM-dd').format(cita.fechaCita)})');
      print('  - horaInicio: ${cita.horaInicio}');
      print('  - nombreEstado: ${cita.nombreEstado}');
      print('  - servicios: ${cita.servicios}');
      if (cita.servicios != null) {
        print('  - servicios.length: ${cita.servicios!.length}');
        for (int j = 0; j < cita.servicios!.length; j++) {
          final s = cita.servicios![j];
          print('    - Servicio $j: nombre=${s.nombre}, duracion=${s.duracion}, servicioId=${s.servicioId}');
        }
      }
      
      // Saltar la misma cita si estamos editando
      if (widget.agendaToEdit != null && cita.agendaId == widget.agendaToEdit!.agendaId) {
        print('  → Saltando (es la misma cita que se edita)');
        continue;
      }
      
      // Saltar citas canceladas
      final estado = cita.nombreEstado?.toLowerCase() ?? '';
      print('  → Estado (lowercase): $estado');
      if (estado.contains('cancelado')) {
        print('  → Saltando (cancelada)');
        continue;
      }
      
      // Parsear la cita y calcular su rango
      final horaCita = _parseTime(cita.horaInicio);
      print('  → Hora parseada: $horaCita');
      final inicioCita = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
        horaCita.hour,
        horaCita.minute,
      );
      print('  → Inicio cita (DateTime): $inicioCita');
      
      int duracionCita = 30;
      print('  → Duración inicial (default): $duracionCita');
      if (cita.servicios != null && cita.servicios!.isNotEmpty) {
        print('  → Calculando duración real usando serviciosDisponibles...');
        duracionCita = 0;
        for (final servicioCita in cita.servicios!) {
          print('    → Buscando servicio en cita: ID=${servicioCita.servicioId}, nombre=${servicioCita.nombre}');
          // Buscar el servicio en serviciosDisponibles por ID
          final servicioEncontrado = serviciosDisponibles.firstWhere(
            (s) => s.servicioId == servicioCita.servicioId,
            orElse: () {
              print('    → ⚠️ Servicio no encontrado en serviciosDisponibles, usando duración de la cita (${servicioCita.duracion})');
              return servicioCita;
            },
          );
          print('    → Servicio encontrado: ${servicioEncontrado.nombre}, duración=${servicioEncontrado.duracion}');
          duracionCita += servicioEncontrado.duracion;
          print('    → Duración actual: $duracionCita');
        }
      }
      print('  → Duración total de la cita: $duracionCita minutos');
      
      final finCita = inicioCita.add(Duration(minutes: duracionCita));
      print('  → Fin cita (DateTime): $finCita');
      rangosCitasExistentes.add(DateTimeRange(start: inicioCita, end: finCita));
      
      print('  ✅ RANGO AÑADIDO: ${_formatTime12Hour(inicioCita)} - ${_formatTime12Hour(finCita)}');
    }
    
    print('Total de rangos de citas: ${rangosCitasExistentes.length}');
    for (int i = 0; i < rangosCitasExistentes.length; i++) {
      final r = rangosCitasExistentes[i];
      print('  Rango $i: ${_formatTime12Hour(r.start)} - ${_formatTime12Hour(r.end)}');
    }
    
    // 4. CALCULAR DURACIÓN TOTAL DEL SERVICIO SELECCIONADO
    int duracionServicioSeleccionado = 30; // Default 30 minutos
    if (serviciosSeleccionados.isNotEmpty) {
      duracionServicioSeleccionado = 0;
      for (final servicioId in serviciosSeleccionados) {
        final servicio = serviciosDisponibles.firstWhere(
          (s) => s.servicioId == servicioId,
          orElse: () => Servicio(
            servicioId: servicioId,
            nombre: 'Desconocido',
            duracion: 30,
            precio: 0,
            estado: true,
          ),
        );
        duracionServicioSeleccionado += servicio.duracion;
      }
    }
    print('--- DURACIÓN DEL SERVICIO SELECCIONADO ---');
    print('Duración total: $duracionServicioSeleccionado minutos');
    
    // 5. Generar y evaluar todos los slots (100% MANUAL, SIN DEPENDER DE LA API)
    final slots = <TimeSlot>[];
    final ahora = DateTime.now();
    
    // Convertir horarioInicio a la fecha real también
    final horarioInicioEnFechaReal = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      horarioInicio.hour,
      horarioInicio.minute,
    );
    
    var horaActual = horarioInicioEnFechaReal;
    int iteraciones = 0;
    const maxIteraciones = 500; // Límite de seguridad para evitar loops infinitos
    
    print('--- EVALUANDO SLOTS (100% MANUAL) ---');
    print('Nota: Se valida que el servicio termine antes de las ${_formatTime12Hour(horarioFinEnFechaReal)}');
    print('Hora inicial real: ${_formatTime12Hour(horarioInicioEnFechaReal)}');
    
    while (horaActual.isBefore(horarioFinEnFechaReal) && iteraciones < maxIteraciones) {
      iteraciones++;
      final slotDateTime = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
        horaActual.hour,
        horaActual.minute,
      );
      
      final slotHoraStr = _formatTime12Hour(horaActual);
      final slotHora24h = DateFormat('HH:mm:ss').format(slotDateTime);
      final slotHora24hSinSegundos = DateFormat('HH:mm').format(slotDateTime);
      final slotInicio = slotDateTime;
      final slotFinConDuracion = slotInicio.add(Duration(minutes: duracionServicioSeleccionado));
      
      TimeSlotStatus estado = TimeSlotStatus.available;
      String motivo = '';
      
      print('  - Evaluando slot: $slotHoraStr ($slotHora24h / $slotHora24hSinSegundos)');
      print('    → Rango del slot con duración: ${_formatTime12Hour(slotInicio)} - ${_formatTime12Hour(slotFinConDuracion)}');
      print('    → Horario fin del profesional: ${_formatTime12Hour(horarioFinEnFechaReal)}');
      
      // 1. VERIFICAR SI LA HORA YA PASÓ (PRIORIDAD 1)
      if (slotInicio.isBefore(ahora)) {
        estado = TimeSlotStatus.unavailable;
        motivo = 'hora pasada';
      }
      // 2. VERIFICAR SI LA CITA TERMINARÍA DESPUÉS DEL HORARIO FIN DEL PROFESIONAL (NUEVA RESTRICCIÓN)
      else if (slotFinConDuracion.isAfter(horarioFinEnFechaReal)) {
        estado = TimeSlotStatus.unavailable;
        motivo = 'la cita terminaría después del horario de fin (${_formatTime12Hour(slotFinConDuracion)} > ${_formatTime12Hour(horarioFinEnFechaReal)})';
      }
      // 3. VERIFICAR SI ESTÁ EN LA LISTA DE HORAS DISPONIBLES DE LA API (PRIORIDAD 3)
      else if (horasDisponiblesApi.contains(slotHora24h) || horasDisponiblesApi.contains(slotHora24hSinSegundos)) {
        // 4. Ahora chequear si se solapa con alguna cita existente (PRIORIDAD 4 - sobreescribe la disponibilidad)
        if (rangosCitasExistentes.any((rango) {
          print('🔍 Evaluando solapamiento: slot $slotHoraStr ($slotInicio - $slotFinConDuracion) vs rango ${_formatTime12Hour(rango.start)} - ${_formatTime12Hour(rango.end)}');
          
          final solapa = slotInicio.isBefore(rango.end) && slotFinConDuracion.isAfter(rango.start);
          if (solapa) {
            print('  ⛔¡SOLAPA!');
          } else {
            print('  ✅ No solapa');
          }
          
          return solapa;
        })) {
          estado = TimeSlotStatus.reserved;
          motivo = 'SOLAPA CON CITA EXISTENTE';
        } else {
          estado = TimeSlotStatus.available;
          motivo = 'disponible según API y no solapa';
        }
      }
      // 5. SI NO ESTÁ EN LA API, ESTÁ RESERVADO
      else {
        estado = TimeSlotStatus.reserved;
        motivo = 'ocupado según API';
      }
      
      // Imprimir resultado
      final icono = estado == TimeSlotStatus.available 
          ? '✅' 
          : (estado == TimeSlotStatus.reserved ? '⛔' : '❌');
      
      print('$icono $slotHoraStr ($slotHora24h): ${estado.name.toUpperCase()} ($motivo)');
      
      slots.add(TimeSlot(
        time: slotHoraStr,
        status: estado,
        dateTime: slotDateTime,
      ));
      
      horaActual = horaActual.add(const Duration(minutes: 30));
    }
    
    // Resumen final
      availableTimeSlots = slots;
      print('========================================');
      print('RESUMEN FINAL:');
      print('  - Total iteraciones: $iteraciones (máximo: $maxIteraciones)');
      if (iteraciones >= maxIteraciones) {
        print('  ⚠️ ADVERTENCIA: Se alcanzó el límite de iteraciones');
      }
      print('  - Disponibles: ${slots.where((s) => s.isAvailable).length}');
      print('  - Reservados: ${slots.where((s) => s.isReserved).length}');
      print('  - No disponibles: ${slots.where((s) => s.isUnavailable).length}');
      print('========================================');
      
      setState(() {});
    } catch (e, stackTrace) {
      print('❌ Error calculando horarios: $e');
      print('Stack trace: $stackTrace');
      availableTimeSlots = [];
      setState(() {});
    }
  }

  // Generar slots para todo el día con el mismo estado
  List<TimeSlot> _generateAllDaySlots(TimeSlotStatus status) {
    final slots = <TimeSlot>[];
    var currentTime = DateTime(2000, 1, 1, 8, 0); // 8:00 AM
    final endTime = DateTime(2000, 1, 1, 20, 0); // 8:00 PM

    while (currentTime.isBefore(endTime)) {
      final fullDateTime = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
        currentTime.hour,
        currentTime.minute,
      );
      
      slots.add(TimeSlot(
        time: _formatTime12Hour(currentTime),
        status: status,
        dateTime: fullDateTime,
      ));
      
      currentTime = currentTime.add(const Duration(minutes: 30));
    }
    return slots;
  }

  // Parsear time string (HH:MM:SS o HH:MM) a DateTime
  DateTime _parseTime(String timeStr) {
    try {
      final parts = timeStr.split(':');
      if (parts.length < 2) {
        // Si el formato es inválido, usar hora por defecto (9:00 AM)
        return DateTime(2000, 1, 1, 9, 0);
      }
      
      int hour = 0;
      int minute = 0;
      
      try {
        hour = int.parse(parts[0]);
      } catch (_) {
        hour = 9;
      }
      
      try {
        minute = int.parse(parts[1]);
      } catch (_) {
        minute = 0;
      }
      
      // Asegurarse que la hora esté en rango válido
      if (hour < 0 || hour > 23) hour = 9;
      if (minute < 0 || minute > 59) minute = 0;
      
      return DateTime(2000, 1, 1, hour, minute);
    } catch (e) {
      print("Error parseando hora '$timeStr': $e");
      // En caso de error, usar hora por defecto
      return DateTime(2000, 1, 1, 9, 0);
    }
  }

  // Formatear DateTime a string de 12 horas (ej: 10:00 AM)
  String _formatTime12Hour(DateTime time) {
    final format = DateFormat('h:mm a');
    return format.format(time);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _servicioSearchController.dispose();
    _clienteSearchController.dispose();
    _empleadoSearchController.dispose();
    // Limpiar timers de debounce
    _servicioSearchTimer?.cancel();
    _clienteSearchTimer?.cancel();
    _empleadoSearchTimer?.cancel();
    // Limpiar FocusNodes
    _servicioFocusNode.dispose();
    _clienteFocusNode.dispose();
    _empleadoFocusNode.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (currentStep < _getSteps().length - 1) {
      setState(() {
        currentStep++;
      });
      _pageController.animateToPage(
        currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (currentStep > 0) {
      setState(() {
        currentStep--;
      });
      _pageController.animateToPage(
        currentStep,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      // Si estamos en el primer paso, regresar a mis citas
      Navigator.pop(context);
    }
  }

  List<Widget> _getSteps() {
    final steps = <Widget>[];

    // Paso 1: Cliente (si es asistente o admin)
    if (isAsistente || isAdmin) {
      steps.add(_clienteScreen());
    }

    // Paso 2: Servicios (todos los roles)
    steps.add(_servicesScreen());

    // Paso 3: Método de pago (todos los roles)
    steps.add(_paymentMethodScreen());

    // Paso 4: Profesional (si es admin o cliente)
    if (!isAsistente) {
      steps.add(_professionalScreen());
    }

    // Paso 5: Fecha y Hora (todos los roles)
    steps.add(_scheduleScreen());

    // Paso 6: Resumen (todos los roles)
    steps.add(_summaryScreen());

    // Paso 7: Confirmación (todos los roles)
    steps.add(_confirmationScreen());
    
    return steps;
  }

  Widget _topBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(gradient: AppColors.primaryGradient),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            widget.showBackButton
                ? IconButton(
                    icon: const Icon(Icons.arrow_back, color: AppColors.white),
                    onPressed: () => Navigator.pop(context),
                  )
                : const SizedBox(width: 48),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: AppColors.primaryPurple,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  "AstrhoApp",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  Widget _stepIndicator() {
    // Determinar los pasos según el rol con abreviaturas cortas
    List<String> stepLabels = [];
    
    if (isCliente) {
      // Cliente: Servicios > Metodo > Profesional > Fecha > Confirmación
      stepLabels = ["Servicios", "Método", "Prof.", "Fecha", "Conf."];
    } else if (isAdmin) {
      // Admin: Cliente > Servicios > Metodo > Profesional > Fecha > Confirmación
      stepLabels = ["Cliente", "Servicios", "Método", "Prof.", "Fecha", "Conf."];
    } else if (isAsistente) {
      // Empleado: Cliente > Servicios > Metodo > Fecha > Confirmación
      stepLabels = ["Cliente", "Servicios", "Método", "Fecha", "Conf."];
    }
    
    // Calcular el índice visual del paso actual
    int visualStep = currentStep;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(stepLabels.length, (index) {
            return SizedBox(
              width: 70,
              child: Column(
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (index > 0)
                        Container(
                          width: 15,
                          height: 2,
                          color: index <= visualStep
                              ? AppColors.primaryPink
                              : Colors.grey.shade300,
                        ),
                      _stepCircle(index, visualStep),
                      if (index < stepLabels.length - 1)
                        Container(
                          width: 15,
                          height: 2,
                          color: index < visualStep
                              ? AppColors.primaryPink
                              : Colors.grey.shade300,
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    stepLabels[index],
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: index <= visualStep
                          ? AppColors.primaryPink
                          : Colors.grey.shade400,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _stepCircle(int index, int visualStep) {
    bool active = index <= visualStep;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: active ? AppColors.primaryPink : Colors.grey.shade300,
        shape: BoxShape.circle,
      ),
      child: active
          ? const Icon(Icons.check, color: Colors.white, size: 18)
          : null,
    );
  }

  Widget _servicesScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _topBar(),
        _stepIndicator(),
        const SizedBox(height: 24),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Selecciona tus Servicios",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Elige los servicios que deseas para tu próxima cita",
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 20),
                // Buscador
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: TextField(
                    controller: _servicioSearchController,
                    focusNode: _servicioFocusNode,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: "¿Qué servicio buscas?",
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _displayedServicios.length + 1,
                    itemBuilder: (context, index) {
                      // Último item: controles de paginación
                      if (index == _displayedServicios.length) {
                        return _buildPaginationControls(
                          currentPage: _currentServicePage,
                          totalPages: _totalServicePages,
                          onPageChange: _changeServicePage,
                        );
                      }
                      
                      final servicio = _displayedServicios[index];
                      final isSelected = serviciosSeleccionados.contains(servicio.servicioId);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isSelected) {
                              serviciosSeleccionados.remove(servicio.servicioId);
                            } else {
                              serviciosSeleccionados.add(servicio.servicioId);
                            }
                          });
                          // Recalcular slots en el siguiente frame después de que setState termine
                          Future.microtask(() {
                            if (selectedEmpleado != null && selectedDate != null && mounted) {
                              _calculateAvailableSlots();
                            }
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected ? const Color(0xFFE54BCF) : Colors.grey.shade200,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isSelected ? const Color(0xFFE54BCF) : Colors.grey.shade400,
                                    width: 2,
                                  ),
                                  color: isSelected ? const Color(0xFFE54BCF) : Colors.white,
                                ),
                                child: isSelected
                                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                                    : null,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      servicio.nombre,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.timer, color: Colors.grey, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          "${servicio.duracion} min",
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                _formatCurrency(servicio.precio),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: Color(0xFF7926F7),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF7926F7), width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: _previousStep,
                          child: const Text(
                            "Atrás",
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF7926F7),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: serviciosSeleccionados.isNotEmpty
                                ? const Color(0xFF7926F7)
                                : Colors.grey.shade300,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          onPressed: serviciosSeleccionados.isNotEmpty ? _nextStep : null,
                          child: const Text(
                            "Continuar",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _professionalScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _topBar(),
        _stepIndicator(),
        const SizedBox(height: 24),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Selecciona a tu Profesional",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Busca al estilista que te atenderá",
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 20),
                // Buscador local
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: TextField(
                    controller: _empleadoSearchController,
                    focusNode: _empleadoFocusNode,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: "Buscar profesional por nombre o documento...",
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _displayedEmpleadosFiltered.length + (_totalEmpleadoFilteredPages > 1 ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Último item: controles de paginación (si hay múltiples páginas)
                      if (index == _displayedEmpleadosFiltered.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: _buildPaginationControls(
                            currentPage: _currentEmpleadoFilteredPage,
                            totalPages: _totalEmpleadoFilteredPages,
                            onPageChange: _changeEmpleadoFilteredPage,
                          ),
                        );
                      }
                      
                      final empleado = _displayedEmpleadosFiltered[index];
                      final isSelected = selectedEmpleado?.documentoEmpleado == empleado.documentoEmpleado;
                      return GestureDetector(
                        onTap: () async {
                          setState(() {
                            selectedEmpleado = empleado;
                          });
                          await _loadEmpleadoHorarios();
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected ? const Color(0xFFE54BCF) : Colors.grey.shade200,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Color(0xFF7926F7),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      empleado.nombre,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      empleado.documentoEmpleado,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle, color: Color(0xFFE54BCF), size: 24),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                if (selectedEmpleado != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE54BCF), width: 2),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 28,
                          backgroundColor: Color(0xFFEAD8FF),
                          child: Icon(Icons.person, color: Color(0xFF7926F7), size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedEmpleado!.nombre,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Documento: ${selectedEmpleado!.documentoEmpleado}",
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.check_circle, color: Color(0xFFE54BCF), size: 28),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    if (currentStep > 0)
                      Expanded(
                        child: SizedBox(
                          height: 56,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Color(0xFF7926F7)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: _previousStep,
                            child: const Text(
                              "Volver a Servicios",
                              style: TextStyle(
                                fontSize: 16,
                                color: Color(0xFF7926F7),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (currentStep > 0) const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: selectedEmpleado != null
                                ? const Color(0xFF7926F7)
                                : Colors.grey.shade300,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          onPressed: selectedEmpleado != null ? _nextStep : null,
                          child: const Text(
                            "Continuar",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _scheduleScreen() {
    final days = List.generate(30, (index) {
      return DateTime.now().add(Duration(days: index));
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _topBar(),
        _stepIndicator(),
        const SizedBox(height: 24),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Selecciona Fecha y Hora",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Disponibilidad para ${selectedEmpleado?.nombre ?? 'el profesional'}",
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 20),
                // Calendario
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE54BCF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.calendar_today,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            DateFormat('MMMM y', 'es_ES').format(selectedDate!).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFE54BCF),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        height: 70,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: days.length,
                          itemBuilder: (context, index) {
                            final day = days[index];
                            final isSelected = selectedDate != null &&
                                selectedDate!.day == day.day &&
                                selectedDate!.month == day.month &&
                                selectedDate!.year == day.year;
                            final worksToday = _doesEmpleadoWorkOnDay(day);
                            
                            return GestureDetector(
                              onTap: worksToday
                                  ? () async {
                                      setState(() {
                                        selectedDate = day;
                                        selectedTime = null;
                                      });
                                      await _loadEmpleadoHorarios();
                                    }
                                  : null,
                              child: Container(
                                width: 60,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: !worksToday
                                      ? Colors.grey.shade100
                                      : (isSelected ? const Color(0xFFE54BCF) : Colors.white),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: !worksToday
                                        ? Colors.grey.shade300
                                        : (isSelected ? const Color(0xFFE54BCF) : Colors.grey.shade200),
                                    width: isSelected && worksToday ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      DateFormat('E', 'es_ES').format(day).substring(0, 2),
                                      style: TextStyle(
                                        color: !worksToday
                                            ? Colors.grey.shade400
                                            : (isSelected ? Colors.white : Colors.grey[600]),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      day.day.toString(),
                                      style: TextStyle(
                                        color: !worksToday
                                            ? Colors.grey.shade400
                                            : (isSelected ? Colors.white : Colors.black87),
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // Horarios
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.access_time, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Text(
                            "Horarios para el ${DateFormat('EEEE, d \'de\' MMMM', 'es_ES').format(selectedDate!)}",
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "Selecciona la hora de tu cita",
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(height: 16),
                      loadingHorarios
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.all(32.0),
                                child: CircularProgressIndicator(),
                              ),
                            )
                          : availableTimeSlots.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(32.0),
                                    child: Column(
                                      children: [
                                        Icon(Icons.event_busy, size: 48, color: Colors.grey[400]),
                                        const SizedBox(height: 16),
                                        Text(
                                          "No hay horarios disponibles para esta fecha",
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: availableTimeSlots.length,
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    mainAxisSpacing: 10,
                                    crossAxisSpacing: 10,
                                    childAspectRatio: 2.2,
                                  ),
                                  itemBuilder: (context, index) {
                                    final slot = availableTimeSlots[index];
                                    final isSelected = selectedTime == slot.time;
                                    
                                    // Colores y estilos según el estado
                                    Color borderColor;
                                    Color bgColor;
                                    Color textColor;
                                    String statusText;
                                    Color statusColor;
                                    
                                    if (slot.isUnavailable) {
                                      borderColor = Colors.grey.shade200;
                                      bgColor = Colors.grey.shade100;
                                      textColor = Colors.grey.shade400;
                                      statusText = "NO DISPONIBLE";
                                      statusColor = Colors.grey.shade400;
                                    } else if (slot.isReserved) {
                                      borderColor = Colors.grey.shade300;
                                      bgColor = Colors.grey.shade50;
                                      textColor = Colors.grey.shade500;
                                      statusText = "RESERVADO";
                                      statusColor = Colors.grey.shade500;
                                    } else {
                                      borderColor = isSelected ? const Color(0xFFE54BCF) : const Color(0xFFD6C7FF);
                                      bgColor = isSelected ? const Color(0xFFE54BCF).withOpacity(0.1) : Colors.white;
                                      textColor = isSelected ? const Color(0xFFE54BCF) : const Color(0xFF7B61FF);
                                      statusText = "LIBRE";
                                      statusColor = const Color(0xFF7B61FF);
                                    }
                                    
                                    return GestureDetector(
                                      onTap: slot.isAvailable
                                          ? () {
                                              setState(() {
                                                selectedTime = slot.time;
                                              });
                                            }
                                          : null,
                                      child: Container(
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(14),
                                          border: Border.all(
                                            color: borderColor,
                                            width: isSelected && slot.isAvailable ? 2 : 1,
                                          ),
                                          color: bgColor,
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              slot.time,
                                              style: TextStyle(
                                                color: textColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              statusText,
                                              style: TextStyle(
                                                color: statusColor,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF7926F7)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _previousStep,
                    child: const Text(
                      "Atrás",
                      style: TextStyle(
                        fontSize: 16,
                        color: Color(0xFF7926F7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: selectedTime != null
                          ? const Color(0xFF7926F7)
                          : Colors.grey.shade300,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    onPressed: selectedTime != null ? _nextStep : null,
                    child: const Text(
                      "Confirmar",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryScreen() {
    final serviciosSeleccionadosList = serviciosDisponibles
        .where((s) => serviciosSeleccionados.contains(s.servicioId))
        .toList();

    final total = serviciosSeleccionadosList.fold(0.0, (sum, s) => sum + s.precio);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _topBar(),
        _stepIndicator(),
        const SizedBox(height: 24),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Resumen de tu Cita",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Revisa los detalles antes de confirmar",
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Servicio(s)",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...serviciosSeleccionadosList.map((s) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("• ${s.nombre}"),
                                Text(
                                  _formatCurrency(s.precio),
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          )),
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Profesional",
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                              Text(selectedEmpleado?.nombre ?? "No seleccionado"),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                "Estilista Profesional",
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Fecha y Hora",
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    DateFormat('EEEE, d \'de\' MMMM \'de\' yyyy', 'es_ES')
                                        .format(selectedDate!),
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  Text(
                                    selectedTime ?? "",
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Total",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                ),
                              ),
                              Text(
                                _formatCurrency(total),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 20,
                                  color: Color(0xFF7926F7),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () {
                      // Retroceder a la pantalla de selección de horario
                      // Calcular el índice correcto según el rol:
                      int scheduleStepIndex = 0;
                      
                      // Paso 1: Cliente (si es asistente o admin)
                      if (isAsistente || isAdmin) {
                        scheduleStepIndex += 1;
                      }
                      
                      // Paso 2: Servicios
                      scheduleStepIndex += 1;
                      
                      // Paso 3: Método de pago
                      scheduleStepIndex += 1;
                      
                      // Paso 4: Profesional (si es admin o cliente)
                      if (!isAsistente) {
                        scheduleStepIndex += 1;
                      }
                      
                      // Ahora scheduleStepIndex es el índice correcto
                      setState(() {
                        currentStep = scheduleStepIndex;
                      });
                      _pageController.animateToPage(
                        currentStep,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: const Text(
                      "Volver a seleccionar horario",
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF7926F7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
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
                    onPressed: _confirmAppointment,
                    child: const Text(
                      "Confirmar Cita",
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _confirmationScreen() {
    final serviciosSeleccionadosList = serviciosDisponibles
        .where((s) => serviciosSeleccionados.contains(s.servicioId))
        .toList();
    final total = serviciosSeleccionadosList.fold(0.0, (sum, s) => sum + s.precio);

    return Column(
      children: [
        _topBar(),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
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
                            Icons.calendar_month,
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
                    const Text(
                      "¡Cita Confirmada!",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "Hemos enviado los detalles a tu correo electrónico",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Color(0xFFEAD8FF),
                              child: Icon(Icons.person, color: Color(0xFF7926F7)),
                            ),
                            title: Text(
                              selectedEmpleado?.nombre ?? "Profesional",
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: const Text("Profesional"),
                          ),
                          const Divider(height: 1),
                          ListTile(
                            leading: const Icon(Icons.calendar_today, color: Color(0xFF7926F7)),
                            title: Text(
                              DateFormat('EEEE, d \'de\' MMMM', 'es_ES').format(selectedDate!),
                              style: const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            subtitle: Text(selectedTime ?? ""),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F3FA),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Total",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatCurrency(total),
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF7926F7),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
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
                          print('========================================');
                          print('👤 USUARIO PRESIONA VER MI CITA');
                          print('========================================');
                          print('Cerrando AppointmentFlowScreen para recarga...');
                          
                          // Solo cerrar el AppointmentFlowScreen
                          // Return appropriate value based on if we're editing or creating new
                          if (widget.agendaToEdit != null) {
                            Navigator.pop(context, 'refresh');
                          } else {
                            Navigator.pop(context, true);
                          }
                        },
                        child: const Text(
                          "Ver mi cita",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _paymentMethodScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _topBar(),
        _stepIndicator(),
        const SizedBox(height: 24),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Método de Pago",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Selecciona cómo deseas pagar",
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: metodosPago.length,
                    itemBuilder: (context, index) {
                      final metodo = metodosPago[index];
                      final isSelected = selectedMetodoPago?.metodopagoId == metodo.metodopagoId;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedMetodoPago = metodo;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 15),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xffFCE8FF) : Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: isSelected ? const Color(0xFFE54BCF) : Colors.grey.shade200,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xffFCE8FF),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.payment,
                                  color: Color(0xFFE54BCF),
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Text(
                                  metodo.nombre,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_circle,
                                  color: Color(0xFFE54BCF),
                                  size: 28,
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF7926F7)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: _previousStep,
                          child: const Text(
                            "Atrás",
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF7926F7),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: selectedMetodoPago != null
                                ? const Color(0xFF7926F7)
                                : Colors.grey.shade300,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          onPressed: selectedMetodoPago != null ? _nextStep : null,
                          child: const Text(
                            "Continuar",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _clienteScreen() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _topBar(),
        _stepIndicator(),
        const SizedBox(height: 24),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Selecciona el Cliente",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Busca y elige el cliente para la cita",
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 20),
                // Buscador local
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: TextField(
                    controller: _clienteSearchController,
                    focusNode: _clienteFocusNode,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: "Buscar cliente por nombre o documento...",
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: _displayedClientesFiltered.length + (_totalClienteFilteredPages > 1 ? 1 : 0),
                    itemBuilder: (context, index) {
                      // Último item: controles de paginación (si hay múltiples páginas)
                      if (index == _displayedClientesFiltered.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: _buildPaginationControls(
                            currentPage: _currentClienteFilteredPage,
                            totalPages: _totalClienteFilteredPages,
                            onPageChange: _changeClienteFilteredPage,
                          ),
                        );
                      }
                      
                      final cliente = _displayedClientesFiltered[index];
                      final isSelected = selectedCliente?.documentoCliente == cliente.documentoCliente;
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            selectedCliente = cliente;
                          });
                        },
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isSelected ? const Color(0xFFE54BCF) : Colors.grey.shade200,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: Colors.purple.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.person,
                                  color: Color(0xFF7926F7),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      cliente.nombre,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      cliente.documentoCliente,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle, color: Color(0xFFE54BCF), size: 24),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
                if (selectedCliente != null)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE54BCF), width: 2),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          radius: 28,
                          backgroundColor: Color(0xFFEAD8FF),
                          child: Icon(Icons.person, color: Color(0xFF7926F7), size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                selectedCliente!.nombre,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Documento: ${selectedCliente!.documentoCliente}",
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.check_circle, color: Color(0xFFE54BCF), size: 28),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF7926F7), width: 2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text(
                            "Atrás",
                            style: TextStyle(
                              fontSize: 16,
                              color: Color(0xFF7926F7),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: selectedCliente != null
                                ? const Color(0xFF7926F7)
                                : Colors.grey.shade300,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          onPressed: selectedCliente != null ? _nextStep : null,
                          child: const Text(
                            "Continuar",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmAppointment() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Convertir hora
      final timeParts = selectedTime!.split(' ');
      final hourMinute = timeParts[0].split(':');
      int hour = int.parse(hourMinute[0]);
      final minute = int.parse(hourMinute[1]);

      if (timeParts[1] == 'PM' && hour != 12) {
        hour += 12;
      } else if (timeParts[1] == 'AM' && hour == 12) {
        hour = 0;
      }

      // Si es cliente, asegurarse que el cliente esté seleccionado
      if (isCliente && selectedCliente == null) {
        final userId = widget.user?["usuarioId"];
        if (userId != null) {
          try {
            selectedCliente = clientes.firstWhere(
              (c) => c.usuarioId == userId,
            );
          } catch (_) {}
        }
      }

      Agenda agendaResultado;

      if (widget.agendaToEdit != null) {
        // Actualizar cita existente
        print('========================================');
        print('🔄 PREPARANDO ACTUALIZACIÓN DE CITA');
        print('========================================');
        print('Agenda ID a actualizar: ${widget.agendaToEdit!.agendaId}');
        print('Documento Cliente: ${selectedCliente!.documentoCliente}');
        print('Documento Empleado: ${selectedEmpleado!.documentoEmpleado}');
        print('Fecha: ${selectedDate!}');
        print('Hora: ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00');
        print('Servicios seleccionados: $serviciosSeleccionados');
        print('Método de pago: ${selectedMetodoPago?.metodopagoId}');
        
        final agenda = Agenda(
          agendaId: widget.agendaToEdit!.agendaId,
          documentoCliente: selectedCliente!.documentoCliente,
          documentoEmpleado: selectedEmpleado!.documentoEmpleado,
          fechaCita: selectedDate!,
          horaInicio: '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00',
          metodopagoId: selectedMetodoPago?.metodopagoId ?? 1,
          servicios: serviciosSeleccionados
              .map((id) => Servicio(
                    servicioId: id,
                    nombre: '',
                    precio: 0,
                    duracion: 0,
                    estado: true,
                  ))
              .toList(),
        );

        print('📤 Enviando PUT request...');
        agendaResultado = await _apiService.updateAgenda(agenda.agendaId!, agenda);
        print('✅ Respuesta recibida del servidor');
        print('Resultado: ${agendaResultado.agendaId}');
      } else {
        // Crear nueva cita
        final agenda = Agenda(
          documentoCliente: selectedCliente!.documentoCliente,
          documentoEmpleado: selectedEmpleado!.documentoEmpleado,
          fechaCita: selectedDate!,
          horaInicio: '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:00',
          metodopagoId: selectedMetodoPago?.metodopagoId ?? 1,
          servicios: serviciosSeleccionados
              .map((id) => Servicio(
                    servicioId: id,
                    nombre: '',
                    precio: 0,
                    duracion: 0,
                    estado: true,
                  ))
              .toList(),
        );

        agendaResultado = await _apiService.createAgenda(agenda);
      }

      if (mounted) {
        print('========================================');
        print('✅ CITA ENVIADA EXITOSAMENTE');
        print('========================================');
        print('Agenda ID resultante: ${agendaResultado.agendaId}');
        
        // Calcular el índice del paso de confirmación
        final steps = _getSteps();
        final confirmationStepIndex = steps.length - 1;
        
        print('Total de pasos: ${steps.length}');
        print('Índice de confirmación esperado: $confirmationStepIndex');
        print('currentStep actual: $currentStep');
        
        // Actualizar currentStep ANTES de animar, para asegurar que sea correcto
        setState(() {
          currentStep = confirmationStepIndex;
          isLoading = false;
        });
        
        // Esperar a que el rebuild termine antes de animar el PageView
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pageController.hasClients) {
            print('📄 Animando PageView a página $confirmationStepIndex');
            try {
              _pageController.animateToPage(
                confirmationStepIndex,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
              );
              print('✅ Animación exitosa');

            } catch (e) {
              print('❌ Error en animateToPage: $e');
              try {
                _pageController.jumpToPage(confirmationStepIndex);
                print('✅ jumpToPage exitoso como fallback');
              } catch (e2) {
                print('❌ Error en jumpToPage: $e2');
              }
            }
          } else {
            print('⚠️ No se pudo animar: mounted=$mounted, hasClients=${_pageController.hasClients}');
          }
        });
      }
    } catch (e, stackTrace) {
      print('========================================');
      print('❌ ERROR EN CONFIRMACIÓN DE CITA');
      print('========================================');
      print('Error: $e');
      print('Stack Trace: $stackTrace');
      print('isLoading: $isLoading');
      if (mounted) {
        final message = widget.agendaToEdit != null 
            ? 'Error al actualizar la cita: $e' 
            : 'Error al crear la cita: $e';
        CustomAlert.showError(context, message);
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F3FA),
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : PageView(
                physics: const NeverScrollableScrollPhysics(),
                controller: _pageController,
                children: _getSteps(),
              ),
      ),
    );
  }
}
