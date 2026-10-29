import 'package:flutter/material.dart';
import '../main.dart';
import '../models/category_model.dart';
import '../services/category_preferences_service.dart';
import '../services/database_service.dart';
import '../utils/custom_snackbar.dart';

/// Dialogo modal para la configuracion, reordenamiento, visibilidad y eliminacion de categorias.
class CategoryConfigDialog extends StatefulWidget {
  final List<String> hiddenCategories;
  final List<String> categoryOrder;
  final ValueChanged<List<String>> onHiddenCategoriesChanged;
  final ValueChanged<List<String>> onCategoryOrderChanged;
  final ValueChanged<String>? onCategoryDeleted;

  const CategoryConfigDialog({
    super.key,
    required this.hiddenCategories,
    required this.categoryOrder,
    required this.onHiddenCategoriesChanged,
    required this.onCategoryOrderChanged,
    this.onCategoryDeleted,
  });

  @override
  State<CategoryConfigDialog> createState() => _CategoryConfigDialogState();
}

class _CategoryConfigDialogState extends State<CategoryConfigDialog> {
  final CategoryPreferencesService _prefsService = CategoryPreferencesService();
  late List<String> _hiddenCategories;
  late List<String> _categoryOrder;
  late List<CategoryModel> _configCats;

  @override
  void initState() {
    super.initState();
    _hiddenCategories = List<String>.from(widget.hiddenCategories);
    _categoryOrder = List<String>.from(widget.categoryOrder);

    final allCategories = DatabaseService().categoryBox.values.toList();
    final orderedCategories = _prefsService.applyOrder(allCategories, _categoryOrder);
    _configCats = orderedCategories
        .where((cat) => cat.name != 'Ingreso' && cat.name != 'Otros')
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final dragHandleColor = isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: AlertDialog(
          backgroundColor: isDarkMode ? AppColors.cardDark : Colors.white,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Configurar Categorías",
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                "Mantén presionado para ordenar, desliza para eliminar las tuyas, u ocúltalas",
                style: TextStyle(
                  color: isDarkMode ? Colors.grey.shade400 : Colors.grey.shade600,
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ReorderableListView.builder(
              shrinkWrap: true,
              buildDefaultDragHandles: false,
              proxyDecorator: (Widget child, int index, Animation<double> animation) {
                final isDark = Theme.of(context).brightness == Brightness.dark;
                return Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(16),
                  color: isDark ? const Color(0xFF1C2C20) : Colors.white,
                  child: child,
                );
              },
              itemCount: _configCats.length,
              onReorder: (int oldIndex, int newIndex) async {
                setState(() {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  final item = _configCats.removeAt(oldIndex);
                  _configCats.insert(newIndex, item);

                  final updatedOrder = <String>[];
                  for (final c in _configCats) {
                    updatedOrder.add(c.name);
                  }
                  for (final name in _categoryOrder) {
                    if (!updatedOrder.contains(name)) {
                      updatedOrder.add(name);
                    }
                  }
                  _categoryOrder = updatedOrder;
                });

                await _prefsService.saveCategoryOrder(_categoryOrder);
                widget.onCategoryOrderChanged(_categoryOrder);
              },
              itemBuilder: (itemContext, index) {
                final cat = _configCats[index];
                final name = cat.name;
                final isHidden = _hiddenCategories.contains(name);

                final tile = ListTile(
                  key: cat.isCustom ? null : ValueKey(cat.name),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  leading: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Color(cat.colorValue).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      IconData(cat.iconCode, fontFamily: 'MaterialIcons'),
                      color: Color(cat.colorValue),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    name,
                    style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black87,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Switch(
                        value: !isHidden,
                        activeColor: isDarkMode ? AppColors.primary : AppColors.primaryLight,
                        onChanged: (isVisible) async {
                          setState(() {
                            if (isVisible) {
                              _hiddenCategories.remove(name);
                            } else {
                              _hiddenCategories.add(name);
                            }
                          });
                          await _prefsService.saveHiddenCategories(_hiddenCategories);
                          widget.onHiddenCategoriesChanged(_hiddenCategories);
                        },
                      ),
                      ReorderableDragStartListener(
                        index: index,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                          child: Icon(
                            Icons.drag_indicator,
                            color: dragHandleColor,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                );

                if (!cat.isCustom) {
                  return tile;
                }

                return Dismissible(
                  key: ValueKey('dismiss_${cat.name}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        color: Colors.red,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        child: const Icon(
                          Icons.delete_outline,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  confirmDismiss: (direction) async {
                    return await showDialog<bool>(
                      context: context,
                      builder: (confirmContext) {
                        final isDark = Theme.of(confirmContext).brightness == Brightness.dark;
                        return AlertDialog(
                          backgroundColor: isDark ? AppColors.cardDark : Colors.white,
                          title: Text(
                            "Eliminar categoría",
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          content: Text(
                            "¿Estás seguro de eliminar la categoría '${cat.name}'? Esto no afectará las transacciones pasadas.",
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(confirmContext, false),
                              child: Text(
                                "Cancelar",
                                style: TextStyle(
                                  color: isDark ? AppColors.primary : AppColors.primaryLight,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(confirmContext, true),
                              child: const Text(
                                "Eliminar",
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        );
                      },
                    ) ?? false;
                  },
                  onDismissed: (direction) async {
                    final catName = cat.name;
                    if (cat.isInBox) {
                      await cat.delete();
                    } else {
                      final categoryBox = DatabaseService().categoryBox;
                      final key = cat.key;
                      if (key != null) {
                        await categoryBox.delete(key);
                      }
                    }

                    _categoryOrder.remove(catName);
                    _hiddenCategories.remove(catName);

                    await _prefsService.saveCategoryOrder(_categoryOrder);
                    await _prefsService.saveHiddenCategories(_hiddenCategories);

                    setState(() {
                      _configCats.removeWhere((c) => c.name == catName);
                    });

                    widget.onCategoryOrderChanged(_categoryOrder);
                    widget.onHiddenCategoriesChanged(_hiddenCategories);
                    widget.onCategoryDeleted?.call(catName);

                    if (context.mounted) {
                      CustomSnackBar.show(
                        context: context,
                        message: "Categoría eliminada",
                        icon: Icons.delete_outline_rounded,
                      );
                    }
                  },
                  child: tile,
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                "Listo",
                style: TextStyle(
                  color: isDarkMode ? AppColors.primary : AppColors.primaryLight,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
