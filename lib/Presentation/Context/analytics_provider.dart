import 'dart:async';

import 'package:flutter/foundation.dart';

import '../Services/analytics_service.dart';
import '../Services/background_job_service.dart';

// ============================================================
// AnalyticsProvider — Estado OLAP para Flutter UI
// ============================================================
// Principios:
//  • NUNCA bloquea el hilo principal
//  • Lee SOLO de tablas summary_* y analytics_* (precalculadas)
//  • Usa compute() / Isolate para cualquier cómputo pesado
//  • Paginación cursor-based (no offset)
//  • Estado granular: cada sección carga independientemente
// ============================================================

class AnalyticsProvider extends ChangeNotifier {
  final AnalyticsService _analytics = AnalyticsService();
  final BackgroundJobService _jobs = BackgroundJobService();

  // ─── Estado de carga granular ─────────────────────────────
  bool _kpiLoading = false;
  bool _dailyLoading = false;
  bool _monthlyLoading = false;
  bool _topProductsLoading = false;
  bool _inventoryLoading = false;
  bool _creditLoading = false;
  bool _rfmLoading = false;

  // ─── Errores independientes ───────────────────────────────
  String? kpiError;
  String? dailyError;
  String? topProductsError;
  String? inventoryError;

  // ─── Datos ───────────────────────────────────────────────
  Map<String, dynamic> kpiSnapshot = {};
  List<Map<String, dynamic>> dailySummary = [];
  List<Map<String, dynamic>> monthlySummary = [];
  List<Map<String, dynamic>> topProducts = [];
  Map<String, dynamic> inventorySummary = {};
  Map<String, dynamic> creditSummary = {};
  List<Map<String, dynamic>> rfmDistribution = [];
  List<Map<String, dynamic>> revenueSparkline = [];

  // ─── Configuración activa ─────────────────────────────────
  int _storeId = 1;
  int _topProductDays = 30;
  String _topProductSort = 'revenue';
  int _dailyDays = 30;

  // ─── Getters de loading ───────────────────────────────────
  bool get isKpiLoading => _kpiLoading;
  bool get isDailyLoading => _dailyLoading;
  bool get isMonthlyLoading => _monthlyLoading;
  bool get isTopProductsLoading => _topProductsLoading;
  bool get isInventoryLoading => _inventoryLoading;
  bool get isCreditLoading => _creditLoading;
  bool get isRfmLoading => _rfmLoading;

  // ─── KPIs derivados ───────────────────────────────────────
  double get revenueToday =>
      (kpiSnapshot['revenue_today'] as num? ?? 0).toDouble();
  double get revenueWeek =>
      (kpiSnapshot['revenue_week'] as num? ?? 0).toDouble();
  double get revenueMonth =>
      (kpiSnapshot['revenue_month'] as num? ?? 0).toDouble();
  double get profitToday =>
      (kpiSnapshot['profit_today'] as num? ?? 0).toDouble();
  double get profitMonth =>
      (kpiSnapshot['profit_month'] as num? ?? 0).toDouble();
  int get salesToday => (kpiSnapshot['sales_today'] as num? ?? 0).toInt();
  int get salesWeek => (kpiSnapshot['sales_week'] as num? ?? 0).toInt();
  int get lowStockCount =>
      (kpiSnapshot['low_stock_count'] as num? ?? 0).toInt();
  double get creditBalance =>
      (kpiSnapshot['credit_balance'] as num? ?? 0).toDouble();
  double get marginMonth =>
      revenueMonth > 0 ? (profitMonth / revenueMonth) * 100 : 0;

  // ─── Inventario derivado ──────────────────────────────────
  double get totalInvested =>
      (inventorySummary['total_invested'] as num? ?? 0).toDouble();
  double get potentialRevenue =>
      (inventorySummary['potential_revenue'] as num? ?? 0).toDouble();
  double get potentialProfit =>
      (inventorySummary['potential_profit'] as num? ?? 0).toDouble();
  int get outOfStockCount =>
      (inventorySummary['out_of_stock_count'] as num? ?? 0).toInt();
  int get criticalStockCount =>
      (inventorySummary['critical_stock_count'] as num? ?? 0).toInt();

