import 'dart:math';

import 'package:tienda/Presentation/Template/catalog_template.dart';
import 'package:go_router/go_router.dart';
import 'package:tienda/Presentation/Controller/Catalog/catalog_controller.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:tienda/Presentation/Widgets/Catalog/catalog_card_widget.dart';
import 'package:tienda/Presentation/Widgets/Products/shared_inputs.dart';
import 'package:tienda/Presentation/Widgets/legal_page_widget.dart';
import 'package:flutter/material.dart';

class CatalogLoadingState extends StatefulWidget {
  const CatalogLoadingState({super.key});

  @override
  State<CatalogLoadingState> createState() => _CatalogLoadingStateState();
}

class _CatalogLoadingStateState extends State<CatalogLoadingState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.rotate(
                angle: _controller.value * 2 * pi,
                child: SizedBox(
                  width: 82,
                  height: 82,
                  child: const Center(
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.primaryLogo,
                      size: 48,
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          Text(
            'Cargando catálogo',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.primaryLogo,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Conectando con Drive y preparando tus productos',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.mediumGray,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              _LoadingDot(color: AppColors.primaryLogo),
              SizedBox(width: 8),
              _LoadingDot(color: AppColors.primaryBlue),
              SizedBox(width: 8),
              _LoadingDot(color: AppColors.primaryRed),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadingDot extends StatelessWidget {
  final Color color;

  const _LoadingDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 500),
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class CatalogSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool isCompact;

  const CatalogSearchBar({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onSubmitted,
    required this.isCompact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: SharedTextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onChanged: onChanged,
        onSubmitted: onSubmitted,
        hint: 'Buscar producto',
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        useFilterStyle: true,
      ),
    );
  }
}

class CategoryFilter extends StatelessWidget {
  final List<CatalogCategory> categories;
  final CatalogCategory? selectedCategory;
  final ValueChanged<CatalogCategory?> onChanged;

  const CategoryFilter({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: DropdownMenu<CatalogCategory?>(
          initialSelection: selectedCategory,
          onSelected: onChanged,
          width: double.infinity,
          textStyle: theme.textTheme.bodyMedium,
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(
                color: theme.colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
          menuStyle: MenuStyle(
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
          dropdownMenuEntries: [
            const DropdownMenuEntry<CatalogCategory?>(
              value: null,
              label: 'Todas las categorías',
            ),
            ...categories.map(
              (category) => DropdownMenuEntry<CatalogCategory?>(
                value: category,
                label: category.name,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CatalogFilters extends StatelessWidget {
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String>? onSearchSubmitted;
  final List<CatalogCategory> categories;
  final CatalogCategory? selectedCategory;
  final ValueChanged<CatalogCategory?> onCategoryChanged;
  final int resultCount;

  const CatalogFilters({
    super.key,
    required this.searchController,
    required this.onSearchChanged,
    this.onSearchSubmitted,
    required this.categories,
    required this.selectedCategory,
    required this.onCategoryChanged,
    required this.resultCount,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 720;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: CatalogSearchBar(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    onSubmitted: onSearchSubmitted,
                    isCompact: isCompact,
                  ),
                ),
                if (!isCompact) const SizedBox(width: 12),
                if (!isCompact)
                  Expanded(
                    child: Center(
                      child: CategoryFilter(
                        categories: categories,
                        selectedCategory: selectedCategory,
                        onChanged: onCategoryChanged,
                      ),
                    ),
                  ),
              ],
            ),
            if (isCompact) ...[
              const SizedBox(height: 12),
              CategoryFilter(
                categories: categories,
                selectedCategory: selectedCategory,
                onChanged: onCategoryChanged,
              ),
            ],
            const SizedBox(height: 12),
            Text(
              '$resultCount productos encontrados',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.mediumGray,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Vista pública del catálogo — solo para web.
/// Muestra los artículos disponibles con selector de sección (Bazar / Papelería).
/// Los datos reales (productos e imágenes) se cargan desde el backup en Google Drive.
class WebCatalogView extends StatefulWidget {
  final CatalogController controller;
  final String? initialCategoryId;
  final String? initialStoreId;
  final String? initialSearch;

  const WebCatalogView({
    super.key,
    required this.controller,
    this.initialCategoryId,
    this.initialStoreId,
    this.initialSearch,
  });

  @override
  State<WebCatalogView> createState() => _WebCatalogViewState();
}

class _WebCatalogViewState extends State<WebCatalogView>
    with TickerProviderStateMixin {
  TabController? _tabController;
  final TextEditingController _searchController = TextEditingController();
  CatalogCategory? _selectedCategory;
  String _search = '';
  bool _initialStateApplied = false;
  bool _isApplyingInitialTab = false;

  List<CatalogSection> get _sections => widget.controller.sections;
  bool get _driveLoading => widget.controller.isLoading;
  String? get _driveError => widget.controller.errorMessage;

  void _loadDriveData() {
    widget.controller.refresh();
  }

  @override
  void initState() {
    super.initState();
    _search = widget.initialSearch?.trim().isNotEmpty == true
        ? widget.initialSearch!.trim()
        : widget.controller.currentSearch;
    _searchController.text = _search;

    if (widget.initialCategoryId != null) {
      _selectedCategory = widget.controller.categoryById(
        widget.initialCategoryId!,
      );
      widget.controller.selectedCategoryId = widget.initialCategoryId;
    } else if (widget.controller.selectedCategoryId != null) {
      _selectedCategory = widget.controller.categoryById(
        widget.controller.selectedCategoryId!,
      );
    }

    if (widget.initialStoreId != null) {
      widget.controller.selectedStoreId = widget.initialStoreId;
    }

    widget.controller.addListener(_onControllerChanged);
    if (widget.controller.isReady) {
      _applyInitialRouteState();
    } else {
      widget.controller.initialize();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _searchController.dispose();
    _tabController?.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (widget.controller.isReady && !_initialStateApplied) {
      _applyInitialRouteState();
    }
    setState(() {});
  }

  void _applyInitialRouteState() {
    _initialStateApplied = true;
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();
    _tabController = TabController(
      length: _sections.isEmpty ? 1 : _sections.length,
      vsync: this,
    );
    _tabController!.addListener(_onTabChanged);

    _isApplyingInitialTab = true;
    if (widget.initialStoreId != null) {
      final index = _sections.indexWhere(
        (section) => section.storeId.toString() == widget.initialStoreId,
      );
      if (index >= 0 && _tabController != null) {
        _tabController!.index = index;
      }
    }
    _isApplyingInitialTab = false;

    if (widget.initialCategoryId != null) {
      _selectedCategory = widget.controller.categoryById(
        widget.initialCategoryId!,
      );
    }
  }

  void _onTabChanged() {
    if (!mounted || _isApplyingInitialTab || _tabController == null) {
      return;
    }

    if (_tabController!.indexIsChanging) {
      return;
    }

    setState(() {
      _selectedCategory = null;
      widget.controller.selectedCategoryId = null;
    });
  }

  void _onSearchSubmitted(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      GoRouter.of(context).go('/catalog');
      return;
    }
    GoRouter.of(context).go('/search/${Uri.encodeComponent(trimmed)}');
  }

  List<CatalogCategory> _filteredCategories(List<CatalogCategory> items) {
    final q = _search.trim().toLowerCase();

    return items.where((category) {
      final matchesCategory =
          _selectedCategory == null || category.id == _selectedCategory!.id;
      if (!matchesCategory) {
        return false;
      }

      final matchesProducts = q.isEmpty
          ? category.products.isNotEmpty
          : category.products.any(
              (product) => product.name.toLowerCase().contains(q),
            );

      return matchesProducts;
    }).toList();
  }

  int _countVisibleProducts(List<CatalogCategory> categories) {
    final q = _search.trim().toLowerCase();
    return categories.fold<int>(0, (total, category) {
      final visibleProducts = q.isEmpty
          ? category.products.length
          : category.products
                .where((product) => product.name.toLowerCase().contains(q))
                .length;
      return total + visibleProducts;
    });
  }

  CatalogSection? get _currentSection {
    if (_sections.isEmpty) return null;
    if (_tabController != null && _tabController!.index < _sections.length) {
      return _sections[_tabController!.index];
    }
    return _sections.first;
  }

  List<CatalogCategory> get _currentSectionCategories =>
      _currentSection?.categories ?? <CatalogCategory>[];

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width > 700;

    final currentSectionCategories = _currentSectionCategories;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F8),
      appBar: AppBar(
        backgroundColor: AppColors.primaryLogo,
        foregroundColor: Colors.white,
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.storefront_outlined, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    'Bazar & Tienda Nicole',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Catálogo de productos',
                    style: TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_driveLoading)
            const Padding(
              padding: EdgeInsets.only(right: 14),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white70,
                  ),
                ),
              ),
            )
          else if (widget.controller.isReady)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Tooltip(
                message: 'Datos en tiempo real desde Google Drive',
                child: const Icon(
                  Icons.cloud_done_outlined,
                  color: Colors.white70,
                  size: 20,
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: TextButton.icon(
                onPressed: _loadDriveData,
                icon: const Icon(
                  Icons.refresh_outlined,
                  color: Colors.white60,
                  size: 18,
                ),
                label: const Text(
                  'Reintentar',
                  style: TextStyle(color: Colors.white60, fontSize: 11),
                ),
              ),
            ),
        ],
        bottom: _sections.isEmpty
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(52),
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: Colors.white,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white60,
                  tabs: _sections
                      .map(
                        (s) => Tab(
                          icon: Icon(
                            s.storeId == 1
                                ? Icons.shopping_bag_outlined
                                : s.storeId == 2
                                ? Icons.storefront_outlined
                                : Icons.menu_book_outlined,
                          ),
                          text: s.storeName,
                        ),
                      )
                      .toList(),
                ),
              ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_driveError != null)
            _DriveBanner(message: _driveError!, onRetry: _loadDriveData),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      isTablet ? 28 : 16,
                      20,
                      isTablet ? 28 : 16,
                      8,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        if (_sections.isNotEmpty)
                          CatalogFilters(
                            searchController: _searchController,
                            onSearchChanged: (value) {
                              setState(() {
                                _search = value;
                                widget.controller.currentSearch = value;
                              });
                            },
                            onSearchSubmitted: _onSearchSubmitted,
                            categories: currentSectionCategories,
                            selectedCategory: _selectedCategory,
                            onCategoryChanged: (category) {
                              setState(() {
                                _selectedCategory = category;
                                widget.controller.selectedCategoryId = category
                                    ?.id
                                    .toString();
                              });
                            },
                            resultCount: _countVisibleProducts(
                              _filteredCategories(currentSectionCategories),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (widget.controller.isLoading && _sections.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: CatalogLoadingState(),
                  )
                else if (_sections.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.cloud_off_outlined,
                            size: 48,
                            color: AppColors.greyOverlay,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No se pudo cargar el catálogo',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _loadDriveData,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Reintentar'),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        isTablet ? 28 : 16,
                        8,
                        isTablet ? 28 : 16,
                        24,
                      ),
                      child: _CatalogGrid(
                        sections: _currentSection == null
                            ? <CatalogSection>[]
                            : <CatalogSection>[_currentSection!],
                        search: _search,
                        selectedCategory: _selectedCategory,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Container(
            color: AppColors.primaryLogo,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            width: double.infinity,
            child: Column(
              children: [
                const Text(
                  '© 2026 Bazar & Tienda Nicole — Todos los derechos reservados',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () =>
                          LegalPageWidget.show(context, LegalDocType.terms),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 0,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Términos y Condiciones',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white54,
                        ),
                      ),
                    ),
                    const Text(
                      '·',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                    TextButton(
                      onPressed: () =>
                          LegalPageWidget.show(context, LegalDocType.privacy),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 0,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Política de Privacidad',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white54,
                        ),
                      ),
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

// ── Banner de estado de Drive ────────────────────────────────────────────────

class _DriveBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _DriveBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFFFF3CD),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_outlined,
            color: Color(0xFF856404),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No se pudieron cargar datos desde Drive. Mostrando catálogo base.',
              style: const TextStyle(fontSize: 11, color: Color(0xFF856404)),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: const Text(
              'Reintentar',
              style: TextStyle(fontSize: 11, color: Color(0xFF856404)),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Grid de categorías ───────────────────────────────────────────────────────

class _CatalogGrid extends StatelessWidget {
  final List<CatalogSection> sections;
  final String search;
  final CatalogCategory? selectedCategory;

  const _CatalogGrid({
    required this.sections,
    required this.search,
    required this.selectedCategory,
  });

  @override
  Widget build(BuildContext context) {
    final filteredSections = sections
        .map((section) {
          final categories = section.categories.where((category) {
            final q = search.trim().toLowerCase();
            final matchesCategory =
                selectedCategory == null || category.id == selectedCategory!.id;
            final matchesProducts = q.isEmpty
                ? category.products.isNotEmpty
                : category.products.any(
                    (product) => product.name.toLowerCase().contains(q),
                  );
            return matchesCategory && matchesProducts;
          }).toList();

          return CatalogSection(
            storeId: section.storeId,
            storeName: section.storeName,
            categories: categories,
          );
        })
        .where((section) => section.categories.isNotEmpty)
        .toList();

    if (filteredSections.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 48, color: AppColors.greyOverlay),
            const SizedBox(height: 8),
            const Text('No se encontraron artículos'),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const minCardWidth = 280.0;
        const maxCardWidth = 340.0;
        const spacing = 16.0;

        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width;
        final columns = (availableWidth / minCardWidth).floor().clamp(1, 4);
        final cardWidth = ((availableWidth - (columns - 1) * spacing) / columns)
            .clamp(minCardWidth, maxCardWidth);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final section in filteredSections) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 14, top: 4),
                child: Text(
                  section.storeName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryLogo,
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: section.categories
                      .map(
                        (category) => SizedBox(
                          width: cardWidth,
                          child: CatalogCategoryCard(
                            name: category.name,
                            storeName: category.storeName,
                            info: category,
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 18),
            ],
          ],
        );
      },
    );
  }
}
