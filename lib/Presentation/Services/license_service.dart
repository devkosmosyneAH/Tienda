// ignore_for_file: constant_identifier_names

import 'dart:convert';

import 'package:cryptography/cryptography.dart';

enum LicenseStatus {
  DEMO_ACTIVA,
  DEMO_POR_VENCER,
  DEMO_VENCIDA,
  LICENCIA_ACTIVA,
  LICENCIA_EXPIRADA,
  LICENCIA_REVOCADA,
  LICENCIA_INVALIDA,
}

class LicenseRecord {
  const LicenseRecord({
    required this.installationId,
    required this.fingerprint,
    required this.demoStartedAt,
    required this.lastSeenAt,
    this.activationCode,
    this.requiresActivation = false,
  });

  final String installationId;
  final String fingerprint;
  final DateTime demoStartedAt;
  final DateTime lastSeenAt;
  final String? activationCode;
  final bool requiresActivation;

  LicenseRecord copyWith({
    DateTime? lastSeenAt,
    String? activationCode,
    bool? requiresActivation,
  }) => LicenseRecord(
    installationId: installationId,
    fingerprint: fingerprint,
    demoStartedAt: demoStartedAt,
    lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    activationCode: activationCode ?? this.activationCode,
    requiresActivation: requiresActivation ?? this.requiresActivation,
  );

  Map<String, Object?> toJson() => {
    'version': 1,
    'installationId': installationId,
    'fingerprint': fingerprint,
    'demoStartedAt': demoStartedAt.toUtc().toIso8601String(),
    'lastSeenAt': lastSeenAt.toUtc().toIso8601String(),
    'activationCode': activationCode,
    'requiresActivation': requiresActivation,
  };

  factory LicenseRecord.fromJson(Map<String, dynamic> json) {
    if (json['version'] != 1) {
      throw const FormatException('Versión de registro de licencia inválida.');
    }
    return LicenseRecord(
      installationId: json['installationId'] as String,
      fingerprint: json['fingerprint'] as String,
      demoStartedAt: DateTime.parse(json['demoStartedAt'] as String).toUtc(),
      lastSeenAt: DateTime.parse(json['lastSeenAt'] as String).toUtc(),
      activationCode: json['activationCode'] as String?,
      requiresActivation: json['requiresActivation'] as bool? ?? false,
    );
  }
}

class StoredLicenseState {
  const StoredLicenseState({
    required this.record,
    required this.foundData,
    this.corrupt = false,
  });

  final LicenseRecord? record;
  final bool foundData;
  final bool corrupt;
}

abstract interface class LicensePersistence {
  Future<StoredLicenseState> read(String fingerprint);
  Future<void> write(LicenseRecord record);
}

abstract interface class LicenseFingerprint {
  Future<String> current();
}

abstract interface class LicenseClock {
  DateTime nowUtc();
}

abstract interface class LicenseIdGenerator {
  String generate();
}

class LicenseSnapshot {
  const LicenseSnapshot({
    required this.status,
    required this.installationId,
    required this.fingerprint,
    required this.demoStartedAt,
    required this.expiresAt,
    required this.remaining,
    this.message,
  });

  final LicenseStatus status;
  final String installationId;
  final String fingerprint;
  final DateTime? demoStartedAt;
  final DateTime? expiresAt;
  final Duration remaining;
  final String? message;

  bool get isBlocked => switch (status) {
    LicenseStatus.DEMO_VENCIDA ||
    LicenseStatus.LICENCIA_EXPIRADA ||
    LicenseStatus.LICENCIA_REVOCADA ||
    LicenseStatus.LICENCIA_INVALIDA => true,
    _ => false,
  };
}

class ActivationResult {
  const ActivationResult({required this.activated, required this.message});

  final bool activated;
  final String message;
}

class LicenseCodeClaims {
  const LicenseCodeClaims({
    required this.installationId,
    required this.fingerprint,
    required this.issuedAt,
    required this.licenseId,
    required this.revoked,
    this.expiresAt,
  });

  final String installationId;
  final String fingerprint;
  final DateTime issuedAt;
  final DateTime? expiresAt;
  final String licenseId;
  final bool revoked;
}

class LicenseCodeVerification {
  const LicenseCodeVerification({this.claims, this.error});

  final LicenseCodeClaims? claims;
  final String? error;

  bool get isValid => claims != null;
}

class Ed25519LicenseCodeVerifier {
  Ed25519LicenseCodeVerifier({required this.publicKeyBase64});

  final String publicKeyBase64;

