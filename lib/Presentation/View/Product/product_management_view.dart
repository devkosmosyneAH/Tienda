// ignore_for_file: file_names

import 'dart:async';

import 'package:tienda/Presentation/Controller/product_management_controller.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:flutter/material.dart';
// flutter_animate se usa en widgets extraídos si corresponde
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../Widgets/Products/shared_inputs.dart';
// Shared helpers are in widgets/shared_inputs.dart; widget-specific imports kept below
import '../../Widgets/Products/new_product_drawer.dart';
import '../../Widgets/Products/edit_product_dialog.dart';
import '../../Widgets/Products/filter_dropdown.dart';
import '../../Widgets/Products/metric_card.dart';
import '../../Widgets/Products/product_card.dart';
import '../../Widgets/Products/add_product_button.dart';
import '../../Widgets/Products/empty_state.dart';

// Shared UI helpers and widgets extracted to separate files in "widgets/"

// ════════════════════════════════════════════════════════════════════════════
// MAIN VIEW
// ════════════════════════════════════════════════════════════════════════════

class ProductManagementView extends StatefulWidget {
  const ProductManagementView({super.key});

  @override
  State<ProductManagementView> createState() => _ProductManagementViewState();
}

class _ProductManagementViewState extends State<ProductManagementView> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _skuController = TextEditingController();
  final _auxCodeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _tagsController = TextEditingController();
  final _priceController = TextEditingController(text: '0.00');
  final _costPriceController = TextEditingController(text: '0.00');
  final _ivaRateController = TextEditingController(text: '0.00');
  final _profitIvaController = TextEditingController(text: '0.00');
  final _bazarController = TextEditingController(text: '0');
  final _tiendaController = TextEditingController(text: '0');
  final _searchController = TextEditingController();
  String? _selectedCategoryName;
  int? _selectedStoreId;
  int? _selectedStoreFilterId;
  String? _selectedCategoryFilterName;
  List<String> _imagePaths = [];
  bool _isUploadingImages = false;
  bool _isSavingProduct = false;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductManagementController>().initialize();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _categoryController.dispose();
    _skuController.dispose();
    _auxCodeController.dispose();
    _descriptionController.dispose();
    _tagsController.dispose();
    _priceController.dispose();
    _costPriceController.dispose();
    _ivaRateController.dispose();
    _profitIvaController.dispose();
    _bazarController.dispose();
    _tiendaController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ════════════════ LÓGICA DE NEGOCIO — sin cambios ════════════════════════

  Future<void> _pickImages() async {
    try {
      final controller = context.read<ProductManagementController>();
      final picker = ImagePicker();
      final picked = await picker.pickMultiImage(imageQuality: 80);
      if (picked.isEmpty) return;
      // show persistent progress notification while uploading
      showProgressNotification(context, 'Subiendo imágenes...');
      setState(() => _isUploadingImages = true);
      final uploaded = await controller.uploadImages(
        picked.map((image) => image.path).toList(),
      );
      if (!mounted) return;
      setState(() => _imagePaths = [..._imagePaths, ...uploaded]);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      // hide progress notification and reset uploading state
      if (mounted) {
        hideProgressNotification(context);
        setState(() => _isUploadingImages = false);
      }
    }
  }

  void _removeImageAt(int index) {
    final imageRef = _imagePaths[index].trim();
    if (imageRef.isEmpty) return;

    setState(() {
      _imagePaths = List.from(_imagePaths)..removeAt(index);
    });

    unawaited(_removeImageReference(imageRef));
  }

  Future<void> _removeImageReference(String imageRef) async {
    final controller = context.read<ProductManagementController>();
    try {
      await controller.removeImageReference(imageRef: imageRef);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se pudo eliminar la imagen: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final controller = context.read<ProductManagementController>();
    final stocks = <int, int>{};

    for (final store in controller.stores) {
      final id = (store['id'] as num).toInt();
      final name = store['name'] as String;
      final source = name == 'Bazar'
          ? _bazarController.text
          : _tiendaController.text;
      stocks[id] = int.tryParse(source) ?? 0;
    }

    setState(() => _isSavingProduct = true);
    // show progress notification while saving
    showProgressNotification(context, 'Guardando producto...');
    try {
      await controller.createProduct(
        name: _nameController.text,
        category: _selectedCategoryName ?? '',
        price: double.tryParse(_priceController.text.replaceAll(',', '.')) ?? 0,
        costPrice:
            double.tryParse(_costPriceController.text.replaceAll(',', '.')) ??
            0,
        ivaRate:
            double.tryParse(_ivaRateController.text.replaceAll(',', '.')) ?? 0,
        profitIva:
            double.tryParse(_profitIvaController.text.replaceAll(',', '.')) ??
            0,
        sku: _skuController.text,
        auxCode: _auxCodeController.text,
        description: _descriptionController.text,
        tags: _tagsController.text,
        storeId: _selectedStoreId,
        images: _imagePaths,
        initialStock: stocks,
      );

      _nameController.clear();
      _selectedCategoryName = null;
      _categoryController.clear();
      _skuController.clear();
      _auxCodeController.clear();
      _descriptionController.clear();
      _tagsController.clear();
      _priceController.text = '0.00';
      _costPriceController.text = '0.00';
      _ivaRateController.text = '0.00';
      _profitIvaController.text = '0.00';
      _bazarController.text = '0';
      _tiendaController.text = '0';
      setState(() {
        _selectedStoreId = null;
        _imagePaths = [];
      });

      if (!mounted) return;
      _scaffoldKey.currentState?.closeEndDrawer();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Colors.white),
              SizedBox(width: 8),
              Text('Producto creado en el catálogo compartido'),
            ],
          ),
          backgroundColor: const Color(0xff1a7f4b),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      // hide progress notification on success
      hideProgressNotification(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('Exception: ', '')),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      hideProgressNotification(context);
    } finally {
      if (mounted) setState(() => _isSavingProduct = false);
    }
  }

  Future<void> _applyCatalogFilters() async {
    final controller = context.read<ProductManagementController>();
    await controller.loadCatalog(
      search: _searchController.text.trim(),
      storeId: _selectedStoreFilterId,
      category: _selectedCategoryFilterName,
    );
    if (mounted) setState(() {});
  }

  Future<void> _showEditProductDialog(Map<String, dynamic> item) async {
    final controller = context.read<ProductManagementController>();
    await showEditProductDialog(context, controller, item);
  }

  // ════════════════════════════════════════════════════════════════════════
  // WIDGETS UI
  // ════════════════════════════════════════════════════════════════════════

  // FilterDropdown moved to widgets/filter_dropdown.dart

  // MetricCard moved to widgets/metric_card.dart

  // stock badge used inside ProductCard widget

  // imagePlaceholder moved to widgets/shared_inputs.dart

  // ProductCard moved to widgets/product_card.dart

  Widget _buildAddProductButton() =>
      AddProductButton(onPressed: () => _showNewProductDrawer());

  Widget _buildEmptyState() =>
      EmptyState(onCreate: () => _showNewProductDrawer());

  Future<void> _showNewProductDrawer() async {
    final controller = context.read<ProductManagementController>();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return SizedBox(
          height: MediaQuery.of(sheetContext).size.height * 0.92,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: NewProductDrawer(
              controller: controller,
              formKey: _formKey,
              nameController: _nameController,
              categoryController: _categoryController,
              skuController: _skuController,
              auxCodeController: _auxCodeController,
              descriptionController: _descriptionController,
              tagsController: _tagsController,
              priceController: _priceController,
              costPriceController: _costPriceController,
              ivaRateController: _ivaRateController,
              profitIvaController: _profitIvaController,
              bazarController: _bazarController,
              tiendaController: _tiendaController,
              selectedCategoryName: _selectedCategoryName,
              selectedStoreId: _selectedStoreId,
              imagePaths: _imagePaths,
              isUploadingImages: _isUploadingImages,
              isSavingProduct: _isSavingProduct,
              onCategoryChanged: (v) =>
                  setState(() => _selectedCategoryName = v),
              onStoreChanged: (v) => setState(() => _selectedStoreId = v),
              onRemoveImage: (i) => _removeImageAt(i),
              onPickImages: _pickImages,
              onSaveProduct: _saveProduct,
              scaffoldKey: _scaffoldKey,
              onClose: () => Navigator.of(sheetContext).pop(),
            ),
          ),
        );
      },
    );
  }

  int _crossAxisCount(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= 1200) return 4;
    if (width >= 768) return 3;
    return 2;
  }

  // ════════════════════════════════════════════════════════════════════════
  // BUILD
  // ════════════════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return Consumer<ProductManagementController>(
      builder: (context, controller, _) {
        final totalProducts = controller.products.length;
        final totalStock = controller.products.fold<int>(
          0,
          (sum, p) =>
              sum +
              ((p['stock_bazar'] as num?)?.toInt() ?? 0) +
              ((p['stock_tienda'] as num?)?.toInt() ?? 0),
        );
        final inventoryValue = controller.products.fold<double>(0, (sum, p) {
          final cost = (p['cost_price'] as num?)?.toDouble() ?? 0;
          final stock =
              ((p['stock_bazar'] as num?)?.toInt() ?? 0) +
              ((p['stock_tienda'] as num?)?.toInt() ?? 0);
          return sum + cost * stock;
        });
        final isMobile = MediaQuery.of(context).size.width < 600;
        return Scaffold(
          key: _scaffoldKey,
          backgroundColor: AppColors.lightGray,
          appBar: isMobile
              ? AppBar(
                  backgroundColor: AppColors.blackOverlay,
                  toolbarHeight: 64,
                  automaticallyImplyLeading: false,
                  leading: const SizedBox.shrink(),
                  leadingWidth: 0,
                  titleSpacing: 0,
                  elevation: 4,
                  shadowColor: AppColors.blackOverlay.withValues(alpha: 0.50),
                  title: _mobileHeader(),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    side: BorderSide(color: Color(0xFF1a1a1a), width: 0.5),
                  ),
                )
              : null,

          body: SafeArea(
            top: !isMobile,
            child: CustomScrollView(
              slivers: [
                // Header
                if (!isMobile)
                  SliverToBoxAdapter(
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
                          elevation: 0,
                          toolbarHeight: 72,
                          centerTitle: true,
                          automaticallyImplyLeading: false,
                          iconTheme: const IconThemeData(
                            color: AppColors.whiteOverlay,
                          ),
                          leading: IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back, size: 28),
                          ),
                          title: const Text(
                            'Productos',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.whiteOverlay,
                              letterSpacing: -0.3,
                            ),
                          ),
                          actions: [
                            _buildAddProductButton(),
                            const SizedBox(width: 16),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Métricas
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: Row(
                      children: [
                        MetricCard(
                          icon: Icons.inventory_2_outlined,
                          title: 'Productos',
                          value: '$totalProducts',
                          color: AppColors.primaryBlue,
                          index: 0,
                        ),
                        const SizedBox(width: 12),
                        MetricCard(
                          icon: Icons.warehouse_outlined,
                          title: 'Stock Total',
                          value: '$totalStock',
                          color: const Color(0xFF1a7f4b),
                          index: 1,
                        ),
                        const SizedBox(width: 12),
                        MetricCard(
                          icon: Icons.payments_outlined,
                          title: 'Valor Inventario',
                          value: inventoryValue >= 1000
                              ? '\$${(inventoryValue / 1000).toStringAsFixed(1)}k'
                              : '\$${inventoryValue.toStringAsFixed(0)}',
                          color: AppColors.primaryLogo,
                          index: 2,
                        ),
                      ],
                    ),
                  ),
                ),

                // Buscador y filtros
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                    child: Column(
                      children: [
                        SizedBox(
                          height: 56,
                          child: SharedTextField(
                            controller: _searchController,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                            hint: 'Buscar productos...',
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: Colors.grey.shade400,
                              size: 22,
                            ),
                            suffixIcon: _searchController.text.isEmpty
                                ? null
                                : IconButton(
                                    onPressed: () {
                                      _searchController.clear();
                                      _applyCatalogFilters();
                                    },
                                    icon: Icon(
                                      Icons.close,
                                      color: Colors.grey.shade400,
                                      size: 18,
                                    ),
                                  ),
                            useFilterStyle: true,
                            onChanged: (value) {
                              setState(() {});
                              _applyCatalogFilters();
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: FilterDropdown<int?>(
                                label: 'Por local',
                                value: _selectedStoreFilterId,
                                items: [
                                  const DropdownMenuItem<int?>(
                                    value: null,
                                    child: Text('Locales'),
                                  ),
                                  ...controller.stores.map((store) {
                                    final storeId = (store['id'] as num)
                                        .toInt();
                                    return DropdownMenuItem<int?>(
                                      value: storeId,
                                      child: Text(store['name'] as String),
                                    );
                                  }),
                                ],
                                onChanged: (value) {
                                  setState(
                                    () => _selectedStoreFilterId = value,
                                  );
                                  _applyCatalogFilters();
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilterDropdown<String?>(
                                label: 'Por categoría',
                                value: _selectedCategoryFilterName,
                                items: [
                                  const DropdownMenuItem<String?>(
                                    value: null,
                                    child: Text('Categorías'),
                                  ),
                                  ...controller.categories.map((category) {
                                    final categoryName =
                                        category['name'] as String;
                                    return DropdownMenuItem<String?>(
                                      value: categoryName,
                                      child: Text(categoryName),
                                    );
                                  }),
                                ],
                                onChanged: (value) {
                                  setState(
                                    () => _selectedCategoryFilterName = value,
                                  );
                                  _applyCatalogFilters();
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Error
                if (controller.errorMessage != null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFE5E5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                controller.errorMessage!,
                                style: const TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                // Catálogo
                if (controller.isLoading && controller.products.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primaryBlue,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                else if (controller.products.isEmpty)
                  SliverFillRemaining(child: _buildEmptyState())
                else
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final item = controller.products[index];
                        return ProductCard(
                          item: item,
                          index: index,
                          onEdit: () => _showEditProductDialog(item),
                        );
                      }, childCount: controller.products.length),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: _crossAxisCount(context),
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        mainAxisExtent: 450,
                      ),
                    ),
                  ),

                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _mobileHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: AppColors.whiteOverlay),
            splashRadius: 20,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Productos',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.whiteOverlay,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 8),
          AddProductButton(onPressed: () => _showNewProductDrawer()),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════
// HOVER CARD
// ════════════════════════════════════════════════════════════════════════════

class _HoverCard extends StatefulWidget {
  const _HoverCard({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: AppColors.whiteOverlay,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _hovered ? 0.10 : 0.05),
                blurRadius: _hovered ? 20 : 10,
                offset: Offset(0, _hovered ? 8 : 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(16),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
