import 'package:flutter/foundation.dart';
import 'package:tienda/Presentation/Model/purchase_model.dart';
import 'package:tienda/Presentation/Services/database_service.dart';

class PurchaseProvider extends ChangeNotifier {
  bool isLoading = false;
  String? errorMessage;

  List<Purchase> purchases = [];
  Purchase? selectedPurchase;
  List<PurchaseItem> orderItems = [];

  int? selectedSupplierId;
  int? selectedStoreId;

  Future<void> initialize() async {
    if (isLoading || purchases.isNotEmpty) return;
    await loadPurchases();
  }

  Future<void> loadPurchases({DateTime? fromDate, DateTime? toDate}) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      final rawPurchases = await DatabaseService.getPurchaseHistory();

      purchases = rawPurchases.map((p) {
        return Purchase(
          id: (p['id'] as num).toInt(),
          supplierId: 0,
          supplierName: p['supplier_name'] as String,
          storeId: 0,
          items: [],
          subtotal: 0,
          tax: 0.0,
          total: (p['total'] as num).toDouble(),
          status: PurchaseStatus.pending,
          orderDate: DateTime.parse(p['date'] as String),
          createdAt: DateTime.parse(p['date'] as String),
        );
      }).toList();

      if (fromDate != null && toDate != null) {
        purchases = purchases
            .where(
              (p) =>
                  p.orderDate.isAfter(fromDate) && p.orderDate.isBefore(toDate),
            )
            .toList();
      }

      purchases.sort((a, b) => b.orderDate.compareTo(a.orderDate));
    } catch (e) {
      errorMessage = 'Error al cargar compras: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Añade un producto a la orden
  void addOrderItem(
    int productId,
    String productName,
    int quantity,
    double unitCost,
  ) {
    final existingIndex = orderItems.indexWhere(
      (item) => item.productId == productId,
    );

    if (existingIndex >= 0) {
      final existingItem = orderItems[existingIndex];
      orderItems[existingIndex] = PurchaseItem(
        productId: existingItem.productId,
        productName: existingItem.productName,
        orderedQuantity: existingItem.orderedQuantity + quantity,
        receivedQuantity: existingItem.receivedQuantity,
        unitCost: unitCost,
        totalCost: (unitCost * (existingItem.orderedQuantity + quantity)),
      );
    } else {
      orderItems.add(
        PurchaseItem(
          productId: productId,
          productName: productName,
          orderedQuantity: quantity,
          receivedQuantity: 0,
          unitCost: unitCost,
          totalCost: unitCost * quantity,
        ),
      );
    }

    notifyListeners();
  }

  /// Elimina un producto de la orden
  void removeOrderItem(int productId) {
    orderItems.removeWhere((item) => item.productId == productId);
    notifyListeners();
  }

  /// Actualiza cantidad ordenada
  void updateOrderItemQuantity(int productId, int newQuantity) {
    final index = orderItems.indexWhere((item) => item.productId == productId);
    if (index >= 0) {
      final item = orderItems[index];
      if (newQuantity <= 0) {
        removeOrderItem(productId);
      } else {
        orderItems[index] = PurchaseItem(
          productId: item.productId,
          productName: item.productName,
          orderedQuantity: newQuantity,
          receivedQuantity: item.receivedQuantity,
          unitCost: item.unitCost,
          totalCost: item.unitCost * newQuantity,
        );
        notifyListeners();
      }
    }
  }

  /// Actualiza cantidad recibida
  void updateReceivedQuantity(int productId, int receivedQuantity) {
    final index = orderItems.indexWhere((item) => item.productId == productId);
    if (index >= 0) {
      final item = orderItems[index];
      orderItems[index] = PurchaseItem(
        productId: item.productId,
        productName: item.productName,
        orderedQuantity: item.orderedQuantity,
        receivedQuantity: receivedQuantity.clamp(0, item.orderedQuantity),
        unitCost: item.unitCost,
        totalCost: item.totalCost,
      );
      notifyListeners();
    }
  }

  /// Limpia la orden
  void clearOrder() {
    orderItems.clear();
    selectedSupplierId = null;
    selectedStoreId = null;
    notifyListeners();
  }

  /// Crea una compra
  /// 🔄 NOTA: Requiere implementar el método createPurchase en DatabaseService
  Future<void> createPurchase({
    required int supplierId,
    required String supplierName,
    required int storeId,
    String? invoiceNumber,
    String? referenceNumber,
    double tax = 0.0,
    String? notes,
    DateTime? expectedDeliveryDate,
  }) async {
    if (orderItems.isEmpty) {
      errorMessage = 'La orden está vacía';
      notifyListeners();
      return;
    }

    try {
      isLoading = true;
      notifyListeners();

      // final subtotal = orderItems.fold<double>(
      //     0, (sum, item) => sum + item.totalCost);
      // final total = subtotal + tax;

      // Crear la compra
      // final purchase = Purchase(
      //   id: 0,
      //   supplierId: supplierId,
      //   supplierName: supplierName,
      //   storeId: storeId,
      //   items: orderItems,
      //   subtotal: subtotal,
      //   tax: tax,
      //   total: total,
      //   invoiceNumber: invoiceNumber,
      //   referenceNumber: referenceNumber,
      //   notes: notes,
      //   status: PurchaseStatus.pending,
      //   orderDate: DateTime.now(),
      //   expectedDeliveryDate: expectedDeliveryDate,
      //   createdAt: DateTime.now(),
      // );

      // odo
      //Implementar createPurchase en DatabaseService
      // await DatabaseService.createPurchase(purchase.toMap());

      clearOrder();
      await loadPurchases();

      errorMessage = null;
    } catch (e) {
      errorMessage = 'Error al crear compra: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  /// Recibe items de una compra
  /// 🔄 NOTA: Requiere implementar el método updatePurchaseStatus en DatabaseService
  Future<void> receivePurchaseItems(
    int purchaseId,
    List<Map<String, int>> itemsReceived,
  ) async {
    try {
      isLoading = true;
      notifyListeners();

      // t odo
      //Implementar updatePurchaseStatus en DatabaseService
      // await DatabaseService.updatePurchaseStatus(
      //   purchaseId,
      //   status: PurchaseStatus.received,
      // );

      await loadPurchases();
    } catch (e) {
      errorMessage = 'Error al recibir items: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  void selectPurchase(Purchase purchase) {
    selectedPurchase = purchase;
    notifyListeners();
  }

  /// Total de la orden
  double get orderTotal =>
      orderItems.fold<double>(0, (sum, item) => sum + item.totalCost);

  /// Total de items en la orden
  int get orderItemCount =>
      orderItems.fold<int>(0, (sum, item) => sum + item.orderedQuantity);

  /// Total de compras
  double get totalPurchases =>
      purchases.fold<double>(0, (sum, purchase) => sum + purchase.total);

  /// Compras pendientes
  List<Purchase> get pendingPurchases =>
      purchases.where((p) => p.status == PurchaseStatus.pending).toList();

  /// Total pendiente de pagar
  double get totalPending =>
      purchases.fold<double>(0, (sum, p) => sum + p.pendingAmount);

  /// Compras por recibir
  int get purchasesNotReceived =>
      purchases.where((p) => p.status == PurchaseStatus.pending).length;
}
