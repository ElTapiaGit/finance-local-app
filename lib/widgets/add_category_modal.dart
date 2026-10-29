import 'package:flutter/material.dart';
import '../main.dart';
import '../models/category_model.dart';
import '../services/database_service.dart';
import '../utils/custom_snackbar.dart';
import 'save_button.dart';

class AddCategoryModal extends StatefulWidget {
  const AddCategoryModal({super.key});

  @override
  State<AddCategoryModal> createState() => _AddCategoryModalState();
}

class _AddCategoryModalState extends State<AddCategoryModal> {
  final TextEditingController _nameController = TextEditingController();
  bool _showError = false;

  static const List<Color> _availableColors = [
    Colors.orange,
    Colors.blue,
    Colors.redAccent,
    Color(0xFFFBC02D),
    Colors.purple,
    Colors.teal,
    Colors.pink,
    Colors.indigo,
  ];

  static const List<IconData> _availableIcons = [
    Icons.home_rounded,
    Icons.directions_car_rounded,
    Icons.pets_rounded,
    Icons.build_rounded,
    Icons.restaurant_rounded,
    Icons.shopping_bag_rounded,
    Icons.fitness_center_rounded,
    Icons.sports_esports_rounded,
    Icons.flight_rounded,
    Icons.savings_rounded,
  ];

  late Color _selectedColor;
  late IconData _selectedIcon;

  @override
  void initState() {
    super.initState();
    _selectedColor = _availableColors.first;
    _selectedIcon = _availableIcons.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveCategory() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() {
        _showError = true;
      });
      return;
    }

    final newCategory = CategoryModel(
      name: name,
      iconCode: _selectedIcon.codePoint,
      colorValue: _selectedColor.value,
      isCustom: true,
    );

    final db = DatabaseService();
    await db.categoryBox.add(newCategory);

    if (mounted) {
      Navigator.pop(context, newCategory);
      CustomSnackBar.show(
        context: context,
        message: "Categoría creada con éxito",
        icon: Icons.check_circle_rounded,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? AppColors.backgroundDark : const Color(0xFFF6F8F6);
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final keyboardSpace = MediaQuery.of(context).viewInsets.bottom;
    final systemBottomPadding = MediaQuery.of(context).padding.bottom;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: keyboardSpace + systemBottomPadding,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  "Nueva Categoría",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Vista previa de la categoria
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: _selectedColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _selectedColor.withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Icon(
                        _selectedIcon,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _nameController.text.trim().isEmpty
                          ? "Nombre de categoría"
                          : _nameController.text.trim(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Campo de Nombre
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.sentences,
                style: TextStyle(color: textColor),
                onChanged: (_) {
                  if (_showError) {
                    setState(() => _showError = false);
                  } else {
                    setState(() {});
                  }
                },
                decoration: InputDecoration(
                  labelText: "Nombre de la categoría",
                  labelStyle: TextStyle(
                    color: isDarkMode ? Colors.white70 : Colors.black87,
                  ),
                  prefixIcon: const Icon(Icons.label_outline_rounded),
                  filled: true,
                  fillColor: isDarkMode ? Colors.white10 : Colors.grey.shade200,
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: _showError
                        ? const BorderSide(color: Colors.redAccent, width: 2)
                        : BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDarkMode ? AppColors.primary : AppColors.primaryLight,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Selector de Color
              Text(
                "Selecciona un Color",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 50,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _availableColors.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final color = _availableColors[index];
                    final isSelected = color.value == _selectedColor.value;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedColor = color;
                        });
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: isSelected
                              ? Border.all(color: Colors.white, width: 3)
                              : null,
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: color.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  )
                                ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 22,
                              )
                            : null,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Selector de Icono
              Text(
                "Selecciona un Ícono",
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _availableIcons.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final icon = _availableIcons[index];
                    final isSelected = icon == _selectedIcon;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedIcon = icon;
                        });
                      },
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? _selectedColor.withValues(alpha: 0.2)
                              : (isDarkMode ? Colors.white10 : Colors.grey.shade100),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? _selectedColor : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          icon,
                          color: isSelected ? _selectedColor : Colors.grey,
                          size: 24,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 28),

              // Boton Guardar
              SaveButton(
                label: "Guardar Categoría",
                onPressed: _saveCategory,
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
