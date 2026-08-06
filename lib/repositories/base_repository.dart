import 'package:tienda/api/api_client.dart';

abstract class BaseRepository<T> {
  BaseRepository(this.apiClient);

  final ApiClient apiClient;
}
