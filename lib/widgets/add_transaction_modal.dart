import 'package:finance_local/widgets/save_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart'; 
import 'package:shared_preferences/shared_preferences.dart'; 
import '../main.dart'; 
import '../services/database_service.dart';
import '../models/transaction_model.dart';
import '../utils/currency_format.dart';
import '../utils/categories_data.dart';

class AddTransactionModal extends StatefulWidget {
  final TransactionModel? transactionToEdit;

  //PARAMETROS PARA PLANTILLA (Recordatorios) 
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
  // CONTROLADORES Y ESTADO 
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  
  bool _isExpense = true; 
  DateTime _selectedDate = DateTime.now();
  String _selectedPaymentMethod = 'Efectivo';
  String _selectedCategoryName = 'Comida'; 
  bool _showError = false; 

  // Lista de Metodos de Pago
  final List<String> _paymentMethods = ['Efectivo', 'Tarjeta de Débito', 'Tarjeta de Crédito', 'QR / Transferencia'];
  // LISTA DE CATEGORIAS OCULTAS
  List<String> _hiddenCategoryNames = []; 

  final List<Map<String, dynamic>> _allCategories = CategoryData.allCategories;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    // FORMATO DE MONEDA
    final numberFormat = NumberFormat("#,##0.00", "en_US");
    // SI ESTAMOS EDITANDO, RELLENAMOS LOS CAMPOS
    if (widget.transactionToEdit != null) {
      final tx = widget.transactionToEdit!;
      _amountController.text = numberFormat.format(tx.amount);
      _titleController.text = tx.title;
      _isExpense = tx.type == TransactionType.expense;
      _selectedDate = tx.date;
      _selectedPaymentMethod = tx.paymentMethod;
      _selectedCategoryName = tx.categoryName;
    }
    // PLANTILLA (Viene desde Recordatorio)
    else {
      _selectedDate = widget.initialDate ?? DateTime.now(); //controla de donde viene la fecha si de calendar o home o otro
      if (widget.initialTitle != null) {
        _titleController.text = widget.initialTitle!;
      }
      if (widget.initialAmount != null) {
        //para la platilla
        _amountController.text = numberFormat.format(widget.initialAmount!);
      }
      
      if (widget.initialCategoryIcon != null) {
        try {
          final match = _allCategories.firstWhere(
            (cat) => (cat['icon'] as IconData).codePoint == widget.initialCategoryIcon
          );
          _selectedCategoryName = match['name'];
        } catch (e) {
          // fallback silencioso Para v2. 
        }
      }
    }
  }

  // CARGAR PREFERENCIAS 
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hiddenCategoryNames = prefs.getStringList('hidden_categories') ?? [];
    });
  }
  // GETTER INTELIGENTE Filtra las categorias ocultas y por tipo
  List<Map<String, dynamic>> get _visibleCategories {
    return _allCategories.where((cat) {
      // filtramos tipo (gasto/ingreso)
      if (_isExpense) {
        //si es gasto se oculta la categoria ingreso
        if(cat['name'] == 'Ingreso') return false;
      } else {
        //si es ingreso oculta todas las categorias
        //podmeos poner otros con || cat['name'] == 'Otros'
        if (cat['name'] != 'Ingreso') return false;
      }
      //FILTRO PERSONALIZADO DE CATEGORIAS 
      if (cat['name'] == 'Ingreso' || cat['name'] == 'Otros') return true;
      // Si esta en la lista negra, no se muestra
      return !_hiddenCategoryNames.contains(cat['name']);
    }).toList();
  }

  // DIALOGO DE CONFIGURACION
  void _showCategoryConfigDialog() {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) {

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Configurar Categorías"),
              content: SizedBox(
                width: double.maxFinite,
                height: 400, 
                child: ListView(
                  children: _allCategories.map((cat) {
                    final name = cat['name'] as String;
                    // Protegemos las categorIas del sistema
                    final isSystem = name == 'Ingreso' || name == 'Otros';
                    final isHidden = _hiddenCategoryNames.contains(name);

                    if (isSystem) return const SizedBox.shrink(); 

                    return SwitchListTile(
                      title: Text(name),
                      secondary: Icon(cat['icon'], color: cat['color']),
                      value: !isHidden, // El switch es "Es Visible?"
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
                    );
                  }).toList(),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Listo", style: TextStyle(color: isDarkMode ? AppColors.primary : AppColors.primaryLight),),
                )
              ],
            );
          },
        );
      },
    );
  }

  // CANDADO FINANCIERO 
  bool _isPeriodLocked(DateTime transactionDate) {
    final now = DateTime.now();
    // si es del mismo mes y año actual, NO sebloquea.
    if (transactionDate.year == now.year && transactionDate.month == now.month) {
      return false;
    }
    // si es de un mes pasado, verificamos el dia de gracia
    if (now.day >= 4) {
      return true; // Bloqueado
    }
    return false;
  }

  // FUNCION GUARDAR 
  Future<void> _submitData() async { 
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final successColor = isDarkMode ? AppColors.primary : Colors.green.shade600;
    final successTextColor = isDarkMode ? Colors.black : Colors.white;
    final rawAmount = _amountController.text.replaceAll(',', '');
    final enteredAmount = double.tryParse(rawAmount);
    final enteredTitle = _titleController.text;

    // VALIDACION VISUAL
    if (enteredAmount == null || enteredAmount <= 0 || enteredTitle.trim().isEmpty) {
      setState(() {
        _showError = true;
      });
      return; 
    }
    // Buscamos la categoria completa basada en el NOMBRE seleccionado
    final selectedCat = _allCategories.firstWhere(
      (c) => c['name'] == _selectedCategoryName,
      orElse: () => _allCategories[0], // Fallback por seguridad
    );

    //validar candado financiero
    if (widget.transactionToEdit != null) {
      final originalTx = widget.transactionToEdit!;
      //si periodo cerrado
      if (_isPeriodLocked(originalTx.date)) {
        // Verificamos si intento cambiar DATOS FINANCIEROS (Monto o Fecha)
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
                TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Entendido", style:TextStyle(color: isDarkMode ? AppColors.primary : AppColors.primaryLight)))
              ],
            ),
          );
          return; // DETENER GUARDADO
        }
        //si solo cambia titulo o categoria dejamos pasar cosmetica
      }
    }

    // Obtenemos la categoria seleccionada de la lista
    final dbService = DatabaseService();
    final int colorInt = (selectedCat['color'] as Color).toARGB32();
    final int iconInt = (selectedCat['icon'] as IconData).codePoint;
    // Variable para saber si fue actualizacion
    bool isUpdate = widget.transactionToEdit != null;

    // ACTUALIZAMOS SI NO, CREAMOS NUEVO
    if (isUpdate) {
      final txToUpdate = widget.transactionToEdit!;
      txToUpdate
        ..title = enteredTitle
        ..amount = enteredAmount
        ..type = _isExpense ? TransactionType.expense : TransactionType.income
        ..paymentMethod = _selectedPaymentMethod
        ..date = _selectedDate
        ..categoryName = selectedCat['name']
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
        categoryName: selectedCat['name'],
        categoryColor: colorInt,
        categoryIcon: iconInt,
      );
    }
    
    if (context.mounted) {
      // ignore: use_build_context_synchronously
      Navigator.of(context).pop(); //cierra modal
      // MENSAJE DINAMICAMENTE
      final String message = isUpdate 
          ? "Transacción actualizada exitosamente" 
          : "Transacción registrada exitosamente";
      
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: TextStyle(color: successTextColor, fontWeight: FontWeight.bold)
          ),
          backgroundColor: successColor,
          behavior: SnackBarBehavior.floating, 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
          margin: const EdgeInsets.all(16),
        ),
      );
    }
  }

  // Selector de Fecha
  void _presentDatePicker() {
    // Definimos el color adecuado para el calendario segun el tema
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
    // Obtenemos la altura del teclado
    final keyboardSpace = MediaQuery.of(context).viewInsets.bottom;
    final visibleCats = _visibleCategories;
    // Validamos que la categoria seleccionada siga siendo visible
    if (!visibleCats.any((c) => c['name'] == _selectedCategoryName)) {
      // Si es gasto, la primera visible, si es ingreso, buscamos ingreso
     if (_isExpense) {
        // Si visibleCats esta vacio, usa un fallback
        if (visibleCats.isNotEmpty) {
          _selectedCategoryName = visibleCats.first['name'];
        }
      } else {
        _selectedCategoryName = 'Ingreso';
      }
    }
    // info del obj. categoria actual para la ayuda visual
    final currentCat = visibleCats.firstWhere(
      (c) => c['name'] == _selectedCategoryName,
      orElse: () => _allCategories.firstWhere((c) => c['name'] == 'Otros')
    );
    final currentCatColor = currentCat['color'] as Color;
    
    return Padding(
      // Empuja el modal hacia arriba cuando sale el teclado
      padding: EdgeInsets.only(bottom: keyboardSpace),
      child: SizedBox(
        height: 650, //altura
        child: Column(
          children: [
            // INDICADOR DE ARRASTRE Y BOTON ELIMIINAR
            Padding(
              padding:  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  //indicador central la barrita gris -
                  Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // CONTENIDO CON SCROLL
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TOGGLE (INGRESO / GASTO) botones switch
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildTypeButton("Gasto", true, incomeColor),
                        const SizedBox(width: 12),
                        _buildTypeButton("Ingreso", false, incomeColor),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // INPUT DE MONTO 
                    TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        // Permite solo numeros y solo UN punto decimal
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')), 
                        // Aplicamos nuestro clase formateador
                        CurrencyInputFormatter(),
                      ],
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: activeColor),
                      decoration: InputDecoration(
                        prefixText: "Bs ", 
                        hintText: "0.00",
                        hintStyle: TextStyle(color: Colors.grey.shade400),
                        border: InputBorder.none,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // INPUT DE TITULO 
                    TextField(
                      controller: _titleController,
                      textCapitalization: TextCapitalization.sentences,
                      // Si empieza a escribir, quitamos el error
                      onChanged: (value) {
                        if (_showError) {
                          setState(() => _showError = false);
                        }
                      },
                      decoration: InputDecoration(
                        labelText: "Concepto (Ej: Almuerzo)",
                        labelStyle: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87,),
                        prefixIcon: const Icon(Icons.edit_note_rounded),
                        filled: true,
                        fillColor: isDarkMode ? Colors.white10 : Colors.grey.shade200,
                        // BORDE NORMAL
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12), 
                          borderSide: _showError 
                              ? const BorderSide(color: Colors.red, width: 2) 
                              : BorderSide.none // Invisible si todo bien
                        ),
                        // BORDE CUANDO SE TOCA 
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12), 
                          borderSide: _showError 
                              ? const BorderSide(color: Colors.redAccent, width: 2) 
                              : BorderSide(color: activeColor, width: 2) 
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // FILA DE FECHA Y METODO DE PAGO
                    Row(
                      children: [
                        // Selector de Fecha
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
                                    style: TextStyle(fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Selector de Metodo de Pago
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: isDarkMode ? Colors.white10 : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedPaymentMethod,
                                isExpanded: true,
                                icon: const Icon(Icons.keyboard_arrow_down_rounded),
                                items: _paymentMethods.map((String method) {
                                  return DropdownMenuItem<String>(
                                    value: method,
                                    child: Text(
                                      method, 
                                      style: const TextStyle(fontSize: 13), 
                                      overflow: TextOverflow.ellipsis
                                    ),
                                  );
                                }).toList(),
                                onChanged: (newValue) {
                                  setState(() {
                                    _selectedPaymentMethod = newValue!;
                                  });
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // SELECCION DE CATEGORIA
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Categoría", style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w600)),
                        
                        // BOTON ENGRANAJE
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
                    //LISTA HORIZONTA DE CATEROIAS
                    SizedBox(
                      height: 80,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: visibleCats.length,
                        itemBuilder: (context, index) {
                          final cat = visibleCats[index];
                          final isSelected = _selectedCategoryName == cat['name'];
                          final catColor = cat['color'] as Color;

                          return GestureDetector(
                            onTap: () => setState(() => _selectedCategoryName = cat['name']),
                            child: Container(
                              margin: const EdgeInsets.only(right: 16),
                              child: Column(
                                children: [
                                  Container(
                                    width: 50, height: 50,
                                    decoration: BoxDecoration(
                                      color: isSelected ? cat['color'] : (isDarkMode ? Colors.white10 : Colors.grey.shade100),
                                      shape: BoxShape.circle,
                                      border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                                      boxShadow: isSelected 
                                        ? [BoxShadow(color: catColor.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4))] 
                                        : null,
                                    ),
                                    child: Icon(
                                      cat['icon'], 
                                      color: isSelected ? Colors.white : Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    cat['name'], 
                                    style: TextStyle(
                                      fontSize: 10, 
                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                      color: isSelected ? (isDarkMode ? Colors.white : Colors.black) : Colors.grey
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

                    //Barra de ayuda
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
                            Icon(Icons.info_outline_rounded, size: 18, color: currentCatColor,),
                            const SizedBox(width: 10,),
                            Expanded(
                              child: Text(
                                currentCat['desc'],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDarkMode ? Colors.white70 : Colors.black87,
                                  height: 1.3
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12,),
                  ],
                ),
              ),
            ),

            // BOTON GUARDAR
            Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              width: double.infinity,
              height: 85,
              child: SaveButton(
                // Cambiamos el texto dinámicamente
                label: widget.transactionToEdit != null ? "Actualizar Transacción" : "Guardar Transacción",
                onPressed: _submitData, // Le pasamos la función limpia
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget boton Ingreso/Gasto 
  Widget _buildTypeButton(String label, bool isExpenseBtn, Color incomeColor) {
    final isSelected = _isExpense == isExpenseBtn;
    final color = isExpenseBtn ? Colors.redAccent : incomeColor;

    return GestureDetector(
      onTap: () {
        setState(() {
          _isExpense = isExpenseBtn;

          if (_isExpense) {
            // Si elige GASTO -> Cambiamos a 'comida' por defecto
            _selectedCategoryName = _visibleCategories.first['name'];
          } else {
            // Si elige INGRESO seleciona la categoria ingresos
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
