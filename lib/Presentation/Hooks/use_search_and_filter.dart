import 'package:flutter/foundation.dart';
import 'dart:async';

/// Hook para búsqueda con debounce
class SearchDebounceHook extends ChangeNotifier {
  final Duration debounceDelay;
  Timer? _debounceTimer;
  String _searchQuery = '';
  bool _isSearching = false;

  String get searchQuery => _searchQuery;
  bool get isSearching => _isSearching;

  SearchDebounceHook({
    this.debounceDelay = const Duration(milliseconds: 500),
  });

  /// Ejecuta búsqueda con debounce
  void search(String query, Function(String) onSearch) {
    _searchQuery = query;
    _isSearching = true;
    notifyListeners();

    // Cancela el timer anterior
    _debounceTimer?.cancel();

    // Crea un nuevo timer
    _debounceTimer = Timer(debounceDelay, () {
      onSearch(query);
      _isSearching = false;
      notifyListeners();
    });
  }

  /// Limpia la búsqueda
  void clear() {
    _searchQuery = '';
    _isSearching = false;
    _debounceTimer?.cancel();
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

/// Hook para sugerencias de búsqueda
class SearchSuggestionsHook extends ChangeNotifier {
  List<String> _suggestions = [];
  bool _isLoadingSuggestions = false;

  List<String> get suggestions => _suggestions;
  bool get isLoadingSuggestions => _isLoadingSuggestions;

  /// Obtiene sugerencias basadas en la consulta
  Future<void> getSuggestions(
    String query,
    Future<List<String>> Function(String) fetchSuggestions,
  ) async {
    if (query.isEmpty) {
      _suggestions = [];
      notifyListeners();
      return;
    }

    _isLoadingSuggestions = true;
    notifyListeners();

    try {
      _suggestions = await fetchSuggestions(query);
    } catch (e) {
      _suggestions = [];
    } finally {
      _isLoadingSuggestions = false;
      notifyListeners();
    }
  }

  /// Limpia las sugerencias
  void clear() {
    _suggestions = [];
    _isLoadingSuggestions = false;
    notifyListeners();
  }
}

/// Hook para filtrado
class FilterHook extends ChangeNotifier {
  final Map<String, dynamic> _filters = {};
  late final List<dynamic> _originalList;
  List<dynamic> _filteredList = [];

  Map<String, dynamic> get filters => _filters;
  List<dynamic> get filteredList => _filteredList;

  /// Inicializa con una lista
  void initialize(List<dynamic> list) {
    _originalList = list;
    _filteredList = list;
    notifyListeners();
  }

  /// Añade un filtro
  void addFilter(String key, dynamic value) {
    if (value == null || (value is String && value.isEmpty)) {
      _filters.remove(key);
    } else {
      _filters[key] = value;
    }
    _applyFilters();
  }

  /// Elimina un filtro
  void removeFilter(String key) {
    _filters.remove(key);
    _applyFilters();
  }

  /// Limpia todos los filtros
  void clearFilters() {
    _filters.clear();
    _filteredList = _originalList;
    notifyListeners();
  }

  /// Aplica los filtros
  void _applyFilters() {
    _filteredList = _originalList.where((item) {
      for (var filterKey in _filters.keys) {
        if (item is Map) {
          if (item[filterKey] != _filters[filterKey]) {
            return false;
          }
        }
      }
      return true;
    }).toList();

    notifyListeners();
  }
}

/// Hook para ordenamiento
class SortHook extends ChangeNotifier {
  String? _sortBy;
  bool _isAscending = true;
  late List<dynamic> _sortedList;

  String? get sortBy => _sortBy;
  bool get isAscending => _isAscending;
  List<dynamic> get sortedList => _sortedList;

  /// Inicializa con una lista
  void initialize(List<dynamic> list) {
    _sortedList = list;
    notifyListeners();
  }

  /// Ordena por un campo
  void sort(String field, {bool ascending = true}) {
    _sortBy = field;
    _isAscending = ascending;

    _sortedList.sort((a, b) {
      if (a is Map && b is Map) {
        final valueA = a[field];
        final valueB = b[field];

        int comparison = 0;
        if (valueA is Comparable && valueB is Comparable) {
          comparison = valueA.compareTo(valueB);
        }

        return ascending ? comparison : -comparison;
      }
      return 0;
    });

    notifyListeners();
  }

  /// Invierte el orden
  void toggleSort() {
    if (_sortBy != null) {
      _isAscending = !_isAscending;
      sort(_sortBy!, ascending: _isAscending);
    }
  }
}
