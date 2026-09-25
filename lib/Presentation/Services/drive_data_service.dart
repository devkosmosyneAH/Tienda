// ignore_for_file: file_names

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:tienda/Presentation/Template/catalog_template.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Producto real proveniente del backup de Drive.
class DriveProduct {
  final int id;
  final String name;
  final String sku;
  final double price;
  final int stock;
  final String categoryName;
  final String storeName;

  const DriveProduct({
    required this.id,
    required this.name,
    required this.sku,
    required this.price,
    required this.stock,
    required this.categoryName,
    this.storeName = '',
  });
}

/// Resultado del catálogo cargado desde Drive.
class CatalogDriveData {
  /// Categorías con sus productos reales. Key = nombre de categoría.
  final Map<String, List<DriveProduct>> productsByCategory;

  /// Archivos de imagen con el `thumbnailLink` original de Google Drive.
  final List<CatalogImageFile> imageFiles;

  /// Email del usuario autenticado.
  final String userEmail;

  /// Secciones del catálogo construidas desde los JSON de Drive.
  /// Listas vacías si no se pudo construir el catálogo.
  final List<CatalogSection> sections;

  const CatalogDriveData({
    required this.productsByCategory,
    required this.imageFiles,
    required this.userEmail,
    this.sections = const [],
  });

  bool get hasData => productsByCategory.isNotEmpty;
}

/// Cliente HTTP autenticado con Bearer token.
class _AuthClient extends http.BaseClient {
  final http.Client _inner;
  final String _token;
  _AuthClient(this._inner, this._token);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_token';
    return _inner.send(request);
  }
}

/// Servicio para leer datos del catálogo desde Google Drive.
///
/// Estructura esperada en Drive:
///   bazarypapeleria/
///     Backup/
///       productos.json
///       categories.json
///       stores.json
///     Imagenes/
///       (archivos de imagen)
class DriveDataService {
  // ID fijo de la carpeta raíz "bazarypapeleria" en Drive.
  static final String _bazarFolderId = dotenv.env['BAZARFOLDERID']!;

  static String get _serverClientId {
    return dotenv.env['ID_CLIENT'] ?? dotenv.env['ID_CLIENT_ANDROID'] ?? '';
  }

  static bool isPlatformSupported({bool? isWeb}) {
    final web = isWeb ?? kIsWeb;
    return web || Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
  }

