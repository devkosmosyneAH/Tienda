// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;

import 'catalog_export_service.dart';
import 'database_service.dart';
import 'git_sync_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Estado de sincronización
// ─────────────────────────────────────────────────────────────────────────────

enum SyncStatus { idle, hashing, exporting, pushing, success, error, skipped }

/// Snapshot del estado actual del sistema de sincronización.
class SyncState {
  final SyncStatus status;
  final DateTime? lastSync;
  final String? lastError;
  final int? lastProductsCount;
  final int? lastCategoriesCount;
  final String? lastHash;

  const SyncState({
    required this.status,
    this.lastSync,
    this.lastError,
    this.lastProductsCount,
    this.lastCategoriesCount,
    this.lastHash,
  });

  SyncState copyWith({
    SyncStatus? status,
    DateTime? lastSync,
    String? lastError,
    int? lastProductsCount,
    int? lastCategoriesCount,
    String? lastHash,
  }) => SyncState(
    status: status ?? this.status,
    lastSync: lastSync ?? this.lastSync,
    lastError: lastError ?? this.lastError,
    lastProductsCount: lastProductsCount ?? this.lastProductsCount,
    lastCategoriesCount: lastCategoriesCount ?? this.lastCategoriesCount,
    lastHash: lastHash ?? this.lastHash,
  );

  bool get isRunning =>
      status == SyncStatus.hashing ||
      status == SyncStatus.exporting ||
      status == SyncStatus.pushing;
}

// ─────────────────────────────────────────────────────────────────────────────
// Entrada del log de sincronización (en memoria y en archivo)
// ─────────────────────────────────────────────────────────────────────────────

class SyncLogEntry {
  final DateTime timestamp;
  final String action;
  final Duration? duration;
  final String result;
  final String? error;

  const SyncLogEntry({
    required this.timestamp,
    required this.action,
    this.duration,
    required this.result,
    this.error,
  });

  /// Formato de línea para catalog_sync.log
  String toLogLine() {
    final ts = timestamp.toLocal().toIso8601String().substring(0, 19);
    final dur = duration != null ? '${duration!.inMilliseconds}ms' : '-';
    final err = error != null ? ' | error: $error' : '';
    return '[$ts] acción=$action | duración=$dur | resultado=$result$err';
  }

  @override
  String toString() => toLogLine();
}

// ─────────────────────────────────────────────────────────────────────────────
// Orquestador principal — Sistema de sincronización basado en eventos
// ─────────────────────────────────────────────────────────────────────────────

