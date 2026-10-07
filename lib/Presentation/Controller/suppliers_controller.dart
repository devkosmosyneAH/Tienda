import 'package:flutter/material.dart';
import 'package:tienda/Presentation/Model/supplier_model.dart';
import 'package:tienda/Presentation/Repository/supplier_repository.dart';
import 'package:tienda/Presentation/Services/database_service.dart';
import 'package:tienda/Presentation/Services/audit_service.dart';

class SuppliersController extends ChangeNotifier {
  SuppliersController({SupplierRepository? repository})
      : _repository = repository ?? const DatabaseSupplierRepository() {
    DatabaseService.addDatabaseListener(_handleDatabaseChanged);
  }

  final SupplierRepository _repository;
  List<SupplierModel> _suppliers = [];
  List<SupplierModel> _filtered = [];
  bool _loading = false;
  String? _error;
  String _search = '';

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
      _suppliers = await _repository.loadSuppliers();
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
      final supplierId = await _repository.createSupplier(supplier);
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
      await _repository.updateSupplier(supplier);
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

      await _repository.deleteSupplier(supplier.id!);
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
    return _repository.getPurchaseHistory(supplierId);
  }
}