  Future<LicenseCodeVerification> verify(String code) async {
    if (publicKeyBase64.isEmpty) {
      return const LicenseCodeVerification(
        error: 'La clave pública de activación no está configurada.',
      );
    }

    try {
      final parts = code.trim().split('.');
      if (parts.length != 3 || parts[0] != 'DK1') {
        return const LicenseCodeVerification(
          error: 'Formato de código inválido.',
        );
      }

      final publicKeyBytes = _decodeBase64Url(publicKeyBase64);
      final signatureBytes = _decodeBase64Url(parts[2]);
      if (publicKeyBytes.length != 32 || signatureBytes.length != 64) {
        return const LicenseCodeVerification(
          error: 'Firma de licencia inválida.',
        );
      }

      final publicKey = SimplePublicKey(
        publicKeyBytes,
        type: KeyPairType.ed25519,
      );
      final signature = Signature(signatureBytes, publicKey: publicKey);
      final isSignatureValid = await Ed25519().verify(
        utf8.encode(parts[1]),
        signature: signature,
      );
      if (!isSignatureValid) {
        return const LicenseCodeVerification(
          error: 'Firma de licencia inválida.',
        );
      }

      final payload = jsonDecode(utf8.decode(_decodeBase64Url(parts[1])));
      if (payload is! Map<String, dynamic> || payload['version'] != 1) {
        return const LicenseCodeVerification(
          error: 'Versión de licencia no compatible.',
        );
      }

      final claims = LicenseCodeClaims(
        installationId: payload['installationId'] as String,
        fingerprint: payload['fingerprint'] as String,
        issuedAt: DateTime.parse(payload['issuedAt'] as String).toUtc(),
        expiresAt: payload['expiresAt'] == null
            ? null
            : DateTime.parse(payload['expiresAt'] as String).toUtc(),
        licenseId: payload['licenseId'] as String,
        revoked: payload['revoked'] as bool? ?? false,
      );
      return LicenseCodeVerification(claims: claims);
    } catch (_) {
      return const LicenseCodeVerification(
        error: 'Código de activación inválido.',
      );
    }
  }

  static List<int> _decodeBase64Url(String value) {
    final normalized = value.replaceAll('-', '+').replaceAll('_', '/');
    return base64.decode(base64.normalize(normalized));
  }
}

class LocalLicenseService {
  LocalLicenseService({
    required LicensePersistence persistence,
    required LicenseFingerprint fingerprint,
    required LicenseClock clock,
    required LicenseIdGenerator idGenerator,
    required Ed25519LicenseCodeVerifier verifier,
  }) : _persistence = persistence,
       _fingerprint = fingerprint,
       _clock = clock,
       _idGenerator = idGenerator,
       _verifier = verifier;

  static const demoDuration = Duration(hours: 168);
  static const expiryWarning = Duration(hours: 24);
  static const clockTolerance = Duration(minutes: 5);

  final LicensePersistence _persistence;
  final LicenseFingerprint _fingerprint;
  final LicenseClock _clock;
  final LicenseIdGenerator _idGenerator;
  final Ed25519LicenseCodeVerifier _verifier;

  LicenseSnapshot? _snapshot;
  LicenseRecord? _record;

  LicenseSnapshot? get snapshot => _snapshot;

  Future<LicenseSnapshot> initialize() async {
    final now = _clock.nowUtc().toUtc();
    final fingerprint = await _fingerprint.current();
    final stored = await _persistence.read(fingerprint);

    if (stored.corrupt || (stored.foundData && stored.record == null)) {
      final recoveryRecord = LicenseRecord(
        installationId: _idGenerator.generate(),
        fingerprint: fingerprint,
        demoStartedAt: now.subtract(demoDuration),
        lastSeenAt: now,
        requiresActivation: true,
      );
      await _persistence.write(recoveryRecord);
      _record = recoveryRecord;
      _snapshot = await _evaluate(recoveryRecord, now);
      return _snapshot!;
    }

    var record = stored.record;
    if (record == null) {
      record = LicenseRecord(
        installationId: _idGenerator.generate(),
        fingerprint: fingerprint,
        demoStartedAt: now,
        lastSeenAt: now,
      );
    } else if (record.fingerprint != fingerprint) {
      return _setInvalid(
        fingerprint,
        message: 'La licencia pertenece a otra instalación o equipo.',
      );
    } else if (now.add(clockTolerance).isBefore(record.lastSeenAt)) {
      return _setInvalid(
        fingerprint,
        message: 'Se detectó un retroceso inesperado del reloj del sistema.',
      );
    }

    final effectiveNow = now.isBefore(record.lastSeenAt)
        ? record.lastSeenAt
        : now;
    record = record.copyWith(lastSeenAt: effectiveNow);
    await _persistence.write(record);
    _record = record;
    _snapshot = await _evaluate(record, effectiveNow);
    return _snapshot!;
  }

