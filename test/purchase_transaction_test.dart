import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tienda/Presentation/Services/database_service.dart';
import 'package:tienda/Presentation/Services/sri_invoice_service.dart';

void main() {
  late Database testDatabase;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    testDatabase = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await _createSchema(testDatabase);
    await testDatabase.insert('stores', {'id': 1, 'name': 'Tienda'});
    await testDatabase.insert('suppliers', {
      'id': 1,
      'name': 'Proveedor de prueba',
      'legal_name': 'Proveedor de prueba S.A.',
      'identification_type': 'ruc',
      'identification_number': '1790016919001',
      'ruc': '1790016919001',
      'payment_condition': 'credito',
      'payment_term_days': 30,
    });
    await testDatabase.insert('products', {
      'id': 1,
      'name': 'Producto de prueba',
      'sku': 'TEST-001',
      'price': 20.0,
      'cost_price': 5.0,
    });
    await testDatabase.insert('inventory', {
      'product_id': 1,
      'store_id': 1,
      'stock': 4,
    });
    DatabaseService.useDatabaseForTesting(testDatabase);
  });

  tearDown(() async {
    await testDatabase.close();
  });

  test('rechaza factura duplicada por proveedor y número', () async {
    await _registerInvoice();
    await expectLater(
      _registerInvoice(),
      throwsA(isA<Exception>().having(
        (error) => error.toString(),
        'mensaje',
        contains('ya existe para este proveedor'),
      )),
    );
    expect(await testDatabase.rawQuery('SELECT id FROM purchases'), hasLength(1));
  });

  test('revierte todo si falla la creación de CxP', () async {
    await testDatabase.execute('''
      CREATE TRIGGER fail_payable BEFORE INSERT ON accounts_payable
      BEGIN SELECT RAISE(ABORT, 'forced payable failure'); END
    ''');

    await expectLater(_registerInvoice(), throwsA(isA<Exception>()));

    expect(await _count(testDatabase, 'purchases'), 0);
    expect(await _count(testDatabase, 'purchase_items'), 0);
    expect(await _count(testDatabase, 'inventory_movements'), 0);
    expect(await _count(testDatabase, 'accounting_entries'), 0);
    final stock = await testDatabase.rawQuery(
      'SELECT stock FROM inventory WHERE product_id = 1 AND store_id = 1',
    );
    expect(stock.single['stock'], 4);
    final product = await testDatabase.rawQuery(
      'SELECT cost_price FROM products WHERE id = 1',
    );
    expect(product.single['cost_price'], 5.0);
  });

  test('nota de crédito revierte stock y genera asiento opuesto', () async {
    final purchaseId = await _registerInvoice();
    final creditKey = _accessKey(sequence: 10);

    await DatabaseService.cancelPurchase(
      purchaseId: purchaseId,
      creditNoteNumber: '001-001-000000010',
      accessKey: creditKey,
      issueDate: DateTime(2026, 10, 1),
      reason: 'Devolución total de la factura',
      createdBy: 'test-user',
    );

    final purchase = await testDatabase.rawQuery(
      'SELECT status FROM purchases WHERE id = ?',
      [purchaseId],
    );
    expect(purchase.single['status'], 'cancelled');
    final stock = await testDatabase.rawQuery(
      'SELECT stock FROM inventory WHERE product_id = 1 AND store_id = 1',
    );
    expect(stock.single['stock'], 4);
    final movements = await testDatabase.rawQuery(
      'SELECT movement_type, quantity FROM inventory_movements ORDER BY id',
    );
    expect(movements.map((row) => row['movement_type']), [
      'purchase',
      'purchase_reversal',
    ]);
    expect(movements.last['quantity'], -10);
    final entries = await testDatabase.rawQuery(
      'SELECT id, total_debit, total_credit, reversal_of FROM accounting_entries ORDER BY id',
    );
    expect(entries, hasLength(2));
    expect(entries.last['total_debit'], entries.last['total_credit']);
    expect(entries.last['reversal_of'], entries.first['id']);
  });

  test('actualiza saldo, pago y asiento al abonar parcialmente CxP', () async {
    final purchaseId = await _registerInvoice();

    await DatabaseService.payPurchasePayable(
      purchaseId: purchaseId,
      amount: 30,
      paymentMethod: 'Transferencia',
      reference: 'TRX-123',
      createdBy: 'test-user',
    );

    final payable = await testDatabase.rawQuery(
      'SELECT amount_paid, balance, status FROM accounts_payable WHERE purchase_id = ?',
      [purchaseId],
    );
    expect(payable.single['amount_paid'], 30.0);
    expect(payable.single['balance'], 70.0);
    expect(payable.single['status'], 'open');
    expect(await _count(testDatabase, 'accounts_payable_payments'), 1);
    expect(await _count(testDatabase, 'purchase_financial_movements'), 1);
    expect(await _count(testDatabase, 'accounting_entries'), 2);
  });

  test('anula correctamente una compra que ya recibió un abono parcial', () async {
    final purchaseId = await _registerInvoice();
    await DatabaseService.payPurchasePayable(
      purchaseId: purchaseId,
      amount: 30,
      paymentMethod: 'Transferencia',
      reference: 'TRX-123',
      createdBy: 'test-user',
    );

    await DatabaseService.cancelPurchase(
      purchaseId: purchaseId,
      creditNoteNumber: '001-001-000000010',
      accessKey: _accessKey(sequence: 10),
      issueDate: DateTime(2026, 10, 1),
      reason: 'Devolución posterior a abono',
      createdBy: 'test-user',
    );

    final payable = await testDatabase.rawQuery(
      'SELECT amount_paid, balance, status FROM accounts_payable WHERE purchase_id = ?',
      [purchaseId],
    );
    expect(payable.single['amount_paid'], 0.0);
    expect(payable.single['balance'], 0.0);
    expect(payable.single['status'], 'cancelled');
    expect(await _count(testDatabase, 'accounting_entries'), 4);
    expect(await _count(testDatabase, 'purchase_financial_movements'), 2);
  });

  test('promedia costo con stock previo y unidades bonificadas', () async {
    await _registerInvoice(
      quantity: 5,
      bonusQuantity: 1,
      unitCost: 10,
      total: 57.5,
      vatType: 'standard',
      vatRate: 15,
    );

    final stock = await testDatabase.rawQuery(
      'SELECT stock FROM inventory WHERE product_id = 1 AND store_id = 1',
    );
    final cost = await testDatabase.rawQuery(
      'SELECT cost_price, price FROM products WHERE id = 1',
    );
    expect(stock.single['stock'], 10);
    expect(cost.single['cost_price'], 7.0);
    expect(cost.single['price'], 20.0);
  });
}

