import 'package:flutter/material.dart';
import 'package:astrhoapp/core/widgets/app_bottom_nav.dart';
import 'package:astrhoapp/core/services/api_service.dart';
import 'package:astrhoapp/agenda/models/agenda.dart';

class ServicesPage extends StatefulWidget {
  final bool showBottomNav;
  
  const ServicesPage({super.key, this.showBottomNav = true});

  @override
  State<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends State<ServicesPage> {
  int currentPage = 1;
  int totalPages = 1;
  final int servicesPerPage = 5;

  List<Servicio> displayedServices = [];
  List<Servicio> allServices = [];
  bool isLoading = true;
  String? errorMessage;
  ApiService? apiService;
  
  final TextEditingController _searchController = TextEditingController();
  String _currentSearch = '';
  int totalServicios = 0;
  int calculatedTotalPages = 1;

  @override
  void initState() {
    super.initState();
    apiService = ApiService();
    _loadServices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadServices({String? busqueda}) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final result = await apiService!.getServicios(
        pagina: currentPage,
        busqueda: busqueda,
      );
      
      setState(() {
        allServices = result['servicios'] as List<Servicio>;
        displayedServices = allServices
            .where((service) => service.estado)
            .toList();
        totalPages = result['totalPaginas'] as int;
        calculatedTotalPages = totalPages;
        totalServicios = result['totalServicios'] as int;
        isLoading = false;
      });
      
      _updateDisplayedServices();
    } catch (e) {
      setState(() {
        errorMessage = 'Error al cargar servicios: $e';
        isLoading = false;
      });
    }
  }

  void _updateDisplayedServices() {
    setState(() {
      displayedServices = allServices
          .where((service) => service.estado)
          .where((service) => _currentSearch.isEmpty || 
              service.nombre.toLowerCase().contains(_currentSearch.toLowerCase()))
          .toList();
      
      calculatedTotalPages = (displayedServices.length / servicesPerPage).ceil();
      if (calculatedTotalPages == 0) calculatedTotalPages = 1;
    });
  }

