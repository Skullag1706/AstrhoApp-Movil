import 'package:flutter/material.dart';
import 'dart:async';

/// Widget que combina búsqueda dinámica con API y lista paginada
class PaginatedDynamicSearch<T> extends StatefulWidget {
  final String hintText;
  final String searchHintText;
  final Future<List<T>> Function(String query) onSearch;
  final void Function(T value) onSelected;
  final String Function(T item) getLabel;
  final String Function(T item) getSubtitle;
  final Widget Function(T item) itemBuilder;
  final T? initialValue;
  final int itemsPerPage;
  final int debounceMs;

  const PaginatedDynamicSearch({
    Key? key,
    required this.hintText,
    this.searchHintText = "Buscar...",
    required this.onSearch,
    required this.onSelected,
    required this.getLabel,
    required this.getSubtitle,
    required this.itemBuilder,
    this.initialValue,
    this.itemsPerPage = 5,
    this.debounceMs = 500,
  }) : super(key: key);

  @override
  State<PaginatedDynamicSearch<T>> createState() =>
      _PaginatedDynamicSearchState<T>();
}

class _PaginatedDynamicSearchState<T> extends State<PaginatedDynamicSearch<T>> {
  late TextEditingController _searchController;
  List<T> _allResults = [];
  int _currentPage = 1;
  bool _isLoading = false;
  T? _selectedValue;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _selectedValue = widget.initialValue;
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _currentPage = 1;

    if (_searchController.text.isEmpty) {
      setState(() {
        _allResults = [];
      });
    } else {
      _debounceTimer = Timer(Duration(milliseconds: widget.debounceMs), () {
        _performSearch(_searchController.text);
      });
    }
  }

  Future<void> _performSearch(String query) async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      final results = await widget.onSearch(query);
      if (mounted) {
        setState(() {
          _allResults = results;
          _currentPage = 1;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error en búsqueda dinámica: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<T> _getPageItems() {
    final startIndex = (_currentPage - 1) * widget.itemsPerPage;
    final endIndex = startIndex + widget.itemsPerPage;

    return _allResults.sublist(
      startIndex,
      endIndex > _allResults.length ? _allResults.length : endIndex,
    );
  }

  int get _totalPages {
    return (_allResults.length / widget.itemsPerPage).ceil();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pageItems = _getPageItems();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
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
              hintText: widget.searchHintText,
              hintStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Lista de items
        if (_allResults.isEmpty && _searchController.text.isNotEmpty)
          Center(
            child: Text(
              _isLoading ? 'Buscando...' : 'Sin resultados',
              style: TextStyle(color: Colors.grey[600]),
            ),
          )
        else if (_allResults.isEmpty)
          Center(
            child: Text(
              'Escribe para buscar',
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
                itemCount: pageItems.length,
                itemBuilder: (context, index) {
                  final item = pageItems[index];
                  final isSelected = _selectedValue != null &&
                      widget.getLabel(_selectedValue as T) ==
                          widget.getLabel(item);
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedValue = item;
                        _searchController.text = widget.getLabel(item);
                      });
                      widget.onSelected(item);
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? Colors.purple.shade50 : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? Colors.purple.shade300
                              : Colors.grey.shade200,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: widget.itemBuilder(item),
                    ),
                  );
                },
              ),
              if (_totalPages > 1) ...[
                const SizedBox(height: 16),
                // Controles de paginación
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
                Center(
                  child: Text(
                    'Página $_currentPage de $_totalPages',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ],
          ),
      ],
    );
  }
}
