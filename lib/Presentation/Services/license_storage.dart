import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:tienda/Presentation/Services/database_service.dart';
import 'package:tienda/Presentation/Services/license_service.dart';
import 'package:uuid/uuid.dart';

class LocalLicensePersistence implements LicensePersistence {
  LocalLicensePersistence({LicenseBlobStore? sqlite, LicenseBlobStore? file})
    : _sqlite = sqlite ?? SqliteLicenseBlobStore(),
      _file = file ?? FileLicenseBlobStore();

  final LicenseBlobStore _sqlite;
  final LicenseBlobStore _file;

  @override
  Future<StoredLicenseState> read(String fingerprint) async {
    final storedBlobs = await Future.wait([_sqlite.read(), _file.read()]);
    final foundData = storedBlobs.any((blob) => blob != null);
    if (!foundData) {
      return const StoredLicenseState(record: null, foundData: false);
    }

    final records = <LicenseRecord>[];
    for (final blob in storedBlobs.whereType<String>()) {
      try {
        records.add(_decode(blob, fingerprint));
      } catch (_) {
        // A valid copy can recover the other mirror on the next write.
      }
    }
    if (records.isEmpty) {
      return const StoredLicenseState(
        record: null,
        foundData: true,
        corrupt: true,
      );
    }

    final first = records.first;
    if (records.any(
      (record) =>
          record.installationId != first.installationId ||
          record.fingerprint != first.fingerprint ||
          record.demoStartedAt != first.demoStartedAt,
    )) {
      return const StoredLicenseState(
        record: null,
        foundData: true,
        corrupt: true,
      );
    }

    records.sort((a, b) {
      final timeComparison = a.lastSeenAt.compareTo(b.lastSeenAt);
      if (timeComparison != 0) return timeComparison;
      return (a.activationCode != null ? 1 : 0).compareTo(
        b.activationCode != null ? 1 : 0,
      );
    });
    return StoredLicenseState(record: records.last, foundData: true);
  }

  @override
  Future<void> write(LicenseRecord record) async {
    final blob = _encode(record);
    await Future.wait([_sqlite.write(blob), _file.write(blob)]);
  }

  String _encode(LicenseRecord record) {
    final payload = jsonEncode(record.toJson());
    final checksum = sha256
        .convert(utf8.encode('${record.fingerprint}|$payload'))
        .toString();
    final envelope = jsonEncode({'payload': payload, 'checksum': checksum});
    final key = sha256.convert(
      utf8.encode('${record.fingerprint}|Tienda|license-state-v1'),
    );
    final input = utf8.encode(envelope);
    final obfuscated = List<int>.generate(
      input.length,
      (index) => input[index] ^ key.bytes[index % key.bytes.length],
    );
    return base64Url.encode(obfuscated);
  }

  LicenseRecord _decode(String encoded, String fingerprint) {
    final obfuscated = base64Url.decode(base64Url.normalize(encoded));
    final key = sha256.convert(
      utf8.encode('$fingerprint|Tienda|license-state-v1'),
    );
    final bytes = List<int>.generate(
      obfuscated.length,
      (index) => obfuscated[index] ^ key.bytes[index % key.bytes.length],
    );
    final envelope = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    final payload = envelope['payload'] as String;
    final expected = sha256
        .convert(utf8.encode('$fingerprint|$payload'))
        .toString();
    if (envelope['checksum'] != expected) {
      throw const FormatException('Checksum de licencia no válido.');
    }
    final record = LicenseRecord.fromJson(
      jsonDecode(payload) as Map<String, dynamic>,
    );
    if (record.fingerprint != fingerprint) {
      throw const FormatException('Fingerprint local no coincide.');
    }
    return record;
  }
}

abstract interface class LicenseBlobStore {
  Future<String?> read();
  Future<void> write(String value);
}