  void _performSearch() {
    final searchText = _searchController.text.trim();
    if (_currentSearch != searchText) {
      setState(() {
        _currentSearch = searchText;
        currentPage = 1;
      });
      _updateDisplayedServices();
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _currentSearch = '';
      currentPage = 1;
    });
    _updateDisplayedServices();
  }

  void _changePage(int newPage) {
    if (newPage != currentPage && newPage >= 1 && newPage <= calculatedTotalPages) {
      setState(() {
        currentPage = newPage;
      });
      _updateDisplayedServices();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          _buildCustomHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadServices(busqueda: _currentSearch.isEmpty ? null : _currentSearch),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    _buildSearchBar(),
                    _buildServicesTitle(),
                    _buildServicesSection(),
                    _buildPagination(),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: widget.showBottomNav ? const AppBottomNav(currentRoute: '/services') : null,
    );
  }

  Widget _buildCustomHeader() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF8B5CF6),
            Color(0xFFEC4899),
          ],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              const Expanded(
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star, color: Colors.white, size: 24),
                      SizedBox(width: 8),
                      Text(
                        'AstroApp',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.person, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              _currentSearch = value;
            });
            _performSearch();
          },
          decoration: InputDecoration(
            hintText: 'Buscar servicios...',
            hintStyle: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: const Color(0xFF8B5CF6),
              size: 24,
            ),
            suffixIcon: _currentSearch.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: _clearSearch,
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildServicesTitle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Nuestros Servicios',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D3748),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Descubre nuestra amplia gama de servicios de belleza profesional',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 25),
        ],
      ),
    );
  }

  Widget _buildServicesSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: _buildServicesGrid(),
    );
  }

  Widget _buildServicesGrid() {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(50),
          child: CircularProgressIndicator(
            color: Color(0xFF8B5CF6),
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => _loadServices(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                ),
                child: const Text(
                  'Reintentar',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (displayedServices.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(50),
          child: Column(
            children: [
              Icon(
                Icons.spa_outlined,
                size: 64,
                color: Colors.grey[400],
              ),
              const SizedBox(height: 16),
              Text(
                _currentSearch.isNotEmpty 
                    ? 'No se encontraron servicios para "$_currentSearch"'
                    : 'No hay servicios disponibles',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Calcular servicios para la página actual
    final startIndex = (currentPage - 1) * servicesPerPage;
    final endIndex = (startIndex + servicesPerPage).clamp(0, displayedServices.length);
    final servicesForCurrentPage = displayedServices.sublist(startIndex, endIndex);

    // Grid de servicios verticales (3 columnas)
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.75,
        crossAxisSpacing: 15,
        mainAxisSpacing: 20,
      ),
      itemCount: servicesForCurrentPage.length,
      itemBuilder: (context, index) {
        return _buildServiceCard(servicesForCurrentPage[index]);
      },
    );
  }

  Widget _buildServiceCard(Servicio service) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 15,
            offset: const Offset(0, 5),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Imagen del servicio (parte superior)
          Container(
            width: double.infinity,
            height: 120,
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Stack(
              children: [
                // Imagen del servicio
                Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: const BoxDecoration(
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    child: service.imagen != null && service.imagen!.isNotEmpty
                        ? Image.network(
                            service.imagen!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildDefaultServiceImage(service);
                            },
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Colors.grey[100],
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                    color: const Color(0xFF8B5CF6),
                                  ),
                                ),
                              );
                            },
                          )
                        : _buildDefaultServiceImage(service),
                  ),
                ),
                // Botón de favorito
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.favorite_border,
                      size: 16,
                      color: Color(0xFFEC4899),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Información del servicio (parte inferior)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Nombre del servicio
                  Text(
                    service.nombre,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2D3748),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Categoría
                  Text(
                    'General',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Duración y precio
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        "${service.duracion} min",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        "\$${_formatPrice(service.precio)}",
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8B5CF6),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Botones
                  Row(
                    children: [
                      // Botón Ver Más
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _showServiceDetails(service),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFF8B5CF6), width: 1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 6),
                          ),
                          child: const Text(
                            "Ver Más",
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF8B5CF6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      // Botón Agendar
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _scheduleService(service),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEC4899),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 6),
                          ),
                          child: const Text(
                            "Agendar",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultServiceImage(Servicio service) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFEC4899).withValues(alpha: 0.7),
            const Color(0xFF8B5CF6).withValues(alpha: 0.8),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getServiceIcon(service.nombre),
              size: 48,
              color: Colors.white,
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                service.nombre,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getServiceIcon(String serviceName) {
    final name = serviceName.toLowerCase();
    if (name.contains('corte') || name.contains('cabello')) return Icons.content_cut;
    if (name.contains('manicure') || name.contains('uñas')) return Icons.back_hand;
    if (name.contains('facial') || name.contains('limpieza')) return Icons.face;
    if (name.contains('masaje')) return Icons.spa;
    if (name.contains('depilación')) return Icons.healing;
    if (name.contains('maquillaje')) return Icons.brush;
    if (name.contains('cejas')) return Icons.visibility;
    return Icons.star;
  }

  Widget _buildPagination() {
    if (calculatedTotalPages <= 1) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Botón anterior
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: currentPage > 1 ? () => _changePage(currentPage - 1) : null,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.chevron_left,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          // Números de página
          ...List.generate(calculatedTotalPages, (index) {
            final pageNumber = index + 1;
            final isCurrentPage = currentPage == pageNumber;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 6),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _changePage(pageNumber),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isCurrentPage ? const Color(0xFF8B5CF6) : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCurrentPage ? const Color(0xFF8B5CF6) : Colors.grey[300]!,
                        width: 1,
                      ),
                      boxShadow: isCurrentPage ? [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ] : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      pageNumber.toString(),
                      style: TextStyle(
                        color: isCurrentPage ? Colors.white : const Color(0xFF2D3748),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
          // Botón siguiente
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: currentPage < calculatedTotalPages ? () => _changePage(currentPage + 1) : null,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.chevron_right,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatPrice(double price) {
    return price.toInt().toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), 
      (Match m) => '${m[1]}.',
    );
  }

  void _showServiceDetails(Servicio service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          service.nombre,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B5CF6),
          ),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imagen del servicio en el detalle
              if (service.imagen != null && service.imagen!.isNotEmpty)
                Container(
                  width: double.infinity,
                  height: 200,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      service.imagen!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _buildDefaultServiceImage(service);
                      },
                    ),
                  ),
                ),
              if (service.descripcion != null && service.descripcion!.isNotEmpty) ...[
                const Text(
                  'Descripción:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  service.descripcion!,
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  const Icon(Icons.access_time, size: 20, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 8),
                  Text(
                    'Duración: ${service.duracion} minutos',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.attach_money, size: 20, color: Color(0xFF8B5CF6)),
                  const SizedBox(width: 8),
                  Text(
                    'Precio: \$${_formatPrice(service.precio)}',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Cerrar',
              style: TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _scheduleService(service);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF8B5CF6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Agendar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _scheduleService(Servicio service) {
    Navigator.pushNamed(
      context, 
      '/appointment-flow',
      arguments: {
        'selectedService': service,
      },
    );
  }
}
