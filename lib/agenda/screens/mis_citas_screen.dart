import 'package:flutter/material.dart';
import '../models/agenda.dart';
import 'package:astrhoapp/core/services/api_service.dart';
import 'package:astrhoapp/core/utils/colors.dart';
import 'package:astrhoapp/shared/widgets/app_header.dart';
import 'package:astrhoapp/agenda/widgets/appointment_card.dart';
import 'agenda_form_screen.dart';
import 'agenda_detail_screen.dart';

class MisCitasScreen extends StatefulWidget {
  const MisCitasScreen({super.key});

  @override
  State<MisCitasScreen> createState() => _MisCitasScreenState();
}

class _MisCitasScreenState extends State<MisCitasScreen> {
  ApiService? _apiService;
  List<Agenda> _activeAgendas = [];
  List<Agenda> _historyAgendas = [];
  bool _isLoading = true;
  String _selectedTab = 'Activas';
  int _activeCount = 0;
  int _historyCount = 0;
  DateTime? _selectedDate;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Map<dynamic, dynamic>? user;

  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args != null && args is Map) {
        user = args;
        final token = user!['token']?.toString();
        _apiService = ApiService(token: token);
      } else {
        _apiService = ApiService();
      }
      _loadAgendas();
      _isInitialized = true;
    }
  }

  // ... (rest of existing methods, need to be careful with positioning) ...

  Widget _buildDrawer(BuildContext context) {
    print("User Data in Drawer: $user");
    final rol = user != null ? user!["rol"]?.toString().toLowerCase() : "";

    return Drawer(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF7926F7), Color(0xFFF63D77)],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(Icons.calendar_month, color: Colors.white),
                    SizedBox(width: 10),
                    Text(
                      "AstrhoApp\nGestión de Citas",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
          _drawerItem(
            icon: Icons.dashboard,
            text: "Principal",
            onTap: () {
              // Redirigir según el rol
              if (rol == 'administrador' || 
                  rol == 'super admin' || 
                  rol == 'superadmin' || 
                  rol == 'super administrador') {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/admin',
                  (route) => false,
                  arguments: user,
                );
              } else if (rol == 'asistente') {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/assistant',
                  (route) => false,
                  arguments: user,
                );
              } else if (rol == 'cliente') {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/home',
                  (route) => false,
                  arguments: user,
                );
              } else {
                // Fallback
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/home',
                  (route) => false,
                  arguments: user,
                );
              }
            },
          ),
          _drawerItem(
            icon: Icons.calendar_month,
            text: "Gestión de Citas",
            selected: true,
            onTap: () => Navigator.pop(context),
          ),
          const Spacer(),
          _drawerItem(
            icon: Icons.logout,
            text: "Cerrar sesión",
            color: Colors.red,
            onTap: () {
              Navigator.pushReplacementNamed(context, '/');
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _drawerItem({
    required IconData icon,
    required String text,
    VoidCallback? onTap,
    bool selected = false,
    Color? color,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: selected ? Colors.purple.shade50 : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Icon(icon, color: color ?? Color(0xFF7926F7)),
        title: Text(
          text,
          style: TextStyle(
            color: color ?? Colors.black87,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  Future<void> _loadAgendas() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final rol = user != null ? user!["rol"]?.toString().toLowerCase() : "";
      final agendas = rol == 'cliente'
          ? await _apiService!.getMisCitas()
          : await _apiService!.getAgendas();

      if (mounted) {
        setState(() {
          _activeAgendas = agendas.where((a) {
            final estado = a.nombreEstado?.toLowerCase() ?? '';
            return estado.contains('pendiente') ||
                estado.contains('confirmado') ||
                estado.contains('confirmada');
          }).toList();
          _historyAgendas = agendas.where((a) {
            final estado = a.nombreEstado?.toLowerCase() ?? '';
            return !estado.contains('pendiente') &&
                !estado.contains('confirmado') &&
                !estado.contains('confirmada');
          }).toList();
          _activeCount = _activeAgendas.length;
          _historyCount = _historyAgendas.length;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _activeAgendas = [];
          _historyAgendas = [];
          _activeCount = 0;
          _historyCount = 0;
        });
        
        String errorMessage = e.toString();
        if (errorMessage.contains('Exception:')) {
          errorMessage = errorMessage.split('Exception:').last.trim();
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $errorMessage'),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Reintentar',
              textColor: Colors.white,
              onPressed: _loadAgendas,
            ),
          ),
        );
      }
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('es', 'ES'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primaryPurple,
              onPrimary: Colors.white,
              onSurface: AppColors.textDark,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryPurple,
              ),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _clearDateFilter() {
    setState(() {
      _selectedDate = null;
    });
  }

  void _navigateToForm({Agenda? agenda}) async {
    final token = user?['token']?.toString();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AgendaFormScreen(agenda: agenda, token: token, user: user),
      ),
    );

    if (result == true) {
      _loadAgendas();
    }
  }

  void _navigateToDetail(Agenda agenda) {
    final token = user?['token']?.toString();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AgendaDetailScreen(agenda: agenda, token: token, user: user),
      ),
    );
  }

  List<Agenda> get _currentAgendas {
    final list = _selectedTab == 'Activas' ? _activeAgendas : _historyAgendas;

    if (_selectedDate == null) {
      return list;
    }

    return list.where((agenda) {
      // Comparar solo la parte de la fecha (año, mes, día)
      return agenda.fechaCita.year == _selectedDate!.year &&
          agenda.fechaCita.month == _selectedDate!.month &&
          agenda.fechaCita.day == _selectedDate!.day;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(context),
      body: Container(
        decoration: BoxDecoration(gradient: AppColors.primaryGradient),
        child: SafeArea(
          child: Column(
            children: [
              AppHeader(
                title: 'Mis Citas',
                onMenuPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
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
                  child: Column(
                    children: [
                      // Tarjeta principal con título y botón agregar
                      Container(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Administrar Citas',
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textDark,
                                      ),
                                    ),
                                    SizedBox(height: 4),
                                    Text(
                                      'Gestiona las citas de tus clientes',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textGray,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                FloatingActionButton(
                                  heroTag: 'btnSearch',
                                  onPressed: _selectDate,
                                  backgroundColor: AppColors.white,
                                  elevation: 2,
                                  mini: true,
                                  child: const Icon(
                                    Icons.search,
                                    color: AppColors.primaryPurple,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FloatingActionButton(
                                  heroTag: 'btnAdd',
                                  onPressed: () => _navigateToForm(),
                                  backgroundColor: AppColors.primaryPink,
                                  mini: true,
                                  child: const Icon(
                                    Icons.add,
                                    color: AppColors.white,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),
                            // Tabs
                            Row(
                              children: [
                                Expanded(
                                  child: _buildTab(
                                    'Activas',
                                    _activeCount,
                                    _selectedTab == 'Activas',
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildTab(
                                    'Historial',
                                    _historyCount,
                                    _selectedTab == 'Historial',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Filtro de fecha
                      if (_selectedDate != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.lightPurple.withOpacity(
                                      0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: AppColors.primaryPurple
                                          .withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today,
                                        size: 16,
                                        color: AppColors.primaryPurple,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Filtrado por: ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                                        style: const TextStyle(
                                          color: AppColors.primaryPurple,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: _clearDateFilter,
                                icon: const Icon(Icons.close),
                                color: Colors.grey,
                                tooltip: 'Borrar filtro',
                              ),
                            ],
                          ),
                        ),
                      // Lista de citas
                      Expanded(
                        child: _isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : _currentAgendas.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.calendar_today_outlined,
                                      size: 64,
                                      color: AppColors.textGray.withOpacity(
                                        0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No hay citas ${_selectedTab.toLowerCase()}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: AppColors.textGray,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _loadAgendas,
                                child: ListView.builder(
                                  padding: const EdgeInsets.only(bottom: 20),
                                  itemCount: _currentAgendas.length,
                                  itemBuilder: (context, index) {
                                    final agenda = _currentAgendas[index];
                                    return AppointmentCard(
                                      agenda: agenda,
                                      onView: () => _navigateToDetail(agenda),
                                      onEdit: _selectedTab == 'Activas'
                                          ? () =>
                                                _navigateToForm(agenda: agenda)
                                          : null,
                                    );
                                  },
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
              // Footer
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: const Text(
                  '© 2025 Todos los derechos reservados',
                  style: TextStyle(color: AppColors.white, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTab(String label, int count, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.lightPurple.withOpacity(0.2)
              : AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryPurple : Colors.transparent,
            width: 1,
          ),
        ),
        child: Center(
          child: Text(
            '$label ($count)',
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected ? AppColors.primaryPurple : AppColors.textGray,
            ),
          ),
        ),
      ),
    );
  }
}
