import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import 'database_service.dart';

// ============================================================
// AnalyticsService — Capa OLAP Enterprise para BazarNicole
// ============================================================
// Responsabilidades:
//  • Leer SOLO las tablas summary_* y analytics_* (OLAP)
//  • NUNCA ejecutar JOINs masivos en el hilo principal
//  • Usar Isolate para cómputos pesados
//  • Gestionar analytics_cache con TTL
//  • Proveer KPI snapshots, sparklines y rankings
// ============================================================

class AnalyticsService {
  // ─── Singleton ────────────────────────────────────────────
  static final AnalyticsService _instance = AnalyticsService._internal();
  factory AnalyticsService() => _instance;
  AnalyticsService._internal();

  // ─── Constantes de caché ──────────────────────────────────
  static const int _cacheTtlSeconds = 300; // 5 minutos default
  static const int _cacheTtlKpi = 60; // 1 minuto para KPIs
  static const int _cacheTtlReport = 900; // 15 minutos reportes

  // ─── Obtener DB ───────────────────────────────────────────
  Future<Database> get _db async => DatabaseService.database;

  // ==========================================================
  // SECCIÓN 1: CACHÉ ANALÍTICO
  // ==========================================================

  /// Guarda resultado en analytics_cache con TTL.
  Future<void> setCacheEntry({
    required String key,
    required Map<String, dynamic> data,
    int ttlSeconds = _cacheTtlSeconds,
  }) async {
    final db = await _db;
    final now = DateTime.now().toUtc();
    final expires = now.add(Duration(seconds: ttlSeconds));
    await db.insert('analytics_cache', {
      'cache_key': key,
      'payload': jsonEncode(data),
      'ttl_seconds': ttlSeconds,
      'created_at': now.toIso8601String(),
      'expires_at': expires.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  /// Lee del caché. Retorna null si expiró o no existe.
  Future<Map<String, dynamic>?> getCacheEntry(String key) async {
    final db = await _db;
    final rows = await db.rawQuery(
      'SELECT payload FROM analytics_cache '
      'WHERE cache_key = ? AND expires_at > ? LIMIT 1',
      [key, DateTime.now().toUtc().toIso8601String()],
    );
    if (rows.isEmpty) return null;
    return jsonDecode(rows.first['payload'] as String) as Map<String, dynamic>;
  }

  /// Invalida todas las entradas de caché de una tienda.
  Future<void> invalidateStoreCache(int storeId) async {
    final db = await _db;
    await db.delete(
      'analytics_cache',
      where: "cache_key LIKE ?",
      whereArgs: ['store_${storeId}_%'],
    );
  }

  // ==========================================================
  // SECCIÓN 2: KPI SNAPSHOT (Dashboard principal)
  // ==========================================================

  /// Retorna el KPI snapshot más reciente de la tienda.
  /// Si no existe o es del día anterior, dispara recálculo en background.
  Future<Map<String, dynamic>> getKpiSnapshot(int storeId) async {
    const cacheKey = 'kpi_';
    final key = '$cacheKey$storeId';
    final cached = await getCacheEntry(key);
    if (cached != null) return cached;

    final db = await _db;

    // Leer snapshot pre-calculado
    final rows = await db.rawQuery(
      'SELECT * FROM kpi_snapshot WHERE store_id = ? '
      'ORDER BY snapshot_date DESC LIMIT 1',
      [storeId],
    );

    Map<String, dynamic> kpi;
    if (rows.isNotEmpty) {
      kpi = Map<String, dynamic>.from(rows.first);
    } else {
      // Calcular en vivo solo si no hay snapshot (primera vez)
      kpi = await computeKpiLive(storeId);
    }

    await setCacheEntry(key: key, data: kpi, ttlSeconds: _cacheTtlKpi);
    return kpi;
  }

  /// Cálculo vivo de KPI (solo cuando no existe snapshot).
  /// Diseñado para ser rápido usando columnas generadas de sales.
  /// Expuesto sin underscore para permitir uso desde BackgroundJobService.
  Future<Map<String, dynamic>> computeKpiLive(int storeId) async {
    final db = await _db;
    final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
    final weekStart = _weekStart();
    final monthStart = today.substring(0, 7);

    // Ejecutar queries en batch (no en paralelo — SQLite es single-writer)
    final results = await Future.wait([
      db.rawQuery(
        '''
        SELECT COALESCE(SUM(total),0) AS rev, COUNT(*) AS cnt,
               COALESCE(SUM(total - COALESCE(tax_total,0)),0) AS profit
        FROM sales WHERE store_id=? AND sale_date=? AND status='completed'
      ''',
        [storeId, today],
      ),
      db.rawQuery(
        '''
        SELECT COALESCE(SUM(total),0) AS rev, COUNT(*) AS cnt
        FROM sales WHERE store_id=? AND sale_date>=? AND status='completed'
      ''',
        [storeId, weekStart],
      ),
      db.rawQuery(
        '''
        SELECT COALESCE(SUM(total),0) AS rev, COALESCE(SUM(total * (1 - COALESCE(discount,0)/NULLIF(total,0))),0) AS profit
        FROM sales WHERE store_id=? AND year_month=? AND status='completed'
      ''',
        [storeId, monthStart],
      ),
      db.rawQuery(
        '''
        SELECT COUNT(*) AS cnt FROM inventory
        WHERE store_id=? AND stock <= min_stock AND min_stock > 0
      ''',
        [storeId],
      ),
      db.rawQuery(
        '''
        SELECT COALESCE(SUM(balance),0) AS total_balance
        FROM credit_sales cr JOIN sales s ON s.id=cr.sale_id
        WHERE s.store_id=? AND cr.status NOT IN ('paid','cancelled')
      ''',
        [storeId],
      ),
    ]);

    final todayData = results[0].first;
    final weekData = results[1].first;
    final monthData = results[2].first;
    final stockAlert = results[3].first;
    final creditData = results[4].first;

    return {
      'store_id': storeId,
      'snapshot_date': DateTime.now().toUtc().toIso8601String(),
      'revenue_today': todayData['rev'],
      'sales_today': todayData['cnt'],
      'profit_today': todayData['profit'],
      'revenue_week': weekData['rev'],
      'sales_week': weekData['cnt'],
      'revenue_month': monthData['rev'],
      'profit_month': monthData['profit'],
      'low_stock_count': stockAlert['cnt'],
      'credit_balance': creditData['total_balance'],
    };
  }

  String _weekStart() {
    final now = DateTime.now().toUtc();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return monday.toIso8601String().substring(0, 10);
  }

  // ==========================================================
  // SECCIÓN 3: RESÚMENES TEMPORALES (OLAP puro)
  // ==========================================================

  /// Revenue diario últimos N días. USA summary_sales_daily (no JOINs).
  Future<List<Map<String, dynamic>>> getDailySummary({
    required int storeId,
    int days = 30,
  }) async {
    final cacheKey = 'store_${storeId}_daily_$days';
    final cached = await getCacheEntry(cacheKey);
    if (cached != null) {
      return List<Map<String, dynamic>>.from(cached['rows'] as List);
    }

    final db = await _db;
    final since = DateTime.now()
        .toUtc()
        .subtract(Duration(days: days))
        .toIso8601String()
        .substring(0, 10);

    final rows = await db.rawQuery(
      '''
      SELECT sale_date, total_revenue, total_cost, total_profit,
             avg_ticket, units_sold, unique_clients, total_sales
      FROM summary_sales_daily
      WHERE store_id = ? AND sale_date >= ?
      ORDER BY sale_date DESC
    ''',
      [storeId, since],
    );

    final result = rows.map((r) => Map<String, dynamic>.from(r)).toList();
    await setCacheEntry(
      key: cacheKey,
      data: {'rows': result},
      ttlSeconds: _cacheTtlReport,
    );
    return result;
  }

  /// Resumen mensual últimos N meses.
  Future<List<Map<String, dynamic>>> getMonthlySummary({
    required int storeId,
    int months = 12,
  }) async {
    final cacheKey = 'store_${storeId}_monthly_$months';
    final cached = await getCacheEntry(cacheKey);
    if (cached != null) {
      return List<Map<String, dynamic>>.from(cached['rows'] as List);
    }

    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT year_month, total_revenue, total_cost, total_profit,
             total_sales, avg_ticket, units_sold, unique_clients,
             new_clients, credit_ratio
      FROM summary_sales_monthly
      WHERE store_id = ?
      ORDER BY year_month DESC
      LIMIT ?
    ''',
      [storeId, months],
    );

    final result = rows.map((r) => Map<String, dynamic>.from(r)).toList();
    await setCacheEntry(key: cacheKey, data: {'rows': result});
    return result;
  }

  // ==========================================================
  // SECCIÓN 4: TOP PRODUCTOS OLAP
  // ==========================================================

  /// Top N productos por revenue/profit/unidades (usa analytics_product).
  Future<List<Map<String, dynamic>>> getTopProducts({
    required int storeId,
    int periodDays = 30,
    String orderBy = 'revenue', // 'revenue' | 'profit' | 'units' | 'score'
    int limit = 10,
  }) async {
    final cacheKey =
        'store_${storeId}_top_products_${periodDays}_${orderBy}_$limit';
    final cached = await getCacheEntry(cacheKey);
    if (cached != null) {
      return List<Map<String, dynamic>>.from(cached['rows'] as List);
    }

    final db = await _db;
    final orderCol = switch (orderBy) {
      'profit' => 'ap.profit',
      'units' => 'ap.units_sold',
      'score' => 'ap.saleability_score',
      _ => 'ap.revenue',
    };

    final rows = await db.rawQuery(
      '''
      SELECT p.id, p.name, p.sku, p.price, p.cost_price,
             cat.name AS category_name,
             ap.units_sold, ap.revenue, ap.profit, ap.profit_margin,
             ap.saleability_score, ap.days_of_stock, ap.rotation_rate,
             inv.stock AS current_stock
      FROM analytics_product ap
      JOIN products p   ON p.id  = ap.product_id
      LEFT JOIN categories cat ON cat.id = p.category_id
      LEFT JOIN inventory inv  ON inv.product_id = ap.product_id
                               AND inv.store_id  = ap.store_id
      WHERE ap.store_id = ? AND ap.period_days = ?
      ORDER BY $orderCol DESC
      LIMIT ?
    ''',
      [storeId, periodDays, limit],
    );

    final result = rows.map((r) => Map<String, dynamic>.from(r)).toList();
    await setCacheEntry(key: cacheKey, data: {'rows': result});
    return result;
  }

  // ==========================================================
  // SECCIÓN 5: ANALYTICS DE CLIENTES (RFM)
  // ==========================================================

  /// Distribución de segmentos RFM para mapa de clientes.
  Future<List<Map<String, dynamic>>> getClientRfmDistribution(
    int storeId,
  ) async {
    final cacheKey = 'store_${storeId}_rfm_dist';
    final cached = await getCacheEntry(cacheKey);
    if (cached != null) {
      return List<Map<String, dynamic>>.from(cached['rows'] as List);
    }

    final db = await _db;
    // rfm_segment está desnormalizado en clients — O(1) por índice
    final rows = await db.rawQuery('''
      SELECT rfm_segment, COUNT(*) AS count,
             AVG(rfm_monetary) AS avg_spent,
             SUM(rfm_monetary) AS total_spent
      FROM clients
      GROUP BY rfm_segment
      ORDER BY total_spent DESC
    ''');

    final result = rows.map((r) => Map<String, dynamic>.from(r)).toList();
    await setCacheEntry(key: cacheKey, data: {'rows': result}, ttlSeconds: 600);
    return result;
  }

  /// Top N clientes por LTV (Lifetime Value).
  Future<List<Map<String, dynamic>>> getTopClientsByLtv({
    required int storeId,
    int limit = 20,
  }) async {
    final db = await _db;
    // Usa total_spent desnormalizado en clients — sin JOINs costosos
    final rows = await db.rawQuery(
      '''
      SELECT c.id, c.name, c.phone, c.email,
             c.total_purchases, c.total_spent,
             c.rfm_segment, c.rfm_score, c.last_purchase_at,
             COALESCE(cr.balance, 0) AS credit_balance
      FROM clients c
      LEFT JOIN (
        SELECT s.client_id, SUM(cr2.balance) AS balance
        FROM credit_sales cr2
        JOIN sales s ON s.id = cr2.sale_id
        WHERE cr2.status NOT IN ('paid','cancelled')
        GROUP BY s.client_id
      ) cr ON cr.client_id = c.id
      WHERE c.total_purchases > 0
      ORDER BY c.total_spent DESC
      LIMIT ?
    ''',
      [limit],
    );

    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  // ==========================================================
  // SECCIÓN 6: CARTERA DE CRÉDITO
  // ==========================================================

  Future<Map<String, dynamic>> getCreditPortfolioSummary(int storeId) async {
    final cacheKey = 'store_${storeId}_credit_summary';
    final cached = await getCacheEntry(cacheKey);
    if (cached != null) return cached;

    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT
        COUNT(*)                              AS total_credits,
        COALESCE(SUM(cr.total),0)             AS total_granted,
        COALESCE(SUM(cr.paid),0)              AS total_collected,
        COALESCE(SUM(cr.balance),0)           AS total_balance,
        SUM(CASE WHEN cr.status='overdue' OR
             (cr.due_date IS NOT NULL AND cr.due_date < date('now'))
             THEN cr.balance ELSE 0 END)      AS overdue_balance,
        SUM(CASE WHEN cr.status='pending'     THEN 1 ELSE 0 END) AS pending_count,
        SUM(CASE WHEN cr.status='partial'     THEN 1 ELSE 0 END) AS partial_count,
        AVG(cr.total)                          AS avg_credit
      FROM credit_sales cr
      JOIN sales s ON s.id = cr.sale_id
      WHERE s.store_id = ? AND cr.status NOT IN ('paid','cancelled')
    ''',
      [storeId],
    );

    final result = Map<String, dynamic>.from(rows.first);
    await setCacheEntry(key: cacheKey, data: result, ttlSeconds: _cacheTtlKpi);
    return result;
  }

  // ==========================================================
  // SECCIÓN 7: SPARKLINES para dashboard
  // ==========================================================

  /// Retorna datos para sparkline de revenue últimos 7/30 días.
  Future<List<Map<String, dynamic>>> getRevenueSparkline({
    required int storeId,
    int days = 30,
  }) async {
    // Intenta leer trend pre-calculado
    final db = await _db;
    final trendRows = await db.rawQuery(
      '''
      SELECT data_json FROM trend_sparklines
      WHERE store_id = ? AND metric = 'revenue' AND period_type = ?
        AND calculated_at > datetime('now', '-1 hour')
    ''',
      [storeId, 'daily_$days'],
    );

    if (trendRows.isNotEmpty) {
      final raw = jsonDecode(trendRows.first['data_json'] as String) as List;
      return raw.cast<Map<String, dynamic>>();
    }

    // Fallback: leer de summary diario (ya es O(n) simple, no JOIN)
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

    return rows.map((r) => Map<String, dynamic>.from(r)).toList();
  }

  // ==========================================================
  // SECCIÓN 8: INVENTARIO ANALÍTICO
  // ==========================================================

  /// Resumen de inversión en inventario por tienda.
  Future<Map<String, dynamic>> getInventoryInvestmentSummary(
    int storeId,
  ) async {
    final cacheKey = 'store_${storeId}_inv_investment';
    final cached = await getCacheEntry(cacheKey);
    if (cached != null) return cached;

    final db = await _db;
    final rows = await db.rawQuery(
      '''
      SELECT
        COUNT(DISTINCT inv.product_id)          AS total_products,
        COALESCE(SUM(inv.stock),0)              AS total_units,
        COALESCE(SUM(inv.stock * p.cost_price),0) AS total_invested,
        COALESCE(SUM(inv.stock * p.price),0)    AS potential_revenue,
        COALESCE(SUM(inv.stock * (p.price - p.cost_price)),0) AS potential_profit,
        COUNT(CASE WHEN inv.stock <= inv.min_stock AND inv.min_stock > 0 THEN 1 END) AS critical_stock_count,
        COUNT(CASE WHEN inv.stock = 0 THEN 1 END) AS out_of_stock_count
      FROM inventory inv
      JOIN products p ON p.id = inv.product_id AND p.is_active = 1
      WHERE inv.store_id = ?
    ''',
      [storeId],
    );

    final result = Map<String, dynamic>.from(rows.first);
    await setCacheEntry(key: cacheKey, data: result, ttlSeconds: 300);
    return result;
  }

  // ==========================================================
  // SECCIÓN 9: ANALYTICS EN ISOLATE (reportes masivos)
  // ==========================================================

  /// Genera reporte completo en Isolate para NO congelar la UI.
  /// Retorna un Map con todas las secciones del reporte.
  Future<Map<String, dynamic>> generateFullReportInBackground({
    required int storeId,
    required String fromDate,
    required String toDate,
  }) async {
    final dbPath = await DatabaseService.getDatabasePath();

    final result = await Isolate.run(() async {
      return _isolateFullReport(
        dbPath: dbPath,
        storeId: storeId,
        fromDate: fromDate,
        toDate: toDate,
      );
    });

    return result;
  }

  // Función de nivel superior para el Isolate (no puede ser método de instancia)
  static Future<Map<String, dynamic>> _isolateFullReport({
    required String dbPath,
    required int storeId,
    required String fromDate,
    required String toDate,
  }) async {
    // El Isolate abre su propia conexión de solo lectura
    debugPrint('Opening database:');
    debugPrint(dbPath);

    final db = await DatabaseService.openReadOnlyDatabase(dbPath);

    try {
      // Resumen de ventas del período
      final salesSummary = await db.rawQuery(
        '''
        SELECT COUNT(*) AS total_sales,
               COALESCE(SUM(total),0)    AS total_revenue,
               COALESCE(SUM(discount),0) AS total_discount,
               COALESCE(SUM(tax_total),0) AS total_tax,
               AVG(total)                AS avg_ticket,
               MAX(total)                AS max_ticket,
               COUNT(DISTINCT client_id) AS unique_clients
        FROM sales
        WHERE store_id = ? AND sale_date BETWEEN ? AND ? AND status = 'completed'
      ''',
        [storeId, fromDate, toDate],
      );

      // Top 20 productos del período
      final topProducts = await db.rawQuery(
        '''
        SELECT p.name, p.sku, SUM(si.quantity) AS units,
               SUM(si.subtotal) AS revenue,
               SUM(si.profit) AS profit
        FROM sale_items si
        JOIN sales s ON s.id = si.sale_id
        JOIN products p ON p.id = si.product_id
        WHERE s.store_id = ? AND s.sale_date BETWEEN ? AND ?
          AND s.status = 'completed'
        GROUP BY si.product_id
        ORDER BY revenue DESC LIMIT 20
      ''',
        [storeId, fromDate, toDate],
      );

      // Ventas por método de pago
      final byPaymentMethod = await db.rawQuery(
        '''
        SELECT pm.name, COUNT(DISTINCT sp.sale_id) AS count,
               SUM(sp.amount) AS total
        FROM sale_payments sp
        JOIN payment_methods pm ON pm.id = sp.method_id
        JOIN sales s ON s.id = sp.sale_id
        WHERE s.store_id = ? AND s.sale_date BETWEEN ? AND ?
        GROUP BY sp.method_id ORDER BY total DESC
      ''',
        [storeId, fromDate, toDate],
      );

      // Evolución diaria
      final dailyEvolution = await db.rawQuery(
        '''
        SELECT sale_date, COUNT(*) AS sales, SUM(total) AS revenue
        FROM sales
        WHERE store_id = ? AND sale_date BETWEEN ? AND ? AND status = 'completed'
        GROUP BY sale_date ORDER BY sale_date ASC
      ''',
        [storeId, fromDate, toDate],
      );

      return {
        'summary': salesSummary.first,
        'top_products': topProducts,
        'by_payment_method': byPaymentMethod,
        'daily_evolution': dailyEvolution,
        'generated_at': DateTime.now().toUtc().toIso8601String(),
      };
    } catch (e) {
      rethrow;
    }
  }
}
