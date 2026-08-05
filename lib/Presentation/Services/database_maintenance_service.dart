// ignore_for_file: avoid_print
import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'database_service.dart';

/// ============================================================
///  DatabaseMaintenanceService — Enterprise SQLite Maintenance
/// ============================================================
///
///  Responsabilidades:
///  • ANALYZE de tablas críticas (actualiza estadísticas del query planner)
///  • Incremental VACUUM (recupera espacio sin bloquear)
///  • WAL checkpoint (PASSIVE → FULL → TRUNCATE según umbral)
///  • Limpieza de caché expirado (analytics_cache)
///  • Limpieza de jobs obsoletos (background_jobs)
///  • Integridad rápida (PRAGMA quick_check)
///  • Reporte de métricas de salud de la BD
///  • Timer de mantenimiento periódico automático
///
///  Uso:
///  ```dart
///  final maint = DatabaseMaintenanceService();
///  await maint.runFullMaintenance();          // una vez
///  maint.startPeriodicMaintenance();          // cada 6h automático
///  final health = await maint.healthReport(); // métricas
///  ```
/// ============================================================
class DatabaseMaintenanceService {
  // ── Singleton ──────────────────────────────────────────────
  DatabaseMaintenanceService._();
  static final DatabaseMaintenanceService _instance =
      DatabaseMaintenanceService._();
  factory DatabaseMaintenanceService() => _instance;

  // ── Configuración ──────────────────────────────────────────
  /// Tablas OLTP que se analizan en cada ciclo completo.
  static const List<String> _criticalTables = [
    'sales',
    'sale_items',
    'inventory',
    'products',
    'clients',
    'purchases',
    'purchase_items',
    'cash_sessions',
    'cash_movements',
  ];

  /// Páginas a recuperar por ciclo de incremental_vacuum (128 × 4KB ≈ 512 KB).
  static const int _vacuumPages = 128;

  /// Umbral de páginas WAL para activar checkpoint FULL (en lugar de PASSIVE).
  static const int _walFullThreshold = 2000;

  /// Días que se conservan jobs completados/fallidos.
  static const int _jobRetentionDays = 7;

  /// Días que se conservan snapshots de KPI históricos.
  static const int _kpiRetentionDays = 90;

  Timer? _periodicTimer;
  DateTime? _lastFullMaintenance;

  Future<Database> get _db async => await DatabaseService.database;

  // ==========================================================
  // SECCIÓN 1: MANTENIMIENTO COMPLETO
  // ==========================================================

  /// Ejecuta el ciclo completo de mantenimiento.
  /// Retorna un mapa de métricas con los resultados de cada paso.
  Future<Map<String, dynamic>> runFullMaintenance() async {
    final stopwatch = Stopwatch()..start();
    final metrics = <String, dynamic>{};

    try {
      final db = await _db;

      print('[DBMaint] ▶ Iniciando ciclo de mantenimiento completo...');

      // 1. ANALYZE
      metrics['analyze'] = await _runAnalyze(db);

      // 2. Incremental VACUUM
      metrics['vacuum'] = await _runIncrementalVacuum(db);

      // 3. WAL Checkpoint
      metrics['wal_checkpoint'] = await _runWalCheckpoint(db);

      // 4. Limpiar caché expirado
      metrics['cache_cleaned'] = await _cleanExpiredCache(db);

      // 5. Limpiar jobs obsoletos
      metrics['jobs_cleaned'] = await _cleanOldJobs(db);

      // 6. Limpiar KPI snapshots antiguos
      metrics['kpi_cleaned'] = await _cleanOldKpiSnapshots(db);

      // 7. Quick check de integridad
      metrics['integrity_ok'] = await _quickIntegrityCheck(db);

      // 8. Métricas de salud
      metrics['health'] = await _collectHealthMetrics(db);

      stopwatch.stop();
      metrics['duration_ms'] = stopwatch.elapsedMilliseconds;
      metrics['ran_at'] = DateTime.now().toUtc().toIso8601String();

      _lastFullMaintenance = DateTime.now();

      print(
        '[DBMaint] ✅ Mantenimiento completado en ${stopwatch.elapsedMilliseconds}ms',
      );
    } catch (e, st) {
      stopwatch.stop();
      metrics['error'] = e.toString();
      metrics['duration_ms'] = stopwatch.elapsedMilliseconds;
      print('[DBMaint] ❌ Error en mantenimiento: $e\n$st');
    }

    return metrics;
  }

