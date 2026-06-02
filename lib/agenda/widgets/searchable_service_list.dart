import 'package:flutter/material.dart';
import 'dart:async';
import '/agenda/models/agenda.dart';

/// Widget que muestra servicios con búsqueda local
class SearchableServiceList extends StatefulWidget {
  final List<Servicio> servicios;
  final Set<int> selectedServiceIds;
  final void Function(Set<int>) onSelectionChanged;
  final String Function(double) formatCurrency;

  const SearchableServiceList({
    super.key,
    required this.servicios,
    required this.selectedServiceIds,
    required this.onSelectionChanged,
    required this.formatCurrency,
  });

  @override
  State<SearchableServiceList> createState() => _SearchableServiceListState();
}

class _SearchableServiceListState extends State<SearchableServiceList> {
  late TextEditingController _searchController;
  List<Servicio> _filteredServicios = [];
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _filteredServicios = List.from(widget.servicios);
    _searchController.addListener(_onSearchChanged);
    print('DEBUG: SearchableServiceList initialized with ${widget.servicios.length} services');
    print('DEBUG: Selected services: ${widget.selectedServiceIds}');
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();

    if (_searchController.text.isEmpty) {
      setState(() {
        _filteredServicios = List.from(widget.servicios);
      });
    } else {
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        _performLocalSearch(_searchController.text);
      });
    }
  }

  void _performLocalSearch(String query) {
    final lowerQuery = query.toLowerCase();
    setState(() {
      _filteredServicios = widget.servicios
          .where((servicio) {
            final nombreMatch = servicio.nombre.toLowerCase().contains(lowerQuery);
            final descriptionMatch = servicio.descripcion != null
                ? servicio.descripcion!.toLowerCase().contains(lowerQuery)
                : false;
            return nombreMatch || descriptionMatch;
          })
          .toList();
    });
    print('DEBUG: Search performed for "$query", found ${_filteredServicios.length} services');
  }

  void _toggleService(int servicioId) {
    final newSelection = Set<int>.from(widget.selectedServiceIds);
    if (newSelection.contains(servicioId)) {
      newSelection.remove(servicioId);
      print('DEBUG: Removed service $servicioId from selection');
    } else {
      newSelection.add(servicioId);
      print('DEBUG: Added service $servicioId to selection');
    }
    print('DEBUG: New selection: $newSelection');
    widget.onSelectionChanged(newSelection);
  }

  @override
  void didUpdateWidget(SearchableServiceList oldWidget) {
    super.didUpdateWidget(oldWidget);
    print('DEBUG: didUpdateWidget called');
    print('DEBUG: Selected services updated from ${oldWidget.selectedServiceIds} to ${widget.selectedServiceIds}');
    
    // Actualizar lista filtrada si cambian los servicios disponibles
    if (oldWidget.servicios != widget.servicios) {
      if (_searchController.text.isEmpty) {
        _filteredServicios = List.from(widget.servicios);
      } else {
        _performLocalSearch(_searchController.text);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Campo de búsqueda
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.grey.shade300,
              width: 1,
            ),
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar servicio...',
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        // Lista de servicios filtrados
        _filteredServicios.isEmpty
            ? Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.grey.shade50,
                ),
                child: Center(
                  child: Text(
                    _searchController.text.isEmpty
                        ? 'No hay servicios disponibles'
                        : 'No se encontraron servicios',
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              )
            : Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _filteredServicios
                    .map(
                      (servicio) {
                        final isSelected =
                            widget.selectedServiceIds.contains(servicio.servicioId);
                        print(
                          'DEBUG: Rendering chip for service ${servicio.servicioId} (${servicio.nombre}), selected: $isSelected, selectedSet: ${widget.selectedServiceIds}',
                        );
                        return FilterChip(
                          label: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                servicio.nombre,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                widget.formatCurrency(servicio.precio),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          selected: isSelected,
                          onSelected: (selected) {
                            print(
                              'DEBUG: FilterChip.onSelected fired for service ${servicio.servicioId}',
                            );
                            _toggleService(servicio.servicioId);
                          },
                        );
                      },
                    )
                    .toList(),
              ),
      ],
    );
  }
}
