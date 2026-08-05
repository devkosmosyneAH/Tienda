import 'package:flutter/foundation.dart';
import 'package:tienda/Presentation/Model/customer_model.dart';
import 'package:tienda/Presentation/Services/database_service.dart';

class CustomerProvider extends ChangeNotifier {
  bool isLoading = false;
  String? errorMessage;
  String search = '';

  List<Customer> customers = [];
  List<Customer> filteredCustomers = [];
  Customer? selectedCustomer;
  List<Map<String, dynamic>> customerHistory = [];

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
      final rawCustomers = await DatabaseService.getCustomers(search: searchValue);
      customers = rawCustomers.map((c) => Customer.fromMap(c)).toList();
      _filterCustomers();
    } catch (e) {
      errorMessage = 'Error al cargar clientes: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void _filterCustomers() {
    filteredCustomers = customers.where((customer) {
      if (search.isEmpty) return true;
      return customer.name.toLowerCase().contains(search.toLowerCase()) ||
          (customer.phone != null &&
              customer.phone!.contains(search)) ||
          (customer.email != null &&
              customer.email!.toLowerCase().contains(search.toLowerCase()));
    }).toList();
    notifyListeners();
  }

  Future<void> createCustomer({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? city,
    String? notes,
  }) async {
    try {
      await DatabaseService.createCustomer(
        name: name,
        phone: phone,
        email: email,
        notes: notes,
      );
      await loadCustomers(searchValue: search);
    } catch (e) {
      errorMessage = 'Error al crear cliente: $e';
      notifyListeners();
    }
  }

  Future<void> updateCustomer(int customerId, {
    String? name,
    String? phone,
    String? email,
    String? address,
    String? city,
    String? notes,
  }) async {
    try {
      // Actualizar en la base de datos si los métodos están disponibles
      // await DatabaseService.updateCustomer(
      //   customerId,
      //   name: name,
      //   phone: phone,
      //   email: email,
      //   notes: notes,
      // );
      await loadCustomers(searchValue: search);
    } catch (e) {
      errorMessage = 'Error al actualizar cliente: $e';
      notifyListeners();
    }
  }

  Future<void> selectCustomer(Customer customer) async {
    selectedCustomer = customer;
    try {
      customerHistory = await DatabaseService.getCustomerHistory(customer.id);
    } catch (e) {
      customerHistory = [];
    }
    notifyListeners();
  }

  void clearSelection() {
    selectedCustomer = null;
    customerHistory = [];
    notifyListeners();
  }

  int get totalCustomers => customers.length;

  List<Customer> get customersWithBalance =>
      customers.where((c) => c.hasBalance).toList();

  double get totalCredit =>
      customers.fold(0, (sum, c) => sum + c.balance);

  List<Customer> get topCustomers {
    final sorted = [...customers];
    sorted.sort((a, b) => b.totalSpent.compareTo(a.totalSpent));
    return sorted.take(10).toList();
  }
}
