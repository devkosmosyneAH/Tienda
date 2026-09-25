import 'package:tienda/Presentation/Controller/cash_controller.dart';
import 'package:tienda/Presentation/Model/cash_model.dart';
import 'package:tienda/Presentation/Renders/responsive_helper.dart';
import 'package:tienda/Presentation/Services/session_service.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:tienda/Presentation/Widgets/cash_widgets.dart';
import 'package:tienda/Presentation/Widgets/cash_stores_status.dart';
import 'package:tienda/Presentation/Widgets/Products/filter_dropdown.dart';
import 'package:tienda/Presentation/Widgets/Products/shared_inputs.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

part '../../Widgets/Cash/cash_current_tab.dart';
part '../../Widgets/Cash/cash_history_tab.dart';

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
                  color: AppColors.primaryLogo,
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
                'Gestión de Caja',
                style: TextStyle(color: AppColors.whiteOverlay),
              ),
              actions: [
                Consumer<CashController>(
                  builder: (context, controller, _) {
                    return Container(
                      margin: const EdgeInsets.only(right: 16),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLogo.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: CashStoresStatus(
                        controller: controller,
                        isMobile: MediaQuery.of(context).size.width < 600,
                      ),
                    );
                  },
                ),
              ],
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
        children: const [CashCurrentTab(), CashHistoryTab()],
      ),
    );
  }
}

// ─── Tab 1: Caja actual ───────────────────────────────────────────────────────

// ignore: unused_element
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
        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 900;
              return ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : 16,
                  vertical: 20,
                ),
                children: [
                  _CashSectionHeader(
                    controller: controller,
                    onStoreChanged: (value) {
                      if (value != null) controller.selectStore(value);
                    },
                  ),
                  const SizedBox(height: 16),
                  _CashStatusCard(controller: controller, summary: summary),
                  if (controller.hasOpenSession) ...[
                    const SizedBox(height: 16),
                    _CashKpiGrid(summary: summary),
                    const SizedBox(height: 20),
                    if (isDesktop)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _MovementsCard(
                              movements: controller.movements,
                            ),
                          ),
                          const SizedBox(width: 20),
                          SizedBox(
                            width: 320,
                            child: _CashSummaryCard(
                              summary: summary,
                              breakdown: controller.openingBreakdown,
                            ),
                          ),
                        ],
                      )
                    else ...[
                      _MovementsCard(movements: controller.movements),
                      const SizedBox(height: 16),
                      _CashSummaryCard(
                        summary: summary,
                        breakdown: controller.openingBreakdown,
                      ),
                    ],
                  ],
                ],
              );
            },
          ),
        );
      },
    );
  }
}

String _cashAmount(Object? value) =>
    '\$${((value ?? 0) as num).toDouble().toStringAsFixed(2)}';

class _CashSectionHeader extends StatelessWidget {
  const _CashSectionHeader({
    required this.controller,
    required this.onStoreChanged,
  });

  final CashController controller;
  final ValueChanged<int?> onStoreChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.storefront_outlined, color: AppColors.blackOverlay),
        const SizedBox(width: 10),
        Expanded(
          child: FilterDropdown<int>(
            label: 'Establecimiento / caja',
            value: controller.selectedStoreId,
            items: controller.stores
                .map(
                  (store) => DropdownMenuItem<int>(
                    value: (store['id'] as num).toInt(),
                    child: Text(store['name'] as String),
                  ),
                )
                .toList(),
            onChanged: onStoreChanged,
          ),
        ),
      ],
    );
  }
}

class _CashStatusCard extends StatelessWidget {
  const _CashStatusCard({required this.controller, required this.summary});

