part of '../../View/Cash/cash_view.dart';

class CashHistoryTab extends StatelessWidget {
  const CashHistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CashController>(
      builder: (context, controller, _) {
        if (controller.isLoadingHistory) {
          return const _HistoryLoadingState();
        }

        final groupBy = controller.historyGroupBy;
        return RefreshIndicator(
          onRefresh: controller.loadHistory,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 850;
              return ListView(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 32 : 16,
                  vertical: 24,
                ),
                children: [
                  _HistoryHeader(controller: controller, isDesktop: isDesktop),
                  const SizedBox(height: 24),
                  _HistoryFilters(
                    controller: controller,
                    groupBy: groupBy,
                    isDesktop: isDesktop,
                  ),
                  const SizedBox(height: 24),
                  _HistoryPeriodHeading(
                    groupBy: groupBy,
                    year: controller.historyYear,
                    month: controller.historyMonth,
                    week: controller.historyWeek,
                    count: controller.historySessions.length,
                  ),
                  const SizedBox(height: 12),
                  if (controller.historySessions.isEmpty)
                    const _HistoryEmptyState()
                  else
                    ...controller.historySessions.map(
                      (s) => _HistorySessionCard(
                        session: s,
                        formatDate: _formatDate,
                      ),
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  String _formatDate(String? iso) {
    if (iso == null) return '-';
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/${dt.year}  '
          '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({required this.controller, required this.isDesktop});

  final CashController controller;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final store = _HistoryDropdown<int>(
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
    );

    if (isDesktop) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Expanded(child: _HistoryTitle()),
          SizedBox(width: 220, child: store),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [const _HistoryTitle(), const SizedBox(height: 16), store],
    );
  }
}

class _HistoryTitle extends StatelessWidget {
  const _HistoryTitle();

  @override
  Widget build(BuildContext context) => const Row(
    children: [
      Icon(Icons.receipt_long_outlined, color: AppColors.blackOverlay),
      SizedBox(width: 12),
      Text(
        'HISTORIAL DE CAJA',
        style: TextStyle(
          color: AppColors.primaryLogo,
          fontSize: 21,
          fontWeight: FontWeight.w800,
          letterSpacing: 0,
        ),
      ),
    ],
  );
}

class _HistoryFilters extends StatelessWidget {
  const _HistoryFilters({
    required this.controller,
    required this.groupBy,
    required this.isDesktop,
  });

  final CashController controller;
  final String groupBy;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final year =
        groupBy != 'year' && controller.historyAvailableYears.isNotEmpty
        ? _HistoryDropdown<String>(
            label: 'Año',
            value: controller.historyYear,
            items: [
              const DropdownMenuItem(value: null, child: Text('Todos')),
              ...controller.historyAvailableYears.map(
                (y) => DropdownMenuItem(value: y, child: Text(y)),
              ),
            ],
            onChanged: controller.setHistoryYear,
          )
        : null;
    final month = groupBy == 'month'
        ? _MonthPicker(
            year: controller.historyYear,
            selected: controller.historyMonth,
            onChanged: controller.setHistoryMonth,
          )
        : null;
    final week = groupBy == 'week'
        ? _WeekPicker(
            year: controller.historyYear,
            selected: controller.historyWeek,
            sessions: controller.historySessions,
            isoWeekFn: _isoWeek,
            onChanged: controller.setHistoryWeek,
          )
        : null;

    final dynamicFilters = [year, month, week].whereType<Widget>().toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'AGRUPAR POR',
          style: TextStyle(
            color: AppColors.mediumGray,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 8),
        _HistorySegmentedControl(
          value: groupBy,
          onChanged: controller.setHistoryGroupBy,
        ),
        if (dynamicFilters.isNotEmpty) ...[
          const SizedBox(height: 16),
          if (isDesktop)
            Row(
              children: [
                for (var i = 0; i < dynamicFilters.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: dynamicFilters[i]),
                ],
              ],
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < dynamicFilters.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  dynamicFilters[i],
                ],
              ],
            ),
        ],
      ],
    );
  }
}