  Future<LicenseSnapshot> refresh() async {
    if (_record == null) return initialize();
    return initialize();
  }

  Future<ActivationResult> activate(String code) async {
    if (_record == null) await initialize();
    final record = _record;
    if (record == null) {
      return const ActivationResult(
        activated: false,
        message: 'No se pudo leer el estado de esta instalación.',
      );
    }

    final verification = await _verifier.verify(code);
    final claims = verification.claims;
    if (claims == null) {
      return ActivationResult(
        activated: false,
        message: verification.error ?? 'Código de activación inválido.',
      );
    }
    if (claims.installationId != record.installationId ||
        claims.fingerprint != record.fingerprint) {
      return const ActivationResult(
        activated: false,
        message: 'El código fue emitido para otra instalación o equipo.',
      );
    }

    final currentTime = _clock.nowUtc().toUtc();
    final now = currentTime.isBefore(record.lastSeenAt)
        ? record.lastSeenAt
        : currentTime;
    if (claims.issuedAt.isAfter(now.add(clockTolerance))) {
      return const ActivationResult(
        activated: false,
        message: 'La fecha de emisión del código no es válida.',
      );
    }

    final updated = record.copyWith(
      lastSeenAt: now,
      activationCode: code.trim(),
      requiresActivation: false,
    );
    await _persistence.write(updated);
    _record = updated;
    _snapshot = await _evaluate(updated, now);
    if (_snapshot!.status != LicenseStatus.LICENCIA_ACTIVA) {
      return ActivationResult(
        activated: false,
        message: _snapshot!.message ?? 'La licencia no está activa.',
      );
    }
    return const ActivationResult(
      activated: true,
      message: 'Licencia activada correctamente.',
    );
  }

  Future<LicenseSnapshot> _evaluate(LicenseRecord record, DateTime now) async {
    if (record.requiresActivation) {
      return _snapshotFor(
        record,
        LicenseStatus.LICENCIA_INVALIDA,
        expiresAt: record.demoStartedAt.add(demoDuration),
        message:
            'El estado local no se pudo validar. Solicita un nuevo código para esta instalación.',
      );
    }
    if (record.activationCode != null) {
      final verification = await _verifier.verify(record.activationCode!);
      final claims = verification.claims;
      if (claims == null ||
          claims.installationId != record.installationId ||
          claims.fingerprint != record.fingerprint) {
        return _snapshotFor(
          record,
          LicenseStatus.LICENCIA_INVALIDA,
          message:
              verification.error ??
              'La licencia no corresponde a esta instalación.',
        );
      }
      if (claims.revoked) {
        return _snapshotFor(
          record,
          LicenseStatus.LICENCIA_REVOCADA,
          expiresAt: claims.expiresAt,
          message: 'Esta licencia fue revocada por su emisor.',
        );
      }
      if (claims.expiresAt != null && !now.isBefore(claims.expiresAt!)) {
        return _snapshotFor(
          record,
          LicenseStatus.LICENCIA_EXPIRADA,
          expiresAt: claims.expiresAt,
          message: 'La licencia ha expirado.',
        );
      }
      return _snapshotFor(
        record,
        LicenseStatus.LICENCIA_ACTIVA,
        expiresAt: claims.expiresAt,
      );
    }

    final expiresAt = record.demoStartedAt.add(demoDuration);
    final remaining = expiresAt.difference(now);
    if (!now.isBefore(expiresAt)) {
      return _snapshotFor(
        record,
        LicenseStatus.DEMO_VENCIDA,
        expiresAt: expiresAt,
        message: 'El período de prueba de 7 días ha finalizado.',
      );
    }
    return _snapshotFor(
      record,
      remaining <= expiryWarning
          ? LicenseStatus.DEMO_POR_VENCER
          : LicenseStatus.DEMO_ACTIVA,
      expiresAt: expiresAt,
      remaining: remaining,
    );
  }

  LicenseSnapshot _snapshotFor(
    LicenseRecord record,
    LicenseStatus status, {
    DateTime? expiresAt,
    Duration remaining = Duration.zero,
    String? message,
  }) => LicenseSnapshot(
    status: status,
    installationId: record.installationId,
    fingerprint: record.fingerprint,
    demoStartedAt: record.demoStartedAt,
    expiresAt: expiresAt,
    remaining: remaining,
    message: message,
  );

  LicenseSnapshot _setInvalid(String fingerprint, {required String message}) {
    _record = null;
    _snapshot = LicenseSnapshot(
      status: LicenseStatus.LICENCIA_INVALIDA,
      installationId: '',
      fingerprint: fingerprint,
      demoStartedAt: null,
      expiresAt: null,
      remaining: Duration.zero,
      message: message,
    );
    return _snapshot!;
  }
}