  final CashController controller;
  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) {
    final isOpen = controller.hasOpenSession;
    final opening = controller.activeSession?['opening_amount'];
    return _CashSurface(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: isOpen ? AppColors.darkGreen : AppColors.primaryRed,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  isOpen ? 'CAJA ABIERTA' : 'CAJA CERRADA',
                  style: const TextStyle(
                    color: AppColors.primaryLogo,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              _cashAmount(isOpen ? summary['expected_balance'] : opening),
              style: const TextStyle(
                color: AppColors.primaryLogo,
                fontSize: 36,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isOpen ? 'Saldo actual' : 'Lista para iniciar operaciones',
              style: const TextStyle(color: AppColors.mediumGray, fontSize: 14),
            ),
            if (controller.activeSession != null) ...[
              const SizedBox(height: 12),
              Text(
                'Apertura: ${_cashAmount(opening)}',
                style: const TextStyle(color: AppColors.darkGray),
              ),
              const SizedBox(height: 4),
              _CashSessionInfo(session: controller.activeSession!),
            ],
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (!isOpen)
                  _CashActionButton(
                    label: 'Abrir caja',
                    icon: Icons.lock_open_outlined,
                    color: AppColors.primaryBlue,
                    onPressed: () => _CashViewActions.showOpenDialog(context),
                  ),
                if (isOpen) ...[
                  _CashActionButton(
                    label: 'Ingreso',
                    icon: Icons.add,
                    color: AppColors.darkGreen,
                    onPressed: () =>
                        _CashViewActions.showMovementDialog(context, 'income'),
                  ),
                  _CashActionButton(
                    label: 'Gasto',
                    icon: Icons.remove,
                    color: AppColors.primaryRed,
                    onPressed: () =>
                        _CashViewActions.showMovementDialog(context, 'expense'),
                  ),
                  _CashActionButton(
                    label: 'Cerrar caja',
                    icon: Icons.lock_outline,
                    color: AppColors.primaryLogo,
                    onPressed: () => _CashViewActions.showCloseDialog(context),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CashActionButton extends StatelessWidget {
  const _CashActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        foregroundColor: AppColors.whiteOverlay,
        backgroundColor: color,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _CashKpiGrid extends StatelessWidget {
  const _CashKpiGrid({required this.summary});
  final Map<String, dynamic> summary;

  @override
  Widget build(BuildContext context) {
    final kpis = [
      ('Ingresos', 'total_income', Icons.trending_up, AppColors.darkGreen),
      ('Egresos', 'total_expense', Icons.trending_down, AppColors.primaryRed),
      (
        'Saldo esperado',
        'expected_balance',
        Icons.account_balance_wallet_outlined,
        AppColors.primaryLogo,
      ),
      (
        'Caja física',
        'physical_cash',
        Icons.payments_outlined,
        AppColors.primaryBlue,
      ),
      (
        'Caja virtual',
        'virtual_balance',
        Icons.credit_card_outlined,
        AppColors.primaryLogo,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000
            ? 5
            : constraints.maxWidth >= 560
            ? 2
            : 1;
        const spacing = 12.0;
        final itemWidth = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            ...kpis.map(
              (kpi) => SizedBox(
                width: itemWidth,
                child: _KpiCard(
                  label: kpi.$1,
                  value: _cashAmount(summary[kpi.$2]),
                  icon: kpi.$3,
                  color: kpi.$4,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return _CashSurface(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(height: 8),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: AppColors.mediumGray,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MovementsCard extends StatelessWidget {
  const _MovementsCard({required this.movements});
  final List<Map<String, dynamic>> movements;

  @override
  Widget build(BuildContext context) {
    return _CashSurface(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _CashCardTitle(title: 'Movimientos', icon: Icons.swap_vert),
            const SizedBox(height: 8),
            if (movements.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(
                  child: Text(
                    'Sin movimientos registrados',
                    style: TextStyle(color: AppColors.mediumGray),
                  ),
                ),
              )
            else
              ...movements.reversed.toList().asMap().entries.map((entry) {
                final movement = entry.value;
                final isIncome = movement['type'] == 'income';
                return _MovementRow(
                  movement: movement,
                  isIncome: isIncome,
                ).animate().fadeIn(
                  delay: Duration(milliseconds: 35 * (entry.key % 20)),
                  duration: 250.ms,
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.movement, required this.isIncome});
  final Map<String, dynamic> movement;
  final bool isIncome;

  String _time() {
    final raw = movement['created_at']?.toString();
    if (raw == null) return '';
    try {
      final date = DateTime.parse(raw).toLocal();
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = isIncome ? AppColors.primaryBlue : AppColors.primaryRed;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.gery100)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isIncome ? Icons.add : Icons.remove,
              color: color,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  movement['description']?.toString().isNotEmpty == true
                      ? movement['description'].toString()
                      : isIncome
                      ? 'Ingreso'
                      : 'Gasto',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkGray,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${movement['method'] ?? '-'}${_time().isNotEmpty ? ' · ${_time()}' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.mediumGray,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${isIncome ? '+' : '-'}${_cashAmount(movement['amount'])}',
            style: TextStyle(color: color, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _CashSummaryCard extends StatelessWidget {
  const _CashSummaryCard({required this.summary, required this.breakdown});
  final Map<String, dynamic> summary;
  final CashBreakdown? breakdown;

  @override
  Widget build(BuildContext context) {
    final byMethod = (summary['by_method'] as List?) ?? [];
    return Column(
      children: [
        _CashSurface(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _CashCardTitle(
                  title: 'Resumen de caja',
                  icon: Icons.assessment_outlined,
                ),
                const SizedBox(height: 14),
                _SummaryLine(
                  label: 'Caja física',
                  value: _cashAmount(summary['physical_cash']),
                ),
                _SummaryLine(
                  label: 'Caja virtual',
                  value: _cashAmount(summary['virtual_balance']),
                ),
                _SummaryLine(
                  label: 'Saldo esperado',
                  value: _cashAmount(summary['expected_balance']),
                  emphasized: true,
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.lightBlue.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'CAJA CUADRADA',
                    style: TextStyle(
                      color: AppColors.primaryBlue,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (byMethod.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const _CashCardTitle(
                    title: 'Métodos de pago',
                    icon: Icons.credit_card_outlined,
                  ),
                  const SizedBox(height: 8),
                  ...byMethod.map((row) => _PaymentMethodRow(row: row)),
                ],
              ],
            ),
          ),
        ),
        if (breakdown != null) ...[
          const SizedBox(height: 12),
          _CashSurface(
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 20),
              childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              title: const Text(
                'Desglose de apertura',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkGray,
                ),
              ),
              trailing: Text(
                _cashAmount(breakdown!.grandTotal),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryBlue,
                ),
              ),
              children: [
                CashBreakdownSummary(
                  breakdown: breakdown!,
                  title: 'Detalle de efectivo',
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _PaymentMethodRow extends StatelessWidget {
  const _PaymentMethodRow({required this.row});
  final dynamic row;

  @override
  Widget build(BuildContext context) {
    final income = (row['income'] ?? 0) as num;
    final expense = (row['expense'] ?? 0) as num;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row['method']?.toString() ?? '-',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.darkGray,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Ingresos ${_cashAmount(income)} · Egresos ${_cashAmount(expense)} · Neto ${_cashAmount(income - expense)}',
            style: const TextStyle(fontSize: 12, color: AppColors.mediumGray),
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.label,
    required this.value,
    this.emphasized = false,
  });
  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppColors.mediumGray,
            fontWeight: emphasized ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: AppColors.primaryLogo,
            fontWeight: emphasized ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    ),
  );
}

class _CashCardTitle extends StatelessWidget {
  const _CashCardTitle({required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 20, color: AppColors.primaryBlue),
      const SizedBox(width: 8),
      Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.primaryLogo,
        ),
      ),
    ],
  );
}

class _CashSurface extends StatelessWidget {
  const _CashSurface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    color: AppColors.whiteOverlay,
    elevation: 1,
    shadowColor: AppColors.greyOverlay.withValues(alpha: 0.35),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    child: child,
  );
}

// ─── Tab 2: Historial de cajas ────────────────────────────────────────────────

// ignore: unused_element
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
              // ── Selector de local ──────────────────────────────────────
              FilterDropdown<int>(
                label: 'Local',
                value: controller.selectedStoreId,
                items: controller.stores
                    .map(
                      (s) => DropdownMenuItem<int>(
                        value: (s['id'] as num).toInt(),
                        child: Text(s['name'] as String),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    controller.selectStore(value);
                    controller.loadHistory();
                  }
                },
              ),
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
                FilterDropdown<String>(
                  label: 'Año',
                  value: controller.historyYear,
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

// ignore: unused_element
class _LegacyHistorySessionCard extends StatelessWidget {
  final Map<String, dynamic> session;
  final String Function(String?) formatDate;

  const _LegacyHistorySessionCard({
    required this.session,
    required this.formatDate,
  });

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
          backgroundColor: AppColors.lightBlue.withValues(alpha: 0.35),
          child: const Icon(Icons.receipt_long, color: AppColors.primaryBlue),
        ),
        title: Text(
          formatDate(session['opened_at'] as String?),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          'Balance: \$${balance.toStringAsFixed(2)}',
          style: TextStyle(
            color: balance >= 0 ? AppColors.primaryBlue : AppColors.primaryRed,
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
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

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
              style: const TextStyle(color: AppColors.mediumGray, fontSize: 13),
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

class _MonthPicker extends StatelessWidget {
  const _MonthPicker({
    required this.year,
    required this.selected,
    required this.onChanged,
  });

  final String? year;
  final String? selected;
  final ValueChanged<String?> onChanged;

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
    final currentValue = selected != null && selected!.startsWith(effectiveYear)
        ? selected
        : null;

    return _HistoryDropdown<String>(
      label: 'Mes',
      value: currentValue,
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
        style: TextStyle(color: AppColors.mediumGray, fontSize: 13),
      );
    }

    return _HistoryDropdown<String>(
      label: 'Semana',
      value: (selected != null && weeks.contains(selected)) ? selected : null,
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
                SharedTextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  label: 'Monto',
                ),
                const SizedBox(height: 8),
                FilterDropdown<String>(
                  label: 'Método',
                  value: selectedMethod,
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
                SharedTextField(
                  controller: descController,
                  label: 'Descripción',
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
        title: const Text(
          'CIERRE DE CAJA',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.primaryLogo,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: StatefulBuilder(
              builder: (ctx, setLocalState) {
                final expected =
                    ((controller.summary?['expected_balance'] ?? 0) as num)
                        .toDouble();
                final difference = denomTotal - expected;
                final isBalanced = difference.abs() < 0.005;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CloseAmountRow(label: 'Saldo esperado', value: expected),
                    const SizedBox(height: 10),
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
                    const SizedBox(height: 12),
                    _CloseAmountRow(
                      label: 'Efectivo contado',
                      value: denomTotal,
                    ),
                    const Divider(height: 22),
                    _CloseAmountRow(
                      label: 'Diferencia',
                      value: difference,
                      color: isBalanced
                          ? AppColors.primaryBlue
                          : AppColors.primaryRed,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isBalanced ? 'CAJA CUADRADA' : 'REVISAR DIFERENCIA',
                      style: TextStyle(
                        color: isBalanced
                            ? AppColors.primaryBlue
                            : AppColors.primaryRed,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                );
              },
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
            child: const Text('Confirmar cierre'),
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

class _CloseAmountRow extends StatelessWidget {
  const _CloseAmountRow({required this.label, required this.value, this.color});

  final String label;
  final double value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: AppColors.mediumGray)),
        Text(
          _cashAmount(value),
          style: TextStyle(
            color: color ?? AppColors.primaryLogo,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ],
    );
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
        const Icon(Icons.person_outline, size: 14, color: AppColors.mediumGray),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            [
              if (openedByName.isNotEmpty) 'Abierta por: $openedByName',
              if (timeStr.isNotEmpty) 'a las $timeStr',
            ].join(' '),
            style: const TextStyle(fontSize: 12, color: AppColors.mediumGray),
          ),
        ),
      ],
    );
  }
}
