import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'backup_service.dart';
import 'database_config.dart';
import 'database_location_service.dart';

/// Genera un ID de 20 caracteres aleatorios estilo Firebase (letras y numeros).
String generateFirebaseId() {
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
  final rng = Random.secure();
  return List.generate(20, (_) => chars[rng.nextInt(chars.length)]).join();
}

/// Servicio principal para manejar la conexion con SQLite.
/// Mantiene un unico sistema con multiples locales compartiendo la misma base.
class ProductQueryFilters {
  const ProductQueryFilters({required this.whereClause, required this.params});

  final String whereClause;
  final List<Object?> params;
}

class DatabaseService {
  static Database? _database;
  static Completer<Database>? _dbCompleter;
  static bool _platformInitialized = false;
  static final ValueNotifier<int> databaseChanged = ValueNotifier<int>(0);

  static const List<String> _storeNames = ['Bazar', 'Tienda'];

  // =========================================================
  // CATÁLOGO ORGANIZADO — BazarNicole ERP/POS v2
  // Estructura: Store → Categoria → Productos
  //
  // Iconos sugeridos por categoria (Flutter Icons):
  //   Jugueteria            → Icons.toys
  //   Moda y Accesorios     → Icons.checkroom
  //   Belleza               → Icons.face_retouching_natural
  //   Hogar y Decoracion    → Icons.home
  //   Fiestas y Regalos     → Icons.celebration
  //   Tecnologia            → Icons.headphones
  //   Temporada             → Icons.ac_unit
  //   Papeleria y Oficina   → Icons.edit_note
  //   Manualidades y Arte   → Icons.palette
  //   Belleza y Cosmeticos  → Icons.spa
  //   Higiene Personal      → Icons.soap
  //   Limpieza y Hogar      → Icons.cleaning_services
  //   Bebes                 → Icons.child_care
  //   Zapateria             → Icons.shopping_bag
  //   Ferreteria            → Icons.hardware
  //   Alimentos y Abarrotes → Icons.shopping_cart
  //   Desechables y Eventos → Icons.dinner_dining
  //
  // Colores sugeridos (Material Design 3):
  //   Bazar   → Color(0xFF6C3EB8)  // Violeta profundo
  //   Tienda  → Color(0xFF1976D2)  // Azul corporativo
  //
  // Subcategorias futuras sugeridas:
  //   Bazar   → Decoracion de interiores, Ropa deportiva, Electronica menor
  //   Tienda  → Farmacia básica, Snacks importados, Articulos escolares premium
  //
  // Big Data / Reportes:
  //   - Usar categoria + tienda como dimensiones en dashboards
  //   - KPIs por categoria: margen, rotacion, stock minimo, ventas mensuales
  //   - Recomendaciones futuras con IA: productos de alta demanda por categoria
  // =========================================================

  /// Catálogo maestro estructurado en tres niveles:
  /// [Store] → [Categoria] → [Productos]
  ///
  /// Optimizado para:
  ///   • GridView / ExpansionTile / NavigationRail / Sidebar
  ///   • Filtrado rápido por categoria y tienda
  ///   • Reportes y análisis Big Data
  ///   • Escalabilidad y mantenimiento profesional
  static const Map<String, Map<String, List<String>>> _catalogByStore = {
    // =========================================================
    // BAZAR
    // =========================================================
    'Bazar': {
      // Icono: Icons.toys | Color: 0xFFE91E63
      'Jugueteria': [
        'Peluches',
        'Juguetes',
        'Pelotas de futbol',
        'Pelotas de indor',
      ],

      // Icono: Icons.checkroom | Color: 0xFF9C27B0
      'Moda y Accesorios': [
        'Carteras',
        'Zapatos deportivos',
        'Zapatillas',
        'Mochilas',
        'Loncheras',
        'Lazos',
        'Vinchas',
        'Joyeria',
        'Billeteras',
      ],

      // Icono: Icons.face_retouching_natural | Color: 0xFFE91E63
      'Belleza y Perfumeria': ['Perfumes', 'Esmaltes', 'Labiales'],

      // Icono: Icons.home | Color: 0xFF795548
      'Hogar y Decoracion': [
        'Portarretratos',
        'Accesorios de cocina',
        'Lámparas de dormitorio',
        'Plateros y accesorios para platos',
        'Velas aromáticas',
        'Espejos',
      ],

      // Icono: Icons.celebration | Color: 0xFFFF9800
      'Fiestas y Regalos': [
        'Fundas de regalo',
        'Accesorios para fiestas y cumpleaños',
        'Cajas para obsequios',
      ],

      // Icono: Icons.headphones | Color: 0xFF00BCD4
      'Tecnologia y Electronicos': ['Audifonos', 'Auriculares Bluetooth'],

      // Icono: Icons.ac_unit | Color: 0xFF2196F3
      'Temporada y Navidad': ['Accesorios navideños'],
    },

    // =========================================================
    // TIENDA
    // =========================================================
    'Tienda': {
      // Icono: Icons.edit_note | Color: 0xFF1565C0
      'Papeleria y Oficina': [
        'Cuadernos',
        'Hojas A4',
        'Hojas papel bond',
        'Agendas',
        'Diccionario',
        'Lápiz',
        'Esferos',
        'Lapicero borrable',
        'Marcador doble punta',
        'Marcador permanente',
        'Marcador borrable',
        'Resaltadores',
        'Corrector',
        'Borrador',
        'Sacapuntas',
        'Reglas',
        'Tijera',
        'Calculadora',
        'Perforadora',
        'Tape dispenser',
        'Grapadora',
        'Carpetas',
        'Fundas plásticas',
        'Cinta transparente',
        'Cinta de empaque',
      ],

      // Icono: Icons.palette | Color: 0xFF7B1FA2
      'Manualidades y Arte': [
        'Papel crepe',
        'Fomix',
        'Carton prensado',
        'Espuma flex',
        'Pinturas',
        'Pintura acrilica Artesco',
        'Acuarelas',
        'Lápices de colores',
        'Paletas de colores',
        'Lana',
        'Hilo raton',
        'Cintas decorativas',
        'Adornos tipo lentejuelas',
        'Adornos en fomix recortados',
        'Silicona',
        'Slime',
        'Goma',
      ],

      // Icono: Icons.spa | Color: 0xFFAD1457
      'Belleza y Cosmeticos': [
        'Uñas postizas',
        'Pegamento de uñas',
        'Pegamento de cejas',
        'Pestañas postizas',
        'Brochas para maquillaje',
        'Ampollas para el pelo',
        'Tinte de cabello',
        'Crema oxigenada',
        'Gel para cabello',
        'Cremas de peinar',
        'Silicon en spray para cabello',
        'Fijacion e hidratacion para pelo',
        'Rizador',
        'Limas',
        'Corta uñas',
        'Pinza para cejas',
        'Moños',
        'Invisibles',
      ],

      // Icono: Icons.soap | Color: 0xFF00838F
      'Higiene y Cuidado Personal': [
        'Prestobarba',
        'Gillette',
        'Maquinilla desechable',
        'Peinillas',
        'Cepillo de dientes',
        'Pasta dental niño',
        'Pasta dental adulto',
        'Desodorante en aerosol',
        'Desodorante en barra',
        'Desodorante en crema',
        'Talco de pies',
        'Limpiador facial',
        'Listerine',
        'Protector solar',
        'Crema hidratante corporal',
        'Jaboncillo',
        'Jabon de baño',
        'Pañitos humedos',
        'Shampoo',
        'Repelente',
        'Aceite Johnson',
        'Tiras de sosten',
      ],

      // Icono: Icons.cleaning_services | Color: 0xFF2E7D32
      'Limpieza y Hogar': [
        'Desinfectante ambiental',
        'Ambientador tips',
        'Aceite limpiador de madera',
        'Lavavajilla',
        'Detergente',
        'Cloro',
        'Guantes de limpieza',
        'Papel aluminio',
        'Papel higienico',
        'Toallas higienicas',
        'Esponjas',
        'Suavizante para ropa',
        'Insecticidas',
        'Focos',
      ],

      // Icono: Icons.child_care | Color: 0xFFF06292
      'Bebes y Maternidad': ['Teta para recien nacido', 'Pañales'],

      // Icono: Icons.shopping_bag | Color: 0xFF5D4037
      'Zapateria y Calzado': [
        'Cherry saca brillo para zapatos',
        'Banderola saca brillo para zapatos',
        'Esponja saca brillo para zapatos',
      ],

      // Icono: Icons.hardware | Color: 0xFF616161
      'Ferreteria y Utilitarios': [
        'Pilas',
        'Estilete',
        'Fosforeras',
        'Fosforos',
        'Velas',
        'Cirio vela',
        'Difusor de esencia',
        'Esencias para carro',
        'Descorchador de vinos',
        'Llaveros',
        'Alcancias',
        'Casino',
      ],

      // Icono: Icons.shopping_cart | Color: 0xFF388E3C
      'Alimentos y Abarrotes': [
        'Leche',
        'Leche condensada',
        'Leches saborizadas',
        'Cafe',
        'Cafe en polvo',
        'Azucar',
        'Sal',
        'Harina',
        'Avena',
        'Aceite',
        'Manteca',
        'Mantequilla',
        'Panela',
        'Tallarines',
        'Fideos',
        'Aliños',
        'Condimentos',
        'Esencias de cocina',
        'Salsas',
        'Cocos',
        'Enlatados',
        'Enlatados de verduras',
        'Sardina',
        'Atun real',
        'Productos lácteos',
        'Jugos y nectares',
        'Frutas',
        'Frutos secos',
        'Bombones',
        'Gelatina',
        'Horchata en sobre',
        'Tes en sobre',
        'Frescosolo',
        'Polvo de hornear',
        'Mezcla chantilly en polvo',
        'Galletas Amor',
      ],

      // Icono: Icons.dinner_dining | Color: 0xFFEF6C00
      'Desechables y Eventos': [
        'Platos desechables',
        'Servilletas',
        'Velas de cumpleaños',
      ],
    },
  };

  static Future<void> initializePlatform() async {
    if (_platformInitialized || kIsWeb) return;
    if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) {
      _platformInitialized = true;
      return;
    }

