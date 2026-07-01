import 'package:flutter/material.dart';
import 'package:astrhoapp/core/widgets/app_bottom_nav.dart';
import 'package:astrhoapp/core/services/api_service.dart';
import 'package:astrhoapp/agenda/models/agenda.dart';
import 'package:astrhoapp/agenda/screens/appointment_flow_screen.dart';
import 'package:astrhoapp/core/utils/colors.dart';

// ─── COLORS ───────────────────────────────────────────────────────────────────
const kPrimary = Color(0xFF8B2FC9);
const kPrimaryDark = Color(0xFF5E1A8A);
const kAccent = Color(0xFFE91E8C);
const kAccentLight = Color(0xFFF06292);
const kCardBg = Colors.white;
const kBackground = Color(0xFFF5F5F5);
const kTextDark = Color(0xFF1A1A2E);
const kTextGrey = Color(0xFF757575);
const kCategoryBg = Color(0xFFF3E5F5);
const kCategoryText = Color(0xFF8B2FC9);

class ServicesPage extends StatefulWidget {
  final bool showBottomNav;
  final Map<dynamic, dynamic>? user;
  final String? token;
  final Function()? onAppointmentBooked;
  
  const ServicesPage({super.key, this.showBottomNav = true, this.user, this.token, this.onAppointmentBooked});

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  int currentPage = 1;
  int totalPages = 1;
  final int servicesPerPage = 6;

