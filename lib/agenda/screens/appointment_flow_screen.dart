import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/agenda.dart';
import 'package:astrhoapp/core/services/api_service.dart';
import 'package:astrhoapp/core/utils/colors.dart';

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

  // Pagination variables
  final int _itemsPerPage = 5;
  int _currentClientePage = 1;
  int _totalClientePages = 1;
  int _currentServicePage = 1;
  int _totalServicePages = 1;
  int _currentEmpleadoPage = 1;
  int _totalEmpleadoPages = 1;

  // Displayed items for pagination
  List<Cliente> _displayedClientes = [];
  List<Servicio> _displayedServicios = [];
  List<Empleado> _displayedEmpleados = [];

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
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      // Cargar datos en paralelo
      final futures = <Future>[];
      futures.add(_apiService.getClientes().then((data) => clientes = data));
      futures.add(_apiService.getEmpleados().then((data) => empleados = data));
      // Load ALL services from all pages (API has 5 records per page)
      futures.add(_loadAllServicios());
      futures.add(_apiService.getMetodosPago().then((data) => metodosPago = data));

      await Future.wait(futures);
      
      print('========================================');
      print('SERVICIOS DISPONIBLES CARGADOS:');
      for (int i = 0; i < serviciosDisponibles.length; i++) {
        final s = serviciosDisponibles[i];
        print('  - Servicio $i: ID=${s.servicioId}, Nombre=${s.nombre}, Duracion=${s.duracion}');
      }
      print('========================================');

      // Initialize pagination
      _updatePaginationForClientes();
      _updatePaginationForServicios();
      _updatePaginationForEmpleados();

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

      serviciosDisponibles = allServicios;
      print('Total servicios cargados de todas las páginas: ${serviciosDisponibles.length}');
    } catch (e) {
      print('Error cargando todos los servicios: $e');
      serviciosDisponibles = [];
    }
  }

  // Pagination helper methods
  void _updatePaginationForClientes() {
    _totalClientePages = (clientes.length / _itemsPerPage).ceil();
    if (_totalClientePages == 0) _totalClientePages = 1;
    _currentClientePage = 1;
    _updateDisplayedClientes();
  }

  void _updatePaginationForServicios() {
    _totalServicePages = (serviciosDisponibles.length / _itemsPerPage).ceil();
    if (_totalServicePages == 0) _totalServicePages = 1;
    _currentServicePage = 1;
    _updateDisplayedServicios();
  }

  void _updatePaginationForEmpleados() {
    _totalEmpleadoPages = (empleados.length / _itemsPerPage).ceil();
    if (_totalEmpleadoPages == 0) _totalEmpleadoPages = 1;
    _currentEmpleadoPage = 1;
    _updateDisplayedEmpleados();
  }

  void _updateDisplayedClientes() {
    final start = (_currentClientePage - 1) * _itemsPerPage;
    final end = (start + _itemsPerPage).clamp(0, clientes.length);
    _displayedClientes = clientes.sublist(start, end);
  }

  void _updateDisplayedServicios() {
    final start = (_currentServicePage - 1) * _itemsPerPage;
    final end = (start + _itemsPerPage).clamp(0, serviciosDisponibles.length);
    _displayedServicios = serviciosDisponibles.sublist(start, end);
  }

  void _updateDisplayedEmpleados() {
    final start = (_currentEmpleadoPage - 1) * _itemsPerPage;
    final end = (start + _itemsPerPage).clamp(0, empleados.length);
    _displayedEmpleados = empleados.sublist(start, end);
  }

  void _changeClientePage(int newPage) {
    if (newPage != _currentClientePage && newPage >= 1 && newPage <= _totalClientePages) {
      setState(() {
        _currentClientePage = newPage;
        _updateDisplayedClientes();
      });
    }
  }

  void _changeServicePage(int newPage) {
    if (newPage != _currentServicePage && newPage >= 1 && newPage <= _totalServicePages) {
      setState(() {
        _currentServicePage = newPage;
        _updateDisplayedServicios();
      });
    }
  }

  void _changeEmpleadoPage(int newPage) {
    if (newPage != _currentEmpleadoPage && newPage >= 1 && newPage <= _totalEmpleadoPages) {
      setState(() {
        _currentEmpleadoPage = newPage;
        _updateDisplayedEmpleados();
      });
    }
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
    if (selectedEmpleado == null || selectedDate == null) return;

    print('========================================');
    print('CARGANDO DATOS DEL EMPLEADO');
    print('========================================');
    print('Empleado: ${selectedEmpleado?.nombre}');
    print('Documento: ${selectedEmpleado?.documentoEmpleado}');
    print('Fecha: ${DateFormat('yyyy-MM-dd').format(selectedDate!)}');

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
          }));
      
      // Cargar HORAS DISPONIBLES desde la API
      futures.add(_apiService.getHorasDisponibles(
          selectedEmpleado!.documentoEmpleado, selectedDate!)
          .then((horas) {
            print('✅ Horas disponibles desde API: $horas');
            horasDisponiblesApi = horas;
          }));
      
      // Cargar TODAS las citas y filtrarlas manualmente (para calcular rangos)
      futures.add(_apiService.getAgendas().then((todasLasCitas) {
        print('✅ Todas las citas cargadas: ${todasLasCitas.length}');
        
        final fechaStr = DateFormat('yyyy-MM-dd').format(selectedDate!);
        final citasFiltradas = todasLasCitas.where((cita) {
          final matchEmpleado = cita.documentoEmpleado == selectedEmpleado!.documentoEmpleado;
          final citaFechaStr = DateFormat('yyyy-MM-dd').format(cita.fechaCita);
          final matchFecha = citaFechaStr == fechaStr;
          print('  - Evaluando cita ID=${cita.agendaId}: Empleado=${cita.documentoEmpleado} vs ${selectedEmpleado!.documentoEmpleado} (match=$matchEmpleado), Fecha=${citaFechaStr} vs ${fechaStr} (match=$matchFecha)');
          return matchEmpleado && matchFecha;
        }).toList();
        
        print('✅ Citas filtradas para empleado y fecha: ${citasFiltradas.length}');
        for (int i = 0; i < citasFiltradas.length; i++) {
          final cita = citasFiltradas[i];
          print('  - Cita ${i+1}: ID=${cita.agendaId}, Hora=${cita.horaInicio}, Estado=${cita.nombreEstado}, Empleado=${cita.documentoEmpleado}, Fecha=${cita.fechaCita}');
        }
        
        citasEmpleadoFecha = citasFiltradas;
      }));

      await Future.wait(futures);
      print('✅ Todos los datos cargados, calculando slots...');
      _calculateAvailableSlots();
    } catch (e) {
      print("❌ Error cargando horarios del empleado: $e");
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

  // Obtener la duración total en minutos de los servicios seleccionados
  int _getTotalDurationMinutes() {
    int total = 0;
    for (final servicio in serviciosDisponibles) {
      if (serviciosSeleccionados.contains(servicio.servicioId)) {
        total += servicio.duracion;
      }
    }
    // Si no hay servicios seleccionados, usar 30 minutos por defecto
    return total > 0 ? total : 30;
  }

  // Calcular horarios disponibles (RESTRICCIÓN MANUAL 100% PRIORITARIA)
  void _calculateAvailableSlots() {
    print('========================================');
    print('INICIANDO CÁLCULO DE HORARIOS (RESTRICCIÓN MANUAL)');
    print('========================================');
    
    // 0. VERIFICAR TODOS LOS DATOS QUE TENEMOS
    print('--- DATOS DISPONIBLES ---');
    print('selectedEmpleado: ${selectedEmpleado?.nombre}');
    print('Documento: ${selectedEmpleado?.documentoEmpleado}');
    print('selectedDate: ${selectedDate != null ? DateFormat('yyyy-MM-dd').format(selectedDate!) : 'null'}');
    print('citasEmpleadoFecha: ${citasEmpleadoFecha.length} citas');
    for (int i = 0; i < citasEmpleadoFecha.length; i++) {
      final c = citasEmpleadoFecha[i];
      print('  - Cita $i: ID=${c.agendaId}, Hora=${c.horaInicio}, Estado=${c.nombreEstado}, Fecha=${c.fechaCita}');
    }
    
    // Datos básicos
    final selectedDateStr = selectedDate != null ? DateFormat('yyyy-MM-dd').format(selectedDate!) : '';
    print('Fecha seleccionada: $selectedDateStr');
    
    // Obtener el día de la semana
    final daysOfWeek = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
    final selectedDayName = selectedDate != null ? daysOfWeek[selectedDate!.weekday - 1].toLowerCase() : '';
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
    
    // 4. Generar y evaluar todos los slots (100% MANUAL, SIN DEPENDER DE LA API)
    final slots = <TimeSlot>[];
    final ahora = DateTime.now();
    var horaActual = horarioInicio;
    
    print('--- EVALUANDO SLOTS (100% MANUAL) ---');
    
    while (horaActual.isBefore(horarioFin)) {
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
      final slotFin30 = slotInicio.add(const Duration(minutes: 30));
      
      TimeSlotStatus estado = TimeSlotStatus.available;
      String motivo = '';
      
      print('  - Evaluando slot: $slotHoraStr ($slotHora24h / $slotHora24hSinSegundos)');
      
      // 1. VERIFICAR SI LA HORA YA PASÓ (PRIORIDAD 1)
      if (slotInicio.isBefore(ahora)) {
        estado = TimeSlotStatus.unavailable;
        motivo = 'hora pasada';
      }
      // 2. VERIFICAR SI ESTÁ EN LA LISTA DE HORAS DISPONIBLES DE LA API (PRIORIDAD 2)
      else if (horasDisponiblesApi.contains(slotHora24h) || horasDisponiblesApi.contains(slotHora24hSinSegundos)) {
        // 3. Ahora chequear si se solapa con alguna cita existente (PRIORIDAD 3 - sobreescribe la disponibilidad)
        if (rangosCitasExistentes.any((rango) {
          print('🔍 Evaluando solapamiento: slot $slotHoraStr ($slotInicio - $slotFin30) vs rango ${_formatTime12Hour(rango.start)} - ${_formatTime12Hour(rango.end)}');
          
          final solapa = slotInicio.isBefore(rango.end) && slotFin30.isAfter(rango.start);
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
      // 4. SI NO ESTÁ EN LA API, ESTÁ RESERVADO
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
    print('  - Disponibles: ${slots.where((s) => s.isAvailable).length}');
    print('  - Reservados: ${slots.where((s) => s.isReserved).length}');
    print('  - No disponibles: ${slots.where((s) => s.isUnavailable).length}');
    print('========================================');
    
    setState(() {});
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

  // Generar horarios por defecto (solo para compatibilidad)
  @Deprecated('Usar _calculateAvailableSlots en su lugar')
  List<String> _generateDefaultSlots() {
    final slots = <String>[];
    var currentTime = DateTime(2000, 1, 1, 9, 0); // 9:00 AM
    final endTime = DateTime(2000, 1, 1, 18, 0); // 6:00 PM

    while (currentTime.isBefore(endTime)) {
      slots.add(_formatTime12Hour(currentTime));
      currentTime = currentTime.add(const Duration(minutes: 30));
    }
    return slots;
  }

  @override
  void dispose() {
    _pageController.dispose();
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
    const stepLabels = ["Servicios", "Profesional", "Confirmación"];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: List.generate(3, (index) {
          return Expanded(
            child: Column(
              children: [
                Row(
                  children: [
                    if (index > 0)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: index <= currentStep
                              ? const Color(0xFFE54BCF)
                              : Colors.grey.shade300,
                        ),
                      ),
                    _stepCircle(index),
                    if (index < 2)
                      Expanded(
                        child: Container(
                          height: 2,
                          color: index < currentStep
                              ? const Color(0xFFE54BCF)
                              : Colors.grey.shade300,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  stepLabels[index],
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: index <= currentStep
                        ? const Color(0xFFE54BCF)
                        : Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _stepCircle(int index) {
    bool active = index <= currentStep;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: active ? const Color(0xFFE54BCF) : Colors.grey.shade300,
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
                  child: const TextField(
                    decoration: InputDecoration(
                      hintText: "¿Qué servicio buscas?",
                      hintStyle: TextStyle(color: Colors.grey),
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _displayedServicios.length,
                          itemBuilder: (context, index) {
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
                        _buildPaginationControls(
                          currentPage: _currentServicePage,
                          totalPages: _totalServicePages,
                          onPageChange: _changeServicePage,
                        ),
                      ],
                    ),
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
                  "Elige al estilista que te atenderá",
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
                  child: const TextField(
                    decoration: InputDecoration(
                      hintText: "Buscar por nombre o especialidad...",
                      hintStyle: TextStyle(color: Colors.grey),
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _displayedEmpleados.length,
                          itemBuilder: (context, index) {
                            final empleado = _displayedEmpleados[index];
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
                                            empleado.nombre,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            "Estilista Profesional",
                                            style: TextStyle(
                                              color: Colors.grey[600],
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFE54BCF),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.check, color: Colors.white, size: 16),
                                      )
                                    else
                                      Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 18),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        _buildPaginationControls(
                          currentPage: _currentEmpleadoPage,
                          totalPages: _totalEmpleadoPages,
                          onPageChange: _changeEmpleadoPage,
                        ),
                      ],
                    ),
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
                          Navigator.pop(context, true);
                        },
                        child: const Text(
                          "Ver mis citas",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        Navigator.popUntil(context, (route) => route.isFirst);
                      },
                      child: Text(
                        "Ir al inicio",
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
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
                  "Elige el cliente para la cita",
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
                  child: const TextField(
                    decoration: InputDecoration(
                      hintText: "Buscar cliente...",
                      hintStyle: TextStyle(color: Colors.grey),
                      prefixIcon: Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _displayedClientes.length,
                          itemBuilder: (context, index) {
                            final cliente = _displayedClientes[index];
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
                                            cliente.nombre,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          if (cliente.email != null)
                                            Text(
                                              cliente.email!,
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                          if (cliente.telefono != null)
                                            Text(
                                              cliente.telefono!,
                                              style: TextStyle(
                                                color: Colors.grey[600],
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    if (isSelected)
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFE54BCF),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.check, color: Colors.white, size: 16),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        _buildPaginationControls(
                          currentPage: _currentClientePage,
                          totalPages: _totalClientePages,
                          onPageChange: _changeClientePage,
                        ),
                      ],
                    ),
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

        agendaResultado = await _apiService.updateAgenda(agenda.agendaId!, agenda);
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
        Navigator.pop(context, agendaResultado);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.agendaToEdit != null 
                ? 'Error al actualizar la cita: $e' 
                : 'Error al crear la cita: $e'),
            backgroundColor: Colors.red,
          ),
        );
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
