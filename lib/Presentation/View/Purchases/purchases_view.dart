import 'package:tienda/Presentation/Controller/purchases_controller.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'new_purchase_tab.dart';
import 'purchase_history_tab.dart';

class PurchasesView extends StatefulWidget {
  const PurchasesView({super.key});

  @override
  State<PurchasesView> createState() => _PurchasesViewState();
}

class _PurchasesViewState extends State<PurchasesView>
    with TickerProviderStateMixin {
  final _searchController = TextEditingController();
  final _supplierController = TextEditingController();
  final _supplierPhoneController = TextEditingController();
  late TabController _tabController;
  int _saleCount = 1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PurchasesController>().initialize();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  void _agregarCompra() {
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

  void _cerrarCompra(int saleIndex) {
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
          Text('Compra ${index + 1}'),
          if (_saleCount > 1)
            IconButton(
              tooltip: 'Cerrar Compra',
              onPressed: () => _cerrarCompra(index),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
              icon: const Icon(Icons.close, size: 18),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
              'Compras · Abastecimiento',
              style: TextStyle(fontSize: 16, color: AppColors.whiteOverlay),
            ),
            iconTheme: const IconThemeData(color: AppColors.lightWhite),
            backgroundColor: AppColors.blackOverlay,
            elevation: 4,
            centerTitle: true,
            surfaceTintColor: Colors.transparent,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back,
                color: AppColors.whiteOverlay,
                size: 30,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                tooltip: 'Nueva Compra',
                onPressed: _agregarCompra,
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
              labelColor: AppColors.whiteOverlay,
              unselectedLabelColor: AppColors.mediumGray,
              indicatorColor: AppColors.whiteOverlay,
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
            NewPurchaseTab(
              searchController: _searchController,
              supplierController: _supplierController,
              supplierPhoneController: _supplierPhoneController,
              onSave: _savePurchase,
            ),
          const PurchaseHistoryTab(),
        ],
      ),
    );
  }
}
