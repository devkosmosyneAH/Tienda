import 'dart:io';
import 'package:tienda/Presentation/View/Auth/app_routes.dart';
import 'package:tienda/Presentation/Services/auth_service.dart';
import 'package:tienda/Presentation/Services/database_service.dart';
import 'package:tienda/Presentation/Services/background_job_service.dart';
import 'package:tienda/Presentation/Services/database_maintenance_service.dart';
import 'package:tienda/Presentation/Services/database_config.dart';
import 'package:tienda/Presentation/Services/database_location_service.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:tienda/Presentation/display/database_initializer_native.dart';
import 'package:tienda/Presentation/display/window_manager_initializer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:tienda/Presentation/Controller/Catalog/catalog_controller.dart';
import 'package:tienda/Presentation/View/Catalog/catalog_repository.dart';
import 'package:tienda/Presentation/View/Catalog/drive_catalog_repository.dart';
import 'package:tienda/Presentation/View/Catalog/catalog_router.dart';
import 'package:tienda/Presentation/Controller/auth_provider.dart';
import 'package:tienda/Presentation/Controller/product_management_controller.dart';
import 'package:tienda/Presentation/Controller/cash_controller.dart';
import 'package:tienda/Presentation/Controller/customers_controller.dart';
import 'package:tienda/Presentation/Controller/pos_controller.dart';
import 'package:tienda/Presentation/Controller/purchases_controller.dart';
import 'package:tienda/Presentation/Controller/reports_controller.dart';
import 'package:tienda/Presentation/Context/providers.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:tienda/Presentation/Services/catalog_sync_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Removida la variable global no utilizada que puede causar problemas
// late MyDatabase driftDatabase; // ❌ COMENTADA PARA EVITAR SIGSEGV

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: "assets/env.txt");

  // 🌍 INICIALIZAR LOCALIZACIÓN PARA FECHAS
  await initializeDateFormatting('es', null);

  // 🖥️ CONFIGURAR TAMAÑO DE VENTANA PARA DESKTOP
  // Inicializadores por plataforma (nativa / web)
  await initializeWindowManager();
  if (!kIsWeb) {
    await initializeDatabasePlatform();
  }

  // 🗄️ INICIALIZAR BASE DE DATOS DE FORMA SEGURA
  await _initDatabaseSafely();

  if (!kIsWeb) {
    final appSupportDirectory = await getApplicationSupportDirectory();
    CatalogSyncService.initialize(
      exportDir: p.join(appSupportDirectory.path, 'catalog'),
      gitRepoPath: appSupportDirectory.path,
      dataDir: appSupportDirectory.path,
    );
  }

  // 🔄 INICIAR MOTOR DE BACKGROUND JOBS + MANTENIMIENTO (OLAP analytics)
  if (!kIsWeb) {
    final jobService = BackgroundJobService();
    jobService.start();
    await jobService.scheduleDailyMaintenance();

    // 🛠️ Motor de mantenimiento SQLite enterprise (cada 6h)
    DatabaseMaintenanceService().startPeriodicMaintenance(intervalHours: 6);
  }

  // 🌐 Web: siempre muestra el catálogo público, sin autenticación
  if (kIsWeb) {
    final controller = CatalogController(
      repository: CatalogRepository(
        driveRepository: const DriveCatalogRepository(),
      ),
    );
    final router = CatalogRouter.createRouter(controller: controller);
    runApp(WebCatalogApp(router: router));
    return;
  }

  // 🖥️ Desktop / Móvil: flujo normal con login
  try {
    final authService = AuthService();
    final isLoggedIn = await authService.isLoggedIn();

    final initialRoute = isLoggedIn ? AppRoutes.dashboard : AppRoutes.login;

    runApp(MyApp(initialRoute: initialRoute));
  } catch (e) {
    runApp(MyApp(initialRoute: AppRoutes.login));
  }
}

// 🛡️ INICIALIZACIÓN SEGURA DE BASE DE DATOS
Future<void> _initDatabaseSafely() async {
  if (kIsWeb) return; // Web no usa SQLite local
  try {
    // Para iOS/Android, usar el DatabaseService compartido.
    if (Platform.isIOS || Platform.isAndroid) {
      await DatabaseService.database;
    } else {
      await DatabaseService.database;
    }
  } catch (e) {
    // Intentar método fallback más seguro
    await _safeFallbackDatabaseInit();
  }
}

// 🔧 MÉTODO FALLBACK MEJORADO Y SEGURO

Future<void> _safeFallbackDatabaseInit() async {
  if (kIsWeb) return; // Web no usa SQLite local
  try {
    final dbPath = await DatabaseLocationService.getDatabasePath();
    final File dbFile = File(dbPath);

    if (await dbFile.exists()) {
      try {
        debugPrint('Opening database:');
        debugPrint(dbPath);
        await DatabaseService.database;
        return;
      } catch (e) {
        await dbFile.delete();
      }
    }

    try {
      final ByteData data = await rootBundle.load(DatabaseConfig.assetDbPath);
      final List<int> bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

      await dbFile.writeAsBytes(bytes, flush: true);
      debugPrint('Opening database:');
      debugPrint(dbPath);
      await DatabaseService.database;
    } catch (e) {
      throw Exception('No se pudo inicializar la base de datos');
    }
  } catch (e) {
    // En este punto, la app continuará pero sin base de datos prepoblada
  }
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProductManagementController()),
        ChangeNotifierProvider(create: (_) => CashController()),
        ChangeNotifierProvider(create: (_) => PosController()),
        ChangeNotifierProvider(create: (_) => PurchasesController()),
        ChangeNotifierProvider(create: (_) => CustomersController()),
        ChangeNotifierProvider(create: (_) => ReportsController()),
        // Providers de contexto
        ...AppProviders.getProviders(),
      ],
      child: MaterialApp(
        title: 'Tienda',
        theme: ThemeData(
          primaryColor: AppColors.primaryLogo,
          useMaterial3: true,
        ),
        initialRoute: initialRoute,
        onGenerateRoute: (settings) {
          final builder = AppRoutes.routes[settings.name];
          if (builder == null) return null;
          return MaterialPageRoute(
            settings: settings,
            builder: (ctx) => SelectionArea(child: builder(ctx)),
          );
        },
        debugShowCheckedModeBanner: false,
        navigatorKey: navigatorKey,
      ),
    );
  }
}

class WebCatalogApp extends StatelessWidget {
  final GoRouter router;

  const WebCatalogApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProductManagementController()),
        ChangeNotifierProvider(create: (_) => CashController()),
        ChangeNotifierProvider(create: (_) => PosController()),
        ChangeNotifierProvider(create: (_) => PurchasesController()),
        ChangeNotifierProvider(create: (_) => CustomersController()),
        ChangeNotifierProvider(create: (_) => ReportsController()),
        ...AppProviders.getProviders(),
      ],
      child: MaterialApp.router(
        title: 'Tienda',
        theme: ThemeData(
          primaryColor: AppColors.primaryLogo,
          useMaterial3: true,
        ),
        debugShowCheckedModeBanner: false,
        routerConfig: router,
      ),
    );
  }
}
