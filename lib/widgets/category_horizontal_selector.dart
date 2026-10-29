import 'package:flutter/material.dart';
import '../main.dart';
import '../models/category_model.dart';
import '../utils/categories_data.dart';
import 'add_category_modal.dart';
import 'painters/dotted_circle_border_painter.dart';

/// Selector horizontal de categorias con boton de creacion rapida,
/// acceso a configuracion y banner animado de ayuda contextual.
class CategoryHorizontalSelector extends StatelessWidget {
  final List<CategoryModel> categories;
  final String selectedCategoryName;
  final ValueChanged<String> onCategorySelected;
  final VoidCallback onOpenConfigDialog;
  final ValueChanged<CategoryModel> onCategoryCreated;

  const CategoryHorizontalSelector({
    super.key,
    required this.categories,
    required this.selectedCategoryName,
    required this.onCategorySelected,
    required this.onOpenConfigDialog,
    required this.onCategoryCreated,
  });

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    final currentCat = categories.firstWhere(
      (c) => c.name == selectedCategoryName,
      orElse: () => categories.firstWhere(
        (c) => c.name == 'Otros',
        orElse: () => categories.isNotEmpty
            ? categories.first
            : CategoryModel(
                name: 'Otros',
                iconCode: Icons.more_horiz_rounded.codePoint,
                colorValue: Colors.grey.value,
              ),
      ),
    );
    final currentCatColor = Color(currentCat.colorValue);
    final currentCatDesc = CategoryData.getDescription(currentCat.name);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "Categoría",
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.settings_outlined, size: 20, color: Colors.grey),
              tooltip: "Configurar categorías visibles",
              onPressed: onOpenConfigDialog,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            )
          ],
        ),
        const SizedBox(height: 10),

        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: 1 + categories.length,
            itemBuilder: (context, index) {
              if (index == 0) {
                return GestureDetector(
                  onTap: () async {
                    final newCategory = await showModalBottomSheet<CategoryModel>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      builder: (context) => const AddCategoryModal(),
                    );
                    if (newCategory != null) {
                      onCategoryCreated(newCategory);
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 16),
                    child: Column(
                      children: [
                        CustomPaint(
                          painter: DottedCircleBorderPainter(
                            color: isDarkMode ? AppColors.primary : AppColors.primaryLight,
                          ),
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              color: isDarkMode ? AppColors.primary : AppColors.primaryLight,
                              size: 26,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Añadir",
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDarkMode ? AppColors.primary : AppColors.primaryLight,
                          ),
                        )
                      ],
                    ),
                  ),
                );
              }

              final cat = categories[index - 1];
              final isSelected = selectedCategoryName == cat.name;
              final catColor = Color(cat.colorValue);

              return GestureDetector(
                onTap: () => onCategorySelected(cat.name),
                child: Container(
                  margin: const EdgeInsets.only(right: 16),
                  child: Column(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? catColor
                              : (isDarkMode ? Colors.white10 : Colors.grey.shade100),
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 2)
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: catColor.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  )
                                ]
                              : null,
                        ),
                        child: Icon(
                          IconData(cat.iconCode, fontFamily: 'MaterialIcons'),
                          color: isSelected ? Colors.white : Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        cat.name,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? (isDarkMode ? Colors.white : Colors.black)
                              : Colors.grey,
                        ),
                      )
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),

        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: Container(
            key: ValueKey<String>(selectedCategoryName),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: currentCatColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: currentCatColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: currentCatColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    currentCatDesc,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDarkMode ? Colors.white70 : Colors.black87,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

