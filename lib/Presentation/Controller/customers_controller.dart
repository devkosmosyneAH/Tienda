import 'package:tienda/Presentation/Repository/customer_repository.dart';
import 'package:tienda/Presentation/Services/database_service.dart';
import 'package:tienda/Presentation/Services/audit_service.dart';
import 'package:flutter/foundation.dart';

class CustomersController extends ChangeNotifier {
  CustomersController({CustomerRepository? repository})
      : _repository = repository ?? const DatabaseCustomerRepository() {
    DatabaseService.addDatabaseListener(_handleDatabaseChanged);
  }

  final CustomerRepository _repository;

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
      customers = await _repository.loadCustomers(search: searchValue);
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

  Future<String> createCustomer({
    required String name,
    String? uid,
    String? phone,
    String? email,
    String? notes,
    String? apellidos,
    String? cedula,
    String? identificationType,
    String? address,
    String? referencias,
  }) async {
    try {
      final savedUid = await _repository.createCustomer(
        name: name,
        uid: uid,
        phone: phone,
        email: email,
        notes: notes,
        apellidos: apellidos,
        cedula: cedula,
        address: address,
        identificationType: identificationType,
        referencias: referencias,
      );
      final created = await _repository.getCustomerByUid(savedUid);
      await AuditService.log(
        action: AuditAction.createCustomer,
        module: 'Customers',
        page: 'CustomersView',
        entity: 'client',
        entityId: created?['id'],
        newData: created,
        controller: 'CustomersController',
      );
      await loadCustomers(searchValue: search);
      return savedUid;
    } catch (error) {
      await AuditService.log(
        action: AuditAction.createCustomer,
        module: 'Customers',
        page: 'CustomersView',
        controller: 'CustomersController',
        success: false,
        error: error,
      );
      rethrow;
    }
  }

  Future<void> selectCustomer(Map<String, dynamic> customer) async {
    selectedCustomer = customer;
    history = await _repository.getCustomerHistory(
      (customer['id'] as num).toInt(),
    );
    notifyListeners();
  }

  Future<void> updateCustomer({
    required int id,
    required String name,
    String? uid,
    String? phone,
    String? email,
    String? notes,
    String? apellidos,
    String? cedula,
    String? identificationType,
    String? address,
    String? referencias,
  }) async {
    final before = await _repository.getCustomerById(id);
    try {
      await _repository.updateCustomer(
        id: id,
        name: name,
        uid: uid,
        phone: phone,
        email: email,
        notes: notes,
        apellidos: apellidos,
        cedula: cedula,
        address: address,
        identificationType: identificationType,
        referencias: referencias,
      );
      final after = await _repository.getCustomerById(id);
      await AuditService.log(
        action: AuditAction.updateCustomer,
        module: 'Customers',
        page: 'CustomersView',
        entity: 'client',
        entityId: id,
        oldData: before,
        newData: after,
        controller: 'CustomersController',
      );
    } catch (error) {
      await AuditService.log(
        action: AuditAction.updateCustomer,
        module: 'Customers',
        page: 'CustomersView',
        entity: 'client',
        entityId: id,
        oldData: before,
        controller: 'CustomersController',
        success: false,
        error: error,
      );
      rethrow;
    }
    selectedCustomer = null;
    await loadCustomers(searchValue: search);
  }

  Future<void> deleteCustomer(int id) async {
    final before = await _repository.getCustomerById(id);
    try {
      await _repository.deleteCustomer(id);
      await AuditService.log(
        action: AuditAction.deleteCustomer,
        module: 'Customers',
        page: 'CustomersView',
        entity: 'client',
        entityId: id,
        oldData: before,
        controller: 'CustomersController',
      );
    } catch (error) {
      await AuditService.log(
        action: AuditAction.deleteCustomer,
        module: 'Customers',
        page: 'CustomersView',
        entity: 'client',
        entityId: id,
        oldData: before,
        controller: 'CustomersController',
        success: false,
        error: error,
      );
      rethrow;
    }
    if (selectedCustomer?['id'] == id) {
      selectedCustomer = null;
      history = [];
    }
    await loadCustomers(searchValue: search);
  }
}
