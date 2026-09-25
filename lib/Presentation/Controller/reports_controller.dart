import 'package:tienda/Presentation/Services/database_service.dart';
import 'package:flutter/foundation.dart';

class ReportsController extends ChangeNotifier {
  ReportsController() {
    DatabaseService.addDatabaseListener(_handleDatabaseChanged);
  }

  bool isLoading = false;
  String? errorMessage;
  DateTime? selectedFromDate;
  DateTime? selectedToDate;

  Map<String, dynamic> salesToday = const {};
  List<Map<String, dynamic>> salesByStore = [];
  List<Map<String, dynamic>> topProducts = [];

  int get salesCountToday => ((salesToday['sales_count'] as num?)?.toInt()) ?? 0;
  double get totalToday => ((salesToday['total'] as num?)?.toDouble()) ?? 0;

  void _handleDatabaseChanged() {
    if (!isLoading) {
      loadReports();
    }
  }

  @override
  void dispose() {
    DatabaseService.removeDatabaseListener(_handleDatabaseChanged);
    super.dispose();
  }

  Future<void> initialize() async {
    if (isLoading) return;
    await loadReports();
  }

  Future<void> setDateRange({DateTime? fromDate, DateTime? toDate}) async {
    selectedFromDate = fromDate;
    selectedToDate = toDate;
    await loadReports();
  }

  Future<void> clearDateRange() async {
    selectedFromDate = null;
    selectedToDate = null;
    await loadReports();
  }

  Future<void> loadReports() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final snapshot = await DatabaseService.getReportsSnapshot(
        fromDate: selectedFromDate,
        toDate: selectedToDate,
      );
      salesToday = Map<String, dynamic>.from(
        snapshot['salesToday'] as Map<String, dynamic>,
      );
      salesByStore = List<Map<String, dynamic>>.from(
        snapshot['salesByStore'] as List,
      );
      topProducts = List<Map<String, dynamic>>.from(
        snapshot['topProducts'] as List,
      );
    } catch (e) {
      errorMessage = 'No se pudieron cargar los reportes: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }
}
