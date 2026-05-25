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
  List<Agenda> _displayedActiveAgendas = [];
  List<Agenda> _displayedHistoryAgendas = [];
  bool _isLoading = true;
  String _selectedTab = 'Próximas';
  int _activeCount = 0;
  int _historyCount = 0;
  int _currentActivePage = 1;
  int _totalActivePages = 1;
  int _currentHistoryPage = 1;
  int _totalHistoryPages = 1;
  final int _citasPerPage = 5;
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
            const SizedBox(width: 48),
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
        final activeList = agendas.where((a) {
          final estado = a.nombreEstado?.toLowerCase() ?? '';
          return estado.contains('pendiente') ||
              estado.contains('confirmado') ||
              estado.contains('confirmada');
        }).toList();
        
        final historyList = agendas.where((a) {
          final estado = a.nombreEstado?.toLowerCase() ?? '';
          return !estado.contains('pendiente') &&
              !estado.contains('confirmado') &&
              !estado.contains('confirmada');
        }).toList();

        setState(() {
          _activeAgendas = activeList;
          _historyAgendas = historyList;
          _activeCount = _activeAgendas.length;
          _historyCount = _historyAgendas.length;
          
          // Calculate total pages
          _totalActivePages = (_activeAgendas.length / _citasPerPage).ceil();
          _totalHistoryPages = (_historyAgendas.length / _citasPerPage).ceil();
          
          // Ensure pages are at least 1
          if (_totalActivePages == 0) _totalActivePages = 1;
          if (_totalHistoryPages == 0) _totalHistoryPages = 1;
          
          // Reset to first page
          _currentActivePage = 1;
          _currentHistoryPage = 1;
          
          _updateDisplayedAgendas();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _activeAgendas = [];
          _historyAgendas = [];
          _displayedActiveAgendas = [];
          _displayedHistoryAgendas = [];
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

  void _updateDisplayedAgendas() {
    // Update active agendas for current page
    final activeStart = (_currentActivePage - 1) * _citasPerPage;
    final activeEnd = (activeStart + _citasPerPage).clamp(0, _activeAgendas.length);
    _displayedActiveAgendas = _activeAgendas.sublist(activeStart, activeEnd);
    
    // Update history agendas for current page
    final historyStart = (_currentHistoryPage - 1) * _citasPerPage;
    final historyEnd = (historyStart + _citasPerPage).clamp(0, _historyAgendas.length);
    _displayedHistoryAgendas = _historyAgendas.sublist(historyStart, historyEnd);
  }

  void _changeActivePage(int newPage) {
    if (newPage != _currentActivePage && newPage >= 1 && newPage <= _totalActivePages) {
      setState(() {
        _currentActivePage = newPage;
        _updateDisplayedAgendas();
      });
    }
  }

  void _changeHistoryPage(int newPage) {
    if (newPage != _currentHistoryPage && newPage >= 1 && newPage <= _totalHistoryPages) {
      setState(() {
        _currentHistoryPage = newPage;
        _updateDisplayedAgendas();
      });
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
    return _selectedTab == 'Próximas' ? _displayedActiveAgendas : _displayedHistoryAgendas;
  }

  int get _currentPage {
    return _selectedTab == 'Próximas' ? _currentActivePage : _currentHistoryPage;
  }

  int get _totalPages {
    return _selectedTab == 'Próximas' ? _totalActivePages : _totalHistoryPages;
  }

  void _changePage(int newPage) {
    if (_selectedTab == 'Próximas') {
      _changeActivePage(newPage);
    } else {
      _changeHistoryPage(newPage);
    }
  }

  Widget _buildPaginationControls() {
    if (_totalPages <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: Column(
        children: [
          Text(
            'Página $_currentPage de $_totalPages',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _paginationBtn(
                Icons.chevron_left,
                _currentPage > 1 ? () => _changePage(_currentPage - 1) : null,
                'Anterior',
              ),
              const SizedBox(width: 12),
              ..._buildPageNumbers(),
              const SizedBox(width: 12),
              _paginationBtn(
                Icons.chevron_right,
                _currentPage < _totalPages ? () => _changePage(_currentPage + 1) : null,
                'Siguiente',
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers() {
    List<Widget> pages = [];
    
    int startPage = 1;
    int endPage = _totalPages;
    
    // Show only 2 pages at a time to avoid hiding pagination buttons
    if (_totalPages > 2) {
      startPage = (_currentPage - 1).clamp(1, _totalPages - 1);
      endPage = (startPage + 1).clamp(1, _totalPages);
    }
    
    if (startPage > 1) {
      pages.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('...', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ),
      );
    }
    
    for (int i = startPage; i <= endPage; i++) {
      pages.add(const SizedBox(width: 4));
      pages.add(_pageNumber(i, _currentPage == i));
      pages.add(const SizedBox(width: 4));
    }
    
    if (endPage < _totalPages) {
      pages.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('...', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        ),
      );
    }
    
    return pages;
  }

  Widget _paginationBtn(IconData icon, VoidCallback? onTap, String tooltip) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: onTap != null ? Colors.grey[100] : Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: onTap != null ? Colors.grey[300]! : Colors.grey[200]!,
              width: 1,
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 18,
            color: onTap != null ? Colors.grey[600] : Colors.grey[300],
          ),
        ),
      ),
    );
  }

  Widget _pageNumber(int page, bool isActive) {
    return GestureDetector(
      onTap: () => _changePage(page),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF7926F7) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
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
            fontSize: 14,
          ),
        ),
      ),
    );
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
                            : SingleChildScrollView(
                                child: Column(
                                  children: [
                                    RefreshIndicator(
                                      onRefresh: _loadAgendas,
                                      child: ListView.builder(
                                        physics: const NeverScrollableScrollPhysics(),
                                        shrinkWrap: true,
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
                                    _buildPaginationControls(),
                                  ],
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
