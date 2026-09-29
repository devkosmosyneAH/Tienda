import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:tienda/Presentation/Services/license_service.dart';

class LicenseProvider extends ChangeNotifier {
  LicenseProvider({required LocalLicenseService service}) : _service = service;

  final LocalLicenseService _service;
  LicenseSnapshot? _snapshot;
  bool _loading = true;
  bool _activating = false;
  final Set<Object> _demoAppBarOwners = {};
  bool _disposed = false;
  Timer? _refreshTimer;
  Timer? _expirationTimer;

  LicenseSnapshot? get snapshot => _snapshot;
  bool get loading => _loading;
  bool get activating => _activating;
  bool get demoShownInAppBar => _demoAppBarOwners.isNotEmpty;
  LicenseStatus get status =>
      _snapshot?.status ?? LicenseStatus.LICENCIA_INVALIDA;

  int get remainingDays {
    final milliseconds = _snapshot?.remaining.inMilliseconds ?? 0;
    if (milliseconds <= 0) return 0;
    return (milliseconds + Duration.millisecondsPerDay - 1) ~/
        Duration.millisecondsPerDay;
  }

  void setDemoShownInAppBar(bool value, {required Object owner}) {
    if (_disposed) return;
    final wasShownInAppBar = demoShownInAppBar;
    if (value) {
      _demoAppBarOwners.add(owner);
    } else {
      _demoAppBarOwners.remove(owner);
    }
    if (wasShownInAppBar == demoShownInAppBar) return;
    notifyListeners();
  }

  Future<void> initialize() async {
    try {
      _snapshot = await _service.initialize();
      _refreshTimer ??= Timer.periodic(
        const Duration(minutes: 1),
        (_) => refresh(),
      );
      _scheduleExpirationRefresh();
    } catch (_) {
      _snapshot = LicenseSnapshot(
        status: LicenseStatus.LICENCIA_INVALIDA,
        installationId: '',
        fingerprint: '',
        demoStartedAt: null,
        expiresAt: null,
        remaining: Duration.zero,
        message: 'No se pudo validar el estado local de la licencia.',
      );
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    try {
      _snapshot = await _service.refresh();
    } catch (_) {
      _snapshot = LicenseSnapshot(
        status: LicenseStatus.LICENCIA_INVALIDA,
        installationId: _snapshot?.installationId ?? '',
        fingerprint: _snapshot?.fingerprint ?? '',
        demoStartedAt: _snapshot?.demoStartedAt,
        expiresAt: _snapshot?.expiresAt,
        remaining: Duration.zero,
        message: 'No se pudo validar el estado local de la licencia.',
      );
    }
    _scheduleExpirationRefresh();
    notifyListeners();
  }

  Future<ActivationResult> activate(String code) async {
    _activating = true;
    notifyListeners();
    try {
      final result = await _service.activate(code);
      _snapshot = _service.snapshot ?? _snapshot;
      _scheduleExpirationRefresh();
      return result;
    } catch (_) {
      return const ActivationResult(
        activated: false,
        message: 'No se pudo guardar la activación en este equipo.',
      );
    } finally {
      _activating = false;
      notifyListeners();
    }
  }

  void _scheduleExpirationRefresh() {
    _expirationTimer?.cancel();
    final snapshot = _snapshot;
    final expiresAt = snapshot?.expiresAt;
    if (expiresAt == null || snapshot!.isBlocked) return;
    final delay = expiresAt.difference(DateTime.now().toUtc());
    _expirationTimer = Timer(delay.isNegative ? Duration.zero : delay, refresh);
  }

  @override
  void dispose() {
    _disposed = true;
    _refreshTimer?.cancel();
    _expirationTimer?.cancel();
    super.dispose();
  }
}