    try {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      _platformInitialized = true;
    } catch (_) {
      _platformInitialized = true;
    }
  }

  static void addDatabaseListener(VoidCallback listener) {
    databaseChanged.addListener(listener);
  }

  static void removeDatabaseListener(VoidCallback listener) {
    databaseChanged.removeListener(listener);
  }

  static void notifyDatabaseChanged() {
    databaseChanged.value += 1;
  }

  static Future<Database> get database async {
    await initializePlatform();

    if (_database != null && _database!.isOpen) return _database!;
    if (_database != null) {
      _database = null;
    }

    if (_dbCompleter != null) {
      try {
        return await _dbCompleter!.future;
      } catch (_) {
        _dbCompleter = null;
      }
    }

    _dbCompleter = Completer<Database>();
    try {
      _database = await _initDatabase();
      _dbCompleter!.complete(_database!);
    } catch (e) {
      if (_dbCompleter != null && !_dbCompleter!.isCompleted) {
        _dbCompleter!.completeError(e);
      }
      _dbCompleter = null;
      rethrow;
    }
    return _database!;
  }

  static Future<Database> _initDatabase() async {
    String path = await DatabaseLocationService.getDatabasePath();

    try {
      await DatabaseLocationService.ensureDatabaseDirectoryExists(path);
    } catch (_) {
      path = await DatabaseLocationService.getFallbackPath();
      await DatabaseLocationService.ensureDatabaseDirectoryExists(path);
    }

    if (!await DatabaseLocationService.databaseExists(path)) {
      try {
        final data = await rootBundle.load(DatabaseConfig.assetDbPath);
        final bytes = data.buffer.asUint8List(
          data.offsetInBytes,
          data.lengthInBytes,
        );
        await File(path).writeAsBytes(bytes, flush: true);
      } catch (e) {
        throw Exception('No se pudo copiar la base de datos desde assets: $e');
      }
    }

    debugPrint('Opening database:');
    debugPrint(path);

    final db = await databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 3,
        onCreate: (db, version) async => _ensureBusinessSchema(db),
        onUpgrade: (db, oldVersion, newVersion) async =>
            _ensureBusinessSchema(db),
        onOpen: (db) async {
          // PRAGMAs que DEVUELVEN un resultado
          await db.rawQuery('PRAGMA journal_mode=WAL');
          // ── PRAGMAs de rendimiento enterprise (ejecutar en cada apertura) ──

          await db.rawQuery('PRAGMA synchronous=NORMAL');
          await db.rawQuery('PRAGMA cache_size=-65536');
          await db.rawQuery('PRAGMA temp_store=MEMORY');
          await db.rawQuery('PRAGMA mmap_size=536870912');
          await db.rawQuery('PRAGMA busy_timeout=10000');
          await db.rawQuery('PRAGMA wal_autocheckpoint=1000');
          await db.execute('PRAGMA foreign_keys = ON');
          await _ensureBusinessSchema(db);
        },
      ),
    );

    _performAutomaticBackupIfNeeded();
    return db;
  }

  static Future<Database> openReadOnlyDatabase(String path) async {
    await initializePlatform();
    return databaseFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        readOnly: true,
        onOpen: (db) async {
          await db.execute('PRAGMA journal_mode = WAL');
          await db.execute('PRAGMA cache_size = -32768');
          await db.execute('PRAGMA temp_store = MEMORY');
        },
      ),
    );
  }

  /// Expone la ruta de la BD para uso en Isolates (AnalyticsService).
  static Future<String> getDatabasePath() async {
    return DatabaseLocationService.getDatabasePath();
  }

  static Future<void> restoreFromAssets() async {
    final path = await DatabaseLocationService.getDatabasePath();
    await DatabaseLocationService.ensureDatabaseDirectoryExists(path);

    final data = await rootBundle.load(DatabaseConfig.assetDbPath);
    final bytes = data.buffer.asUint8List(
      data.offsetInBytes,
      data.lengthInBytes,
    );

    await File(path).writeAsBytes(bytes, flush: true);
    await reopen();
  }

  static Future<void> close() async {
    final db = _database;
    _database = null;

    final completer = _dbCompleter;
    _dbCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(Exception('Database closed'));
    }

    if (db != null && db.isOpen) {
      try {
        await db.close();
      } catch (_) {}
    }
  }

  static Future<void> reopen() async {
    await close();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await database;
    notifyDatabaseChanged();
  }

  static Future<void> replaceDatabase(File file) async {
    if (!await file.exists()) {
      throw Exception('El archivo seleccionado no existe: ${file.path}');
    }

    final path = await DatabaseLocationService.getDatabasePath();
    await DatabaseLocationService.ensureDatabaseDirectoryExists(path);

    await close();
    await Future<void>.delayed(const Duration(milliseconds: 250));

    final backupPath = '$path.backup.${DateTime.now().millisecondsSinceEpoch}';
    if (await File(path).exists()) {
      await File(path).copy(backupPath);
      await File(path).delete();
    }

    if (file.path == path) {
      await file.copy(path);
    } else {
      await file.copy(path);
    }

    await Future<void>.delayed(const Duration(milliseconds: 250));
    await reopen();
  }

  static Future<void> _ensureBusinessSchema(DatabaseExecutor db) async {
    await db.execute('PRAGMA foreign_keys = ON');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS stores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        slug TEXT NOT NULL,
        store_id INTEGER
      )
    ''');

    await _ensureColumn(
      db,
      table: 'categories',
      column: 'slug',
      definition: 'TEXT NOT NULL DEFAULT ""',
    );
    await _ensureColumn(
      db,
      table: 'categories',
      column: 'image_url',
      definition: 'TEXT NOT NULL DEFAULT ""',
    );

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_categories_slug ON categories(slug)',
    );

    final existingCategories = await db.rawQuery(
      'SELECT id, name FROM categories',
    );
    for (final row in existingCategories) {
      final id = (row['id'] as num).toInt();
      final name = row['name'] as String? ?? '';
      final slug = _buildCategorySlug(name);
      await db.rawUpdate('UPDATE categories SET slug = ? WHERE id = ?', [
        slug,
        id,
      ]);
    }

    await db.execute('''
      CREATE TABLE IF NOT EXISTS products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uid TEXT,
        name TEXT NOT NULL,
        sku TEXT NOT NULL UNIQUE,
        aux_code TEXT,
        description TEXT,
        tags TEXT,
        category_id INTEGER,
        store_id INTEGER,
        price REAL NOT NULL DEFAULT 0,
        cost_price REAL NOT NULL DEFAULT 0,
        iva_rate REAL NOT NULL DEFAULT 0,
        profit_iva REAL NOT NULL DEFAULT 0,
        images TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories(id),
        FOREIGN KEY (store_id) REFERENCES stores(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        store_id INTEGER NOT NULL,
        stock INTEGER NOT NULL DEFAULT 0,
        UNIQUE(product_id, store_id),
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
        FOREIGN KEY (store_id) REFERENCES stores(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS clients (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        notes TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // ── Migracion: datos adicionales del cliente ──
    for (final colDef in [
      'cedula TEXT',
      'identification_type TEXT DEFAULT "cedula"',
      'address TEXT',
      'apellidos TEXT',
      'referencias TEXT',
      'uid TEXT',
    ]) {
      try {
        await db.execute('ALTER TABLE clients ADD COLUMN $colDef');
      } catch (_) {} // columna ya existe
    }

    await db.execute('''
      CREATE TABLE IF NOT EXISTS suppliers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        phone TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        store_id INTEGER NOT NULL,
        supplier_id INTEGER,
        total REAL NOT NULL DEFAULT 0,
        date TEXT NOT NULL,
        FOREIGN KEY (store_id) REFERENCES stores(id),
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        cost REAL NOT NULL,
        FOREIGN KEY (purchase_id) REFERENCES purchases(id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        store_id INTEGER NOT NULL,
        client_id INTEGER,
        date TEXT NOT NULL,
        total REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (store_id) REFERENCES stores(id),
        FOREIGN KEY (client_id) REFERENCES clients(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sale_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        price REAL NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS inventory_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id INTEGER NOT NULL,
        from_store_id INTEGER NOT NULL,
        to_store_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        date TEXT NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products(id),
        FOREIGN KEY (from_store_id) REFERENCES stores(id),
        FOREIGN KEY (to_store_id) REFERENCES stores(id)
      )
    ''');

    // --- Modulo de Caja ---

    await db.execute('''
      CREATE TABLE IF NOT EXISTS payment_methods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        is_cash INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cash_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        store_id INTEGER NOT NULL,
        opening_amount REAL NOT NULL DEFAULT 0,
        closing_amount REAL,
        opened_at TEXT NOT NULL,
        closed_at TEXT,
        status TEXT NOT NULL DEFAULT 'open',
        FOREIGN KEY (store_id) REFERENCES stores(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS cash_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        method TEXT NOT NULL DEFAULT 'Efectivo',
        description TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (session_id) REFERENCES cash_sessions(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sale_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        method_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE CASCADE,
        FOREIGN KEY (method_id) REFERENCES payment_methods(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS credit_sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL UNIQUE,
        total REAL NOT NULL,
        paid REAL NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'pending',
        FOREIGN KEY (sale_id) REFERENCES sales(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS credit_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        credit_sale_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        method_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        FOREIGN KEY (credit_sale_id) REFERENCES credit_sales(id),
        FOREIGN KEY (method_id) REFERENCES payment_methods(id)
      )
    ''');

    // --- Modulo de Caja legacy (cajas / egresos_caja / ingresos_caja) ---
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cajas (
        id                    INTEGER PRIMARY KEY AUTOINCREMENT,
        codigo                TEXT    NOT NULL UNIQUE,
        estado                TEXT    NOT NULL DEFAULT 'c',
        existente             REAL    NOT NULL DEFAULT 0,
        fecha_ap              TEXT    NOT NULL,
        fecha_ci              TEXT,
        id_usuario            TEXT    NOT NULL DEFAULT '',
        ingresos              REAL    NOT NULL DEFAULT 0,
        monto_ap              REAL    NOT NULL DEFAULT 0,
        pagos                 REAL    NOT NULL DEFAULT 0,
        billetes_inicio       TEXT,
        monedas_inicio        TEXT,
        billetes_fin          TEXT,
        monedas_fin           TEXT,
        monto_total_cierre    REAL    NOT NULL DEFAULT 0,
        monto_billetes_inicio TEXT,
        monto_monedas_inicio  TEXT,
        monto_billetes_fin    TEXT,
        monto_monedas_fin     TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS egresos_caja (
        id       INTEGER PRIMARY KEY AUTOINCREMENT,
        _key     TEXT,
        codigo   TEXT    NOT NULL,
        concepto TEXT    NOT NULL DEFAULT '',
        fecha    TEXT    NOT NULL,
        id_caja  TEXT    NOT NULL,
        monto    REAL    NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ingresos_caja (
        id       INTEGER PRIMARY KEY AUTOINCREMENT,
        _key     TEXT,
        codigo   TEXT    NOT NULL,
        concepto TEXT    NOT NULL DEFAULT '',
        fecha    TEXT    NOT NULL,
        id_caja  TEXT    NOT NULL,
        monto    REAL    NOT NULL DEFAULT 0
      )
    ''');

    // --- Modulo de Usuarios y Roles ---
    // Si la tabla users existe pero es la del dump de Firebase (tiene columna _key),
    // la renombramos a firebase_users para no entrar en conflicto.
    try {
      final cols = await db.rawQuery("PRAGMA table_info(users)");
      if (cols.isNotEmpty) {
        final hasKey = cols.any((c) => c['name'] == '_key');
        if (hasKey) {
          await db.execute('ALTER TABLE users RENAME TO firebase_users');
        }
      }
    } catch (_) {}

    await db.execute('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        uid TEXT NOT NULL UNIQUE,
        email TEXT NOT NULL UNIQUE,
        password TEXT NOT NULL,
        name TEXT NOT NULL,
        lastname TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'cajero',
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT,
        user_name TEXT,
        user_email TEXT,
        user_role TEXT,
        action TEXT NOT NULL,
        module TEXT,
        page TEXT,
        entity TEXT,
        entity_id TEXT,
        description TEXT,
        old_data TEXT,
        new_data TEXT,
        metadata TEXT,
        controller TEXT,
        service TEXT,
        platform TEXT,
        created_at TEXT NOT NULL,
        success INTEGER NOT NULL DEFAULT 1,
        error_message TEXT,
        ip_address TEXT,
        device_info TEXT
      )
    ''');
    for (final index in [
      'CREATE INDEX IF NOT EXISTS idx_audit_created_at ON audit_logs(created_at)',
      'CREATE INDEX IF NOT EXISTS idx_audit_user_id ON audit_logs(user_id)',
      'CREATE INDEX IF NOT EXISTS idx_audit_action ON audit_logs(action)',
      'CREATE INDEX IF NOT EXISTS idx_audit_module ON audit_logs(module)',
      'CREATE INDEX IF NOT EXISTS idx_audit_entity ON audit_logs(entity)',
      'CREATE INDEX IF NOT EXISTS idx_audit_entity_id ON audit_logs(entity_id)',
    ]) {
      await db.execute(index);
    }

    await _seedAdminUser(db);
    await _seedPaymentMethods(db);

    await _ensureColumn(
      db,
      table: 'products',
      column: 'price',
      definition: 'REAL NOT NULL DEFAULT 0',
    );
    await _ensureColumn(
      db,
      table: 'products',
      column: 'uid',
      definition: 'TEXT',
    );
    await _ensureColumn(
      db,
      table: 'purchases',
      column: 'invoice_number',
      definition: 'TEXT',
    );
    await _ensureColumn(
      db,
      table: 'purchases',
      column: 'auxiliary_invoice_number',
      definition: 'TEXT',
    );
    await _ensureColumn(
      db,
      table: 'purchases',
      column: 'payment_method',
      definition: "TEXT NOT NULL DEFAULT 'Contado'",
    );
    await _ensureColumn(
      db,
      table: 'products',
      column: 'aux_code',
      definition: 'TEXT',
    );
    await _ensureColumn(
      db,
      table: 'products',
      column: 'store_id',
      definition: 'INTEGER',
    );
    await _ensureColumn(
      db,
      table: 'products',
      column: 'cost_price',
      definition: 'REAL NOT NULL DEFAULT 0',
    );
    await _ensureColumn(
      db,
      table: 'products',
      column: 'iva_rate',
      definition: 'REAL NOT NULL DEFAULT 0',
    );
    await _ensureColumn(
      db,
      table: 'products',
      column: 'profit_iva',
      definition: 'REAL NOT NULL DEFAULT 0',
    );
    await _ensureColumn(
      db,
      table: 'products',
      column: 'images',
      definition: 'TEXT',
    );
    await _ensureColumn(
      db,
      table: 'products',
      column: 'description',
      definition: 'TEXT',
    );
    await _ensureColumn(
      db,
      table: 'products',
      column: 'tags',
      definition: 'TEXT',
    );
    await _ensureColumn(
      db,
      table: 'products',
      column: 'is_active',
      definition: 'INTEGER NOT NULL DEFAULT 1',
    );
    await _ensureColumn(
      db,
      table: 'sales',
      column: 'client_id',
      definition: 'INTEGER',
    );
    await _ensureColumn(
      db,
      table: 'suppliers',
      column: 'email',
      definition: 'TEXT',
    );
    await _ensureColumn(
      db,
      table: 'suppliers',
      column: 'notes',
      definition: 'TEXT',
    );

    // Migracion: agregar store_id a categories para aislar categorias por tienda
    await _ensureColumn(
      db,
      table: 'categories',
      column: 'store_id',
      definition: 'INTEGER',
    );

    // Migracion de la tabla users (por si existia antes con menos columnas)
    await _ensureColumn(
      db,
      table: 'users',
      column: 'uid',
      definition: "TEXT NOT NULL DEFAULT ''",
    );
    await _ensureColumn(
      db,
      table: 'users',
      column: 'email',
      definition: "TEXT NOT NULL DEFAULT ''",
    );
    await _ensureColumn(
      db,
      table: 'users',
      column: 'password',
      definition: "TEXT NOT NULL DEFAULT ''",
    );
    await _ensureColumn(
      db,
      table: 'users',
      column: 'name',
      definition: "TEXT NOT NULL DEFAULT ''",
    );
    await _ensureColumn(
      db,
      table: 'users',
      column: 'lastname',
      definition: "TEXT NOT NULL DEFAULT ''",
    );
    await _ensureColumn(
      db,
      table: 'users',
      column: 'role',
      definition: "TEXT NOT NULL DEFAULT 'cajero'",
    );
    await _ensureColumn(
      db,
      table: 'users',
      column: 'is_active',
      definition: 'INTEGER NOT NULL DEFAULT 1',
    );
    await _ensureColumn(
      db,
      table: 'users',
      column: 'created_at',
      definition: "TEXT NOT NULL DEFAULT ''",
    );

    // Migracion: quien abre la caja
    await _ensureColumn(
      db,
      table: 'cash_sessions',
      column: 'opened_by',
      definition: 'INTEGER',
    );
    await _ensureColumn(
      db,
      table: 'cash_sessions',
      column: 'opened_by_name',
      definition: "TEXT NOT NULL DEFAULT ''",
    );

    // Migracion: tabla de desglose de denominaciones al abrir/cerrar caja
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cash_denominations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        value REAL NOT NULL,
        label TEXT NOT NULL,
        is_coin INTEGER NOT NULL DEFAULT 0,
        quantity INTEGER NOT NULL DEFAULT 0,
        subtotal REAL NOT NULL DEFAULT 0,
        moment TEXT NOT NULL DEFAULT 'open',
        created_at TEXT NOT NULL,
        FOREIGN KEY (session_id) REFERENCES cash_sessions(id) ON DELETE CASCADE
      )
    ''');

    // Migracion: asignar uid a cualquier producto que aun no lo tenga
    await db.rawUpdate(
      "UPDATE products SET uid = (lower(hex(randomblob(10)))) WHERE uid IS NULL OR uid = ''",
    );

    // ── CAPA OLAP: Tablas analiticas enterprise ──────────────
    await _ensureOlapSchema(db);

    await _seedStores(db);
    await _seedCatalog(db);
    await _runCatalogIntegrityMigration(db);
  }

  /// Crea las tablas y indices de la capa OLAP Big Data.
  /// Idempotente: usa IF NOT EXISTS en todo.
  static Future<void> _ensureOlapSchema(DatabaseExecutor db) async {
    // Resumenes temporales
    for (final ddl in _olapTablesDdl) {
      await db.execute(ddl);
    }
    // indices OLTP criticos
    for (final idx in _olapIndexesDdl) {
      await db.execute(idx);
    }
  }

  static const List<String> _olapTablesDdl = [
    '''CREATE TABLE IF NOT EXISTS summary_sales_daily (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      store_id        INTEGER NOT NULL,
      sale_date       TEXT    NOT NULL,
      total_sales     INTEGER NOT NULL DEFAULT 0,
      total_revenue   REAL    NOT NULL DEFAULT 0,
      total_cost      REAL    NOT NULL DEFAULT 0,
      total_profit    REAL    NOT NULL DEFAULT 0,
      total_discount  REAL    NOT NULL DEFAULT 0,
      total_tax       REAL    NOT NULL DEFAULT 0,
      avg_ticket      REAL    NOT NULL DEFAULT 0,
      max_ticket      REAL    NOT NULL DEFAULT 0,
      min_ticket      REAL    NOT NULL DEFAULT 0,
      units_sold      INTEGER NOT NULL DEFAULT 0,
      unique_clients  INTEGER NOT NULL DEFAULT 0,
      calculated_at   TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
      UNIQUE(store_id, sale_date)
    )''',
    '''CREATE TABLE IF NOT EXISTS summary_sales_monthly (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      store_id        INTEGER NOT NULL,
      year_month      TEXT    NOT NULL,
      total_sales     INTEGER NOT NULL DEFAULT 0,
      total_revenue   REAL    NOT NULL DEFAULT 0,
      total_cost      REAL    NOT NULL DEFAULT 0,
      total_profit    REAL    NOT NULL DEFAULT 0,
      total_discount  REAL    NOT NULL DEFAULT 0,
      total_tax       REAL    NOT NULL DEFAULT 0,
      avg_ticket      REAL    NOT NULL DEFAULT 0,
      units_sold      INTEGER NOT NULL DEFAULT 0,
      unique_clients  INTEGER NOT NULL DEFAULT 0,
      new_clients     INTEGER NOT NULL DEFAULT 0,
      credit_ratio    REAL    NOT NULL DEFAULT 0,
      calculated_at   TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
      UNIQUE(store_id, year_month)
    )''',
    '''CREATE TABLE IF NOT EXISTS summary_sales_annual (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      store_id        INTEGER NOT NULL,
      sale_year       INTEGER NOT NULL,
      total_sales     INTEGER NOT NULL DEFAULT 0,
      total_revenue   REAL    NOT NULL DEFAULT 0,
      total_cost      REAL    NOT NULL DEFAULT 0,
      total_profit    REAL    NOT NULL DEFAULT 0,
      avg_monthly_revenue REAL NOT NULL DEFAULT 0,
      units_sold      INTEGER NOT NULL DEFAULT 0,
      calculated_at   TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
      UNIQUE(store_id, sale_year)
    )''',
    '''CREATE TABLE IF NOT EXISTS analytics_product (
      id                  INTEGER PRIMARY KEY AUTOINCREMENT,
      product_id          INTEGER NOT NULL,
      store_id            INTEGER NOT NULL,
      period_days         INTEGER NOT NULL,
      units_sold          INTEGER NOT NULL DEFAULT 0,
      revenue             REAL    NOT NULL DEFAULT 0,
      cost_total          REAL    NOT NULL DEFAULT 0,
      profit              REAL    NOT NULL DEFAULT 0,
      profit_margin       REAL    NOT NULL DEFAULT 0,
      avg_daily_sales     REAL    NOT NULL DEFAULT 0,
      rotation_rate       REAL    NOT NULL DEFAULT 0,
      days_of_stock       REAL    NOT NULL DEFAULT 999,
      saleability_score   INTEGER NOT NULL DEFAULT 0,
      rank_by_revenue     INTEGER NOT NULL DEFAULT 0,
      rank_by_units       INTEGER NOT NULL DEFAULT 0,
      calculated_at       TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
      UNIQUE(product_id, store_id, period_days)
    )''',
    '''CREATE TABLE IF NOT EXISTS kpi_snapshot (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      store_id        INTEGER NOT NULL,
      snapshot_date   TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
      revenue_today   REAL    NOT NULL DEFAULT 0,
      revenue_week    REAL    NOT NULL DEFAULT 0,
      revenue_month   REAL    NOT NULL DEFAULT 0,
      revenue_year    REAL    NOT NULL DEFAULT 0,
      sales_today     INTEGER NOT NULL DEFAULT 0,
      sales_week      INTEGER NOT NULL DEFAULT 0,
      sales_month     INTEGER NOT NULL DEFAULT 0,
      profit_today    REAL    NOT NULL DEFAULT 0,
      profit_month    REAL    NOT NULL DEFAULT 0,
      margin_month    REAL    NOT NULL DEFAULT 0,
      low_stock_count INTEGER NOT NULL DEFAULT 0,
      total_inventory_value REAL NOT NULL DEFAULT 0,
      active_clients  INTEGER NOT NULL DEFAULT 0,
      new_clients_month INTEGER NOT NULL DEFAULT 0,
      credit_balance  REAL    NOT NULL DEFAULT 0,
      overdue_credit  REAL    NOT NULL DEFAULT 0,
      revenue_vs_last_month REAL DEFAULT 0,
      revenue_vs_last_year  REAL DEFAULT 0
    )''',
    '''CREATE TABLE IF NOT EXISTS analytics_cache (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      cache_key   TEXT    NOT NULL UNIQUE,
      payload     TEXT    NOT NULL,
      ttl_seconds INTEGER NOT NULL DEFAULT 300,
      created_at  TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
      expires_at  TEXT    NOT NULL
    )''',
    '''CREATE TABLE IF NOT EXISTS background_jobs (
      id           INTEGER PRIMARY KEY AUTOINCREMENT,
      job_type     TEXT    NOT NULL,
      store_id     INTEGER,
      payload      TEXT,
      status       TEXT    NOT NULL DEFAULT 'pending',
      priority     INTEGER NOT NULL DEFAULT 5,
      attempts     INTEGER NOT NULL DEFAULT 0,
      error_msg    TEXT,
      scheduled_at TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
      started_at   TEXT,
      finished_at  TEXT
    )''',
    '''CREATE TABLE IF NOT EXISTS trend_sparklines (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      store_id      INTEGER NOT NULL,
      metric        TEXT    NOT NULL,
      period_type   TEXT    NOT NULL,
      data_json     TEXT    NOT NULL,
      calculated_at TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
      UNIQUE(store_id, metric, period_type)
    )''',
  ];

  static const List<String> _olapIndexesDdl = [
    // OLTP criticos que podrian no existir aun
    'CREATE INDEX IF NOT EXISTS idx_sales_store_date ON sales(store_id, date DESC)',
    'CREATE INDEX IF NOT EXISTS idx_sales_client ON sales(client_id, date DESC)',
    'CREATE INDEX IF NOT EXISTS idx_sale_items_product ON sale_items(product_id, sale_id)',
    'CREATE INDEX IF NOT EXISTS idx_sale_items_sale ON sale_items(sale_id)',
    'CREATE INDEX IF NOT EXISTS idx_inventory_product_store ON inventory(product_id, store_id)',
    'CREATE INDEX IF NOT EXISTS idx_inventory_store_stock ON inventory(store_id, stock)',
    'CREATE INDEX IF NOT EXISTS idx_purchases_store ON purchases(store_id, date DESC)',
    'CREATE INDEX IF NOT EXISTS idx_cash_sessions_store ON cash_sessions(store_id, status, opened_at DESC)',
    'CREATE INDEX IF NOT EXISTS idx_cash_movements_session ON cash_movements(session_id, created_at DESC)',
    'CREATE INDEX IF NOT EXISTS idx_credit_sales_status ON credit_sales(status)',
    'CREATE INDEX IF NOT EXISTS idx_products_store_active ON products(store_id, is_active)',
    // OLAP
    'CREATE INDEX IF NOT EXISTS idx_summary_daily_store_date ON summary_sales_daily(store_id, sale_date DESC)',
    'CREATE INDEX IF NOT EXISTS idx_summary_monthly_store ON summary_sales_monthly(store_id, year_month DESC)',
    'CREATE INDEX IF NOT EXISTS idx_analytics_product_store ON analytics_product(store_id, period_days, saleability_score DESC)',
    'CREATE INDEX IF NOT EXISTS idx_kpi_store ON kpi_snapshot(store_id, snapshot_date DESC)',
    'CREATE INDEX IF NOT EXISTS idx_analytics_cache ON analytics_cache(cache_key, expires_at)',
    'CREATE INDEX IF NOT EXISTS idx_bg_jobs ON background_jobs(status, priority, scheduled_at)',
  ];

  static Future<void> _seedAdminUser(DatabaseExecutor db) async {
    // Crear usuario administrador por defecto si no existen usuarios
    final count = await db.rawQuery('SELECT COUNT(*) as c FROM users');
    final total = (count.first['c'] as num).toInt();
    if (total == 0) {
      final uid = generateFirebaseId();
      await db.rawInsert(
        '''INSERT OR IGNORE INTO users (uid, email, password, name, lastname, role, is_active, created_at)
           VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          uid,
          'admin@bazarnicole.com',
          'admin123',
          'Administrador',
          '',
          'admin',
          1,
          DateTime.now().toIso8601String(),
        ],
      );
    }

    // Asegurar que el usuario principal siempre exista
    await db.rawInsert(
      '''INSERT OR IGNORE INTO users (uid, email, password, name, lastname, role, is_active, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        'user_1754669120053',
        'anthonycordova330@gmail.com',
        '12345678',
        'Anthony',
        'Cordova',
        'admin',
        1,
        '2025-08-08T11:05:20.058581',
      ],
    );
  }

  static Future<void> _seedPaymentMethods(DatabaseExecutor db) async {
    const methods = [
      {'name': 'Efectivo', 'is_cash': 1},
      {'name': 'Transferencia', 'is_cash': 0},
      {'name': 'Deposito', 'is_cash': 0},
      {'name': 'PayPal', 'is_cash': 0},
      {'name': 'Tarjeta debito', 'is_cash': 0},
      {'name': 'Credito', 'is_cash': 0},
    ];
    for (final m in methods) {
      await db.rawInsert(
        'INSERT OR IGNORE INTO payment_methods (name, is_cash) VALUES (?, ?)',
        [m['name'], m['is_cash']],
      );
    }
  }

  static Future<void> _seedStores(DatabaseExecutor db) async {
    for (final storeName in _storeNames) {
      await db.rawInsert('INSERT OR IGNORE INTO stores (name) VALUES (?)', [
        storeName,
      ]);
    }
  }

  static Future<void> _seedCatalog(DatabaseExecutor db) async {
    await _ensureCategory(db, 'Sin categoria');

    final stores = await db.rawQuery('SELECT id, name FROM stores ORDER BY id');
    final storeIds = <String, int>{
      for (final row in stores)
        row['name'] as String: (row['id'] as num).toInt(),
    };

    if (storeIds.isEmpty) return;

    // Iterar estructura: Store → Categoria → Productos
    for (final storeEntry in _catalogByStore.entries) {
      final storeName = storeEntry.key;
      final storeId = storeIds[storeName];
      if (storeId == null) continue; // tienda no existe en DB

      for (final categoryEntry in storeEntry.value.entries) {
        final categoryId = await _ensureCategory(
          db,
          categoryEntry.key,
          storeId: storeId,
        );

        for (final rawName in categoryEntry.value) {
          final productName = _cleanName(rawName);
          // Buscar por nombre Y tienda para evitar mezclar productos de distintos locales
          final existing = await db.rawQuery(
            'SELECT id FROM products WHERE lower(name) = ? AND store_id = ?',
            [productName.toLowerCase(), storeId],
          );

          int productId;
          if (existing.isNotEmpty) {
            productId = (existing.first['id'] as num).toInt();
            // Asignar uid si el producto semilla aun no lo tiene
            final uidCheck = await db.rawQuery(
              'SELECT uid FROM products WHERE id = ? LIMIT 1',
              [productId],
            );
            if (uidCheck.isNotEmpty && uidCheck.first['uid'] == null) {
              await db.rawUpdate('UPDATE products SET uid = ? WHERE id = ?', [
                generateFirebaseId(),
                productId,
              ]);
            }
          } else {
            final uniqueSku = await _uniqueSku(db, _buildSku(productName));
            productId = await db.rawInsert(
              'INSERT INTO products (uid, name, sku, category_id, store_id, created_at) VALUES (?, ?, ?, ?, ?, ?)',
              [
                generateFirebaseId(),
                productName,
                uniqueSku,
                categoryId,
                storeId,
                DateTime.now().toIso8601String(),
              ],
            );
          }

          // Registrar inventario para la tienda correspondiente
          await db.rawInsert(
            'INSERT OR IGNORE INTO inventory (product_id, store_id, stock) VALUES (?, ?, 0)',
            [productId, storeId],
          );
        }
      }
    }
  }

  // ════════════════════════════════════════════════════════════════════════
  // AUDITORiA E INTEGRIDAD DEL CATÁLOGO
  // ════════════════════════════════════════════════════════════════════════

  /// Construye mapas de validacion desde el catálogo maestro.
  /// Retorna: { productKey → (storeName, categoryName) }
  static Map<String, _CatalogEntry> _buildCatalogLookup() {
    final lookup = <String, _CatalogEntry>{};
    for (final storeEntry in _catalogByStore.entries) {
      for (final catEntry in storeEntry.value.entries) {
        for (final product in catEntry.value) {
          lookup[product.trim().toLowerCase()] = _CatalogEntry(
            storeName: storeEntry.key,
            categoryName: catEntry.key,
          );
        }
      }
    }
    return lookup;
  }

  /// Correccion segura: solo ejecuta UPDATEs, nunca elimina registros.
  /// Se llama automáticamente desde [_ensureBusinessSchema].
  static Future<void> _runCatalogIntegrityMigration(DatabaseExecutor db) async {
    final lookup = _buildCatalogLookup();

    // Obtener tiendas
    final stores = await db.rawQuery('SELECT id, name FROM stores');
    final storeNameToId = <String, int>{
      for (final r in stores) r['name'] as String: (r['id'] as num).toInt(),
    };

    // Obtener todos los productos con su tienda y categoria actual
    final products = await db.rawQuery('''
      SELECT
        p.id,
        p.name,
        p.store_id,
        p.category_id,
        c.name  AS category_name,
        s.name  AS store_name
      FROM products p
      LEFT JOIN categories c ON c.id = p.category_id
      LEFT JOIN stores s ON s.id = p.store_id
    ''');

    for (final p in products) {
      final productKey = (p['name'] as String? ?? '').trim().toLowerCase();
      final entry = lookup[productKey];
      if (entry == null) continue; // fuera del catálogo → no tocar

      final expectedStoreId = storeNameToId[entry.storeName];
      if (expectedStoreId == null) continue;

      final currentStoreId = p['store_id'] as int?;
      final currentCategoryId = p['category_id'] as int?;
      final productId = (p['id'] as num).toInt();

      // Obtener (o crear) la categoria correcta para la tienda correcta
      final correctCategoryId = await _ensureCategory(
        db,
        entry.categoryName,
        storeId: expectedStoreId,
      );

      final storeWrong = currentStoreId != expectedStoreId;
      final categoryWrong = currentCategoryId != correctCategoryId;

      if (!storeWrong && !categoryWrong) continue;

      final sets = <String>[];
      final args = <dynamic>[];

      if (storeWrong) {
        sets.add('store_id = ?');
        args.add(expectedStoreId);
      }
      if (categoryWrong) {
        sets.add('category_id = ?');
        args.add(correctCategoryId);
      }
      args.add(productId);

      await db.rawUpdate(
        'UPDATE products SET ${sets.join(', ')} WHERE id = ?',
        args,
      );
    }

    // Reparar categorias del catálogo que no tengan store_id asignado
    for (final storeEntry in _catalogByStore.entries) {
      final storeId = storeNameToId[storeEntry.key];
      if (storeId == null) continue;
      for (final categoryName in storeEntry.value.keys) {
        await db.rawUpdate(
          '''UPDATE categories
             SET store_id = ?
             WHERE slug = ? AND store_id IS NULL''',
          [storeId, _buildCategorySlug(categoryName)],
        );
      }
    }
  }

  /// Auditoria publica: devuelve un reporte de integridad del catálogo.
  /// No modifica datos; solo lee y clasifica.
  ///
  /// Campos retornados:
  /// - `correct`            : productos cuya tienda y categoria son correctas
  /// - `corrected_products` : productos que serian corregidos (simulacion)
  /// - `out_of_catalog`     : productos que no aparecen en el catálogo maestro
  /// - `duplicates_found`   : grupos de productos con el mismo nombre (lower)
  /// - `duplicates`         : lista de nombres duplicados
  /// - `risks`              : descripciones de inconsistencias detectadas
  static Future<Map<String, dynamic>> runCatalogIntegrityAudit() async {
    final db = await database;
    final lookup = _buildCatalogLookup();

    final stores = await db.rawQuery('SELECT id, name FROM stores');
    final storeNameToId = <String, int>{
      for (final r in stores) r['name'] as String: (r['id'] as num).toInt(),
    };

    final products = await db.rawQuery('''
      SELECT
        p.id,
        p.name,
        p.store_id,
        p.category_id,
        c.name  AS category_name,
        s.name  AS store_name
      FROM products p
      LEFT JOIN categories c ON c.id = p.category_id
      LEFT JOIN stores s ON s.id = p.store_id
    ''');

    int correct = 0;
    int wouldCorrect = 0;
    int outOfCatalog = 0;
    final risks = <String>[];

    for (final p in products) {
      final productKey = (p['name'] as String? ?? '').trim().toLowerCase();
      final entry = lookup[productKey];

      if (entry == null) {
        outOfCatalog++;
        continue;
      }

      final expectedStoreId = storeNameToId[entry.storeName];
      final currentStoreId = p['store_id'] as int?;

      // Para la comparacion de categoria buscamos por nombre
      final catRows = await db.rawQuery(
        'SELECT id FROM categories WHERE slug = ? LIMIT 1',
        [_buildCategorySlug(entry.categoryName)],
      );
      final expectedCategoryId = catRows.isNotEmpty
          ? (catRows.first['id'] as num).toInt()
          : null;

      final storeWrong =
          expectedStoreId != null && currentStoreId != expectedStoreId;
      final categoryWrong =
          expectedCategoryId != null &&
          (p['category_id'] as int?) != expectedCategoryId;

      if (storeWrong || categoryWrong) {
        wouldCorrect++;
        final msg = StringBuffer('⚠ "${p['name']}": ');
        if (storeWrong) {
          msg.write('tienda "${p['store_name']}" → "${entry.storeName}"; ');
        }
        if (categoryWrong) {
          msg.write(
            'categoria "${p['category_name']}" → "${entry.categoryName}"',
          );
        }
        risks.add(msg.toString().trim());
      } else {
        correct++;
      }
    }

    // Detectar duplicados por nombre (lower)
    final dupRows = await db.rawQuery('''
      SELECT name, COUNT(*) AS cnt
      FROM products
      GROUP BY lower(name)
      HAVING COUNT(*) > 1
      ORDER BY cnt DESC
    ''');

    return {
      'correct': correct,
      'corrected_products': wouldCorrect,
      'out_of_catalog': outOfCatalog,
      'duplicates_found': dupRows.length,
      'duplicates': dupRows.map((d) => '${d['name']} (×${d['cnt']})').toList(),
      'risks': risks,
      'total_audited': products.length,
    };
  }

  static Future<void> _ensureColumn(
    DatabaseExecutor db, {
    required String table,
    required String column,
    required String definition,
  }) async {
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final exists = info.any((row) => row['name'] == column);
    if (!exists) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  static Future<int> _ensureCategory(
    DatabaseExecutor db,
    String? categoryName, {
    int? storeId,
  }) async {
    final name = _cleanName(
      categoryName?.isNotEmpty == true ? categoryName! : 'Sin categoria',
    );
    final slug = _buildCategorySlug(name);

    if (storeId != null) {
      // Buscar categoria especifica de esta tienda primero
      final existingForStore = await db.rawQuery(
        'SELECT id FROM categories WHERE slug = ? AND store_id = ? LIMIT 1',
        [slug, storeId],
      );
      if (existingForStore.isNotEmpty) {
        return (existingForStore.first['id'] as num).toInt();
      }

      // Buscar si ya existe con ese slug (sin store_id o de otra tienda)
      final existingGlobal = await db.rawQuery(
        'SELECT id, store_id FROM categories WHERE slug = ? LIMIT 1',
        [slug],
      );

      if (existingGlobal.isNotEmpty) {
        final catId = (existingGlobal.first['id'] as num).toInt();
        final existingStoreId = existingGlobal.first['store_id'];
        // Si no tiene store_id asignado aun, asignarlo
        if (existingStoreId == null) {
          await db.rawUpdate(
            'UPDATE categories SET store_id = ? WHERE id = ?',
            [storeId, catId],
          );
        }
        // Si ya pertenece a otra tienda, crear nueva entrada con nombre compuesto
        // para no romper la restriccion UNIQUE(name). Esto solo ocurre si dos
        // tiendas comparten exactamente el mismo nombre de categoria.
        else if (existingStoreId != storeId) {
          final altName = '$name [$storeId]';
          final altSlug = _buildCategorySlug(altName);
          await db.rawInsert(
            'INSERT OR IGNORE INTO categories (name, slug, store_id) VALUES (?, ?, ?)',
            [altName, altSlug, storeId],
          );
          final altRows = await db.rawQuery(
            'SELECT id FROM categories WHERE slug = ? AND store_id = ? LIMIT 1',
            [altSlug, storeId],
          );
          return (altRows.first['id'] as num).toInt();
        }
        return catId;
      }

      // No existe: crear con store_id
      final newId = await db.rawInsert(
        'INSERT INTO categories (name, slug, store_id) VALUES (?, ?, ?)',
        [name, slug, storeId],
      );
      return newId;
    }

    // Modo legado sin contexto de tienda
    await db.rawInsert(
      'INSERT OR IGNORE INTO categories (name, slug) VALUES (?, ?)',
      [name, slug],
    );

    final rows = await db.rawQuery(
      'SELECT id FROM categories WHERE slug = ? LIMIT 1',
      [slug],
    );

    return (rows.first['id'] as num).toInt();
  }

  static Future<int?> _ensureSupplier(
    DatabaseExecutor db,
    String? supplierName, {
    String? phone,
  }) async {
    final name = _cleanName(supplierName ?? '');
    if (name.isEmpty) return null;

    final cleanPhone = phone?.trim();

    await db.rawInsert(
      'INSERT OR IGNORE INTO suppliers (name, phone) VALUES (?, ?)',
      [name, cleanPhone?.isEmpty == true ? null : cleanPhone],
    );

    if (cleanPhone != null && cleanPhone.isNotEmpty) {
      await db.rawUpdate(
        'UPDATE suppliers SET phone = ? WHERE lower(name) = ?',
        [cleanPhone, name.toLowerCase()],
      );
    }

    final rows = await db.rawQuery(
      'SELECT id FROM suppliers WHERE lower(name) = ? LIMIT 1',
      [name.toLowerCase()],
    );

    return rows.isEmpty ? null : (rows.first['id'] as num).toInt();
  }

  static Future<String> _uniqueSku(DatabaseExecutor db, String baseSku) async {
    final cleanBase = _buildSku(baseSku);
    var candidate = cleanBase;
    var suffix = 1;

    while (true) {
      final rows = await db.rawQuery(
        'SELECT id FROM products WHERE upper(sku) = upper(?) LIMIT 1',
        [candidate],
      );

      if (rows.isEmpty) return candidate;

      candidate = '$cleanBase-$suffix';
      suffix++;
    }
  }

  static String _buildSku(String name) {
    final normalized = name
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');

    if (normalized.isEmpty) return 'ITEM';
    return normalized.substring(0, min(normalized.length, 32));
  }

  static String _cleanName(String value) {
    return value.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String _buildCategorySlug(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'\s+'), '');
    return normalized.toLowerCase();
  }

  static void _performAutomaticBackupIfNeeded() {
    Future.delayed(const Duration(seconds: 2), () async {
      try {
        await BackupService.performAutomaticBackupIfNeeded();
      } catch (_) {}
    });
  }

  static Future<List<Map<String, dynamic>>> getStores() async {
    final db = await database;
    return db.rawQuery('SELECT id, name FROM stores ORDER BY id');
  }

  static Future<List<Map<String, dynamic>>> getCategories() async {
    final db = await database;
    return db.rawQuery('''
      SELECT c.id, c.name, c.slug, c.store_id, c.image_url,
        (SELECT COUNT(*) FROM products p WHERE p.category_id = c.id) AS product_count
      FROM categories c
      ORDER BY c.name
    ''');
  }

  static Future<int> createCategory({
    required String name,
    int? storeId,
    String imageUrl = '',
  }) async {
    final db = await database;
    final cleanName = _cleanName(name);
    if (cleanName.isEmpty) throw Exception('El nombre de la categoría es obligatorio.');
    final slug = _buildCategorySlug(cleanName);
    final id = await db.rawInsert(
      'INSERT INTO categories (name, slug, store_id, image_url) VALUES (?, ?, ?, ?)',
      [cleanName, slug, storeId, imageUrl.trim()],
    );
    notifyDatabaseChanged();
    return id;
  }

  static Future<void> updateCategory({
    required int categoryId,
    required String name,
    int? storeId,
    String imageUrl = '',
  }) async {
    final db = await database;
    final cleanName = _cleanName(name);
    if (cleanName.isEmpty) throw Exception('El nombre de la categoría es obligatorio.');
    await db.rawUpdate(
      'UPDATE categories SET name = ?, slug = ?, store_id = ?, image_url = ? WHERE id = ?',
      [cleanName, _buildCategorySlug(cleanName), storeId, imageUrl.trim(), categoryId],
    );
    notifyDatabaseChanged();
  }

  static Future<void> deleteCategory(int categoryId) async {
    final db = await database;
    final products = await db.rawQuery(
      'SELECT COUNT(*) AS total FROM products WHERE category_id = ?',
      [categoryId],
    );
    final total = (products.first['total'] as num?)?.toInt() ?? 0;
    if (total > 0) {
      throw Exception('No puedes eliminar esta categoría porque tiene $total producto(s) asociado(s).');
    }
    await db.rawDelete('DELETE FROM categories WHERE id = ?', [categoryId]);
    notifyDatabaseChanged();
  }

  static ProductQueryFilters buildProductQueryFilters({
    String search = '',
    int? storeId,
    String? category,
  }) {
    final params = <Object?>[];
    final clauses = <String>[];

    final normalizedSearch = search.trim();
    if (normalizedSearch.isNotEmpty) {
      final filter = '%$normalizedSearch%';
      clauses.add(
        "(p.name LIKE ? OR p.sku LIKE ? OR COALESCE(p.description, '') LIKE ? OR COALESCE(p.aux_code, '') LIKE ? OR COALESCE(c.name, '') LIKE ?)",
      );
      params.addAll([filter, filter, filter, filter, filter]);
    }

    if (storeId != null) {
      clauses.add('p.store_id = ?');
      params.add(storeId);
    }

    if (category != null && category.trim().isNotEmpty) {
      final normalizedCategory = '%${category.trim()}%';
      clauses.add("COALESCE(c.name, '') LIKE ?");
      params.add(normalizedCategory);
    }

    return ProductQueryFilters(
      whereClause: clauses.isEmpty ? '' : ' WHERE ${clauses.join(' AND ')}',
      params: params,
    );
  }

  static Future<List<Map<String, dynamic>>> getProducts({
    String search = '',
    int? storeId,
    String? category,
  }) async {
    final db = await database;
    final filters = buildProductQueryFilters(
      search: search,
      storeId: storeId,
      category: category,
    );

    return db.rawQuery('''
      SELECT
        p.id,
        p.uid,
        p.name,
        p.sku,
        p.aux_code,
        p.description,
        p.tags,
        p.price,
        p.cost_price,
        p.iva_rate,
        p.profit_iva,
        p.images,
        p.store_id,
        COALESCE(c.name, 'Sin categoria') AS category,
        COALESCE(st.name, '') AS store_name,
        COALESCE(SUM(i.stock), 0) AS total_stock,
        COALESCE(MAX(CASE WHEN s.name = 'Bazar' THEN i.stock END), 0) AS stock_bazar,
        COALESCE(MAX(CASE WHEN s.name = 'Tienda' THEN i.stock END), 0) AS stock_tienda
      FROM products p
      LEFT JOIN categories c ON c.id = p.category_id
      LEFT JOIN stores st ON st.id = p.store_id
      LEFT JOIN inventory i ON i.product_id = p.id
      LEFT JOIN stores s ON s.id = i.store_id
      ${filters.whereClause}
      GROUP BY p.id, p.name, p.sku, p.price, c.name
      ORDER BY p.name COLLATE NOCASE
      ''', filters.params);
  }

  static Future<List<Map<String, dynamic>>> getInventoryByStore(
    int storeId, {
    String search = '',
  }) async {
    final db = await database;
    final filter = '%${search.trim()}%';

    return db.rawQuery(
      '''
      SELECT
        p.id AS product_id,
        p.name,
        p.sku,
        COALESCE(p.aux_code, '') AS aux_code,
        COALESCE(p.description, '') AS description,
        p.price,
        COALESCE(p.cost_price, 0) AS cost_price,
        COALESCE(c.name, 'Sin categoria') AS category,
        COALESCE(i.stock, 0) AS stock
      FROM products p
      LEFT JOIN categories c ON c.id = p.category_id
      INNER JOIN inventory i ON i.product_id = p.id AND i.store_id = ?
      WHERE i.stock >= 0
        AND (
          p.name LIKE ? OR
          p.sku LIKE ? OR
          COALESCE(p.aux_code, '') LIKE ? OR
          COALESCE(p.description, '') LIKE ? OR
          COALESCE(c.name, '') LIKE ?
        )
      ORDER BY p.name COLLATE NOCASE
      ''',
      [storeId, filter, filter, filter, filter, filter],
    );
  }

  static Future<void> createProduct({
    required String name,
    double price = 0,
    double costPrice = 0,
    double ivaRate = 0,
    double profitIva = 0,
    String? sku,
    String? auxCode,
    String? description,
    String? tags,
    int? storeId,
    String? categoryName,
    List<String> images = const [],
    Map<int, int> initialStock = const {},
  }) async {
    final cleanName = _cleanName(name);
    if (cleanName.isEmpty) {
      throw Exception('El nombre del producto es obligatorio');
    }

    await transaction((txn) async {
      final existing = await txn.rawQuery(
        'SELECT id FROM products WHERE lower(name) = ?',
        [cleanName.toLowerCase()],
      );

      if (existing.isNotEmpty) {
        throw Exception(
          'El producto ya existe. Usa el inventario por local para ajustar stock.',
        );
      }

      final categoryId = await _ensureCategory(txn, categoryName);
      final uniqueSku = await _uniqueSku(
        txn,
        (sku?.trim().isNotEmpty ?? false) ? sku!.trim() : _buildSku(cleanName),
      );
      final uid = generateFirebaseId();
      final imagesJson = images.isEmpty ? null : images.join(',');

      final productId = await txn.rawInsert(
        'INSERT INTO products (uid, name, sku, aux_code, description, tags, category_id, store_id, price, cost_price, iva_rate, profit_iva, images, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          uid,
          cleanName,
          uniqueSku,
          auxCode?.trim().isEmpty ?? true ? null : auxCode!.trim(),
          description?.trim().isEmpty ?? true ? null : description!.trim(),
          tags?.trim().isEmpty ?? true ? null : tags!.trim(),
          categoryId,
          storeId,
          price < 0 ? 0 : price,
          costPrice < 0 ? 0 : costPrice,
          ivaRate < 0 ? 0 : ivaRate,
          profitIva < 0 ? 0 : profitIva,
          imagesJson,
          DateTime.now().toIso8601String(),
        ],
      );

      final storeRows = await txn.rawQuery('SELECT id FROM stores ORDER BY id');
      for (final store in storeRows) {
        final sid = (store['id'] as num).toInt();
        await txn.rawInsert(
          'INSERT OR IGNORE INTO inventory (product_id, store_id, stock) VALUES (?, ?, ?)',
          [productId, sid, max(0, initialStock[sid] ?? 0)],
        );
      }
    });
  }

  static Future<void> updateInventoryStock({
    required int productId,
    required int storeId,
    required int stock,
  }) async {
    final db = await database;
    final safeStock = max(0, stock);

    await db.transaction((txn) async {
      await txn.rawInsert(
        'INSERT OR IGNORE INTO inventory (product_id, store_id, stock) VALUES (?, ?, 0)',
        [productId, storeId],
      );

      await txn.rawUpdate(
        'UPDATE inventory SET stock = ? WHERE product_id = ? AND store_id = ?',
        [safeStock, productId, storeId],
      );
    });
  }

  static Future<void> transferInventory({
    required int productId,
    required int fromStoreId,
    required int toStoreId,
    required int quantity,
  }) async {
    if (fromStoreId == toStoreId) {
      throw Exception('Selecciona dos locales distintos');
    }

    if (quantity <= 0) {
      throw Exception('La cantidad debe ser mayor que cero');
    }

    await transaction((txn) async {
      await txn.rawInsert(
        'INSERT OR IGNORE INTO inventory (product_id, store_id, stock) VALUES (?, ?, 0)',
        [productId, fromStoreId],
      );
      await txn.rawInsert(
        'INSERT OR IGNORE INTO inventory (product_id, store_id, stock) VALUES (?, ?, 0)',
        [productId, toStoreId],
      );

      final sourceRows = await txn.rawQuery(
        'SELECT stock FROM inventory WHERE product_id = ? AND store_id = ? LIMIT 1',
        [productId, fromStoreId],
      );

      final available = sourceRows.isEmpty
          ? 0
          : (sourceRows.first['stock'] as num).toInt();

      if (available < quantity) {
        throw Exception('No hay stock suficiente en el local origen');
      }

      await txn.rawUpdate(
        'UPDATE inventory SET stock = stock - ? WHERE product_id = ? AND store_id = ?',
        [quantity, productId, fromStoreId],
      );

      await txn.rawUpdate(
        'UPDATE inventory SET stock = stock + ? WHERE product_id = ? AND store_id = ?',
        [quantity, productId, toStoreId],
      );

      await txn.rawInsert(
        'INSERT INTO inventory_movements (product_id, from_store_id, to_store_id, quantity, date) VALUES (?, ?, ?, ?, ?)',
        [
          productId,
          fromStoreId,
          toStoreId,
          quantity,
          DateTime.now().toIso8601String(),
        ],
      );
    });
  }

  static Future<int> registerSale({
    required int storeId,
    required List<Map<String, dynamic>> items,
    int? clientId,
  }) async {
    if (items.isEmpty) {
      throw Exception('La venta debe contener al menos un producto');
    }

    return transaction((txn) async {
      double total = 0;

      for (final item in items) {
        final productId = item['product_id'] as int;
        final quantity = (item['quantity'] as num).toInt();
        final price = (item['price'] as num).toDouble();

        if (quantity <= 0) {
          throw Exception('La cantidad de venta debe ser mayor que cero');
        }

        final stockRows = await txn.rawQuery(
          'SELECT stock FROM inventory WHERE product_id = ? AND store_id = ? LIMIT 1',
          [productId, storeId],
        );

        final available = stockRows.isEmpty
            ? 0
            : (stockRows.first['stock'] as num).toInt();

        if (available < quantity) {
          throw Exception('Stock insuficiente para completar la venta');
        }

        total += quantity * price;
      }

      final saleId = await txn.rawInsert(
        'INSERT INTO sales (store_id, client_id, date, total) VALUES (?, ?, ?, ?)',
        [storeId, clientId, DateTime.now().toIso8601String(), total],
      );

      for (final item in items) {
        final productId = item['product_id'] as int;
        final quantity = (item['quantity'] as num).toInt();
        final price = (item['price'] as num).toDouble();

        await txn.rawInsert(
          'INSERT INTO sale_items (sale_id, product_id, quantity, price) VALUES (?, ?, ?, ?)',
          [saleId, productId, quantity, price],
        );

        await txn.rawUpdate(
          'UPDATE inventory SET stock = stock - ? WHERE product_id = ? AND store_id = ?',
          [quantity, productId, storeId],
        );
      }

      return saleId;
    });
  }

  static Future<void> updateProduct({
    required int productId,
    required String name,
    required String categoryName,
    required String sku,
    required double price,
    double costPrice = 0,
    double ivaRate = 0,
    double profitIva = 0,
    String? auxCode,
    String? description,
    String? tags,
    int? storeId,
    List<String>? images,
  }) async {
    final cleanName = _cleanName(name);
    if (cleanName.isEmpty) {
      throw Exception('El nombre del producto es obligatorio');
    }

    await transaction((txn) async {
      final repeated = await txn.rawQuery(
        'SELECT id FROM products WHERE lower(name) = ? AND id != ?',
        [cleanName.toLowerCase(), productId],
      );

      if (repeated.isNotEmpty) {
        throw Exception('Ya existe otro producto con ese nombre');
      }

      final categoryId = await _ensureCategory(txn, categoryName);
      final imagesJson = images == null
          ? null
          : (images.isEmpty ? null : images.join(','));
      await txn.rawUpdate(
        'UPDATE products SET name = ?, sku = ?, aux_code = ?, description = ?, tags = ?, category_id = ?, store_id = ?, price = ?, cost_price = ?, iva_rate = ?, profit_iva = ?, images = ? WHERE id = ?',
        [
          cleanName,
          sku.trim().isEmpty ? _buildSku(cleanName) : sku.trim(),
          auxCode?.trim().isEmpty ?? true ? null : auxCode!.trim(),
          description?.trim().isEmpty ?? true ? null : description!.trim(),
          tags?.trim().isEmpty ?? true ? null : tags!.trim(),
          categoryId,
          storeId,
          price < 0 ? 0 : price,
          costPrice < 0 ? 0 : costPrice,
          ivaRate < 0 ? 0 : ivaRate,
          profitIva < 0 ? 0 : profitIva,
          imagesJson,
          productId,
        ],
      );
    });
  }

  static Future<void> updateProductImages({
    required int productId,
    required List<String> imageIds,
  }) async {
    final db = await database;
    final cleanIds = imageIds
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();
    final imagesJson = cleanIds.isEmpty ? null : cleanIds.join(',');

    await db.update(
      'products',
      {'images': imagesJson},
      where: 'id = ?',
      whereArgs: [productId],
    );
  }

  /// IDs de Drive asociados al producto. Las rutas locales antiguas se ignoran
  /// para no intentar borrar archivos fuera de Google Drive.
  static Future<List<String>> getProductImageIds(int productId) async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT images FROM products WHERE id = ? LIMIT 1',
      [productId],
    );
    if (rows.isEmpty) return const [];
    final raw = rows.first['images'] as String? ?? '';
    return raw
        .split(',')
        .map((value) => value.trim())
        .where(
          (value) =>
              value.isNotEmpty && !value.contains('/') && !value.contains('\\'),
        )
        .toList();
  }

  static Future<void> deleteProduct(int productId) async {
    await transaction((txn) async {
      await txn.rawDelete('DELETE FROM inventory WHERE product_id = ?', [
        productId,
      ]);
      await txn.rawDelete('DELETE FROM products WHERE id = ?', [productId]);
    });
  }

  static Future<List<Map<String, dynamic>>> getCustomers({
    String search = '',
  }) async {
    final db = await database;
    final filter = '%${search.trim()}%';

    return db.rawQuery(
      '''
      SELECT id, name, phone, email, notes, created_at,
              cedula, identification_type, address, apellidos, referencias, uid
      FROM clients
      WHERE name LIKE ? OR COALESCE(phone, '') LIKE ?
         OR COALESCE(email, '') LIKE ? OR COALESCE(cedula, '') LIKE ?
      ORDER BY name COLLATE NOCASE
      ''',
      [filter, filter, filter, filter],
    );
  }

  static Future<void> updateCustomer({
    required int id,
    required String name,
    String? uid,
    String? phone,
    String? email,
    String? notes,
    String? apellidos,
    String? cedula,
    String? identificationType,
    String? address,
    String? referencias,
  }) async {
    if (name.trim().isEmpty) {
      throw Exception('El nombre del cliente es obligatorio');
    }
    final db = await database;
    await db.update(
      'clients',
      {
        'name': _cleanName(name),
        'uid': uid?.trim().isNotEmpty == true ? uid!.trim() : null,
        'phone': phone?.trim().isNotEmpty == true ? phone!.trim() : null,
        'email': email?.trim().isNotEmpty == true ? email!.trim() : null,
        'notes': notes?.trim().isNotEmpty == true ? notes!.trim() : null,
        'apellidos': apellidos?.trim().isNotEmpty == true
            ? apellidos!.trim()
            : null,
        'cedula': cedula?.trim().isNotEmpty == true ? cedula!.trim() : null,
        'identification_type': identificationType,
        'address': address?.trim().isNotEmpty == true ? address!.trim() : null,
        'referencias': referencias?.trim().isNotEmpty == true
            ? referencias!.trim()
            : null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> deleteCustomer(int id) async {
    final db = await database;
    await db.delete('clients', where: 'id = ?', whereArgs: [id]);
  }

  static Future<String> createCustomer({
    required String name,
    String? uid,
    String? phone,
    String? email,
    String? notes,
    String? apellidos,
    String? cedula,
    String? address,
    String? referencias,
  }) async {
    final cleanName = _cleanName(name);
    if (cleanName.isEmpty) {
      throw Exception('El nombre del cliente es obligatorio');
    }

    final db = await database;
    final customerId = await db.rawInsert(
      '''INSERT INTO clients
         (name, phone, email, notes, apellidos, cedula, address, referencias, uid, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, COALESCE(?, lower(hex(randomblob(16)))), ?)''',
      [
        cleanName,
        phone?.trim(),
        email?.trim(),
        notes?.trim(),
        apellidos?.trim(),
        cedula?.trim(),
        address?.trim(),
        referencias?.trim(),
        uid?.trim().isNotEmpty == true ? uid!.trim() : null,
        DateTime.now().toIso8601String(),
      ],
    );
    final rows = await db.query(
      'clients',
      columns: ['uid'],
      where: 'id = ?',
      whereArgs: [customerId],
      limit: 1,
    );
    return rows.first['uid']?.toString() ?? '';
  }

  static Future<List<Map<String, dynamic>>> getCustomerHistory(
    int customerId,
  ) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT sa.id, sa.date, sa.total, st.name AS store_name
      FROM sales sa
      LEFT JOIN stores st ON st.id = sa.store_id
      WHERE sa.client_id = ?
      ORDER BY sa.date DESC
      ''',
      [customerId],
    );
  }

  static Future<List<Map<String, dynamic>>> getSuppliers({
    String search = '',
  }) async {
    final db = await database;
    final filter = '%${search.trim()}%';

    return db.rawQuery(
      '''
      SELECT id, name, phone
      FROM suppliers
      WHERE name LIKE ? OR COALESCE(phone, '') LIKE ?
      ORDER BY name COLLATE NOCASE
      ''',
      [filter, filter],
    );
  }

  static Future<int> registerPurchase({
    required int storeId,
    required List<Map<String, dynamic>> items,
    String? supplierName,
    String? supplierPhone,
    double vatRate = 0,
    double discount = 0,
    String? invoiceNumber,
    String? auxiliaryInvoiceNumber,
    String paymentMethod = 'Contado',
  }) async {
    if (items.isEmpty) {
      throw Exception('La compra debe contener al menos un producto');
    }

    return transaction((txn) async {
      double total = 0;

      for (final item in items) {
        final quantity = (item['quantity'] as num).toInt();
        final cost = (item['cost'] as num).toDouble();

        if (quantity <= 0) {
          throw Exception('La cantidad de compra debe ser mayor que cero');
        }

        if (cost < 0) {
          throw Exception('El costo no puede ser negativo');
        }

        total += quantity * cost * (1 + vatRate / 100);
      }

      total = (total - discount).clamp(0, double.infinity);

      final supplierId = await _ensureSupplier(
        txn,
        supplierName,
        phone: supplierPhone,
      );

      final purchaseId = await txn.rawInsert(
        'INSERT INTO purchases (store_id, supplier_id, total, date, invoice_number, auxiliary_invoice_number, payment_method) VALUES (?, ?, ?, ?, ?, ?, ?)',
        [
          storeId,
          supplierId,
          total,
          DateTime.now().toIso8601String(),
          invoiceNumber,
          auxiliaryInvoiceNumber,
          paymentMethod,
        ],
      );

      for (final item in items) {
        final productId = (item['product_id'] as num).toInt();
        final quantity = (item['quantity'] as num).toInt();
        final cost = (item['cost'] as num).toDouble();

        await txn.rawInsert(
          'INSERT OR IGNORE INTO inventory (product_id, store_id, stock) VALUES (?, ?, 0)',
          [productId, storeId],
        );

        await txn.rawInsert(
          'INSERT INTO purchase_items (purchase_id, product_id, quantity, cost) VALUES (?, ?, ?, ?)',
          [purchaseId, productId, quantity, cost],
        );

        await txn.rawUpdate(
          'UPDATE inventory SET stock = stock + ? WHERE product_id = ? AND store_id = ?',
          [quantity, productId, storeId],
        );
      }

      return purchaseId;
    });
  }

  static Future<List<Map<String, dynamic>>> getSalesHistory({
    int? storeId,
    int? customerId,
    int? year,
    int? month,
    int? day,
    int limit = 50,
    int offset = 0,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (storeId != null) {
      conditions.add('sa.store_id = ?');
      args.add(storeId);
    }
    if (customerId != null) {
      conditions.add('sa.client_id = ?');
      args.add(customerId);
    }
    if (year != null) {
      conditions.add("strftime('%Y', sa.date) = ?");
      args.add(year.toString().padLeft(4, '0'));
    }
    if (month != null) {
      conditions.add("strftime('%m', sa.date) = ?");
      args.add(month.toString().padLeft(2, '0'));
    }
    if (day != null) {
      conditions.add("strftime('%d', sa.date) = ?");
      args.add(day.toString().padLeft(2, '0'));
    }

    final whereClause = conditions.isEmpty
        ? ''
        : 'WHERE ${conditions.join(' AND ')}';

    return db.rawQuery('''
      SELECT sa.id, sa.date, sa.total,
             st.name AS store_name,
             COALESCE(c.name, 'Consumidor final') AS client_name,
             pm.name AS payment_method_name
      FROM sales sa
      INNER JOIN stores st ON st.id = sa.store_id
      LEFT JOIN clients c ON c.id = sa.client_id
      LEFT JOIN sale_payments sp ON sp.sale_id = sa.id
        AND sp.id = (SELECT MIN(id) FROM sale_payments WHERE sale_id = sa.id)
      LEFT JOIN payment_methods pm ON pm.id = sp.method_id
      $whereClause
      ORDER BY sa.date DESC, sa.id DESC
      LIMIT $limit OFFSET $offset
    ''', args);
  }

  static Future<int> getSalesHistoryCount({
    int? storeId,
    int? customerId,
    int? year,
    int? month,
    int? day,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (storeId != null) {
      conditions.add('sa.store_id = ?');
      args.add(storeId);
    }
    if (customerId != null) {
      conditions.add('sa.client_id = ?');
      args.add(customerId);
    }
    if (year != null) {
      conditions.add("strftime('%Y', sa.date) = ?");
      args.add(year.toString().padLeft(4, '0'));
    }
    if (month != null) {
      conditions.add("strftime('%m', sa.date) = ?");
      args.add(month.toString().padLeft(2, '0'));
    }
    if (day != null) {
      conditions.add("strftime('%d', sa.date) = ?");
      args.add(day.toString().padLeft(2, '0'));
    }

    final whereClause = conditions.isEmpty
        ? ''
        : 'WHERE ${conditions.join(' AND ')}';
    final result = await db.rawQuery('''
      SELECT COUNT(*) as cnt FROM sales sa
      INNER JOIN stores st ON st.id = sa.store_id
      LEFT JOIN clients c ON c.id = sa.client_id
      $whereClause
    ''', args);
    return (result.first['cnt'] as num?)?.toInt() ?? 0;
  }

  static Future<List<Map<String, dynamic>>> getSaleItems(int saleId) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT si.id, p.name AS product_name, si.quantity, si.price
      FROM sale_items si
      INNER JOIN products p ON p.id = si.product_id
      WHERE si.sale_id = ?
      ORDER BY si.id ASC
      ''',
      [saleId],
    );
  }

  static Future<List<Map<String, dynamic>>> getPurchaseHistory({
    int? storeId,
    int? supplierId,
    String? category,
    DateTime? date,
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <dynamic>[];

    if (storeId != null) {
      conditions.add('pu.store_id = ?');
      args.add(storeId);
    }
    if (supplierId != null) {
      conditions.add('pu.supplier_id = ?');
      args.add(supplierId);
    }
    if (category != null && category.trim().isNotEmpty) {
      conditions.add('''EXISTS (
        SELECT 1
        FROM purchase_items pi_filter
        INNER JOIN products p_filter
          ON p_filter.id = pi_filter.product_id
        LEFT JOIN categories c_filter
          ON c_filter.id = p_filter.category_id
        WHERE pi_filter.purchase_id = pu.id
          AND COALESCE(c_filter.name, '') LIKE ?
      )''');
      args.add('%${category.trim()}%');
    }
    if (date != null) {
      conditions.add('pu.date LIKE ?');
      args.add('${date.toIso8601String().split('T').first}%');
    }
    if (fromDate != null) {
      conditions.add('pu.date >= ?');
      args.add(fromDate.toIso8601String());
    }
    if (toDate != null) {
      conditions.add('pu.date < ?');
      args.add(toDate.toIso8601String());
    }

    final whereClause = conditions.isEmpty
        ? ''
        : 'WHERE ${conditions.join(' AND ')}';

    return db.rawQuery('''
            SELECT pu.id, pu.date, pu.total,
              pu.invoice_number, pu.payment_method,
             st.name AS store_name,
             COALESCE(sp.name, 'Sin proveedor') AS supplier_name
      FROM purchases pu
      INNER JOIN stores st ON st.id = pu.store_id
      LEFT JOIN suppliers sp ON sp.id = pu.supplier_id
      $whereClause
      ORDER BY pu.date DESC, pu.id DESC
      ''', args);
  }

  static Future<List<Map<String, dynamic>>> getPurchaseItems(
    int purchaseId,
  ) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT pi.id, p.name AS product_name, pi.quantity, pi.cost
      FROM purchase_items pi
      INNER JOIN products p ON p.id = pi.product_id
      WHERE pi.purchase_id = ?
      ORDER BY pi.id ASC
      ''',
      [purchaseId],
    );
  }

  static Future<Map<String, dynamic>> getReportsSnapshot({
    DateTime? fromDate,
    DateTime? toDate,
  }) async {
    final db = await database;
    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final from = fromDate != null
        ? DateTime(fromDate.year, fromDate.month, fromDate.day)
        : dayStart;
    final to = toDate != null
        ? DateTime(toDate.year, toDate.month, toDate.day, 23, 59, 59, 999)
        : DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    final salesArgs = <dynamic>[];
    String salesWhere = 'WHERE 1 = 1';
    if (fromDate != null) {
      salesWhere += ' AND date >= ?';
      salesArgs.add(from.toIso8601String());
    }
    if (toDate != null) {
      salesWhere += ' AND date <= ?';
      salesArgs.add(to.toIso8601String());
    }

    final salesToday = await db.rawQuery(
      'SELECT COUNT(*) AS sales_count, COALESCE(SUM(total), 0) AS total FROM sales $salesWhere',
      salesArgs,
    );

    final storeArgs = <dynamic>[];
    String storeWhere = '';
    if (fromDate != null) {
      storeWhere += 'sa.date >= ?';
      storeArgs.add(from.toIso8601String());
    }
    if (toDate != null) {
      if (storeWhere.isNotEmpty) {
        storeWhere += ' AND ';
      }
      storeWhere += 'sa.date <= ?';
      storeArgs.add(to.toIso8601String());
    }

    final salesByStore = await db.rawQuery('''
      SELECT st.name, COUNT(sa.id) AS sales_count, COALESCE(SUM(sa.total), 0) AS total
      FROM stores st
      LEFT JOIN sales sa ON sa.store_id = st.id ${storeWhere.isEmpty ? '' : 'AND $storeWhere'}
      GROUP BY st.id, st.name
      ORDER BY total DESC, st.name ASC
    ''', storeArgs);

    final productArgs = <dynamic>[];
    String productWhere = '';
    if (fromDate != null) {
      productWhere += 's.date >= ?';
      productArgs.add(from.toIso8601String());
    }
    if (toDate != null) {
      if (productWhere.isNotEmpty) {
        productWhere += ' AND ';
      }
      productWhere += 's.date <= ?';
      productArgs.add(to.toIso8601String());
    }

    final topProducts = await db.rawQuery('''
      SELECT p.name, COALESCE(SUM(si.quantity), 0) AS units, COALESCE(SUM(si.quantity * si.price), 0) AS revenue
      FROM sale_items si
      INNER JOIN products p ON p.id = si.product_id
      INNER JOIN sales s ON s.id = si.sale_id
      ${productWhere.isEmpty ? '' : 'WHERE $productWhere'}
      GROUP BY p.id, p.name
      ORDER BY units DESC, revenue DESC
      LIMIT 10
    ''', productArgs);

    return {
      'salesToday': salesToday.isNotEmpty
          ? salesToday.first
          : {'sales_count': 0, 'total': 0},
      'salesByStore': salesByStore,
      'topProducts': topProducts,
    };
  }

  static bool get isOpen => _database != null && _database!.isOpen;

  static Future<void> closeDatabase() async => close();

  static Future<int> insertAuditLog(Map<String, dynamic> values) async {
    final db = await database;
    return db.insert('audit_logs', values);
  }

  static Future<List<Map<String, dynamic>>> getAuditLogs({
    String? search,
    String? userId,
    String? action,
    String? module,
    String? entity,
    DateTime? from,
    DateTime? to,
    bool? success,
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await database;
    final conditions = <String>[];
    final args = <Object?>[];

    void add(String condition, Object? value) {
      conditions.add(condition);
      args.add(value);
    }

    if (search?.trim().isNotEmpty == true) {
      final value = '%${search!.trim()}%';
      conditions.add(
        '(user_name LIKE ? OR user_email LIKE ? OR action LIKE ? OR module LIKE ? OR entity LIKE ? OR description LIKE ?)',
      );
      args.addAll([value, value, value, value, value, value]);
    }
    if (userId != null) add('user_id = ?', userId);
    if (action != null) add('action = ?', action);
    if (module != null) add('module = ?', module);
    if (entity != null) add('entity = ?', entity);
    if (from != null) add('created_at >= ?', from.toUtc().toIso8601String());
    if (to != null) add('created_at <= ?', to.toUtc().toIso8601String());
    if (success != null) add('success = ?', success ? 1 : 0);

    return db.query(
      'audit_logs',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: args,
      orderBy: 'created_at DESC, id DESC',
      limit: limit,
      offset: offset,
    );
  }

  static Future<List<Map<String, dynamic>>> rawQuery(
    String sql, [
    List<dynamic>? arguments,
  ]) async {
    final db = await database;
    return db.rawQuery(sql, arguments);
  }

  static Future<int> rawInsert(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return db.rawInsert(sql, arguments);
  }

  static Future<int> rawUpdate(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return db.rawUpdate(sql, arguments);
  }

  static Future<int> rawDelete(String sql, [List<dynamic>? arguments]) async {
    final db = await database;
    return db.rawDelete(sql, arguments);
  }

  static Future<T> transaction<T>(
    Future<T> Function(Transaction txn) action,
  ) async {
    final db = await database;
    return db.transaction(action);
  }

  static Future<Map<String, dynamic>> getDatabaseInfo() async {
    try {
      final path = await DatabaseLocationService.getDatabasePath();
      final exists = await DatabaseLocationService.databaseExists(path);
      final size = exists
          ? await DatabaseLocationService.getDatabaseSize(path)
          : 0.0;

      return {
        'path': path,
        'exists': exists,
        'sizeMB': size,
        'systemInfo': DatabaseLocationService.getSystemInfo(),
      };
    } catch (e) {
      return {
        'error': e.toString(),
        'path': 'Error obteniendo ruta',
        'exists': false,
        'sizeMB': 0.0,
      };
    }
  }

  static Future<bool> createManualBackup({String? customName}) async {
    try {
      return await BackupService.createBackup(customName: customName);
    } catch (_) {
      return false;
    }
  }

  static Future<bool> restoreFromBackup(String backupName) async {
    try {
      await closeDatabase();
      final result = await BackupService.restoreFromBackup(backupName);
      if (result) {
        await reopen();
      }
      return result;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // MeTODOS DE PAGO
  // ─────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getPaymentMethods() async {
    final db = await database;
    return db.rawQuery(
      'SELECT id, name, is_cash FROM payment_methods ORDER BY id',
    );
  }

  static Future<String> getNextPurchaseInvoiceNumber() async {
    final db = await database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS total FROM purchases');
    final next = ((rows.first['total'] as num?)?.toInt() ?? 0) + 1;
    return next.toString().padLeft(8, '0');
  }

  // ─────────────────────────────────────────────
  // SESIONES DE CAJA (APERTURA / CIERRE)
  // ─────────────────────────────────────────────

  /// Retorna la sesion activa para el local, o null si está cerrada.
  static Future<Map<String, dynamic>?> getActiveCashSession(int storeId) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT cs.id, cs.store_id, cs.opening_amount, cs.opened_at, cs.status,
             cs.opened_by, cs.opened_by_name,
             st.name AS store_name
      FROM cash_sessions cs
      JOIN stores st ON st.id = cs.store_id
      WHERE cs.store_id = ? AND cs.status = 'open'
      ORDER BY cs.id DESC
      LIMIT 1
      ''',
      [storeId],
    );
    return rows.isEmpty ? null : rows.first;
  }

  /// Abre una nueva sesion de caja.
  static Future<int> openCashSession({
    required int storeId,
    required double openingAmount,
    int? openedBy,
    String openedByName = '',
  }) async {
    return transaction((txn) async {
      final existing = await txn.rawQuery(
        "SELECT id FROM cash_sessions WHERE store_id = ? AND status = 'open' LIMIT 1",
        [storeId],
      );
      if (existing.isNotEmpty) {
        throw Exception('Ya hay una caja abierta para este local');
      }

      final sessionId = await txn.rawInsert(
        '''INSERT INTO cash_sessions (store_id, opening_amount, opened_at, status, opened_by, opened_by_name)
           VALUES (?, ?, ?, 'open', ?, ?)''',
        [
          storeId,
          openingAmount,
          DateTime.now().toIso8601String(),
          openedBy,
          openedByName,
        ],
      );

      // Registrar apertura como movimiento de ingreso
      await txn.rawInsert(
        '''INSERT INTO cash_movements (session_id, type, amount, method, description, created_at)
           VALUES (?, 'income', ?, 'Efectivo', 'Apertura de caja', ?)''',
        [sessionId, openingAmount, DateTime.now().toIso8601String()],
      );

      return sessionId;
    });
  }

  /// Cierra la sesion de caja activa.
  static Future<void> closeCashSession({
    required int sessionId,
    required double closingAmount,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final updated = await db.rawUpdate(
      '''UPDATE cash_sessions
         SET closing_amount = ?, closed_at = ?, status = 'closed'
         WHERE id = ? AND status = 'open' ''',
      [closingAmount, now, sessionId],
    );
    if (updated == 0) {
      throw Exception('No se encontro una sesion abierta con ese ID');
    }
  }

  // ─────────────────────────────────────────────
  // MOVIMIENTOS DE CAJA
  // ─────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getCashMovements(
    int sessionId,
  ) async {
    final db = await database;
    return db.rawQuery(
      '''SELECT id, type, amount, method, description, created_at
         FROM cash_movements
         WHERE session_id = ?
         ORDER BY id ASC''',
      [sessionId],
    );
  }

  static Future<void> addCashMovement({
    required int sessionId,
    required String type, // 'income' | 'expense'
    required double amount,
    required String method,
    String? description,
  }) async {
    if (amount <= 0) throw Exception('El monto debe ser mayor que cero');
    if (type != 'income' && type != 'expense') {
      throw Exception('Tipo de movimiento inválido');
    }
    final db = await database;
    await db.rawInsert(
      '''INSERT INTO cash_movements (session_id, type, amount, method, description, created_at)
         VALUES (?, ?, ?, ?, ?, ?)''',
      [
        sessionId,
        type,
        amount,
        method,
        description?.trim(),
        DateTime.now().toIso8601String(),
      ],
    );
  }

  /// Resumen financiero de la sesion: ingresos, egresos, saldo esperado.
  static Future<Map<String, dynamic>> getCashSessionSummary(
    int sessionId,
  ) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''SELECT
           COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) AS total_income,
           COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) AS total_expense
         FROM cash_movements
         WHERE session_id = ?''',
      [sessionId],
    );
    final row = rows.first;
    final totalIncome = (row['total_income'] as num).toDouble();
    final totalExpense = (row['total_expense'] as num).toDouble();

    // Desglose por metodo
    final byMethod = await db.rawQuery(
      '''SELECT method,
           COALESCE(SUM(CASE WHEN type = 'income' THEN amount ELSE 0 END), 0) AS income,
           COALESCE(SUM(CASE WHEN type = 'expense' THEN amount ELSE 0 END), 0) AS expense
         FROM cash_movements
         WHERE session_id = ?
         GROUP BY method
         ORDER BY method''',
      [sessionId],
    );

    final balances = await db.rawQuery(
      '''SELECT
           COALESCE(SUM(
             CASE
               WHEN cm.type = 'income' AND COALESCE(pm.is_cash, 0) = 1 THEN cm.amount
               WHEN cm.type = 'expense' AND COALESCE(pm.is_cash, 0) = 1 THEN -cm.amount
               ELSE 0
             END
           ), 0) AS physical_cash,
           COALESCE(SUM(
             CASE
               WHEN cm.type = 'income' AND COALESCE(pm.is_cash, 0) = 0 THEN cm.amount
               WHEN cm.type = 'expense' AND COALESCE(pm.is_cash, 0) = 0 THEN -cm.amount
               ELSE 0
             END
           ), 0) AS virtual_balance
         FROM cash_movements cm
         LEFT JOIN payment_methods pm ON lower(pm.name) = lower(cm.method)
         WHERE cm.session_id = ?''',
      [sessionId],
    );

    final balanceRow = balances.first;

    return {
      'total_income': totalIncome,
      'total_expense': totalExpense,
      'expected_balance': totalIncome - totalExpense,
      'physical_cash': (balanceRow['physical_cash'] as num).toDouble(),
      'virtual_balance': (balanceRow['virtual_balance'] as num).toDouble(),
      'by_method': byMethod,
    };
  }

  // ─────────────────────────────────────────────
  // DENOMINACIONES DE CAJA (billetes / monedas)
  // ─────────────────────────────────────────────

  /// Guarda el desglose de denominaciones para una sesion.
  /// [moment]: 'open' al abrir, 'close' al cerrar.
  static Future<void> saveCashDenominations({
    required int sessionId,
    required List<Map<String, dynamic>>
    entries, // toMap() de cada DenominationEntry
    required String moment,
  }) async {
    final db = await database;
    final batch = db.batch();
    // Elimina registros previos del mismo momento para evitar duplicados
    batch.delete(
      'cash_denominations',
      where: 'session_id = ? AND moment = ?',
      whereArgs: [sessionId, moment],
    );
    for (final e in entries) {
      if ((e['quantity'] as int) > 0) {
        batch.insert('cash_denominations', {
          'session_id': sessionId,
          'value': e['value'],
          'label': e['label'],
          'is_coin': e['is_coin'],
          'quantity': e['quantity'],
          'subtotal': e['subtotal'],
          'moment': moment,
          'created_at': DateTime.now().toIso8601String(),
        });
      }
    }
    await batch.commit(noResult: true);
  }

  /// Recupera el desglose de denominaciones de una sesion y momento.
  static Future<List<Map<String, dynamic>>> getCashDenominations({
    required int sessionId,
    required String moment,
  }) async {
    final db = await database;
    return db.rawQuery(
      '''SELECT value, label, is_coin, quantity, subtotal
         FROM cash_denominations
         WHERE session_id = ? AND moment = ?
         ORDER BY is_coin ASC, value DESC''',
      [sessionId, moment],
    );
  }

  /// Suma total de billetes y monedas guardados para un momento.
  static Future<Map<String, double>> getCashDenominationTotals({
    required int sessionId,
    required String moment,
  }) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''SELECT
           COALESCE(SUM(CASE WHEN is_coin = 0 THEN subtotal ELSE 0 END), 0) AS total_bills,
           COALESCE(SUM(CASE WHEN is_coin = 1 THEN subtotal ELSE 0 END), 0) AS total_coins
         FROM cash_denominations
         WHERE session_id = ? AND moment = ?''',
      [sessionId, moment],
    );
    final row = rows.first;
    return {
      'total_bills': (row['total_bills'] as num).toDouble(),
      'total_coins': (row['total_coins'] as num).toDouble(),
    };
  }

  // ─────────────────────────────────────────────
  // HISTORIAL DE SESIONES DE CAJA
  // ─────────────────────────────────────────────

  /// Devuelve sesiones cerradas de un local.
  /// Filtros opcionales (se pasan como strings ya formateados):
  ///   [yearFilter]  → '2026'
  ///   [monthFilter] → '2026-04'
  ///   [weekFilter]  → '2026-15'  (año-semana ISO)
  static Future<List<Map<String, dynamic>>> getCashSessionHistory(
    int storeId, {
    String? yearFilter,
    String? monthFilter,
    String? weekFilter,
  }) async {
    final db = await database;
    String where = "cs.store_id = ? AND cs.status = 'closed'";
    final args = <dynamic>[storeId];

    if (weekFilter != null) {
      where += " AND strftime('%Y-%W', cs.opened_at) = ?";
      args.add(weekFilter);
    } else if (monthFilter != null) {
      where += " AND strftime('%Y-%m', cs.opened_at) = ?";
      args.add(monthFilter);
    } else if (yearFilter != null) {
      where += " AND strftime('%Y', cs.opened_at) = ?";
      args.add(yearFilter);
    }

    return db.rawQuery('''
      SELECT cs.id, cs.opening_amount, cs.closing_amount,
             cs.opened_at, cs.closed_at,
             COALESCE(cs.opened_by_name, '') AS opened_by_name,
             st.name AS store_name,
             COALESCE(SUM(CASE WHEN cm.type = 'income' THEN cm.amount ELSE 0 END), 0) AS total_income,
             COALESCE(SUM(CASE WHEN cm.type = 'expense' THEN cm.amount ELSE 0 END), 0) AS total_expense
      FROM cash_sessions cs
      JOIN stores st ON st.id = cs.store_id
      LEFT JOIN cash_movements cm ON cm.session_id = cs.id
      WHERE $where
      GROUP BY cs.id
      ORDER BY cs.opened_at DESC
      ''', args);
  }

  /// Devuelve los años distintos en que hubo sesiones cerradas para un local.
  static Future<List<String>> getCashSessionYears(int storeId) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''SELECT DISTINCT strftime('%Y', opened_at) AS year
         FROM cash_sessions
         WHERE store_id = ? AND status = 'closed'
         ORDER BY year DESC''',
      [storeId],
    );
    return rows.map((r) => r['year'] as String).toList();
  }

  // ─────────────────────────────────────────────
  // VENTA CON MuLTIPLES MeTODOS DE PAGO
  // ─────────────────────────────────────────────

  /// Registra una venta y sus pagos. Si se proporciona [sessionId],
  /// tambien genera movimientos en caja por cada metodo de pago.
  static Future<int> registerSaleWithPayments({
    required int storeId,
    required List<Map<String, dynamic>> items,
    required List<Map<String, dynamic>> payments,
    // [{method_id: int, method_name: String, amount: double}]
    int? clientId,
    int? sessionId,
    bool isCredit = false,
  }) async {
    if (items.isEmpty) {
      throw Exception('La venta debe contener al menos un producto');
    }
    if (payments.isEmpty) {
      throw Exception('Debes indicar al menos un metodo de pago');
    }

    return transaction((txn) async {
      double total = 0;

      for (final item in items) {
        final productId = item['product_id'] as int;
        final quantity = (item['quantity'] as num).toInt();
        final price = (item['price'] as num).toDouble();

        if (quantity <= 0) {
          throw Exception('La cantidad debe ser mayor que cero');
        }

        final stockRows = await txn.rawQuery(
          'SELECT stock FROM inventory WHERE product_id = ? AND store_id = ? LIMIT 1',
          [productId, storeId],
        );
        final available = stockRows.isEmpty
            ? 0
            : (stockRows.first['stock'] as num).toInt();
        if (available < quantity) {
          throw Exception('Stock insuficiente para completar la venta');
        }

        total += quantity * price;
      }

      final saleId = await txn.rawInsert(
        'INSERT INTO sales (store_id, client_id, date, total) VALUES (?, ?, ?, ?)',
        [storeId, clientId, DateTime.now().toIso8601String(), total],
      );

      // Guardar items y reducir stock
      for (final item in items) {
        final productId = item['product_id'] as int;
        final quantity = (item['quantity'] as num).toInt();
        final price = (item['price'] as num).toDouble();

        await txn.rawInsert(
          'INSERT INTO sale_items (sale_id, product_id, quantity, price) VALUES (?, ?, ?, ?)',
          [saleId, productId, quantity, price],
        );
        await txn.rawUpdate(
          'UPDATE inventory SET stock = stock - ? WHERE product_id = ? AND store_id = ?',
          [quantity, productId, storeId],
        );
      }

      // Guardar metodos de pago
      for (final p in payments) {
        final methodId = (p['method_id'] as num).toInt();
        final amount = (p['amount'] as num).toDouble();
        await txn.rawInsert(
          'INSERT INTO sale_payments (sale_id, method_id, amount) VALUES (?, ?, ?)',
          [saleId, methodId, amount],
        );

        // Registrar ingreso en caja si hay sesion activa
        if (sessionId != null) {
          await txn.rawInsert(
            '''INSERT INTO cash_movements (session_id, type, amount, method, description, created_at)
               VALUES (?, 'income', ?, ?, ?, ?)''',
            [
              sessionId,
              amount,
              p['method_name'] ?? 'Efectivo',
              'Venta #$saleId',
              DateTime.now().toIso8601String(),
            ],
          );
        }
      }

      // Venta a credito
      if (isCredit) {
        final paidNow = payments.fold<double>(
          0,
          (s, p) => s + (p['amount'] as num),
        );
        await txn.rawInsert(
          '''INSERT INTO credit_sales (sale_id, total, paid, status)
             VALUES (?, ?, ?, ?)''',
          [saleId, total, paidNow, paidNow >= total ? 'paid' : 'pending'],
        );
      }

      return saleId;
    });
  }

  // ─────────────────────────────────────────────
  // VENTAS A CReDITO / ABONOS
  // ─────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getCreditSalesPending() async {
    final db = await database;
    return db.rawQuery(
      '''SELECT cs.id, cs.sale_id, cs.total, cs.paid, cs.status,
                (cs.total - cs.paid) AS balance,
                sa.date, sa.store_id, c.name AS client_name,
                st.name AS store_name
         FROM credit_sales cs
         JOIN sales sa ON sa.id = cs.sale_id
         LEFT JOIN clients c ON c.id = sa.client_id
         JOIN stores st ON st.id = sa.store_id
         WHERE cs.status = 'pending'
         ORDER BY sa.date DESC''',
    );
  }

  static Future<void> addCreditPayment({
    required int creditSaleId,
    required double amount,
    required int methodId,
    int? sessionId,
    String? methodName,
  }) async {
    if (amount <= 0) throw Exception('El abono debe ser mayor que cero');
    await transaction((txn) async {
      final rows = await txn.rawQuery(
        'SELECT total, paid FROM credit_sales WHERE id = ? LIMIT 1',
        [creditSaleId],
      );
      if (rows.isEmpty) throw Exception('Credito no encontrado');

      final paid = (rows.first['paid'] as num).toDouble();
      final newPaid = paid + amount;

      await txn.rawInsert(
        '''INSERT INTO credit_payments (credit_sale_id, amount, method_id, date)
           VALUES (?, ?, ?, ?)''',
        [creditSaleId, amount, methodId, DateTime.now().toIso8601String()],
      );

      await txn.rawUpdate(
        '''UPDATE credit_sales SET paid = ?,
           status = CASE WHEN ? >= total THEN 'paid' ELSE 'pending' END
           WHERE id = ?''',
        [newPaid, newPaid, creditSaleId],
      );

      if (sessionId != null) {
        await txn.rawInsert(
          '''INSERT INTO cash_movements (session_id, type, amount, method, description, created_at)
             VALUES (?, 'income', ?, ?, 'Abono credito', ?)''',
          [
            sessionId,
            amount,
            methodName ?? 'Efectivo',
            DateTime.now().toIso8601String(),
          ],
        );
      }
    });
  }

  // ─────────────────────────────────────────────
  // ANÁLISIS DE INVENTARIO (FASE 5)
  // ─────────────────────────────────────────────

  /// Obtiene unidades vendidas por producto en un periodo
  static Future<Map<int, int>> getUnitsSoldByProduct({
    required int storeId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      final db = await database;

      String whereClause = 'si.product_id IS NOT NULL AND s.store_id = ?';
      List<dynamic> whereArgs = [storeId];

      if (dateFrom != null) {
        whereClause += ' AND s.date >= ?';
        whereArgs.add(dateFrom.toIso8601String());
      }

      if (dateTo != null) {
        whereClause += ' AND s.date <= ?';
        whereArgs.add(dateTo.toIso8601String());
      }

      final result = await db.rawQuery('''
        SELECT 
          si.product_id,
          SUM(si.quantity) as totalSold
        FROM sale_items si
        JOIN sales s ON si.sale_id = s.id
        WHERE $whereClause
        GROUP BY si.product_id
      ''', whereArgs);

      final Map<int, int> unitsSold = {};
      for (var row in result) {
        final productId = (row['product_id'] as num).toInt();
        final quantity = (row['totalSold'] as num).toInt();
        unitsSold[productId] = quantity;
      }

      return unitsSold;
    } catch (e) {
      return {};
    }
  }

  /// Obtiene TOP N productos más vendidos
  static Future<List<Map<String, dynamic>>> getTopSellingProducts({
    required int storeId,
    int topCount = 5,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      final db = await database;

      String whereClause = 's.store_id = ?';
      List<dynamic> whereArgs = [storeId];

      if (dateFrom != null) {
        whereClause += ' AND s.date >= ?';
        whereArgs.add(dateFrom.toIso8601String());
      }

      if (dateTo != null) {
        whereClause += ' AND s.date <= ?';
        whereArgs.add(dateTo.toIso8601String());
      }

      final result = await db.rawQuery(
        '''
        SELECT
          p.id,
          p.name,
          p.sku,
          SUM(si.quantity) as totalSold,
          AVG(si.price) as avgPrice,
          COUNT(DISTINCT s.id) as saleTimes
        FROM sale_items si
        JOIN products p ON si.product_id = p.id
        JOIN sales s ON si.sale_id = s.id
        WHERE $whereClause
        GROUP BY p.id
        ORDER BY totalSold DESC
        LIMIT ?
      ''',
        [...whereArgs, topCount],
      );

      return result;
    } catch (e) {
      return [];
    }
  }

  /// Obtiene TOP N productos con mejor margen
  static Future<List<Map<String, dynamic>>> getTopMarginProducts({
    required int storeId,
    int topCount = 5,
  }) async {
    try {
      final db = await database;

      final result = await db.rawQuery(
        '''
        SELECT 
          p.id,
          p.name,
          p.sku,
          p.price as sellPrice,
          COALESCE((SELECT cost FROM purchase_items 
                    WHERE product_id = p.id 
                    LIMIT 1), 0) as costPrice,
          (p.price - COALESCE((SELECT cost FROM purchase_items 
                               WHERE product_id = p.id 
                               LIMIT 1), 0)) as marginPerUnit,
          CASE 
            WHEN COALESCE((SELECT cost FROM purchase_items 
                          WHERE product_id = p.id 
                          LIMIT 1), 0) > 0
            THEN ((p.price - COALESCE((SELECT cost FROM purchase_items 
                                      WHERE product_id = p.id 
                                      LIMIT 1), 0)) / 
                  COALESCE((SELECT cost FROM purchase_items 
                           WHERE product_id = p.id 
                           LIMIT 1), 1) * 100)
            ELSE 0 
          END as marginPercent,
          i.stock as quantity
        FROM products p
        LEFT JOIN inventory i ON p.id = i.product_id AND i.store_id = ?
        WHERE i.store_id = ?
        ORDER BY marginPercent DESC
        LIMIT ?
      ''',
        [storeId, storeId, topCount],
      );

      return result;
    } catch (e) {
      return [];
    }
  }

  /// Obtiene informacion de inversion de bodega
  static Future<Map<String, dynamic>> getInventoryInvestmentSummary({
    required int storeId,
  }) async {
    try {
      final db = await database;

      final result = await db.rawQuery(
        '''
        SELECT 
          COUNT(DISTINCT p.id) as totalProducts,
          SUM(i.stock) as totalUnits,
          SUM(i.stock * COALESCE((SELECT cost FROM purchase_items 
                                  WHERE product_id = p.id 
                                  LIMIT 1), 0)) as totalInvested,
          SUM(i.stock * p.price) as totalSellValue,
          AVG(p.price - COALESCE((SELECT cost FROM purchase_items 
                                  WHERE product_id = p.id 
                                  LIMIT 1), 0)) as avgMarginPerUnit,
          COUNT(CASE WHEN i.stock <= 2 THEN 1 END) as lowStockCount
        FROM products p
        LEFT JOIN inventory i ON p.id = i.product_id
        WHERE i.store_id = ?
      ''',
        [storeId],
      );

      if (result.isEmpty) {
        return {
          'totalProducts': 0,
          'totalUnits': 0,
          'totalInvested': 0.0,
          'totalSellValue': 0.0,
          'avgMarginPerUnit': 0.0,
          'lowStockCount': 0,
          'potentialGain': 0.0,
          'potentialROI': 0.0,
        };
      }

      final row = result.first;
      final totalInvested = (row['totalInvested'] as num?)?.toDouble() ?? 0.0;
      final totalSellValue = (row['totalSellValue'] as num?)?.toDouble() ?? 0.0;
      final potentialGain = totalSellValue - totalInvested;
      final potentialROI = totalInvested > 0
          ? (potentialGain / totalInvested) * 100
          : 0.0;

      return {
        'totalProducts': (row['totalProducts'] as num?)?.toInt() ?? 0,
        'totalUnits': (row['totalUnits'] as num?)?.toInt() ?? 0,
        'totalInvested': totalInvested,
        'totalSellValue': totalSellValue,
        'potentialGain': potentialGain,
        'potentialROI': potentialROI,
        'avgMarginPerUnit':
            (row['avgMarginPerUnit'] as num?)?.toDouble() ?? 0.0,
        'lowStockCount': (row['lowStockCount'] as num?)?.toInt() ?? 0,
      };
    } catch (e) {
      return {};
    }
  }

  /// Obtiene tendencia de ventas (ultimos 7 dias)
  static Future<Map<String, double>> getSalesTrendLast7Days({
    required int storeId,
  }) async {
    try {
      final db = await database;
      final Map<String, double> trend = {};

      // Inicializar con los ultimos 7 dias
      for (int i = 6; i >= 0; i--) {
        final date = DateTime.now().subtract(Duration(days: i));
        final dateStr =
            '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        trend[dateStr] = 0.0;
      }

      final result = await db.rawQuery(
        '''
        SELECT 
          DATE(s.date) as saleDate,
          SUM(s.total) as dayTotal
        FROM sales s
        WHERE s.store_id = ?
          AND s.date >= datetime('now', '-7 days')
        GROUP BY DATE(s.date)
        ORDER BY s.date
      ''',
        [storeId],
      );

      // Actualizar trend con datos reales
      for (var row in result) {
        final dateStr = row['saleDate'] as String;
        final dayTotal = (row['dayTotal'] as num).toDouble();
        if (trend.containsKey(dateStr)) {
          trend[dateStr] = dayTotal;
        }
      }

      return trend;
    } catch (e) {
      return {};
    }
  }

  /// Obtiene rotacion promedio de inventario (unidades/dia)
  static Future<double> getAverageInventoryRotation({
    required int storeId,
    int daysToAnalyze = 30,
  }) async {
    try {
      final db = await database;

      final dateFrom = DateTime.now().subtract(Duration(days: daysToAnalyze));

      final result = await db.rawQuery(
        '''
        SELECT SUM(si.quantity) as totalSold
        FROM sale_items si
        JOIN sales s ON si.sale_id = s.id
        WHERE s.store_id = ?
          AND s.date >= ?
      ''',
        [storeId, dateFrom.toIso8601String()],
      );

      if (result.isEmpty || result.first['totalSold'] == null) {
        return 0.0;
      }

      final totalSold = (result.first['totalSold'] as num).toDouble();
      return totalSold / daysToAnalyze;
    } catch (e) {
      return 0.0;
    }
  }

  /// Obtiene productos con inversion critica (bajo stock, alto valor)
  static Future<List<Map<String, dynamic>>> getCriticalInvestmentProducts({
    required int storeId,
    double minInvestmentValue = 500.0,
    int maxStock = 2,
  }) async {
    try {
      final db = await database;

      final result = await db.rawQuery(
        '''
        SELECT 
          p.id,
          p.name,
          p.sku,
          p.price,
          COALESCE((SELECT cost FROM purchase_items 
                    WHERE product_id = p.id 
                    LIMIT 1), 0) as costPrice,
          i.stock,
          (i.stock * COALESCE((SELECT cost FROM purchase_items 
                              WHERE product_id = p.id 
                              LIMIT 1), 0)) as investmentValue
        FROM products p
        JOIN inventory i ON p.id = i.product_id
        WHERE i.store_id = ?
          AND i.stock <= ?
          AND (i.stock * COALESCE((SELECT cost FROM purchase_items 
                                  WHERE product_id = p.id 
                                  LIMIT 1), 0)) >= ?
        ORDER BY investmentValue DESC
      ''',
        [storeId, maxStock, minInvestmentValue],
      );

      return result;
    } catch (e) {
      return [];
    }
  }

  /// Obtiene reporte completo de análisis de inventario
  static Future<Map<String, dynamic>> getInventoryAnalysisReport({
    required int storeId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    try {
      final now = DateTime.now();
      final from = dateFrom ?? DateTime(now.year, now.month, 1);
      final to = dateTo ?? now;

      // Obtener todos los datos en paralelo
      final unitsSoldData = await getUnitsSoldByProduct(
        storeId: storeId,
        dateFrom: from,
        dateTo: to,
      );

      final topSellers = await getTopSellingProducts(
        storeId: storeId,
        topCount: 10,
        dateFrom: from,
        dateTo: to,
      );

      final topMargin = await getTopMarginProducts(
        storeId: storeId,
        topCount: 10,
      );

      final investment = await getInventoryInvestmentSummary(storeId: storeId);

      final trend = await getSalesTrendLast7Days(storeId: storeId);

      final rotation = await getAverageInventoryRotation(
        storeId: storeId,
        daysToAnalyze: 30,
      );

      final critical = await getCriticalInvestmentProducts(storeId: storeId);

      // Calcular metricas adicionales
      final totalSales = topSellers.fold<double>(
        0,
        (sum, item) => sum + ((item['totalSold'] as num?)?.toDouble() ?? 0),
      );

      return {
        'period': {'from': from.toIso8601String(), 'to': to.toIso8601String()},
        'investment': investment,
        'unitsSoldByProduct': unitsSoldData,
        'topSellers': topSellers,
        'topMargin': topMargin,
        'salesTrend': trend,
        'averageRotation': rotation,
        'criticalProducts': critical,
        'totalSalesInPeriod': totalSales,
        'generatedAt': now.toIso8601String(),
      };
    } catch (e) {
      return {};
    }
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Clase auxiliar interna para el catálogo de integridad
// ────────────────────────────────────────────────────────────────────────────
class _CatalogEntry {
  const _CatalogEntry({required this.storeName, required this.categoryName});
  final String storeName;
  final String categoryName;
}
