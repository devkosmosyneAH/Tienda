/// Denominaciones disponibles en USD (Ecuador)
class CashDenomination {
  final double value;
  final String label;
  final bool isCoin; // false = billete

  const CashDenomination({
    required this.value,
    required this.label,
    required this.isCoin,
  });
}

/// Catálogo de denominaciones (billetes y monedas USD)
class CashDenominations {
  static const List<CashDenomination> bills = [
    CashDenomination(value: 100, label: '\$100', isCoin: false),
    CashDenomination(value: 50, label: '\$50', isCoin: false),
    CashDenomination(value: 20, label: '\$20', isCoin: false),
    CashDenomination(value: 10, label: '\$10', isCoin: false),
    CashDenomination(value: 5, label: '\$5', isCoin: false),
    CashDenomination(value: 1, label: '\$1', isCoin: false),
  ];

  static const List<CashDenomination> coins = [
    CashDenomination(value: 1.00, label: '\$1.00', isCoin: true),
    CashDenomination(value: 0.50, label: '\$0.50', isCoin: true),
    CashDenomination(value: 0.25, label: '\$0.25', isCoin: true),
    CashDenomination(value: 0.10, label: '\$0.10', isCoin: true),
    CashDenomination(value: 0.05, label: '\$0.05', isCoin: true),
    CashDenomination(value: 0.01, label: '\$0.01', isCoin: true),
  ];

  static List<CashDenomination> get all => [...bills, ...coins];
}

/// Entrada de una denominación: cuántos billetes/monedas de cierto valor
class DenominationEntry {
  final CashDenomination denomination;
  int quantity;

  DenominationEntry({required this.denomination, this.quantity = 0});

  double get subtotal => denomination.value * quantity;

  Map<String, dynamic> toMap(int sessionId, String moment) => {
    'session_id': sessionId,
    'value': denomination.value,
    'label': denomination.label,
    'is_coin': denomination.isCoin ? 1 : 0,
    'quantity': quantity,
    'subtotal': subtotal,
    'moment': moment, // 'open' | 'close'
    'created_at': DateTime.now().toIso8601String(),
  };

  static DenominationEntry fromMap(Map<String, dynamic> map) {
    final value = (map['value'] as num).toDouble();
    final isCoin = (map['is_coin'] as int) == 1;
    final denom = CashDenominations.all.firstWhere(
      (d) => d.value == value && d.isCoin == isCoin,
      orElse: () => CashDenomination(
        value: value,
        label: map['label'] as String,
        isCoin: isCoin,
      ),
    );
    return DenominationEntry(
      denomination: denom,
      quantity: (map['quantity'] as num).toInt(),
    );
  }
}

// ─── Modelos de Caja (compatible con tablas cajas / egresos_caja / ingresos_caja) ───

/// Modelo unificado para Caja - Compatible con SQLite
class Caja {
  final int? id;
  final String codigo;
  final String estado; // 'a' = abierta, 'c' = cerrada
  final double existente;
  final String fechaAp;
  final String? fechaCi;
  final String idUsuario;
  final double ingresos;
  final double montoAp;
  final double pagos;
  final String? billetesInicio;
  final String? monedasInicio;
  final String? billetesFin;
  final String? monedasFin;
  final double montoTotalCierre;
  final String? montoBilletesInicio;
  final String? montoMonedasInicio;
  final String? montoBilletesFin;
  final String? montoMonedasFin;

  Caja({
    this.id,
    required this.codigo,
    required this.estado,
    this.existente = 0.0,
    required this.fechaAp,
    this.fechaCi,
    required this.idUsuario,
    this.ingresos = 0.0,
    this.montoAp = 0.0,
    this.pagos = 0.0,
    this.billetesInicio,
    this.monedasInicio,
    this.billetesFin,
    this.monedasFin,
    this.montoTotalCierre = 0.0,
    this.montoBilletesInicio,
    this.montoMonedasInicio,
    this.montoBilletesFin,
    this.montoMonedasFin,
  });

