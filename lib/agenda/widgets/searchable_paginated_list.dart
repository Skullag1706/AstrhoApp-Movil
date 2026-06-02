import 'package:flutter/material.dart';
import 'dart:async';

/// Widget que muestra una lista paginada con búsqueda local
class SearchablePaginatedList<T> extends StatefulWidget {
  final List<T> items;
  final String Function(T item) getLabel;
  final String Function(T item) getSubtitle;
  final Widget Function(T item) itemBuilder;
  final void Function(T value) onSelected;
  final T? initialValue;
  final int itemsPerPage;
  final String searchHintText;

  const SearchablePaginatedList({
    Key? key,
    required this.items,
    required this.getLabel,
    required this.getSubtitle,
    required this.itemBuilder,
    required this.onSelected,
    this.initialValue,
    this.itemsPerPage = 5,
    this.searchHintText = "Buscar...",
  }) : super(key: key);

  @override
  State<SearchablePaginatedList<T>> createState() =>
      _SearchablePaginatedListState<T>();
}

class _SearchablePaginatedListState<T> extends State<SearchablePaginatedList<T>> {
  late TextEditingController _searchController;
  List<T> _filteredItems = [];
  int _currentPage = 1;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _filteredItems = List.from(widget.items);
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _currentPage = 1;

    if (_searchController.text.isEmpty) {
      setState(() {
        _filteredItems = List.from(widget.items);
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
      _filteredItems = widget.items
          .where((item) =>
              widget.getLabel(item).toLowerCase().contains(lowerQuery) ||
              widget.getSubtitle(item).toLowerCase().contains(lowerQuery))
          .toList();
      _currentPage = 1;
    });
  }

  List<T> _getPageItems() {
    final startIndex = (_currentPage - 1) * widget.itemsPerPage;
    final endIndex = startIndex + widget.itemsPerPage;

    return _filteredItems.sublist(
      startIndex,
      endIndex > _filteredItems.length ? _filteredItems.length : endIndex,
    );
  }

  int get _totalPages {
    return (_filteredItems.length / widget.itemsPerPage).ceil();
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
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Campo de búsqueda
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: widget.searchHintText,
            hintStyle: const TextStyle(color: Colors.grey),
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
        const SizedBox(height: 16),

        // Lista de items
        if (_filteredItems.isEmpty)
          Center(
            child: Text(
              _searchController.text.isEmpty
                  ? 'No hay items disponibles'
                  : 'Sin resultados',
              style: TextStyle(color: Colors.grey[600]),
            ),
          )
        else
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _getPageItems().length,
                itemBuilder: (context, index) {
                  final item = _getPageItems()[index];
                  return GestureDetector(
                    onTap: () {
                      widget.onSelected(item);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.grey.shade200,
                        ),
                      ),
                      child: widget.itemBuilder(item),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              // Controles de paginación
              if (_totalPages > 1)
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.first_page),
                          onPressed: _currentPage > 1
                              ? () {
                                  setState(() {
                                    _currentPage = 1;
                                  });
                                }
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: _currentPage > 1
                              ? () {
                                  setState(() {
                                    _currentPage--;
                                  });
                                }
                              : null,
                        ),
                        ...List.generate(_totalPages, (index) {
                          final pageNum = index + 1;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _currentPage == pageNum
                                    ? const Color(0xFF7926F7)
                                    : Colors.grey.shade200,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                minimumSize: const Size(40, 40),
                              ),
                              onPressed: () {
                                setState(() {
                                  _currentPage = pageNum;
                                });
                              },
                              child: Text(
                                pageNum.toString(),
                                style: TextStyle(
                                  color: _currentPage == pageNum
                                      ? Colors.white
                                      : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          );
                        }),
                        IconButton(
                          icon: const Icon(Icons.chevron_right),
                          onPressed: _currentPage < _totalPages
                              ? () {
                                  setState(() {
                                    _currentPage++;
                                  });
                                }
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.last_page),
                          onPressed: _currentPage < _totalPages
                              ? () {
                                  setState(() {
                                    _currentPage = _totalPages;
                                  });
                                }
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              if (_totalPages > 1)
                Center(
                  child: Text(
                    'Página $_currentPage de $_totalPages',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
