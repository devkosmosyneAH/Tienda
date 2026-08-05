import 'package:tienda/Presentation/Controller/cash_controller.dart';
import 'package:tienda/Presentation/Model/cash_model.dart';
import 'package:tienda/Presentation/Renders/responsive_helper.dart';
import 'package:tienda/Presentation/Services/session_service.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:tienda/Presentation/Widgets/cash_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

class CashView extends StatefulWidget {
  const CashView({super.key});

  @override
  State<CashView> createState() => _CashViewState();
}

class _CashViewState extends State<CashView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.index == 1 && !_tabController.indexIsChanging) {
        context.read<CashController>().loadHistory();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CashController>().initialize();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appBarHeight = ResponsiveHelper.getAppBarHeight(context);
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(appBarHeight + kTextTabBarHeight),
        child: ClipRRect(
          clipBehavior: Clip.hardEdge,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(25),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.blackOverlay,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.blackOverlay, AppColors.blackOverlay],
              ),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 5,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: AppBar(
              surfaceTintColor: Colors.transparent,
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.whiteOverlay,
                  size: 30,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Caja diaria',
                style: TextStyle(color: AppColors.whiteOverlay),
              ),
              bottom: TabBar(
                controller: _tabController,
                labelColor: AppColors.whiteOverlay,
                unselectedLabelColor: AppColors.whiteOverlay.withValues(
                  alpha: 0.5,
                ),
                indicatorColor: AppColors.whiteOverlay,
                tabs: const [
                  Tab(text: 'Caja'),
                  Tab(text: 'Historial'),
                ],
              ),
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [_CajaTab(), _HistorialTab()],
      ),
    );
  }
}

// ─── Tab 1: Caja actual ───────────────────────────────────────────────────────

