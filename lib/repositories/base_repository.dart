import 'package:tienda/api/api_client.dart';

abstract class BaseRepository<T> {
  BaseRepository(this.apiClient);

  final ApiClient apiClient;

  String buildQueryString(Map<String, String>? query) {
    if (query == null || query.isEmpty) {
      return '';
    }
    final queryString = query.entries
        .map((entry) => '${entry.key}=${Uri.encodeComponent(entry.value)}')
        .join('&');
    return '?$queryString';
  }

  List<T> parseList(dynamic payload, T Function(Map<String, dynamic>) mapper) {
    if (payload is! List<dynamic>) {
      return const [];
    }
    return payload
        .whereType<Map>()
        .map((item) => mapper(Map<String, dynamic>.from(item)))
        .toList();
  }
}
