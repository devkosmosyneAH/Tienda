import 'package:tienda/Presentation/Controller/purchases_controller.dart';
import 'package:tienda/Presentation/Renders/responsive_helper.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class PurchasesView extends StatefulWidget {
  const PurchasesView({super.key});

  @override
  State<PurchasesView> createState() => _PurchasesViewState();
}

class _PurchasesViewState extends State<PurchasesView> {
  final _searchController = TextEditingController();
  final _supplierController = TextEditingController();
  final _supplierPhoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PurchasesController>().initialize();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _supplierController.dispose();
    _supplierPhoneController.dispose();
    super.dispose();
  }

  Future<void> _savePurchase() async {
    final controller = context.read<PurchasesController>();
    final messenger = ScaffoldMessenger.of(context);

    try {
      final purchaseId = await controller.savePurchase(
        supplierName: _supplierController.text.trim(),
        supplierPhone: _supplierPhoneController.text.trim(),
      );

      _supplierController.clear();
      _supplierPhoneController.clear();

      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Compra registrada correctamente #$purchaseId')),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appBarHeight = ResponsiveHelper.getAppBarHeight(context) + 48;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.whiteOverlay,
        appBar: PreferredSize(
          preferredSize: Size.fromHeight(appBarHeight),
          child: ClipRRect(
            clipBehavior: Clip.hardEdge,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(25),
            ),
            child: Container(
              decoration: const BoxDecoration(
                color: AppColors.blackOverlay,
                boxShadow: [
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
                elevation: 4,
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: AppColors.whiteOverlay,
                    size: 30,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                title: const Text(
                  'Compras · Abastecimiento',
                  style: TextStyle(fontSize: 16, color: AppColors.whiteOverlay),
                ),
                bottom: TabBar(
                  labelColor: _searchController.text.isEmpty
                      ? AppColors.whiteOverlay
                      : AppColors.mediumGray,
                  unselectedLabelColor: _searchController.text.isEmpty
                      ? AppColors.mediumGray
                      : AppColors.whiteOverlay,
                  unselectedLabelStyle: TextStyle(
                    color: _searchController.text.isEmpty
                        ? AppColors.mediumGray
                        : AppColors.whiteOverlay,
                  ),
                  indicatorColor: AppColors.whiteOverlay,
                  tabs: const [
                    Tab(
                      text: 'Nueva compra',
                      icon: Icon(Icons.add_box_outlined),
                    ),
                    Tab(
                      text: 'Historial de compras',
                      icon: Icon(Icons.history_outlined),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _NewPurchaseTab(
              searchController: _searchController,
              supplierController: _supplierController,
              supplierPhoneController: _supplierPhoneController,
              onSave: _savePurchase,
            ),
            const _PurchaseHistoryTab(),
          ],
        ),
      ),
    );
  }
}

class _NewPurchaseTab extends StatelessWidget {
  final TextEditingController searchController;
  final TextEditingController supplierController;
  final TextEditingController supplierPhoneController;
  final VoidCallback onSave;

  const _NewPurchaseTab({
    required this.searchController,
    required this.supplierController,
    required this.supplierPhoneController,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<PurchasesController>(
      builder: (context, controller, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 980;

            final catalogPanel = Card(
              color: AppColors.lightGray,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ingreso de mercadería',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Selecciona el local, agrega proveedor y suma productos para aumentar stock.',
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int>(
                            value: controller.selectedStoreId,
                            decoration: InputDecoration(
                              labelText: 'Local destino',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 15,
                              ),
                            ),
                            items: controller.stores
                                .map(
                                  (store) => DropdownMenuItem<int>(
                                    value: (store['id'] as num).toInt(),
                                    child: Text(store['name'].toString()),
                                  ),
                                )
                                .toList(),
                            onChanged: controller.selectStore,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: supplierController,
                            decoration: InputDecoration(
                              labelText: 'Proveedor opcional',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 15,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: supplierPhoneController,
                            decoration: InputDecoration(
                              labelText: 'Teléfono proveedor',
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 15,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            decoration: InputDecoration(
                              labelText: 'Buscar producto',
                              prefixIcon: Icon(Icons.search),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(25),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 15,
                              ),
                            ),
                            onChanged: controller.updateSearch,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: controller.isLoading && controller.products.isEmpty
                          ? const Center(child: CircularProgressIndicator())
                          : controller.products.isEmpty
                          ? const Center(
                              child: Text('No hay productos para comprar.'),
                            )
                          : GridView.builder(
                              gridDelegate:
                                  const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 220,
                                    mainAxisSpacing: 12,
                                    crossAxisSpacing: 12,
                                    childAspectRatio: 1.05,
                                  ),
                              itemCount: controller.products.length,
                              itemBuilder: (context, index) {
                                final product = controller.products[index];
                                final price =
                                    ((product['price'] as num?)?.toDouble()) ??
                                    0;

                                return FilledButton.tonal(
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.all(16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        backgroundColor: AppColors.threeColor,
                                      ),
                                      onPressed: () =>
                                          controller.addToCart(product),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Icon(
                                            Icons.inventory_2_outlined,
                                          ),
                                          const Spacer(),
                                          Text(
                                            product['name']?.toString() ?? '',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            'Precio ref. \$${price.toStringAsFixed(2)}',
                                          ),
                                        ],
                                      ),
                                    )
                                    .animate()
                                    .fadeIn(
                                      delay: Duration(
                                        milliseconds: 30 * (index % 20),
                                      ),
                                      duration: 280.ms,
                                    )
                                    .scale(
                                      begin: const Offset(0.9, 0.9),
                                      end: const Offset(1, 1),
                                      delay: Duration(
                                        milliseconds: 30 * (index % 20),
                                      ),
                                      duration: 280.ms,
                                      curve: Curves.easeOut,
                                    );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );

            final summaryPanel = Card(
              color: AppColors.lightGray,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Resumen de compra',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Total: \$${controller.total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: controller.cart.isEmpty
                          ? const Center(
                              child: Text('Todavía no agregas productos.'),
                            )
                          : ListView.separated(
                              itemCount: controller.cart.length,
                              separatorBuilder: (_, __) => const Divider(),
                              itemBuilder: (context, index) {
                                final item = controller.cart[index];
                                final subtotal =
                                    (item['quantity'] as int) *
                                    (item['cost'] as double);

                                return ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(item['name']?.toString() ?? ''),
                                  subtitle: Text(
                                    'Costo: \$${(item['cost'] as double).toStringAsFixed(2)} · Subtotal: \$${subtotal.toStringAsFixed(2)}',
                                  ),
                                  trailing: Wrap(
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    spacing: 4,
                                    children: [
                                      IconButton(
                                        onPressed: () =>
                                            controller.decrementQuantity(
                                              item['product_id'] as int,
                                            ),
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                        ),
                                      ),
                                      Text('${item['quantity']}'),
                                      IconButton(
                                        onPressed: () =>
                                            controller.incrementQuantity(
                                              item['product_id'] as int,
                                            ),
                                        icon: const Icon(
                                          Icons.add_circle_outline,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Editar costo',
                                        onPressed: () => _showCostDialog(
                                          context,
                                          controller,
                                          item['product_id'] as int,
                                          (item['cost'] as double),
                                        ),
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: controller.cart.isEmpty ? null : onSave,
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.save_outlined),
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Guardar compra'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );

            return Padding(
              padding: const EdgeInsets.all(16),
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: catalogPanel),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: summaryPanel),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(child: catalogPanel),
                        const SizedBox(height: 16),
                        SizedBox(height: 360, child: summaryPanel),
                      ],
                    ),
            );
          },
        );
      },
    );
  }

  Future<void> _showCostDialog(
    BuildContext context,
    PurchasesController controller,
    int productId,
    double currentCost,
  ) async {
    final costController = TextEditingController(
      text: currentCost.toStringAsFixed(2),
    );

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Actualizar costo'),
        content: TextField(
          controller: costController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Costo unitario',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final newCost =
                  double.tryParse(costController.text.trim()) ?? currentCost;
              controller.updateCost(productId, newCost);
              Navigator.pop(context);
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}

class _PurchaseHistoryTab extends StatelessWidget {
  const _PurchaseHistoryTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<PurchasesController>(
      builder: (context, controller, _) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<int>(
                          value: controller.selectedStoreId,
                          decoration: const InputDecoration(
                            labelText: 'Local',
                            border: OutlineInputBorder(),
                          ),
                          items: controller.stores
                              .map(
                                (store) => DropdownMenuItem<int>(
                                  value: (store['id'] as num).toInt(),
                                  child: Text(store['name'].toString()),
                                ),
                              )
                              .toList(),
                          onChanged: controller.selectStore,
                        ),
                      ),
                      SizedBox(
                        width: 220,
                        child: DropdownButtonFormField<int?>(
                          value: controller.historySupplierId,
                          decoration: const InputDecoration(
                            labelText: 'Proveedor',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('Todos'),
                            ),
                            ...controller.suppliers.map(
                              (supplier) => DropdownMenuItem<int?>(
                                value: (supplier['id'] as num).toInt(),
                                child: Text(supplier['name'].toString()),
                              ),
                            ),
                          ],
                          onChanged: controller.selectHistorySupplier,
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final picked = await showDatePicker(
                            context: context,
                            firstDate: DateTime(2024),
                            lastDate: DateTime(2100),
                            initialDate:
                                controller.historyDate ?? DateTime.now(),
                          );
                          if (picked != null) {
                            await controller.setHistoryDate(picked);
                          }
                        },
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: Text(
                          controller.historyDate == null
                              ? 'Filtrar por fecha'
                              : DateFormat(
                                  'dd/MM/yyyy',
                                ).format(controller.historyDate!),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: controller.clearHistoryFilters,
                        icon: const Icon(Icons.filter_alt_off_outlined),
                        label: const Text('Limpiar filtros'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Card(
                  child: controller.isHistoryLoading
                      ? const Center(child: CircularProgressIndicator())
                      : controller.purchaseHistory.isEmpty
                      ? const Center(
                          child: Text('Aún no hay compras registradas.'),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.all(12),
                          itemCount: controller.purchaseHistory.length,
                          separatorBuilder: (_, __) => const Divider(),
                          itemBuilder: (context, index) {
                            final purchase = controller.purchaseHistory[index];
                            final date = DateTime.tryParse(
                              purchase['date']?.toString() ?? '',
                            );
                            return ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.receipt_long_outlined),
                              ),
                              title: Text(
                                'Compra #${purchase['id']} · ${purchase['store_name'] ?? ''}',
                              ),
                              subtitle: Text(
                                '${purchase['supplier_name'] ?? 'Sin proveedor'} · ${date != null ? DateFormat('dd/MM/yyyy HH:mm').format(date) : ''}',
                              ),
                              trailing: Text(
                                '\$${((purchase['total'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              onTap: () => _showPurchaseDetail(
                                context,
                                controller,
                                (purchase['id'] as num).toInt(),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showPurchaseDetail(
    BuildContext context,
    PurchasesController controller,
    int purchaseId,
  ) async {
    final items = await controller.getPurchaseItems(purchaseId);
    if (!context.mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Detalle de compra #$purchaseId'),
        content: SizedBox(
          width: 420,
          child: items.isEmpty
              ? const Text('No hay productos en esta compra.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final subtotal =
                        ((item['quantity'] as num?)?.toInt() ?? 0) *
                        (((item['cost'] as num?)?.toDouble()) ?? 0);
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(item['product_name']?.toString() ?? ''),
                      subtitle: Text(
                        'Cant: ${item['quantity']} · Costo: \$${((item['cost'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                      ),
                      trailing: Text('\$${subtotal.toStringAsFixed(2)}'),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