  // ==========================================================
  // SECCIÓN 2: PASOS INDIVIDUALES
  // ==========================================================

  /// Actualiza estadísticas del query planner para las tablas críticas.
  /// Sin esto, SQLite puede ignorar índices en tablas grandes.
  Future<Map<String, dynamic>> _runAnalyze(Database db) async {
    final sw = Stopwatch()..start();
    for (final table in _criticalTables) {
      try {
        await db.execute('ANALYZE $table');
      } catch (_) {
        // Tabla puede no existir en bases antiguas
      }
    }
    // Persistir estadísticas en sqlite_stat1
    await db.execute('ANALYZE');
    sw.stop();
    print('[DBMaint]   ANALYZE: ${sw.elapsedMilliseconds}ms');
    return {
      'tables': _criticalTables.length,
      'duration_ms': sw.elapsedMilliseconds,
    };
  }

  /// Recupera espacio de páginas borradas sin bloquear lectores.
  Future<Map<String, dynamic>> _runIncrementalVacuum(Database db) async {
    final sw = Stopwatch()..start();

    // Activar modo freelist para vacuum incremental
    await db.execute('PRAGMA auto_vacuum = INCREMENTAL');
    final result = await db.rawQuery(
      'PRAGMA incremental_vacuum($_vacuumPages)',
    );
    sw.stop();
    print('[DBMaint]   VACUUM incremental: ${sw.elapsedMilliseconds}ms');
    return {
      'pages_recovered': _vacuumPages,
      'result_rows': result.length,
      'duration_ms': sw.elapsedMilliseconds,
    };
  }

  /// Checkpoint del WAL: mueve páginas del .wal al archivo principal.
  /// Usa FULL si hay muchas páginas pendientes, PASSIVE si el umbral es bajo.
  Future<Map<String, dynamic>> _runWalCheckpoint(Database db) async {
    final sw = Stopwatch()..start();

    // Verificar tamaño del WAL primero
    final walPages = await db.rawQuery('PRAGMA wal_size');
    final pages = walPages.isNotEmpty
        ? (walPages.first.values.first as int? ?? 0)
        : 0;

    final mode = pages > _walFullThreshold ? 'FULL' : 'PASSIVE';
    final result = await db.rawQuery('PRAGMA wal_checkpoint($mode)');

    sw.stop();
    final row = result.isNotEmpty ? result.first : {};
    print('[DBMaint]   WAL checkpoint ($mode): ${sw.elapsedMilliseconds}ms');
    return {
      'mode': mode,
      'wal_pages': pages,
      'busy': row['busy'] ?? 0,
      'log': row['log'] ?? 0,
      'checkpointed': row['checkpointed'] ?? 0,
      'duration_ms': sw.elapsedMilliseconds,
    };
  }

  /// Elimina entradas de caché cuyo TTL ha vencido.
  Future<int> _cleanExpiredCache(Database db) async {
    final now = DateTime.now().toUtc().toIso8601String();
    final deleted = await db.delete(
      'analytics_cache',
      where: 'expires_at < ?',
      whereArgs: [now],
    );
    if (deleted > 0) print('[DBMaint]   Cache limpiado: $deleted entradas');
    return deleted;
  }

  /// Elimina background_jobs completados/fallidos con más de [_jobRetentionDays].
  Future<int> _cleanOldJobs(Database db) async {
    final cutoff = DateTime.now()
        .toUtc()
        .subtract(Duration(days: _jobRetentionDays))
        .toIso8601String();
    final deleted = await db.delete(
      'background_jobs',
      where: "status IN ('done','failed') AND finished_at < ?",
      whereArgs: [cutoff],
    );
    if (deleted > 0) print('[DBMaint]   Jobs obsoletos eliminados: $deleted');
    return deleted;
  }

