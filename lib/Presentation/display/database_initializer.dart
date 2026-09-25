// Selector condicional: usa la implementación nativa cuando esté disponible,
// y una implementación web (vacía) para evitar errores de compilación.
import 'database_initializer_native.dart'
    if (dart.library.html) 'database_initializer_web.dart' as impl;

/// Inicializa la plataforma de base de datos según el entorno.
Future<void> initializeDatabasePlatform() => impl.initializeDatabasePlatform();