  // ==========================================================
  // SECCIÓN 1: INICIALIZACIÓN
  // ==========================================================

  Future<void> initialize(int storeId) async {
    _storeId = storeId;
    await loadAll();
  }

  /// Carga todas las secciones en paralelo (lectura concurrente SQLite WAL).
  Future<void> loadAll() async {
    await Future.wait([
      loadKpi(),
      loadDailySummary(),
      loadTopProducts(),
      loadInventorySummary(),
      loadCreditSummary(),
      loadRfmDistribution(),
      loadRevenueSparkline(),
    ]);
  }

  // ==========================================================
  // SECCIÓN 2: LOADERS INDEPENDIENTES
  // ==========================================================

  Future<void> loadKpi() async {
    _kpiLoading = true;
    kpiError = null;
    notifyListeners();
    try {
      kpiSnapshot = await _analytics.getKpiSnapshot(_storeId);
    } catch (e) {
      kpiError = e.toString();
    } finally {
      _kpiLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadDailySummary({int? days}) async {
    _dailyLoading = true;
    if (days != null) _dailyDays = days;
    notifyListeners();
    try {
      dailySummary = await _analytics.getDailySummary(
        storeId: _storeId,
        days: _dailyDays,
      );
    } catch (e) {
      dailyError = e.toString();
    } finally {
      _dailyLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMonthlySummary({int months = 12}) async {
    _monthlyLoading = true;
    notifyListeners();
    try {
      monthlySummary = await _analytics.getMonthlySummary(
        storeId: _storeId,
        months: months,
      );
    } catch (_) {
    } finally {
      _monthlyLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadTopProducts({String? orderBy, int? periodDays}) async {
    _topProductsLoading = true;
    if (orderBy != null) _topProductSort = orderBy;
    if (periodDays != null) _topProductDays = periodDays;
    topProductsError = null;
    notifyListeners();
    try {
      topProducts = await _analytics.getTopProducts(
        storeId: _storeId,
        periodDays: _topProductDays,
        orderBy: _topProductSort,
        limit: 20,
      );
    } catch (e) {
      topProductsError = e.toString();
    } finally {
      _topProductsLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadInventorySummary() async {
    _inventoryLoading = true;
    inventoryError = null;
    notifyListeners();
    try {
      inventorySummary = await _analytics.getInventoryInvestmentSummary(
        _storeId,
      );
    } catch (e) {
      inventoryError = e.toString();
    } finally {
      _inventoryLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadCreditSummary() async {
    _creditLoading = true;
    notifyListeners();
    try {
      creditSummary = await _analytics.getCreditPortfolioSummary(_storeId);
    } catch (_) {
    } finally {
      _creditLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadRfmDistribution() async {
    _rfmLoading = true;
    notifyListeners();
    try {
      rfmDistribution = await _analytics.getClientRfmDistribution(_storeId);
    } catch (_) {
    } finally {
      _rfmLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadRevenueSparkline({int days = 30}) async {
    try {
      revenueSparkline = await _analytics.getRevenueSparkline(
        storeId: _storeId,
        days: days,
      );
      notifyListeners();
    } catch (_) {}
  }

  // ==========================================================
  // SECCIÓN 3: REPORTE COMPLETO EN BACKGROUND
  // ==========================================================

  bool _reportLoading = false;
  Map<String, dynamic> lastReport = {};
  bool get isReportLoading => _reportLoading;

  Future<void> generateFullReport({
    required String fromDate,
    required String toDate,
  }) async {
    _reportLoading = true;
    notifyListeners();
    try {
      lastReport = await _analytics.generateFullReportInBackground(
        storeId: _storeId,
        fromDate: fromDate,
        toDate: toDate,
      );
    } catch (_) {
    } finally {
      _reportLoading = false;
      notifyListeners();
    }
  }

  // ==========================================================
  // SECCIÓN 4: TRIGGER DE RECÁLCULO POST-VENTA
  // ==========================================================

  /// Llamar después de registrar una venta para encolar recálculo OLAP.
  Future<void> onSaleCompleted() async {
    await _jobs.enqueueFullRecalculation(_storeId);
  }

  /// Forzar refresh manual del dashboard.
  Future<void> refresh() async => loadAll();
}
