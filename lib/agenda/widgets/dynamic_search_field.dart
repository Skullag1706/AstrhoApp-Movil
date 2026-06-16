import 'dart:async';
import 'package:flutter/material.dart';

/// Widget de búsqueda dinámica con resultados en dropdown
class DynamicSearchField<T> extends StatefulWidget {
  final String hintText;
  final String searchHintText;
  final Future<List<T>> Function(String query) onSearch;
  final void Function(T value) onSelected;
  final String Function(T item) getLabel;
  final T? initialValue;
  final Widget Function(T item)? itemBuilder;
  final int debounceMs;
  final bool enabled;
  final Color? borderColor;
  final Color? focusedBorderColor;

  const DynamicSearchField({
    Key? key,
    required this.hintText,
    this.searchHintText = "Buscar...",
    required this.onSearch,
    required this.onSelected,
    required this.getLabel,
    this.initialValue,
    this.itemBuilder,
    this.debounceMs = 500,
    this.enabled = true,
    this.borderColor,
    this.focusedBorderColor,
  }) : super(key: key);

  @override
  State<DynamicSearchField<T>> createState() => _DynamicSearchFieldState<T>();
}

class _DynamicSearchFieldState<T> extends State<DynamicSearchField<T>> {
  late TextEditingController _searchController;
  List<T> _searchResults = [];
  bool _isLoading = false;
  T? _selectedValue;
  final FocusNode _focusNode = FocusNode();
  OverlayEntry? _overlayEntry;
  final GlobalKey _fieldKey = GlobalKey();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _selectedValue = widget.initialValue;
    // NO agregar listener aquí - usar onChanged en el TextField en su lugar
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      // Si hay texto escrito y resultados previos, mostrar overlay
      if (_searchController.text.isNotEmpty && _searchResults.isNotEmpty) {
        _showOverlay();
      } else if (_searchController.text.isEmpty && _selectedValue != null) {
        // Si el campo está vacío pero hay selección previa, trigger búsqueda
        _performSearch(widget.getLabel(_selectedValue as T));
      }
    } else {
      _hideOverlay();
    }
  }

  void _onSearchChanged(String value) {
    // Cancelar timer anterior
    _debounceTimer?.cancel();

    if (value.isEmpty) {
      // Si está vacío, limpiar resultados inmediatamente
      if (mounted) {
        setState(() {
          _selectedValue = null;
          _searchResults = [];
        });
      }
    } else if (_focusNode.hasFocus) {
      // Debounce: esperar antes de realizar búsqueda
      _debounceTimer = Timer(Duration(milliseconds: widget.debounceMs), () {
        _performSearch(value);
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
          _searchResults = results;
          _isLoading = false;
        });
        _showOverlay();
      }
    } catch (e) {
      print('Error en búsqueda dinámica: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;

    final renderBox =
        _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx,
        top: offset.dy + size.height + 4,
        width: size.width,
        child: Material(
          elevation: 4,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 300),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: _isLoading
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _searchResults.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          'Sin resultados',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final item = _searchResults[index];
                          return InkWell(
                            onTap: () {
                              _selectItem(item);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: index < _searchResults.length - 1
                                      ? BorderSide(
                                          color: Colors.grey.shade100,
                                        )
                                      : BorderSide.none,
                                ),
                              ),
                              child: widget.itemBuilder != null
                                  ? widget.itemBuilder!(item)
                                  : Text(widget.getLabel(item)),
                            ),
                          );
                        },
                      ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _selectItem(T item) {
    _selectedValue = item;
    _searchController.text = widget.getLabel(item);
    _hideOverlay();
    widget.onSelected(item);
    setState(() {});
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounceTimer?.cancel();
    _overlayEntry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: _fieldKey,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _focusNode.hasFocus
              ? (widget.focusedBorderColor ?? Colors.purple.shade300)
              : (widget.borderColor ?? Colors.grey.shade200),
          width: _focusNode.hasFocus ? 2 : 1,
        ),
      ),
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        enabled: widget.enabled,
        decoration: InputDecoration(
          hintText: _selectedValue == null
              ? widget.hintText
              : widget.getLabel(_selectedValue as T),
          hintStyle: const TextStyle(color: Colors.grey),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon: _isLoading
              ? Padding(
                  padding: const EdgeInsets.all(12),
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
        onChanged: _onSearchChanged,
      ),
    );
  }
}
