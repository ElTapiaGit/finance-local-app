import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart'; 
import '../main.dart'; 
import '../models/category_model.dart';
import '../models/transaction_model.dart';
import '../services/category_preferences_service.dart';
import '../services/database_service.dart';
import '../utils/categories_data.dart';
import '../utils/currency_format.dart';
import '../utils/custom_snackbar.dart';
import '../utils/period_lock_helper.dart';
import 'category_config_dialog.dart';
import 'category_horizontal_selector.dart';
import 'date_payment_selector_row.dart';
import 'save_button.dart';
import 'transaction_type_selector.dart';

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
  final CategoryPreferencesService _categoryPrefsService = CategoryPreferencesService();
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
    final hidden = await _categoryPrefsService.getHiddenCategories();
    final order = await _categoryPrefsService.getCategoryOrder();
    if (mounted) {
      setState(() {
        _hiddenCategoryNames = hidden;
        _categoryOrder = order;
      });
    }
  }

  void _openCategoryConfigDialog() {
    showDialog(
      context: context,
      builder: (ctx) => CategoryConfigDialog(
        hiddenCategories: _hiddenCategoryNames,
        categoryOrder: _categoryOrder,
        onHiddenCategoriesChanged: (newHidden) {
          setState(() {
            _hiddenCategoryNames = newHidden;
          });
        },
        onCategoryOrderChanged: (newOrder) {
          setState(() {
            _categoryOrder = newOrder;
          });
        },
        onCategoryDeleted: (deletedName) {
          if (_selectedCategoryName == deletedName) {
            setState(() {
              _selectedCategoryName = 'Comida';
            });
          }
        },
      ),
    );
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
      if (PeriodLockHelper.isPeriodLocked(originalTx.date)) {
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
        final orderedCategories = _categoryPrefsService.applyOrder(allCategories, _categoryOrder);
        final visibleCats = _categoryPrefsService.filterVisible(
          orderedCategories,
          isExpense: _isExpense,
          hiddenCategories: _hiddenCategoryNames,
        );

        if (!visibleCats.any((c) => c.name == _selectedCategoryName)) {
          if (_isExpense) {
            if (visibleCats.isNotEmpty) {
              _selectedCategoryName = visibleCats.first.name;
            }
          } else {
            _selectedCategoryName = 'Ingreso';
          }
        }

        final currentCatExample = CategoryData.getExample(_selectedCategoryName);

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
                        TransactionTypeSelector(
                          isExpense: _isExpense,
                          onTypeChanged: (newIsExpense) {
                            setState(() {
                              _isExpense = newIsExpense;
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

                        DatePaymentSelectorRow(
                          selectedDate: _selectedDate,
                          selectedPaymentMethod: _selectedPaymentMethod,
                          paymentMethods: _paymentMethods,
                          onDateChanged: (newDate) {
                            setState(() {
                              _selectedDate = newDate;
                            });
                          },
                          onPaymentMethodChanged: (newMethod) {
                            setState(() {
                              _selectedPaymentMethod = newMethod;
                            });
                          },
                        ),
                        const SizedBox(height: 20),

                        CategoryHorizontalSelector(
                          categories: visibleCats,
                          selectedCategoryName: _selectedCategoryName,
                          onCategorySelected: (categoryName) {
                            setState(() {
                              _selectedCategoryName = categoryName;
                            });
                          },
                          onOpenConfigDialog: _openCategoryConfigDialog,
                          onCategoryCreated: (newCategory) async {
                            setState(() {
                              if (!_categoryOrder.contains(newCategory.name)) {
                                _categoryOrder.insert(0, newCategory.name);
                              }
                              _selectedCategoryName = newCategory.name;
                            });
                            await _categoryPrefsService.saveCategoryOrder(_categoryOrder);
                          },
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
}
