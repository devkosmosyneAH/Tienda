import 'package:tienda/Presentation/Services/database_service.dart';
import 'package:flutter/foundation.dart';
import 'package:tienda/Presentation/Services/audit_service.dart';
import 'package:tienda/Presentation/Model/purchase_calculation.dart';
import 'package:tienda/Presentation/Utils/supplier_ruc_validator.dart';

enum PurchaseHistoryPeriod { all, today, week, month }

class PurchasesController extends ChangeNotifier {
  static String formatInvoiceNumber(int sequence) {
    final digits = sequence < 0 ? 0 : sequence;
    final number = digits.toString().padLeft(9, '0');
    return '001-001-$number';
  }

  static String resolveInvoiceNumber(String? value) {
    final trimmed = (value ?? '').trim();
    if (trimmed.isEmpty) return formatInvoiceNumber(1);
    if (RegExp(r'^\d{3}-\d{3}-\d{9}$').hasMatch(trimmed)) {
      return trimmed;
    }
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return formatInvoiceNumber(1);
    final asInt = int.tryParse(digits) ?? 1;
    return formatInvoiceNumber(asInt);
  }

  bool isLoading = false;
  bool isHistoryLoading = false;
  String? errorMessage;

  int? selectedStoreId;
  int? selectedSupplierId;
  int? historySupplierId;
  String? historyCategory;
  DateTime? historyDate;
  DateTime? historyFromDate;
  DateTime? historyToDate;
  String historySearch = '';
  PurchaseHistoryPeriod historyPeriod = PurchaseHistoryPeriod.all;
  String search = '';

  List<Map<String, dynamic>> stores = [];
  List<Map<String, dynamic>> suppliers = [];
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> products = [];
  List<Map<String, dynamic>> cart = [];
  List<Map<String, dynamic>> purchaseHistory = [];
  List<Map<String, dynamic>> paymentMethods = [];
  int _historyRequestSequence = 0;

  String invoiceNumber = '';
  String auxiliaryInvoiceNumber = '';
  int? selectedPaymentMethodId;
  String selectedPaymentMethodName = 'Contado';

  bool considerVatProfit = false;
  double governmentVatRate = 15.0;
  double profitVatRate = 15.0;
  double discount = 0;
  String accessKey = '';
  DateTime issueDate = DateTime.now();
  String paymentCondition = 'contado';
  DateTime? dueDate;
  String taxSupportCode = '';
  double? physicalTotal;
  List<Map<String, dynamic>> withholdings = [];
  String withholdingAuthorization = '';

  PurchaseTotals get calculatedTotals => PurchaseTotals.calculate(
    cart.map(
      (item) => PurchaseLineInput(
        productId: (item['product_id'] as num).toInt(),
        quantity: (item['quantity'] as num).toInt(),
        bonusQuantity: (item['bonus_quantity'] as num?)?.toInt() ?? 0,
        unitCost: (item['cost'] as num).toDouble(),
        discount: (item['discount'] as num?)?.toDouble() ?? 0,
        bonusVatAmount: (item['bonus_vat_amount'] as num?)?.toDouble() ?? 0,
        vatType: PurchaseVatType.values.firstWhere(
          (type) => type.name == (item['vat_type']?.toString() ?? 'standard'),
        ),
        vatRate: (item['vat_rate'] as num?)?.toDouble() ?? governmentVatRate,
      ),
    ),
  );

  double get subtotal =>
      calculatedTotals.grossSubtotal - calculatedTotals.discount;

  double get appliedVatRate => governmentVatRate;

  double get vatTotal => calculatedTotals.vatTotal;

  double get total => calculatedTotals.total;

  int get productsWithVat => cart
      .where((item) => item['vat_type'] == PurchaseVatType.standard.name)
      .length;

  int get historyTotalCount => purchaseHistory.length;

  int get historyPaidCount => purchaseHistory.where((purchase) {
    if (purchase['status'] == 'cancelled') return false;
    return ((purchase['payable_balance'] as num?)?.toDouble() ?? 0) <= 0.01;
  }).length;

  int get historyPendingCount => purchaseHistory.where((purchase) {
    if (purchase['status'] == 'cancelled') return false;
    return ((purchase['payable_balance'] as num?)?.toDouble() ?? 0) > 0.01;
  }).length;

