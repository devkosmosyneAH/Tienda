import 'dart:async';
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'database_service.dart';
import 'analytics_service.dart';

// ============================================================
// BackgroundJobService — Motor de procesamiento asíncrono OLAP
// ============================================================
// Arquitectura: Producer-Consumer sobre tabla background_jobs
// Ejecuta jobs fuera del hilo UI usando Timers + compute()
//
// Jobs disponibles:
//  • recalculate_daily   → Recalcula summary_sales_daily
//  • recalculate_monthly → Recalcula summary_sales_monthly
//  • recalculate_annual  → Recalcula summary_sales_annual
//  • rebuild_kpi         → Reconstruye kpi_snapshot
//  • update_rfm          → Actualiza segmentos RFM de clientes
//  • refresh_analytics_product → Recalcula analytics_product
//  • update_sparklines   → Actualiza trend_sparklines
//  • maintenance         → ANALYZE + incremental_vacuum + checkpoint
// ============================================================

class BackgroundJobService {
  static final BackgroundJobService _instance =
      BackgroundJobService._internal();
  factory BackgroundJobService() => _instance;
  BackgroundJobService._internal();

  Timer? _pollingTimer;
  bool _isRunning = false;

  static const Duration _pollInterval = Duration(seconds: 30);

  Future<Database> get _db async => DatabaseService.database;

  // ==========================================================
  // SECCIÓN 1: CONTROL DEL MOTOR
  // ==========================================================