  List<Servicio> displayedServices = [];
  bool isLoading = true;
  String? errorMessage;
  ApiService? apiService;
  Map<dynamic, dynamic>? user;
  String? token;
  
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    user = widget.user;
    token = widget.token ?? user?['token']?.toString();
    apiService = ApiService();
    _loadServicesForPage(1);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      currentPage = 1; // Reset to first page when searching
    });
    _loadServicesForPage(1);
  }

  Future<void> _loadServicesForPage(int page) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final result = await apiService!.getServiciosTodos(
        pagina: page,
        busqueda: _searchQuery.isNotEmpty ? _searchQuery : null,
        pageSize: servicesPerPage,  // Pasar el tamaño de página
      );
      
      if (!mounted) return;

      setState(() {
        displayedServices = (result['servicios'] as List<Servicio>)
            .where((service) => service.estado == true)
            .toList();
        
        totalPages = result['totalPaginas'] as int;
        currentPage = page;
        
        print('📄 Página $currentPage de $totalPages: ${displayedServices.length} servicios mostrados');
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        errorMessage = 'Error al cargar servicios: $e';
        isLoading = false;
      });
      print('❌ Error cargando servicios: $e');
    }
  }

  void _changePage(int newPage) {
    if (newPage != currentPage && newPage >= 1 && newPage <= totalPages) {
      _loadServicesForPage(newPage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      body: Column(
        children: [
          _buildAppBar(),
          Expanded(
            child: _buildBody(),
          ),
          if (widget.showBottomNav) const AppBottomNav(currentRoute: '/services'),
        ],
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const SizedBox(width: 48),
            const Text(
              "AstrhoApp",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.white,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.logout, color: AppColors.white),
              onPressed: _showLogoutDialog,
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cerrar Sesión'),
          content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  '/login',
                  (route) => false,
                );
              },
              child: const Text(
                'Cerrar Sesión',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBody() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          Expanded(
            child: _buildServiceGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nuestros Servicios',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: kTextDark,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Descubre nuestra amplia gama de servicios de belleza profesional',
            style: TextStyle(
              fontSize: 13,
              color: kTextGrey,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          _buildSearchBar(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar servicios...',
          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    _onSearchChanged();
                  },
                  child: Icon(Icons.close, color: Colors.grey[600], size: 20),
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        ),
        style: const TextStyle(fontSize: 14, color: kTextDark),
      ),
    );
  }

  Widget _buildServiceGrid() {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: kPrimary),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadServicesForPage(currentPage),
              style: ElevatedButton.styleFrom(backgroundColor: kPrimary),
              child: const Text('Reintentar', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    if (displayedServices.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.spa_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(_searchQuery.isEmpty 
                ? 'No hay servicios disponibles'
                : 'No se encontraron servicios que coincidan con tu búsqueda'),
          ],
        ),
      );
    }

    print('Mostrando ${displayedServices.length} servicios en la página $currentPage');

    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.62,
              ),
              itemCount: displayedServices.length,
              itemBuilder: (context, index) {
                return ServiceCard(
                  service: displayedServices[index],
                  user: user,
                  token: token,
                  onAppointmentBooked: widget.onAppointmentBooked,
                );
              },
            ),
          ),
          _buildPagination(),
        ],
      ),
    );
  }

  Widget _buildPagination() {
    if (totalPages <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey[200]!, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Información de página
          Text(
            'Página $currentPage de $totalPages',
            style: TextStyle(
              fontSize: 12,
              color: kTextGrey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          // Botones de navegación
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _paginationBtn(
                Icons.first_page,
                currentPage > 1 ? () => _changePage(1) : null,
                'Primera',
              ),
              const SizedBox(width: 8),
              _paginationBtn(
                Icons.chevron_left,
                currentPage > 1 ? () => _changePage(currentPage - 1) : null,
                'Anterior',
              ),
              const SizedBox(width: 12),
              ..._buildPageNumbers(),
              const SizedBox(width: 12),
              _paginationBtn(
                Icons.chevron_right,
                currentPage < totalPages ? () => _changePage(currentPage + 1) : null,
                'Siguiente',
              ),
              const SizedBox(width: 8),
              _paginationBtn(
                Icons.last_page,
                currentPage < totalPages ? () => _changePage(totalPages) : null,
                'Última',
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers() {
    List<Widget> pages = [];
    
    // Mostrar números de página
    int startPage = 1;
    int endPage = totalPages;
    
    // Si hay muchas páginas, mostrar solo las cercanas a la actual
    if (totalPages > 5) {
      startPage = (currentPage - 2).clamp(1, totalPages - 4);
      endPage = (currentPage + 2).clamp(5, totalPages);
    }
    
    // Agregar puntos suspensivos al inicio si es necesario
    if (startPage > 1) {
      pages.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('...', style: TextStyle(color: kTextGrey, fontSize: 12)),
        ),
      );
    }
    
    // Agregar números de página
    for (int i = startPage; i <= endPage; i++) {
      pages.add(const SizedBox(width: 4));
      pages.add(_pageNumber(i, currentPage == i));
      pages.add(const SizedBox(width: 4));
    }
    
    // Agregar puntos suspensivos al final si es necesario
    if (endPage < totalPages) {
      pages.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text('...', style: TextStyle(color: kTextGrey, fontSize: 12)),
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
            color: onTap != null ? kTextGrey : Colors.grey[300],
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
          color: isActive ? kPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: isActive
              ? Border.all(color: kPrimary, width: 2)
              : Border.all(color: Colors.grey[300]!, width: 1),
        ),
        alignment: Alignment.center,
        child: Text(
          '$page',
          style: TextStyle(
            color: isActive ? Colors.white : kTextGrey,
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

// ─── SERVICE CARD ─────────────────────────────────────────────────────────────
class ServiceCard extends StatelessWidget {
  final Servicio service;
  final Map<dynamic, dynamic>? user;
  final String? token;
  final Function()? onAppointmentBooked;

  const ServiceCard({super.key, required this.service, this.user, this.token, this.onAppointmentBooked});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openServiceDetail(context),
      child: Container(
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildImage(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.nombre,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kTextDark,
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    if (service.descripcion != null && service.descripcion!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Text(
                          service.descripcion!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: kTextGrey,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    _buildCategoryChip(),
                    const SizedBox(height: 6),
                    _buildDurationPrice(),
                    const Spacer(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Container(
            height: 110,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _getColorForService(service.nombre),
                  _getColorForService(service.nombre).withValues(alpha: 0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Decorative circles
                Positioned(
                  right: -20,
                  bottom: -20,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ),
                Positioned(
                  left: -10,
                  top: -10,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Center(
                  child: Icon(
                    _getIconForService(service.nombre),
                    size: 42,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Badge
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.content_cut,
              size: 16,
              color: kAccent,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kCategoryBg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'General',
        style: TextStyle(
          fontSize: 10,
          color: kCategoryText,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDurationPrice() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            const Icon(Icons.access_time, size: 12, color: kTextGrey),
            const SizedBox(width: 3),
            Text(
              '${service.duracion} min',
              style: const TextStyle(fontSize: 11, color: kTextGrey),
            ),
          ],
        ),
        Text(
          '\$${service.precio.toInt().toString()}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: kPrimary,
          ),
        ),
      ],
    );
  }

  void _scheduleService(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppointmentFlowScreen(
          user: user,
          token: token,
        ),
      ),
    );

    if ((result == true || result == 'refresh' || result == 'reload') && onAppointmentBooked != null) {
      onAppointmentBooked!();
    }
  }

  void _openServiceDetail(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          service.nombre,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: kPrimary,
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (service.imagen != null && service.imagen!.isNotEmpty)
                Container(
                  width: double.infinity,
                  height: 200,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      colors: [
                        _getColorForService(service.nombre),
                        _getColorForService(service.nombre).withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      _getIconForService(service.nombre),
                      size: 80,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
              if (service.descripcion != null && service.descripcion!.isNotEmpty) ...[
                const Text(
                  'Descripción:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(service.descripcion!, style: const TextStyle(fontSize: 14)),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  const Icon(Icons.access_time, size: 20, color: kPrimary),
                  const SizedBox(width: 8),
                  Text('Duración: ${service.duracion} minutos', style: const TextStyle(fontSize: 14)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.attach_money, size: 20, color: kPrimary),
                  const SizedBox(width: 8),
                  Text('Precio: \$${service.precio.toInt().toString()}', style: const TextStyle(fontSize: 14)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _scheduleService(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Agendar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Color _getColorForService(String serviceName) {
    final name = serviceName.toLowerCase();
    if (name.contains('corte')) return const Color(0xFFAD1457);
    if (name.contains('manicure') || name.contains('pedicure')) return const Color(0xFFC2185B);
    if (name.contains('tintura')) return const Color(0xFF6A1B9A);
    if (name.contains('masaje')) return const Color(0xFF880E4F);
    if (name.contains('limpieza') || name.contains('facial')) return const Color(0xFFAD1457);
    if (name.contains('maquillaje')) return const Color(0xFFE91E8C);
    return const Color(0xFFE91E8C);
  }

  IconData _getIconForService(String serviceName) {
    final name = serviceName.toLowerCase();
    if (name.contains('corte') || name.contains('cabello')) return Icons.content_cut;
    if (name.contains('manicure') || name.contains('uñas')) return Icons.back_hand;
    if (name.contains('facial') || name.contains('limpieza')) return Icons.face;
    if (name.contains('masaje')) return Icons.spa;
    if (name.contains('depilación')) return Icons.healing;
    if (name.contains('maquillaje')) return Icons.brush;
    if (name.contains('cejas')) return Icons.visibility;
    if (name.contains('pedicure')) return Icons.self_improvement;
    if (name.contains('tintura')) return Icons.colorize;
    return Icons.star;
  }
}