  double get historyTotalAmount => purchaseHistory.fold<double>(
    0,
    (sum, purchase) =>
        sum +
        (purchase['status'] == 'cancelled'
            ? 0
            : ((purchase['total'] as num?)?.toDouble() ?? 0)),
  );

  void setConsiderVatProfit(bool value) {
    considerVatProfit = value;
    notifyListeners();
  }

  void updateGovernmentVatRate(double value) {
    governmentVatRate = value < 0 ? 0 : value;
    notifyListeners();
  }

  void updateProfitVatRate(double value) {
    profitVatRate = value < 0 ? 0 : value;
    notifyListeners();
  }

  void updateDiscount(double value) {
    discount = value < 0 ? 0 : value;
    notifyListeners();
  }

  void updateAuxiliaryInvoiceNumber(String value) {
    auxiliaryInvoiceNumber = value;
    notifyListeners();
  }

  void selectPaymentMethod(int? methodId) {
    if (methodId == null) return;
    selectedPaymentMethodId = methodId;
    final method = paymentMethods.firstWhere(
      (item) => (item['id'] as num).toInt() == methodId,
      orElse: () => <String, dynamic>{},
    );
    selectedPaymentMethodName = _paymentMethodLabel(
      method['name']?.toString() ?? 'Contado',
    );
    notifyListeners();
  }

  String _paymentMethodLabel(String name) {
    return name;
  }

  Future<void> initialize() async {
    if (isLoading || stores.isNotEmpty) return;
    await refresh();
  }

