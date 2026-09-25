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
        "SELECT id, name, COALESCE(phone, '') as phone, COALESCE(email, '') as email, COALESCE(notes, '') as notes FROM suppliers ORDER BY name COLLATE NOCASE",
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
                (s.email?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }
  }

  /// Crear proveedor. Retorna null si fue exitoso, o un mensaje de error.
  Future<String?> createSupplier(SupplierModel supplier) async {
    try {
      final existing = await DatabaseService.rawQuery(
        'SELECT id FROM suppliers WHERE lower(name) = ?',
        [supplier.name.toLowerCase().trim()],
      );
      if (existing.isNotEmpty) {
        return 'Ya existe un proveedor con ese nombre.';
      }
      final supplierId = await DatabaseService.rawInsert(
        'INSERT INTO suppliers (name, phone, email, notes) VALUES (?, ?, ?, ?)',
        [
          supplier.name.trim(),
          supplier.phone?.trim(),
          supplier.email?.trim(),
          supplier.notes?.trim(),
        ],
      );
      await AuditService.log(
        action: AuditAction.createSupplier, module: 'Suppliers',
        page: 'SuppliersView', entity: 'supplier', entityId: supplierId,
        newData: supplier.toMap(), controller: 'SuppliersController',
      );
      await loadSuppliers();
      return null;
    } catch (e) {
      return 'Error al crear proveedor: $e';
    }
  }

  /// Actualizar proveedor. Retorna null si fue exitoso.
  Future<String?> updateSupplier(SupplierModel supplier) async {
    try {
      final before = await DatabaseService.rawQuery(
        'SELECT * FROM suppliers WHERE id = ? LIMIT 1', [supplier.id],
      );
      await DatabaseService.rawUpdate(
        'UPDATE suppliers SET name = ?, phone = ?, email = ?, notes = ? WHERE id = ?',
        [
          supplier.name.trim(),
          supplier.phone?.trim(),
          supplier.email?.trim(),
          supplier.notes?.trim(),
          supplier.id,
        ],
      );
      final after = await DatabaseService.rawQuery(
        'SELECT * FROM suppliers WHERE id = ? LIMIT 1', [supplier.id],
      );
      await AuditService.log(
        action: AuditAction.updateSupplier, module: 'Suppliers',
        page: 'SuppliersView', entity: 'supplier', entityId: supplier.id,
        oldData: before.isEmpty ? null : before.first,
        newData: after.isEmpty ? null : after.first,
        controller: 'SuppliersController',
      );
      await loadSuppliers();
      return null;
    } catch (e) {
      return 'Error al actualizar proveedor: $e';
    }
  }

  /// Eliminar proveedor. Retorna null si fue exitoso.
  Future<String?> deleteSupplier(SupplierModel supplier) async {
    try {
      final before = await DatabaseService.rawQuery(
        'SELECT * FROM suppliers WHERE id = ? LIMIT 1', [supplier.id],
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
        action: AuditAction.deleteSupplier, module: 'Suppliers',
        page: 'SuppliersView', entity: 'supplier', entityId: supplier.id,
        oldData: before.isEmpty ? null : before.first,
        controller: 'SuppliersController',
      );
      await loadSuppliers();
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
