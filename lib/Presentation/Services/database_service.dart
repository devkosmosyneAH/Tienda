import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'backup_service.dart';
import 'database_location_service.dart';
import '../Utils/supplier_ruc_validator.dart';
import '../Model/purchase_calculation.dart';
import 'session_service.dart';

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

  static const List<String> _storeNames = ['Negocio'];

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

  @visibleForTesting
  static void useDatabaseForTesting(Database testDatabase) {
    _database = testDatabase;
    _dbCompleter = null;
  }

  static Future<Database> _initDatabase() async {
    String path = await DatabaseLocationService.getDatabasePath();

    try {
      await DatabaseLocationService.ensureDatabaseDirectoryExists(path);
    } catch (_) {
      path = await DatabaseLocationService.getFallbackPath();
      await DatabaseLocationService.ensureDatabaseDirectoryExists(path);
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

    // La restauración de fábrica debe pasar por el esquema y los seeds
    // actuales; nunca debe copiar una BD de assets que pueda contener datos
    // históricos o de demostración.
    await close();
    for (final suffix in ['', '-wal', '-shm', '-journal']) {
      final file = File('$path$suffix');
      if (await file.exists()) await file.delete();
    }
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
      CREATE TABLE IF NOT EXISTS local_license_state (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        payload TEXT NOT NULL,
        updated_at TEXT NOT NULL
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
        purchase_vat_type TEXT NOT NULL DEFAULT 'standard',
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
        phone TEXT,
        legal_name TEXT,
        identification_type TEXT,
        identification_number TEXT,
        address TEXT,
        email TEXT,
        payment_condition TEXT NOT NULL DEFAULT 'contado',
        payment_term_days INTEGER NOT NULL DEFAULT 0,
        taxpayer_type TEXT,
        is_withholding_agent INTEGER NOT NULL DEFAULT 0,
        ruc TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        store_id INTEGER NOT NULL,
        supplier_id INTEGER,
        total REAL NOT NULL DEFAULT 0,
        date TEXT NOT NULL,
        invoice_number TEXT,
        access_key TEXT,
        issue_date TEXT,
        payment_condition TEXT NOT NULL DEFAULT 'contado',
        due_date TEXT,
        tax_support_code TEXT,
        physical_total REAL,
        calculated_total REAL,
        status TEXT NOT NULL DEFAULT 'posted',
        cancelled_at TEXT,
        cancellation_reason TEXT,
        retention_income_amount REAL NOT NULL DEFAULT 0,
        retention_vat_amount REAL NOT NULL DEFAULT 0,
        created_by TEXT,
        created_at TEXT,
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
        paid_quantity INTEGER NOT NULL DEFAULT 0,
        bonus_quantity INTEGER NOT NULL DEFAULT 0,
        bonus_vat_amount REAL NOT NULL DEFAULT 0,
        invoice_unit_cost REAL NOT NULL DEFAULT 0,
        discount REAL NOT NULL DEFAULT 0,
        vat_type TEXT NOT NULL DEFAULT 'standard',
        vat_rate REAL NOT NULL DEFAULT 0,
        vat_amount REAL NOT NULL DEFAULT 0,
        line_subtotal REAL NOT NULL DEFAULT 0,
        line_total REAL NOT NULL DEFAULT 0,
        created_by TEXT,
        FOREIGN KEY (purchase_id) REFERENCES purchases(id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS accounts_payable (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_id INTEGER NOT NULL UNIQUE,
        supplier_id INTEGER NOT NULL,
        invoice_total REAL NOT NULL,
        withheld_total REAL NOT NULL DEFAULT 0,
        amount_paid REAL NOT NULL DEFAULT 0,
        balance REAL NOT NULL DEFAULT 0,
        due_date TEXT,
        status TEXT NOT NULL DEFAULT 'open',
        created_at TEXT NOT NULL,
        FOREIGN KEY (purchase_id) REFERENCES purchases(id),
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS accounts_payable_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        payable_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        payment_method TEXT NOT NULL,
        reference TEXT,
        created_at TEXT NOT NULL,
        created_by TEXT,
        FOREIGN KEY (payable_id) REFERENCES accounts_payable(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS accounting_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source_type TEXT NOT NULL,
        source_id INTEGER NOT NULL,
        reversal_of INTEGER,
        entry_date TEXT NOT NULL,
        description TEXT NOT NULL,
        total_debit REAL NOT NULL,
        total_credit REAL NOT NULL,
        created_by TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (reversal_of) REFERENCES accounting_entries(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS accounting_entry_lines (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entry_id INTEGER NOT NULL,
        account_code TEXT NOT NULL,
        account_name TEXT NOT NULL,
        debit REAL NOT NULL DEFAULT 0,
        credit REAL NOT NULL DEFAULT 0,
        memo TEXT,
        FOREIGN KEY (entry_id) REFERENCES accounting_entries(id) ON DELETE CASCADE
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_withholding_vouchers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_id INTEGER NOT NULL UNIQUE,
        supplier_id INTEGER NOT NULL,
        authorization_number TEXT,
        issue_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        created_by TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (purchase_id) REFERENCES purchases(id),
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_withholdings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        voucher_id INTEGER NOT NULL,
        tax_type TEXT NOT NULL,
        code TEXT NOT NULL,
        taxable_base REAL NOT NULL,
        rate REAL NOT NULL,
        amount REAL NOT NULL,
        FOREIGN KEY (voucher_id) REFERENCES purchase_withholding_vouchers(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_adjustment_documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_id INTEGER NOT NULL,
        document_type TEXT NOT NULL,
        document_number TEXT NOT NULL,
        access_key TEXT NOT NULL,
        issue_date TEXT NOT NULL,
        reason TEXT NOT NULL,
        amount REAL NOT NULL,
        status TEXT NOT NULL DEFAULT 'posted',
        created_by TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (purchase_id) REFERENCES purchases(id)
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS purchase_financial_movements (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_id INTEGER NOT NULL,
        store_id INTEGER NOT NULL,
        direction TEXT NOT NULL,
        payment_method TEXT NOT NULL,
        amount REAL NOT NULL,
        reference TEXT,
        created_at TEXT NOT NULL,
        created_by TEXT,
        FOREIGN KEY (purchase_id) REFERENCES purchases(id),
        FOREIGN KEY (store_id) REFERENCES stores(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        store_id INTEGER NOT NULL,
        client_id INTEGER,
        date TEXT NOT NULL,
        total REAL NOT NULL DEFAULT 0,
        electronic_invoice_id INTEGER,
        sri_status TEXT,
        FOREIGN KEY (store_id) REFERENCES stores(id),
        FOREIGN KEY (client_id) REFERENCES clients(id)
      )
    ''');

    await _ensureColumn(
      db,
      table: 'sales',
      column: 'electronic_invoice_id',
      definition: 'INTEGER',
    );
    await _ensureColumn(
      db,
      table: 'sales',
      column: 'sri_status',
      definition: 'TEXT',
    );

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sri_store_config (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        store_id INTEGER NOT NULL UNIQUE,
        sri_enabled INTEGER NOT NULL DEFAULT 0,
        auto_emit_on_checkout INTEGER NOT NULL DEFAULT 0,
        ambiente INTEGER NOT NULL DEFAULT 1,
        ruc TEXT,
        razon_social TEXT,
        nombre_comercial TEXT,
        direccion_matriz TEXT,
        codigo_establecimiento TEXT DEFAULT '001',
        punto_emision TEXT DEFAULT '001',
        tipo_emision TEXT DEFAULT 'NORMAL',
        path_p12 TEXT,
        p12_password TEXT,
        factura_tipo TEXT DEFAULT '01',
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (store_id) REFERENCES stores(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS sri_sequences (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        store_id INTEGER NOT NULL,
        cod_doc TEXT NOT NULL DEFAULT '01',
        estab TEXT NOT NULL DEFAULT '001',
        pto_emi TEXT NOT NULL DEFAULT '001',
        current_value INTEGER NOT NULL DEFAULT 1,
        updated_at TEXT NOT NULL,
        UNIQUE(store_id, cod_doc, estab, pto_emi),
        FOREIGN KEY (store_id) REFERENCES stores(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS electronic_invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        store_id INTEGER NOT NULL,
        sale_id INTEGER NOT NULL,
        client_id INTEGER,
        document_code TEXT NOT NULL DEFAULT '01',
        clave_acceso TEXT,
        estado TEXT NOT NULL DEFAULT 'PENDIENTE',
        ambiente INTEGER NOT NULL DEFAULT 1,
        xml TEXT,
        authorization_number TEXT,
        error_message TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (store_id) REFERENCES stores(id),
        FOREIGN KEY (sale_id) REFERENCES sales(id),
        FOREIGN KEY (client_id) REFERENCES clients(id)
      )
    ''');

    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sri_config_store ON sri_store_config(store_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_electronic_invoices_store_estado ON electronic_invoices(store_id, estado)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sri_sequences_store ON sri_sequences(store_id, cod_doc, estab, pto_emi)',
    );

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
    await _ensureColumn(
      db,
      table: 'inventory_movements',
      column: 'movement_type',
      definition: "TEXT NOT NULL DEFAULT 'transfer'",
    );
    await _ensureColumn(
      db,
      table: 'inventory_movements',
      column: 'reference_id',
      definition: 'INTEGER',
    );

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
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchases_store_date ON purchases(store_id, date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchases_supplier_date ON purchases(supplier_id, date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchases_invoice_number ON purchases(invoice_number)',
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
    await _ensureColumn(
      db,
      table: 'suppliers',
      column: 'ruc',
      definition: 'TEXT',
    );
    for (final entry in <String, String>{
      'legal_name': 'TEXT',
      'identification_type': 'TEXT',
      'identification_number': 'TEXT',
      'address': 'TEXT',
      'payment_condition': "TEXT NOT NULL DEFAULT 'contado'",
      'payment_term_days': 'INTEGER NOT NULL DEFAULT 0',
      'taxpayer_type': 'TEXT',
      'is_withholding_agent': 'INTEGER NOT NULL DEFAULT 0',
    }.entries) {
      await _ensureColumn(
        db,
        table: 'suppliers',
        column: entry.key,
        definition: entry.value,
      );
    }
    await db.rawUpdate('''
      UPDATE suppliers
      SET identification_type = COALESCE(identification_type, 'ruc'),
          identification_number = COALESCE(identification_number, ruc),
          legal_name = COALESCE(legal_name, name)
      WHERE identification_number IS NULL OR legal_name IS NULL
    ''');
    await _ensureColumn(
      db,
      table: 'products',
      column: 'purchase_vat_type',
      definition: "TEXT NOT NULL DEFAULT 'standard'",
    );

    for (final entry in <String, String>{
      'access_key': 'TEXT',
      'issue_date': 'TEXT',
      'payment_condition': "TEXT NOT NULL DEFAULT 'contado'",
      'due_date': 'TEXT',
      'tax_support_code': 'TEXT',
      'physical_total': 'REAL',
      'calculated_total': 'REAL',
      'status': "TEXT NOT NULL DEFAULT 'posted'",
      'cancelled_at': 'TEXT',
      'cancellation_reason': 'TEXT',
      'retention_income_amount': 'REAL NOT NULL DEFAULT 0',
      'retention_vat_amount': 'REAL NOT NULL DEFAULT 0',
      'created_by': 'TEXT',
      'created_at': 'TEXT',
    }.entries) {
      await _ensureColumn(
        db,
        table: 'purchases',
        column: entry.key,
        definition: entry.value,
      );
    }
    for (final entry in <String, String>{
      'paid_quantity': 'INTEGER NOT NULL DEFAULT 0',
      'bonus_quantity': 'INTEGER NOT NULL DEFAULT 0',
      'bonus_vat_amount': 'REAL NOT NULL DEFAULT 0',
      'invoice_unit_cost': 'REAL NOT NULL DEFAULT 0',
      'discount': 'REAL NOT NULL DEFAULT 0',
      'vat_type': "TEXT NOT NULL DEFAULT 'standard'",
      'vat_rate': 'REAL NOT NULL DEFAULT 0',
      'vat_amount': 'REAL NOT NULL DEFAULT 0',
      'line_subtotal': 'REAL NOT NULL DEFAULT 0',
      'line_total': 'REAL NOT NULL DEFAULT 0',
      'created_by': 'TEXT',
    }.entries) {
      await _ensureColumn(
        db,
        table: 'purchase_items',
        column: entry.key,
        definition: entry.value,
      );
    }
    for (final entry in <String, String>{
      'unit_cost': 'REAL NOT NULL DEFAULT 0',
      'total_value': 'REAL NOT NULL DEFAULT 0',
      'created_by': 'TEXT',
    }.entries) {
      await _ensureColumn(
        db,
        table: 'inventory_movements',
        column: entry.key,
        definition: entry.value,
      );
    }
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_accounts_payable_supplier_status ON accounts_payable(supplier_id, status, due_date)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_purchase_adjustments_purchase ON purchase_adjustment_documents(purchase_id, issue_date)',
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

    // Una instalación nueva empieza únicamente con el local y las categorías
    // mínimas. Los productos se crean desde el flujo de productos/compras.

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
    String? ruc,
  }) async {
    final name = _cleanName(supplierName ?? '');
    if (name.isEmpty) return null;

    final cleanPhone = phone?.trim();
    final cleanRuc = ruc?.trim();
    final rucError = SupplierRucValidator.validate(cleanRuc);
    if (rucError != null) throw Exception(rucError);

    final existingName = await db.rawQuery(
      'SELECT id, ruc FROM suppliers WHERE lower(trim(name)) = lower(trim(?)) LIMIT 1',
      [name],
    );
    if (existingName.isNotEmpty) {
      final existingId = (existingName.first['id'] as num).toInt();
      final existingRuc = existingName.first['ruc']?.toString().trim();
      if (cleanRuc?.isNotEmpty == true) {
        final duplicateRuc = await db.rawQuery(
          'SELECT id FROM suppliers WHERE trim(ruc) = trim(?) AND id <> ? LIMIT 1',
          [cleanRuc, existingId],
        );
        if (duplicateRuc.isNotEmpty) {
          throw Exception('El RUC ya está registrado en otro proveedor.');
        }
      }
      if (cleanRuc?.isNotEmpty == true &&
          existingRuc?.isNotEmpty == true &&
          existingRuc != cleanRuc) {
        throw Exception('El proveedor ya existe con otro RUC.');
      }
      if (cleanPhone?.isNotEmpty == true) {
        await db.rawUpdate('UPDATE suppliers SET phone = ? WHERE id = ?', [
          cleanPhone,
          existingId,
        ]);
      }
      if (cleanRuc?.isNotEmpty == true && existingRuc?.isNotEmpty != true) {
        await db.rawUpdate('UPDATE suppliers SET ruc = ? WHERE id = ?', [
          cleanRuc,
          existingId,
        ]);
      }
      return existingId;
    }

    if (cleanRuc?.isNotEmpty == true) {
      final existingRuc = await db.rawQuery(
        'SELECT id FROM suppliers WHERE trim(ruc) = trim(?) LIMIT 1',
        [cleanRuc],
      );
      if (existingRuc.isNotEmpty) {
        return (existingRuc.first['id'] as num).toInt();
      }
    }

    await db.rawInsert(
      'INSERT OR IGNORE INTO suppliers (name, phone, ruc) VALUES (?, ?, ?)',
      [
        name,
        cleanPhone?.isEmpty == true ? null : cleanPhone,
        cleanRuc?.isEmpty == true ? null : cleanRuc,
      ],
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

  static Future<int> _requireSupplier(
    DatabaseExecutor db,
    int supplierId,
  ) async {
    final rows = await db.rawQuery(
      'SELECT id FROM suppliers WHERE id = ? LIMIT 1',
      [supplierId],
    );
    if (rows.isEmpty) throw Exception('El proveedor seleccionado ya no existe');
    return (rows.first['id'] as num).toInt();
  }

  static String? _nullableTrim(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
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
    if (cleanName.isEmpty) {
      throw Exception('El nombre de la categoría es obligatorio.');
    }
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
    if (cleanName.isEmpty) {
      throw Exception('El nombre de la categoría es obligatorio.');
    }
    await db.rawUpdate(
      'UPDATE categories SET name = ?, slug = ?, store_id = ?, image_url = ? WHERE id = ?',
      [
        cleanName,
        _buildCategorySlug(cleanName),
        storeId,
        imageUrl.trim(),
        categoryId,
      ],
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
      throw Exception(
        'No puedes eliminar esta categoría porque tiene $total producto(s) asociado(s).',
      );
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
        p.purchase_vat_type,
        p.profit_iva,
        p.images,
        p.store_id,
        COALESCE(c.name, 'Sin categoria') AS category,
        COALESCE(st.name, '') AS store_name,
        COALESCE(SUM(i.stock), 0) AS total_stock,
        COALESCE(MAX(CASE WHEN i.store_id = (SELECT MIN(id) FROM stores) THEN i.stock END), 0) AS stock_store_1,
        COALESCE(MAX(CASE WHEN i.store_id = (SELECT MAX(id) FROM stores) THEN i.stock END), 0) AS stock_store_2
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

  static Future<int> createProduct({
    required String name,
    double price = 0,
    double costPrice = 0,
    double ivaRate = 0,
    String purchaseVatType = 'standard',
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

    final productId = await transaction((txn) async {
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
        'INSERT INTO products (uid, name, sku, aux_code, description, tags, category_id, store_id, price, cost_price, iva_rate, purchase_vat_type, profit_iva, images, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
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
          purchaseVatType,
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
      return productId;
    });
    notifyDatabaseChanged();
    return productId;
  }

  static Future<int> createStore(String name) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw Exception('El nombre del local es obligatorio');
    }
    final id = await rawInsert('INSERT INTO stores (name) VALUES (?)', [
      cleanName,
    ]);
    notifyDatabaseChanged();
    return id;
  }

  static Future<void> updateInventoryStock({
    required int productId,
    required int storeId,
    required int stock,
  }) async {
    final safeStock = max(0, stock);
    final now = DateTime.now().toIso8601String();
    final actor = await SessionService.getCurrentUserId();

    await transaction((txn) async {
      await txn.rawInsert(
        'INSERT OR IGNORE INTO inventory (product_id, store_id, stock) VALUES (?, ?, 0)',
        [productId, storeId],
      );

      final currentRows = await txn.rawQuery(
        'SELECT stock FROM inventory WHERE product_id = ? AND store_id = ? LIMIT 1',
        [productId, storeId],
      );
      final currentStock = (currentRows.first['stock'] as num).toInt();
      final delta = safeStock - currentStock;
      await txn.rawUpdate(
        'UPDATE inventory SET stock = ? WHERE product_id = ? AND store_id = ?',
        [safeStock, productId, storeId],
      );
      if (delta != 0) {
        final productRows = await txn.rawQuery(
          'SELECT cost_price FROM products WHERE id = ? LIMIT 1',
          [productId],
        );
        final cost = productRows.isEmpty
            ? 0.0
            : (productRows.first['cost_price'] as num).toDouble();
        await txn.rawInsert(
          '''INSERT INTO inventory_movements (
               product_id, from_store_id, to_store_id, quantity, date,
               movement_type, unit_cost, total_value, created_by
             ) VALUES (?, ?, ?, ?, ?, 'adjustment', ?, ?, ?)''',
          [
            productId,
            storeId,
            storeId,
            delta,
            now,
            cost,
            PurchaseTotals.money(delta.abs() * cost),
            actor,
          ],
        );
      }
    });
    notifyDatabaseChanged();
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

    final now = DateTime.now().toIso8601String();
    final actor = await SessionService.getCurrentUserId();
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

      final productRows = await txn.rawQuery(
        'SELECT cost_price FROM products WHERE id = ? LIMIT 1',
        [productId],
      );
      final cost = productRows.isEmpty
          ? 0.0
          : (productRows.first['cost_price'] as num).toDouble();
      await txn.rawInsert(
        '''INSERT INTO inventory_movements (
             product_id, from_store_id, to_store_id, quantity, date,
             movement_type, unit_cost, total_value, created_by
           ) VALUES (?, ?, ?, ?, ?, 'transfer', ?, ?, ?)''',
        [
          productId,
          fromStoreId,
          toStoreId,
          quantity,
          now,
          cost,
          PurchaseTotals.money(quantity * cost),
          actor,
        ],
      );
    });
    notifyDatabaseChanged();
  }

  static Future<int> registerSale({
    required int storeId,
    required List<Map<String, dynamic>> items,
    int? clientId,
  }) async {
    if (items.isEmpty) {
      throw Exception('La venta debe contener al menos un producto');
    }
    final createdBy = await SessionService.getCurrentUserId();
    final now = DateTime.now().toIso8601String();

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
        final productRows = await txn.rawQuery(
          'SELECT cost_price FROM products WHERE id = ? LIMIT 1',
          [productId],
        );
        final unitCost = productRows.isEmpty
            ? 0.0
            : (productRows.first['cost_price'] as num).toDouble();
        await txn.rawInsert(
          '''INSERT INTO inventory_movements (
               product_id, from_store_id, to_store_id, quantity, date,
               movement_type, reference_id, unit_cost, total_value, created_by
             ) VALUES (?, ?, ?, ?, ?, 'sale', ?, ?, ?, ?)''',
          [
            productId,
            storeId,
            storeId,
            -quantity,
            now,
            saleId,
            unitCost,
            PurchaseTotals.money(unitCost * quantity),
            createdBy,
          ],
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
    notifyDatabaseChanged();
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
      SELECT id, name, legal_name, identification_type, identification_number,
             address, phone, ruc, email, notes, payment_condition,
             payment_term_days, taxpayer_type, is_withholding_agent
      FROM suppliers
      WHERE name LIKE ? OR COALESCE(legal_name, '') LIKE ?
        OR COALESCE(phone, '') LIKE ?
        OR COALESCE(identification_number, ruc, '') LIKE ?
      ORDER BY name COLLATE NOCASE
      ''',
      [filter, filter, filter, filter],
    );
  }

  static Future<int> createSupplier({
    required String name,
    String? phone,
    String? email,
    String? notes,
    String? ruc,
    String? identificationType,
    String? identificationNumber,
    String? legalName,
    String? address,
    String paymentCondition = 'contado',
    int paymentTermDays = 0,
    String? taxpayerType,
    bool isWithholdingAgent = false,
  }) async {
    final cleanName = _cleanName(name);
    if (cleanName.isEmpty) {
      throw Exception('El nombre del proveedor es obligatorio');
    }
    final cleanType = (identificationType ?? 'ruc').trim().toLowerCase();
    final cleanIdentification = (identificationNumber ?? ruc)?.trim();
    final identityError = SupplierRucValidator.validateIdentification(
      value: cleanIdentification,
      type: cleanType,
    );
    if (identityError != null) throw Exception(identityError);
    if (paymentTermDays < 0) {
      throw Exception('El plazo de pago no puede ser negativo.');
    }
    final cleanRuc = cleanType == 'ruc' ? cleanIdentification : null;

    return transaction((txn) async {
      final duplicate = await txn.rawQuery(
        '''SELECT id FROM suppliers
           WHERE lower(trim(name)) = lower(trim(?))
              OR trim(COALESCE(identification_number, ruc, '')) = trim(?)
           LIMIT 1''',
        [cleanName, cleanIdentification],
      );
      if (duplicate.isNotEmpty) {
        throw Exception(
          'Ya existe un proveedor con ese nombre o identificación.',
        );
      }

      return txn.rawInsert(
        '''INSERT INTO suppliers (
             name, legal_name, identification_type, identification_number,
             address, phone, email, notes, ruc, payment_condition,
             payment_term_days, taxpayer_type, is_withholding_agent
           ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          cleanName,
          _nullableTrim(legalName) ?? cleanName,
          cleanType,
          cleanIdentification,
          _nullableTrim(address),
          _nullableTrim(phone),
          _nullableTrim(email),
          _nullableTrim(notes),
          cleanRuc?.isEmpty == true ? null : cleanRuc,
          paymentCondition.trim().toLowerCase(),
          paymentTermDays,
          _nullableTrim(taxpayerType),
          isWithholdingAgent ? 1 : 0,
        ],
      );
    });
  }

  static Future<void> updateSupplier({
    required int id,
    required String name,
    String? phone,
    String? email,
    String? notes,
    String? ruc,
    String? identificationType,
    String? identificationNumber,
    String? legalName,
    String? address,
    String paymentCondition = 'contado',
    int paymentTermDays = 0,
    String? taxpayerType,
    bool isWithholdingAgent = false,
  }) async {
    final cleanName = _cleanName(name);
    if (cleanName.isEmpty) {
      throw Exception('El nombre del proveedor es obligatorio');
    }
    final cleanType = (identificationType ?? 'ruc').trim().toLowerCase();
    final cleanIdentification = (identificationNumber ?? ruc)?.trim();
    final identityError = SupplierRucValidator.validateIdentification(
      value: cleanIdentification,
      type: cleanType,
    );
    if (identityError != null) throw Exception(identityError);
    if (paymentTermDays < 0) {
      throw Exception('El plazo de pago no puede ser negativo.');
    }
    final cleanRuc = cleanType == 'ruc' ? cleanIdentification : null;

    await transaction((txn) async {
      final duplicate = await txn.rawQuery(
        '''SELECT id FROM suppliers
           WHERE id <> ? AND (
             lower(trim(name)) = lower(trim(?)) OR
               trim(COALESCE(identification_number, ruc, '')) = trim(?)
           ) LIMIT 1''',
        [id, cleanName, cleanIdentification],
      );
      if (duplicate.isNotEmpty) {
        throw Exception('Ya existe un proveedor con ese nombre o RUC.');
      }
      final updated = await txn.rawUpdate(
        '''UPDATE suppliers SET name = ?, legal_name = ?, identification_type = ?,
            identification_number = ?, address = ?, phone = ?, email = ?, notes = ?,
            ruc = ?, payment_condition = ?, payment_term_days = ?, taxpayer_type = ?,
            is_withholding_agent = ?
           WHERE id = ?''',
        [
          cleanName,
          _nullableTrim(legalName) ?? cleanName,
          cleanType,
          cleanIdentification,
          _nullableTrim(address),
          _nullableTrim(phone),
          _nullableTrim(email),
          _nullableTrim(notes),
          cleanRuc?.isEmpty == true ? null : cleanRuc,
          paymentCondition.trim().toLowerCase(),
          paymentTermDays,
          _nullableTrim(taxpayerType),
          isWithholdingAgent ? 1 : 0,
          id,
        ],
      );
      if (updated == 0) throw Exception('El proveedor ya no existe');
    });
  }

  static Future<int> registerPurchase({
    required int storeId,
    required List<Map<String, dynamic>> items,
    int? supplierId,
    String? supplierName,
    String? supplierPhone,
    String? supplierRuc,
    double vatRate = 15,
    double discount = 0,
    String? invoiceNumber,
    String? auxiliaryInvoiceNumber,
    String? accessKey,
    DateTime? issueDate,
    String? paymentCondition,
    DateTime? dueDate,
    String? taxSupportCode,
    double? physicalTotal,
    String paymentMethod = 'Efectivo',
    List<Map<String, dynamic>> withholdings = const [],
    String? withholdingAuthorization,
    String? createdBy,
  }) async {
    if (items.isEmpty) {
      throw Exception('Detalle: agregue al menos una línea.');
    }
    final invoice = invoiceNumber?.trim() ?? '';
    if (invoice.isNotEmpty &&
        !RegExp(r'^\d{3}-\d{3}-\d{9}$').hasMatch(invoice)) {
      throw Exception('Número de factura: use el formato 001-001-000000000.');
    }
    final normalizedAccessKey = (accessKey ?? '').trim();
    if (normalizedAccessKey.isNotEmpty) {
      final keyError = SupplierRucValidator.validateAccessKey(
        normalizedAccessKey,
      );
      if (keyError != null) {
        throw Exception('Clave de acceso: $keyError');
      }
    }
    if (issueDate == null) {
      throw Exception('Fecha de emisión: campo obligatorio.');
    }
    final condition = paymentCondition?.trim().toLowerCase() ?? '';
    if (condition != 'contado' &&
        condition != 'credito' &&
        condition != 'crédito') {
      throw Exception('Condición de pago: seleccione contado o crédito.');
    }
    final isCredit = condition == 'credito' || condition == 'crédito';
    if (isCredit && dueDate == null) {
      throw Exception('Fecha de vencimiento: obligatoria para crédito.');
    }
    if (isCredit && dueDate!.isBefore(issueDate)) {
      throw Exception('Fecha de vencimiento: no puede ser anterior a emisión.');
    }
    if (!vatRate.isFinite || vatRate < 0 || vatRate > 100) {
      throw Exception('La tarifa de IVA vigente no es válida.');
    }
    if (!discount.isFinite || discount < 0) {
      throw Exception('El descuento general no es válido.');
    }
    if (physicalTotal == null || !physicalTotal.isFinite || physicalTotal < 0) {
      throw Exception('Total de factura física: campo obligatorio.');
    }

    final lineInputs = <PurchaseLineInput>[];
    for (final item in items) {
      final vatTypeName = item['vat_type']?.toString() ?? 'standard';
      final vatType = PurchaseVatType.values.firstWhere(
        (type) => type.name == vatTypeName,
        orElse: () =>
            throw Exception('Tipo de IVA no reconocido: $vatTypeName'),
      );
      final itemVatRate = (item['vat_rate'] as num?)?.toDouble() ?? vatRate;
      lineInputs.add(
        PurchaseLineInput(
          productId: (item['product_id'] as num?)?.toInt(),
          quantity: (item['quantity'] as num?)?.toInt() ?? 0,
          bonusQuantity: (item['bonus_quantity'] as num?)?.toInt() ?? 0,
          unitCost:
              ((item['unit_cost'] ?? item['cost']) as num?)?.toDouble() ?? 0,
          discount: (item['discount'] as num?)?.toDouble() ?? 0,
          vatType: vatType,
          vatRate: itemVatRate,
          bonusVatAmount: (item['bonus_vat_amount'] as num?)?.toDouble() ?? 0,
        ),
      );
    }
    if (discount > 0) {
      final gross = lineInputs.fold<double>(
        0,
        (sum, line) => sum + line.quantity * line.unitCost,
      );
      if (gross == 0 || discount > gross) {
        throw Exception('El descuento general supera el subtotal.');
      }
      var remainingDiscount = PurchaseTotals.money(discount);
      for (var index = 0; index < lineInputs.length; index++) {
        final line = lineInputs[index];
        final share = index == lineInputs.length - 1
            ? remainingDiscount
            : PurchaseTotals.money(
                discount * line.quantity * line.unitCost / gross,
              );
        remainingDiscount = PurchaseTotals.money(remainingDiscount - share);
        lineInputs[index] = PurchaseLineInput(
          productId: line.productId,
          quantity: line.quantity,
          bonusQuantity: line.bonusQuantity,
          unitCost: line.unitCost,
          discount: PurchaseTotals.money(line.discount + share),
          vatType: line.vatType,
          vatRate: line.vatRate,
          bonusVatAmount: line.bonusVatAmount,
        );
      }
    }
    final totals = PurchaseTotals.calculate(lineInputs);
    if (totals.differsFromInvoice(physicalTotal)) {
      throw Exception(
        'El total calculado (\$${totals.total.toStringAsFixed(2)}) difiere de la factura física (\$${physicalTotal.toStringAsFixed(2)}). Revise cantidades, descuentos e IVA.',
      );
    }

    final now = DateTime.now().toIso8601String();
    final actor = createdBy ?? await SessionService.getCurrentUserId();
    final withholdingsTotal = PurchaseTotals.money(
      withholdings.fold<double>(
        0,
        (sum, withholding) =>
            sum + ((withholding['amount'] as num?)?.toDouble() ?? 0),
      ),
    );
    if (withholdingsTotal > totals.total) {
      throw Exception('Las retenciones superan el total de la factura.');
    }

    return transaction((txn) async {
      final resolvedSupplierId = supplierId == null
          ? await _ensureSupplier(
              txn,
              supplierName,
              phone: supplierPhone,
              ruc: supplierRuc,
            )
          : await _requireSupplier(txn, supplierId);
      if (resolvedSupplierId == null) {
        throw Exception('Proveedor: campo obligatorio.');
      }

      final suppliers = await txn.rawQuery(
        '''SELECT name, identification_type, identification_number, ruc
               FROM suppliers WHERE id = ? LIMIT 1''',
        [resolvedSupplierId],
      );
      if (suppliers.isEmpty) throw Exception('El proveedor ya no existe.');
      final supplier = suppliers.first;
      final supplierIdValue =
          supplier['identification_number']?.toString() ??
          supplier['ruc']?.toString();
      final supplierIdType =
          supplier['identification_type']?.toString() ?? 'ruc';
      if (SupplierRucValidator.validateIdentification(
            value: supplierIdValue,
            type: supplierIdType,
          ) !=
          null) {
        throw Exception(
          'Proveedor: identificación RUC/cédula inválida o faltante.',
        );
      }
      if (normalizedAccessKey.isNotEmpty) {
        final invoiceKeyError =
            SupplierRucValidator.validateAccessKeyForInvoice(
              accessKey: normalizedAccessKey,
              invoiceNumber: invoice,
              issueDate: issueDate,
              supplierRuc: supplierIdType == 'ruc' ? supplierIdValue : null,
            );
        if (invoiceKeyError != null) {
          throw Exception('Clave de acceso: $invoiceKeyError');
        }
      }

      final duplicate = await txn.rawQuery(
        '''SELECT id FROM purchases
               WHERE supplier_id = ? AND invoice_number = ?
               LIMIT 1''',
        [resolvedSupplierId, invoice],
      );
      if (duplicate.isNotEmpty) {
        throw Exception('Número de factura: ya existe para este proveedor.');
      }

      final payableBeforeWithholding = totals.total;
      final payableAmount = PurchaseTotals.money(
        totals.total - withholdingsTotal,
      );
      final purchaseId = await txn.rawInsert(
        '''INSERT INTO purchases (
                 store_id, supplier_id, total, date, invoice_number,
                 auxiliary_invoice_number, payment_method, access_key,
                 issue_date, payment_condition, due_date, tax_support_code,
                 physical_total, calculated_total, status,
                 retention_income_amount, retention_vat_amount, created_by, created_at
               ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'posted', ?, ?, ?, ?)''',
        [
          storeId,
          resolvedSupplierId,
          totals.total,
          issueDate.toIso8601String(),
          invoice,
          auxiliaryInvoiceNumber?.trim(),
          paymentMethod.trim(),
          normalizedAccessKey,
          issueDate.toIso8601String(),
          isCredit ? 'credito' : 'contado',
          dueDate?.toIso8601String(),
          taxSupportCode?.trim() ?? '',
          physicalTotal,
          totals.total,
          withholdings
              .where((line) => line['tax_type'] == 'income')
              .fold<double>(
                0,
                (sum, line) => sum + (line['amount'] as num).toDouble(),
              ),
          withholdings
              .where((line) => line['tax_type'] == 'vat')
              .fold<double>(
                0,
                (sum, line) => sum + (line['amount'] as num).toDouble(),
              ),
          actor,
          now,
        ],
      );

      final productChanges = <int, ({int quantity, double value})>{};
      for (final line in totals.lines) {
        final productId = line.productId;
        if (productId == null) throw Exception('Producto: línea sin producto.');
        final productRows = await txn.rawQuery(
          'SELECT id FROM products WHERE id = ? LIMIT 1',
          [productId],
        );
        if (productRows.isEmpty) {
          throw Exception('El producto $productId no existe.');
        }
        if (line.receivedQuantity <= 0) {
          throw Exception(
            'La cantidad de unidades recibidas debe ser mayor que cero.',
          );
        }
        await txn.rawInsert(
          'INSERT OR IGNORE INTO inventory (product_id, store_id, stock) VALUES (?, ?, 0)',
          [productId, storeId],
        );
        await txn.rawInsert(
          '''INSERT INTO purchase_items (
                   purchase_id, product_id, quantity, cost, paid_quantity,
                   bonus_quantity, bonus_vat_amount, invoice_unit_cost, discount, vat_type,
                   vat_rate, vat_amount, line_subtotal, line_total, created_by
                 ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)''',
          [
            purchaseId,
            productId,
            line.receivedQuantity,
            line.effectiveUnitCost,
            line.quantity,
            line.bonusQuantity,
            line.bonusVatAmount,
            line.unitCost,
            line.discount,
            line.vatType.name,
            line.vatRate,
            line.vatAmount,
            line.taxableBase,
            line.total,
            actor,
          ],
        );
        final previous = productChanges[productId];
        productChanges[productId] = (
          quantity: (previous?.quantity ?? 0) + line.receivedQuantity,
          value: PurchaseTotals.money(
            (previous?.value ?? 0) + line.taxableBase,
          ),
        );
      }

      for (final entry in productChanges.entries) {
        final productId = entry.key;
        final change = entry.value;
        final stockRows = await txn.rawQuery(
          '''SELECT COALESCE(SUM(i.stock), 0) AS stock, p.cost_price FROM products p
             LEFT JOIN inventory i ON i.product_id = p.id
             WHERE p.id = ?
             GROUP BY p.id
             LIMIT 1''',
          [productId],
        );
        final existingQuantity = (stockRows.first['stock'] as num).toInt();
        final existingCost = (stockRows.first['cost_price'] as num).toDouble();
        final newCost = totals.weightedAverageCost(
          existingQuantity: existingQuantity,
          existingUnitCost: existingCost,
          receivedQuantity: change.quantity,
          receivedValue: change.value,
        );
        await txn.rawUpdate(
          'UPDATE inventory SET stock = stock + ? WHERE product_id = ? AND store_id = ?',
          [change.quantity, productId, storeId],
        );
        await txn.rawUpdate('UPDATE products SET cost_price = ? WHERE id = ?', [
          newCost,
          productId,
        ]);
        await txn.rawInsert(
          '''INSERT INTO inventory_movements (
                   product_id, from_store_id, to_store_id, quantity, date,
                   movement_type, reference_id, unit_cost, total_value, created_by
                 ) VALUES (?, ?, ?, ?, ?, 'purchase', ?, ?, ?, ?)''',
          [
            productId,
            storeId,
            storeId,
            change.quantity,
            now,
            purchaseId,
            PurchaseTotals.money(change.value / change.quantity),
            change.value,
            actor,
          ],
        );
      }

      final payableId = await txn.rawInsert(
        '''INSERT INTO accounts_payable (
                 purchase_id, supplier_id, invoice_total, withheld_total,
                 amount_paid, balance, due_date, status, created_at
               ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
        [
          purchaseId,
          resolvedSupplierId,
          payableBeforeWithholding,
          withholdingsTotal,
          isCredit ? 0 : payableAmount,
          isCredit ? payableAmount : 0,
          dueDate?.toIso8601String(),
          isCredit ? (payableAmount == 0 ? 'paid' : 'open') : 'paid',
          now,
        ],
      );

      int? voucherId;
      if (withholdings.isNotEmpty) {
        voucherId = await txn.rawInsert(
          '''INSERT INTO purchase_withholding_vouchers (
                   purchase_id, supplier_id, authorization_number, issue_date,
                   status, created_by, created_at
                 ) VALUES (?, ?, ?, ?, 'pending', ?, ?)''',
          [
            purchaseId,
            resolvedSupplierId,
            withholdingAuthorization?.trim(),
            issueDate.toIso8601String(),
            actor,
            now,
          ],
        );
        for (final withholding in withholdings) {
          final taxType = withholding['tax_type']?.toString() ?? '';
          final code = withholding['code']?.toString().trim() ?? '';
          final base = (withholding['base'] as num?)?.toDouble() ?? -1;
          final rate = (withholding['rate'] as num?)?.toDouble() ?? -1;
          final amount = (withholding['amount'] as num?)?.toDouble() ?? -1;
          if ((taxType != 'income' && taxType != 'vat') ||
              code.isEmpty ||
              base < 0 ||
              rate < 0 ||
              rate > 100 ||
              amount < 0 ||
              !base.isFinite ||
              !rate.isFinite ||
              !amount.isFinite ||
              (PurchaseTotals.money(base * rate / 100) - amount).abs() > 0.01) {
            throw Exception(
              'Retención: código, base, porcentaje o valor inválido.',
            );
          }
          await txn.rawInsert(
            '''INSERT INTO purchase_withholdings
                   (voucher_id, tax_type, code, taxable_base, rate, amount)
                   VALUES (?, ?, ?, ?, ?, ?)''',
            [
              voucherId,
              taxType,
              code,
              base,
              rate,
              PurchaseTotals.money(amount),
            ],
          );
        }
      }

      final debitLines = <Map<String, dynamic>>[
        {
          'account_code': 'ASSET_INVENTORY',
          'account_name': 'Inventario',
          'amount': PurchaseTotals.money(
            totals.lines.fold<double>(0, (sum, line) => sum + line.taxableBase),
          ),
        },
        {
          'account_code': 'ASSET_INPUT_VAT',
          'account_name': 'IVA compras / crédito tributario',
          'amount': totals.vatTotal,
        },
      ];
      final creditLines = <Map<String, dynamic>>[
        if (isCredit)
          {
            'account_code': 'LIABILITY_SUPPLIER_PAYABLE',
            'account_name': 'Cuentas por pagar a proveedores',
            'amount': payableAmount,
          }
        else if (_isCashPayment(paymentMethod))
          {
            'account_code': 'ASSET_CASH',
            'account_name': 'Caja',
            'amount': payableAmount,
          }
        else
          {
            'account_code': 'ASSET_BANK',
            'account_name': 'Bancos - ${paymentMethod.trim()}',
            'amount': payableAmount,
          },
        for (final type in ['income', 'vat'])
          if (withholdings.any((line) => line['tax_type'] == type))
            {
              'account_code': type == 'income'
                  ? 'LIABILITY_INCOME_WITHHOLDING'
                  : 'LIABILITY_VAT_WITHHOLDING',
              'account_name': type == 'income'
                  ? 'Retención en la fuente por pagar'
                  : 'Retención de IVA por pagar',
              'amount': PurchaseTotals.money(
                withholdings
                    .where((line) => line['tax_type'] == type)
                    .fold<double>(
                      0,
                      (sum, line) => sum + (line['amount'] as num).toDouble(),
                    ),
              ),
            },
      ];
      final entryId = await _insertAccountingEntry(
        txn,
        sourceType: 'purchase',
        sourceId: purchaseId,
        entryDate: issueDate,
        description: 'Registro de factura $invoice',
        debitLines: debitLines,
        creditLines: creditLines,
        createdBy: actor,
        createdAt: now,
      );
      if (entryId <= 0) {
        throw Exception('No se pudo generar el asiento contable.');
      }

      if (!isCredit && payableAmount > 0) {
        await txn.rawInsert(
          '''INSERT INTO accounts_payable_payments
                 (payable_id, amount, payment_method, reference, created_at, created_by)
                 VALUES (?, ?, ?, ?, ?, ?)''',
          [
            payableId,
            payableAmount,
            paymentMethod.trim(),
            auxiliaryInvoiceNumber,
            now,
            actor,
          ],
        );
        if (_isCashPayment(paymentMethod)) {
          final sessions = await txn.rawQuery(
            "SELECT id FROM cash_sessions WHERE store_id = ? AND status = 'open' ORDER BY id DESC LIMIT 1",
            [storeId],
          );
          if (sessions.isEmpty) {
            throw Exception(
              'Para pagar en efectivo debe existir una caja abierta.',
            );
          }
          await txn.rawInsert(
            '''INSERT INTO cash_movements
                   (session_id, type, amount, method, description, created_at)
                   VALUES (?, 'expense', ?, ?, ?, ?)''',
            [
              sessions.first['id'],
              payableAmount,
              paymentMethod.trim(),
              'Pago compra $invoice',
              now,
            ],
          );
        } else {
          await txn.rawInsert(
            '''INSERT INTO purchase_financial_movements
                   (purchase_id, store_id, direction, payment_method, amount, reference, created_at, created_by)
                   VALUES (?, ?, 'outflow', ?, ?, ?, ?, ?)''',
            [
              purchaseId,
              storeId,
              paymentMethod.trim(),
              payableAmount,
              auxiliaryInvoiceNumber,
              now,
              actor,
            ],
          );
        }
      }

      return purchaseId;
    });
  }

  static Future<void> cancelPurchase({
    required int purchaseId,
    required String creditNoteNumber,
    required String accessKey,
    required DateTime issueDate,
    required String reason,
    String? createdBy,
  }) async {
    if (!RegExp(r'^\d{3}-\d{3}-\d{9}$').hasMatch(creditNoteNumber.trim())) {
      throw Exception(
        'La nota de crédito debe usar el formato 001-001-000000000.',
      );
    }
    if (reason.trim().isEmpty) {
      throw Exception('El motivo de anulación es obligatorio.');
    }
    final actor = createdBy ?? await SessionService.getCurrentUserId();
    final now = DateTime.now().toIso8601String();

    await transaction((txn) async {
      final purchases = await txn.rawQuery(
        '''SELECT store_id, supplier_id, total, status, payment_method,
            payment_condition, invoice_number
           FROM purchases WHERE id = ? LIMIT 1''',
        [purchaseId],
      );
      if (purchases.isEmpty) {
        throw Exception('La compra no existe.');
      }
      final purchase = purchases.first;
      final supplierRows = await txn.rawQuery(
        '''SELECT identification_type, identification_number, ruc
           FROM suppliers WHERE id = ? LIMIT 1''',
        [purchase['supplier_id']],
      );
      final supplier = supplierRows.isEmpty
          ? <String, Object?>{}
          : supplierRows.first;
      final supplierType = supplier['identification_type']?.toString() ?? 'ruc';
      final supplierNumber =
          supplier['identification_number']?.toString() ??
          supplier['ruc']?.toString();
      final creditNoteKeyError =
          SupplierRucValidator.validateAccessKeyForInvoice(
            accessKey: accessKey,
            invoiceNumber: creditNoteNumber.trim(),
            issueDate: issueDate,
            supplierRuc: supplierType == 'ruc' ? supplierNumber : null,
          );
      if (creditNoteKeyError != null) {
        throw Exception('Clave de acceso: $creditNoteKeyError');
      }
      if (purchase['status'] == 'cancelled') {
        throw Exception('La compra ya está anulada.');
      }
      final noteDuplicate = await txn.rawQuery(
        '''SELECT id FROM purchase_adjustment_documents
           WHERE document_type = 'credit_note' AND document_number = ? LIMIT 1''',
        [creditNoteNumber.trim()],
      );
      if (noteDuplicate.isNotEmpty) {
        throw Exception('La nota de crédito ya está registrada.');
      }

      final storeId = (purchase['store_id'] as num).toInt();
      final rows = await txn.rawQuery(
        '''SELECT product_id, quantity, cost,
                  CASE WHEN line_subtotal <> 0 OR cost = 0
                       THEN line_subtotal ELSE quantity * cost END AS inventory_value
           FROM purchase_items
           WHERE purchase_id = ? ORDER BY id''',
        [purchaseId],
      );
      final quantities = <int, int>{};
      final inventoryValues = <int, double>{};
      for (final row in rows) {
        final productId = (row['product_id'] as num).toInt();
        quantities[productId] =
            (quantities[productId] ?? 0) + (row['quantity'] as num).toInt();
        inventoryValues[productId] = PurchaseTotals.money(
          (inventoryValues[productId] ?? 0) +
              (row['inventory_value'] as num).toDouble(),
        );
      }
      for (final entry in quantities.entries) {
        final stockRows = await txn.rawQuery(
          '''SELECT stock FROM inventory WHERE product_id = ? AND store_id = ? LIMIT 1''',
          [entry.key, storeId],
        );
        final stock = stockRows.isEmpty
            ? 0
            : (stockRows.first['stock'] as num).toInt();
        if (stock < entry.value) {
          throw Exception(
            'No se puede anular: el stock disponible no cubre las unidades de la factura.',
          );
        }
      }

      for (final entry in quantities.entries) {
        await txn.rawUpdate(
          'UPDATE inventory SET stock = stock - ? WHERE product_id = ? AND store_id = ?',
          [entry.value, entry.key, storeId],
        );
        final inventoryValue = inventoryValues[entry.key] ?? 0;
        final unitCost = entry.value == 0
            ? 0.0
            : PurchaseTotals.money(inventoryValue / entry.value);
        await txn.rawInsert(
          '''INSERT INTO inventory_movements (
               product_id, from_store_id, to_store_id, quantity, date,
               movement_type, reference_id, unit_cost, total_value, created_by
             ) VALUES (?, ?, ?, ?, ?, 'purchase_reversal', ?, ?, ?, ?)''',
          [
            entry.key,
            storeId,
            storeId,
            -entry.value,
            now,
            purchaseId,
            unitCost,
            inventoryValue,
            actor,
          ],
        );
        final remaining = await txn.rawQuery(
          'SELECT COALESCE(SUM(stock), 0) AS stock FROM inventory WHERE product_id = ?',
          [entry.key],
        );
        final remainingQuantity = (remaining.first['stock'] as num).toInt();
        final productCostRows = await txn.rawQuery(
          'SELECT cost_price FROM products WHERE id = ? LIMIT 1',
          [entry.key],
        );
        final currentAverageCost = (productCostRows.first['cost_price'] as num)
            .toDouble();
        final inventoryBeforeReversal = remainingQuantity + entry.value;
        final restoredValue =
            inventoryBeforeReversal * currentAverageCost - inventoryValue;
        if (remainingQuantity > 0 && restoredValue < -0.01) {
          throw Exception(
            'No se puede revertir el costo: el valor disponible del inventario no cubre esta factura.',
          );
        }
        await txn.rawUpdate('UPDATE products SET cost_price = ? WHERE id = ?', [
          remainingQuantity == 0
              ? 0
              : PurchaseTotals.money(
                  (restoredValue < 0 ? 0 : restoredValue) / remainingQuantity,
                ),
          entry.key,
        ]);
      }

      final originalEntries = await txn.rawQuery(
        '''SELECT id FROM accounting_entries
           WHERE source_type = 'purchase' AND source_id = ? AND reversal_of IS NULL
           ORDER BY id LIMIT 1''',
        [purchaseId],
      );
      if (originalEntries.isEmpty) {
        throw Exception('No se encontró el asiento original.');
      }
      final originalEntryId = (originalEntries.first['id'] as num).toInt();
      final originalLines = await txn.rawQuery(
        'SELECT account_code, account_name, debit, credit, memo FROM accounting_entry_lines WHERE entry_id = ?',
        [originalEntryId],
      );
      final inverseDebit = <Map<String, dynamic>>[];
      final inverseCredit = <Map<String, dynamic>>[];
      for (final line in originalLines) {
        final debit = (line['debit'] as num).toDouble();
        final credit = (line['credit'] as num).toDouble();
        if (credit > 0) {
          inverseDebit.add({
            'account_code': line['account_code'],
            'account_name': line['account_name'],
            'amount': credit,
          });
        }
        if (debit > 0) {
          inverseCredit.add({
            'account_code': line['account_code'],
            'account_name': line['account_name'],
            'amount': debit,
          });
        }
      }
      await _insertAccountingEntry(
        txn,
        sourceType: 'purchase_cancel',
        sourceId: purchaseId,
        reversalOf: originalEntryId,
        entryDate: issueDate,
        description: 'Anulación por nota de crédito $creditNoteNumber',
        debitLines: inverseDebit,
        creditLines: inverseCredit,
        createdBy: actor,
        createdAt: now,
      );

      final payableRows = await txn.rawQuery(
        'SELECT id, amount_paid FROM accounts_payable WHERE purchase_id = ? LIMIT 1',
        [purchaseId],
      );
      if (payableRows.isNotEmpty) {
        final payableId = (payableRows.first['id'] as num).toInt();
        final amountPaid = (payableRows.first['amount_paid'] as num).toDouble();
        if (amountPaid > 0) {
          final payments = await txn.rawQuery(
            '''SELECT amount, payment_method, reference
               FROM accounts_payable_payments WHERE payable_id = ? ORDER BY id''',
            [payableId],
          );
          final recordedPayments = PurchaseTotals.money(
            payments.fold<double>(
              0,
              (sum, payment) => sum + (payment['amount'] as num).toDouble(),
            ),
          );
          if ((recordedPayments - amountPaid).abs() > 0.01) {
            throw Exception(
              'Los pagos registrados no cuadran con el saldo CxP.',
            );
          }
          for (final payment in payments) {
            final refund = (payment['amount'] as num).toDouble();
            final paymentMethod = payment['payment_method']?.toString() ?? '';
            final cashPayment = _isCashPayment(paymentMethod);
            final isCredit =
                purchase['payment_condition'] == 'credito' ||
                purchase['payment_condition'] == 'crédito';
            final sessions = cashPayment
                ? await txn.rawQuery(
                    "SELECT id FROM cash_sessions WHERE store_id = ? AND status = 'open' ORDER BY id DESC LIMIT 1",
                    [storeId],
                  )
                : <Map<String, Object?>>[];
            if (cashPayment && sessions.isEmpty) {
              throw Exception(
                'Para registrar el reembolso en efectivo debe existir una caja abierta.',
              );
            }
            if (isCredit) {
              await _insertAccountingEntry(
                txn,
                sourceType: 'purchase_cancel_payment',
                sourceId: purchaseId,
                entryDate: issueDate,
                description: 'Reembolso nota de crédito $creditNoteNumber',
                debitLines: [
                  {
                    'account_code': cashPayment ? 'ASSET_CASH' : 'ASSET_BANK',
                    'account_name': cashPayment
                        ? 'Caja'
                        : 'Bancos - $paymentMethod',
                    'amount': refund,
                  },
                ],
                creditLines: [
                  {
                    'account_code': 'LIABILITY_SUPPLIER_PAYABLE',
                    'account_name': 'Cuentas por pagar a proveedores',
                    'amount': refund,
                  },
                ],
                createdBy: actor,
                createdAt: now,
              );
            }
            if (cashPayment) {
              await txn.rawInsert(
                '''INSERT INTO cash_movements
                   (session_id, type, amount, method, description, created_at)
                   VALUES (?, 'income', ?, ?, ?, ?)''',
                [
                  sessions.first['id'],
                  refund,
                  paymentMethod,
                  'Reembolso nota $creditNoteNumber',
                  now,
                ],
              );
            } else {
              await txn.rawInsert(
                '''INSERT INTO purchase_financial_movements
                   (purchase_id, store_id, direction, payment_method, amount, reference, created_at, created_by)
                   VALUES (?, ?, 'inflow', ?, ?, ?, ?, ?)''',
                [
                  purchaseId,
                  storeId,
                  paymentMethod,
                  refund,
                  creditNoteNumber,
                  now,
                  actor,
                ],
              );
            }
          }
        }
        await txn.rawUpdate(
          "UPDATE accounts_payable SET amount_paid = 0, balance = 0, status = 'cancelled' WHERE id = ?",
          [payableId],
        );
      }

      await txn.rawUpdate(
        "UPDATE purchase_withholding_vouchers SET status = 'cancelled' WHERE purchase_id = ?",
        [purchaseId],
      );
      await txn.rawInsert(
        '''INSERT INTO purchase_adjustment_documents
           (purchase_id, document_type, document_number, access_key,
            issue_date, reason, amount, status, created_by, created_at)
           VALUES (?, 'credit_note', ?, ?, ?, ?, ?, 'posted', ?, ?)''',
        [
          purchaseId,
          creditNoteNumber.trim(),
          accessKey.trim(),
          issueDate.toIso8601String(),
          reason.trim(),
          purchase['total'],
          actor,
          now,
        ],
      );
      await txn.rawUpdate(
        "UPDATE purchases SET status = 'cancelled', cancelled_at = ?, cancellation_reason = ? WHERE id = ?",
        [now, reason.trim(), purchaseId],
      );
    });
    notifyDatabaseChanged();
  }

  static Future<void> payPurchasePayable({
    required int purchaseId,
    required double amount,
    required String paymentMethod,
    String? reference,
    DateTime? paymentDate,
    String? createdBy,
  }) async {
    if (!amount.isFinite || amount <= 0) {
      throw Exception('El valor del pago debe ser mayor que cero.');
    }
    if (paymentMethod.trim().isEmpty) {
      throw Exception('Seleccione el medio de pago.');
    }
    final actor = createdBy ?? await SessionService.getCurrentUserId();
    final now = (paymentDate ?? DateTime.now()).toIso8601String();

    await transaction((txn) async {
      final rows = await txn.rawQuery(
        '''SELECT ap.id, ap.balance, ap.supplier_id, p.store_id
           FROM accounts_payable ap
           JOIN purchases p ON p.id = ap.purchase_id
           WHERE ap.purchase_id = ? AND ap.status = 'open' LIMIT 1''',
        [purchaseId],
      );
      if (rows.isEmpty) {
        throw Exception('No existe saldo pendiente para esta compra.');
      }
      final payableId = (rows.first['id'] as num).toInt();
      final balance = (rows.first['balance'] as num).toDouble();
      final storeId = (rows.first['store_id'] as num).toInt();
      final payment = PurchaseTotals.money(amount);
      if (payment - balance > 0.01) {
        throw Exception('El pago supera el saldo pendiente.');
      }
      final remaining = PurchaseTotals.money(
        (balance - payment).clamp(0, double.infinity),
      );
      await txn.rawInsert(
        '''INSERT INTO accounts_payable_payments
           (payable_id, amount, payment_method, reference, created_at, created_by)
           VALUES (?, ?, ?, ?, ?, ?)''',
        [
          payableId,
          payment,
          paymentMethod.trim(),
          reference?.trim(),
          now,
          actor,
        ],
      );
      await txn.rawUpdate(
        '''UPDATE accounts_payable SET amount_paid = amount_paid + ?, balance = ?,
           status = ? WHERE id = ?''',
        [payment, remaining, remaining <= 0.01 ? 'paid' : 'open', payableId],
      );

      final cashPayment = _isCashPayment(paymentMethod);
      final debitLines = <Map<String, dynamic>>[
        {
          'account_code': 'LIABILITY_SUPPLIER_PAYABLE',
          'account_name': 'Cuentas por pagar a proveedores',
          'amount': payment,
        },
      ];
      final creditLines = <Map<String, dynamic>>[
        {
          'account_code': cashPayment ? 'ASSET_CASH' : 'ASSET_BANK',
          'account_name': cashPayment
              ? 'Caja'
              : 'Bancos - ${paymentMethod.trim()}',
          'amount': payment,
        },
      ];
      await _insertAccountingEntry(
        txn,
        sourceType: 'purchase_payment',
        sourceId: purchaseId,
        entryDate: paymentDate ?? DateTime.now(),
        description: 'Pago de cuenta por pagar de compra #$purchaseId',
        debitLines: debitLines,
        creditLines: creditLines,
        createdBy: actor,
        createdAt: now,
      );

      if (cashPayment) {
        final sessions = await txn.rawQuery(
          "SELECT id FROM cash_sessions WHERE store_id = ? AND status = 'open' ORDER BY id DESC LIMIT 1",
          [storeId],
        );
        if (sessions.isEmpty) {
          throw Exception(
            'Para pagar en efectivo debe existir una caja abierta.',
          );
        }
        await txn.rawInsert(
          '''INSERT INTO cash_movements
             (session_id, type, amount, method, description, created_at)
             VALUES (?, 'expense', ?, ?, ?, ?)''',
          [
            sessions.first['id'],
            payment,
            paymentMethod.trim(),
            'Pago compra #$purchaseId',
            now,
          ],
        );
      } else {
        await txn.rawInsert(
          '''INSERT INTO purchase_financial_movements
             (purchase_id, store_id, direction, payment_method, amount, reference, created_at, created_by)
             VALUES (?, ?, 'outflow', ?, ?, ?, ?, ?)''',
          [
            purchaseId,
            storeId,
            paymentMethod.trim(),
            payment,
            reference?.trim(),
            now,
            actor,
          ],
        );
      }
    });
    notifyDatabaseChanged();
  }

  static bool _isCashPayment(String paymentMethod) =>
      paymentMethod.toLowerCase().contains('efectivo') ||
      paymentMethod.toLowerCase() == 'caja';

  static Future<int> _insertAccountingEntry(
    DatabaseExecutor txn, {
    required String sourceType,
    required int sourceId,
    int? reversalOf,
    required DateTime entryDate,
    required String description,
    required List<Map<String, dynamic>> debitLines,
    required List<Map<String, dynamic>> creditLines,
    required String? createdBy,
    required String createdAt,
  }) async {
    final debit = PurchaseTotals.money(
      debitLines.fold<double>(
        0,
        (sum, line) => sum + (line['amount'] as num).toDouble(),
      ),
    );
    final credit = PurchaseTotals.money(
      creditLines.fold<double>(
        0,
        (sum, line) => sum + (line['amount'] as num).toDouble(),
      ),
    );
    if ((debit - credit).abs() > 0.01) {
      throw Exception('El asiento contable no está balanceado.');
    }
    final entryId = await txn.rawInsert(
      '''INSERT INTO accounting_entries
             (source_type, source_id, reversal_of, entry_date, description,
              total_debit, total_credit, created_by, created_at)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)''',
      [
        sourceType,
        sourceId,
        reversalOf,
        entryDate.toIso8601String(),
        description,
        debit,
        credit,
        createdBy,
        createdAt,
      ],
    );
    for (final line in debitLines) {
      final amount = PurchaseTotals.money((line['amount'] as num).toDouble());
      if (amount == 0) continue;
      await txn.rawInsert(
        '''INSERT INTO accounting_entry_lines
               (entry_id, account_code, account_name, debit, credit, memo)
               VALUES (?, ?, ?, ?, 0, ?)''',
        [
          entryId,
          line['account_code'],
          line['account_name'],
          amount,
          description,
        ],
      );
    }
    for (final line in creditLines) {
      final amount = PurchaseTotals.money((line['amount'] as num).toDouble());
      if (amount == 0) continue;
      await txn.rawInsert(
        '''INSERT INTO accounting_entry_lines
               (entry_id, account_code, account_name, debit, credit, memo)
               VALUES (?, ?, ?, 0, ?, ?)''',
        [
          entryId,
          line['account_code'],
          line['account_name'],
          amount,
          description,
        ],
      );
    }
    return entryId;
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
    String search = '',
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
    final searchTerm = search.trim();
    if (searchTerm.isNotEmpty) {
      conditions.add('''(
        COALESCE(pu.invoice_number, '') LIKE ? OR
        COALESCE(pu.auxiliary_invoice_number, '') LIKE ? OR
        COALESCE(sp.name, '') LIKE ? OR COALESCE(sp.ruc, '') LIKE ? OR
        COALESCE(pu.payment_method, '') LIKE ? OR st.name LIKE ? OR
        CAST(pu.id AS TEXT) LIKE ? OR
        EXISTS (
          SELECT 1 FROM purchase_items pi_search
          INNER JOIN products p_search ON p_search.id = pi_search.product_id
          WHERE pi_search.purchase_id = pu.id
            AND (p_search.name LIKE ? OR p_search.sku LIKE ?)
        )
      )''');
      final pattern = '%$searchTerm%';
      args.addAll(List<dynamic>.filled(7, pattern));
      args.addAll([pattern, pattern]);
    }

    final whereClause = conditions.isEmpty
        ? ''
        : 'WHERE ${conditions.join(' AND ')}';

    return db.rawQuery('''
            SELECT pu.id, pu.store_id, pu.date, pu.total, pu.status,
              pu.payment_condition,
              pu.due_date, pu.tax_support_code,
              pu.invoice_number, pu.auxiliary_invoice_number, pu.payment_method,
              pu.supplier_id,
              COALESCE(ap.invoice_total, pu.total) AS invoice_total,
              COALESCE(ap.amount_paid, 0) AS amount_paid,
              COALESCE((SELECT SUM(pi.line_subtotal)
                        FROM purchase_items pi WHERE pi.purchase_id = pu.id), 0) AS subtotal,
              COALESCE((SELECT SUM(pi.vat_amount)
                        FROM purchase_items pi WHERE pi.purchase_id = pu.id), 0) AS tax,
              COALESCE(ap.balance, 0) AS payable_balance,
             st.name AS store_name,
             COALESCE(sp.name, 'Sin proveedor') AS supplier_name,
             sp.ruc AS supplier_ruc
      FROM purchases pu
      INNER JOIN stores st ON st.id = pu.store_id
      LEFT JOIN suppliers sp ON sp.id = pu.supplier_id
      LEFT JOIN accounts_payable ap ON ap.purchase_id = pu.id
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
                  SELECT pi.id, p.name AS product_name, pi.quantity, pi.cost,
                    pi.paid_quantity, pi.bonus_quantity,
                       CASE WHEN pi.paid_quantity = 0 AND pi.bonus_quantity = 0
                           AND pi.invoice_unit_cost = 0
                         THEN pi.cost ELSE pi.invoice_unit_cost END AS invoice_unit_cost,
                       pi.discount, pi.vat_type, pi.vat_rate, pi.vat_amount,
                       CASE WHEN pi.line_total = 0 AND pi.cost <> 0
                         THEN pi.quantity * pi.cost ELSE pi.line_total END AS line_total
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
    final createdBy = await SessionService.getCurrentUserId();
    final now = DateTime.now().toIso8601String();

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
        final productRows = await txn.rawQuery(
          'SELECT cost_price FROM products WHERE id = ? LIMIT 1',
          [productId],
        );
        final unitCost = productRows.isEmpty
            ? 0.0
            : (productRows.first['cost_price'] as num).toDouble();
        await txn.rawInsert(
          '''INSERT INTO inventory_movements (
               product_id, from_store_id, to_store_id, quantity, date,
               movement_type, reference_id, unit_cost, total_value, created_by
             ) VALUES (?, ?, ?, ?, ?, 'sale', ?, ?, ?, ?)''',
          [
            productId,
            storeId,
            storeId,
            -quantity,
            now,
            saleId,
            unitCost,
            PurchaseTotals.money(unitCost * quantity),
            createdBy,
          ],
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
        SELECT p.id, p.name, p.sku, p.price AS sellPrice,
          COALESCE(p.cost_price, 0) AS costPrice,
          p.price - COALESCE(p.cost_price, 0) AS marginPerUnit,
          CASE WHEN COALESCE(p.cost_price, 0) > 0
            THEN ((p.price - p.cost_price) / p.cost_price * 100)
            ELSE 0 END AS marginPercent,
          i.stock AS quantity
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
        SELECT COUNT(DISTINCT p.id) AS totalProducts,
          SUM(i.stock) AS totalUnits,
          SUM(i.stock * COALESCE(p.cost_price, 0)) AS totalInvested,
          SUM(i.stock * p.price) AS totalSellValue,
          AVG(p.price - COALESCE(p.cost_price, 0)) AS avgMarginPerUnit,
          COUNT(CASE WHEN i.stock <= 2 THEN 1 END) AS lowStockCount
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
        SELECT p.id, p.name, p.sku, p.price,
          COALESCE(p.cost_price, 0) AS costPrice,
          i.stock,
          (i.stock * COALESCE(p.cost_price, 0)) AS investmentValue
        FROM products p
        JOIN inventory i ON p.id = i.product_id
        WHERE i.store_id = ?
          AND i.stock <= ?
          AND (i.stock * COALESCE(p.cost_price, 0)) >= ?
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
