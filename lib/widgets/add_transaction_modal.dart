import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; 
import '../main.dart'; 
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../services/database_service.dart';
import '../utils/categories_data.dart';
import '../utils/currency_format.dart';
import '../utils/custom_snackbar.dart';
import 'add_category_modal.dart';
import 'save_button.dart';

class AddTransactionModal extends StatefulWidget {
  final TransactionModel? transactionToEdit;

  // Parametros para plantilla de recordatorios
  final String? initialTitle;
  final double? initialAmount;
  final int? initialCategoryIcon; 
  final DateTime? initialDate; 

  const AddTransactionModal({
    super.key, 
    this.transactionToEdit,
    this.initialTitle,
    this.initialAmount,
    this.initialCategoryIcon,
    this.initialDate,
  });

  @override
  State<AddTransactionModal> createState() => _AddTransactionModalState();
}

class _AddTransactionModalState extends State<AddTransactionModal> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  
  bool _isExpense = true; 
  DateTime _selectedDate = DateTime.now();
  String _selectedPaymentMethod = 'Efectivo';
  String _selectedCategoryName = 'Comida'; 
  bool _showError = false; 

  final List<String> _paymentMethods = [
    'Efectivo',
    'Tarjeta de Débito',
    'Tarjeta de Crédito',
    'QR / Transferencia',
  ];
  List<String> _hiddenCategoryNames = []; 
  List<String> _categoryOrder = [];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    final numberFormat = NumberFormat("#,##0.00", "en_US");

    if (widget.transactionToEdit != null) {
      final tx = widget.transactionToEdit!;
      _amountController.text = numberFormat.format(tx.amount);
      _titleController.text = tx.title;
      _isExpense = tx.type == TransactionType.expense;
      _selectedDate = tx.date;
      _selectedPaymentMethod = tx.paymentMethod;
      _selectedCategoryName = tx.categoryName;
    } else {
      _selectedDate = widget.initialDate ?? DateTime.now();
      if (widget.initialTitle != null) {
        _titleController.text = widget.initialTitle!;
      }
      if (widget.initialAmount != null) {
        _amountController.text = numberFormat.format(widget.initialAmount!);
      }
      
      if (widget.initialCategoryIcon != null) {
        try {
          final categories = DatabaseService().categoryBox.values.toList();
          final match = categories.firstWhere(
            (cat) => cat.iconCode == widget.initialCategoryIcon,
          );
          _selectedCategoryName = match.name;
        } catch (_) {
          // Fallback silencioso si no existe coincidencia directa
        }
      }
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hiddenCategoryNames = prefs.getStringList('hidden_categories') ?? [];
      _categoryOrder = prefs.getStringList('category_order') ?? [];
    });
  }

  List<CategoryModel> _applyCategoryOrder(List<CategoryModel> categories) {
    if (categories.isEmpty) return [];

    bool needsSave = false;
    for (final cat in categories) {
      if (!_categoryOrder.contains(cat.name)) {
        _categoryOrder.insert(0, cat.name);
        needsSave = true;
      }
    }

    if (needsSave) {
      SharedPreferences.getInstance().then((prefs) {
        prefs.setStringList('category_order', _categoryOrder);
      });
    }

    final sortedList = List<CategoryModel>.from(categories);
    sortedList.sort((a, b) {
      final indexA = _categoryOrder.indexOf(a.name);
      final indexB = _categoryOrder.indexOf(b.name);
      final posA = indexA == -1 ? 999999 : indexA;
      final posB = indexB == -1 ? 999999 : indexB;
      return posA.compareTo(posB);
    });

    return sortedList;
  }

  List<CategoryModel> _filterCategories(List<CategoryModel> allCategories) {
    return allCategories.where((cat) {
      if (_isExpense) {
        if (cat.name == 'Ingreso') return false;
      } else {
        if (cat.name != 'Ingreso') return false;
      }
      if (cat.name == 'Ingreso' || cat.name == 'Otros') return true;
      return !_hiddenCategoryNames.contains(cat.name);
    }).toList();
  }

  String _getCategoryDescription(String name) {
    try {
      final match = CategoryData.allCategories.firstWhere((c) => c['name'] == name);
      return match['desc'] as String? ?? 'Categoría personalizada';
    } catch (_) {
      return 'Categoría personalizada';
    }
  }

  String _getCategoryExample(String name) {
    try {
      final match = CategoryData.allCategories.firstWhere((c) => c['name'] == name);
      return match['example'] as String? ?? name;
    } catch (_) {
      return name;
    }
  }

  void _showCategoryConfigDialog() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final allCategories = DatabaseService().categoryBox.values.toList();
    final orderedCategories = _applyCategoryOrder(allCategories);
    final configCats = orderedCategories
        .where((cat) => cat.name != 'Ingreso' && cat.name != 'Otros')
        .toList();

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final dragHandleColor = Theme.of(context).brightness == Brightness.dark
                ? Colors.grey.shade400
                : Colors.grey.shade600;

            return AlertDialog(
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
                    "Mantén presionado para ordenar u oculta las que no uses",
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
                  itemCount: configCats.length,
                  onReorder: (int oldIndex, int newIndex) async {
                    setDialogState(() {
                      if (newIndex > oldIndex) {
                        newIndex -= 1;
                      }
                      final item = configCats.removeAt(oldIndex);
                      configCats.insert(newIndex, item);

                      final updatedOrder = <String>[];
                      for (final c in configCats) {
                        updatedOrder.add(c.name);
                      }
                      for (final name in _categoryOrder) {
                        if (!updatedOrder.contains(name)) {
                          updatedOrder.add(name);
                        }
                      }
                      _categoryOrder = updatedOrder;
                    });

                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setStringList('category_order', _categoryOrder);
                    setState(() {});
                  },
                  itemBuilder: (context, index) {
                    final cat = configCats[index];
                    final name = cat.name;
                    final isHidden = _hiddenCategoryNames.contains(name);

                    return ListTile(
                      key: ValueKey(cat.name),
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
                              final prefs = await SharedPreferences.getInstance();
                              setDialogState(() {
                                if (isVisible) {
                                  _hiddenCategoryNames.remove(name);
                                } else {
                                  _hiddenCategoryNames.add(name);
                                }
                              });
                              await prefs.setStringList('hidden_categories', _hiddenCategoryNames);
                              setState(() {});
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
            );
          },
        );
      },
    );
  }

  bool _isPeriodLocked(DateTime transactionDate) {
    final now = DateTime.now();
    if (transactionDate.year == now.year && transactionDate.month == now.month) {
      return false;
    }
    if (now.day >= 4) {
      return true;
    }
    return false;
  }

  Future<void> _submitData() async { 
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final successColor = isDarkMode ? AppColors.primary : Colors.green.shade600;
    final successTextColor = isDarkMode ? Colors.black : Colors.white;
    final rawAmount = _amountController.text.replaceAll(',', '');
    final enteredAmount = double.tryParse(rawAmount);
    final enteredTitle = _titleController.text;

    if (enteredAmount == null || enteredAmount <= 0 || enteredTitle.trim().isEmpty) {
      setState(() {
        _showError = true;
      });
      return; 
    }

    final allCategories = DatabaseService().categoryBox.values.toList();
    final selectedCat = allCategories.firstWhere(
      (c) => c.name == _selectedCategoryName,
      orElse: () => allCategories.isNotEmpty
          ? allCategories.first
          : CategoryModel(
              name: 'Otros',
              iconCode: Icons.more_horiz_rounded.codePoint,
              colorValue: Colors.grey.value,
            ),
    );

    if (widget.transactionToEdit != null) {
      final originalTx = widget.transactionToEdit!;
      if (_isPeriodLocked(originalTx.date)) {
        final isAmountChanged = (originalTx.amount - enteredAmount).abs() > 0.01;
        final isDateChanged = originalTx.date.year != _selectedDate.year || 
                              originalTx.date.month != _selectedDate.month || 
                              originalTx.date.day != _selectedDate.day;
        
        if (isAmountChanged || isDateChanged) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Periodo Cerrado"),
              content: const Text(
                "No puedes cambiar el Monto ni la Fecha de un mes cerrado.\n\n"
                "Para ajustar el saldo, crea una nueva transacción de ajuste con fecha de hoy."
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    "Entendido",
                    style: TextStyle(
                      color: isDarkMode ? AppColors.primary : AppColors.primaryLight,
                    ),
                  ),
                )
              ],
            ),
          );
          return;
        }
      }
    }

    final dbService = DatabaseService();
    final int colorInt = selectedCat.colorValue;
    final int iconInt = selectedCat.iconCode;
    bool isUpdate = widget.transactionToEdit != null;

    if (isUpdate) {
      final txToUpdate = widget.transactionToEdit!;
      txToUpdate
        ..title = enteredTitle
        ..amount = enteredAmount
        ..type = _isExpense ? TransactionType.expense : TransactionType.income
        ..paymentMethod = _selectedPaymentMethod
        ..date = _selectedDate
        ..categoryName = selectedCat.name
        ..categoryColor = colorInt
        ..categoryIconCode = iconInt;

      await txToUpdate.save();
    } else {
      await dbService.saveTransaction(
        title: enteredTitle,
        amount: enteredAmount,
        isExpense: _isExpense,
        paymentMethod: _selectedPaymentMethod,
        date: _selectedDate,
        categoryName: selectedCat.name,
        categoryColor: colorInt,
        categoryIcon: iconInt,
      );
    }
    
    if (mounted) {
      Navigator.of(context).pop();
      final String message = isUpdate 
          ? "Transacción actualizada exitosamente" 
          : "Transacción registrada exitosamente";
      
      CustomSnackBar.show(
        context: context,
        message: message,
        icon: isUpdate ? Icons.edit_rounded : Icons.check_circle_rounded,
        backgroundColor: successColor,
        iconColor: successTextColor,
      );
    }
  }

  void _presentDatePicker() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final calendarColor = isDarkMode ? AppColors.primary : AppColors.primaryLight;

    showDatePicker(
      context: context,
      locale: const Locale('es', 'ES'),
      initialDate: _selectedDate, 
      firstDate: DateTime(2024), 
      lastDate: DateTime.now(),
      cancelText: "CANCELAR",
      confirmText: "ACEPTAR",
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDarkMode 
              ? const ColorScheme.dark(
                  primary: AppColors.primary,
                  onPrimary: Colors.black,
                  surface: AppColors.cardDark,
                )
              : ColorScheme.light(
                  primary: calendarColor, 
                  onPrimary: Colors.white,
                  surface: Colors.white,
                ),
          ),
          child: child!,
        );
      }
    ).then((pickedDate) {
      if (pickedDate == null) return;
      setState(() {
        _selectedDate = pickedDate;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final incomeColor = isDarkMode ? AppColors.primary : AppColors.primaryLight;
    final activeColor = _isExpense ? Colors.redAccent : incomeColor;
    final keyboardSpace = MediaQuery.of(context).viewInsets.bottom;
    final systemBottomPadding = MediaQuery.of(context).padding.bottom;

    return ValueListenableBuilder<Box<CategoryModel>>(
      valueListenable: DatabaseService().categoryBox.listenable(),
      builder: (context, box, _) {
        final allCategories = box.values.toList();
        final orderedCategories = _applyCategoryOrder(allCategories);
        final visibleCats = _filterCategories(orderedCategories);

        if (!visibleCats.any((c) => c.name == _selectedCategoryName)) {
          if (_isExpense) {
            if (visibleCats.isNotEmpty) {
              _selectedCategoryName = visibleCats.first.name;
            }
          } else {
            _selectedCategoryName = 'Ingreso';
          }
        }

        final currentCat = visibleCats.firstWhere(
          (c) => c.name == _selectedCategoryName,
          orElse: () => allCategories.firstWhere(
            (c) => c.name == 'Otros',
            orElse: () => allCategories.isNotEmpty
                ? allCategories.first
                : CategoryModel(
                    name: 'Otros',
                    iconCode: Icons.more_horiz_rounded.codePoint,
                    colorValue: Colors.grey.value,
                  ),
          ),
        );
        final currentCatColor = Color(currentCat.colorValue);
        final currentCatDesc = _getCategoryDescription(currentCat.name);
        final currentCatExample = _getCategoryExample(currentCat.name);

        return Padding(
          padding: EdgeInsets.only(bottom: keyboardSpace + systemBottomPadding),
          child: SizedBox(
            height: 650,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildTypeButton("Gasto", true, incomeColor, visibleCats),
                            const SizedBox(width: 12),
                            _buildTypeButton("Ingreso", false, incomeColor, visibleCats),
                          ],
                        ),
                        const SizedBox(height: 24),

                        TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(14),
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')), 
                            CurrencyInputFormatter(),
                          ],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: activeColor,
                          ),
                          decoration: InputDecoration(
                            prefixText: "${CurrencyFormat.currencySymbol} ",
                            hintText: "0.00",
                            hintStyle: TextStyle(color: Colors.grey.shade400),
                            border: InputBorder.none,
                          ),
                        ),
                        const SizedBox(height: 20),

                        TextField(
                          controller: _titleController,
                          textCapitalization: TextCapitalization.sentences,
                          onChanged: (value) {
                            if (_showError) {
                              setState(() => _showError = false);
                            }
                          },
                          decoration: InputDecoration(
                            labelText: "Concepto (Ej: $currentCatExample)",
                            labelStyle: TextStyle(
                              color: isDarkMode ? Colors.white70 : Colors.black87,
                            ),
                            prefixIcon: const Icon(Icons.edit_note_rounded),
                            filled: true,
                            fillColor: isDarkMode ? Colors.white10 : Colors.grey.shade200,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12), 
                              borderSide: _showError 
                                  ? const BorderSide(color: Colors.red, width: 2) 
                                  : BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12), 
                              borderSide: _showError 
                                  ? const BorderSide(color: Colors.redAccent, width: 2) 
                                  : BorderSide(color: activeColor, width: 2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: _presentDatePicker,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                                  decoration: BoxDecoration(
                                    color: isDarkMode ? Colors.white10 : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today_rounded, size: 18, color: Colors.grey),
                                      const SizedBox(width: 8),
                                      Text(
                                        DateFormat('dd/MM/yyyy').format(_selectedDate),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 15,
                                          color: isDarkMode ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  return DropdownMenu<String>(
                                    expandedInsets: EdgeInsets.zero,
                                    requestFocusOnTap: false,
                                    enableFilter: false,
                                    enableSearch: false,
                                    initialSelection: _selectedPaymentMethod,
                                    textStyle: TextStyle(
                                      fontSize: 15,
                                      color: isDarkMode ? Colors.white : Colors.black87,
                                    ),
                                    inputDecorationTheme: InputDecorationTheme(
                                      filled: true,
                                      fillColor: isDarkMode ? Colors.white10 : Colors.grey.shade200,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide.none,
                                      ),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                                    ),
                                    menuStyle: MenuStyle(
                                      backgroundColor: WidgetStateProperty.all<Color>(
                                        isDarkMode ? const Color(0xFF1C2C20) : Colors.white,
                                      ),
                                      shape: WidgetStateProperty.all<OutlinedBorder>(
                                        RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                    dropdownMenuEntries: _paymentMethods.map((String method) {
                                      return DropdownMenuEntry<String>(
                                        value: method,
                                        label: method,
                                        style: MenuItemButton.styleFrom(
                                          foregroundColor: isDarkMode ? Colors.white : Colors.black87,
                                        ),
                                      );
                                    }).toList(),
                                    onSelected: (newValue) {
                                      if (newValue != null) {
                                        setState(() {
                                          _selectedPaymentMethod = newValue;
                                        });
                                      }
                                    },
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

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
                              onPressed: _showCategoryConfigDialog,
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
                            itemCount: 1 + visibleCats.length,
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
                                      setState(() {
                                        if (!_categoryOrder.contains(newCategory.name)) {
                                          _categoryOrder.insert(0, newCategory.name);
                                        }
                                        _selectedCategoryName = newCategory.name;
                                      });
                                      final prefs = await SharedPreferences.getInstance();
                                      await prefs.setStringList('category_order', _categoryOrder);
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

                              final cat = visibleCats[index - 1];
                              final isSelected = _selectedCategoryName == cat.name;
                              final catColor = Color(cat.colorValue);

                              return GestureDetector(
                                onTap: () => setState(() => _selectedCategoryName = cat.name),
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
                            key: ValueKey<String>(_selectedCategoryName), 
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
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),

                Container(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  width: double.infinity,
                  height: 85,
                  child: SaveButton(
                    label: widget.transactionToEdit != null
                        ? "Actualizar Transacción"
                        : "Guardar Transacción",
                    onPressed: _submitData,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTypeButton(
    String label,
    bool isExpenseBtn,
    Color incomeColor,
    List<CategoryModel> visibleCats,
  ) {
    final isSelected = _isExpense == isExpenseBtn;
    final color = isExpenseBtn ? Colors.redAccent : incomeColor;

    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpense = isExpenseBtn;

          if (_isExpense) {
            if (visibleCats.isNotEmpty) {
              _selectedCategoryName = visibleCats.first.name;
            } else {
              _selectedCategoryName = 'Comida';
            }
          } else {
            _selectedCategoryName = 'Ingreso';
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 24),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: isSelected ? color : Colors.grey.shade300),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class DottedCircleBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final int dashCount;

  const DottedCircleBorderPainter({
    required this.color,
    this.strokeWidth = 1.8,
    this.dashCount = 14,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final radius = size.width / 2;
    final center = Offset(radius, radius);
    const double pi = 3.141592653589793;
    final circumference = 2 * pi * radius;
    final dashLength = circumference / (dashCount * 2);
    final dashAngle = dashLength / radius;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * 2 * dashAngle;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        dashAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant DottedCircleBorderPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
  }
}
