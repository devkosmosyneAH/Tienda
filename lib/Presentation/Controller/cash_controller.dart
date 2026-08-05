import 'package:tienda/Presentation/Model/cash_model.dart';
import 'package:flutter/foundation.dart';
import 'package:tienda/Presentation/Services/database_service.dart';

class CashController extends ChangeNotifier {
  CashController() {
    DatabaseService.addDatabaseListener(_handleDatabaseChanged);
  }

  bool isLoading = false;
  String? errorMessage;

  // Locales
  List<Map<String, dynamic>> stores = [];
  int? selectedStoreId;

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
  int? get sessionId => activeSession != null
      ? (activeSession!['id'] as num).toInt()
      : null;

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
        selectedStoreId ??= (stores.first['id'] as num).toInt();
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
    await _loadSession();
  }

  Future<void> _loadSession() async {
    if (selectedStoreId == null) return;
    try {
      activeSession =
          await DatabaseService.getActiveCashSession(selectedStoreId!);
      if (activeSession != null) {
        await _loadMovements();
      } else {
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
          entries: denominations.map((e) => e.toMap(sessionId, 'open')).toList(),
          moment: 'open',
        );
      }
      await _loadSession();
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
          entries: denominations.map((e) => e.toMap(sessionId!, 'close')).toList(),
          moment: 'close',
        );
      }
      await DatabaseService.closeCashSession(
        sessionId: sessionId!,
        closingAmount: closingAmount,
      );
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
    await DatabaseService.addCashMovement(
      sessionId: sessionId!,
      type: 'expense',
      amount: amount,
      method: method,
      description: description,
    );
    await _loadMovements();
    notifyListeners();
  }

  Future<void> addIncome({
    required double amount,
    required String method,
    String? description,
  }) async {
    if (sessionId == null) throw Exception('No hay sesión de caja abierta');
    await DatabaseService.addCashMovement(
      sessionId: sessionId!,
      type: 'income',
      amount: amount,
      method: method,
      description: description,
    );
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