  factory Caja.fromMap(Map<String, dynamic> map) {
    return Caja(
      id: map['id'] as int?,
      codigo: map['codigo']?.toString() ?? '',
      estado: map['estado']?.toString() ?? 'c',
      existente: double.tryParse(map['existente']?.toString() ?? '0') ?? 0.0,
      fechaAp: map['fecha_ap']?.toString() ?? '',
      fechaCi: map['fecha_ci']?.toString(),
      idUsuario: map['id_usuario']?.toString() ?? '',
      ingresos: double.tryParse(map['ingresos']?.toString() ?? '0') ?? 0.0,
      montoAp: double.tryParse(map['monto_ap']?.toString() ?? '0') ?? 0.0,
      pagos: double.tryParse(map['pagos']?.toString() ?? '0') ?? 0.0,
      billetesInicio: map['billetes_inicio']?.toString(),
      monedasInicio: map['monedas_inicio']?.toString(),
      billetesFin: map['billetes_fin']?.toString(),
      monedasFin: map['monedas_fin']?.toString(),
      montoTotalCierre:
          double.tryParse(map['monto_total_cierre']?.toString() ?? '0') ?? 0.0,
      montoBilletesInicio: map['monto_billetes_inicio']?.toString(),
      montoMonedasInicio: map['monto_monedas_inicio']?.toString(),
      montoBilletesFin: map['monto_billetes_fin']?.toString(),
      montoMonedasFin: map['monto_monedas_fin']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'codigo': codigo,
      'estado': estado,
      'existente': existente,
      'fecha_ap': fechaAp,
      'fecha_ci': fechaCi,
      'id_usuario': idUsuario,
      'ingresos': ingresos,
      'monto_ap': montoAp,
      'pagos': pagos,
      'billetes_inicio': billetesInicio,
      'monedas_inicio': monedasInicio,
      'billetes_fin': billetesFin,
      'monedas_fin': monedasFin,
      'monto_total_cierre': montoTotalCierre,
      'monto_billetes_inicio': montoBilletesInicio,
      'monto_monedas_inicio': montoMonedasInicio,
      'monto_billetes_fin': montoBilletesFin,
      'monto_monedas_fin': montoMonedasFin,
    };
  }

  bool get estaAbierta => estado.toLowerCase() == 'a';
  bool get estaCerrada => estado.toLowerCase() == 'c';
  double get balanceCalculado => montoAp + ingresos - pagos;
  double get diferencia => existente - balanceCalculado;

  Caja copyWith({
    int? id,
    String? codigo,
    String? estado,
    double? existente,
    String? fechaAp,
    String? fechaCi,
    String? idUsuario,
    double? ingresos,
    double? montoAp,
    double? pagos,
    String? billetesInicio,
    String? monedasInicio,
    String? billetesFin,
    String? monedasFin,
    double? montoTotalCierre,
    String? montoBilletesInicio,
    String? montoMonedasInicio,
    String? montoBilletesFin,
    String? montoMonedasFin,
  }) {
    return Caja(
      id: id ?? this.id,
      codigo: codigo ?? this.codigo,
      estado: estado ?? this.estado,
      existente: existente ?? this.existente,
      fechaAp: fechaAp ?? this.fechaAp,
      fechaCi: fechaCi ?? this.fechaCi,
      idUsuario: idUsuario ?? this.idUsuario,
      ingresos: ingresos ?? this.ingresos,
      montoAp: montoAp ?? this.montoAp,
      pagos: pagos ?? this.pagos,
      billetesInicio: billetesInicio ?? this.billetesInicio,
      monedasInicio: monedasInicio ?? this.monedasInicio,
      billetesFin: billetesFin ?? this.billetesFin,
      monedasFin: monedasFin ?? this.monedasFin,
      montoTotalCierre: montoTotalCierre ?? this.montoTotalCierre,
      montoBilletesInicio: montoBilletesInicio ?? this.montoBilletesInicio,
      montoMonedasInicio: montoMonedasInicio ?? this.montoMonedasInicio,
      montoBilletesFin: montoBilletesFin ?? this.montoBilletesFin,
      montoMonedasFin: montoMonedasFin ?? this.montoMonedasFin,
    );
  }

