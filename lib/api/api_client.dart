import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:tienda/core/app_config.dart';

class ApiClient {
  ApiClient({String? baseUrl, Duration? timeout})
    : baseUrl = baseUrl ?? AppConfig.serverBaseUrl,
      timeout = timeout ?? const Duration(seconds: 8);

  final String baseUrl;
  final Duration timeout;

  Future<Map<String, dynamic>> getJson(String path) async {
    final response = await _sendRequest(
      () => http.get(Uri.parse('$baseUrl$path')),
      path,
    );
    return _decodeJsonMap(response.body, path);
  }

  Future<List<dynamic>> getList(String path) async {
    final response = await _sendRequest(
      () => http.get(Uri.parse('$baseUrl$path')),
      path,
    );
    return _decodeJsonList(response.body, path);
  }

  Future<Map<String, dynamic>> postJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _sendRequest(
      () => http.post(
        Uri.parse('$baseUrl$path'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode(body),
      ),
      path,
    );
    return _decodeJsonMap(response.body, path);
  }

  Future<Map<String, dynamic>> putJson(
    String path,
    Map<String, dynamic> body,
  ) async {
    final response = await _sendRequest(
      () => http.put(
        Uri.parse('$baseUrl$path'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode(body),
      ),
      path,
    );
    return _decodeJsonMap(response.body, path);
  }

  Future<Map<String, dynamic>> deleteJson(String path) async {
    final response = await _sendRequest(
      () => http.delete(Uri.parse('$baseUrl$path')),
      path,
    );
    return _decodeJsonMap(response.body, path);
  }

  Future<http.Response> _sendRequest(
    Future<http.Response> Function() requestFactory,
    String path,
  ) async {
    try {
      final response = await requestFactory().timeout(timeout);
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode} para $path');
      }
      return response;
    } on TimeoutException {
      throw Exception('Tiempo de espera agotado para $path');
    } on http.ClientException catch (error) {
      throw Exception('No se pudo conectar con el servidor local: $error');
    }
  }

  Map<String, dynamic> _decodeJsonMap(String body, String path) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) {
        throw Exception('Respuesta inesperada para $path');
      }
      return decoded;
    } on FormatException catch (error) {
      throw Exception('Respuesta inválida para $path: $error');
    }
  }

  List<dynamic> _decodeJsonList(String body, String path) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! List<dynamic>) {
        throw Exception('Respuesta inesperada para $path');
      }
      return decoded;
    } on FormatException catch (error) {
      throw Exception('Respuesta inválida para $path: $error');
    }
  }
}