  /// Elimina snapshots KPI más antiguos que [_kpiRetentionDays] días.
  Future<int> _cleanOldKpiSnapshots(Database db) async {
    final cutoff = DateTime.now()
        .toUtc()
        .subtract(Duration(days: _kpiRetentionDays))
        .toIso8601String();
    try {
      final deleted = await db.delete(
        'kpi_snapshot',
        where: 'snapshot_date < ?',
        whereArgs: [cutoff],
      );
      if (deleted > 0) print('[DBMaint]   KPI snapshots antiguos: $deleted');
      return deleted;
    } catch (_) {
      return 0;
    }
  }

  /// Verifica integridad rápida (no bloquea, solo lee).
  Future<bool> _quickIntegrityCheck(Database db) async {
    try {
      final result = await db.rawQuery('PRAGMA quick_check(10)');
      final ok =
          result.isNotEmpty && result.first.values.first.toString() == 'ok';
      if (!ok) {
        print('[DBMaint] ⚠️  quick_check reportó problemas: $result');
      }
      return ok;
    } catch (e) {
      print('[DBMaint] ⚠️  quick_check falló: $e');
      return false;
    }
  }

  // ==========================================================
  // SECCIÓN 3: REPORTE DE SALUD
  // ==========================================================

  /// Recolecta métricas de salud de la base de datos.
  Future<Map<String, dynamic>> _collectHealthMetrics(Database db) async {
    final metrics = <String, dynamic>{};

    // Tamaño de la BD en páginas y bytes
    final pageSize =
        (await db.rawQuery('PRAGMA page_size')).first.values.first as int;
    final pageCount =
        (await db.rawQuery('PRAGMA page_count')).first.values.first as int;
    final freelistCount =
        (await db.rawQuery('PRAGMA freelist_count')).first.values.first as int;
    metrics['page_size_bytes'] = pageSize;
    metrics['total_pages'] = pageCount;
    metrics['free_pages'] = freelistCount;
    metrics['db_size_mb'] = ((pageSize * pageCount) / 1024 / 1024)
        .toStringAsFixed(2);
    metrics['fragmentation_pct'] = pageCount > 0
        ? (freelistCount / pageCount * 100).toStringAsFixed(1)
        : '0';

    // WAL
    try {
      final walInfo = await db.rawQuery('PRAGMA wal_checkpoint(PASSIVE)');
      if (walInfo.isNotEmpty) {
        metrics['wal_log_pages'] = walInfo.first['log'] ?? 0;
        metrics['wal_checkpointed'] = walInfo.first['checkpointed'] ?? 0;
      }
    } catch (_) {}

    // Conteos de tablas OLAP
    for (final t in ['background_jobs', 'analytics_cache', 'kpi_snapshot']) {
      try {
        final r = await db.rawQuery('SELECT COUNT(*) AS c FROM $t');
        metrics['count_$t'] = (r.first['c'] as int?) ?? 0;
      } catch (_) {
        metrics['count_$t'] = -1;
      }
    }

    // Jobs pendientes
    try {
      final pending = await db.rawQuery(
        "SELECT COUNT(*) AS c FROM background_jobs WHERE status='pending'",
      );
      metrics['pending_jobs'] = (pending.first['c'] as int?) ?? 0;
    } catch (_) {}

    return metrics;
  }

  /// Retorna un reporte completo de salud de la BD (sin modificar nada).
  Future<Map<String, dynamic>> healthReport() async {
    final db = await _db;
    final health = await _collectHealthMetrics(db);
    health['integrity_ok'] = await _quickIntegrityCheck(db);
    health['last_maintenance'] = _lastFullMaintenance?.toIso8601String();
    return health;
  }

  // ==========================================================
  // SECCIÓN 4: OPERACIONES PUNTUALES PÚBLICAS
  // ==========================================================