  @override
  String toString() =>
      'Caja(id: $id, codigo: $codigo, estado: $estado, fechaAp: $fechaAp, balance: $balanceCalculado)';
}

/// Modelo para Egreso de Caja - Compatible con SQLite
class EgresoCaja {
  final int? id;
  final String? key;
  final String codigo;
  final String concepto;
  final String fecha;
  final String idCaja;
  final double monto;

  EgresoCaja({
    this.id,
    this.key,
    required this.codigo,
    required this.concepto,
    required this.fecha,
    required this.idCaja,
    required this.monto,
  });

  factory EgresoCaja.fromMap(Map<String, dynamic> map) {
    return EgresoCaja(
      id: map['id'] as int?,
      key: map['_key']?.toString(),
      codigo: map['codigo']?.toString() ?? '',
      concepto: map['concepto']?.toString() ?? '',
      fecha: map['fecha']?.toString() ?? '',
      idCaja: map['id_caja']?.toString() ?? '',
      monto: double.tryParse(map['monto']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      '_key': key,
      'codigo': codigo,
      'concepto': concepto,
      'fecha': fecha,
      'id_caja': idCaja,
      'monto': monto,
    };
  }

  EgresoCaja copyWith({
    int? id,
    String? key,
    String? codigo,
    String? concepto,
    String? fecha,
    String? idCaja,
    double? monto,
  }) {
    return EgresoCaja(
      id: id ?? this.id,
      key: key ?? this.key,
      codigo: codigo ?? this.codigo,
      concepto: concepto ?? this.concepto,
      fecha: fecha ?? this.fecha,
      idCaja: idCaja ?? this.idCaja,
      monto: monto ?? this.monto,
    );
  }

  @override
  String toString() =>
      'EgresoCaja(id: $id, codigo: $codigo, concepto: $concepto, monto: $monto)';
}

/// Modelo para Ingreso de Caja - Compatible con SQLite
class IngresoCaja {
  final int? id;
  final String? key;
  final String codigo;
  final String concepto;
  final String fecha;
  final String idCaja;
  final double monto;

  IngresoCaja({
    this.id,
    this.key,
    required this.codigo,
    required this.concepto,
    required this.fecha,
    required this.idCaja,
    required this.monto,
  });

  factory IngresoCaja.fromMap(Map<String, dynamic> map) {
    return IngresoCaja(
      id: map['id'] as int?,
      key: map['_key']?.toString(),
      codigo: map['codigo']?.toString() ?? '',
      concepto: map['concepto']?.toString() ?? '',
      fecha: map['fecha']?.toString() ?? '',
      idCaja: map['id_caja']?.toString() ?? '',
      monto: double.tryParse(map['monto']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      '_key': key,
      'codigo': codigo,
      'concepto': concepto,
      'fecha': fecha,
      'id_caja': idCaja,
      'monto': monto,
    };
  }

  IngresoCaja copyWith({
    int? id,
    String? key,
    String? codigo,
    String? concepto,
    String? fecha,
    String? idCaja,
    double? monto,
  }) {
    return IngresoCaja(
      id: id ?? this.id,
      key: key ?? this.key,
      codigo: codigo ?? this.codigo,
      concepto: concepto ?? this.concepto,
      fecha: fecha ?? this.fecha,
      idCaja: idCaja ?? this.idCaja,
      monto: monto ?? this.monto,
    );
  }

  @override
  String toString() =>
      'IngresoCaja(id: $id, codigo: $codigo, concepto: $concepto, monto: $monto)';
}

/// Resumen de caja: total en billetes, total en monedas, gran total
class CashBreakdown {
  final List<DenominationEntry> entries;
  final String moment; // 'open' | 'close'

  const CashBreakdown({required this.entries, required this.moment});

  double get totalBills => entries
      .where((e) => !e.denomination.isCoin && e.quantity > 0)
      .fold(0, (sum, e) => sum + e.subtotal);

  double get totalCoins => entries
      .where((e) => e.denomination.isCoin && e.quantity > 0)
      .fold(0, (sum, e) => sum + e.subtotal);

  double get grandTotal => totalBills + totalCoins;
}