class _HistorySegmentedControl extends StatelessWidget {
  const _HistorySegmentedControl({
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.gery100,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (final option in [
            ('year', 'Año'),
            ('month', 'Mes'),
            ('week', 'Semana'),
          ])
            Expanded(
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => onChanged(option.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: value == option.$1
                        ? AppColors.blackOverlay
                        : AppColors.gery100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    option.$2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: value == option.$1
                          ? AppColors.whiteOverlay
                          : AppColors.darkGray,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryPeriodHeading extends StatelessWidget {
  const _HistoryPeriodHeading({
    required this.groupBy,
    required this.year,
    required this.month,
    required this.week,
    required this.count,
  });

  final String groupBy;
  final String? year;
  final String? month;
  final String? week;
  final int count;

  @override
  Widget build(BuildContext context) {
    final period = switch (groupBy) {
      'year' => year ?? 'Todos los años',
      'month' => month ?? (year ?? 'Todos los meses'),
      _ => week ?? (year ?? 'Todas las semanas'),
    };
    return Row(
      children: [
        Expanded(
          child: Text(
            period,
            style: const TextStyle(
              color: AppColors.secondaryLogo,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Text(
          '$count ${count == 1 ? 'caja' : 'cajas'}',
          style: const TextStyle(
            color: AppColors.mediumGray,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _HistoryDropdown<T> extends StatelessWidget {
  const _HistoryDropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T? value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: AppColors.mediumGray),
          filled: true,
          fillColor: AppColors.whiteOverlay,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.greyOverlay),
          ),
        ),
        child: const Text(
          'Cargando...',
          style: TextStyle(color: AppColors.mediumGray, fontSize: 14),
        ),
      );
    }

    return FilterDropdown<T>(
      label: label,
      value: value,
      items: items,
      onChanged: onChanged,
    );
  }
}

class _HistorySessionCard extends StatelessWidget {
  const _HistorySessionCard({required this.session, required this.formatDate});

  final Map<String, dynamic> session;
  final String Function(String?) formatDate;

  @override
  Widget build(BuildContext context) {
    final income = (session['total_income'] as num?)?.toDouble() ?? 0;
    final expense = (session['total_expense'] as num?)?.toDouble() ?? 0;
    final opening = (session['opening_amount'] as num?)?.toDouble() ?? 0;
    final closing = (session['closing_amount'] as num?)?.toDouble();
    final openedAt = session['opened_at'] as String?;
    final closedAt = session['closed_at'] as String?;
    final openedBy = session['opened_by_name']?.toString();
    final openedDate = _dateLabel(openedAt);
    final openedTime = _timeLabel(openedAt);
    final closedTime = _timeLabel(closedAt);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: AppColors.whiteOverlay,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.greyOverlay),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        collapsedShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        leading: const Icon(
          Icons.point_of_sale_outlined,
          color: AppColors.blackOverlay,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                openedDate,
                style: const TextStyle(
                  color: AppColors.primaryLogo,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _ClosedBadge(),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            '$openedTime — $closedTime',
            style: const TextStyle(color: AppColors.mediumGray, fontSize: 13),
          ),
        ),
        children: [
          const Divider(color: AppColors.greyOverlay),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MoneyItem(label: 'Apertura', value: opening),
              _MoneyItem(label: 'Ingresos', value: income, positive: true),
              _MoneyItem(label: 'Egresos', value: expense, negative: true),
              _MoneyItem(
                label: 'Saldo final',
                value: closing,
                positive: closing != null && closing >= 0,
              ),
              _MoneyItem(
                label: 'Diferencia',
                value: (session['difference'] as num?)?.toDouble(),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(
                Icons.person_outline,
                size: 18,
                color: AppColors.mediumGray,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  openedBy == null || openedBy.isEmpty
                      ? 'Sin usuario registrado'
                      : openedBy,
                  style: const TextStyle(
                    color: AppColors.darkGray,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Text(
                'Ver detalle →',
                style: TextStyle(
                  color: AppColors.blackOverlay,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ClosedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: AppColors.lightBlue,
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 15,
          color: AppColors.blackOverlay,
        ),
        SizedBox(width: 4),
        Text(
          'CERRADA',
          style: TextStyle(
            color: AppColors.blackOverlay,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _MoneyItem extends StatelessWidget {
  const _MoneyItem({
    required this.label,
    required this.value,
    this.positive = false,
    this.negative = false,
  });

  final String label;
  final double? value;
  final bool positive;
  final bool negative;

  @override
  Widget build(BuildContext context) {
    final color = negative
        ? AppColors.primaryRed
        : (positive ? AppColors.blackOverlay : AppColors.primaryLogo);
    return SizedBox(
      width: 132,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: AppColors.mediumGray,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value == null ? '-' : '\$${value!.toStringAsFixed(2)}',
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryEmptyState extends StatelessWidget {
  const _HistoryEmptyState();

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    color: AppColors.whiteOverlay,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: const BorderSide(color: AppColors.greyOverlay),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
      child: Column(
        children: [
          const Icon(
            Icons.inbox_outlined,
            size: 42,
            color: AppColors.blackOverlay,
          ),
          const SizedBox(height: 14),
          const Text(
            'No hay cajas en este período',
            style: TextStyle(
              color: AppColors.primaryLogo,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Prueba cambiando el período o el local.',
            style: TextStyle(color: AppColors.mediumGray),
          ),
        ],
      ),
    ),
  );
}

class _HistoryLoadingState extends StatelessWidget {
  const _HistoryLoadingState();

  @override
  Widget build(BuildContext context) => const Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            color: AppColors.blackOverlay,
          ),
        ),
        SizedBox(height: 14),
        Text(
          'Cargando historial...',
          style: TextStyle(color: AppColors.mediumGray),
        ),
      ],
    ),
  );
}

String _dateLabel(String? iso) {
  if (iso == null) return '-';
  try {
    final date = DateTime.parse(iso).toLocal();
    const months = [
      'ENE',
      'FEB',
      'MAR',
      'ABR',
      'MAY',
      'JUN',
      'JUL',
      'AGO',
      'SEP',
      'OCT',
      'NOV',
      'DIC',
    ];
    return '${date.day.toString().padLeft(2, '0')} ${months[date.month - 1]} ${date.year}';
  } catch (_) {
    return iso;
  }
}

String _timeLabel(String? iso) {
  if (iso == null) return '-';
  try {
    final date = DateTime.parse(iso).toLocal();
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  } catch (_) {
    return '-';
  }
}

String _isoWeek(String iso) {
  try {
    final date = DateTime.parse(iso).toLocal();
    final dayOfYear = date.difference(DateTime(date.year, 1, 1)).inDays + 1;
    final week = ((dayOfYear - date.weekday + 10) ~/ 7).toString().padLeft(
      2,
      '0',
    );
    return '${date.year}-$week';
  } catch (_) {
    return '';
  }
}
