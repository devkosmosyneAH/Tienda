import 'package:tienda/Presentation/Context/inventory_provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:tienda/Presentation/Model/inventory_model.dart';
import 'package:tienda/Presentation/Renders/responsive_helper.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class InventoryView extends StatefulWidget {
  const InventoryView({super.key});

  @override
  State<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<InventoryView> {
  final _searchController = TextEditingController();
  final _descController = TextEditingController();
  final _codeController = TextEditingController();
  // 0 = Resumen, 1 = Productos, 2 = Stock Bajo
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
    _descController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _showProductDetailSheet(InventoryItem item) {
    final fmt = NumberFormat('#,##0.00', 'es');
    final isZero = item.quantity == 0;
    final isLow = !isZero && item.quantity <= 5;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            // Título + badge
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isZero || isLow) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isZero ? AppColors.primaryRed : Colors.orange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isZero ? 'SIN STOCK' : 'STOCK BAJO',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            // Descripción
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.lightGray,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Descripción',
                    style: TextStyle(fontSize: 12, color: Colors.black45),
                  ),
                  const SizedBox(height: 4),
                  Text(item.name, style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Código
            Text(
              'Código: ${item.sku.isNotEmpty ? item.sku : 'Prod${item.productId.toString().padLeft(9, '0')}'}',
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            // Almacén + Precio
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Almacén',
                        style: TextStyle(fontSize: 12, color: Colors.black45),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.quantity.toString(),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: isZero
                              ? AppColors.primaryRed
                              : isLow
                              ? Colors.orange
                              : AppColors.darkGray,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Precio Compra',
                        style: TextStyle(fontSize: 12, color: Colors.black45),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${fmt.format(item.costPrice)}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Botón cerrar
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blackOverlay,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cerrar',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appBarHeight = ResponsiveHelper.getAppBarHeight(context);
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(appBarHeight + 50),
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
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back,
                  color: AppColors.whiteOverlay,
                  size: 26,
                ),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                'Gestión de Inventario',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.whiteOverlay,
                ),
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(
                    Icons.shopping_cart_outlined,
                    color: AppColors.whiteOverlay,
                  ),
                  onPressed: () {},
                ),
                IconButton(
                  icon: const Icon(
                    Icons.refresh,
                    color: AppColors.whiteOverlay,
                  ),
                  onPressed: () =>
                      context.read<InventoryProvider>().loadInventory(),
                ),
              ],
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(50),
                child: Row(
                  children: [
                    _NavTab(
                      icon: Icons.grid_view_rounded,
                      label: 'Resumen',
                      isSelected: _selectedTab == 0,
                      onTap: () => setState(() => _selectedTab = 0),
                    ),
                    _NavTab(
                      icon: Icons.search,
                      label: 'Productos',
                      isSelected: _selectedTab == 1,
                      onTap: () => setState(() => _selectedTab = 1),
                    ),
                    _NavTab(
                      icon: Icons.warning_amber_rounded,
                      label: 'Stock Bajo',
                      isSelected: _selectedTab == 2,
                      onTap: () => setState(() => _selectedTab = 2),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
              return _buildResumenTab(provider);
            case 1:
              return _buildProductosTab(provider);
            case 2:
              return _buildStockBajoTab(provider);
            default:
              return const SizedBox.shrink();
          }
        },
      ),
    );
  }

  Widget _buildResumenTab(InventoryProvider provider) {
    final items = provider.inventoryItems;
    final outOfStock = items.where((i) => i.quantity == 0).length;
    final toOrder = items
        .where((i) => i.quantity > 0 && i.quantity <= 2)
        .length;
    final stable = items
        .where((i) => i.quantity > 2 && i.quantity <= 10)
        .length;
    final excess = items.where((i) => i.quantity > 10).length;
    final avgStock = items.isEmpty
        ? 0.0
        : (provider.summary?.totalUnits ?? 0) / items.length;
    final criticalStock = items
        .where((i) => i.quantity > 0 && i.quantity <= 5)
        .length;
    final fmt = NumberFormat('#,##0.0', 'es');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Banner
        Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: AppColors.blackOverlay,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.secondaryLogo,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.grid_view_rounded,
                      color: AppColors.whiteOverlay,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dashboard de Inventario',
                        style: TextStyle(
                          color: AppColors.whiteOverlay,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Análisis completo de tu inventario',
                        style: TextStyle(
                          color: AppColors.greyOverlay,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
            .animate()
            .fadeIn(duration: 400.ms)
            .slideY(
              begin: -0.1,
              end: 0,
              duration: 400.ms,
              curve: Curves.easeOut,
            ),
        const SizedBox(height: 16),

        // Tarjetas de estado
        SizedBox(
          height: 185,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _StatusCard(
                    value: provider.summary?.totalProducts.toString() ?? '0',
                    label: 'Total Productos',
                    sublabel: 'En inventario',
                    icon: Icons.inventory_2_outlined,
                    iconColor: AppColors.primaryBlue,
                    iconBgColor: AppColors.lightBlue,
                    bgColor: AppColors.whiteOverlay,
                    valueColor: AppColors.darkGray,
                  )
                  .animate()
                  .fadeIn(delay: 100.ms, duration: 350.ms)
                  .slideX(
                    begin: 0.2,
                    end: 0,
                    delay: 100.ms,
                    duration: 350.ms,
                    curve: Curves.easeOut,
                  ),
              _StatusCard(
                    value: outOfStock.toString(),
                    label: 'Agotado (=0)',
                    sublabel: 'Requiere reposición inmediata',
                    badge: 'Requiere atención',
                    badgeColor: AppColors.primaryRed,
                    icon: Icons.cancel_outlined,
                    iconColor: AppColors.primaryRed,
                    iconBgColor: AppColors.lightRed,
                    bgColor: const Color(0xFFFFE8E6),
                    valueColor: AppColors.primaryRed,
                  )
                  .animate()
                  .fadeIn(delay: 160.ms, duration: 350.ms)
                  .slideX(
                    begin: 0.2,
                    end: 0,
                    delay: 160.ms,
                    duration: 350.ms,
                    curve: Curves.easeOut,
                  ),
              _StatusCard(
                    value: toOrder.toString(),
                    label: 'Pedir (≤Mín)',
                    sublabel: items.isEmpty
                        ? '0.0% del total'
                        : '${(toOrder / items.length * 100).toStringAsFixed(1)}% del total',
                    badge: 'Requiere atención',
                    badgeColor: Colors.orange,
                    icon: Icons.warning_amber_rounded,
                    iconColor: Colors.orange,
                    iconBgColor: const Color(0xFFFFEDD5),
                    bgColor: const Color(0xFFFFF3E0),
                    valueColor: Colors.orange,
                  )
                  .animate()
                  .fadeIn(delay: 220.ms, duration: 350.ms)
                  .slideX(
                    begin: 0.2,
                    end: 0,
                    delay: 220.ms,
                    duration: 350.ms,
                    curve: Curves.easeOut,
                  ),
              _StatusCard(
                    value: stable.toString(),
                    label: 'Estable (Mín<St<Máx)',
                    sublabel: 'Stock óptimo',
                    icon: Icons.check_circle_outline,
                    iconColor: Colors.green,
                    iconBgColor: AppColors.lightGreen,
                    bgColor: AppColors.whiteOverlay,
                    valueColor: AppColors.darkGray,
                  )
                  .animate()
                  .fadeIn(delay: 280.ms, duration: 350.ms)
                  .slideX(
                    begin: 0.2,
                    end: 0,
                    delay: 280.ms,
                    duration: 350.ms,
                    curve: Curves.easeOut,
                  ),
              _StatusCard(
                    value: excess.toString(),
                    label: 'Exceso (≥Máx)',
                    sublabel: 'Stock por encima del máximo',
                    icon: Icons.trending_up,
                    iconColor: AppColors.primaryBlue,
                    iconBgColor: AppColors.lightBlue,
                    bgColor: AppColors.whiteOverlay,
                    valueColor: AppColors.darkGray,
                  )
                  .animate()
                  .fadeIn(delay: 340.ms, duration: 350.ms)
                  .slideX(
                    begin: 0.2,
                    end: 0,
                    delay: 340.ms,
                    duration: 350.ms,
                    curve: Curves.easeOut,
                  ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Estadísticas Rápidas
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFEEEEF2),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.bar_chart, color: AppColors.primaryBlue, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Estadísticas Rápidas',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _QuickStatCard(
                      icon: Icons.attach_money,
                      iconColor: Colors.green,
                      value: fmt.format(provider.summary?.totalInvested ?? 0),
                      label: 'Valor Total',
                      dotColor: Colors.green,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickStatCard(
                      icon: Icons.inventory_2_outlined,
                      iconColor: AppColors.primaryBlue,
                      value: '${avgStock.toStringAsFixed(1)} un.',
                      label: 'Stock Promedio',
                      dotColor: AppColors.primaryBlue,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _QuickStatCard(
                      icon: Icons.warning_amber_rounded,
                      iconColor: AppColors.primaryRed,
                      value: outOfStock.toString(),
                      label: 'Sin Stock',
                      dotColor: AppColors.primaryRed,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _QuickStatCard(
                      icon: Icons.star_outline,
                      iconColor: Colors.orange,
                      value: criticalStock.toString(),
                      label: 'Stock Crítico',
                      dotColor: Colors.orange,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'Valor promedio por producto: ${fmt.format(provider.summary?.averageProductValue ?? 0)}',
            style: const TextStyle(fontSize: 12, color: AppColors.mediumGray),
          ),
        ),
        const SizedBox(height: 16),

        // ── Inversión en Bodega ───────────────────────────────
        _InversionCard(provider: provider, items: items, fmt: fmt)
            .animate()
            .fadeIn(delay: 200.ms, duration: 400.ms)
            .slideY(
              begin: 0.1,
              end: 0,
              delay: 200.ms,
              duration: 400.ms,
              curve: Curves.easeOut,
            ),
        const SizedBox(height: 16),

        // ── Gráficos: Distribución + Rangos ──────────────────
        Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _DonutChartCard(
                    outOfStock: outOfStock,
                    toOrder: toOrder,
                    stable: stable,
                    excess: excess,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: _BarChartCard(items: items)),
              ],
            )
            .animate()
            .fadeIn(delay: 300.ms, duration: 400.ms)
            .slideY(
              begin: 0.1,
              end: 0,
              delay: 300.ms,
              duration: 400.ms,
              curve: Curves.easeOut,
            ),
        const SizedBox(height: 16),

        // ── Productos que Requieren Atención ─────────────────
        _AttencionSection(items: items, fmt: fmt)
            .animate()
            .fadeIn(delay: 400.ms, duration: 400.ms)
            .slideY(
              begin: 0.1,
              end: 0,
              delay: 400.ms,
              duration: 400.ms,
              curve: Curves.easeOut,
            ),
        const SizedBox(height: 16),
      ],
    );
  }

  List<InventoryItem> _filtrarProductos(InventoryProvider provider) {
    final nombre = _searchController.text.toLowerCase();
    final desc = _descController.text.toLowerCase();
    final codigo = _codeController.text.toLowerCase();
    return provider.inventoryItems.where((item) {
      final matchNombre =
          nombre.isEmpty || item.name.toLowerCase().contains(nombre);
      final matchDesc =
          desc.isEmpty ||
          item.name.toLowerCase().contains(desc) ||
          item.category.toLowerCase().contains(desc);
      final matchCodigo =
          codigo.isEmpty ||
          item.sku.toLowerCase().contains(codigo) ||
          item.productId.toString().contains(codigo);
      return matchNombre && matchDesc && matchCodigo;
    }).toList();
  }

  Widget _buildProductosTab(InventoryProvider provider) {
    final filtered = _filtrarProductos(provider);
    final fmt = NumberFormat('#,##0.00', 'es');

    return Column(
      children: [
        const SizedBox(height: 10),
        // ── Barra de búsqueda por código ──────────────────────
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            color: AppColors.lightGray,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const Icon(
                  Icons.grid_view_rounded,
                  color: AppColors.darkGray,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Material(
                    elevation: 4,
                    shadowColor: Colors.black26,
                    borderRadius: BorderRadius.circular(25),
                    clipBehavior: Clip.antiAlias,
                    child: TextField(
                      controller: _codeController,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppColors.whiteOverlay,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: AppColors.whiteOverlay,
                            width: 1.5,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: AppColors.whiteOverlay,
                            width: 1.5,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: AppColors.whiteOverlay,
                            width: 1.5,
                          ),
                        ),
                        hintText:
                            'Buscar por código, código auxiliar o código de barras...',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: Colors.black38,
                        ),
                        isDense: true,
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                if (_codeController.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _codeController.clear();
                      setState(() {});
                    },
                    child: const Icon(
                      Icons.clear,
                      size: 18,
                      color: Colors.black38,
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 5),

        // ── Selector de local + dos búsquedas ─────────────────
        Container(
          color: AppColors.lightGray,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Column(
            children: [
              if (provider.stores.length > 1) ...[
                Material(
                  color: AppColors.primaryRed,
                  elevation: 4,
                  shadowColor: Colors.black26,
                  borderRadius: BorderRadius.circular(25),
                  clipBehavior: Clip.antiAlias,
                  child: DropdownButtonFormField<int>(
                    dropdownColor: AppColors.whiteOverlay,
                    value: provider.selectedStoreId,
                    focusColor: AppColors.whiteOverlay,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.whiteOverlay,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: AppColors.whiteOverlay,
                          width: 1.5,
                        ),
                      ),
                      focusColor: AppColors.whiteOverlay,
                      hintText: 'Local',
                      isDense: true,
                    ),
                    items: provider.stores
                        .map(
                          (s) => DropdownMenuItem<int>(
                            value: (s['id'] as num).toInt(),
                            child: Text(s['name'] ?? 'Tienda'),
                          ),
                        )
                        .toList(),
                    onChanged: (id) {
                      if (id != null) provider.selectStore(id);
                    },
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: Container(
                      color: AppColors.lightGray,
                      child: Material(
                        elevation: 4,
                        shadowColor: Colors.black26,
                        borderRadius: BorderRadius.circular(25),
                        clipBehavior: Clip.antiAlias,
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.whiteOverlay,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: AppColors.whiteOverlay,
                                width: 1.5,
                              ),
                            ),
                            hintText: 'Buscar por Producto...',
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                            prefixIcon: const Icon(
                              Icons.search,
                              size: 18,
                              color: Colors.black38,
                            ),
                            isDense: true,
                            suffixIcon: _searchController.text.isEmpty
                                ? null
                                : GestureDetector(
                                    onTap: () {
                                      _searchController.clear();
                                      setState(() {});
                                    },
                                    child: const Icon(
                                      Icons.clear,
                                      size: 16,
                                      color: Colors.black38,
                                    ),
                                  ),
                          ),

                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Material(
                      elevation: 4,
                      shadowColor: Colors.black26,
                      borderRadius: BorderRadius.circular(25),
                      clipBehavior: Clip.antiAlias,
                      child: Container(
                        color: AppColors.lightGray,
                        child: TextField(
                          controller: _descController,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppColors.whiteOverlay,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: AppColors.whiteOverlay,
                                width: 1.5,
                              ),
                            ),
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                            hintText: 'Buscar por Descripción...',
                            prefixIcon: const Icon(
                              Icons.search,
                              size: 18,
                              color: Colors.black38,
                            ),
                            isDense: true,
                            suffixIcon: _descController.text.isEmpty
                                ? null
                                : GestureDetector(
                                    onTap: () {
                                      _descController.clear();
                                      setState(() {});
                                    },
                                    child: const Icon(
                                      Icons.clear,
                                      size: 16,
                                      color: Colors.black38,
                                    ),
                                  ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // ── Contador de resultados ────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            '${filtered.length} productos encontrados',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),

        // ── Cuadrícula de productos ───────────────────────────
        Expanded(
          child: filtered.isEmpty
              ? const Center(child: Text('No hay productos para este local'))
              : GridView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 160,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) =>
                      _ProductGridCard(
                            item: filtered[i],
                            fmt: fmt,
                            onTap: () => _showProductDetailSheet(filtered[i]),
                          )
                          .animate()
                          .fadeIn(
                            delay: Duration(milliseconds: 25 * (i % 24)),
                            duration: 300.ms,
                          )
                          .slideY(
                            begin: 0.15,
                            end: 0,
                            delay: Duration(milliseconds: 25 * (i % 24)),
                            duration: 300.ms,
                            curve: Curves.easeOut,
                          ),
                ),
        ),
      ],
    );
  }

  Widget _buildStockBajoTab(InventoryProvider provider) {
    final allLow =
        provider.inventoryItems.where((i) => i.quantity <= 5).toList()
          ..sort((a, b) => a.quantity.compareTo(b.quantity));

    return StatefulBuilder(
      builder: (context, setLocal) {
        // Filtros: 0=Todos, 1=Agotado(=0), 2=Pedir(1-2), 3=Estable(3-5)
        int activeFilter = 0;
        List<InventoryItem> filtered = allLow;

        return StatefulBuilder(
          builder: (context, setFilter) {
            switch (activeFilter) {
              case 1:
                filtered = allLow.where((i) => i.quantity == 0).toList();
                break;
              case 2:
                filtered = allLow
                    .where((i) => i.quantity >= 1 && i.quantity <= 2)
                    .toList();
                break;
              case 3:
                filtered = allLow
                    .where((i) => i.quantity >= 3 && i.quantity <= 5)
                    .toList();
                break;
              default:
                filtered = allLow;
            }

            return Column(
              children: [
                // ── Encabezado con contador y alerta ─────────────────
                Container(
                      color: AppColors.lightGray,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.lightGray,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.filter_list,
                              size: 20,
                              color: AppColors.darkGray,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Filtros de Stock Bajo',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              RichText(
                                text: TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '${filtered.length} ',
                                      style: const TextStyle(
                                        color: AppColors.primaryRed,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    TextSpan(
                                      text: 'de ${allLow.length} productos',
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.lightRed,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.warning_amber_rounded,
                              color: AppColors.primaryRed,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    )
                    .animate()
                    .fadeIn(duration: 350.ms)
                    .slideY(
                      begin: -0.1,
                      end: 0,
                      duration: 350.ms,
                      curve: Curves.easeOut,
                    ),

                // ── Chips de filtro ───────────────────────────────────
                Container(
                  color: AppColors.lightGray,
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _FilterChip(
                          label: 'Todos',
                          icon: Icons.apps,
                          active: activeFilter == 0,
                          onTap: () => setFilter(() => activeFilter = 0),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Agotado (=0)',
                          icon: Icons.cancel_outlined,
                          active: activeFilter == 1,
                          color: AppColors.primaryRed,
                          onTap: () => setFilter(() => activeFilter = 1),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Pedir (≤Mín)',
                          icon: Icons.warning_amber_rounded,
                          active: activeFilter == 2,
                          color: Colors.orange,
                          onTap: () => setFilter(() => activeFilter = 2),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Estable',
                          icon: Icons.check_circle_outline,
                          active: activeFilter == 3,
                          color: Colors.green,
                          onTap: () => setFilter(() => activeFilter = 3),
                        ),
                        const SizedBox(width: 8),
                        _FilterChip(
                          label: 'Exceso (≥Max)',
                          icon: Icons.trending_up,
                          active: activeFilter == 4,
                          color: AppColors.primaryBlue,
                          onTap: () => setFilter(() => activeFilter = 4),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 80.ms, duration: 350.ms),

                const SizedBox(height: 10),

                // ── Lista de productos ────────────────────────────────
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.check_circle_outline,
                                color: Colors.green,
                                size: 48,
                              ),
                              SizedBox(height: 12),
                              Text(
                                '¡Sin productos en este filtro!',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 12,
                          ),
                          itemCount: filtered.length,
                          itemBuilder: (_, i) {
                            final item = filtered[i];
                            final isZero = item.quantity == 0;
                            final isLow = !isZero && item.quantity <= 5;
                            return _StockBajoRow(
                                  item: item,
                                  isZero: isZero,
                                  isLow: isLow,
                                  onTap: () => _showProductDetailSheet(item),
                                )
                                .animate()
                                .fadeIn(
                                  delay: Duration(milliseconds: 40 * (i % 20)),
                                  duration: 320.ms,
                                )
                                .slideX(
                                  begin: -0.1,
                                  end: 0,
                                  delay: Duration(milliseconds: 40 * (i % 20)),
                                  duration: 320.ms,
                                  curve: Curves.easeOut,
                                );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ── Secciones del Resumen ────────────────────────────────────────

class _InversionCard extends StatelessWidget {
  final InventoryProvider provider;
  final List<InventoryItem> items;
  final NumberFormat fmt;

  const _InversionCard({
    required this.provider,
    required this.items,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    final compraTotalAll = items.fold<double>(
      0,
      (s, i) => s + i.costPrice * i.quantity,
    );
    final ventaTotalAll = items.fold<double>(
      0,
      (s, i) => s + i.sellPrice * i.quantity,
    );
    final diferencia = ventaTotalAll - compraTotalAll;
    final pct = compraTotalAll == 0 ? 0.0 : (diferencia / compraTotalAll) * 100;
    final conExistencia = items.where((i) => i.quantity > 0).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.whiteOverlay,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.lightBlue,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: AppColors.primaryBlue,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Inversión en Bodega (stock existente)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$conExistencia productos con existencia > 0',
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _InvBox(
                  icon: Icons.shopping_cart_outlined,
                  iconColor: Colors.orange,
                  label: 'Compra total',
                  value: fmt.format(compraTotalAll),
                  valueColor: Colors.orange,
                  bgColor: const Color(0xFFFFF3E0),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InvBox(
                  icon: Icons.label_outline,
                  iconColor: AppColors.primaryBlue,
                  label: 'Venta total',
                  value: fmt.format(ventaTotalAll),
                  valueColor: AppColors.primaryBlue,
                  bgColor: const Color(0xFFE8F0FB),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _InvBox(
                  icon: Icons.trending_up,
                  iconColor: Colors.green,
                  label: 'Diferencia',
                  value:
                      '${fmt.format(diferencia)} (${pct.toStringAsFixed(1)}%)',
                  valueColor: Colors.green,
                  bgColor: const Color(0xFFE8F5E9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InvBox extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color valueColor;
  final Color bgColor;

  const _InvBox({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Colors.black54),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _DonutChartCard extends StatelessWidget {
  final int outOfStock;
  final int toOrder;
  final int stable;
  final int excess;

  const _DonutChartCard({
    required this.outOfStock,
    required this.toOrder,
    required this.stable,
    required this.excess,
  });

  @override
  Widget build(BuildContext context) {
    final total = outOfStock + toOrder + stable + excess;
    if (total == 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.whiteOverlay,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Distribución de Stock',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(
                    value: outOfStock.toDouble(),
                    color: AppColors.primaryRed,
                    title: '',
                    radius: 40,
                  ),
                  PieChartSectionData(
                    value: toOrder.toDouble(),
                    color: Colors.orange,
                    title: '',
                    radius: 40,
                  ),
                  PieChartSectionData(
                    value: stable.toDouble(),
                    color: Colors.green,
                    title: '',
                    radius: 40,
                  ),
                  PieChartSectionData(
                    value: excess.toDouble(),
                    color: AppColors.primaryBlue,
                    title: '',
                    radius: 40,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _Legend(
            color: AppColors.primaryRed,
            label: 'Agotado',
            value: outOfStock,
          ),
          _Legend(color: Colors.orange, label: 'Pedir', value: toOrder),
          _Legend(color: Colors.green, label: 'Estable', value: stable),
          _Legend(color: AppColors.primaryBlue, label: 'Exceso', value: excess),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;
  final int value;

  const _Legend({
    required this.color,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(Icons.circle, color: color, size: 10),
          const SizedBox(width: 6),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 11))),
          Text(
            value.toString(),
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _BarChartCard extends StatelessWidget {
  final List<InventoryItem> items;

  const _BarChartCard({required this.items});

  @override
  Widget build(BuildContext context) {
    // Rangos: 0, 1-5, 6-10, 11-20, 21-50, 50+
    final r0 = items.where((i) => i.quantity == 0).length;
    final r1 = items.where((i) => i.quantity >= 1 && i.quantity <= 5).length;
    final r2 = items.where((i) => i.quantity >= 6 && i.quantity <= 10).length;
    final r3 = items.where((i) => i.quantity >= 11 && i.quantity <= 20).length;
    final r4 = items.where((i) => i.quantity >= 21 && i.quantity <= 50).length;
    final r5 = items.where((i) => i.quantity > 50).length;
    final maxY = [
      r0,
      r1,
      r2,
      r3,
      r4,
      r5,
    ].fold<int>(1, (m, v) => v > m ? v : m).toDouble();
    final colors = [
      AppColors.primaryRed,
      Colors.orange,
      const Color(0xFFD4A017),
      AppColors.primaryBlue,
      Colors.green,
      Colors.purple,
    ];
    final labels = ['0', '1-5', '6-10', '11-20', '21-50', '50+'];
    final counts = [r0, r1, r2, r3, r4, r5];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.whiteOverlay,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rangos de Stock',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: BarChart(
              BarChartData(
                maxY: maxY * 1.2,
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (v, _) => Text(
                        labels[v.toInt()],
                        style: const TextStyle(fontSize: 8),
                      ),
                    ),
                  ),
                ),
                barGroups: List.generate(
                  6,
                  (i) => BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: counts[i].toDouble(),
                        color: colors[i],
                        width: 14,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
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

class _AttencionSection extends StatelessWidget {
  final List<InventoryItem> items;
  final NumberFormat fmt;

  const _AttencionSection({required this.items, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final needAttention = items.where((i) => i.quantity <= 2).toList()
      ..sort((a, b) => a.quantity.compareTo(b.quantity));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.whiteOverlay,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.primaryRed,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Productos que Requieren Atención',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.lightRed,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${items.length} productos',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.primaryRed,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (needAttention.isEmpty)
            const Text(
              'Todos los productos tienen stock suficiente.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            )
          else
            ...needAttention
                .take(10)
                .map((item) => _AttentionRow(item: item, fmt: fmt)),
        ],
      ),
    );
  }
}

class _AttentionRow extends StatelessWidget {
  final InventoryItem item;
  final NumberFormat fmt;

  const _AttentionRow({required this.item, required this.fmt});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.lightGray,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppColors.lightRed,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: AppColors.primaryRed,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  item.sku,
                  style: const TextStyle(fontSize: 10, color: Colors.black45),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Stock: ${item.quantity} | Compra: \$${fmt.format(item.costPrice)}',
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: item.quantity == 0 ? AppColors.primaryRed : Colors.orange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${item.quantity}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets privados ──────────────────────────────────────────────

class _ProductGridCard extends StatelessWidget {
  final InventoryItem item;
  final NumberFormat fmt;
  final VoidCallback onTap;

  const _ProductGridCard({
    required this.item,
    required this.fmt,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isZero = item.quantity == 0;
    final isLow = !isZero && item.quantity <= 5;
    final stockColor = isZero
        ? AppColors.primaryRed
        : isLow
        ? Colors.orange
        : Colors.green;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.whiteOverlay,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Nombre + ícono de alerta
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isZero || isLow)
                          Padding(
                            padding: const EdgeInsets.only(left: 2),
                            child: Icon(
                              Icons.warning_amber_rounded,
                              color: isZero
                                  ? AppColors.primaryRed
                                  : Colors.orange,
                              size: 14,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Código:',
                      style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                    ),
                    Text(
                      item.sku,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Almacén: ',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[600],
                          ),
                        ),
                        Text(
                          item.quantity.toString(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: stockColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            // Precio compra
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.lightGreen,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(12),
                  ),
                ),
                child: Text(
                  'Compra: \$${fmt.format(item.costPrice)}',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTab extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavTab({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            border: isSelected
                ? const Border(
                    bottom: BorderSide(color: AppColors.whiteOverlay, width: 2),
                  )
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.whiteOverlay : Colors.white54,
                size: 20,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.whiteOverlay : Colors.white54,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String value;
  final String label;
  final String sublabel;
  final String? badge;
  final Color? badgeColor;
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final Color bgColor;
  final Color valueColor;

  const _StatusCard({
    required this.value,
    required this.label,
    required this.sublabel,
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.bgColor,
    required this.valueColor,
    this.badge,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: Container(
        width: 145,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: valueColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sublabel,
                style: const TextStyle(fontSize: 10, color: Colors.black54),
                maxLines: 2,
              ),
              if (badge != null) ...[
                const SizedBox(height: 4),
                Text(
                  '● $badge',
                  style: TextStyle(
                    fontSize: 9,
                    color: badgeColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickStatCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;
  final Color dotColor;

  const _QuickStatCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
    required this.dotColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.whiteOverlay,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 16),
              const Spacer(),
              Icon(Icons.circle, color: dotColor, size: 8),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: iconColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

// ── Stock Bajo: fila de producto ─────────────────────────────────

class _StockBajoRow extends StatelessWidget {
  final InventoryItem item;
  final bool isZero;
  final bool isLow;
  final VoidCallback onTap;

  const _StockBajoRow({
    required this.item,
    required this.isZero,
    required this.isLow,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color iconBg = isZero ? AppColors.lightRed : const Color(0xFFFFEDD5);
    final Color iconColor = isZero ? AppColors.primaryRed : Colors.orange;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: AppColors.whiteOverlay,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 3,
              offset: Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            // Ícono con cantidad
            Container(
              width: 60,
              height: 72,
              margin: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isZero
                        ? Icons.cancel_outlined
                        : Icons.warning_amber_rounded,
                    color: iconColor,
                    size: 22,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.quantity.toString(),
                    style: TextStyle(
                      color: iconColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Código: ${item.sku.isNotEmpty ? item.sku : 'Prod${item.productId.toString().padLeft(9, '0')}'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black45,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Stock: ${item.quantity} / 5',
                      style: TextStyle(
                        fontSize: 11,
                        color: isZero ? AppColors.primaryRed : Colors.orange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Botón carrito
            Container(
              margin: const EdgeInsets.only(right: 10),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.blackOverlay,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.shopping_cart_outlined,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Chip de filtro ────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.active,
    required this.onTap,
    this.color = AppColors.darkGray,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: active ? color : Colors.transparent,
          border: Border.all(color: active ? color : Colors.black26, width: 1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: active ? Colors.white : color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: active ? Colors.white : Colors.black87,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