  /// Inicia el motor de background jobs.
  /// Llamar desde main() después de inicializar la BD.
  void start() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(_pollInterval, (_) => _processNextJob());
    // Primer proceso inmediato
    Timer(const Duration(seconds: 5), _processNextJob);
  }

  void stop() => _pollingTimer?.cancel();

  // ==========================================================
  // SECCIÓN 2: ENCOLADO DE JOBS
  // ==========================================================

  Future<void> enqueue({
    required String jobType,
    int? storeId,
    Map<String, dynamic>? payload,
    int priority = 5,
    Duration delay = Duration.zero,
  }) async {
    final db = await _db;
    final scheduledAt = DateTime.now().toUtc().add(delay).toIso8601String();

    await db.insert('background_jobs', {
      'job_type': jobType,
      'store_id': storeId,
      'payload': payload != null ? jsonEncode(payload) : null,
      'status': 'pending',
      'priority': priority,
      'attempts': 0,
      'scheduled_at': scheduledAt,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// Encola recálculo completo para una tienda (útil al cerrar caja).
  Future<void> enqueueFullRecalculation(int storeId) async {
    final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    final month = today.substring(0, 7);
    await Future.wait([
      enqueue(
        jobType: 'recalculate_daily',
        storeId: storeId,
        payload: {'date': today},
        priority: 1,
      ),
      enqueue(
        jobType: 'recalculate_monthly',
        storeId: storeId,
        payload: {'year_month': month},
        priority: 2,
      ),
      enqueue(jobType: 'rebuild_kpi', storeId: storeId, priority: 1),
      enqueue(
        jobType: 'update_sparklines',
        storeId: storeId,
        priority: 3,
        delay: const Duration(seconds: 10),
      ),
      enqueue(
        jobType: 'refresh_analytics_product',
        storeId: storeId,
        payload: {'period_days': 30},
        priority: 4,
        delay: const Duration(seconds: 20),
      ),
    ]);
  }

  // ==========================================================
  // SECCIÓN 3: PROCESADOR DE JOBS
  // ==========================================================

  Future<void> _processNextJob() async {
    if (_isRunning) return;
    if (!DatabaseService.isOpen) return;
    _isRunning = true;

    try {
      final db = await _db;

      // Tomar el job de mayor prioridad que está pendiente
      final rows = await db.rawQuery(
        '''
        SELECT * FROM background_jobs
        WHERE status = 'pending' AND scheduled_at <= ?
        ORDER BY priority ASC, scheduled_at ASC
        LIMIT 1
      ''',
        [DateTime.now().toUtc().toIso8601String()],
      );

      if (rows.isEmpty) return;

      final job = rows.first;
      final jobId = job['id'] as int;
      final jobType = job['job_type'] as String;
      final storeId = job['store_id'] as int?;
      final payload = job['payload'] != null
          ? jsonDecode(job['payload'] as String) as Map<String, dynamic>
          : <String, dynamic>{};

      // Marcar como running
      await db.update(
        'background_jobs',
        {
          'status': 'running',
          'started_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [jobId],
      );

      try {
        await _executeJob(
          jobType: jobType,
          storeId: storeId,
          payload: payload,
          db: db,
        );

        // Marcar como done
        await db.update(
          'background_jobs',
          {
            'status': 'done',
            'finished_at': DateTime.now().toUtc().toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [jobId],
        );
      } catch (e) {
        final attempts = (job['attempts'] as int) + 1;
        await db.update(
          'background_jobs',
          {
            'status': attempts < 3 ? 'pending' : 'failed',
            'attempts': attempts,
            'error_msg': e.toString(),
          },
          where: 'id = ?',
          whereArgs: [jobId],
        );
      }
    } on DatabaseException catch (e) {
      // La BD fue cerrada mientras el job estaba en cola; se ignora silenciosamente.
      if (e.toString().contains('database_closed')) {
        stop();
      }
    } finally {
      _isRunning = false;
    }
  }

  // ==========================================================
  // SECCIÓN 4: EJECUTORES DE JOBS
  // ==========================================================

  Future<void> _executeJob({
    required String jobType,
    required int? storeId,
    required Map<String, dynamic> payload,
    required Database db,
  }) async {
    switch (jobType) {
      case 'recalculate_daily':
        await _jobRecalculateDaily(db, storeId!, payload['date'] as String);
      case 'recalculate_monthly':
        await _jobRecalculateMonthly(
          db,
          storeId!,
          payload['year_month'] as String,
        );
      case 'recalculate_annual':
        await _jobRecalculateAnnual(
          db,
          storeId!,
          (payload['year'] as num).toInt(),
        );
      case 'rebuild_kpi':
        await _jobRebuildKpi(db, storeId!);
      case 'update_rfm':
        await _jobUpdateRfm(db);
      case 'refresh_analytics_product':
        await _jobRefreshAnalyticsProduct(
          db,
          storeId!,
          payload['period_days'] as int? ?? 30,
        );
      case 'update_sparklines':
        await _jobUpdateSparklines(db, storeId!);
      case 'maintenance':
        await _jobMaintenance(db);
      default:
        throw Exception('Unknown job type: $jobType');
    }
  }

  // ── Job 1: Recálculo diario ────────────────────────────────
  Future<void> _jobRecalculateDaily(
    Database db,
    int storeId,
    String date,
  ) async {
    final rows = await db.rawQuery(
      '''
      SELECT
        COUNT(*)                              AS total_sales,
        COALESCE(SUM(s.total),0)             AS total_revenue,
        COALESCE(SUM(si_agg.total_cost),0)   AS total_cost,
        COALESCE(SUM(si_agg.total_profit),0) AS total_profit,
        COALESCE(SUM(s.discount),0)          AS total_discount,
        COALESCE(SUM(s.tax_total),0)         AS total_tax,
        COALESCE(AVG(s.total),0)             AS avg_ticket,
        COALESCE(MAX(s.total),0)             AS max_ticket,
        COALESCE(MIN(s.total),0)             AS min_ticket,
        COALESCE(SUM(si_agg.total_units),0)  AS units_sold,
        COUNT(DISTINCT s.client_id)          AS unique_clients
      FROM sales s
      LEFT JOIN (
        SELECT sale_id,
               SUM(quantity * cost_price) AS total_cost,
               SUM(profit)                AS total_profit,
               SUM(quantity)              AS total_units
        FROM sale_items GROUP BY sale_id
      ) si_agg ON si_agg.sale_id = s.id
      WHERE s.store_id = ? AND s.sale_date = ? AND s.status = 'completed'
    ''',
      [storeId, date],
    );

    final r = rows.first;

    await db.insert('summary_sales_daily', {
      'store_id': storeId,
      'sale_date': date,
      'total_sales': r['total_sales'],
      'total_revenue': r['total_revenue'],
      'total_cost': r['total_cost'],
      'total_profit': r['total_profit'],
      'total_discount': r['total_discount'],
      'total_tax': r['total_tax'],
      'avg_ticket': r['avg_ticket'],
      'max_ticket': r['max_ticket'],
      'min_ticket': r['min_ticket'],
      'units_sold': r['units_sold'],
      'unique_clients': r['unique_clients'],
      'calculated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    // Invalidar caché de la tienda
    await AnalyticsService().invalidateStoreCache(storeId);
  }

  // ── Job 2: Recálculo mensual ───────────────────────────────
  Future<void> _jobRecalculateMonthly(
    Database db,
    int storeId,
    String yearMonth,
  ) async {
    // Agrega desde los resúmenes diarios (mucho más rápido que ir a sales)
    final rows = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(total_sales),0)    AS total_sales,
        COALESCE(SUM(total_revenue),0)  AS total_revenue,
        COALESCE(SUM(total_cost),0)     AS total_cost,
        COALESCE(SUM(total_profit),0)   AS total_profit,
        COALESCE(SUM(total_discount),0) AS total_discount,
        COALESCE(SUM(total_tax),0)      AS total_tax,
        COALESCE(AVG(avg_ticket),0)     AS avg_ticket,
        COALESCE(SUM(units_sold),0)     AS units_sold,
        COUNT(DISTINCT sale_date)       AS days_with_sales
      FROM summary_sales_daily
      WHERE store_id = ? AND substr(sale_date,1,7) = ?
    ''',
      [storeId, yearMonth],
    );

    final r = rows.first;

    await db.insert('summary_sales_monthly', {
      'store_id': storeId,
      'year_month': yearMonth,
      'total_sales': r['total_sales'],
      'total_revenue': r['total_revenue'],
      'total_cost': r['total_cost'],
      'total_profit': r['total_profit'],
      'total_discount': r['total_discount'],
      'total_tax': r['total_tax'],
      'avg_ticket': r['avg_ticket'],
      'units_sold': r['units_sold'],
      'calculated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ── Job 3: Recálculo anual ────────────────────────────────
  Future<void> _jobRecalculateAnnual(Database db, int storeId, int year) async {
    final rows = await db.rawQuery(
      '''
      SELECT
        COALESCE(SUM(total_sales),0)    AS total_sales,
        COALESCE(SUM(total_revenue),0)  AS total_revenue,
        COALESCE(SUM(total_cost),0)     AS total_cost,
        COALESCE(SUM(total_profit),0)   AS total_profit,
        COALESCE(SUM(total_discount),0) AS total_discount,
        COALESCE(AVG(total_revenue),0)  AS avg_monthly_revenue,
        COALESCE(SUM(units_sold),0)     AS units_sold
      FROM summary_sales_monthly
      WHERE store_id = ? AND substr(year_month,1,4) = ?
    ''',
      [storeId, year.toString()],
    );

    final r = rows.first;
    await db.insert('summary_sales_annual', {
      'store_id': storeId,
      'sale_year': year,
      'total_sales': r['total_sales'],
      'total_revenue': r['total_revenue'],
      'total_cost': r['total_cost'],
      'total_profit': r['total_profit'],
      'total_discount': r['total_discount'],
      'avg_monthly_revenue': r['avg_monthly_revenue'],
      'units_sold': r['units_sold'],
      'calculated_at': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ── Job 4: Reconstruir KPI snapshot ──────────────────────
  Future<void> _jobRebuildKpi(Database db, int storeId) async {
    final analytics = AnalyticsService();
    final kpi = await analytics.computeKpiLive(storeId);

    await db.insert('kpi_snapshot', {
      ...kpi,
      'store_id': storeId,
      'snapshot_date': DateTime.now().toUtc().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await analytics.invalidateStoreCache(storeId);
  }

  // ── Job 5: Actualizar RFM de clientes ────────────────────
  Future<void> _jobUpdateRfm(Database db) async {
    // Recency: días desde última compra
    // Frequency: total de compras
    // Monetary: total gastado
    final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);

    await db.execute(
      '''
      UPDATE clients SET
        rfm_recency   = CAST(julianday(?) - julianday(COALESCE(last_purchase_at, created_at)) AS INTEGER),
        rfm_frequency = total_purchases,
        rfm_monetary  = total_spent,
        rfm_score     = CASE
          WHEN total_spent > 500 AND total_purchases > 10 THEN 5
          WHEN total_spent > 200 AND total_purchases >  5 THEN 4
          WHEN total_spent > 100 AND total_purchases >  2 THEN 3
          WHEN total_spent >  50 THEN 2
          ELSE 1
        END,
        rfm_segment   = CASE
          WHEN total_spent > 500 AND total_purchases > 10
               AND CAST(julianday(?) - julianday(COALESCE(last_purchase_at,created_at)) AS INTEGER) < 30
            THEN 'champion'
          WHEN total_purchases > 5
               AND CAST(julianday(?) - julianday(COALESCE(last_purchase_at,created_at)) AS INTEGER) < 60
            THEN 'loyal'
          WHEN CAST(julianday(?) - julianday(COALESCE(last_purchase_at,created_at)) AS INTEGER) BETWEEN 60 AND 120
            THEN 'at_risk'
          WHEN CAST(julianday(?) - julianday(COALESCE(last_purchase_at,created_at)) AS INTEGER) > 120
            THEN 'lost'
          ELSE 'new'
        END
      WHERE total_purchases > 0
    ''',
      [today, today, today, today, today],
    );
  }

  // ── Job 6: Recalcular analytics_product ──────────────────
  Future<void> _jobRefreshAnalyticsProduct(
    Database db,
    int storeId,
    int periodDays,
  ) async {
    final sinceDate = DateTime.now()
        .toUtc()
        .subtract(Duration(days: periodDays))
        .toIso8601String()
        .substring(0, 10);

    // Calcular métricas por producto en el período
    final rows = await db.rawQuery(
      '''
      SELECT
        si.product_id,
        SUM(si.quantity)   AS units_sold,
        SUM(si.subtotal)   AS revenue,
        SUM(si.quantity * si.cost_price) AS cost_total,
        SUM(si.profit)     AS profit,
        COUNT(DISTINCT s.id) AS sale_count
      FROM sale_items si
      JOIN sales s ON s.id = si.sale_id
      WHERE s.store_id = ? AND s.sale_date >= ? AND s.status = 'completed'
      GROUP BY si.product_id
    ''',
      [storeId, sinceDate],
    );

    // (ranking por posición en resultados ordenados por revenue)

    // Enriquecer y guardar
    for (int i = 0; i < rows.length; i++) {
      final r = rows[i];
      final prodId = r['product_id'] as int;
      final revenue = (r['revenue'] as num).toDouble();
      final cost = (r['cost_total'] as num? ?? 0).toDouble();
      final profit = (r['profit'] as num? ?? 0).toDouble();
      final units = (r['units_sold'] as num).toInt();
      final margin = cost > 0 ? (profit / cost) * 100 : 0.0;
      final avgDaily = units / periodDays;

      // Stock actual
      final stockRows = await db.rawQuery(
        'SELECT stock, min_stock FROM inventory WHERE product_id=? AND store_id=?',
        [prodId, storeId],
      );
      final stock = stockRows.isNotEmpty
          ? (stockRows.first['stock'] as int)
          : 0;
      final daysStock = avgDaily > 0 ? stock / avgDaily : 999.0;

      // Saleability score (0-100)
      final rotationBonus = (avgDaily * 10).clamp(0, 25).toDouble();
      final marginBonus = margin.clamp(0, 15).toDouble();
      final stockPenalty = stock <= 0
          ? 15
          : (stockRows.isNotEmpty &&
                    stock <= (stockRows.first['min_stock'] as int? ?? 0)
                ? 10
                : 0);
      final score = (50 + rotationBonus + marginBonus - stockPenalty)
          .clamp(0, 100)
          .toInt();

      await db.insert('analytics_product', {
        'product_id': prodId,
        'store_id': storeId,
        'period_days': periodDays,
        'units_sold': units,
        'revenue': revenue,
        'cost_total': cost,
        'profit': profit,
        'profit_margin': margin,
        'avg_daily_sales': avgDaily,
        'rotation_rate': avgDaily,
        'days_of_stock': daysStock,
        'saleability_score': score,
        'rank_by_revenue': i + 1,
        'rank_by_units': i + 1,
        'calculated_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  // ── Job 7: Actualizar sparklines ─────────────────────────
  Future<void> _jobUpdateSparklines(Database db, int storeId) async {
    for (final days in [7, 30]) {
      final since = DateTime.now()
          .toUtc()
          .subtract(Duration(days: days))
          .toIso8601String()
          .substring(0, 10);

      final rows = await db.rawQuery(
        '''
        SELECT sale_date AS date, total_revenue AS value
        FROM summary_sales_daily
        WHERE store_id = ? AND sale_date >= ?
        ORDER BY sale_date ASC
      ''',
        [storeId, since],
      );

      final data = rows
          .map((r) => {'date': r['date'], 'value': r['value']})
          .toList();

      await db.insert('trend_sparklines', {
        'store_id': storeId,
        'metric': 'revenue',
        'period_type': 'daily_$days',
        'data_json': jsonEncode(data),
        'calculated_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }

  // ── Job 8: Mantenimiento SQLite ──────────────────────────
  Future<void> _jobMaintenance(Database db) async {
    // Actualizar estadísticas del query planner (crítico para índices)
    await db.execute('ANALYZE sales');
    await db.execute('ANALYZE sale_items');
    await db.execute('ANALYZE inventory');
    await db.execute('ANALYZE products');
    await db.execute('ANALYZE clients');

    // Recuperar espacio incremental sin bloquear
    await db.execute('PRAGMA incremental_vacuum(200)');

    // Checkpoint del WAL (asegura datos en el archivo principal)
    await db.execute('PRAGMA wal_checkpoint(PASSIVE)');

    // Limpiar caché expirado
    await db.delete(
      'analytics_cache',
      where: 'expires_at < ?',
      whereArgs: [DateTime.now().toUtc().toIso8601String()],
    );

    // Limpiar jobs completados hace más de 7 días
    await db.delete(
      'background_jobs',
      where: "status IN ('done','failed') AND finished_at < ?",
      whereArgs: [
        DateTime.now()
            .toUtc()
            .subtract(const Duration(days: 7))
            .toIso8601String(),
      ],
    );
  }

  // ==========================================================
  // SECCIÓN 5: SCHEDULER DE MANTENIMIENTO
  // ==========================================================

  /// Programa mantenimiento diario automático (al iniciar la app).
  Future<void> scheduleDailyMaintenance() async {
    final db = await _db;

    // Verificar si ya se ejecutó hoy
    final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    final existing = await db.rawQuery(
      '''
      SELECT id FROM background_jobs
      WHERE job_type = 'maintenance' AND date(scheduled_at) = ?
        AND status IN ('pending','running','done')
      LIMIT 1
    ''',
      [today],
    );

    if (existing.isEmpty) {
      await enqueue(jobType: 'maintenance', priority: 10);
    }
  }
}
