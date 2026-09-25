import 'package:tienda/Presentation/Context/pos_sale_provider.dart';
import 'package:tienda/Presentation/Controller/pos_controller.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:tienda/Presentation/Widgets/POS/pos_receipt_type_card.dart';
import 'package:tienda/Presentation/Widgets/POS/pos_cliente_section.dart';
import 'package:tienda/Presentation/Widgets/POS/pos_productos_section.dart';
import 'package:tienda/Presentation/Widgets/POS/pos_forma_pago_section.dart';
import 'package:tienda/Presentation/Widgets/POS/pos_resumen_venta_card.dart';
import 'package:tienda/Presentation/Widgets/POS/pos_product_search_dialog.dart';
import 'package:tienda/Presentation/Widgets/POS/pos_client_search_dialog.dart';
import 'package:tienda/Presentation/Widgets/POS/pos_sales_history_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────
//  POS View — Sistema de Ventas (Orquestador MVC delgado)
// ─────────────────────────────────────────────────────────────────

class PosView extends StatelessWidget {
  const PosView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PosSaleProvider(),
      child: const _PosScaffold(),
    );
  }
}

class _PosScaffold extends StatefulWidget {
  const _PosScaffold();

  @override
  State<_PosScaffold> createState() => _PosScaffoldState();
}

