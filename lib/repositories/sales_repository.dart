import 'package:tienda/api/api_client.dart';
import 'package:tienda/repositories/base_repository.dart';

class SalesRepository extends BaseRepository<Map<String, dynamic>> {
  SalesRepository({ApiClient? apiClient}) : super(apiClient ?? ApiClient());

  Future<List<Map<String, dynamic>>> getSalesHistory({
    int? storeId,
    int? customerId,
    int? year,
    int? month,
    int? day,
  }) async {
    final query = <String, String>{};
    if (storeId != null) query['storeId'] = storeId.toString();
    if (customerId != null) query['customerId'] = customerId.toString();
    if (year != null) query['year'] = year.toString();
    if (month != null) query['month'] = month.toString();
    if (day != null) query['day'] = day.toString();
    final uri =
        '/api/sales${query.isEmpty ? '' : '?${query.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}'}';
    final list = await apiClient.getList(uri);
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<Map<String, dynamic>> registerSale(
    Map<String, dynamic> payload,
  ) async {
    return apiClient.postJson('/api/sales', payload);
  }
}
