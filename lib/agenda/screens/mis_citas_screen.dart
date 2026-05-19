import 'package:flutter/material.dart';
import '../models/agenda.dart';
import 'package:astrhoapp/core/services/api_service.dart';
import 'package:astrhoapp/core/utils/colors.dart';
import 'package:astrhoapp/core/widgets/app_bottom_nav.dart';
import 'appointment_flow_screen.dart';
import 'agenda_detail_screen.dart';
import 'package:intl/intl.dart';

class MisCitasScreen extends StatefulWidget {
  final Map<dynamic, dynamic>? user;
  final String? token;
  final bool showBackButton;
  final bool showBottomNav;

  const MisCitasScreen({
    super.key, 
    this.user, 
    this.token, 
    this.showBackButton = false,
    this.showBottomNav = true,
  });

  @override
  State<MisCitasScreen> createState() => _MisCitasScreenState();
}

class _MisCitasScreenState extends State<MisCitasScreen> {
  ApiService? _apiService;
  List<Agenda> _activeAgendas = [];
  List<Agenda> _historyAgendas = [];
  bool _isLoading = true;
  String _selectedTab = 'Próximas';
  int _activeCount = 0;
  int _historyCount = 0;
  Map<dynamic, dynamic>? user;

  @override
  void initState() {
    super.initState();
    user = widget.user;
    final token = widget.token ?? user?['token']?.toString();
    _apiService = ApiService(token: token);
    _loadAgendas();
  }

  Widget _topBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(gradient: AppColors.primaryGradient),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.white),
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/home');
              },
            ),
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

  Widget _buildTabs() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedTab = 'Próximas';
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _selectedTab == 'Próximas'
                    ? const Color(0xFF7926F7)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  'Próximas ($_activeCount)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _selectedTab == 'Próximas'
                        ? Colors.white
                        : Colors.grey[600],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () {
              setState(() {
                _selectedTab = 'Historial';
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _selectedTab == 'Historial'
                    ? const Color(0xFF7926F7)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text(
                  'Historial ($_historyCount)',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _selectedTab == 'Historial'
                        ? Colors.white
                        : Colors.grey[600],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAppointmentCard(Agenda agenda) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 60,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEAD8FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Text(
                      'MAY',
                      style: TextStyle(
                        color: Color(0xFF7926F7),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      agenda.fechaCita.day.toString(),
                      style: TextStyle(
                        color: Colors.black87,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateFormat('EEEE, d \'de\' MMMM', 'es_ES').format(agenda.fechaCita),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAD8FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            agenda.horaInicio.substring(0, 5),
                            style: const TextStyle(
                              color: Color(0xFF7926F7),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFCE8FF),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Próxima cita',
                            style: const TextStyle(
                              color: Color(0xFFE54BCF),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: Color(0xFFEAD8FF),
                child: Icon(Icons.person, color: Color(0xFF7926F7), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      agenda.nombreEmpleado ?? 'Profesional',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      'Estilista Profesional',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (agenda.servicios != null && agenda.servicios!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 52),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Servicios',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  ...agenda.servicios!.map((s) => Text(
                        '• ${s.nombre}',
                        style: const TextStyle(
                          fontSize: 13,
                        ),
                      )),
                ],
              ),
            ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                ),
              ),
              Text(
                _formatCurrency(_calculateTotal(agenda)),
                style: const TextStyle(
                  color: Color(0xFF7926F7),
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF7926F7)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                _navigateToDetail(agenda);
              },
              child: const Text(
                'Ver detalles',
                style: TextStyle(
                  color: Color(0xFF7926F7),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateTotal(Agenda agenda) {
    if (agenda.servicios == null || agenda.servicios!.isEmpty) {
      return 0;
    }
    return agenda.servicios!.fold(0.0, (sum, s) => sum + s.precio);
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );
    return formatter.format(amount);
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

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  void _navigateToForm() async {
    final token = user?['token']?.toString();
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AppointmentFlowScreen(token: token, user: user),
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
    return _selectedTab == 'Próximas' ? _activeAgendas : _historyAgendas;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F3FA),
      body: Column(
        children: [
          _topBar(),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(top: 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mis Citas',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 20),
                        _buildTabs(),
                      ],
                    ),
                  ),
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
                                      color: Colors.grey.withValues(alpha: 0.5),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No hay citas ${_selectedTab.toLowerCase()}',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : RefreshIndicator(
                                onRefresh: _loadAgendas,
                                child: ListView.builder(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                  itemCount: _currentAgendas.length,
                                  itemBuilder: (context, index) {
                                    final agenda = _currentAgendas[index];
                                    return _buildAppointmentCard(agenda);
                                  },
                                ),
                              ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToForm,
        backgroundColor: const Color(0xFF7926F7),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      bottomNavigationBar: widget.showBottomNav ? AppBottomNav(
        currentRoute: '/mis-citas',
        user: user,
      ) : null,
    );
  }
}