/// Sistema inteligente de sincronización del catálogo web.
///
/// Funcionalidades:
///   • [markDirty] — punto de entrada desde Controllers. Activa debounce.
///   • Debounce de 30 s para agrupar múltiples cambios consecutivos.
///   • Cola de sincronización: nunca dos procesos simultáneos.
///   • HASH del catálogo: si el contenido no cambió, no hay push.
///   • Persistencia del hash en `last_catalog_hash.txt`.
///   • Log estructurado en `catalog_sync.log` (fecha|acción|duración|resultado).
///   • Reintentos automáticos para export, commit y push (hasta 3 intentos).
///   • Fallback cada 5 minutos para detectar cambios no capturados por eventos.
///
/// Integración:
/// ```dart
/// // En main.dart o providers.dart:
/// CatalogSyncService.initialize(
///   exportDir: '/ruta/gh-pages/catalog',
///   gitRepoPath: '/ruta/gh-pages',
///   dataDir: '/ruta/app/data',
/// );
///
/// // En ProductManagementController o cualquier Controller con CRUD:
/// CatalogSyncService.instance.markDirty();
/// ```
class CatalogSyncService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static CatalogSyncService? _instance;

  static CatalogSyncService get instance {
    assert(
      _instance != null,
      'Llama a CatalogSyncService.initialize() antes de usar la instancia.',
    );
    return _instance!;
  }

  /// Inicializa el singleton. Llamar UNA vez en main.dart / providers.dart.
  ///
  /// [exportDir]   — directorio donde se escriben los JSON para GitHub Pages.
  /// [gitRepoPath] — raíz del repositorio git (donde está la carpeta .git/).
  /// [dataDir]     — directorio donde persisten last_catalog_hash.txt y catalog_sync.log.
  /// [debounce]    — tiempo de espera tras el último cambio antes de sincronizar (default 30 s).
  /// [fallbackInterval] — sincronización de respaldo si no llegan eventos (default 5 min).
  /// [maxLogEntries]    — entradas máximas en el log en memoria.
  /// [maxRetries]       — intentos máximos por operación fallida (export/commit/push).
  static void initialize({
    required String exportDir,
    required String gitRepoPath,
    required String dataDir,
    Duration debounce = const Duration(seconds: 30),
    Duration fallbackInterval = const Duration(minutes: 5),
    int maxLogEntries = 200,
    int maxRetries = 3,
  }) {
    _instance ??= CatalogSyncService._(
      exportDir: exportDir,
      gitRepoPath: gitRepoPath,
      dataDir: dataDir,
      debounce: debounce,
      fallbackInterval: fallbackInterval,
      maxLogEntries: maxLogEntries,
      maxRetries: maxRetries,
    );
    _instance!._startFallbackTimer();
  }

  // ── Campos de configuración ────────────────────────────────────────────────
  final String exportDir;
  final String gitRepoPath;
  final String dataDir;
  final Duration debounce;
  final Duration fallbackInterval;
  final int maxLogEntries;
  final int maxRetries;

  // ── Estado interno ─────────────────────────────────────────────────────────
  final _stateController = StreamController<SyncState>.broadcast();
  final List<SyncLogEntry> _log = [];

  SyncState _state = const SyncState(status: SyncStatus.idle);
  Timer? _debounceTimer;
  Timer? _fallbackTimer;
  bool _syncRunning = false;
  bool _pendingSync = false; // Cola: máximo una petición encolada.

  CatalogSyncService._({
    required this.exportDir,
    required this.gitRepoPath,
    required this.dataDir,
    required this.debounce,
    required this.fallbackInterval,
    required this.maxLogEntries,
    required this.maxRetries,
  });

  // ── Rutas de archivos de estado ────────────────────────────────────────────

  String get _hashFilePath => p.join(dataDir, 'last_catalog_hash.txt');
  String get _logFilePath => p.join(dataDir, 'catalog_sync.log');

  // ── API pública ────────────────────────────────────────────────────────────

  /// Stream que emite el estado actualizado. Conéctalo desde el Provider.
  Stream<SyncState> get stateStream => _stateController.stream;

  /// Estado actual (snapshot síncrono).
  SyncState get state => _state;

  /// Log en memoria (inmutable desde afuera).
  List<SyncLogEntry> get log => List.unmodifiable(_log);

  // ── PUNTO DE ENTRADA PRINCIPAL ─────────────────────────────────────────────

  /// Marca el catálogo como modificado y activa el debounce de [debounce].
  ///
  /// Llamar desde los Controllers cada vez que ocurra:
  ///   • Producto creado / actualizado / eliminado.
  ///   • Categoría creada / actualizada / eliminada.
  ///
  /// Si se producen N cambios consecutivos dentro de la ventana de debounce,
  /// solo se ejecutará UNA sincronización al final de la ráfaga.
  void markDirty() {
    _writeLog(
      action: 'mark_dirty',
      result: 'debounce reiniciado (${debounce.inSeconds}s)',
    );
    print(
      '[CatalogSyncService] 🔔 markDirty() — debounce ${debounce.inSeconds}s',
    );
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, _enqueueSyncIfIdle);
  }

  /// Alias de compatibilidad hacia atrás.
  void notifyCatalogChanged() => markDirty();

  /// Sincronización manual inmediata (botón en UI o forzado).
  /// Cancela el debounce pendiente y ejecuta ahora sin comparar hash.
  Future<void> syncNow({bool forceEvenIfHashMatch = false}) async {
    _debounceTimer?.cancel();
    _writeLog(action: 'sync_now', result: 'solicitado manualmente');
    print('[CatalogSyncService] ▶ syncNow()');
    await _runSync(forceEvenIfHashMatch: forceEvenIfHashMatch);
  }

  /// Libera recursos (llamar en dispose del Provider).
  void dispose() {
    _debounceTimer?.cancel();
    _fallbackTimer?.cancel();
    _stateController.close();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HASH — Cálculo, almacenamiento y comparación
  // ─────────────────────────────────────────────────────────────────────────

  /// Obtiene todos los productos y categorías de la BD y calcula SHA-256.
  ///
  /// El input del hash es el JSON canónico ordenado por id, de forma que
  /// dos catálogos idénticos producen siempre el mismo hash.
  Future<String> calculateCatalogHash() async {
    final products = await DatabaseService.getProducts();
    final categories = await DatabaseService.getCategories();

    // Ordenar para garantizar determinismo.
    products.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));
    categories.sort((a, b) => (a['id'] as int).compareTo(b['id'] as int));

    // Normalizar: solo campos relevantes para el catálogo público.
    final normalizedProducts = products
        .map(
          (row) => {
            'id': row['id'],
            'name': row['name'],
            'sku': row['sku'],
            'description': row['description'],
            'tags': row['tags'],
            'price': row['price'],
            'iva_rate': row['iva_rate'] ?? row['ivaRate'] ?? 0,
            'category': row['category'],
            'images': row['images'],
            'total_stock': row['total_stock'] ?? row['totalStock'] ?? 0,
            'is_active': row['is_active'] ?? row['isActive'] ?? true,
          },
        )
        .toList();

    final normalizedCategories = categories
        .map((row) => {'id': row['id'], 'name': row['name']})
        .toList();

    final payload = jsonEncode({
      'products': normalizedProducts,
      'categories': normalizedCategories,
    });

    final bytes = utf8.encode(payload);
    return sha256.convert(bytes).toString();
  }

  /// Persiste el hash en [_hashFilePath] (last_catalog_hash.txt).
  Future<void> saveHash(String hash) async {
    try {
      await _ensureDataDir();
      await File(_hashFilePath).writeAsString(hash, encoding: utf8);
      print('[CatalogSyncService] 💾 Hash guardado: $hash');
    } catch (e) {
      print('[CatalogSyncService] ⚠ No se pudo guardar hash: $e');
    }
  }

  /// Lee el último hash sincronizado desde [_hashFilePath].
  /// Retorna cadena vacía si el archivo no existe o hay error.
  Future<String> loadHash() async {
    try {
      final file = File(_hashFilePath);
      if (!await file.exists()) return '';
      final hash = (await file.readAsString(encoding: utf8)).trim();
      print('[CatalogSyncService] 📂 Hash cargado: $hash');
      return hash;
    } catch (e) {
      print('[CatalogSyncService] ⚠ No se pudo leer hash: $e');
      return '';
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Lógica de cola y sincronización
  // ─────────────────────────────────────────────────────────────────────────

  void _enqueueSyncIfIdle() {
    if (_syncRunning) {
      _pendingSync = true;
      print('[CatalogSyncService] ⏳ Sync en curso — petición encolada.');
      return;
    }
    _runSync();
  }

  Future<void> _runSync({bool forceEvenIfHashMatch = false}) async {
    if (_syncRunning) {
      _pendingSync = true;
      return;
    }

    _syncRunning = true;
    _pendingSync = false;
    final syncStart = DateTime.now();

    try {
      // ── 1. Calcular HASH ──────────────────────────────────────────────────
      _emit(_state.copyWith(status: SyncStatus.hashing));
      final hashStart = DateTime.now();
      final currentHash = await calculateCatalogHash();
      final savedHash = await loadHash();
      final hashDuration = DateTime.now().difference(hashStart);

      _writeLog(
        action: 'calculate_hash',
        duration: hashDuration,
        result: 'hash=$currentHash',
      );

      // ── 2. Comparar HASH ──────────────────────────────────────────────────
      if (!forceEvenIfHashMatch && currentHash == savedHash) {
        print('[CatalogSyncService] ✔ Hash idéntico — sin cambios. Skip.');
        _writeLog(
          action: 'hash_compare',
          result: 'sin cambios — sincronización omitida',
        );
        _emit(_state.copyWith(status: SyncStatus.skipped));
        return;
      }

      _writeLog(action: 'hash_compare', result: 'hash cambió — iniciando sync');

      // ── 3. Exportar JSON (con reintentos) ─────────────────────────────────
      _emit(_state.copyWith(status: SyncStatus.exporting));
      print('[CatalogSyncService] 📦 Exportando SQLite → JSON…');

      final exportStart = DateTime.now();
      ExportResult? exportResult;
      String? exportError;

      for (var attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          exportResult = await CatalogExportService.exportAllWithHash(
            exportDir,
            catalogHash: currentHash,
          );
          if (exportResult.success) break;
          exportError = exportResult.error;
        } catch (e) {
          exportError = e.toString();
        }
        if (attempt < maxRetries) {
          print(
            '[CatalogSyncService] ⚠ Export intento $attempt fallido — reintentando…',
          );
          await Future.delayed(Duration(seconds: attempt * 2));
        }
      }

      final exportDuration = DateTime.now().difference(exportStart);

      if (exportResult == null || !exportResult.success) {
        _writeLog(
          action: 'export_json',
          duration: exportDuration,
          result: 'error',
          error: exportError,
        );
        _fail('Error en exportación tras $maxRetries intentos: $exportError');
        return;
      }

      _writeLog(
        action: 'export_json',
        duration: exportDuration,
        result:
            'ok — ${exportResult.productsCount} productos, ${exportResult.categoriesCount} categorías',
      );

      // ── 4. Git commit + push (con reintentos) ─────────────────────────────
      _emit(_state.copyWith(status: SyncStatus.pushing));
      print('[CatalogSyncService] 🚀 Publicando en GitHub Pages…');

      final git = GitSyncService(repoPath: gitRepoPath, maxRetries: maxRetries);
      final commitMsg =
          'catalog update: ${exportResult.productsCount} prods, '
          '${exportResult.categoriesCount} cats | hash=${currentHash.substring(0, 8)} | '
          '${DateTime.now().toUtc().toIso8601String()}';

      final gitStart = DateTime.now();
      GitOperationResult? gitResult;
      String? gitError;

      for (var attempt = 1; attempt <= maxRetries; attempt++) {
        try {
          gitResult = await git.publishCatalog(commitMessage: commitMsg);
          if (gitResult.success) break;
          gitError = gitResult.stderr;
        } catch (e) {
          gitError = e.toString();
        }
        if (attempt < maxRetries) {
          print(
            '[CatalogSyncService] ⚠ Git intento $attempt fallido — reintentando…',
          );
          await Future.delayed(Duration(seconds: attempt * 3));
        }
      }

      final gitDuration = DateTime.now().difference(gitStart);

      if (gitResult == null || !gitResult.success) {
        _writeLog(
          action: 'git_push',
          duration: gitDuration,
          result: 'error',
          error: gitError,
        );
        _fail('Error en git push tras $maxRetries intentos: $gitError');
        return;
      }

      _writeLog(action: 'git_push', duration: gitDuration, result: 'ok');

      // ── 5. Persistir hash (solo si todo fue exitoso) ───────────────────────
      await saveHash(currentHash);

      // ── 6. Éxito ──────────────────────────────────────────────────────────
      final totalDuration = DateTime.now().difference(syncStart);
      final now = DateTime.now();

      _emit(
        SyncState(
          status: SyncStatus.success,
          lastSync: now,
          lastProductsCount: exportResult.productsCount,
          lastCategoriesCount: exportResult.categoriesCount,
          lastHash: currentHash,
        ),
      );

      _writeLog(
        action: 'sync_complete',
        duration: totalDuration,
        result: 'ok — catálogo publicado en GitHub Pages',
      );
      print(
        '[CatalogSyncService] ✅ Sync completo en ${totalDuration.inSeconds}s',
      );
    } catch (e, st) {
      final dur = DateTime.now().difference(syncStart);
      _writeLog(
        action: 'sync_complete',
        duration: dur,
        result: 'error',
        error: '$e',
      );
      _fail('Excepción inesperada: $e\n$st');
    } finally {
      _syncRunning = false;

      if (_pendingSync) {
        _pendingSync = false;
        print('[CatalogSyncService] ▶ Procesando sincronización encolada…');
        Future.microtask(_runSync);
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Fallback timer — respaldo cada [fallbackInterval]
  // ─────────────────────────────────────────────────────────────────────────

  /// Inicia el timer de respaldo. Solo lanza sync si [_isDirty] o si hay
  /// cambios reales (detectados por diferencia de hash).
  void _startFallbackTimer() {
    _fallbackTimer?.cancel();
    _fallbackTimer = Timer.periodic(fallbackInterval, (_) async {
      if (_syncRunning) return; // No interrumpir una sync en curso.
      print('[CatalogSyncService] ⏰ Fallback timer — verificando cambios…');
      _writeLog(action: 'fallback_check', result: 'iniciado por timer');
      // El _runSync compara hash internamente; si no hay cambios, skips.
      await _runSync();
    });
    print(
      '[CatalogSyncService] ⏰ Fallback timer iniciado: cada '
      '${fallbackInterval.inMinutes} min.',
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Helpers internos
  // ─────────────────────────────────────────────────────────────────────────

  void _fail(String message) {
    print('[CatalogSyncService] ❌ $message');
    _emit(_state.copyWith(status: SyncStatus.error, lastError: message));
  }

  void _emit(SyncState newState) {
    _state = newState;
    if (!_stateController.isClosed) {
      _stateController.add(_state);
    }
  }

  /// Escribe una entrada en el log en memoria Y en catalog_sync.log.
  void _writeLog({
    required String action,
    Duration? duration,
    required String result,
    String? error,
  }) {
    final entry = SyncLogEntry(
      timestamp: DateTime.now(),
      action: action,
      duration: duration,
      result: result,
      error: error,
    );

    _log.add(entry);
    if (_log.length > maxLogEntries) {
      _log.removeRange(0, _log.length - maxLogEntries);
    }

    _appendToLogFile(entry);
  }

  Future<void> _appendToLogFile(SyncLogEntry entry) async {
    try {
      await _ensureDataDir();
      final file = File(_logFilePath);
      await file.writeAsString(
        '${entry.toLogLine()}\n',
        mode: FileMode.append,
        encoding: utf8,
      );
    } catch (_) {
      // El log de archivo es best-effort; nunca debe romper el flujo principal.
    }
  }

  Future<void> _ensureDataDir() async {
    final dir = Directory(dataDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }
}
