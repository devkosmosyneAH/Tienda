// ignore_for_file: avoid_print

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../Services/catalog_sync_service.dart';
import '../Services/catalog_scheduler_service.dart';

/// Provider MVC para el sistema de sincronización del catálogo web.
///
/// Conecta [CatalogSyncService] (orquestador) y [CatalogSchedulerService]
/// (timer 5 min) con la UI mediante ChangeNotifier.
///
/// Registrar en AppProviders:
/// ```dart
/// ChangeNotifierProvider<CatalogSyncProvider>(
///   create: (_) => CatalogSyncProvider()..initialize(),
/// ),
/// ```
///
/// Desde la UI:
/// ```dart
/// // Ver estado
/// context.watch<CatalogSyncProvider>().state
///
/// // Sync manual
/// context.read<CatalogSyncProvider>().syncNow();
///
/// // Notificar cambio en catálogo (desde ProductManagementController, etc.)
/// context.read<CatalogSyncProvider>().notifyCatalogChanged();
/// ```
class CatalogSyncProvider extends ChangeNotifier {
  SyncState _state = const SyncState(status: SyncStatus.idle);
  StreamSubscription<SyncState>? _subscription;

  // ── Estado observable ──────────────────────────────────────────────────────

  SyncState get state => _state;

  bool get isRunning => _state.isRunning;

  String get statusLabel {
    switch (_state.status) {
      case SyncStatus.idle:
        return 'En espera';
      case SyncStatus.exporting:
        return 'Exportando datos…';
      case SyncStatus.pushing:
        return 'Publicando en GitHub…';
      case SyncStatus.success:
        return '✅ Publicado correctamente';
      case SyncStatus.error:
        return '❌ Error de sincronización';
      case SyncStatus.hashing:
        return 'Calculando cambios…';
      case SyncStatus.skipped:
        return '✔ Sin cambios — catálogo actualizado';
    }
  }

  String get lastSyncLabel {
    if (_state.lastSync == null) return 'Nunca sincronizado';
    final dt = _state.lastSync!.toLocal();
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return 'Última sync: ${dt.day}/${dt.month}/${dt.year} $h:$m';
  }

  List<SyncLogEntry> get log => CatalogSyncService.instance.log;

  // ── Ciclo de vida ──────────────────────────────────────────────────────────

  /// Suscribe el Provider al stream del servicio y arranca el scheduler.
  void initialize() {
    _subscription = CatalogSyncService.instance.stateStream.listen((newState) {
      _state = newState;
      notifyListeners();
    });

    // Arrancar sincronización periódica cada 5 minutos.
    if (!CatalogSchedulerService.instance.isRunning) {
      CatalogSchedulerService.instance.start();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    CatalogSchedulerService.instance.stop();
    CatalogSyncService.instance.dispose();
    super.dispose();
  }

  // ── Acciones ───────────────────────────────────────────────────────────────

  /// Sincronización manual (botón en UI).
  Future<void> syncNow() => CatalogSyncService.instance.syncNow();

  /// Notificar cambio en productos o categorías (crea/edita/elimina).
  /// Activa el debounce de 30 s antes de publicar.
  void notifyCatalogChanged() =>
      CatalogSyncService.instance.notifyCatalogChanged();
}