class SqliteLicenseBlobStore implements LicenseBlobStore {
  @override
  Future<String?> read() async {
    final database = await DatabaseService.database;
    final rows = await database.query(
      'local_license_state',
      columns: ['payload'],
      where: 'id = 1',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['payload'] as String?;
  }

  @override
  Future<void> write(String value) async {
    final database = await DatabaseService.database;
    await database.rawInsert(
      '''INSERT OR REPLACE INTO local_license_state (id, payload, updated_at)
         VALUES (1, ?, ?)''',
      [value, DateTime.now().toUtc().toIso8601String()],
    );
  }
}

class FileLicenseBlobStore implements LicenseBlobStore {
  FileLicenseBlobStore({Directory? directory}) : _directory = directory;

  final Directory? _directory;

  Future<File> _file() async {
    final directory = _directory ?? await _resolveDirectory();
    return File(path.join(directory.path, 'license.dat'));
  }

  Future<Directory> _resolveDirectory() async {
    final executablePath = Platform.resolvedExecutable.toLowerCase();
    final installationScope = sha256
        .convert(utf8.encode(executablePath))
        .toString()
        .substring(0, 20);
    if (!kIsWeb && Platform.isWindows) {
      final programData =
          Platform.environment['PROGRAMDATA'] ??
          Platform.environment['ProgramData'];
      if (programData != null && programData.isNotEmpty) {
        return Directory(
          path.join(
            programData,
            'DevKosmosyne',
            'Tienda',
            installationScope,
            'license',
          ),
        );
      }
    }
    final supportDirectory = await getApplicationSupportDirectory();
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      return Directory(path.join(supportDirectory.path, 'license'));
    }
    return Directory(
      path.join(supportDirectory.path, 'license', installationScope),
    );
  }

  @override
  Future<String?> read() async {
    final file = await _file();
    if (!await file.exists()) return null;
    return file.readAsString();
  }

  @override
  Future<void> write(String value) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final temporaryFile = File('${file.path}.tmp');
    await temporaryFile.writeAsString(value, flush: true);
    if (await file.exists()) await file.delete();
    await temporaryFile.rename(file.path);
  }
}

class MachineLicenseFingerprint implements LicenseFingerprint {
  @override
  Future<String> current() async {
    final stableId = await _platformMachineId();
    final fallback = [
      Platform.operatingSystem,
      Platform.localHostname,
      Platform.environment['COMPUTERNAME'] ?? '',
      Platform.environment['PROCESSOR_IDENTIFIER'] ?? '',
    ].join('|');
    return sha256.convert(utf8.encode(stableId ?? fallback)).toString();
  }

  Future<String?> _platformMachineId() async {
    try {
      if (Platform.isWindows) {
        final result = await Process.run('reg', [
          'query',
          r'HKLM\SOFTWARE\Microsoft\Cryptography',
          '/v',
          'MachineGuid',
        ], runInShell: false);
        final match = RegExp(
          r'MachineGuid\s+REG_SZ\s+(\S+)',
        ).firstMatch(result.stdout.toString());
        return match?.group(1);
      }
      if (Platform.isMacOS) {
        final result = await Process.run('/usr/sbin/ioreg', [
          '-rd1',
          '-c',
          'IOPlatformExpertDevice',
        ], runInShell: false);
        final match = RegExp(
          r'"IOPlatformUUID"\s*=\s*"([^"]+)"',
        ).firstMatch(result.stdout.toString());
        return match?.group(1);
      }
      if (Platform.isLinux) {
        for (final machineIdPath in [
          '/etc/machine-id',
          '/var/lib/dbus/machine-id',
        ]) {
          final file = File(machineIdPath);
          if (await file.exists()) {
            final value = (await file.readAsString()).trim();
            if (value.isNotEmpty) return value;
          }
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }
}

class UuidLicenseIdGenerator implements LicenseIdGenerator {
  const UuidLicenseIdGenerator();

  @override
  String generate() => const Uuid().v4();
}

class SystemLicenseClock implements LicenseClock {
  const SystemLicenseClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}
