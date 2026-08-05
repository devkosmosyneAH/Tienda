import 'package:tienda/Presentation/Services/database_service.dart';
import 'package:flutter/foundation.dart';

class CustomersController extends ChangeNotifier {
  CustomersController() {
    DatabaseService.addDatabaseListener(_handleDatabaseChanged);
  }

  bool isLoading = false;
  String? errorMessage;
  String search = '';

  List<Map<String, dynamic>> customers = [];
  List<Map<String, dynamic>> history = [];
  Map<String, dynamic>? selectedCustomer;

  void _handleDatabaseChanged() {
    if (!isLoading) {
      loadCustomers();
    }
  }

  @override
  void dispose() {
    DatabaseService.removeDatabaseListener(_handleDatabaseChanged);
    super.dispose();
  }

  Future<void> initialize() async {
    if (isLoading || customers.isNotEmpty) return;
    await loadCustomers();
  }

  Future<void> loadCustomers({String searchValue = ''}) async {
    isLoading = true;
    search = searchValue;
    errorMessage = null;
    notifyListeners();

    try {
      customers = await DatabaseService.getCustomers(search: searchValue);
      if (selectedCustomer != null) {
        await selectCustomer(selectedCustomer!);
      }
    } catch (e) {
      errorMessage = 'No se pudo cargar el CRM: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createCustomer({
    required String name,
    String? phone,
    String? email,
    String? notes,
  }) async {
    await DatabaseService.createCustomer(
      name: name,
      phone: phone,
      email: email,
      notes: notes,
    );
    await loadCustomers(searchValue: search);
  }

  Future<void> selectCustomer(Map<String, dynamic> customer) async {
    selectedCustomer = customer;
    history = await DatabaseService.getCustomerHistory(
      (customer['id'] as num).toInt(),
    );
    notifyListeners();
  }
}
