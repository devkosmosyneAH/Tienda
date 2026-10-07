import 'package:tienda/Presentation/Model/supplier_model.dart';
import 'package:tienda/Presentation/Services/database_service.dart';

abstract class SupplierRepository {
  Future<List<SupplierModel>> loadSuppliers();

  Future<int> createSupplier(SupplierModel supplier);

  Future<void> updateSupplier(SupplierModel supplier);

  Future<void> deleteSupplier(int supplierId);

  Future<List<Map<String, dynamic>>> getPurchaseHistory(int supplierId);
}

class DatabaseSupplierRepository implements SupplierRepository {
  const DatabaseSupplierRepository();

  @override
  Future<List<SupplierModel>> loadSuppliers() async {
    final rows = await DatabaseService.rawQuery(
      '''SELECT id, name, COALESCE(legal_name, name) AS legal_name,
                COALESCE(identification_type, 'ruc') AS identification_type,
                COALESCE(identification_number, ruc, '') AS identification_number,
                COALESCE(address, '') AS address, COALESCE(phone, '') AS phone,
                COALESCE(email, '') AS email, COALESCE(notes, '') AS notes,
                COALESCE(ruc, '') AS ruc,
                COALESCE(payment_condition, 'contado') AS payment_condition,
                COALESCE(payment_term_days, 0) AS payment_term_days,
                COALESCE(taxpayer_type, '') AS taxpayer_type,
                COALESCE(is_withholding_agent, 0) AS is_withholding_agent
         FROM suppliers ORDER BY name COLLATE NOCASE''',
      [],
    );

    return rows.map(SupplierModel.fromMap).toList();
  }

  @override
  Future<int> createSupplier(SupplierModel supplier) {
    return DatabaseService.createSupplier(
      name: supplier.name,
      phone: supplier.phone,
      email: supplier.email,
      notes: supplier.notes,
      ruc: supplier.ruc,
      identificationType: supplier.identificationType,
      identificationNumber: supplier.identificationNumber,
      legalName: supplier.legalName,
      address: supplier.address,
      paymentCondition: supplier.paymentCondition,
      paymentTermDays: supplier.paymentTermDays,
      taxpayerType: supplier.taxpayerType,
      isWithholdingAgent: supplier.isWithholdingAgent,
    );
  }

  @override
  Future<void> updateSupplier(SupplierModel supplier) {
    return DatabaseService.updateSupplier(
      id: supplier.id!,
      name: supplier.name,
      phone: supplier.phone,
      email: supplier.email,
      notes: supplier.notes,
      ruc: supplier.ruc,
      identificationType: supplier.identificationType,
      identificationNumber: supplier.identificationNumber,
      legalName: supplier.legalName,
      address: supplier.address,
      paymentCondition: supplier.paymentCondition,
      paymentTermDays: supplier.paymentTermDays,
      taxpayerType: supplier.taxpayerType,
      isWithholdingAgent: supplier.isWithholdingAgent,
    );
  }

  @override
  Future<void> deleteSupplier(int supplierId) async {
    await DatabaseService.rawUpdate(
      'DELETE FROM suppliers WHERE id = ?',
      [supplierId],
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getPurchaseHistory(int supplierId) {
    return DatabaseService.rawQuery(
      '''SELECT p.id, p.date, p.total,
              (SELECT COUNT(*) FROM purchase_items pi WHERE pi.purchase_id = p.id) as items_count
         FROM purchases p
         WHERE p.supplier_id = ?
         ORDER BY p.date DESC
         LIMIT 50''',
      [supplierId],
    );
  }
}