  /// Solo ANALYZE (útil tras importación masiva de datos).
  Future<void> analyze() async {
    final db = await _db;
    await _runAnalyze(db);
  }

  /// Solo WAL checkpoint (útil antes de un backup).
  Future<Map<String, dynamic>> walCheckpoint({bool full = false}) async {
    final db = await _db;
    final mode = full ? 'FULL' : 'PASSIVE';
    final result = await db.rawQuery('PRAGMA wal_checkpoint($mode)');
    return result.isNotEmpty ? Map<String, dynamic>.from(result.first) : {};
  }

  /// Ejecuta un VACUUM completo (reconstruye el archivo, puede tardar).
  /// ⚠️ Bloquea la BD durante su ejecución. Solo usar cuando la app está inactiva.
  Future<void> fullVacuum() async {
    print('[DBMaint] ⚙️  Iniciando VACUUM completo (bloqueante)...');
    final db = await _db;
    await db.execute('VACUUM');
    print('[DBMaint] ✅ VACUUM completo finalizado');
  }

  /// Elimina caché expirado manualmente (por ejemplo, al cambiar de tienda).
  Future<int> clearExpiredCache() async {
    final db = await _db;
    return _cleanExpiredCache(db);
  }

  /// Limpia
  /// t odo el caché analítico (útil tras actualización de datos masiva).
  Future<int> clearAllAnalyticsCache() async {
    final db = await _db;
    return db.delete('analytics_cache');
  }

  // ==========================================================
  // SECCIÓN 5: TIMER PERIÓDICO AUTOMÁTICO
  // ==========================================================

  /// Inicia mantenimiento periódico automático cada [intervalHours] horas.
  /// Por defecto cada 6 horas. No bloquea el hilo principal.
  void startPeriodicMaintenance({int intervalHours = 6}) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(
      Duration(hours: intervalHours),
      (_) => runFullMaintenance(),
    );
    print(
      '[DBMaint] 🕐 Mantenimiento periódico activo: cada ${intervalHours}h',
    );
  }

  /// Detiene el timer periódico.
  void stopPeriodicMaintenance() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
    print('[DBMaint] ⏹ Mantenimiento periódico detenido');
  }

  /// Verdadero si el timer está activo.
  bool get isRunning => _periodicTimer?.isActive ?? false;

  /// Fecha/hora del último mantenimiento completo.
  DateTime? get lastMaintenanceTime => _lastFullMaintenance;

  // ==========================================================
  // SECCIÓN 6: DIAGNÓSTICO DE ÍNDICES
  // ==========================================================

  /// Retorna las estadísticas de los índices (sqlite_stat1).
  /// Útil para detectar índices no usados o faltantes.
  Future<List<Map<String, dynamic>>> indexStats() async {
    final db = await _db;
    try {
      return await db.rawQuery(
        'SELECT tbl, idx, stat FROM sqlite_stat1 ORDER BY tbl, idx',
      );
    } catch (_) {
      return [];
    }
  }

  /// Retorna el plan de ejecución (EXPLAIN QUERY PLAN) de una consulta.
  /// Útil para verificar que los índices se están usando.
  Future<List<Map<String, dynamic>>> explainQueryPlan(
    String sql, [
    List<Object?> args = const [],
  ]) async {
    final db = await _db;
    return db.rawQuery('EXPLAIN QUERY PLAN $sql', args);
  }

  /// Verifica que los índices críticos existen en la BD.
  Future<Map<String, bool>> verifyCriticalIndexes() async {
    final db = await _db;
    const criticalIndexes = [
      'idx_sales_store_date',
      'idx_sale_items_product',
      'idx_inventory_product_store',
      'idx_summary_daily_store_date',
      'idx_summary_monthly_store',
      'idx_analytics_product_store',
      'idx_kpi_store',
      'idx_bg_jobs',
    ];

    final existing = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='index'",
    );
    final existingNames = existing.map((r) => r['name'] as String).toSet();

    return {
      for (final idx in criticalIndexes) idx: existingNames.contains(idx),
    };
  }
}
