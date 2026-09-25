import 'package:tienda/Presentation/Services/database_service.dart';
import 'package:tienda/Presentation/Services/catalog_sync_service.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:flutter/material.dart';

class CategoryManagementView extends StatefulWidget {
  const CategoryManagementView({super.key});

  @override
  State<CategoryManagementView> createState() => _CategoryManagementViewState();
}

class _CategoryManagementViewState extends State<CategoryManagementView> {
  List<Map<String, dynamic>> _categories = const [];
  List<Map<String, dynamic>> _stores = const [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        DatabaseService.getCategories(),
        DatabaseService.getStores(),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = results[0];
        _stores = results[1];
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _openEditor([Map<String, dynamic>? category]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _CategoryDialog(category: category, stores: _stores),
    );
    if (saved == true) {
      CatalogSyncService.instance.markDirty();
      await _loadData();
    }
  }

  Future<void> _deleteCategory(Map<String, dynamic> category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar categoría'),
        content: Text('¿Quieres eliminar “${category['name']}”?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await DatabaseService.deleteCategory((category['id'] as num).toInt());
      CatalogSyncService.instance.markDirty();
      await _loadData();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.lightGray,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: ClipRRect(
          clipBehavior: Clip.hardEdge,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(25),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.blackOverlay,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.blackOverlay, AppColors.blackOverlay],
              ),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.primaryLogo,
                  blurRadius: 5,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: AppBar(
              surfaceTintColor: Colors.transparent,
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: const Text(
                'Categorías',
                style: TextStyle(
                  color: AppColors.whiteOverlay,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
                  tooltip: 'Actualizar',
                  onPressed: _isLoading ? null : _loadData,
                  icon: const Icon(
                    Icons.refresh,
                    color: AppColors.whiteOverlay,
                    size: 30,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: FilledButton.icon(
                    onPressed: () => _openEditor(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.whiteOverlay,
                      foregroundColor: AppColors.blackOverlay,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(
                      Icons.add,
                      color: AppColors.blackOverlay,
                      size: 30,
                    ),
                    label: const Text('Nueva categoría'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorState(message: _error!, onRetry: _loadData)
          : _categories.isEmpty
          ? _EmptyState(onCreate: () => _openEditor())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final category = _categories[index];
                  final imageUrl = category['image_url'] as String? ?? '';
                  final store = _stores
                      .cast<Map<String, dynamic>?>()
                      .firstWhere(
                        (item) => item?['id'] == category['store_id'],
                        orElse: () => null,
                      );
                  final products =
                      (category['product_count'] as num?)?.toInt() ?? 0;
                  return Card(
                    color: AppColors.whiteOverlay,
                    elevation: 2,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: AppColors.blackOverlay.withValues(alpha: 0.08),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                      leading: _CategoryImage(url: imageUrl),
                      title: Text(
                        category['name'] as String? ?? '',
                        style: const TextStyle(
                          color: AppColors.darkGray,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        '${store?['name'] ?? 'Sin tienda'} · $products producto(s)',
                        style: const TextStyle(color: AppColors.mediumGray),
                      ),
                      trailing: Wrap(
                        children: [
                          IconButton(
                            tooltip: 'Editar',
                            onPressed: () => _openEditor(category),
                            icon: const Icon(Icons.edit_outlined),
                          ),
                          IconButton(
                            tooltip: 'Eliminar',
                            onPressed: () => _deleteCategory(category),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({required this.category, required this.stores});

  final Map<String, dynamic>? category;
  final List<Map<String, dynamic>> stores;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _imageController;
  int? _storeId;
  bool _isSaving = false;

  bool get _isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();
    final category = widget.category;
    _nameController = TextEditingController(
      text: category?['name'] as String? ?? '',
    );
    _imageController = TextEditingController(
      text: category?['image_url'] as String? ?? '',
    );
    _storeId = (category?['store_id'] as num?)?.toInt();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _imageController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    final imageUrl = _imageController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un nombre para la categoría.')),
      );
      return;
    }
    if (imageUrl.isNotEmpty) {
      final uri = Uri.tryParse(imageUrl);
      if (uri == null ||
          !uri.hasScheme ||
          (uri.scheme != 'http' && uri.scheme != 'https')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La imagen debe ser una URL http o https.'),
          ),
        );
        return;
      }
    }

    setState(() => _isSaving = true);
    try {
      if (_isEditing) {
        await DatabaseService.updateCategory(
          categoryId: (widget.category!['id'] as num).toInt(),
          name: name,
          storeId: _storeId,
          imageUrl: imageUrl,
        );
      } else {
        await DatabaseService.createCategory(
          name: name,
          storeId: _storeId,
          imageUrl: imageUrl,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final imageUrl = _imageController.text.trim();
    return AlertDialog(
      backgroundColor: AppColors.whiteOverlay,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(_isEditing ? 'Editar categoría' : 'Nueva categoría'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nombre',
                  labelStyle: TextStyle(color: AppColors.mediumGray),
                  prefixIcon: Icon(Icons.category_outlined),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int?>(
                value: _storeId,
                decoration: const InputDecoration(
                  labelText: 'Tienda',
                  labelStyle: TextStyle(color: AppColors.mediumGray),
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Sin tienda'),
                  ),
                  ...widget.stores.map(
                    (store) => DropdownMenuItem<int?>(
                      value: (store['id'] as num).toInt(),
                      child: Text(store['name'] as String),
                    ),
                  ),
                ],
                onChanged: _isSaving
                    ? null
                    : (value) => setState(() => _storeId = value),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _imageController,
                keyboardType: TextInputType.url,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'URL de imagen de portada',
                  hintText: 'https://sitio.com/imagen.jpg',
                  labelStyle: TextStyle(color: AppColors.mediumGray),
                  prefixIcon: Icon(Icons.image_outlined),
                ),
              ),
              if (imageUrl.isNotEmpty) ...[
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: SizedBox(
                    height: 130,
                    width: double.infinity,
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: AppColors.greyOverlay,
                        alignment: Alignment.center,
                        child: const Text('No se pudo cargar la imagen'),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton.icon(
          onPressed: _isSaving ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.blackOverlay,
            foregroundColor: AppColors.whiteOverlay,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: _isSaving
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _CategoryImage extends StatelessWidget {
  const _CategoryImage({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 64,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: url.isEmpty
            ? Container(
                color: AppColors.greyOverlay,
                child: const Icon(Icons.image_outlined),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: AppColors.greyOverlay,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: AppColors.whiteOverlay,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.blackOverlay.withValues(alpha: 0.08),
          ),
        ),
        child: FilledButton.icon(
          onPressed: onCreate,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.blackOverlay,
            foregroundColor: AppColors.whiteOverlay,
          ),
          icon: const Icon(Icons.add),
          label: const Text('Crear primera categoría'),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.whiteOverlay,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.primaryRed.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: AppColors.primaryRed),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.darkGray),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.blackOverlay,
                side: const BorderSide(color: AppColors.blackOverlay),
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
