import 'package:flutter/foundation.dart';
import 'package:tienda/Presentation/Model/inventory_model.dart';
import 'package:tienda/Presentation/Services/database_service.dart';

class InventoryProvider extends ChangeNotifier {
  InventoryProvider() {
    DatabaseService.addDatabaseListener(_handleDatabaseChanged);
  }

  bool isLoading = false;
  String? errorMessage;
  String search = '';
  int? selectedStoreId;

  List<Map<String, dynamic>> stores = [];
  List<InventoryItem> inventoryItems = [];
  List<InventoryItem> filteredItems = [];
  InventorySummary? summary;

  // Datos de vendibilidad (simulado - conectar con getSalesHistory)
  final Map<int, int> _unitsSoldByProduct = {};

  void _handleDatabaseChanged() {
    if (!isLoading) {
      loadInventory();
    }
  }

  @override
  void dispose() {
    DatabaseService.removeDatabaseListener(_handleDatabaseChanged);
    super.dispose();
  }

  Future<void> initialize() async {
    if (isLoading || stores.isNotEmpty) return;

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      stores = await DatabaseService.getStores();
      if (stores.isNotEmpty) {
        selectedStoreId ??= (stores.first['id'] as num).toInt();
        await loadInventory();
      }
    } catch (e) {
      errorMessage = 'No se pudo cargar el inventario: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectStore(int? storeId) async {
    if (storeId == null) return;
    selectedStoreId = storeId;
    await loadInventory();
  }

