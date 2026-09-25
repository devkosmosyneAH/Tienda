import 'package:tienda/Presentation/Model/cash_model.dart';
import 'package:tienda/Presentation/Services/database_service.dart';
import 'package:flutter/foundation.dart';
import 'package:tienda/Presentation/Services/audit_service.dart';

class CashController extends ChangeNotifier {
  CashController() {
    DatabaseService.addDatabaseListener(_handleDatabaseChanged);
  }

  bool isLoading = false;
  String? errorMessage;

  // Locales
  List<Map<String, dynamic>> stores = [];
  int? selectedStoreId;
  final Set<int> openStoreIds = {};

  // Métodos de pago
  List<Map<String, dynamic>> paymentMethods = [];

  // Sesión activa
  Map<String, dynamic>? activeSession;

  // Movimientos de la sesión activa
  List<Map<String, dynamic>> movements = [];

  // Resumen financiero
  Map<String, dynamic>? summary;

  // Desglose de denominaciones al abrir la caja
  CashBreakdown? openingBreakdown;

  // Desglose de denominaciones al cerrar la caja
  CashBreakdown? closingBreakdown;

  // ─── Historial ────────────────────────────────────────────────────────────

  /// Tipo de agrupación: 'year' | 'month' | 'week'
  String historyGroupBy = 'month';

  /// Año seleccionado para filtrar (null = todos)
  String? historyYear;

  /// Mes seleccionado 'YYYY-MM' (null = todos del año)
  String? historyMonth;

  /// Semana seleccionada 'YYYY-WW' (null = todas)
  String? historyWeek;

  List<Map<String, dynamic>> historySessions = [];
  List<String> historyAvailableYears = [];
  bool isLoadingHistory = false;

  bool get hasOpenSession => activeSession != null;
  bool isStoreOpen(int storeId) => openStoreIds.contains(storeId);
  int? get sessionId =>
      activeSession != null ? (activeSession!['id'] as num).toInt() : null;

  void _handleDatabaseChanged() {
    if (!isLoading) {
      refresh();
    }
  }

  @override
  void dispose() {
    DatabaseService.removeDatabaseListener(_handleDatabaseChanged);
    super.dispose();
  }

  Future<void> initialize() async {
    if (isLoading) return;
    _setLoading(true);
    try {
      stores = await DatabaseService.getStores();
      paymentMethods = await DatabaseService.getPaymentMethods();
      if (stores.isNotEmpty) {
        await _refreshOpenStoreIds();
        if (selectedStoreId == null) {
          if (openStoreIds.isNotEmpty) {
            selectedStoreId = openStoreIds.first;
          } else {
            selectedStoreId = (stores.first['id'] as num).toInt();
          }
        }
        await _loadSession();
      }
    } catch (e) {
      errorMessage = 'Error al inicializar la caja: $e';
    } finally {
      _setLoading(false);
    }
  }

  Future<void> selectStore(int storeId) async {
    selectedStoreId = storeId;
    activeSession = null;
    movements = [];
    summary = null;
    notifyListeners();
    await _loadSession();
  }

  Future<void> refresh() async {
    if (selectedStoreId == null) return;
    await _refreshOpenStoreIds();
    await _loadSession();
  }

  Future<void> _refreshOpenStoreIds() async {
    openStoreIds.clear();
    for (final store in stores) {
      final storeId = (store['id'] as num).toInt();
      final session = await DatabaseService.getActiveCashSession(storeId);
      if (session != null) openStoreIds.add(storeId);
    }
  }

  Future<void> _loadSession() async {
    if (selectedStoreId == null) return;
    try {
      activeSession = await DatabaseService.getActiveCashSession(
        selectedStoreId!,
      );
      if (activeSession != null) {
        openStoreIds.add(selectedStoreId!);
        await _loadMovements();
      } else {
        openStoreIds.remove(selectedStoreId!);
        movements = [];
        summary = null;
      }
    } catch (e) {
      errorMessage = 'Error al cargar sesión: $e';
    }
    notifyListeners();
  }

  Future<void> _loadMovements() async {
    if (sessionId == null) return;
    movements = await DatabaseService.getCashMovements(sessionId!);
    summary = await DatabaseService.getCashSessionSummary(sessionId!);
    // Cargar desglose de denominaciones de apertura si existe
    final rows = await DatabaseService.getCashDenominations(
      sessionId: sessionId!,
      moment: 'open',
    );
    if (rows.isNotEmpty) {
      final entries = rows.map(DenominationEntry.fromMap).toList();
      openingBreakdown = CashBreakdown(entries: entries, moment: 'open');
    } else {
      openingBreakdown = null;
    }
  }