Future<int> _registerInvoice({
  int quantity = 10,
  int bonusQuantity = 0,
  double bonusVatAmount = 0,
  double unitCost = 10,
  double total = 100,
  String vatType = 'zero',
  double vatRate = 0,
}) {
  return DatabaseService.registerPurchase(
    storeId: 1,
    supplierId: 1,
    invoiceNumber: '001-001-000000001',
    accessKey: _accessKey(),
    issueDate: DateTime(2026, 10, 1),
    paymentCondition: 'credito',
    dueDate: DateTime(2026, 10, 31),
    taxSupportCode: '01',
    physicalTotal: total,
    paymentMethod: 'Transferencia',
    createdBy: 'test-user',
    items: [
      {
        'product_id': 1,
        'quantity': quantity,
        'bonus_quantity': bonusQuantity,
        'bonus_vat_amount': bonusVatAmount,
        'unit_cost': unitCost,
        'discount': 0,
        'vat_type': vatType,
        'vat_rate': vatRate,
      },
    ],
  );
}

String _accessKey({int sequence = 1}) => SriInvoiceService.generateAccessKey(
  ruc: '1790016919001',
  documentCode: '01',
  ambiente: 1,
  estab: '001',
  ptoEmi: '001',
  sequence: sequence,
  date: DateTime(2026, 10, 1),
);

Future<int> _count(Database db, String table) async {
  final rows = await db.rawQuery('SELECT COUNT(*) AS total FROM $table');
  return (rows.single['total'] as num).toInt();
}