  Future<void> refresh() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    try {
      stores = await DatabaseService.getStores();
      suppliers = await DatabaseService.getSuppliers();
      categories = await DatabaseService.getCategories();
      paymentMethods = await DatabaseService.getPaymentMethods();
      selectedPaymentMethodId ??= paymentMethods.isNotEmpty
          ? (paymentMethods.first['id'] as num).toInt()
          : null;
      selectedPaymentMethodName = paymentMethods.isNotEmpty
          ? _paymentMethodLabel(paymentMethods.first['name'].toString())
          : 'Contado';
      if (invoiceNumber.trim().isEmpty) {
        final generated = await DatabaseService.getNextPurchaseInvoiceNumber();
        invoiceNumber = formatInvoiceNumber(int.tryParse(generated) ?? 1);
      }
      if (stores.isNotEmpty) {
        selectedStoreId ??= (stores.first['id'] as num).toInt();
      }
      await _loadProducts();
      await loadPurchaseHistory();
    } catch (e) {
      errorMessage = 'No se pudo cargar el módulo de compras: $e';
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> selectStore(int? storeId) async {
    if (storeId == null) return;
    selectedStoreId = storeId;
    cart.clear();
    if (invoiceNumber.trim().isEmpty) {
      final generated = await DatabaseService.getNextPurchaseInvoiceNumber();
      invoiceNumber = formatInvoiceNumber(int.tryParse(generated) ?? 1);
    }
    await _loadProducts();
    await loadPurchaseHistory();
  }

  Future<void> ensureInvoiceNumber() async {
    if (invoiceNumber.trim().isNotEmpty) return;
    final generated = await DatabaseService.getNextPurchaseInvoiceNumber();
    invoiceNumber = formatInvoiceNumber(int.tryParse(generated) ?? 1);
    notifyListeners();
  }

  void selectSupplier(int? supplierId) {
    selectedSupplierId = supplierId;
    final matches = suppliers.where(
      (supplier) => (supplier['id'] as num).toInt() == supplierId,
    );
    if (matches.isEmpty) {
      paymentCondition = 'contado';
      dueDate = null;
    } else {
      final supplier = matches.first;
      paymentCondition = supplier['payment_condition']?.toString() ?? 'contado';
      final termDays = (supplier['payment_term_days'] as num?)?.toInt() ?? 0;
      dueDate = paymentCondition == 'credito'
          ? issueDate.add(Duration(days: termDays))
          : null;
    }
    notifyListeners();
  }

  void setInvoiceNumber(String value) {
    invoiceNumber = value.trim();
    notifyListeners();
  }

  void setAccessKey(String value) {
    accessKey = value.trim();
    notifyListeners();
  }

  void setIssueDate(DateTime value) {
    issueDate = value;
    if (paymentCondition == 'credito') {
      final supplier = suppliers.where(
        (item) => (item['id'] as num).toInt() == selectedSupplierId,
      );
      final days = supplier.isEmpty
          ? 0
          : (supplier.first['payment_term_days'] as num?)?.toInt() ?? 0;
      dueDate = value.add(Duration(days: days));
    }
    notifyListeners();
  }

  void setPaymentCondition(String value) {
    paymentCondition = value.toLowerCase();
    if (paymentCondition == 'credito') {
      final supplier = suppliers.where(
        (item) => (item['id'] as num).toInt() == selectedSupplierId,
      );
      final days = supplier.isEmpty
          ? 0
          : (supplier.first['payment_term_days'] as num?)?.toInt() ?? 0;
      dueDate ??= issueDate.add(Duration(days: days));
    } else {
      dueDate = null;
    }
    notifyListeners();
  }

  void setDueDate(DateTime? value) {
    dueDate = value;
    notifyListeners();
  }

  void setTaxSupportCode(String value) {
    taxSupportCode = value.trim();
    notifyListeners();
  }

  void setPhysicalTotal(double? value) {
    physicalTotal = value;
    notifyListeners();
  }

  void addWithholding(Map<String, dynamic> withholding) {
    withholdings = [...withholdings, Map<String, dynamic>.from(withholding)];
    notifyListeners();
  }

  void removeWithholding(int index) {
    if (index < 0 || index >= withholdings.length) return;
    withholdings = [...withholdings]..removeAt(index);
    notifyListeners();
  }

  void setWithholdingAuthorization(String value) {
    withholdingAuthorization = value.trim();
    notifyListeners();
  }

  Future<Map<String, dynamic>> createSupplier({
    required String name,
    String? phone,
    String? email,
    String? notes,
    String? ruc,
    String? identificationType,
    String? identificationNumber,
    String? legalName,
    String? address,
    String? paymentCondition,
    int paymentTermDays = 0,
    String? taxpayerType,
    bool isWithholdingAgent = false,
  }) async {
    final supplierId = await DatabaseService.createSupplier(
      name: name,
      phone: phone,
      email: email,
      notes: notes,
      ruc: ruc,
      identificationType: identificationType,
      identificationNumber: identificationNumber,
      legalName: legalName,
      address: address,
      paymentCondition: paymentCondition ?? 'contado',
      paymentTermDays: paymentTermDays,
      taxpayerType: taxpayerType,
      isWithholdingAgent: isWithholdingAgent,
    );
    await AuditService.log(
      action: AuditAction.createSupplier,
      module: 'Suppliers',
      page: 'PurchasesView',
      entity: 'supplier',
      entityId: supplierId,
      newData: {
        'name': name.trim(),
        'phone': phone?.trim(),
        'email': email?.trim(),
        'ruc': ruc?.trim(),
        'identification_type': identificationType ?? 'ruc',
        'identification_number': identificationNumber ?? ruc?.trim(),
        'legal_name': legalName?.trim(),
        'address': address?.trim(),
        'payment_condition': paymentCondition ?? 'contado',
      },
      controller: 'PurchasesController',
    );
    DatabaseService.notifyDatabaseChanged();
    suppliers = await DatabaseService.getSuppliers();
    selectedSupplierId = supplierId;
    notifyListeners();
    return suppliers.firstWhere(
      (supplier) => (supplier['id'] as num).toInt() == supplierId,
    );
  }

  Future<void> updateSearch(String value) async {
    search = value;
    await _loadProducts();
  }

  Future<void> _loadProducts() async {
    if (selectedStoreId == null) {
      products = [];
      notifyListeners();
      return;
    }

    products = await DatabaseService.getProducts(
      search: search,
      storeId: selectedStoreId,
    );
    notifyListeners();
  }

  void addToCart(Map<String, dynamic> product) {
    final productId = (product['id'] as num).toInt();
    final index = cart.indexWhere((item) => item['product_id'] == productId);

    if (index >= 0) {
      cart[index]['quantity'] = (cart[index]['quantity'] as int) + 1;
    } else {
      cart.add({
        'product_id': productId,
        'name': product['name'],
        'quantity': 1,
        'bonus_quantity': 0,
        'bonus_vat_amount': 0.0,
        'discount': 0.0,
        'cost':
            ((product['cost_price'] ?? product['cost']) as num?)?.toDouble() ??
            0,
        'vat_type': product['purchase_vat_type']?.toString() ?? 'standard',
        'vat_rate': ((product['iva_rate'] as num?)?.toDouble() ?? 0) > 0
            ? (product['iva_rate'] as num).toDouble()
            : governmentVatRate,
      });
    }

    notifyListeners();
  }

  void incrementQuantity(int productId) {
    final index = cart.indexWhere((item) => item['product_id'] == productId);
    if (index < 0) return;
    cart[index]['quantity'] = (cart[index]['quantity'] as int) + 1;
    notifyListeners();
  }

  void decrementQuantity(int productId) {
    final index = cart.indexWhere((item) => item['product_id'] == productId);
    if (index < 0) return;

    final currentQty = cart[index]['quantity'] as int;
    if (currentQty <= 1) {
      cart.removeAt(index);
    } else {
      cart[index]['quantity'] = currentQty - 1;
    }
    notifyListeners();
  }

  void removeFromCart(int productId) {
    cart.removeWhere((item) => item['product_id'] == productId);
    notifyListeners();
  }

  void updateCost(int productId, double cost) {
    final index = cart.indexWhere((item) => item['product_id'] == productId);
    if (index < 0) return;
    cart[index]['cost'] = cost < 0 ? 0 : cost;
    notifyListeners();
  }

  void updateBonusQuantity(int productId, int quantity) {
    final index = cart.indexWhere((item) => item['product_id'] == productId);
    if (index < 0) return;
    cart[index]['bonus_quantity'] = quantity < 0 ? 0 : quantity;
    notifyListeners();
  }

  void updateBonusVatAmount(int productId, double amount) {
    final index = cart.indexWhere((item) => item['product_id'] == productId);
    if (index < 0) return;
    cart[index]['bonus_vat_amount'] = amount < 0 ? 0 : amount;
    notifyListeners();
  }

  void updateLineDiscount(int productId, double value) {
    final index = cart.indexWhere((item) => item['product_id'] == productId);
    if (index < 0) return;
    cart[index]['discount'] = value < 0 ? 0 : value;
    notifyListeners();
  }

  void updateLineVat(int productId, String vatType, {double? rate}) {
    final index = cart.indexWhere((item) => item['product_id'] == productId);
    if (index < 0) return;
    cart[index]['vat_type'] = vatType;
    cart[index]['vat_rate'] = rate ?? governmentVatRate;
    notifyListeners();
  }

  Future<void> createProductFromPurchase({
    required String name,
    required String sku,
    required String category,
    required String vatType,
    required double vatRate,
    required double salePrice,
  }) async {
    if (selectedStoreId == null) {
      throw Exception('Seleccione el local de ingreso.');
    }
    final productId = await DatabaseService.createProduct(
      name: name,
      sku: sku,
      categoryName: category,
      storeId: selectedStoreId,
      price: salePrice,
      ivaRate: vatType == PurchaseVatType.standard.name ? vatRate : 0,
      purchaseVatType: vatType,
    );
    DatabaseService.notifyDatabaseChanged();
    products = await DatabaseService.getProducts(storeId: selectedStoreId);
    final created = products.firstWhere(
      (product) => (product['id'] as num).toInt() == productId,
    );
    addToCart(created);
  }

  void clearCart() {
    cart.clear();
    notifyListeners();
  }

  Future<int> savePurchase({
    String? supplierName,
    String? supplierPhone,
  }) async {
    if (selectedStoreId == null) {
      throw Exception('Selecciona el local donde ingresará el stock');
    }
    if (cart.isEmpty) {
      throw Exception('Agrega productos a la compra');
    }
    final missingFields = <String>[];
    if (selectedSupplierId == null) missingFields.add('Proveedor');
    final normalizedInvoiceNumber = resolveInvoiceNumber(invoiceNumber);
    if (invoiceNumber.trim().isNotEmpty &&
        !RegExp(r'^\d{3}-\d{3}-\d{9}$').hasMatch(normalizedInvoiceNumber)) {
      missingFields.add('Número de factura (001-001-000000000)');
    }
    if (accessKey.trim().isNotEmpty) {
      final accessKeyValidation = SupplierRucValidator.validateAccessKey(
        accessKey,
      );
      if (accessKeyValidation != null) {
        missingFields.add('Clave de acceso ($accessKeyValidation)');
      }
    }
    if (paymentCondition == 'credito' && dueDate == null) {
      missingFields.add('Fecha de vencimiento');
    }
    if (physicalTotal == null) missingFields.add('Total de factura física');
    if (missingFields.isNotEmpty) {
      throw Exception(
        'Faltan campos obligatorios: ${missingFields.join(', ')}.',
      );
    }

    invoiceNumber = normalizedInvoiceNumber;

    final resolvedAccessKey = accessKey.trim();
    final resolvedTaxSupportCode = taxSupportCode.trim();

    final purchaseId = await DatabaseService.registerPurchase(
      storeId: selectedStoreId!,
      supplierId: selectedSupplierId,
      supplierName: supplierName,
      supplierPhone: supplierPhone,
      vatRate: appliedVatRate,
      discount: discount,
      invoiceNumber: invoiceNumber,
      auxiliaryInvoiceNumber: auxiliaryInvoiceNumber,
      accessKey: resolvedAccessKey.isEmpty ? null : resolvedAccessKey,
      issueDate: issueDate,
      paymentCondition: paymentCondition,
      dueDate: dueDate,
      taxSupportCode: resolvedTaxSupportCode.isEmpty
          ? null
          : resolvedTaxSupportCode,
      physicalTotal: physicalTotal,
      paymentMethod: selectedPaymentMethodName,
      withholdings: withholdings,
      withholdingAuthorization: withholdingAuthorization,
      items: cart
          .map(
            (item) => {
              'product_id': item['product_id'],
              'quantity': item['quantity'],
              'bonus_quantity': item['bonus_quantity'],
              'bonus_vat_amount': item['bonus_vat_amount'],
              'discount': item['discount'],
              'cost': item['cost'],
              'vat_type': item['vat_type'],
              'vat_rate': item['vat_rate'],
            },
          )
          .toList(),
    );

    final supplierNameForAudit = suppliers
        .where(
          (supplier) => (supplier['id'] as num).toInt() == selectedSupplierId,
        )
        .map((supplier) => supplier['name']?.toString())
        .firstOrNull;
    await AuditService.log(
      action: AuditAction.createPurchase,
      module: 'Purchases',
      page: 'PurchasesView',
      entity: 'purchase',
      entityId: purchaseId,
      newData: {
        'purchase_id': purchaseId,
        'products': cart,
        'supplier': supplierNameForAudit ?? supplierName,
        'supplier_id': selectedSupplierId,
        'payment_method': selectedPaymentMethodName,
      },
      controller: 'PurchasesController',
    );

    cart.clear();
    selectedSupplierId = null;
    invoiceNumber = '';
    auxiliaryInvoiceNumber = '';
    accessKey = '';
    issueDate = DateTime.now();
    paymentCondition = 'contado';
    dueDate = null;
    taxSupportCode = '';
    physicalTotal = null;
    withholdings = [];
    withholdingAuthorization = '';
    DatabaseService.notifyDatabaseChanged();
    suppliers = await DatabaseService.getSuppliers();
    await _loadProducts();
    await loadPurchaseHistory();
    await ensureInvoiceNumber();
    return purchaseId;
  }

  Future<void> selectHistorySupplier(int? supplierId) async {
    historySupplierId = supplierId;
    await loadPurchaseHistory();
  }

  Future<void> selectHistoryPeriod(PurchaseHistoryPeriod period) async {
    historyPeriod = period;
    historyDate = null;
    historyFromDate = null;
    historyToDate = null;
    await loadPurchaseHistory();
  }

  Future<void> selectHistoryCategory(String? category) async {
    historyCategory = category;
    await loadPurchaseHistory();
  }

  Future<void> setHistoryDate(DateTime? value) async {
    historyDate = value;
    historyPeriod = PurchaseHistoryPeriod.all;
    historyFromDate = null;
    historyToDate = null;
    await loadPurchaseHistory();
  }

  Future<void> setHistoryDateRange({DateTime? from, DateTime? to}) async {
    if (from != null && to != null && to.isBefore(from)) {
      throw ArgumentError(
        'La fecha final debe ser igual o posterior a la inicial.',
      );
    }
    historyDate = null;
    historyPeriod = PurchaseHistoryPeriod.all;
    historyFromDate = from;
    historyToDate = to;
    await loadPurchaseHistory();
  }

  Future<void> updateHistorySearch(String value) async {
    historySearch = value;
    await loadPurchaseHistory();
  }

  Future<void> clearHistoryFilters() async {
    historySupplierId = null;
    historyCategory = null;
    historyDate = null;
    historyFromDate = null;
    historyToDate = null;
    historySearch = '';
    historyPeriod = PurchaseHistoryPeriod.all;
    await loadPurchaseHistory();
  }

  Future<void> loadPurchaseHistory() async {
    final requestSequence = ++_historyRequestSequence;
    isHistoryLoading = true;
    notifyListeners();

    try {
      final now = DateTime.now();
      DateTime? fromDate;
      DateTime? toDate;
      switch (historyPeriod) {
        case PurchaseHistoryPeriod.all:
          break;
        case PurchaseHistoryPeriod.today:
          fromDate = DateTime(now.year, now.month, now.day);
          toDate = fromDate.add(const Duration(days: 1));
        case PurchaseHistoryPeriod.week:
          final dayStart = DateTime(now.year, now.month, now.day);
          fromDate = dayStart.subtract(Duration(days: dayStart.weekday - 1));
          toDate = fromDate.add(const Duration(days: 7));
        case PurchaseHistoryPeriod.month:
          fromDate = DateTime(now.year, now.month);
          toDate = DateTime(now.year, now.month + 1);
      }
      if (historyFromDate != null) {
        fromDate = DateTime(
          historyFromDate!.year,
          historyFromDate!.month,
          historyFromDate!.day,
        );
      }
      if (historyToDate != null) {
        toDate = DateTime(
          historyToDate!.year,
          historyToDate!.month,
          historyToDate!.day + 1,
        );
      }
      final results = await DatabaseService.getPurchaseHistory(
        storeId: selectedStoreId,
        supplierId: historySupplierId,
        category: historyCategory,
        date: historyDate,
        fromDate: fromDate,
        toDate: toDate,
        search: historySearch,
      );
      if (requestSequence != _historyRequestSequence) return;
      purchaseHistory = results;
      errorMessage = null;
    } catch (e) {
      if (requestSequence == _historyRequestSequence) {
        errorMessage = 'No se pudo cargar el historial de compras: $e';
      }
    } finally {
      if (requestSequence == _historyRequestSequence) {
        isHistoryLoading = false;
        notifyListeners();
      }
    }
  }

  Future<List<Map<String, dynamic>>> getPurchaseItems(int purchaseId) {
    return DatabaseService.getPurchaseItems(purchaseId);
  }

  Future<void> cancelPurchase({
    required int purchaseId,
    required String creditNoteNumber,
    required String accessKey,
    required DateTime issueDate,
    required String reason,
  }) async {
    await DatabaseService.cancelPurchase(
      purchaseId: purchaseId,
      creditNoteNumber: creditNoteNumber,
      accessKey: accessKey,
      issueDate: issueDate,
      reason: reason,
    );
    await AuditService.log(
      action: AuditAction.cancelPurchase,
      module: 'Purchases',
      page: 'PurchaseHistory',
      entity: 'purchase',
      entityId: purchaseId,
      newData: {'credit_note_number': creditNoteNumber, 'reason': reason},
      controller: 'PurchasesController',
    );
    await loadPurchaseHistory();
  }

  Future<void> payPurchaseBalance({
    required int purchaseId,
    required double amount,
    required String paymentMethod,
    String? reference,
  }) async {
    await DatabaseService.payPurchasePayable(
      purchaseId: purchaseId,
      amount: amount,
      paymentMethod: paymentMethod,
      reference: reference,
    );
    await AuditService.log(
      action: AuditAction.cashExpense,
      module: 'AccountsPayable',
      page: 'PurchaseHistory',
      entity: 'purchase',
      entityId: purchaseId,
      newData: {
        'amount': amount,
        'payment_method': paymentMethod,
        'reference': reference,
      },
      controller: 'PurchasesController',
    );
    await loadPurchaseHistory();
  }
}
