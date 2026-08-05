import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tienda/Presentation/View/Login/Login.dart';
import 'package:tienda/Presentation/View/Customers/customers_view.dart';
import 'package:tienda/Presentation/View/Cash/cash_view.dart';
import 'package:tienda/Presentation/View/Dashboard/dashboard_page.dart';
import 'package:tienda/Presentation/View/Inventory/inventory_view.dart';
import 'package:tienda/Presentation/View/POS/pos_view.dart';
import 'package:tienda/Presentation/View/Product/product_management_view.dart';
import 'package:tienda/Presentation/View/Purchases/purchases_view.dart';
import 'package:tienda/Presentation/View/Reports/reports_view.dart';
import 'package:tienda/Presentation/View/Users/users_view.dart';
import 'package:tienda/Presentation/View/Suppliers/suppliers_view.dart';
import 'package:tienda/Presentation/Widgets/legal_page_widget.dart';

class AppRoutes {
  // --- Rutas Públicas ---
  static const login = '/login';
  static const register = '/register';
  static const authenticate = '/authenticate';
  static const contracts = '/contracts';

  // --- Rutas de la aplicación ---
  static const dashboard = '/dashboard';
  static const pos = '/pos';
  static const products = '/products';
  static const purchases = '/purchases';
  static const inventory = '/inventory';
  static const customers = '/customers';
  static const reports = '/reports';
  static const cash = '/cash';
  static const users = '/users';
  static const suppliers = '/suppliers';
  static const adminDb = '/admin-db';
  static const catalog = '/catalog';
  static const terms = '/terms';
  static const privacy = '/privacy';

  /// Todas las rutas registradas
  static final routes = <String, WidgetBuilder>{
    login: (context) => const LoginPage(),
    dashboard: (context) => const DashboardPage(),
    pos: (context) => const PosView(),
    products: (context) => const ProductManagementView(),
    purchases: (context) => const PurchasesView(),
    inventory: (context) => const InventoryView(),
    customers: (context) => const CustomersView(),
    reports: (context) => const ReportsView(),
    cash: (context) => const CashView(),
    users: (context) => const UsersView(),
    suppliers: (context) => const SuppliersView(),

    terms: (context) => const LegalPageWidget(type: LegalDocType.terms),
    privacy: (context) => const LegalPageWidget(type: LegalDocType.privacy),
  };

  /// Map de roles con rutas permitidas
  static final Map<String, List<String>> allowedRoutesByRole = {
    // Admin Superior: acceso total
    'admin_superior': [
      login,
      register,
      authenticate,
      contracts,
      dashboard,
      pos,
      products,
      purchases,
      inventory,
      customers,
      reports,
      cash,
      users,
      suppliers,
      adminDb,
    ],
    // Administrador: sin gestión de usuarios
    'administrador': [
      login,
      authenticate,
      dashboard,
      pos,
      products,
      purchases,
      inventory,
      customers,
      reports,
      cash,
      suppliers,
    ],
    // Cajero: solo ventas
    'cajero': [login, authenticate, dashboard, pos, customers, cash],
    // Compatibilidad con rol 'admin' antiguo
    'admin': [
      login,
      register,
      authenticate,
      contracts,
      dashboard,
      pos,
      products,
      purchases,
      inventory,
      customers,
      reports,
      cash,
      users,
      suppliers,
      adminDb,
    ],
  };

  /// Obtiene las rutas permitidas para un rol específico
  static List<String> getRoutesForRole(String role) {
    return allowedRoutesByRole[role] ?? [login];
  }
}