class _PosScaffoldState extends State<_PosScaffold>
    with TickerProviderStateMixin {
  late TabController _tabController;
  int _saleCount = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PosController>().initialize();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _agregarVenta() {
    final newTabIndex = _saleCount;
    setState(() {
      _saleCount++;
      _tabController.dispose();
      _tabController = TabController(
        length: _saleCount + 1,
        vsync: this,
        initialIndex: newTabIndex,
      );
    });
  }

  void _cerrarVenta(int saleIndex) {
    if (_saleCount == 1) return;

    final currentIndex = _tabController.index;
    final newSaleCount = _saleCount - 1;
    var newTabIndex = currentIndex;

    if (currentIndex > saleIndex) {
      newTabIndex--;
    }
    newTabIndex = newTabIndex.clamp(0, newSaleCount);

    setState(() {
      _saleCount = newSaleCount;
      _tabController.dispose();
      _tabController = TabController(
        length: _saleCount + 1,
        vsync: this,
        initialIndex: newTabIndex,
      );
    });
  }

  Widget _buildSaleTab(int index) {
    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Venta ${index + 1}'),
          if (_saleCount > 1)
            IconButton(
              tooltip: 'Cerrar venta',
              onPressed: () => _cerrarVenta(index),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              icon: const Icon(Icons.close, size: 18),
            ),
        ],
      ),
    );
  }

  // ── Acciones de venta

  void _showProductSearch(BuildContext ctx) {
    showDialog(context: ctx, builder: (_) => const PosProductSearchDialog());
  }

  void _showClientSearch(BuildContext ctx) {
    final controller = ctx.read<PosController>();
    final sale = ctx.read<PosSaleProvider>();
    showDialog(
      context: ctx,
      builder: (_) => ChangeNotifierProvider.value(
        value: controller,
        child: const PosClientSearchDialog(),
      ),
    ).then((_) {
      if (mounted) {
        sale.setConsumerFinal(controller.selectedCustomerId == null);
      }
    });
  }

  void _limpiarVenta() {
    context.read<PosController>().clearCart();
    context.read<PosSaleProvider>().clearSale();
  }

  Future<void> _finalizarVenta() async {
    final messenger = ScaffoldMessenger.of(context);
    final posCtrl = context.read<PosController>();
    final sale = context.read<PosSaleProvider>();
    final effectiveTotal = sale.effectiveTotal(posCtrl.total);

    if (posCtrl.cart.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Agrega productos antes de vender')),
      );
      return;
    }
    try {
      final paymentsToSend = sale.buildPayloads(
        paymentMethods: posCtrl.paymentMethods,
        total: effectiveTotal,
      );
      final saleId = await posCtrl.checkout(payments: paymentsToSend);
      if (!mounted) return;
      sale.clearSale();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Venta #$saleId registrada correctamente'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final posCtrl = context.watch<PosController>();
    final cartTotal = posCtrl.total;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f9): _finalizarVenta,
        const SingleActivator(LogicalKeyboardKey.escape): _limpiarVenta,
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: AppColors.lightGray,
          appBar: PreferredSize(
            preferredSize: const Size.fromHeight(kToolbarHeight + 48),
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
              child: AppBar(
                title: const Text(
                  'Sistema de Ventas',
                  style: TextStyle(
                    fontSize: 22,
                    color: AppColors.whiteOverlay,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                iconTheme: const IconThemeData(color: AppColors.lightWhite),
                backgroundColor: AppColors.blackOverlay,
                elevation: 4,
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: AppColors.whiteOverlay,
                    size: 30,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
                surfaceTintColor: Colors.transparent,

                actions: [
                  IconButton(
                    tooltip: 'Nueva venta · ESC',
                    onPressed: _agregarVenta,
                    icon: const Icon(
                      Icons.add,
                      color: AppColors.whiteOverlay,
                      size: 28,
                    ),
                  ),
                ],
                bottom: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: AppColors.lightWhite,
                  unselectedLabelColor: AppColors.lightWhite.withValues(
                    alpha: 0.6,
                  ),
                  indicatorColor: AppColors.lightWhite,
                  tabs: [
                    for (var index = 0; index < _saleCount; index++)
                      _buildSaleTab(index),
                    const Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.history),
                          SizedBox(width: 4),
                          Text('Historial'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              for (var index = 0; index < _saleCount; index++)
                _buildSaleContent(posCtrl, cartTotal),
              const PosSalesHistoryTab(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSaleContent(PosController posCtrl, double cartTotal) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ════════════════════════════════════════════════
          //  Tab 1: Nueva Venta
          // ════════════════════════════════════════════════

          // ── Tipo de comprobante
          const PosReceiptTypeCard()
              .animate()
              .fadeIn(duration: 350.ms)
              .slideY(
                begin: 0.1,
                end: 0,
                duration: 350.ms,
                curve: Curves.easeOut,
              ),
          const SizedBox(height: 16),
          // ── Cliente
          PosClienteSection(
                onShowClientSearch: (ctx, _) => _showClientSearch(ctx),
              )
              .animate()
              .fadeIn(delay: 80.ms, duration: 350.ms)
              .slideY(
                begin: 0.1,
                end: 0,
                delay: 80.ms,
                duration: 350.ms,
                curve: Curves.easeOut,
              ),
          const SizedBox(height: 16),
          // ── Local
          if (posCtrl.stores.isNotEmpty)
            Material(
              elevation: 4,
              shadowColor: Colors.black26,
              borderRadius: BorderRadius.circular(25),
              child: DropdownButtonFormField<int>(
                value: posCtrl.selectedStoreId,
                decoration: InputDecoration(
                  labelText: 'Local',
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
                items: posCtrl.stores.map((store) {
                  return DropdownMenuItem<int>(
                    value: (store['id'] as num).toInt(),
                    child: Text(store['name'].toString()),
                  );
                }).toList(),
                onChanged: posCtrl.selectStore,
              ),
            ),
          const SizedBox(height: 16),
          // ── Productos / Carrito
          PosProductosSection(
                onShowProductSearch: (ctx, _) => _showProductSearch(ctx),
              )
              .animate()
              .fadeIn(delay: 160.ms, duration: 350.ms)
              .slideY(
                begin: 0.1,
                end: 0,
                delay: 160.ms,
                duration: 350.ms,
                curve: Curves.easeOut,
              ),
          const SizedBox(height: 16),
          // ── Forma de pago
          const PosFormaPagoSection()
              .animate()
              .fadeIn(delay: 240.ms, duration: 350.ms)
              .slideY(
                begin: 0.1,
                end: 0,
                delay: 240.ms,
                duration: 350.ms,
                curve: Curves.easeOut,
              ),
          const SizedBox(height: 16),
          // ── Resumen de venta
          PosResumenVentaCard(subtotal: cartTotal)
              .animate()
              .fadeIn(delay: 360.ms, duration: 350.ms)
              .slideY(
                begin: 0.1,
                end: 0,
                delay: 360.ms,
                duration: 350.ms,
                curve: Curves.easeOut,
              ),
          const SizedBox(height: 20),
          // ── Botones finales
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _limpiarVenta,
                    icon: const Icon(Icons.delete_sweep_outlined),
                    label: const Text(
                      'Limpiar Venta',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2D5A27),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: posCtrl.cart.isEmpty ? null : _finalizarVenta,
                    icon: const Icon(Icons.sell_outlined),
                    label: const Text(
                      'Finalizar Venta',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          // ════════════════════════════════════════════════
          //  Tab 2: Historial
          // ════════════════════════════════════════════════
        ],
      ),
    );
  }
}