class _CajaTab extends StatelessWidget {
  const _CajaTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<CashController>(
      builder: (context, controller, _) {
        if (controller.isLoading && controller.stores.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        final summary = controller.summary ?? {};
        final byMethod = (summary['by_method'] as List?) ?? [];

        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 16),
              Card(
                color: AppColors.whiteOverlay,
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        controller.hasOpenSession
                            ? 'Caja abierta'
                            : 'Caja cerrada',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),

                      const SizedBox(height: 8),
                      if (controller.activeSession != null)
                        Text(
                          'Apertura: \$${((controller.activeSession!['opening_amount'] ?? 0) as num).toStringAsFixed(2)}',
                        ),
                      if (controller.activeSession != null) ...[
                        const SizedBox(height: 4),
                        _CashSessionInfo(session: controller.activeSession!),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (!controller.hasOpenSession)
                            ElevatedButton.icon(
                              onPressed: () =>
                                  _CashViewActions.showOpenDialog(context),
                              icon: const Icon(Icons.lock_open),
                              label: const Text('Abrir caja'),
                            ),
                          if (controller.hasOpenSession) ...[
                            ElevatedButton.icon(
                              onPressed: () =>
                                  _CashViewActions.showMovementDialog(
                                    context,
                                    'income',
                                  ),
                              icon: const Icon(Icons.add_circle_outline),
                              label: const Text('Ingreso'),
                            ),
                            ElevatedButton.icon(
                              onPressed: () =>
                                  _CashViewActions.showMovementDialog(
                                    context,
                                    'expense',
                                  ),
                              icon: const Icon(Icons.remove_circle_outline),
                              label: const Text('Gasto'),
                            ),
                            FilledButton.icon(
                              onPressed: () =>
                                  _CashViewActions.showCloseDialog(context),
                              icon: const Icon(Icons.lock_outline),
                              label: const Text('Cerrar caja'),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (controller.hasOpenSession)
                Card(
                  color: AppColors.whiteOverlay,
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Resumen',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Ingresos: \$${((summary['total_income'] ?? 0) as num).toStringAsFixed(2)}',
                        ),
                        Text(
                          'Egresos: \$${((summary['total_expense'] ?? 0) as num).toStringAsFixed(2)}',
                        ),
                        Text(
                          'Saldo esperado: \$${((summary['expected_balance'] ?? 0) as num).toStringAsFixed(2)}',
                        ),
                        Text(
                          'Caja física: \$${((summary['physical_cash'] ?? 0) as num).toStringAsFixed(2)}',
                        ),
                        Text(
                          'Caja virtual: \$${((summary['virtual_balance'] ?? 0) as num).toStringAsFixed(2)}',
                        ),
                        if (controller.openingBreakdown != null) ...[
                          const SizedBox(height: 12),
                          const Divider(),
                          const SizedBox(height: 8),
                          CashBreakdownSummary(
                            breakdown: controller.openingBreakdown!,
                            title: 'Desglose de apertura',
                          ),
                        ],
                        const SizedBox(height: 12),
                        const Text(
                          'Por método',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 6),
                        ...byMethod.map(
                          (row) => ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            title: Text(row['method']?.toString() ?? '-'),
                            subtitle: Text(
                              'Ingreso: \$${((row['income'] ?? 0) as num).toStringAsFixed(2)} · Egreso: \$${((row['expense'] ?? 0) as num).toStringAsFixed(2)}',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              const Text(
                'Movimientos',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (controller.movements.isEmpty)
                const Card(
                  elevation: 4,
                  color: AppColors.whiteOverlay,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No hay movimientos registrados'),
                  ),
                )
              else
                ...controller.movements.reversed.toList().asMap().entries.map((
                  entry,
                ) {
                  final i = entry.key;
                  final m = entry.value;
                  return Card(
                        elevation: 4,
                        color: AppColors.whiteOverlay,
                        child: ListTile(
                          leading: Icon(
                            m['type'] == 'income'
                                ? Icons.arrow_downward
                                : Icons.arrow_upward,
                            color: m['type'] == 'income'
                                ? Colors.green
                                : Colors.red,
                          ),
                          title: Text(
                            m['description']?.toString().isNotEmpty == true
                                ? m['description'].toString()
                                : (m['type'] == 'income' ? 'Ingreso' : 'Gasto'),
                          ),
                          subtitle: Text('Método: ${m['method']}'),
                          trailing: Text(
                            '\$${((m['amount'] ?? 0) as num).toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: m['type'] == 'income'
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                        ),
                      )
                      .animate()
                      .fadeIn(
                        delay: Duration(milliseconds: 40 * (i % 20)),
                        duration: 300.ms,
                      )
                      .slideX(
                        begin: -0.1,
                        end: 0,
                        delay: Duration(milliseconds: 40 * (i % 20)),
                        duration: 300.ms,
                        curve: Curves.easeOut,
                      );
                }),
            ],
          ),
        );
      },
    );
  }
}

// ─── Tab 2: Historial de cajas ────────────────────────────────────────────────

class _HistorialTab extends StatelessWidget {
  const _HistorialTab();

  String _formatDate(String? iso) {
    if (iso == null) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/'
          '${dt.year}  '
          '${dt.hour.toString().padLeft(2, '0')}:'
          '${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }

  /// Devuelve 'YYYY-WW' a partir de una fecha ISO.
  String _isoWeek(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      // Número de semana del año (00-53)
      final dayOfYear = int.parse(
        '${dt.difference(DateTime(dt.year, 1, 1)).inDays + 1}',
      );
      final week = ((dayOfYear - dt.weekday + 10) ~/ 7).toString().padLeft(
        2,
        '0',
      );
      return '${dt.year}-$week';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CashController>(
      builder: (context, controller, _) {
        if (controller.isLoadingHistory) {
          return const Center(child: CircularProgressIndicator());
        }

        final groupBy = controller.historyGroupBy;

        return RefreshIndicator(
          onRefresh: controller.loadHistory,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const SizedBox(height: 16),

              // ── Chips de agrupación ────────────────────────────────────
              Wrap(
                spacing: 8,
                children: [
                  for (final opt in [
                    ('year', 'Año'),
                    ('month', 'Mes'),
                    ('week', 'Semana'),
                  ])
                    ChoiceChip(
                      label: Text(opt.$2),
                      selected: groupBy == opt.$1,
                      onSelected: (_) => controller.setHistoryGroupBy(opt.$1),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Filtro por año (visible en modo mes/semana) ────────────
              if (groupBy != 'year' &&
                  controller.historyAvailableYears.isNotEmpty) ...[
                DropdownButtonFormField<String>(
                  elevation: 4,
                  value: controller.historyYear,
                  decoration: InputDecoration(
                    labelText: 'Año',
                    filled: true,
                    fillColor: AppColors.whiteOverlay,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 0,
                      horizontal: 12,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todos')),
                    ...controller.historyAvailableYears.map(
                      (y) => DropdownMenuItem(value: y, child: Text(y)),
                    ),
                  ],
                  onChanged: controller.setHistoryYear,
                ),
                const SizedBox(height: 12),
              ],

              // ── Filtro adicional por mes (modo mes) ────────────────────
              if (groupBy == 'month') ...[
                _MonthPicker(
                  year: controller.historyYear,
                  selected: controller.historyMonth,
                  onChanged: controller.setHistoryMonth,
                ),
                const SizedBox(height: 12),
              ],

              // ── Filtro adicional por semana (modo semana) ──────────────
              if (groupBy == 'week') ...[
                _WeekPicker(
                  year: controller.historyYear,
                  selected: controller.historyWeek,
                  sessions: controller.historySessions,
                  isoWeekFn: _isoWeek,
                  onChanged: controller.setHistoryWeek,
                ),
                const SizedBox(height: 12),
              ],

              // ── Lista de sesiones ──────────────────────────────────────
              if (controller.historySessions.isEmpty)
                const Card(
                  elevation: 4,
                  color: AppColors.whiteOverlay,
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No hay cajas en este período'),
                  ),
                )
              else
                ...controller.historySessions.map(
                  (s) =>
                      _HistorySessionCard(session: s, formatDate: _formatDate),
                ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Card de sesión histórica ─────────────────────────────────────────────────

class _HistorySessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final String Function(String?) formatDate;

  const _HistorySessionCard({required this.session, required this.formatDate});

  @override
  Widget build(BuildContext context) {
    final income = (session['total_income'] as num).toDouble();
    final expense = (session['total_expense'] as num).toDouble();
    final balance = income - expense;
    final openedByName = session['opened_by_name']?.toString() ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: Colors.green.shade50,
          child: const Icon(Icons.receipt_long, color: Colors.green),
        ),
        title: Text(
          formatDate(session['opened_at'] as String?),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Balance: \$${balance.toStringAsFixed(2)}',
          style: TextStyle(
            color: balance >= 0 ? Colors.green : Colors.red,
            fontWeight: FontWeight.w500,
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(),
                _InfoRow(
                  label: 'Apertura',
                  value:
                      '\$${((session['opening_amount'] ?? 0) as num).toStringAsFixed(2)}',
                ),
                _InfoRow(
                  label: 'Cierre',
                  value:
                      '\$${((session['closing_amount'] ?? 0) as num).toStringAsFixed(2)}',
                ),
                _InfoRow(
                  label: 'Ingresos',
                  value: '\$${income.toStringAsFixed(2)}',
                ),
                _InfoRow(
                  label: 'Egresos',
                  value: '\$${expense.toStringAsFixed(2)}',
                ),
                _InfoRow(
                  label: 'Cerrada',
                  value: formatDate(session['closed_at'] as String?),
                ),
                if (openedByName.isNotEmpty)
                  _InfoRow(label: 'Cajero', value: openedByName),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              '$label:',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Picker de mes ────────────────────────────────────────────────────────────

class _MonthPicker extends StatelessWidget {
  final String? year;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _MonthPicker({
    required this.year,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const months = [
      '01',
      '02',
      '03',
      '04',
      '05',
      '06',
      '07',
      '08',
      '09',
      '10',
      '11',
      '12',
    ];
    const monthNames = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];

    final effectiveYear = year ?? DateTime.now().year.toString();

    final items = List.generate(
      months.length,
      (i) => DropdownMenuItem<String>(
        value: '$effectiveYear-${months[i]}',
        child: Text(monthNames[i]),
      ),
    );

    final currentValue =
        (selected != null && selected!.startsWith(effectiveYear))
        ? selected
        : null;

    return DropdownButtonFormField<String>(
      elevation: 4,
      value: currentValue,
      decoration: InputDecoration(
        labelText: 'Mes',
        filled: true,
        fillColor: AppColors.whiteOverlay,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('Todos')),
        ...items,
      ],
      onChanged: onChanged,
    );
  }
}

// ─── Picker de semana ─────────────────────────────────────────────────────────

class _WeekPicker extends StatelessWidget {
  final String? year;
  final String? selected;
  final List<Map<String, dynamic>> sessions;
  final String Function(String) isoWeekFn;
  final ValueChanged<String?> onChanged;

  const _WeekPicker({
    required this.year,
    required this.selected,
    required this.sessions,
    required this.isoWeekFn,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveYear = year ?? DateTime.now().year.toString();

    // Extraer semanas únicas del historial actual filtradas por año
    final weeksSet = <String>{};
    for (final s in sessions) {
      final openedAt = s['opened_at'] as String?;
      if (openedAt == null) continue;
      final w = isoWeekFn(openedAt);
      if (w.startsWith(effectiveYear)) weeksSet.add(w);
    }
    final weeks = weeksSet.toList()..sort();

    if (weeks.isEmpty) {
      return const Text(
        'Sin semanas disponibles para el período',
        style: TextStyle(color: Colors.grey, fontSize: 13),
      );
    }

    return DropdownButtonFormField<String>(
      value: (selected != null && weeks.contains(selected)) ? selected : null,
      decoration: InputDecoration(
        suffixStyle: const TextStyle(fontSize: 12, color: Colors.grey),
        labelText: 'Semana',
        filled: true,
        fillColor: AppColors.whiteOverlay,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('Todas')),
        ...weeks.map((w) {
          final parts = w.split('-');
          return DropdownMenuItem<String>(
            value: w,
            child: Text('Semana ${parts.last} de ${parts.first}'),
          );
        }),
      ],
      onChanged: onChanged,
    );
  }
}

// ─── Acciones delegadas (usado desde _CajaTab) ───────────────────────────────

class _CashViewActions {
  static Future<void> showOpenDialog(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = context.read<CashController>();

    List<DenominationEntry> denomEntries = [];
    double denomTotal = 0;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Abrir caja'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (ctx, setLocalState) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ingresa el efectivo inicial por denominación:',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  DenominationInputWidget(
                    onChanged: (entries, total) {
                      setLocalState(() {
                        denomEntries = entries;
                        denomTotal = total;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Abrir'),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        final session = await SessionService.getCurrentUserSession();
        final userId = session?['id'] as int?;
        final userName = [
          session?['name'] ?? '',
          session?['lastname'] ?? '',
        ].where((s) => (s as String).isNotEmpty).join(' ');
        await controller.openSession(
          denomTotal,
          openedBy: userId,
          openedByName: userName,
          denominations: denomEntries.where((e) => e.quantity > 0).toList(),
        );
        if (!context.mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('Caja abierta correctamente')),
        );
      } catch (e) {
        if (!context.mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  static Future<void> showMovementDialog(
    BuildContext context,
    String type,
  ) async {
    final amountController = TextEditingController();
    final descController = TextEditingController();
    String? selectedMethod;
    final messenger = ScaffoldMessenger.of(context);
    final controller = context.read<CashController>();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(type == 'income' ? 'Registrar ingreso' : 'Registrar gasto'),
        content: StatefulBuilder(
          builder: (ctx, setLocalState) {
            final methods = controller.paymentMethods;
            selectedMethod ??= methods.isNotEmpty
                ? methods.first['name'] as String
                : 'Efectivo';
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Monto'),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedMethod,
                  decoration: const InputDecoration(labelText: 'Método'),
                  items: methods
                      .map(
                        (m) => DropdownMenuItem<String>(
                          value: m['name'] as String,
                          child: Text(m['name'] as String),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setLocalState(() => selectedMethod = v),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: 'Descripción'),
                ),
              ],
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        final amount = double.tryParse(amountController.text.trim()) ?? 0;
        if (type == 'income') {
          await controller.addIncome(
            amount: amount,
            method: selectedMethod ?? 'Efectivo',
            description: descController.text,
          );
        } else {
          await controller.addExpense(
            amount: amount,
            method: selectedMethod ?? 'Efectivo',
            description: descController.text,
          );
        }
        if (!context.mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('Movimiento registrado')),
        );
      } catch (e) {
        if (!context.mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }

  static Future<void> showCloseDialog(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = context.read<CashController>();

    List<DenominationEntry> denomEntries = [];
    double denomTotal = 0;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cerrar caja'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (ctx, setLocalState) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Cuenta el efectivo físico al cierre:',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  DenominationInputWidget(
                    onChanged: (entries, total) {
                      setLocalState(() {
                        denomEntries = entries;
                        denomTotal = total;
                      });
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );

    if (ok == true) {
      try {
        await controller.closeSession(
          denomTotal,
          denominations: denomEntries.where((e) => e.quantity > 0).toList(),
        );
        if (!context.mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('Caja cerrada correctamente')),
        );
      } catch (e) {
        if (!context.mounted) return;
        messenger.showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    }
  }
}

// ─── Widget: info de quién abrió la caja ─────────────────────────────────────

class _CashSessionInfo extends StatelessWidget {
  final Map<String, dynamic> session;
  const _CashSessionInfo({required this.session});

  @override
  Widget build(BuildContext context) {
    final openedByName = (session['opened_by_name'] as String?) ?? '';
    final openedAt = session['opened_at'] as String?;

    String timeStr = '';
    if (openedAt != null) {
      try {
        final dt = DateTime.parse(openedAt).toLocal();
        timeStr =
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) {}
    }

    if (openedByName.isEmpty && timeStr.isEmpty) return const SizedBox.shrink();

    return Row(
      children: [
        const Icon(Icons.person_outline, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            [
              if (openedByName.isNotEmpty) 'Abierta por: $openedByName',
              if (timeStr.isNotEmpty) 'a las $timeStr',
            ].join(' '),
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
      ],
    );
  }
}
