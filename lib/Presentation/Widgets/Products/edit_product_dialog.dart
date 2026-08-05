import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tienda/Presentation/Controller/product_management_controller.dart';
import 'shared_inputs.dart';

Future<void> showEditProductDialog(
  BuildContext context,
  ProductManagementController controller,
  Map<String, dynamic> item,
) async {
  final nameController = TextEditingController(
    text: item['name']?.toString() ?? '',
  );
  String? editCategory = item['category']?.toString();
  final skuController = TextEditingController(
    text: item['sku']?.toString() ?? '',
  );
  final auxCodeController = TextEditingController(
    text: item['aux_code']?.toString() ?? '',
  );
  final descriptionController = TextEditingController(
    text: item['description']?.toString() ?? '',
  );
  final tagsController = TextEditingController(
    text: item['tags']?.toString() ?? '',
  );
  final priceController = TextEditingController(
    text: ((item['price'] as num?)?.toDouble() ?? 0).toStringAsFixed(2),
  );
  final costPriceController = TextEditingController(
    text: ((item['cost_price'] as num?)?.toDouble() ?? 0).toStringAsFixed(2),
  );
  final ivaRateController = TextEditingController(
    text: ((item['iva_rate'] as num?)?.toDouble() ?? 0).toStringAsFixed(2),
  );
  final profitIvaController = TextEditingController(
    text: ((item['profit_iva'] as num?)?.toDouble() ?? 0).toStringAsFixed(2),
  );

  int? editStoreId = item['store_id'] != null
      ? (item['store_id'] as num).toInt()
      : null;
  List<String> editImages =
      item['images'] != null && (item['images'] as String).isNotEmpty
      ? (item['images'] as String).split(',')
      : [];
  bool isUploadingEditImages = false;
  bool isSavingEdit = false;
  final bazarStockController = TextEditingController(
    text: ((item['stock_bazar'] as num?)?.toInt() ?? 0).toString(),
  );
  final tiendaStockController = TextEditingController(
    text: ((item['stock_tienda'] as num?)?.toInt() ?? 0).toString(),
  );

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setDialogState) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 32,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                    decoration: const BoxDecoration(
                      color: AppColors.primaryLogo,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.edit_outlined,
                          color: Colors.white70,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Editar producto',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (item['uid'] != null)
                                Text(
                                  'ID: ${item['uid']}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Colors.white54,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),

                  // Body
                  Flexible(
                    child: Container(
                      color: AppColors.whiteOverlay,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            formSection(
                              title: 'Información básica',
                              children: [
                                TextField(
                                  controller: nameController,
                                  decoration: modernInput(
                                    label: 'Nombre del producto',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                DropdownButtonFormField<String?>(
                                  value: editCategory,
                                  decoration: modernInput(label: 'Categoría'),
                                  items: [
                                    const DropdownMenuItem<String?>(
                                      value: null,
                                      child: Text('Selecciona una categoría'),
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
                                  onChanged: (value) => setDialogState(
                                    () => editCategory = value,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: skuController,
                                        decoration: modernInput(label: 'SKU'),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: auxCodeController,
                                        decoration: modernInput(
                                          label: 'Código auxiliar',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: descriptionController,
                                  maxLines: 3,
                                  decoration: modernInput(
                                    label: 'Descripción',
                                    hint: 'Describe el producto...',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: tagsController,
                                  decoration: modernInput(
                                    label: 'Etiquetas',
                                    hint: 'Ej: oferta, nuevo, importado',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Divider(color: Colors.grey.shade100),
                            const SizedBox(height: 24),
                            formSection(
                              title: 'Precios e impuestos',
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: priceController,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        decoration: modernInput(
                                          label: 'Precio de venta',
                                          prefix: '\$',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: costPriceController,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        decoration: modernInput(
                                          label: 'Precio de compra',
                                          prefix: '\$',
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
                                        controller: ivaRateController,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        decoration: modernInput(
                                          label: 'IVA gubernamental',
                                          suffix: '%',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: profitIvaController,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        decoration: modernInput(
                                          label: 'IVA ganancia',
                                          suffix: '%',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Divider(color: Colors.grey.shade100),
                            const SizedBox(height: 24),
                            formSection(
                              title: 'Local e inventario',
                              children: [
                                DropdownButtonFormField<int?>(
                                  value: editStoreId,
                                  decoration: modernInput(
                                    label: 'Local principal',
                                  ),
                                  items: [
                                    const DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text('Sin asignar'),
                                    ),
                                    ...controller.stores.map((s) {
                                      final id = (s['id'] as num).toInt();
                                      return DropdownMenuItem<int?>(
                                        value: id,
                                        child: Text(s['name'] as String),
                                      );
                                    }),
                                  ],
                                  onChanged: (v) =>
                                      setDialogState(() => editStoreId = v),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: bazarStockController,
                                        keyboardType: TextInputType.number,
                                        decoration: modernInput(
                                          label: 'Cantidad Bazar',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: tiendaStockController,
                                        keyboardType: TextInputType.number,
                                        decoration: modernInput(
                                          label: 'Cantidad Tienda',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Divider(color: Colors.grey.shade100),
                            const SizedBox(height: 24),
                            formSection(
                              title: 'Imágenes del producto',
                              children: [
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: [
                                    ...editImages.asMap().entries.map((entry) {
                                      return Stack(
                                        children: [
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            child: imagePreview(
                                              entry.value,
                                              width: 84,
                                              height: 84,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) =>
                                                  Container(
                                                    width: 84,
                                                    height: 84,
                                                    decoration: BoxDecoration(
                                                      color:
                                                          Colors.grey.shade100,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                    ),
                                                    child: const Icon(
                                                      Icons
                                                          .broken_image_outlined,
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                            ),
                                          ),
                                          Positioned(
                                            top: 4,
                                            right: 4,
                                            child: GestureDetector(
                                              onTap:
                                                  isUploadingEditImages ||
                                                      isSavingEdit
                                                  ? null
                                                  : () async {
                                                      final imageRef =
                                                          editImages[entry.key];
                                                      setDialogState(() {
                                                        editImages = List.from(
                                                          editImages,
                                                        )..removeAt(entry.key);
                                                      });
                                                      try {
                                                        await controller
                                                            .removeImageReference(
                                                              productId: (item['id'] as num)
                                                                  .toInt(),
                                                              imageRef: imageRef,
                                                            );
                                                      } catch (e) {
                                                        if (!context.mounted) {
                                                          return;
                                                        }
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              'No se pudo eliminar la imagen: ${e.toString().replaceFirst('Exception: ', '')}',
                                                            ),
                                                          ),
                                                        );
                                                      }
                                                    },
                                              child: Container(
                                                width: 20,
                                                height: 20,
                                                decoration: BoxDecoration(
                                                  color: Colors.red.shade600,
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons.close,
                                                  size: 12,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }),
                                    InkWell(
                                      onTap: () async {
                                        if (isUploadingEditImages ||
                                            isSavingEdit) {
                                          return;
                                        }
                                        try {
                                          final picker = ImagePicker();
                                          final picked = await picker
                                              .pickMultiImage(imageQuality: 80);
                                          if (picked.isEmpty) return;
                                          setDialogState(
                                            () => isUploadingEditImages = true,
                                          );
                                          final uploaded = await controller
                                              .uploadImages(
                                                picked
                                                    .map((image) => image.path)
                                                    .toList(),
                                              );
                                          if (!ctx.mounted) return;
                                          setDialogState(() {
                                            editImages = [
                                              ...editImages,
                                              ...uploaded,
                                            ];
                                          });
                                        } catch (e) {
                                          if (!context.mounted) return;
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(
                                                e.toString().replaceFirst(
                                                  'Exception: ',
                                                  '',
                                                ),
                                              ),
                                            ),
                                          );
                                        } finally {
                                          if (ctx.mounted) {
                                            setDialogState(
                                              () =>
                                                  isUploadingEditImages = false,
                                            );
                                          }
                                        }
                                      },
                                      borderRadius: BorderRadius.circular(10),
                                      child: Container(
                                        width: 84,
                                        height: 84,
                                        decoration: BoxDecoration(
                                          color: AppColors.lightWhite,
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: isUploadingEditImages
                                            ? const Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  SizedBox(
                                                    width: 22,
                                                    height: 22,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                        ),
                                                  ),
                                                  SizedBox(height: 6),
                                                  Text(
                                                    'Subiendo',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons
                                                        .add_photo_alternate_outlined,
                                                    color: Colors.grey.shade400,
                                                    size: 24,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Añadir',
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color:
                                                          Colors.grey.shade400,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Actions
                  Container(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      border: Border(
                        top: BorderSide(color: Colors.grey.shade200),
                      ),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(20),
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            TextButton.icon(
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red.shade600,
                              ),
                              onPressed: isUploadingEditImages || isSavingEdit
                                  ? null
                                  : () async {
                                      final navigator = Navigator.of(ctx);
                                      final messenger = ScaffoldMessenger.of(
                                        context,
                                      );
                                      final confirm = await showDialog<bool>(
                                        context: ctx,
                                        builder: (c) => AlertDialog(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          title: const Text(
                                            'Eliminar producto',
                                          ),
                                          content: Text(
                                            '¿Seguro que deseas eliminar "${item['name']}"?\n\nSe eliminará el producto y todo su inventario. Esta acción no se puede deshacer.',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(c, false),
                                              child: const Text('Cancelar'),
                                            ),
                                            FilledButton(
                                              style: FilledButton.styleFrom(
                                                backgroundColor:
                                                    Colors.red.shade600,
                                              ),
                                              onPressed: () =>
                                                  Navigator.pop(c, true),
                                              child: const Text('Eliminar'),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirm != true) return;
                                      try {
                                        showProgressNotification(
                                          context,
                                          'Eliminando producto...',
                                        );
                                        await controller.deleteProduct(
                                          (item['id'] as num).toInt(),
                                        );
                                        if (!context.mounted) return;
                                        navigator.pop();
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: const Text(
                                              'Producto eliminado',
                                            ),
                                            backgroundColor:
                                                Colors.red.shade700,
                                            behavior: SnackBarBehavior.floating,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                          ),
                                        );
                                        hideProgressNotification(context);
                                      } catch (e) {
                                        if (!context.mounted) return;
                                        messenger.showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              e.toString().replaceFirst(
                                                'Exception: ',
                                                '',
                                              ),
                                            ),
                                          ),
                                        );
                                        hideProgressNotification(context);
                                      }
                                    },
                              icon: const Icon(Icons.delete_outline, size: 18),
                              label: const Text('Eliminar'),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text(
                                'Cancelar',
                                style: TextStyle(color: AppColors.primaryRed),
                              ),
                            ),
                          ],
                        ),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.blackOverlay,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          onPressed: isUploadingEditImages || isSavingEdit
                              ? null
                              : () async {
                                  final navigator = Navigator.of(ctx);
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  // show progress notification while saving
                                  showProgressNotification(context, 'Guardando cambios...');
                                  setDialogState(() => isSavingEdit = true);
                                  try {
                                    final productId = (item['id'] as num)
                                        .toInt();
                                    final stockByStore = <int, int>{};
                                    for (final store in controller.stores) {
                                      final sid = (store['id'] as num).toInt();
                                      final storeName = store['name'] as String;
                                      stockByStore[sid] = storeName == 'Bazar'
                                          ? int.tryParse(
                                                  bazarStockController.text,
                                                ) ??
                                                0
                                          : int.tryParse(
                                                  tiendaStockController.text,
                                                ) ??
                                                0;
                                    }
                                    await controller.updateProductWithStock(
                                      productId: productId,
                                      name: nameController.text,
                                      category: editCategory ?? '',
                                      sku: skuController.text,
                                      auxCode: auxCodeController.text,
                                      description: descriptionController.text,
                                      tags: tagsController.text,
                                      price:
                                          double.tryParse(
                                            priceController.text.replaceAll(
                                              ',',
                                              '.',
                                            ),
                                          ) ??
                                          0,
                                      costPrice:
                                          double.tryParse(
                                            costPriceController.text.replaceAll(
                                              ',',
                                              '.',
                                            ),
                                          ) ??
                                          0,
                                      ivaRate:
                                          double.tryParse(
                                            ivaRateController.text.replaceAll(
                                              ',',
                                              '.',
                                            ),
                                          ) ??
                                          0,
                                      profitIva:
                                          double.tryParse(
                                            profitIvaController.text.replaceAll(
                                              ',',
                                              '.',
                                            ),
                                          ) ??
                                          0,
                                      storeId: editStoreId,
                                      images: editImages,
                                      stockByStore: stockByStore,
                                    );
                                    if (!context.mounted) return;
                                    navigator.pop();
                                    hideProgressNotification(context);
                                  } catch (e) {
                                    if (!context.mounted) return;
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          e.toString().replaceFirst(
                                            'Exception: ',
                                            '',
                                          ),
                                        ),
                                      ),
                                    );
                                    hideProgressNotification(context);
                                  } finally {
                                    if (ctx.mounted) {
                                      setDialogState(
                                        () => isSavingEdit = false,
                                      );
                                    }
                                  }
                                },
                          icon: isSavingEdit
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check, size: 16),
                          label: Text(
                            isSavingEdit ? 'Guardando...' : 'Guardar cambios',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
