import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart' as shelf_ws;
import 'package:tienda/Presentation/Services/database_service.dart';
import 'package:tienda/Presentation/Services/auth_service.dart';
import 'package:tienda/Presentation/Services/image_storage_service.dart';
import 'package:tienda/core/app_config.dart';
import 'package:tienda/core/app_logger.dart';
import 'package:tienda/runtime/ui_runtime.dart';
import 'package:tienda/server/local_server_event_bus.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class LocalServerHost {
  static HttpServer? _server;
  static bool _started = false;

  static void _onDatabaseChanged() {
    LocalServerEventBus.instance.emit(
      const LocalServerEvent(type: 'database_changed', payload: {}),
    );
  }

  static Future<void> start() async {
    if (_started || _server != null) return;

    final router = Router();

    router.get('/health', (shelf.Request request) {
      return _jsonResponse({'status': 'ok', 'service': 'tienda-local-server'});
    });

    router.get('/version', (shelf.Request request) {
      return _jsonResponse({'version': AppConfig.appVersion});
    });

    router.get('/api/version', (shelf.Request request) {
      return _jsonResponse({'version': AppConfig.appVersion});
    });

    Future<shelf.Response> getProducts(shelf.Request request) async {
      final search = request.url.queryParameters['search'] ?? '';
      final storeId = int.tryParse(
        request.url.queryParameters['storeId'] ?? '',
      );
      final category = request.url.queryParameters['category'];
      final rows = await DatabaseService.getProducts(
        search: search,
        storeId: storeId,
        category: category,
      );
      return _jsonResponse(rows);
    }

    router.get('/products', getProducts);
    router.get('/api/products', getProducts);

    Future<shelf.Response> getCustomers(shelf.Request request) async {
      final search = request.url.queryParameters['search'] ?? '';
      final rows = await DatabaseService.getCustomers(search: search);
      return _jsonResponse(rows);
    }

    router.get('/customers', getCustomers);
    router.get('/api/customers', getCustomers);

    Future<shelf.Response> getStores(shelf.Request request) async {
      return _jsonResponse(await DatabaseService.getStores());
    }

    router.get('/stores', getStores);
    router.get('/api/stores', getStores);

    Future<shelf.Response> getCategories(shelf.Request request) async {
      return _jsonResponse(await DatabaseService.getCategories());
    }

    router.get('/categories', getCategories);
    router.get('/api/categories', getCategories);

    Future<shelf.Response> getSales(shelf.Request request) async {
      final storeId = int.tryParse(
        request.url.queryParameters['storeId'] ?? '',
      );
      final customerId = int.tryParse(
        request.url.queryParameters['customerId'] ?? '',
      );
      final year = int.tryParse(request.url.queryParameters['year'] ?? '');
      final month = int.tryParse(request.url.queryParameters['month'] ?? '');
      final day = int.tryParse(request.url.queryParameters['day'] ?? '');
      final rows = await DatabaseService.getSalesHistory(
        storeId: storeId,
        customerId: customerId,
        year: year,
        month: month,
        day: day,
      );
      return _jsonResponse(rows);
    }

    router.get('/sales', getSales);
    router.get('/api/sales', getSales);

    Future<shelf.Response> getDashboard(shelf.Request request) async {
      final rows = await DatabaseService.getReportsSnapshot();
      return _jsonResponse(rows);
    }

    router.get('/dashboard', getDashboard);
    router.get('/api/dashboard', getDashboard);
    router.get('/api/reports', getDashboard);

    Future<shelf.Response> getUsers(shelf.Request request) async {
      final rows = await DatabaseService.rawQuery(
        'SELECT * FROM users ORDER BY name ASC',
      );
      return _jsonResponse(rows);
    }

    router.get('/users', getUsers);
    router.get('/api/users', getUsers);

    Future<shelf.Response> login(shelf.Request request) async {
      final body = await _readJson(request);
      final user = await AuthService().login(
        body['email']?.toString() ?? '',
        body['password']?.toString() ?? '',
      );
      if (user == null) {
        return _jsonResponse({'ok': false}, statusCode: 401);
      }
      return _jsonResponse({'ok': true, 'user': user});
    }

    router.post('/login', login);
    router.post('/api/login', login);

    Future<shelf.Response> createProduct(shelf.Request request) async {
      final body = await _readJson(request);
      await DatabaseService.createProduct(
        name: body['name']?.toString() ?? '',
        price: (body['price'] as num?)?.toDouble() ?? 0,
        costPrice: (body['costPrice'] as num?)?.toDouble() ?? 0,
        sku: body['sku']?.toString(),
        auxCode: body['auxCode']?.toString(),
        description: body['description']?.toString(),
        tags: body['tags']?.toString(),
        storeId:
            body['storeId'] is num ? (body['storeId'] as num).toInt() : null,
        categoryName: body['categoryName']?.toString(),
        images: List<String>.from(body['images'] ?? const []),
        initialStock: _intMap(body['initialStock']),
      );
      LocalServerEventBus.instance.emit(
        const LocalServerEvent(type: 'inventory_changed', payload: {}),
      );
      return _jsonResponse({'ok': true});
    }

    router.post('/products', createProduct);
    router.post('/api/products', createProduct);

    Future<shelf.Response> registerSale(shelf.Request request) async {
      final body = await _readJson(request);
      final items = List<Map<String, dynamic>>.from(
        (body['items'] as List<dynamic>? ?? []).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
      final payments = List<Map<String, dynamic>>.from(
        (body['payments'] as List<dynamic>? ?? []).map(
          (e) => Map<String, dynamic>.from(e as Map),
        ),
      );
      final saleId = await DatabaseService.registerSaleWithPayments(
        storeId: (body['storeId'] as num?)?.toInt() ?? 1,
        items: items,
        payments: payments,
        clientId: (body['clientId'] as num?)?.toInt(),
        sessionId: (body['sessionId'] as num?)?.toInt(),
        isCredit: body['isCredit'] == true,
      );
      LocalServerEventBus.instance.emit(
        LocalServerEvent(type: 'sale_registered', payload: {'saleId': saleId}),
      );
      return _jsonResponse({'saleId': saleId});
    }

    router.post('/sales', registerSale);
    router.post('/api/sales', registerSale);

    Future<shelf.Response> updateProduct(shelf.Request request) async {
      final id = int.parse(request.params['id']!);
      final body = await _readJson(request);
      final previousImages = await DatabaseService.getProductImageIds(id);
      final images = body['images'] == null
          ? null
          : List<String>.from(body['images'] as List);
      await DatabaseService.updateProduct(
        productId: id,
        name: body['name']?.toString() ?? '',
        categoryName: body['categoryName']?.toString() ?? '',
        sku: body['sku']?.toString() ?? '',
        price: (body['price'] as num?)?.toDouble() ?? 0,
        costPrice: (body['costPrice'] as num?)?.toDouble() ?? 0,
        ivaRate: (body['ivaRate'] as num?)?.toDouble() ?? 0,
        profitIva: (body['profitIva'] as num?)?.toDouble() ?? 0,
        auxCode: body['auxCode']?.toString(),
        description: body['description']?.toString(),
        tags: body['tags']?.toString(),
        storeId:
            body['storeId'] is num ? (body['storeId'] as num).toInt() : null,
        images: images,
      );
      if (images != null) {
        for (final imagePath in previousImages.where(
          (item) => !images.contains(item),
        )) {
          await ImageStorageService.deleteImage(imagePath);
        }
      }
      for (final entry in _intMap(body['stockByStore']).entries) {
        await DatabaseService.updateInventoryStock(
          productId: id,
          storeId: entry.key,
          stock: entry.value,
        );
      }
      LocalServerEventBus.instance.emit(
        const LocalServerEvent(type: 'inventory_changed', payload: {}),
      );
      return _jsonResponse({'ok': true});
    }

    router.put('/products/:id', updateProduct);
    router.put('/api/products/:id', updateProduct);

    Future<shelf.Response> getProductImages(shelf.Request request) async {
      final id = int.parse(request.params['id']!);
      return _jsonResponse(await DatabaseService.getProductImageIds(id));
    }

    router.get('/products/:id/images', getProductImages);
    router.get('/api/products/:id/images', getProductImages);

    Future<shelf.Response> removeProductImage(shelf.Request request) async {
      final id = int.parse(request.params['id']!);
      final body = await _readJson(request);
      final imageRef = body['imageRef']?.toString().trim() ?? '';
      if (imageRef.isEmpty) {
        return _jsonResponse({'ok': false}, statusCode: 400);
      }
      final currentIds = await DatabaseService.getProductImageIds(id);
      if (currentIds.contains(imageRef)) {
        await DatabaseService.updateProductImages(
          productId: id,
          imageIds: currentIds.where((item) => item != imageRef).toList(),
        );
        await ImageStorageService.deleteImage(imageRef);
        LocalServerEventBus.instance.emit(
          const LocalServerEvent(type: 'inventory_changed', payload: {}),
        );
      }
      return _jsonResponse({'ok': true});
    }

    router.put('/products/:id/images', removeProductImage);
    router.put('/api/products/:id/images', removeProductImage);

    Future<shelf.Response> deleteProduct(shelf.Request request) async {
      final id = int.parse(request.params['id']!);
      final imagePaths = await DatabaseService.getProductImageIds(id);
      await DatabaseService.deleteProduct(id);
      for (final imagePath in imagePaths) {
        await ImageStorageService.deleteImage(imagePath);
      }
      LocalServerEventBus.instance.emit(
        const LocalServerEvent(type: 'inventory_changed', payload: {}),
      );
      return _jsonResponse({'ok': true});
    }

    router.delete('/products/:id', deleteProduct);
    router.delete('/api/products/:id', deleteProduct);

    router.get(
      '/ws',
      shelf_ws.webSocketHandler((
        WebSocketChannel webSocket,
        String? subprotocol,
      ) {
        final subscription = LocalServerEventBus.instance.stream.listen((
          event,
        ) {
          webSocket.sink.add(jsonEncode(event.toJson()));
        });
        webSocket.stream.listen((message) {
          if (message is String) {
            final decoded = jsonDecode(message);
            if (decoded is Map<String, dynamic> && decoded['type'] == 'ping') {
              webSocket.sink.add(jsonEncode({'type': 'pong'}));
            }
          }
        }, onDone: () => subscription.cancel());
      }),
    );

    final uiDirectory = await UiRuntime.uiDirectory();
    final apiHandler = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addHandler(router.call);
    final uiHandler = createStaticHandler(
      uiDirectory.path,
      defaultDocument: 'index.html',
      serveFilesOutsidePath: false,
    );
    final handler = shelf.Cascade().add(apiHandler).add(uiHandler).handler;
    _server = await shelf_io.serve(
      handler,
      AppConfig.serverHost,
      AppConfig.serverPort,
    );
    _started = true;
    DatabaseService.addDatabaseListener(_onDatabaseChanged);
    AppLogger.log(
      'Servidor local iniciado en ${AppConfig.serverHost}:${AppConfig.serverPort}',
    );
  }

  static Future<void> stop() async {
    if (_server != null) {
      DatabaseService.removeDatabaseListener(_onDatabaseChanged);
      await _server!.close(force: true);
      _server = null;
      _started = false;
    }
  }

  static bool get isRunning => _started && _server != null;
}

Future<shelf.Response> _jsonResponse(
  Object data, {
  int statusCode = 200,
}) async {
  return shelf.Response(
    statusCode,
    body: jsonEncode(data),
    headers: const {'content-type': 'application/json'},
  );
}

Future<Map<String, dynamic>> _readJson(shelf.Request request) async {
  final body = await request.readAsString();
  if (body.isEmpty) return <String, dynamic>{};
  return jsonDecode(body) as Map<String, dynamic>;
}

Map<int, int> _intMap(Object? value) {
  if (value is! Map) return const {};
  return value.map(
    (key, item) => MapEntry(
      int.parse(key.toString()),
      (item as num).toInt(),
    ),
  );
}
