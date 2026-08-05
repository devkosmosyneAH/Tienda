import 'package:tienda/Presentation/Controller/product_management_controller.dart';
import 'package:tienda/Presentation/Utils/Colors.dart';
import 'package:flutter/material.dart';
import 'shared_inputs.dart';

class NewProductDrawer extends StatelessWidget {
  const NewProductDrawer({
    required this.controller,
    required this.formKey,
    required this.nameController,
    required this.categoryController,
    required this.skuController,
    required this.auxCodeController,
    required this.descriptionController,
    required this.tagsController,
    required this.priceController,
    required this.costPriceController,
    required this.ivaRateController,
    required this.profitIvaController,
    required this.selectedCategoryName,
    required this.selectedStoreId,
    required this.imagePaths,
    required this.isUploadingImages,
    required this.isSavingProduct,
    required this.onCategoryChanged,
    required this.onStoreChanged,
    required this.onRemoveImage,
    required this.onPickImages,
    required this.onSaveProduct,
    required this.scaffoldKey,
    this.onClose,
    required this.stockController,
    super.key,
  });

  final ProductManagementController controller;
  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController categoryController;
  final TextEditingController skuController;
  final TextEditingController auxCodeController;
  final TextEditingController descriptionController;
  final TextEditingController tagsController;
  final TextEditingController priceController;
  final TextEditingController costPriceController;
  final TextEditingController ivaRateController;
  final TextEditingController profitIvaController;
  final TextEditingController stockController;
  final String? selectedCategoryName;
  final int? selectedStoreId;
  final List<String> imagePaths;
  final bool isUploadingImages;
  final bool isSavingProduct;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<int?> onStoreChanged;
  final void Function(int) onRemoveImage;
  final VoidCallback onPickImages;
  final VoidCallback onSaveProduct;
  final GlobalKey<ScaffoldState> scaffoldKey;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: 480,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(
              24,
              MediaQuery.of(context).padding.top + 20,
              16,
              20,
            ),
            color: AppColors.primaryLogo,
            child: Row(
              children: [
                const Icon(
                  Icons.add_box_outlined,
                  color: Colors.white70,
                  size: 22,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nuevo producto',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        'Agregar al catálogo compartido',
                        style: TextStyle(fontSize: 12, color: Colors.white54),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    if (onClose != null) {
                      onClose!();
                    } else {
                      scaffoldKey.currentState?.closeEndDrawer();
                    }
                  },
                  icon: const Icon(Icons.close, color: AppColors.whiteOverlay),
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: AppColors.whiteOverlay,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      formSection(
                        title: 'Información básica',
                        children: [
                          TextFormField(
                            controller: nameController,
                            decoration: modernInput(label: 'Nombre del producto'),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Ingresa un nombre';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String?>(
                            value: selectedCategoryName,
                            decoration: modernInput(
                              label: 'Categoría',
                              hint: 'Selecciona una categoría',
                            ),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Selecciona una categoría'),
                              ),
                              ...controller.categories.map((category) {
                                final categoryName = category['name'] as String;
                                return DropdownMenuItem<String?>(
                                  value: categoryName,
                                  child: Text(categoryName),
                                );
                              }),
                            ],
                            onChanged: onCategoryChanged,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Selecciona una categoría';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: skuController,
                                  decoration: modernInput(label: 'SKU (opcional)'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: auxCodeController,
                                  decoration: modernInput(label: 'Código auxiliar'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: descriptionController,
                            maxLines: 3,
                            decoration:
                                modernInput(label: 'Descripción', hint: 'Describe el producto...'),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: tagsController,
                            decoration: modernInput(label: 'Etiquetas', hint: 'oferta, nuevo, importado'),
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
                                child: TextFormField(
                                  controller: priceController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: modernInput(label: 'Precio de venta', prefix: '\$'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: costPriceController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: modernInput(label: 'Precio de compra', prefix: '\$'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: ivaRateController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: modernInput(label: 'IVA gubernamental', suffix: '%'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: profitIvaController,
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: modernInput(label: 'IVA ganancia', suffix: '%'),
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
                        title: 'Local e inventario inicial',
                        children: [
                          DropdownButtonFormField<int?>(
                            value: selectedStoreId,
                            decoration: modernInput(label: 'Local principal'),
                            items: [
                              const DropdownMenuItem<int?>(value: null, child: Text('Sin asignar')),
                              ...controller.stores.map((s) {
                                final id = (s['id'] as num).toInt();
                                return DropdownMenuItem<int?>(value: id, child: Text(s['name'] as String));
                              }),
                            ],
                            onChanged: onStoreChanged,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: stockController,
                            keyboardType: TextInputType.number,
                            decoration: modernInput(label: 'Stock inicial'),
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
                              ...imagePaths.asMap().entries.map((entry) {
                                return Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: imagePreview(
                                        entry.value,
                                        width: 84,
                                        height: 84,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => Container(
                                          width: 84,
                                          height: 84,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: const Icon(Icons.broken_image_outlined, color: Colors.grey),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: isUploadingImages || isSavingProduct
                                            ? null
                                            : () => onRemoveImage(entry.key),
                                        child: Container(
                                          width: 20,
                                          height: 20,
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade600,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close, size: 12, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              }),
                              InkWell(
                                onTap: isUploadingImages || isSavingProduct ? null : onPickImages,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 84,
                                  height: 84,
                                  decoration: BoxDecoration(
                                    color: AppColors.lightWhite,
                                    border: Border.all(color: Colors.grey.shade300),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: isUploadingImages
                                      ? const Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                                            SizedBox(height: 6),
                                            Text('Subiendo', style: TextStyle(fontSize: 10)),
                                          ],
                                        )
                                      : Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.add_photo_alternate_outlined, color: Colors.grey.shade400, size: 24),
                                            const SizedBox(height: 4),
                                            Text('Añadir', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              24,
              16,
              24,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            decoration: BoxDecoration(
              color: AppColors.whiteOverlay,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.blackOverlay,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: controller.isLoading || isSavingProduct || isUploadingImages ? null : onSaveProduct,
                icon: controller.isLoading || isSavingProduct
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline, size: 18),
                label: Text(
                  isUploadingImages
                      ? 'Subiendo imágenes...'
                      : (controller.isLoading || isSavingProduct) ? 'Guardando...' : 'Guardar producto',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
