import 'package:tienda/Presentation/Context/pos_sale_provider.dart';
import 'package:tienda/Presentation/Controller/pos_controller.dart';
import 'package:tienda/Presentation/Renders/responsive_helper.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:tienda/Presentation/Widgets/POS/pos_receipt_type_card.dart';
import 'package:tienda/Presentation/Widgets/POS/pos_cliente_section.dart';
import 'package:tienda/Presentation/Widgets/POS/pos_productos_section.dart';
import 'package:tienda/Presentation/Widgets/POS/pos_forma_pago_section.dart';
import 'package:tienda/Presentation/Widgets/POS/pos_pagos_recibidos_section.dart';
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

class _PosScaffoldState extends State<_PosScaffold> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PosController>().initialize();
    });
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
    final appBarHeight = ResponsiveHelper.getAppBarHeight(context) + 48;
    final posCtrl = context.watch<PosController>();
    final sale = context.watch<PosSaleProvider>();
    final cartTotal = posCtrl.total;
    final total = sale.effectiveTotal(cartTotal);

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f9): _finalizarVenta,
        const SingleActivator(LogicalKeyboardKey.escape): _limpiarVenta,
      },
      child: Focus(
        autofocus: true,
        child: DefaultTabController(
          length: 2,
          child: Scaffold(
            backgroundColor: const Color(0xFFF2F2F2),
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
                      'Sistema de Ventas',
                      style: TextStyle(
                        fontSize: 22,
                        color: AppColors.whiteOverlay,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    actions: [
                      IconButton(
                        tooltip: 'Nueva venta · ESC',
                        onPressed: _limpiarVenta,
                        icon: const Icon(
                          Icons.add,
                          color: AppColors.whiteOverlay,
                          size: 28,
                        ),
                      ),
                    ],
                    bottom: const TabBar(
                      labelColor: AppColors.whiteOverlay,
                      unselectedLabelColor: AppColors.mediumGray,
                      indicatorColor: AppColors.whiteOverlay,
                      tabs: [
                        Tab(
                          text: 'Venta 1',
                          icon: Icon(Icons.receipt_outlined),
                        ),
                        Tab(
                          text: 'Historial',
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
                // ════════════════════════════════════════════════
                //  Tab 1: Nueva Venta
                // ════════════════════════════════════════════════
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
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
                            onShowClientSearch: (ctx, _) =>
                                _showClientSearch(ctx),
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
                      // ── Productos / Carrito
                      PosProductosSection(
                            onShowProductSearch: (ctx, _) =>
                                _showProductSearch(ctx),
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
                      // ── Pagos recibidos
                      PosPagosRecibidosSection(total: total)
                          .animate()
                          .fadeIn(delay: 300.ms, duration: 350.ms)
                          .slideY(
                            begin: 0.1,
                            end: 0,
                            delay: 300.ms,
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
                                onPressed: posCtrl.cart.isEmpty
                                    ? null
                                    : _finalizarVenta,
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
                    ],
                  ),
                ),
                // ════════════════════════════════════════════════
                //  Tab 2: Historial
                // ════════════════════════════════════════════════
                const PosSalesHistoryTab(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
