import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'product_provider.dart';
import 'customer_provider.dart';
import 'sale_provider.dart';
import 'purchase_provider.dart';
import 'inventory_provider.dart';
import 'reports_provider.dart';
import 'analytics_provider.dart';
import 'package:tienda/Presentation/Controller/users_controller.dart';
import 'package:tienda/Presentation/Controller/suppliers_controller.dart';

/// Centro de control de todos los Providers
/// Usar en main.dart con MultiProvider
class AppProviders {
  static List<SingleChildWidget> getProviders() => [
    ChangeNotifierProvider<ProductProvider>(create: (_) => ProductProvider()),
    ChangeNotifierProvider<CustomerProvider>(create: (_) => CustomerProvider()),
    ChangeNotifierProvider<SaleProvider>(create: (_) => SaleProvider()),
    ChangeNotifierProvider<PurchaseProvider>(create: (_) => PurchaseProvider()),
    ChangeNotifierProvider<InventoryProvider>(
      create: (_) => InventoryProvider(),
    ),
    ChangeNotifierProvider<ReportsProvider>(create: (_) => ReportsProvider()),
    ChangeNotifierProvider<UsersController>(create: (_) => UsersController()),
    ChangeNotifierProvider<SuppliersController>(
      create: (_) => SuppliersController(),
    ),
    // OLAP Analytics — capa Big Data
    ChangeNotifierProvider<AnalyticsProvider>(
      create: (_) => AnalyticsProvider(),
    ),
  ];
}

/// Para acceder fácilmente desde las vistas
extension ProviderAccess on BuildContext {
  ProductProvider get productProvider => read<ProductProvider>();

  CustomerProvider get customerProvider => read<CustomerProvider>();

  SaleProvider get saleProvider => read<SaleProvider>();

  PurchaseProvider get purchaseProvider => read<PurchaseProvider>();

  InventoryProvider get inventoryProvider => read<InventoryProvider>();

  ReportsProvider get reportsProvider => read<ReportsProvider>();

  // Watchers (para rebuild automático)
  ProductProvider watchProductProvider() => watch<ProductProvider>();

  CustomerProvider watchCustomerProvider() => watch<CustomerProvider>();

  SaleProvider watchSaleProvider() => watch<SaleProvider>();

  PurchaseProvider watchPurchaseProvider() => watch<PurchaseProvider>();

  InventoryProvider watchInventoryProvider() => watch<InventoryProvider>();

  ReportsProvider watchReportsProvider() => watch<ReportsProvider>();
}
