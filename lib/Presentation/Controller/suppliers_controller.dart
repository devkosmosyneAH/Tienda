import 'package:flutter/material.dart';
import 'package:tienda/Presentation/Model/supplier_model.dart';
import 'package:tienda/Presentation/Services/database_service.dart';
import 'package:tienda/Presentation/Services/audit_service.dart';

class SuppliersController extends ChangeNotifier {
  List<SupplierModel> _suppliers = [];
  List<SupplierModel> _filtered = [];
  bool _loading = false;
  String? _error;
  String _search = '';

  SuppliersController() {
    DatabaseService.addDatabaseListener(_handleDatabaseChanged);
  }

  List<SupplierModel> get suppliers => _filtered;
  bool get loading => _loading;
  String? get error => _error;
  String get search => _search;

  void _handleDatabaseChanged() {
    if (!_loading) {
      loadSuppliers();
    }
  }

  @override
  void dispose() {
    DatabaseService.removeDatabaseListener(_handleDatabaseChanged);
    super.dispose();
  }

  Future<void> loadSuppliers() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
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
      _suppliers = rows.map(SupplierModel.fromMap).toList();
      _applyFilter();
    } catch (e) {
      _error = 'Error al cargar proveedores: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void updateSearch(String value) {
    _search = value;
    _applyFilter();
    notifyListeners();
  }

  void _applyFilter() {
    if (_search.trim().isEmpty) {
      _filtered = List.from(_suppliers);
    } else {
      final q = _search.toLowerCase();
      _filtered = _suppliers
          .where(
            (s) =>
                s.name.toLowerCase().contains(q) ||
                (s.phone?.toLowerCase().contains(q) ?? false) ||
                (s.email?.toLowerCase().contains(q) ?? false) ||
                (s.identificationNumber?.toLowerCase().contains(q) ?? false) ||
                (s.legalName?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }
  }

  /// Crear proveedor. Retorna null si fue exitoso, o un mensaje de error.
  Future<String?> createSupplier(SupplierModel supplier) async {
    try {
      final supplierId = await DatabaseService.createSupplier(
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
      await AuditService.log(
        action: AuditAction.createSupplier,
        module: 'Suppliers',
        page: 'SuppliersView',
        entity: 'supplier',
        entityId: supplierId,
        newData: supplier.toMap(),
        controller: 'SuppliersController',
      );
      await loadSuppliers();
      DatabaseService.notifyDatabaseChanged();
      return null;
    } catch (e) {
      return 'Error al crear proveedor: $e';
    }
  }

  /// Actualizar proveedor. Retorna null si fue exitoso.
  Future<String?> updateSupplier(SupplierModel supplier) async {
    try {
      final before = await DatabaseService.rawQuery(
        'SELECT * FROM suppliers WHERE id = ? LIMIT 1',
        [supplier.id],
      );
      await DatabaseService.updateSupplier(
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
      final after = await DatabaseService.rawQuery(
        'SELECT * FROM suppliers WHERE id = ? LIMIT 1',
        [supplier.id],
      );
      await AuditService.log(
        action: AuditAction.updateSupplier,
        module: 'Suppliers',
        page: 'SuppliersView',
        entity: 'supplier',
        entityId: supplier.id,
        oldData: before.isEmpty ? null : before.first,
        newData: after.isEmpty ? null : after.first,
        controller: 'SuppliersController',
      );
      await loadSuppliers();
      DatabaseService.notifyDatabaseChanged();
      return null;
    } catch (e) {
      return 'Error al actualizar proveedor: $e';
    }
  }

  /// Eliminar proveedor. Retorna null si fue exitoso.
  Future<String?> deleteSupplier(SupplierModel supplier) async {
    try {
      final before = await DatabaseService.rawQuery(
        'SELECT * FROM suppliers WHERE id = ? LIMIT 1',
        [supplier.id],
      );
      // Verificar si tiene compras asociadas
      final purchases = await DatabaseService.rawQuery(
        'SELECT COUNT(*) as c FROM purchases WHERE supplier_id = ?',
        [supplier.id],
      );
      final count = (purchases.first['c'] as num).toInt();
      if (count > 0) {
        return 'No se puede eliminar: tiene $count compra(s) registrada(s).';
      }

      await DatabaseService.rawUpdate('DELETE FROM suppliers WHERE id = ?', [
        supplier.id,
      ]);
      await AuditService.log(
        action: AuditAction.deleteSupplier,
        module: 'Suppliers',
        page: 'SuppliersView',
        entity: 'supplier',
        entityId: supplier.id,
        oldData: before.isEmpty ? null : before.first,
        controller: 'SuppliersController',
      );
      await loadSuppliers();
      DatabaseService.notifyDatabaseChanged();
      return null;
    } catch (e) {
      return 'Error al eliminar proveedor: $e';
    }
  }

  /// Obtener historial de compras de un proveedor.
  Future<List<Map<String, dynamic>>> getPurchaseHistory(int supplierId) async {
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
