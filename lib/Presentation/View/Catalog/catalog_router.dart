import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../Controller/Catalog/catalog_controller.dart';
import 'web_catalog_view.dart';
import 'product_detail_page.dart';

class CatalogRouter {
  static GoRouter createRouter({required CatalogController controller}) {
    return GoRouter(
      initialLocation: '/catalog',
      routes: [
        GoRoute(
          path: '/catalog',
          builder: (context, state) =>
              _selectable(WebCatalogView(controller: controller)),
        ),
        GoRoute(
          path: '/catalog/:sku',
          builder: (context, state) => _selectable(
            _CatalogDetailRoute(
              controller: controller,
              sku: Uri.decodeComponent(state.pathParameters['sku'] ?? ''),
            ),
          ),
        ),
        GoRoute(
          path: '/category/:categoryId',
          builder: (context, state) => _selectable(
            WebCatalogView(
              controller: controller,
              initialCategoryId: state.pathParameters['categoryId'],
            ),
          ),
        ),
        GoRoute(
          path: '/store/:storeId',
          builder: (context, state) => _selectable(
            WebCatalogView(
              controller: controller,
              initialStoreId: state.pathParameters['storeId'],
            ),
          ),
        ),
        GoRoute(
          path: '/search/:text',
          builder: (context, state) => _selectable(
            WebCatalogView(
              controller: controller,
              initialSearch: Uri.decodeComponent(
                state.pathParameters['text'] ?? '',
              ),
              initialStoreId: null,
            ),
          ),
        ),
      ],
      errorBuilder: (context, state) => _selectable(
        Scaffold(
          appBar: AppBar(title: const Text('Ruta no encontrada')),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('La ruta solicitada no existe.'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => context.go('/catalog'),
                  child: const Text('Volver al catálogo'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _selectable(Widget child) => SelectionArea(child: child);

class _CatalogDetailRoute extends StatefulWidget {
  final CatalogController controller;
  final String sku;

  const _CatalogDetailRoute({required this.controller, required this.sku});

  @override
  State<_CatalogDetailRoute> createState() => _CatalogDetailRouteState();
}

class _CatalogDetailRouteState extends State<_CatalogDetailRoute> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    widget.controller.initialize();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (widget.controller.errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error de catálogo')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(widget.controller.errorMessage!),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  widget.controller.refresh();
                },
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    if (!widget.controller.isReady) {
      return const Scaffold(body: CatalogLoadingState());
    }

    debugPrint('[CatalogDetail] route key: ${widget.sku}');
    debugPrint('[CatalogDetail] isLoading: ${widget.controller.isLoading}');
    debugPrint('[CatalogDetail] isReady: ${widget.controller.isReady}');
    debugPrint('[CatalogDetail] buscando producto...');
    final product = widget.controller.productByRouteKey(widget.sku);
    debugPrint(
      '[CatalogDetail] ${product == null ? 'producto NO encontrado' : 'producto encontrado: ${product.name}'}',
    );
    if (product == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Producto no encontrado')),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Producto no encontrado'),
              const SizedBox(height: 8),
              Text('Clave: ${widget.sku}'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.go('/catalog'),
                child: const Text('Volver al catálogo'),
              ),
            ],
          ),
        ),
      );
    }

    return ProductDetailPage(product: product);
  }
}
