import 'package:tienda/Presentation/Context/inventory_provider.dart';
import 'package:tienda/Presentation/Model/inventory_model.dart';
import 'package:tienda/Presentation/Renders/responsive_helper.dart';
import 'package:tienda/Presentation/Services/database_service.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:tienda/Presentation/Widgets/Inventory/inventory_header.dart';
import 'package:tienda/Presentation/Widgets/Inventory/inventory_low_stock_tab.dart';
import 'package:tienda/Presentation/Widgets/Inventory/inventory_product_detail_sheet.dart';
import 'package:tienda/Presentation/Widgets/Inventory/inventory_products_tab.dart';
import 'package:tienda/Presentation/Widgets/Inventory/inventory_summary_tab.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tienda/Presentation/Controller/purchases_controller.dart';
import 'package:tienda/Presentation/View/Purchases/purchases_view.dart';

class InventoryView extends StatefulWidget {
  const InventoryView({super.key});

  @override
  State<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<InventoryView> {
  final _searchController = TextEditingController();
  final _codeController = TextEditingController();
  int _selectedTab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        context.read<InventoryProvider>().initialize();
      } catch (e) {
        debugPrint('Error al acceder a InventoryProvider en initState: $e');
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _showProductDetailSheet(InventoryItem item) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InventoryProductDetailSheet(item: item),
    );
  }

  Future<void> _buyProduct(InventoryItem item) async {
    final purchaseController = context.read<PurchasesController>();

    try {
      final product = await DatabaseService.getProducts(
        storeId: purchaseController.selectedStoreId,
        search: item.name,
      );

      final match = product.firstWhere(
        (entry) => (entry['id'] as num).toInt() == item.productId,
        orElse: () => <String, dynamic>{},
      );

      if (match.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se encontró el producto ${item.name} para comprar.')),
        );
        return;
      }

      purchaseController.addToCart(match);

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const PurchasesView(),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir la compra: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final appBarHeight = ResponsiveHelper.getAppBarHeight(context);

    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: InventoryHeader(
        appBarHeight: appBarHeight,
        selectedTab: _selectedTab,
        onTabChanged: (value) => setState(() => _selectedTab = value),
        onRefresh: () => context.read<InventoryProvider>().refreshInventory(),
        onBack: () => Navigator.pop(context),
      ),
      body: Consumer<InventoryProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.blackOverlay),
            );
          }
          if (provider.errorMessage != null) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  provider.errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          switch (_selectedTab) {
            case 0:
              return InventorySummaryTab(provider: provider);
            case 1:
              return InventoryProductsTab(
                provider: provider,
                searchController: _searchController,
                codeController: _codeController,
                onOpenDetail: _showProductDetailSheet,
                onFilterChanged: () => setState(() {}),
              );
            case 2:
              return InventoryLowStockTab(
                items: provider.inventoryItems,
                onOpenDetail: _showProductDetailSheet,
                onBuyProduct: _buyProduct,
              );
            default:
              return const SizedBox.shrink();
          }
        },
      ),
    );
  }
}
