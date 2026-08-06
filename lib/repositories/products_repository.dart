import 'package:tienda/api/api_client.dart';
import 'package:tienda/repositories/base_repository.dart';

class ProductsRepository extends BaseRepository<Map<String, dynamic>> {
  ProductsRepository({ApiClient? apiClient}) : super(apiClient ?? ApiClient());

  Future<List<Map<String, dynamic>>> getProducts({
    String search = '',
    int? storeId,
    String? category,
  }) async {
    final uri = '/api/products?search=${Uri.encodeComponent(search)}';
    final query = <String, String>{};
    if (storeId != null) query['storeId'] = storeId.toString();
    if (category != null && category.isNotEmpty) query['category'] = category;
    final finalUri = query.isEmpty
        ? uri
        : '$uri&${query.entries.map((e) => '${e.key}=${Uri.encodeComponent(e.value)}').join('&')}';
    final list = await apiClient.getList(finalUri);
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> createProduct(Map<String, dynamic> payload) async {
    await apiClient.postJson('/api/products', payload);
  }

  Future<void> updateProduct(int id, Map<String, dynamic> payload) async {
    await apiClient.putJson('/api/products/$id', payload);
  }

  Future<void> deleteProduct(int id) async {
    await apiClient.deleteJson('/api/products/$id');
  }
}
