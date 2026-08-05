import 'package:flutter/foundation.dart';
import 'package:tienda/Presentation/Services/database_service.dart';

/// Proveedor para análisis avanzados y reportes de inventario
class ReportsProvider extends ChangeNotifier {
  bool isLoading = false;
  String? errorMessage;

  int? selectedStoreId;
  DateTime? dateFrom;
  DateTime? dateTo;

  // Datos de reportes
  Map<String, dynamic> analysisReport = {};
  List<Map<String, dynamic>> topSellers = [];
  List<Map<String, dynamic>> topMargin = [];
  List<Map<String, dynamic>> criticalProducts = [];
  Map<String, dynamic> investmentSummary = {};
  Map<String, double> salesTrend = {};
  double averageRotation = 0.0;

  /// Genera reporte completo de análisis
  Future<void> generateFullReport({
    required int storeId,
    DateTime? from,
    DateTime? to,
  }) async {
    selectedStoreId = storeId;
    dateFrom = from;
    dateTo = to;

    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      // Obtener todos los datos en paralelo
      final [
        report,
        sellers,
        margins,
        critical,
        investment,
        trend,
        rotation,
      ] = await Future.wait([
        DatabaseService.getInventoryAnalysisReport(
          storeId: storeId,
          dateFrom: from,
          dateTo: to,
        ),
        DatabaseService.getTopSellingProducts(
          storeId: storeId,
          topCount: 15,
          dateFrom: from,
          dateTo: to,
        ),
        DatabaseService.getTopMarginProducts(storeId: storeId, topCount: 15),
        DatabaseService.getCriticalInvestmentProducts(storeId: storeId),
        DatabaseService.getInventoryInvestmentSummary(storeId: storeId),
        DatabaseService.getSalesTrendLast7Days(storeId: storeId),
        DatabaseService.getAverageInventoryRotation(
          storeId: storeId,
          daysToAnalyze: 30,
        ),
      ]);

      analysisReport = (report as Map<String, dynamic>?) ?? {};
      topSellers = (sellers as List<Map<String, dynamic>>?) ?? [];
      topMargin = (margins as List<Map<String, dynamic>>?) ?? [];
      criticalProducts = (critical as List<Map<String, dynamic>>?) ?? [];
      investmentSummary = (investment as Map<String, dynamic>?) ?? {};
      salesTrend = (trend as Map<String, double>?) ?? {};
      averageRotation = (rotation as double?) ?? 0.0;
    } catch (e) {
      errorMessage = 'Error generando reporte: $e';
      debugPrint('Error en generateFullReport: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Obtiene solo top sellers
  Future<void> refreshTopSellers({int limit = 15}) async {
    if (selectedStoreId == null) return;

    try {
      topSellers = await DatabaseService.getTopSellingProducts(
        storeId: selectedStoreId!,
        topCount: limit,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );
      notifyListeners();
    } catch (e) {
      errorMessage = 'Error cargando top sellers: $e';
      notifyListeners();
    }
  }

  /// Obtiene solo top margin
  Future<void> refreshTopMargin({int limit = 15}) async {
    if (selectedStoreId == null) return;

    try {
      topMargin = await DatabaseService.getTopMarginProducts(
        storeId: selectedStoreId!,
        topCount: limit,
      );
      notifyListeners();
    } catch (e) {
      errorMessage = 'Error cargando top margen: $e';
      notifyListeners();
    }
  }

  /// Obtiene solo productos críticos
  Future<void> refreshCriticalProducts({
    double minInvestment = 500.0,
    int maxStock = 2,
  }) async {
    if (selectedStoreId == null) return;

    try {
      criticalProducts = await DatabaseService.getCriticalInvestmentProducts(
        storeId: selectedStoreId!,
        minInvestmentValue: minInvestment,
        maxStock: maxStock,
      );
      notifyListeners();
    } catch (e) {
      errorMessage = 'Error cargando productos críticos: $e';
      notifyListeners();
    }
  }

  /// Obtiene solo resumen de inversión
  Future<void> refreshInvestmentSummary() async {
    if (selectedStoreId == null) return;

    try {
      investmentSummary = await DatabaseService.getInventoryInvestmentSummary(
        storeId: selectedStoreId!,
      );
      notifyListeners();
    } catch (e) {
      errorMessage = 'Error cargando resumen: $e';
      notifyListeners();
    }
  }

  /// Obtiene tendencia de ventas
  Future<void> refreshSalesTrend() async {
    if (selectedStoreId == null) return;

    try {
      salesTrend = await DatabaseService.getSalesTrendLast7Days(
        storeId: selectedStoreId!,
      );
      notifyListeners();
    } catch (e) {
      errorMessage = 'Error cargando tendencia: $e';
      notifyListeners();
    }
  }

  /// Obtiene rotación promedio
  Future<void> refreshAverageRotation() async {
    if (selectedStoreId == null) return;

    try {
      averageRotation = await DatabaseService.getAverageInventoryRotation(
        storeId: selectedStoreId!,
        daysToAnalyze: 30,
      );
      notifyListeners();
    } catch (e) {
      errorMessage = 'Error cargando rotación: $e';
      notifyListeners();
    }
  }

  // ─────────────────────────────────────────────
  // GETTERS PARA DATOS CALCULADOS
  // ─────────────────────────────────────────────

  /// Retorna la inversión total
  double get totalInvested {
    final value = investmentSummary['totalInvested'];
    return (value as num?)?.toDouble() ?? 0.0;
  }

  /// Retorna ganancia potencial
  double get potentialGain {
    final value = investmentSummary['potentialGain'];
    return (value as num?)?.toDouble() ?? 0.0;
  }

  /// Retorna ROI potencial (%)
  double get potentialROI {
    final value = investmentSummary['potentialROI'];
    return (value as num?)?.toDouble() ?? 0.0;
  }

  /// Retorna total de productos
  int get totalProducts {
    final value = investmentSummary['totalProducts'];
    return (value as num?)?.toInt() ?? 0;
  }

  /// Retorna unidades totales
  int get totalUnits {
    final value = investmentSummary['totalUnits'];
    return (value as num?)?.toInt() ?? 0;
  }

  /// Retorna productos con stock bajo
  int get lowStockCount {
    final value = investmentSummary['lowStockCount'];
    return (value as num?)?.toInt() ?? 0;
  }

  /// Retorna margen promedio
  double get avgMarginPerUnit {
    final value = investmentSummary['avgMarginPerUnit'];
    return (value as num?)?.toDouble() ?? 0.0;
  }

  /// Total de ventas en el período
  double get totalSalesInPeriod {
    final value = analysisReport['totalSalesInPeriod'];
    return (value as num?)?.toDouble() ?? 0.0;
  }

  /// Venta promedio diaria
  double get averageDailySales {
    if (salesTrend.isEmpty) return 0.0;
    final total = salesTrend.values.fold<double>(0, (sum, val) => sum + val);
    return total / (salesTrend.isNotEmpty ? salesTrend.length : 1);
  }

  /// Venta máxima en los últimos 7 días
  double get maxDailySales {
    return salesTrend.values.isNotEmpty
        ? salesTrend.values.reduce((a, b) => a > b ? a : b)
        : 0.0;
  }

  /// Venta mínima en los últimos 7 días
  double get minDailySales {
    return salesTrend.values.isNotEmpty
        ? salesTrend.values.reduce((a, b) => a < b ? a : b)
        : 0.0;
  }

  /// Producto más vendido
  String get topSellerName {
    return topSellers.isNotEmpty ? topSellers.first['name'] ?? 'N/A' : 'N/A';
  }

  /// Unidades vendidas del top seller
  int get topSellerUnits {
    if (topSellers.isEmpty) return 0;
    final value = topSellers.first['totalSold'];
    return (value as num?)?.toInt() ?? 0;
  }

  /// Producto con mejor margen
  String get bestMarginProduct {
    return topMargin.isNotEmpty ? topMargin.first['name'] ?? 'N/A' : 'N/A';
  }

  /// Mejor margen %
  double get bestMarginPercent {
    if (topMargin.isEmpty) return 0.0;
    final value = topMargin.first['marginPercent'];
    return (value as num?)?.toDouble() ?? 0.0;
  }

  // Resets
  void clearReport() {
    analysisReport.clear();
    topSellers.clear();
    topMargin.clear();
    criticalProducts.clear();
    investmentSummary.clear();
    salesTrend.clear();
    averageRotation = 0.0;
    errorMessage = null;
    notifyListeners();
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }
}
