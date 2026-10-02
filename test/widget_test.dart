import 'package:tienda/Presentation/Controller/customers_controller.dart';
import 'package:tienda/Presentation/Controller/pos_controller.dart';
import 'package:tienda/Presentation/Controller/product_management_controller.dart';
import 'package:tienda/Presentation/Controller/purchases_controller.dart';
import 'package:tienda/Presentation/Controller/reports_controller.dart';
import 'package:tienda/Presentation/View/Customers/customers_view.dart';
import 'package:tienda/Presentation/View/POS/pos_view.dart';
import 'package:tienda/Presentation/View/Product/product_management_view.dart';
import 'package:tienda/Presentation/View/Purchases/purchases_view.dart';
import 'package:tienda/Presentation/View/Reports/reports_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('muestra el catálogo y permite abrir el formulario', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ProductManagementController(),
        child: const MaterialApp(home: ProductManagementView()),
      ),
    );

    await tester.pump();

    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.text('Productos'),
      ),
      findsOneWidget,
    );
    expect(find.byTooltip('Nuevo producto'), findsOneWidget);

    await tester.tap(find.byTooltip('Nuevo producto'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Nuevo producto'), findsOneWidget);
    expect(find.text('Nombre del producto'), findsOneWidget);
    expect(find.text('Precio de venta'), findsOneWidget);
  });

  testWidgets('muestra el módulo de ventas con tabs', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => PosController(),
        child: const MaterialApp(home: PosView()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Sistema de Ventas'), findsOneWidget);
    expect(find.text('Venta 1'), findsOneWidget);
    expect(find.text('Historial'), findsOneWidget);
    expect(find.byTooltip('Nueva venta · ESC'), findsOneWidget);
  });

  testWidgets('muestra el módulo de compras con tabs', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => PurchasesController(),
        child: const MaterialApp(home: PurchasesView()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Compras · Abastecimiento'), findsOneWidget);
    expect(find.text('Nueva compra'), findsOneWidget);
    expect(find.text('Historial de compras'), findsOneWidget);
  });

  testWidgets('muestra la pantalla de clientes', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => CustomersController(),
        child: const MaterialApp(home: CustomersView()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Clientes'), findsOneWidget);
    expect(find.text('Nuevo'), findsOneWidget);
  });

  testWidgets('muestra la pantalla de reportes', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ReportsController(),
        child: const MaterialApp(home: ReportsView()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Reportes comerciales'), findsOneWidget);
    expect(find.text('Ventas por local'), findsOneWidget);
  });
}