  static String _platformLabel() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'Android';
    if (Platform.isIOS) return 'iOS';
    if (Platform.isMacOS) return 'macOS';
    if (Platform.isWindows) return 'Windows';
    if (Platform.isLinux) return 'Linux';
    return 'esta plataforma';
  }

  // ID fijo del backup más reciente: tienda_Backup_20260615_2020
  //static final String _backupFolderId = dotenv.env['BACKUPFOLDERID']!;
  // API Key pública de Google — solo lectura en carpetas compartidas públicamente.
  static final String _apiKey = dotenv.env['GOOGLE_API_KEY']!;

  // URL base de Drive REST API v3
  static const _driveBase = 'https://www.googleapis.com/drive/v3';

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveReadonlyScope],
    serverClientId: _serverClientId,
  );

  static GoogleSignInAccount? _account;

  // ── Auth ────────────────────────────────────────────────────────────────────

  static bool get isSignedIn => _account != null;
  static String get userEmail => _account?.email ?? '';

  /// Intenta restaurar la sesión de Google silenciosamente.
  /// Retorna el email si logró autenticarse, null si no.
  static Future<String?> signInSilently() async {
    if (!isPlatformSupported()) {
      debugPrint(
        '[DriveDataService] signInSilently skipped on unsupported platform ${_platformLabel()}',
      );
      _account = null;
      return null;
    }

    try {
      _account = await _googleSignIn.signInSilently();
      return _account?.email;
    } catch (e) {
      debugPrint('[DriveDataService] signInSilently error: $e');
      _account = null;
      return null;
    }
  }

  /// Lanza el flujo explícito de inicio de sesión con Google.
  static Future<String> signIn() async {
    if (!isPlatformSupported()) {
      throw Exception(
        'Google Drive backup no está disponible en ${_platformLabel()}. Usa Android, iOS, macOS o web para iniciar sesión.',
      );
    }

    final account = await _googleSignIn.signIn();
    if (account == null) throw Exception('Inicio de sesión cancelado');
    _account = account;
    return account.email;
  }

  /// Cierra la sesión.
  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    _account = null;
  }

  // ── Carga pública (sin login) ────────────────────────────────────────────────

  /// Carga el catálogo desde una carpeta Drive compartida públicamente,
  /// usando solo la API Key (sin OAuth). No requiere inicio de sesión.
  ///
  /// La carpeta raíz y sus subcarpetas deben tener permisos
  /// "Cualquier persona con el enlace puede ver".
  static Future<CatalogDriveData> fetchPublic() async {
    try {
      // JSON e imágenes viven en carpetas hermanas permanentes. No se busca
      // Backup/imagenes: cada fileId de producto apunta a Imagenes directamente.
      final jsonFolderId = await _publicFindSubfolder(_bazarFolderId, 'Backup');
      final imagesFolderId = await _publicFindSubfolder(
        _bazarFolderId,
        'Imagenes',
      );

      // 2. Descargar JSON en paralelo
      final results = await Future.wait([
        _publicDownloadJson(jsonFolderId, 'productos.json'),
        _publicDownloadJson(jsonFolderId, 'categories.json'),
        _publicDownloadJson(jsonFolderId, 'stores.json'),
        _publicDownloadJson(jsonFolderId, 'stock.json'),
      ]);

      final productsJson = results[0];
      final categoriesJson = results[1];
      final storesJson = results[2];
      final stockJson = results[3];

      _validateRequiredJson(
        productsJson: productsJson,
        categoriesJson: categoriesJson,
        storesJson: storesJson,
      );

      // 3. Listar imágenes
      final imageFiles = await _publicListImageThumbnails(imagesFolderId);

      // 4. Construir mapa legacy y secciones
      final productsByCategory = _buildProductsByCategory(
        productsJson: productsJson,
        categoriesJson: categoriesJson,
        storesJson: storesJson,
        stockJson: stockJson,
      );

      final sections = CatalogBuilder.buildFromJson(
        productsJson: productsJson,
        categoriesJson: categoriesJson,
        storesJson: storesJson,
        imageFiles: imageFiles,
        stockJson: stockJson,
      );

      return CatalogDriveData(
        productsByCategory: productsByCategory,
        imageFiles: imageFiles,
        userEmail: '',
        sections: sections,
      );
    } catch (e) {
      debugPrint('[DriveDataService.fetchPublic] error: $e');

      if (kIsWeb) {
        try {
          if (_account == null) {
            final signedIn = await signInSilently();
            if (signedIn == null) {
              await signIn();
            }
          }

          if (_account != null) {
            debugPrint(
              '[DriveDataService.fetchPublic] Reintentando con sesión de Google...',
            );
            return fetchCatalogData();
          }
        } catch (fallbackError) {
          debugPrint(
            '[DriveDataService.fetchPublic] Fallback con sesión falló: $fallbackError',
          );
        }
      }

      rethrow;
    }
  }

  // ── Helpers públicos (API Key) ────────────────────────────────────────────

  static Uri _driveFilesUri(Map<String, String> params) {
    return Uri.parse(
      '$_driveBase/files',
    ).replace(queryParameters: {...params, 'key': _apiKey});
  }

  static Uri buildPublicDownloadUri(String fileId, {bool useFallback = false}) {
    if (useFallback) {
      return Uri.parse(
        'https://drive.google.com/uc?export=download&id=$fileId',
      );
    }
    return Uri.parse(
      '$_driveBase/files/$fileId',
    ).replace(queryParameters: {'alt': 'media', 'key': _apiKey});
  }

  static String _publicThumbnailUrl(String fileId) =>
      'https://drive.google.com/thumbnail?id=$fileId&sz=w1000';

  static Future<Map<String, dynamic>> _publicGet(Uri uri) async {
    final resp = await http.get(uri).timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        throw TimeoutException('Tiempo de espera agotado al descargar $uri');
      },
    );

    debugPrint("URL:");
    debugPrint(uri.toString());

    debugPrint("STATUS:");
    debugPrint(resp.statusCode.toString());

    debugPrint("BODY:");
    debugPrint(resp.body);

    if (resp.statusCode != 200) {
      throw Exception(resp.body);
    }

    return jsonDecode(resp.body);
  }

  /// Busca una subcarpeta por nombre usando API Key.
  static Future<String> _publicFindSubfolder(
    String parentId,
    String name,
  ) async {
    final uri = _driveFilesUri({
      'q':
          "'$parentId' in parents and name='$name' and mimeType='application/vnd.google-apps.folder' and trashed=false",
      'pageSize': '5',
      'fields': 'files(id,name)',
    });
    final data = await _publicGet(uri);
    final files = (data['files'] as List?)?.cast<Map<String, dynamic>>();
    if (files == null || files.isEmpty) {
      throw Exception("Subcarpeta '$name' no encontrada en Drive.");
    }
    return files.first['id'] as String;
  }

  /// Descarga un JSON de Drive usando API Key.
  static Future<List<Map<String, dynamic>>> _publicDownloadJson(
    String folderId,
    String fileName,
  ) async {
    // 1. Buscar el archivo
    final listUri = _driveFilesUri({
      'q': "'$folderId' in parents and name='$fileName' and trashed=false",
      'pageSize': '5',
      'fields': 'files(id,name)',
    });
    final listData = await _publicGet(listUri);
    final files = (listData['files'] as List?)?.cast<Map<String, dynamic>>();
    if (files == null || files.isEmpty) {
      debugPrint('[DriveDataService] $fileName no encontrado, omitiendo.');
      return [];
    }

    // 2. Descargar contenido
    final fileId = files.first['id'] as String;
    final downloadUri = buildPublicDownloadUri(fileId);

    try {
      final resp = await http.get(downloadUri);
      if (resp.statusCode != 200) {
        throw Exception('status ${resp.statusCode}');
      }

      final decoded = jsonDecode(utf8.decode(resp.bodyBytes));
      if (decoded is List) return decoded.cast<Map<String, dynamic>>();
      return [];
    } catch (e, stack) {
      debugPrint('[DriveDataService] Fallback de descarga para $fileName: $e');
      debugPrint('========================');
      debugPrint('DOWNLOAD URI: $downloadUri');
      debugPrint('ERROR: $e');
      debugPrint(stack.toString());
      debugPrint('========================');

      final fallbackUri = buildPublicDownloadUri(fileId, useFallback: true);
      final fallbackResp = await http.get(fallbackUri);
      debugPrint('FALLBACK STATUS: ${fallbackResp.statusCode}');
      debugPrint('FALLBACK BODY: ${fallbackResp.body}');
      if (fallbackResp.statusCode != 200) {
        debugPrint(
          '[DriveDataService] Error descargando $fileName: ${fallbackResp.statusCode}',
        );
        return [];
      }

      final decoded = jsonDecode(utf8.decode(fallbackResp.bodyBytes));
      if (decoded is List) return decoded.cast<Map<String, dynamic>>();
      return [];
    }
  }

  /// Lista miniaturas públicas de imágenes en un folder usando API Key.
  static Future<List<CatalogImageFile>> _publicListImageThumbnails(
    String folderId,
  ) async {
    final result = <CatalogImageFile>[];
    String? pageToken;

    do {
      final params = <String, String>{
        'q': "'$folderId' in parents and trashed=false",
        'pageSize': '100',
        'fields': 'nextPageToken,files(id,name,thumbnailLink)',
      };
      if (pageToken != null) params['pageToken'] = pageToken;

      final uri = _driveFilesUri(params);
      final data = await _publicGet(uri);
      final files =
          (data['files'] as List?)?.cast<Map<String, dynamic>>() ?? [];

      for (final f in files) {
        final id = f['id'] as String?;
        final name = f['name'] as String?;
        if (id == null || name == null) {
          continue;
        }

        final effectiveThumbnailLink = _publicThumbnailUrl(id);

        result.add(
          CatalogImageFile(
            id: id,
            name: name,
            thumbnailLink: effectiveThumbnailLink,
          ),
        );
      }

      pageToken = data['nextPageToken'] as String?;
    } while (pageToken != null);

    debugPrint('[DriveDataService] Imágenes cargadas: ${result.length}');
    return result;
  }

  // ── Carga principal (OAuth) ─────────────────────────────────────────────────

  /// Carga productos e imágenes del backup más reciente en Drive.
  ///
  /// Lanza [Exception] si no hay sesión activa o si falla la lectura.
  static Future<CatalogDriveData> fetchCatalogData() async {
    if (_account == null) {
      throw Exception('No hay sesión activa. Inicia sesión primero.');
    }

    final auth = await _account!.authentication;
    final client = _AuthClient(http.Client(), auth.accessToken!);
    final driveApi = drive.DriveApi(client);

    try {
      // JSON e imágenes son carpetas hermanas permanentes bajo la raíz.
      final jsonFolderId = await _findSubfolder(
        driveApi,
        _bazarFolderId,
        'Backup',
      );
      final imagesFolderId = await _findSubfolder(
        driveApi,
        _bazarFolderId,
        'Imagenes',
      );

      // 3. Descargar los JSON necesarios para el catálogo y stock
      final results = await Future.wait([
        _downloadJson(driveApi, jsonFolderId, 'productos.json'),
        _downloadJson(driveApi, jsonFolderId, 'categories.json'),
        _downloadJson(driveApi, jsonFolderId, 'stores.json'),
        _downloadJson(driveApi, jsonFolderId, 'stock.json'),
      ]);

      final productsJson = results[0];
      final categoriesJson = results[1];
      final storesJson = results[2];
      final stockJson = results[3];

      _validateRequiredJson(
        productsJson: productsJson,
        categoriesJson: categoriesJson,
        storesJson: storesJson,
      );

      // 4. Parsear datos
      final productsByCategory = _buildProductsByCategory(
        productsJson: productsJson,
        categoriesJson: categoriesJson,
        storesJson: storesJson,
        stockJson: stockJson,
      );

      // 5. Listar imágenes
      final imageFiles = await _listImageThumbnails(driveApi, imagesFolderId);

      // 6. Construir secciones del catálogo desde los JSON crudos
      final sections = CatalogBuilder.buildFromJson(
        productsJson: productsJson,
        categoriesJson: categoriesJson,
        storesJson: storesJson,
        imageFiles: imageFiles,
        stockJson: stockJson,
      );

      return CatalogDriveData(
        productsByCategory: productsByCategory,
        imageFiles: imageFiles,
        userEmail: _account!.email,
        sections: sections,
      );
    } finally {
      client.close();
    }
  }

  static void _validateRequiredJson({
    required List<Map<String, dynamic>> productsJson,
    required List<Map<String, dynamic>> categoriesJson,
    required List<Map<String, dynamic>> storesJson,
  }) {
    if (productsJson.isEmpty) {
      throw Exception('products.json está vacío o no válido.');
    }
    if (categoriesJson.isEmpty) {
      throw Exception('categories.json está vacío o no válido.');
    }
    if (storesJson.isEmpty) {
      throw Exception('stores.json está vacío o no válido.');
    }
  }

  // ── Helpers privados ────────────────────────────────────────────────────────

  /// Busca una subcarpeta por nombre dentro de un folder dado.
  static Future<String> _findSubfolder(
    drive.DriveApi api,
    String parentId,
    String name,
  ) async {
    final list = await api.files.list(
      q: "'$parentId' in parents and name = '$name' and mimeType = 'application/vnd.google-apps.folder' and trashed = false",
      pageSize: 5,
      $fields: 'files(id,name)',
    );

    final files = list.files;
    if (files == null || files.isEmpty) {
      throw Exception("Subcarpeta '$name' no encontrada en Drive.");
    }
    return files.first.id!;
  }

  /// Descarga el contenido de un archivo JSON y lo parsea como lista de mapas.
  static Future<List<Map<String, dynamic>>> _downloadJson(
    drive.DriveApi api,
    String folderId,
    String fileName,
  ) async {
    // Buscar el archivo
    final list = await api.files.list(
      q: "'$folderId' in parents and name = '$fileName' and trashed = false",
      pageSize: 5,
      $fields: 'files(id,name)',
    );

    final files = list.files;
    if (files == null || files.isEmpty) {
      debugPrint('[DriveDataService] $fileName no encontrado, omitiendo.');
      return [];
    }

    final fileId = files.first.id!;
    final media =
        await api.files.get(
              fileId,
              downloadOptions: drive.DownloadOptions.fullMedia,
            )
            as drive.Media;

    final bytes = <int>[];
    await for (final chunk in media.stream) {
      bytes.addAll(chunk);
    }

    final content = utf8.decode(bytes);
    final decoded = jsonDecode(content);
    if (decoded is List) {
      return decoded.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// Lista los archivos de imagen en el folder con una miniatura pública estable.
  static Future<List<CatalogImageFile>> _listImageThumbnails(
    drive.DriveApi api,
    String folderId,
  ) async {
    final result = <CatalogImageFile>[];
    String? pageToken;

    do {
      final list = await api.files.list(
        q: "'$folderId' in parents and trashed = false",
        pageSize: 100,
        pageToken: pageToken,
        $fields: 'nextPageToken,files(id,name,thumbnailLink,webContentLink)',
      );

      for (final f in list.files ?? []) {
        final id = f.id;
        final name = f.name;
        if (id == null || name == null) {
          continue;
        }
        result.add(
          CatalogImageFile(
            id: id,
            name: name,
            thumbnailLink: _publicThumbnailUrl(id),
          ),
        );
      }

      pageToken = list.nextPageToken;
    } while (pageToken != null);

    debugPrint('[DriveDataService] Imágenes cargadas: ${result.length}');
    return result;
  }

  /// Construye el mapa categoryName → [DriveProduct] a partir de los JSONs.
  static Map<String, List<DriveProduct>> _buildProductsByCategory({
    required List<Map<String, dynamic>> productsJson,
    required List<Map<String, dynamic>> categoriesJson,
    required List<Map<String, dynamic>> storesJson,
    required List<Map<String, dynamic>> stockJson,
  }) {
    final stockByProductId = <int, int>{};
    for (final row in stockJson) {
      final productId =
          (row['product_id'] as num?)?.toInt() ??
          (row['productId'] as num?)?.toInt();
      final stockValue =
          (row['stock'] as num?)?.toInt() ?? (row['quantity'] as num?)?.toInt();
      if (productId != null && stockValue != null) {
        stockByProductId[productId] =
            (stockByProductId[productId] ?? 0) + stockValue;
      }
    }

    // Mapa categoryId → categoryName
    final categoryNames = <int, String>{};
    for (final c in categoriesJson) {
      final id = (c['id'] as num?)?.toInt();
      final name = c['name'] as String?;
      if (id != null && name != null) categoryNames[id] = name;
    }

    // Mapa storeId → storeName
    final storeNames = <int, String>{};
    for (final s in storesJson) {
      final id = (s['id'] as num?)?.toInt();
      final name = s['name'] as String?;
      if (id != null && name != null) storeNames[id] = name;
    }

    final Map<String, List<DriveProduct>> byCategory = {};

    for (final p in productsJson) {
      final id = (p['id'] as num?)?.toInt();
      final name = p['name'] as String?;
      final sku = p['sku'] as String? ?? '';
      final price = (p['price'] as num?)?.toDouble() ?? 0;
      final categoryId = (p['category_id'] as num?)?.toInt();
      final storeId = (p['store_id'] as num?)?.toInt();
      final fallbackStock = (p['stock'] as num?)?.toInt() ?? 0;
      final stock = stockByProductId[id] ?? fallbackStock;

      if (id == null || name == null) continue;

      final categoryName =
          (categoryId != null ? categoryNames[categoryId] : null) ??
          'Sin categoría';

      final storeName = (storeId != null ? storeNames[storeId] : null) ?? '';

      final product = DriveProduct(
        id: id,
        name: name,
        sku: sku,
        price: price,
        stock: stock,
        categoryName: categoryName,
        storeName: storeName,
      );

      byCategory.putIfAbsent(categoryName, () => []).add(product);
    }

    // Ordenar productos por nombre dentro de cada categoría
    for (final list in byCategory.values) {
      list.sort((a, b) => a.name.compareTo(b.name));
    }

    return byCategory;
  }

  // ── Utilidades ──────────────────────────────────────────────────────────────

  static String _removeAccents(String input) {
    const accents = 'áàäâãéèëêíìïîóòöôõúùüûñç';
    const plain = 'aaaaaeeeeiiiioooooouuuunc';
    var result = input;
    for (int i = 0; i < accents.length; i++) {
      result = result.replaceAll(accents[i], plain[i]);
    }
    return result;
  }

  /// Dada la información de imágenes y el nombre de categoría,
  /// retorna la URL del thumbnail más apropiado o null si no hay coincidencia.
  static String? findImageForCategory(
    Map<String, String> thumbnails,
    String categoryName,
  ) {
    final normalized = _removeAccents(categoryName.toLowerCase());
    // Búsqueda exacta
    if (thumbnails.containsKey(normalized)) return thumbnails[normalized];
    // Búsqueda parcial: alguna imagen cuyo nombre contiene la categoría
    for (final entry in thumbnails.entries) {
      if (entry.key.contains(normalized) || normalized.contains(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }
}