  Future<void> loadInventory() async {
    if (selectedStoreId == null) return;

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      // Cargar inventario
      final rawInventory = await DatabaseService.getInventoryByStore(
        selectedStoreId!,
        search: search,
      );

      // Cargar datos de ventas para calcular unidades vendidas
      await _loadSalesData();

      // Convertir a InventoryItem
      inventoryItems = rawInventory.map((item) {
        final productId = (item['product_id'] as num).toInt();
        final unitsSold = _unitsSoldByProduct[productId] ?? 0;
        return InventoryItem.fromMap(item, unitsSold: unitsSold);
      }).toList();

      _filterAndSort();
      _calculateSummary();
    } catch (e) {
      errorMessage = 'No se pudo actualizar el inventario: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Carga datos de ventas para calcular rotación (CONECTADO CON BD)
  Future<void> _loadSalesData() async {
    try {
      if (selectedStoreId == null) return;

      // Obtener unidades vendidas en los últimos 30 días
      final unitsSold = await DatabaseService.getUnitsSoldByProduct(
        storeId: selectedStoreId!,
        dateFrom: DateTime.now().subtract(const Duration(days: 30)),
      );

      _unitsSoldByProduct.clear();
      _unitsSoldByProduct.addAll(unitsSold);
    } catch (e) {
      // Si falla la carga de datos, continuar sin vendibilidad real
      debugPrint('Error cargando datos de ventas: $e');
    }
  }

  void _filterAndSort() {
    // Filtrar por búsqueda
    filteredItems = inventoryItems.where((item) {
      if (search.isEmpty) return true;
      return item.name.toLowerCase().contains(search.toLowerCase()) ||
          item.sku.toLowerCase().contains(search.toLowerCase()) ||
          item.category.toLowerCase().contains(search.toLowerCase());
    }).toList();

    // Ordenar por saleability score (descendente)
    filteredItems.sort(
      (a, b) => b.saleabilityScore.compareTo(a.saleabilityScore),
    );
  }

  void _calculateSummary() {
    if (inventoryItems.isEmpty) {
      summary = null;
      return;
    }

    final totalInvested = inventoryItems.fold<double>(
      0,
      (sum, item) => sum + item.investmentValue,
    );
    final totalPotentialGain = inventoryItems.fold<double>(
      0,
      (sum, item) => sum + item.potentialGain,
    );

    final lowStock = inventoryItems.where((i) => i.isLowStock).length;
    final totalUnits = inventoryItems.fold<int>(
      0,
      (sum, i) => sum + i.quantity,
    );

    // Top 5 más vendidos
    final topSellers = [...inventoryItems]
      ..sort((a, b) => b.unitsSold.compareTo(a.unitsSold));

    // Top 5 mejor margen
    final topMargin = [...inventoryItems]
      ..sort((a, b) => b.marginPercent.compareTo(a.marginPercent));

    final avgMargin = inventoryItems.isNotEmpty
        ? (inventoryItems.fold<double>(0, (sum, i) => sum + i.marginPercent) /
                  inventoryItems.length)
              .toDouble()
        : 0.0;

    final avgRotation = inventoryItems.isNotEmpty
        ? (inventoryItems.fold<double>(0, (sum, i) => sum + i.rotationRate) /
                  inventoryItems.length)
              .toDouble()
        : 0.0;

    summary = InventorySummary(
      totalInvested: totalInvested,
      totalPotentialGain: totalPotentialGain,
      totalProducts: inventoryItems.length,
      totalUnits: totalUnits,
      lowStockCount: lowStock,
      topSellers: topSellers.take(5).toList(),
      topMargin: topMargin.take(5).toList(),
      averageMarginPercent: avgMargin,
      averageRotation: avgRotation,
    );

    notifyListeners();
  }

  Future<void> updateSearch(String value) async {
    search = value;
    _filterAndSort();
    notifyListeners();
  }

  Future<void> updateStock({required int productId, required int stock}) async {
    if (selectedStoreId == null) return;
    try {
      await DatabaseService.updateInventoryStock(
        productId: productId,
        storeId: selectedStoreId!,
        stock: stock,
      );
      await loadInventory();
    } catch (e) {
      errorMessage = 'Error al actualizar stock: $e';
      notifyListeners();
    }
  }

  Future<void> transferStock({
    required int productId,
    required int fromStoreId,
    required int toStoreId,
    required int quantity,
  }) async {
    try {
      await DatabaseService.transferInventory(
        productId: productId,
        fromStoreId: fromStoreId,
        toStoreId: toStoreId,
        quantity: quantity,
      );
      await loadInventory();
    } catch (e) {
      errorMessage = 'Error al transferir: $e';
      notifyListeners();
    }
  }

  /// Obtiene productos ordenados por saleability (más vendidos)
  List<InventoryItem> get topSellersItems =>
      [...filteredItems]
        ..sort((a, b) => b.saleabilityScore.compareTo(a.saleabilityScore));

  /// Obtiene productos con inversión crítica (stock bajo pero alto valor)
  List<InventoryItem> get criticalInvestment => filteredItems
      .where((item) => item.isLowStock && item.investmentValue > 500)
      .toList();

  /// Obtiene productos con mejor margen pero bajo stock
  List<InventoryItem> get highMarginLowStock => filteredItems
      .where((item) => item.isLowStock && item.marginPercent > 40)
      .toList();

  // ──────────────────────────────────────────────────────────
  // ANÁLISIS AVANZADO - FASE 5
  // ──────────────────────────────────────────────────────────

  /// Obtiene reporte completo de análisis de inventario para reportes
  Future<Map<String, dynamic>> getAnalysisReport({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    if (selectedStoreId == null) return {};

    try {
      isLoading = true;
      notifyListeners();

      final report = await DatabaseService.getInventoryAnalysisReport(
        storeId: selectedStoreId!,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );

      return report;
    } catch (e) {
      errorMessage = 'Error generando reporte: $e';
      notifyListeners();
      return {};
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Obtiene TOP sellers real desde BD
  Future<List<Map<String, dynamic>>> getTopSellersFromDB({
    int limit = 10,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    if (selectedStoreId == null) return [];

    try {
      return await DatabaseService.getTopSellingProducts(
        storeId: selectedStoreId!,
        topCount: limit,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );
    } catch (e) {
      debugPrint('Error en getTopSellersFromDB: $e');
      return [];
    }
  }

  /// Obtiene TOP margin products real desde BD
  Future<List<Map<String, dynamic>>> getTopMarginFromDB({
    int limit = 10,
  }) async {
    if (selectedStoreId == null) return [];

    try {
      return await DatabaseService.getTopMarginProducts(
        storeId: selectedStoreId!,
        topCount: limit,
      );
    } catch (e) {
      debugPrint('Error en getTopMarginFromDB: $e');
      return [];
    }
  }

  /// Obtiene rotación promedio de inventario (unidades/día)
  Future<double> getAverageRotationValue({int daysToAnalyze = 30}) async {
    if (selectedStoreId == null) return 0.0;

    try {
      return await DatabaseService.getAverageInventoryRotation(
        storeId: selectedStoreId!,
        daysToAnalyze: daysToAnalyze,
      );
    } catch (e) {
      debugPrint('Error en getAverageRotationValue: $e');
      return 0.0;
    }
  }

  /// Obtiene tendencia de ventas últimos 7 días
  Future<Map<String, double>> getSalesTrend() async {
    if (selectedStoreId == null) return {};

    try {
      return await DatabaseService.getSalesTrendLast7Days(
        storeId: selectedStoreId!,
      );
    } catch (e) {
      debugPrint('Error en getSalesTrend: $e');
      return {};
    }
  }

  /// Obtiene productos con inversión crítica desde BD
  Future<List<Map<String, dynamic>>> getCriticalProducts({
    double minInvestment = 500.0,
    int maxStock = 2,
  }) async {
    if (selectedStoreId == null) return [];

    try {
      return await DatabaseService.getCriticalInvestmentProducts(
        storeId: selectedStoreId!,
        minInvestmentValue: minInvestment,
        maxStock: maxStock,
      );
    } catch (e) {
      debugPrint('Error en getCriticalProducts: $e');
      return [];
    }
  }

  /// Obtiene resumen de inversión desde BD
  Future<Map<String, dynamic>> getInvestmentSummary() async {
    if (selectedStoreId == null) return {};

    try {
      return await DatabaseService.getInventoryInvestmentSummary(
        storeId: selectedStoreId!,
      );
    } catch (e) {
      debugPrint('Error en getInvestmentSummary: $e');
      return {};
    }
  }
}
