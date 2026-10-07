import 'package:tienda/Presentation/Services/database_service.dart';

abstract class CustomerRepository {
  Future<List<Map<String, dynamic>>> loadCustomers({String search = ''});

  Future<Map<String, dynamic>?> getCustomerById(int id);

  Future<Map<String, dynamic>?> getCustomerByUid(String uid);

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
  });

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
  });

  Future<void> deleteCustomer(int id);

  Future<List<Map<String, dynamic>>> getCustomerHistory(int customerId);
}

class DatabaseCustomerRepository implements CustomerRepository {
  const DatabaseCustomerRepository();

  @override
  Future<List<Map<String, dynamic>>> loadCustomers({String search = ''}) {
    return DatabaseService.getCustomers(search: search);
  }

  @override
  Future<Map<String, dynamic>?> getCustomerById(int id) async {
    final rows = await DatabaseService.rawQuery(
      'SELECT * FROM clients WHERE id = ? LIMIT 1',
      [id],
    );
    return rows.isEmpty ? null : rows.first;
  }

  @override
  Future<Map<String, dynamic>?> getCustomerByUid(String uid) async {
    final rows = await DatabaseService.rawQuery(
      'SELECT * FROM clients WHERE uid = ? LIMIT 1',
      [uid],
    );
    return rows.isEmpty ? null : rows.first;
  }

  @override
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
  }) {
    return DatabaseService.createCustomer(
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
  }

  @override
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
  }) {
    return DatabaseService.updateCustomer(
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
  }

  @override
  Future<void> deleteCustomer(int id) {
    return DatabaseService.deleteCustomer(id);
  }

  @override
  Future<List<Map<String, dynamic>>> getCustomerHistory(int customerId) {
    return DatabaseService.getCustomerHistory(customerId);
  }
}
