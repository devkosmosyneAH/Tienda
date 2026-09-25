// ignore_for_file: file_names

import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'database_service.dart';

/// Resultado de una operación de backup.
class BackupResult {
  final bool success;
  final String message;
  final String? driveFolderUrl;
  final List<String> uploadedFiles;

  BackupResult({
    required this.success,
    required this.message,
    this.driveFolderUrl,
    this.uploadedFiles = const [],
  });
}

/// Reporte de progreso durante el backup.
class BackupProgress {
  final String step;
  final int current;
  final int total;

  BackupProgress({
    required this.step,
    required this.current,
    required this.total,
  });

  double get percent => total == 0 ? 0 : current / total;
}

/// Cliente HTTP autenticado con el token de Google Sign-In.
class _AuthenticatedClient extends http.BaseClient {
  final http.Client _inner;
  final Map<String, String> _headers;

  _AuthenticatedClient(this._inner, this._headers);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(_headers);
    return _inner.send(request);
  }
}

/// Servicio para exportar la base de datos a JSON y subir a Google Drive.
class GoogleDriveBackupService {
  // Carpeta raíz compartida de los backups. Las imágenes de productos se
  // conservan en su subcarpeta `imagenes` para que sus IDs no dependan de un
  // backup con fecha concreta.
  static const String _bazarFolderId = '10bKLs-XzG0G2H1tqLJ16A5FkT5JfI39M';
  static String get _serverClientId {
    return dotenv.env['ID_CLIENT'] ?? dotenv.env['ID_CLIENT_ANDROID'] ?? '';
  }

  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [drive.DriveApi.driveScope],
    serverClientId: _serverClientId,
  );

  static GoogleSignInAccount? _currentUser;

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

  /// Retorna si hay un usuario autenticado activamente.
  static bool get isSignedIn => _currentUser != null;

  static String get currentUserEmail => _currentUser?.email ?? 'No autenticado';

  /// Inicia sesión con Google y retorna el email del usuario.
  static Future<String> signIn() async {
    if (!isPlatformSupported()) {
      throw Exception(
        'Google Drive backup no está disponible en ${_platformLabel()}. Usa Android, iOS, macOS o web para iniciar sesión.',
      );
    }

    try {
      final account = await _googleSignIn.signIn();
      if (account == null) {
        throw Exception('El usuario canceló el inicio de sesión');
      }
      _currentUser = account;
      return account.email;
    } on PlatformException catch (e, st) {
      debugPrint(
        'PlatformException en signIn: code=${e.code}, message=${e.message}, details=${e.details}',
      );
      debugPrint(st.toString());
      throw Exception(
        'Error al iniciar sesión: PlatformException(code=${e.code}, message=${e.message})',
      );
    } catch (e, st) {
      debugPrint('Error en signIn: $e');
      debugPrint(st.toString());
      throw Exception('Error al iniciar sesión: $e');
    }
  }

  /// Cierra sesión de Google.
  static Future<void> signOut() async {
    await _googleSignIn.signOut();
    _currentUser = null;
  }

  /// Intenta restaurar la sesión silenciosamente.
  static Future<String?> signInSilently() async {
    if (!isPlatformSupported()) {
      debugPrint(
        'Google Drive sign-in skipped: unsupported platform ${_platformLabel()}',
      );
      return _currentUser?.email;
    }

    // AdminDBPage inicia esta restauración de forma asíncrona. No debe borrar
    // una sesión que el usuario haya iniciado manualmente mientras la llamada
    // silenciosa seguía pendiente; esa misma sesión es la que reutiliza el
    // módulo de productos.
    final activeUser = _currentUser;
    try {
      final account = await _googleSignIn.signInSilently();
      if (account != null) {
        _currentUser = account;
        return account.email;
      }
      return activeUser?.email;
    } catch (e) {
      debugPrint('Google Drive sign-in silently failed: $e');
      return activeUser?.email;
    }
  }

  /// URL que puede consumirse directamente en el catálogo público.
  static String publicImageUrl(String fileId) =>
      'https://drive.google.com/uc?export=view&id=$fileId';

  /// Obtiene la misma cuenta usada por el backup.
  ///
  /// Si la app fue recreada, `_currentUser` se pierde aunque Google conserve
  /// la autorización. Primero se restaura sin interfaz y, solo si el SDK no
  /// entrega la cuenta, se relanza su flujo oficial para recuperar esa sesión.
  static Future<GoogleSignInAccount> _activeAccount() async {
    final current = _currentUser;
    if (current != null) return current;

    await signInSilently();
    final restored = _currentUser;
    if (restored != null) return restored;

    await signIn();
    final signedIn = _currentUser;
    if (signedIn == null) {
      throw Exception('No fue posible recuperar la sesión de Google Drive.');
    }
    return signedIn;
  }

  /// Sube una imagen elegida por el usuario y devuelve su `fileId`.
  ///
  /// El archivo se comparte como lectura pública porque el catálogo web se
  /// carga sin una sesión de Google. SQLite debe guardar únicamente el ID.
  static Future<String> uploadProductImage(String localPath) async {
    final account = await _activeAccount();

    final image = File(localPath);
    if (!await image.exists()) {
      throw Exception('La imagen seleccionada ya no está disponible.');
    }

    final auth = await account.authentication;
    final accessToken = auth.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      throw Exception(
        'No se obtuvo un token válido de Google. Vuelve a iniciar sesión.',
      );
    }
    final client = _AuthenticatedClient(http.Client(), {
      'Authorization': 'Bearer $accessToken',
    });
    final api = drive.DriveApi(client);
    try {
      final folderId = await _findOrCreateImagesFolder(api);
      final bytes = await image.readAsBytes();
      final name = image.uri.pathSegments.last;
      final created = await api.files.create(
        drive.File()
          ..name = '${DateTime.now().microsecondsSinceEpoch}_$name'
          ..parents = [folderId],
        uploadMedia: drive.Media(
          Stream.value(bytes),
          bytes.length,
          contentType: _getMimeType(name),
        ),
        $fields: 'id',
      );
      final fileId = created.id;
      if (fileId == null) {
        throw Exception('Google Drive no devolvió el ID de la imagen.');
      }

      await api.permissions.create(
        drive.Permission()
          ..type = 'anyone'
          ..role = 'reader',
        fileId,
      );
      return fileId;
    } finally {
      client.close();
    }
  }

  /// Elimina una imagen que ya no pertenece a ningún producto.
  static Future<void> deleteProductImage(String fileId) async {
    final account = _currentUser;
    if (fileId.isEmpty || account == null) return;
    final auth = await account.authentication;
    final accessToken = auth.accessToken;
    if (accessToken == null || accessToken.isEmpty) {
      debugPrint('No se pudo eliminar $fileId: token de Google no disponible.');
      return;
    }
    final client = _AuthenticatedClient(http.Client(), {
      'Authorization': 'Bearer $accessToken',
    });
    try {
      await drive.DriveApi(client).files.delete(fileId);
    } catch (e) {
      // No se deshace la actualización de SQLite por una limpieza fallida.
      debugPrint('No se pudo eliminar imagen de Drive ($fileId): $e');
    } finally {
      client.close();
    }
  }

  static String backupFileNameForTable(String table) {
    if (table == 'products') return 'productos.json';
    if (table == 'inventory') return 'stock.json';
    return '$table.json';
  }

  /// Realiza el backup completo: JSON de tablas + imágenes a Google Drive.
  /// [onProgress] se llama con cada paso.
  static Future<BackupResult> performBackup({
    void Function(BackupProgress)? onProgress,
  }) async {
    try {
      // 1. Verificar autenticación
      if (_currentUser == null) {
        throw Exception('Debe iniciar sesión primero');
      }

      onProgress?.call(
        BackupProgress(step: 'Autenticando...', current: 0, total: 10),
      );

      final auth = await _currentUser!.authentication;
      final authClient = _AuthenticatedClient(http.Client(), {
        'Authorization': 'Bearer ${auth.accessToken}',
      });
      final driveApi = drive.DriveApi(authClient);

      // 2. Usar la carpeta permanente de JSON del catálogo.
      onProgress?.call(
        BackupProgress(
          step: 'Preparando carpeta Backup...',
          current: 1,
          total: 10,
        ),
      );

      final jsonFolderId = await _findOrCreateDriveFolder(
        driveApi,
        'Backup',
        _bazarFolderId,
      );

      // 4. Exportar tablas a JSON y subir
      onProgress?.call(
        BackupProgress(
          step: 'Exportando tablas de la base de datos...',
          current: 2,
          total: 10,
        ),
      );

      // Reutilizar la conexión administrada por DatabaseService. Abrir la
      // misma ruta con otra instancia FFI y cerrarla después puede cerrar la
      // conexión compartida que usa CatalogSyncService.
      final db = await DatabaseService.database;

      // Se exportan productos, categorías, tiendas e inventario al catálogo de Drive.
      const tables = ['products', 'categories', 'stores', 'inventory'];
      final List<String> uploadedFiles = [];

      for (int i = 0; i < tables.length; i++) {
        final table = tables[i];
        onProgress?.call(
          BackupProgress(
            step: 'Exportando tabla: $table (${i + 1}/${tables.length})',
            current: 3 + i,
            total: 3 + tables.length + 3,
          ),
        );

        final rows = await db.query(table);
        final jsonContent = jsonEncode(rows);
        final fileName = backupFileNameForTable(table);
        await _uploadTextFile(driveApi, fileName, jsonContent, jsonFolderId);
        uploadedFiles.add(fileName);
      }

      // Las imágenes se mantienen solamente en /Imagenes. No se duplican
      // dentro de Backup porque SQLite ya guarda los fileId de Drive.
      onProgress?.call(
        BackupProgress(
          step: 'Usando imágenes externas...',
          current: 3 + tables.length + 1,
          total: 3 + tables.length + 3,
        ),
      );

      // 6. Enlace a la carpeta
      onProgress?.call(
        BackupProgress(
          step: '¡Backup completado!',
          current: 3 + tables.length + 3,
          total: 3 + tables.length + 3,
        ),
      );

      final folderUrl = 'https://drive.google.com/drive/folders/$jsonFolderId';

      authClient.close();

      return BackupResult(
        success: true,
        message: '✅ Backup completado exitosamente en Google Drive',
        driveFolderUrl: folderUrl,
        uploadedFiles: uploadedFiles,
      );
    } catch (e) {
      return BackupResult(
        success: false,
        message: '⛔ Error durante el backup: $e',
      );
    }
  }

  // ─── Métodos privados ──────────────────────────────────────────────────────

  static Future<String> _createDriveFolder(
    drive.DriveApi driveApi,
    String name,
    String? parentId,
  ) async {
    final folder = drive.File()
      ..name = name
      ..mimeType = 'application/vnd.google-apps.folder';

    if (parentId != null) {
      folder.parents = [parentId];
    }

    final created = await driveApi.files.create(folder);
    final id = created.id;
    if (id == null || id.isEmpty) {
      throw Exception('Google Drive no devolvió el ID de la carpeta "$name".');
    }
    return id;
  }

  static Future<String> _findOrCreateImagesFolder(drive.DriveApi api) async {
    return _findOrCreateDriveFolder(api, 'Imagenes', _bazarFolderId);
  }

  static Future<String> _findOrCreateDriveFolder(
    drive.DriveApi api,
    String name,
    String parentId,
  ) async {
    final found = await api.files.list(
      q:
          "'$parentId' in parents and name = '$name' and "
          "mimeType = 'application/vnd.google-apps.folder' and trashed = false",
      pageSize: 1,
      $fields: 'files(id)',
    );
    final files = found.files ?? const <drive.File>[];
    final id = files.isEmpty ? null : files.first.id;
    if (id != null && id.isNotEmpty) {
      return id;
    }
    return _createDriveFolder(api, name, parentId);
  }

  static Future<void> _uploadTextFile(
    drive.DriveApi driveApi,
    String fileName,
    String content,
    String parentFolderId,
  ) async {
    final bytes = utf8.encode(content);
    final stream = Stream.value(bytes);

    final matches = await driveApi.files.list(
      q: "'$parentFolderId' in parents and name = '$fileName' and trashed = false",
      pageSize: 1,
      $fields: 'files(id)',
    );
    final existing = matches.files?.isNotEmpty == true
        ? matches.files!.first.id
        : null;
    final media = drive.Media(
      stream,
      bytes.length,
      contentType: 'application/json',
    );
    if (existing != null) {
      await driveApi.files.update(
        drive.File()..name = fileName,
        existing,
        uploadMedia: media,
      );
    } else {
      await driveApi.files.create(
        drive.File()
          ..name = fileName
          ..parents = [parentFolderId],
        uploadMedia: media,
      );
    }
  }

  static String _getMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'application/octet-stream';
  }
}
