import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:tienda/core/app_config.dart';
import 'package:tienda/core/app_logger.dart';
import 'package:tienda/Presentation/Services/database_service.dart';
import 'package:tienda/server/local_server_event_bus.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart' as shelf_ws;
import 'package:web_socket_channel/web_socket_channel.dart';

class LocalServerHost {
  static HttpServer? _server;
  static bool _started = false;

  static Future<void> start() async {
    if (_started || _server != null) return;

    final router = Router();

    router.get('/health', (shelf.Request request) {
      return shelf.Response.ok(
        jsonEncode({'status': 'ok', 'service': 'tienda-local-server'}),
        headers: {'content-type': 'application/json'},
      );
    });

    router.get('/api/products', (shelf.Request request) async {
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
    });

    router.get('/api/customers', (shelf.Request request) async {
      final search = request.url.queryParameters['search'] ?? '';
      final rows = await DatabaseService.getCustomers(search: search);
      return _jsonResponse(rows);
    });

    router.get('/api/sales', (shelf.Request request) async {
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
    });

    router.get('/api/reports', (shelf.Request request) async {
      final rows = await DatabaseService.getReportsSnapshot();
      return _jsonResponse(rows);
    });

    router.get('/api/dashboard', (shelf.Request request) async {
      final rows = await DatabaseService.getReportsSnapshot();
      return _jsonResponse(rows);
    });

    router.get('/api/users', (shelf.Request request) async {
      final rows = await DatabaseService.rawQuery(
        'SELECT * FROM users ORDER BY name ASC',
      );
      return _jsonResponse(rows);
    });

    router.post('/api/products', (shelf.Request request) async {
      final body = await _readJson(request);
      await DatabaseService.createProduct(
        name: body['name']?.toString() ?? '',
        price: (body['price'] as num?)?.toDouble() ?? 0,
        costPrice: (body['costPrice'] as num?)?.toDouble() ?? 0,
        sku: body['sku']?.toString(),
        auxCode: body['auxCode']?.toString(),
        description: body['description']?.toString(),
        tags: body['tags']?.toString(),
        storeId: body['storeId'] as int?,
        categoryName: body['categoryName']?.toString(),
        images: List<String>.from(body['images'] ?? const []),
      );
      LocalServerEventBus.instance.emit(
        const LocalServerEvent(type: 'inventory_changed', payload: {}),
      );
      return shelf.Response.ok(
        jsonEncode({'ok': true}),
        headers: {'content-type': 'application/json'},
      );
    });

    router.post('/api/sales', (shelf.Request request) async {
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
    });

    router.put('/api/products/:id', (shelf.Request request) async {
      final id = int.parse(request.params['id']!);
      final body = await _readJson(request);
      await DatabaseService.updateProduct(
        productId: id,
        name: body['name']?.toString() ?? '',
        categoryName: body['categoryName']?.toString() ?? '',
        sku: body['sku']?.toString() ?? '',
        price: (body['price'] as num?)?.toDouble() ?? 0,
        costPrice: (body['costPrice'] as num?)?.toDouble() ?? 0,
        auxCode: body['auxCode']?.toString(),
        description: body['description']?.toString(),
        tags: body['tags']?.toString(),
        storeId: body['storeId'] as int?,
        images: List<String>.from(body['images'] ?? const []),
      );
      LocalServerEventBus.instance.emit(
        const LocalServerEvent(type: 'inventory_changed', payload: {}),
      );
      return shelf.Response.ok(
        jsonEncode({'ok': true}),
        headers: {'content-type': 'application/json'},
      );
    });

    router.delete('/api/products/:id', (shelf.Request request) async {
      final id = int.parse(request.params['id']!);
      await DatabaseService.deleteProduct(id);
      LocalServerEventBus.instance.emit(
        const LocalServerEvent(type: 'inventory_changed', payload: {}),
      );
      return shelf.Response.ok(
        jsonEncode({'ok': true}),
        headers: {'content-type': 'application/json'},
      );
    });

    final handler = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addHandler(router.call);

    final wsHandler = shelf_ws.webSocketHandler((
      WebSocketChannel webSocket,
      String? subprotocol,
    ) {
      final subscription = LocalServerEventBus.instance.stream.listen((event) {
        webSocket.sink.add(jsonEncode(event.toJson()));
      });
      webSocket.stream.listen((message) {
        if (message is String) {
          final decoded = jsonDecode(message);
          if (decoded['type'] == 'ping') {
            webSocket.sink.add(jsonEncode({'type': 'pong'}));
          }
        }
      }, onDone: () => subscription.cancel());
    });

    final cascade = shelf.Cascade().add(handler).add(wsHandler).handler;
    _server = await shelf_io.serve(
      cascade,
      AppConfig.serverHost,
      AppConfig.serverPort,
    );
    _started = true;
    AppLogger.log(
      'Servidor local iniciado en ${AppConfig.serverHost}:${AppConfig.serverPort}',
    );
  }

  static Future<void> stop() async {
    if (_server != null) {
      await _server!.close(force: true);
      _server = null;
      _started = false;
    }
  }

  static bool get isRunning => _started && _server != null;
}

Future<shelf.Response> _jsonResponse(Object data) async {
  return shelf.Response.ok(
    jsonEncode(data),
    headers: {'content-type': 'application/json'},
  );
}

Future<Map<String, dynamic>> _readJson(shelf.Request request) async {
  final body = await request.readAsString();
  if (body.isEmpty) return <String, dynamic>{};
  return jsonDecode(body) as Map<String, dynamic>;
}
