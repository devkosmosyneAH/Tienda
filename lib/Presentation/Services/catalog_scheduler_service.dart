// ignore_for_file: avoid_print

import 'dart:async';

import 'catalog_sync_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Scheduler — sincronización automática cada 5 minutos
// ─────────────────────────────────────────────────────────────────────────────

/// Programa sincronizaciones periódicas del catálogo web.
///
/// Por defecto ejecuta [CatalogSyncService.instance.syncNow] cada 5 minutos.
/// El intervalo es configurable en [initialize].
///
/// Ciclo de vida:
/// ```dart
/// // Arrancar (ej. en providers.dart o main.dart, después de CatalogSyncService.initialize):
/// CatalogSchedulerService.initialize();
/// CatalogSchedulerService.instance.start();
///
/// // Detener limpiamente (en dispose del Provider o al cerrar la app):
/// CatalogSchedulerService.instance.stop();
/// ```
class CatalogSchedulerService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static CatalogSchedulerService? _instance;

  static CatalogSchedulerService get instance {
    assert(
      _instance != null,
      'Llama a CatalogSchedulerService.initialize() antes de usar.',
    );
    return _instance!;
  }

  static void initialize({
    Duration interval = const Duration(minutes: 5),
  }) {
    _instance ??= CatalogSchedulerService._(interval: interval);
  }

  // ── Campos ─────────────────────────────────────────────────────────────────
  final Duration interval;
  Timer? _timer;
  bool _running = false;

  CatalogSchedulerService._({required this.interval});

  // ── API pública ────────────────────────────────────────────────────────────

  bool get isRunning => _running;

  /// Inicia el temporizador periódico.
  /// Llama a [syncNow] inmediatamente al arrancar y luego cada [interval].
  void start() {
    if (_running) return;
    _running = true;

    print('[CatalogSchedulerService] ▶ Scheduler iniciado '
        '(cada ${interval.inMinutes} min).');

    // Primera sincronización inmediata al arrancar.
    _triggerSync();

    _timer = Timer.periodic(interval, (_) => _triggerSync());
  }

  /// Detiene el temporizador.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
    print('[CatalogSchedulerService] ⏹ Scheduler detenido.');
  }

  /// Reinicia el temporizador con el mismo intervalo.
  void restart() {
    stop();
    start();
  }

  // ── Privado ────────────────────────────────────────────────────────────────

  void _triggerSync() {
    print('[CatalogSchedulerService] 🔄 Disparando sincronización automática…');
    // Delegamos al orquestador para respetar la cola y el estado.
    CatalogSyncService.instance.syncNow().catchError((e) {
      print('[CatalogSchedulerService] ❌ Error en sync automático: $e');
    });
  }
}
