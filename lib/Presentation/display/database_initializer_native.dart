import 'dart:io';
import 'package:tienda/Presentation/Services/database_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../Services/database_config.dart';
import '../Services/database_location_service.dart';

/// Inicialización de base de datos para entornos nativos (desktop, mobile).
Future<void> initializeDatabasePlatform() async {
  if (kIsWeb) return;

  await DatabaseService.initializePlatform();

  try {
    await DatabaseService.database;
  } catch (_) {
    await _safeFallbackDatabaseInit();
  }
}

Future<void> _safeFallbackDatabaseInit() async {
  try {
    final dbPath = await DatabaseLocationService.getDatabasePath();
    final File dbFile = File(dbPath);
    if (await dbFile.exists()) {
      try {
        debugPrint('Opening database:');
        debugPrint(dbPath);
        await DatabaseService.database;
        return;
      } catch (_) {
        await dbFile.delete();
      }
    }

    final ByteData data = await rootBundle.load(DatabaseConfig.assetDbPath);
    final List<int> bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );

    await dbFile.writeAsBytes(bytes, flush: true);
    debugPrint('Opening database:');
    debugPrint(dbPath);
    await DatabaseService.database;
  } catch (_) {
    // No propagamos: la app seguirá funcionando pero sin DB precargada
  }
}

// Usamos el `DatabaseService` existente para forzar acceso/validación cuando sea necesario.