Future<void> _createSchema(Database db) async {
  for (final sql in [
    'CREATE TABLE stores (id INTEGER PRIMARY KEY, name TEXT NOT NULL)',
    '''CREATE TABLE suppliers (
      id INTEGER PRIMARY KEY, name TEXT NOT NULL, legal_name TEXT,
      identification_type TEXT, identification_number TEXT, ruc TEXT,
      payment_condition TEXT, payment_term_days INTEGER)''',
    '''CREATE TABLE products (
      id INTEGER PRIMARY KEY, name TEXT NOT NULL, sku TEXT NOT NULL,
      price REAL NOT NULL DEFAULT 0, cost_price REAL NOT NULL DEFAULT 0)''',
    '''CREATE TABLE inventory (
      id INTEGER PRIMARY KEY AUTOINCREMENT, product_id INTEGER NOT NULL,
      store_id INTEGER NOT NULL, stock INTEGER NOT NULL DEFAULT 0,
      UNIQUE(product_id, store_id))''',
    '''CREATE TABLE purchases (
      id INTEGER PRIMARY KEY AUTOINCREMENT, store_id INTEGER NOT NULL,
      supplier_id INTEGER, total REAL NOT NULL, date TEXT NOT NULL,
      invoice_number TEXT, auxiliary_invoice_number TEXT, payment_method TEXT,
      access_key TEXT, issue_date TEXT, payment_condition TEXT, due_date TEXT,
      tax_support_code TEXT, physical_total REAL, calculated_total REAL,
      status TEXT, retention_income_amount REAL DEFAULT 0,
      retention_vat_amount REAL DEFAULT 0, created_by TEXT, created_at TEXT,
      cancelled_at TEXT, cancellation_reason TEXT)''',
    '''CREATE TABLE purchase_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT, purchase_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL, quantity INTEGER NOT NULL, cost REAL NOT NULL,
      paid_quantity INTEGER DEFAULT 0, bonus_quantity INTEGER DEFAULT 0,
      bonus_vat_amount REAL DEFAULT 0,
      invoice_unit_cost REAL DEFAULT 0, discount REAL DEFAULT 0,
      vat_type TEXT DEFAULT 'standard', vat_rate REAL DEFAULT 0,
      vat_amount REAL DEFAULT 0, line_subtotal REAL DEFAULT 0,
      line_total REAL DEFAULT 0, created_by TEXT)''',
    '''CREATE TABLE inventory_movements (
      id INTEGER PRIMARY KEY AUTOINCREMENT, product_id INTEGER NOT NULL,
      from_store_id INTEGER NOT NULL, to_store_id INTEGER NOT NULL,
      quantity INTEGER NOT NULL, date TEXT NOT NULL, movement_type TEXT,
      reference_id INTEGER, unit_cost REAL DEFAULT 0, total_value REAL DEFAULT 0,
      created_by TEXT)''',
    '''CREATE TABLE accounts_payable (
      id INTEGER PRIMARY KEY AUTOINCREMENT, purchase_id INTEGER UNIQUE,
      supplier_id INTEGER, invoice_total REAL, withheld_total REAL,
      amount_paid REAL, balance REAL, due_date TEXT, status TEXT, created_at TEXT)''',
    '''CREATE TABLE accounts_payable_payments (
      id INTEGER PRIMARY KEY AUTOINCREMENT, payable_id INTEGER, amount REAL,
      payment_method TEXT, reference TEXT, created_at TEXT, created_by TEXT)''',
    '''CREATE TABLE accounting_entries (
      id INTEGER PRIMARY KEY AUTOINCREMENT, source_type TEXT, source_id INTEGER,
      reversal_of INTEGER, entry_date TEXT, description TEXT,
      total_debit REAL, total_credit REAL, created_by TEXT, created_at TEXT)''',
    '''CREATE TABLE accounting_entry_lines (
      id INTEGER PRIMARY KEY AUTOINCREMENT, entry_id INTEGER,
      account_code TEXT, account_name TEXT, debit REAL, credit REAL, memo TEXT)''',
    '''CREATE TABLE purchase_withholding_vouchers (
      id INTEGER PRIMARY KEY AUTOINCREMENT, purchase_id INTEGER UNIQUE,
      supplier_id INTEGER, authorization_number TEXT, issue_date TEXT,
      status TEXT, created_by TEXT, created_at TEXT)''',
    '''CREATE TABLE purchase_withholdings (
      id INTEGER PRIMARY KEY AUTOINCREMENT, voucher_id INTEGER,
      tax_type TEXT, code TEXT, taxable_base REAL, rate REAL, amount REAL)''',
    '''CREATE TABLE purchase_adjustment_documents (
      id INTEGER PRIMARY KEY AUTOINCREMENT, purchase_id INTEGER,
      document_type TEXT, document_number TEXT, access_key TEXT,
      issue_date TEXT, reason TEXT, amount REAL, status TEXT,
      created_by TEXT, created_at TEXT)''',
    '''CREATE TABLE purchase_financial_movements (
      id INTEGER PRIMARY KEY AUTOINCREMENT, purchase_id INTEGER,
      store_id INTEGER, direction TEXT, payment_method TEXT, amount REAL,
      reference TEXT, created_at TEXT, created_by TEXT)''',
    '''CREATE TABLE cash_sessions (
      id INTEGER PRIMARY KEY AUTOINCREMENT, store_id INTEGER, status TEXT)''',
    '''CREATE TABLE cash_movements (
      id INTEGER PRIMARY KEY AUTOINCREMENT, session_id INTEGER, type TEXT,
      amount REAL, method TEXT, description TEXT, created_at TEXT)''',
  ]) {
    await db.execute(sql);
  }
}