  Future<void> openSession(
    double openingAmount, {
    int? openedBy,
    String openedByName = '',
    List<DenominationEntry>? denominations,
  }) async {
    if (selectedStoreId == null) {
      throw Exception('Selecciona un local');
    }
    _setLoading(true);
    try {
      final sessionId = await DatabaseService.openCashSession(
        storeId: selectedStoreId!,
        openingAmount: openingAmount,
        openedBy: openedBy,
        openedByName: openedByName,
      );
      if (denominations != null && denominations.isNotEmpty) {
        await DatabaseService.saveCashDenominations(
          sessionId: sessionId,
          entries: denominations
              .map((e) => e.toMap(sessionId, 'open'))
              .toList(),
          moment: 'open',
        );
      }
      await AuditService.log(
        action: AuditAction.cashOpen, module: 'Cash', page: 'CashView',
        entity: 'cash_session', entityId: sessionId,
        newData: {'opening_amount': openingAmount, 'store_id': selectedStoreId},
        controller: 'CashController',
      );
      await _loadSession();
    } catch (error) {
      await AuditService.log(
        action: AuditAction.cashOpen, module: 'Cash', page: 'CashView',
        controller: 'CashController', success: false, error: error,
      );
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> closeSession(
    double closingAmount, {
    List<DenominationEntry>? denominations,
  }) async {
    if (sessionId == null) throw Exception('No hay sesión abierta');
    _setLoading(true);
    try {
      if (denominations != null && denominations.isNotEmpty) {
        await DatabaseService.saveCashDenominations(
          sessionId: sessionId!,
          entries: denominations
              .map((e) => e.toMap(sessionId!, 'close'))
              .toList(),
          moment: 'close',
        );
      }
      await DatabaseService.closeCashSession(
        sessionId: sessionId!,
        closingAmount: closingAmount,
      );
      await AuditService.log(
        action: AuditAction.cashClose, module: 'Cash', page: 'CashView',
        entity: 'cash_session', entityId: sessionId,
        newData: {'closing_amount': closingAmount}, controller: 'CashController',
      );
      openStoreIds.remove(selectedStoreId);
      activeSession = null;
      movements = [];
      summary = null;
      openingBreakdown = null;
      closingBreakdown = null;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addExpense({
    required double amount,
    required String method,
    String? description,
  }) async {
    if (sessionId == null) throw Exception('No hay sesión de caja abierta');
    try {
      await DatabaseService.addCashMovement(
        sessionId: sessionId!, type: 'expense', amount: amount,
        method: method, description: description,
      );
      await AuditService.log(
        action: AuditAction.cashExpense, module: 'Cash', page: 'CashView',
        entity: 'cash_movement', entityId: sessionId,
        newData: {'type': 'expense', 'amount': amount, 'method': method,
          'description': description}, controller: 'CashController',
      );
    } catch (error) {
      await AuditService.log(
        action: AuditAction.cashExpense, module: 'Cash', page: 'CashView',
        controller: 'CashController', success: false, error: error,
      );
      rethrow;
    }
    await _loadMovements();
    notifyListeners();
  }

  Future<void> addIncome({
    required double amount,
    required String method,
    String? description,
  }) async {
    if (sessionId == null) throw Exception('No hay sesión de caja abierta');
    try {
      await DatabaseService.addCashMovement(
        sessionId: sessionId!, type: 'income', amount: amount,
        method: method, description: description,
      );
      await AuditService.log(
        action: AuditAction.cashIncome, module: 'Cash', page: 'CashView',
        entity: 'cash_movement', entityId: sessionId,
        newData: {'type': 'income', 'amount': amount, 'method': method,
          'description': description}, controller: 'CashController',
      );
    } catch (error) {
      await AuditService.log(
        action: AuditAction.cashIncome, module: 'Cash', page: 'CashView',
        controller: 'CashController', success: false, error: error,
      );
      rethrow;
    }
    await _loadMovements();
    notifyListeners();
  }

  void _setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }

  // ─── Historial ────────────────────────────────────────────────────────────

  Future<void> loadHistory() async {
    if (selectedStoreId == null) return;
    isLoadingHistory = true;
    notifyListeners();
    try {
      historyAvailableYears = await DatabaseService.getCashSessionYears(
        selectedStoreId!,
      );
      await _fetchHistorySessions();
    } finally {
      isLoadingHistory = false;
      notifyListeners();
    }
  }

  Future<void> _fetchHistorySessions() async {
    if (selectedStoreId == null) return;
    historySessions = await DatabaseService.getCashSessionHistory(
      selectedStoreId!,
      yearFilter: historyGroupBy == 'year' ? historyYear : null,
      monthFilter: historyGroupBy == 'month' ? historyMonth : null,
      weekFilter: historyGroupBy == 'week' ? historyWeek : null,
    );
  }

  Future<void> setHistoryGroupBy(String groupBy) async {
    historyGroupBy = groupBy;
    historyYear = null;
    historyMonth = null;
    historyWeek = null;
    await loadHistory();
  }

  Future<void> setHistoryYear(String? year) async {
    historyYear = year;
    await _fetchHistorySessions();
    notifyListeners();
  }

  Future<void> setHistoryMonth(String? month) async {
    historyMonth = month;
    await _fetchHistorySessions();
    notifyListeners();
  }

  Future<void> setHistoryWeek(String? week) async {
    historyWeek = week;
    await _fetchHistorySessions();
    notifyListeners();
  }
}
