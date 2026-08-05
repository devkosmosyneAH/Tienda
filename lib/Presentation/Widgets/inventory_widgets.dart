import 'package:flutter/material.dart';
import 'package:tienda/Presentation/Hooks/use_currency_formatter.dart';
import 'package:tienda/Presentation/Model/inventory_model.dart';

/// Tarjeta de Resumen de Inversión
class InventoryInvestmentCard extends StatelessWidget {
  final InventorySummary summary;

  const InventoryInvestmentCard({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '💰 Inversión en Bodega',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Grid de métricas principales
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              children: [
                _MetricTile(
                  icon: '💵',
                  label: 'Inversión Total',
                  value: CurrencyFormatter.formatCurrency(
                    summary.totalInvested,
                  ),
                  subValue: '${summary.totalUnits} unidades',
                ),
                _MetricTile(
                  icon: '📈',
                  label: 'Ganancia Potencial',
                  value: CurrencyFormatter.formatCurrency(
                    summary.totalPotentialGain,
                  ),
                  subValue: 'Si se vende todo',
                  valueColor: Colors.green,
                ),
                _MetricTile(
                  icon: '📊',
                  label: 'ROI Potencial',
                  value: '${summary.potentialROI.toStringAsFixed(1)}%',
                  subValue: 'Retorno inversión',
                  valueColor: Colors.blue,
                ),
                _MetricTile(
                  icon: '🎯',
                  label: 'Margen Promedio',
                  value: '${summary.averageMarginPercent.toStringAsFixed(1)}%',
                  subValue: 'Ganancia por unidad',
                  valueColor: Colors.purple,
                ),
              ],
            ),
            const Divider(height: 24),
            // Detalle de productos
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _DetailRow(
                  label: 'Total de Productos',
                  value: '${summary.totalProducts}',
                ),
                _DetailRow(
                  label: 'Stock Bajo',
                  value: '${summary.lowStockCount}',
                  valueColor: Colors.red,
                ),
                _DetailRow(
                  label: 'Valor Promedio/Producto',
                  value: CurrencyFormatter.formatCurrencyNoSymbol(
                    summary.averageProductValue,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de Métrica Individual
class _MetricTile extends StatefulWidget {
  final String icon;
  final String label;
  final String value;
  final String subValue;
  final Color? valueColor;

  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.subValue,
    this.valueColor,
  });

  @override
  State<_MetricTile> createState() => _MetricTileState();
}

class _MetricTileState extends State<_MetricTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _fade = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
    _scale = Tween<double>(
      begin: 0.75,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack));
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(widget.icon, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  widget.value,
                  key: ValueKey(widget.value),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: widget.valueColor,
                  ),
                ),
              ),
              Text(
                widget.subValue,
                style: const TextStyle(fontSize: 10, color: Colors.grey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila de Detalle
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DetailRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

/// Tarjeta de Producto con Detalles de Inversión
class InventoryProductCard extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback onEditStock;
  final VoidCallback onTransfer;

  const InventoryProductCard({
    super.key,
    required this.item,
    required this.onEditStock,
    required this.onTransfer,
  });

  @override
  Widget build(BuildContext context) {
    final stockColor = item.isLowStock ? Colors.red : Colors.green;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: stockColor.withValues(alpha: 0.15),
          child: Text(
            item.quantity.toString(),
            style: TextStyle(
              color: stockColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        title: Text(
          item.name,
          style: const TextStyle(fontWeight: FontWeight.bold),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          'SKU: ${item.sku} · ${item.category}',
          style: const TextStyle(fontSize: 11),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: _SaleabilityBadge(score: item.saleabilityScore),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Información de precios
                const Text(
                  '💲 Información de Precios',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _PriceInfo(
                      label: 'Costo Unitario',
                      value: CurrencyFormatter.formatCurrency(item.costPrice),
                    ),
                    _PriceInfo(
                      label: 'Venta Unitaria',
                      value: CurrencyFormatter.formatCurrency(item.sellPrice),
                    ),
                    _PriceInfo(
                      label: 'Margen/Unidad',
                      value: CurrencyFormatter.formatCurrency(
                        item.marginPerUnit,
                      ),
                      valueColor: Colors.green,
                    ),
                  ],
                ),
                const Divider(height: 24),
                // Inversión en Bodega
                const Text(
                  '📦 Inversión en Bodega',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _InvestmentInfo(
                      icon: '💰',
                      label: 'Inversión Total',
                      value: CurrencyFormatter.formatCurrency(
                        item.investmentValue,
                      ),
                    ),
                    _InvestmentInfo(
                      icon: '📈',
                      label: 'Ganancia Potencial',
                      value: CurrencyFormatter.formatCurrency(
                        item.potentialGain,
                      ),
                      valueColor: Colors.green,
                    ),
                    _InvestmentInfo(
                      icon: '📊',
                      label: 'Margen %',
                      value: '${item.marginPercent.toStringAsFixed(1)}%',
                      valueColor: Colors.blue,
                    ),
                  ],
                ),
                const Divider(height: 24),
                // Estadísticas de venta
                const Text(
                  '📣 Estadísticas de Venta',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _StatInfo(
                      label: 'Unidades Vendidas',
                      value: '${item.unitsSold}',
                    ),
                    _StatInfo(
                      label: 'Rotación',
                      value: '${item.rotationRate.toStringAsFixed(2)}x',
                    ),
                    _StatInfo(
                      label: 'Vendibilidad',
                      value: '${item.saleabilityScore}/100',
                      color: _getSaleabilityColor(item.saleabilityScore),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Botones de acción
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onTransfer,
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Transferir'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: onEditStock,
                      icon: const Icon(Icons.edit),
                      label: const Text('Editar Stock'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Badge de Vendibilidad
class _SaleabilityBadge extends StatelessWidget {
  final int score;

  const _SaleabilityBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getSaleabilityColor(score).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$score',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: _getSaleabilityColor(score),
          fontSize: 12,
        ),
      ),
    );
  }
}

/// Obtiene color según score de vendibilidad
Color _getSaleabilityColor(int score) {
  if (score >= 80) return Colors.green;
  if (score >= 60) return Colors.orange;
  if (score >= 40) return Colors.amber;
  return Colors.red;
}

/// Widget de información de precio
class _PriceInfo extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _PriceInfo({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

/// Widget de información de inversión
class _InvestmentInfo extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final Color? valueColor;

  const _InvestmentInfo({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: valueColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Widget de información de estadísticas
class _StatInfo extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const _StatInfo({required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: color,
          ),
        ),
      ],
    );
  }
}

/// Widget de Top Sellers / Top Margen
class TopProductsList extends StatelessWidget {
  final List<InventoryItem> items;
  final String title;
  final String metric; // 'sales' o 'margin'

  const TopProductsList({
    super.key,
    required this.items,
    required this.title,
    this.metric = 'sales',
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...items.asMap().entries.map((entry) {
              final index = entry.key + 1;
              final item = entry.value;

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    // Posición
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _getPositionColor(index).withValues(alpha: 0.2),
                      ),
                      child: Center(
                        child: Text(
                          '#$index',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getPositionColor(index),
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Producto
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Stock: ${item.quantity} · ${item.category}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Métrica
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          metric == 'sales'
                              ? '${item.unitsSold} vendidas'
                              : '${item.marginPercent.toStringAsFixed(1)}% margen',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          CurrencyFormatter.formatCurrency(
                            metric == 'sales'
                                ? item.investmentValue
                                : item.potentialGain,
                          ),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Color _getPositionColor(int position) {
    switch (position) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.grey;
      case 3:
        return Colors.orange;
      default:
        return Colors.blue;
    }
  }
}
