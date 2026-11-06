import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart'; // Para AppColors, navigatorKey
import '../models/category_model.dart';
import '../services/category_preferences_service.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../utils/currency_format.dart';
import 'save_button.dart';

class AddReminderModal extends StatefulWidget {
  final int? initialDay; // Obtenemos el dia del calendario
  const AddReminderModal({super.key, this.initialDay});

  @override
  State<AddReminderModal> createState() => _AddReminderModalState();
}

class _AddReminderModalState extends State<AddReminderModal> {
  final CategoryPreferencesService _categoryPrefsService = CategoryPreferencesService();

  // CONTROLADORES
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();

  // ESTADO
  late int _selectedDay;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  bool _showError = false;

  List<CategoryModel> _orderedCategories = [];
  CategoryModel? _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.initialDay ?? DateTime.now().day;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final order = await _categoryPrefsService.getCategoryOrder();
    final allCats = DatabaseService().categoryBox.values.toList();

    // Filtra 'Ingreso' y aplica el orden del usuario
    var sorted = _categoryPrefsService.applyOrder(allCats, order)
        .where((c) => c.name != 'Ingreso').toList();

    // Extrae 'Servicios' y clávala en la posicion 0
    final serviciosIndex = sorted.indexWhere((c) => c.name == 'Servicios');
    if (serviciosIndex != -1) {
      final serviciosCat = sorted.removeAt(serviciosIndex);
      sorted.insert(0, serviciosCat);
    }

    if (mounted) {
      setState(() {
        _orderedCategories = sorted;
        if (_selectedCategory == null && sorted.isNotEmpty) {
          _selectedCategory = sorted.first; // Selecciona 'Servicios' por defecto
        }
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  // SELECCIONAR DIA DEL MES
  Future<void> _pickDay() async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDarkMode ? AppColors.primary : AppColors.primaryLight;
    final activeTextColor = isDarkMode ? Colors.black : Colors.white;

    final int? picked = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDarkMode ? AppColors.cardDark : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          "Selecciona el día del mes",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            itemCount: 28,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final day = index + 1;
              final isSelected = day == _selectedDay;
              return InkWell(
                onTap: () => Navigator.pop(ctx, day),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? activeColor
                        : (isDarkMode ? Colors.white10 : Colors.grey.shade200),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    "$day",
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected
                          ? activeTextColor
                          : (isDarkMode ? Colors.white : Colors.black87),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              "Cancelar",
              style: TextStyle(color: activeColor, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (picked != null) {
      setState(() {
        _selectedDay = picked;
      });
    }
  }

  // SELECCIONAR HORA
  Future<void> _pickTime() async {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final clockColor = isDarkMode ? AppColors.primary : AppColors.primaryLight;

    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDarkMode
                ? ColorScheme.dark(
                    primary: AppColors.primary,
                    onPrimary: Colors.black,
                    surface: AppColors.cardDark,
                    onSurface: Colors.white,
                  )
                : ColorScheme.light(
                    primary: clockColor,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black,
                  ),
            dialogTheme: DialogThemeData(
              backgroundColor: isDarkMode ? AppColors.cardDark : Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();

    // OBTENER Y LIMPIAR EL MONTO
    String amountText = _amountController.text.trim();
    amountText = amountText.replaceAll(',', '');

    // VALIDACION VISUAL
    if (title.isEmpty || amountText.isEmpty) {
      setState(() => _showError = true);
      return;
    }

    final amount = double.tryParse(amountText) ?? 0.0;

    // OBTENER DATOS DE LA CATEGORIA SELECCIONADA
    CategoryModel? selectedCat = _selectedCategory;
    if (selectedCat == null) {
      final categories = DatabaseService().categoryBox.values.toList();
      if (categories.isNotEmpty) {
        selectedCat = categories.firstWhere(
          (c) => c.name != 'Ingreso',
          orElse: () => categories.first,
        );
      }
    }

    final int colorValue = selectedCat?.colorValue ?? Colors.blue.toARGB32();
    final int iconCode = selectedCat?.iconCode ?? Icons.notifications_rounded.codePoint;

    final db = DatabaseService();
    // 1. Guardamos SIEMPRE en BD primero.
    final newId = await db.saveReminderAndReturnId(
      title: title,
      amount: amount,
      dayOfMonth: _selectedDay,
      color: colorValue,
      icon: iconCode,
      hour: _selectedTime.hour,
      minute: _selectedTime.minute,
    );

    // 2. Intentamos programar la alarma.
    final notifService = NotificationService();
    try {
      await notifService.requestExactAlarmsPermission();
      await notifService.scheduleMonthlyNotification(
        id: newId,
        title: "¡Momento de pagar!",
        body: "Pagar $title (${CurrencyFormat.currencySymbol}  ${amount.toStringAsFixed(2)})",
        dayOfMonth: _selectedDay,
        hour: _selectedTime.hour,
        minute: _selectedTime.minute,
      );
    } catch (e) {
      debugPrint("Error programando alarma: $e");
      if (!mounted) return;
      FocusScope.of(context).unfocus();
      // Mostramos diálogo de error CRÍTICO en lugar del de éxito
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("Error de Sistema"),
          content: Text("El recordatorio se guardó en tu calendario, pero tu teléfono bloqueó la alarma. Error: $e"),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context); // Cierra el modal principal
              },
              child: const Text("Entendido"),
            ),
          ],
        ),
      );
      return; // Detenemos aquí, ya no muestra el mensaje de Xiaomi/Samsung.
    }

    if (!mounted) return;
    FocusScope.of(context).unfocus();
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    Navigator.pop(context); 

    // 3. Muestra el diálogo educativo post-guardado
    final navContext = navigatorKey.currentContext;
    if (navContext != null && navContext.mounted) {
      showDialog(
        context: navContext,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.notifications_active_rounded, color: Colors.blueAccent),
              SizedBox(width: 10),
              Expanded(
                child: Text("Notificación Programada"),
              ),
            ],
          ),
          content: const Text(
            "Importante: Si usas Xiaomi, Huawei o Samsung, asegúrate de activar el 'Inicio Automático' y quitar las restricciones de batería para esta aplicación en los ajustes de tu teléfono. De lo contrario, el sistema podría silenciar tus alarmas.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                "Entendido",
                style: TextStyle(
                  color: isDarkMode ? AppColors.primary : AppColors.primaryLight,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final keyboardSpace = MediaQuery.of(context).viewInsets.bottom;
    final systemBottomPadding = MediaQuery.of(context).padding.bottom;
    final contrastColor = isDarkMode ? AppColors.primary : AppColors.primaryLight;

    return Padding(
      // Empuja el modal hacia arriba
      padding: EdgeInsets.only(bottom: keyboardSpace + systemBottomPadding),
      child: SizedBox(
        height: 650, // altura fija modal
        child: Column(
          children: [
            // INDICADOR DE ARRASTRE
            const SizedBox(height: 20),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              "Programar Gasto Fijo",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),

            // CONTENIDO SCROLLABLE
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    // INPUT DE NOMBRE
                    TextField(
                      controller: _titleController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        labelText: "Concepto o Servicio",
                        hintText: "Ej. Alquiler, Netflix, Internet",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        errorText: _showError && _titleController.text.isEmpty
                            ? "Ingrese un concepto"
                            : null,
                      ),
                    ),
                    const SizedBox(height: 15),

                    // INPUT DE MONTO
                    TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+[\.,]?\d{0,2}')),
                      ],
                      decoration: InputDecoration(
                        labelText: "Monto a pagar",
                        prefixText: "${CurrencyFormat.currencySymbol}  ",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        errorText: _showError && _amountController.text.isEmpty
                            ? "Ingrese un monto"
                            : null,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // SELECCION DE CATEGORIA DINAMICA
                    Container(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Categoría",
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    SizedBox(
                      height: 70,
                      child: _orderedCategories.isEmpty
                          ? const Center(child: Text("No hay categorías"))
                          : ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: _orderedCategories.length,
                              itemBuilder: (context, index) {
                                final cat = _orderedCategories[index];
                                final isSelected = _selectedCategory?.name == cat.name;
                                final catColor = Color(cat.colorValue);
                                final catIcon = IconData(cat.iconCode, fontFamily: 'MaterialIcons');

                                return GestureDetector(
                                  onTap: () {
                                    setState(() => _selectedCategory = cat);
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 16),
                                    child: Column(
                                      children: [
                                        Container(
                                          width: 45,
                                          height: 45,
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? catColor
                                                : (isDarkMode ? Colors.white10 : Colors.grey.shade100),
                                            shape: BoxShape.circle,
                                            border: isSelected
                                                ? Border.all(color: Colors.white, width: 2)
                                                : null,
                                          ),
                                          child: Icon(
                                            catIcon,
                                            color: isSelected ? Colors.white : Colors.grey,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          cat.name,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight:
                                                isSelected ? FontWeight.bold : FontWeight.normal,
                                            color: isSelected
                                                ? (isDarkMode ? Colors.white : Colors.black)
                                                : Colors.grey,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const Divider(),
                    const SizedBox(height: 10),

                    // CONFIGURACION DE FECHA Y HORA
                    Row(
                      children: [
                        // DIA DEL MES
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Día del mes",
                                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                              ),
                              const SizedBox(height: 8),

                              InkWell(
                                onTap: _pickDay,
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  height: 50,
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  decoration: BoxDecoration(
                                    color: isDarkMode ? Colors.white10 : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.grey.shade400),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.calendar_today_rounded,
                                        size: 16,
                                        color: isDarkMode ? Colors.white54 : Colors.grey.shade600,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        "Día $_selectedDay",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: isDarkMode ? Colors.white70 : Colors.black87,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),
                        Container(width: 1, height: 40, color: Colors.grey.shade300),
                        const SizedBox(width: 12),

                        // SELECTOR DE HORA
                        Expanded(
                          child: InkWell(
                            onTap: _pickTime,
                            borderRadius: BorderRadius.circular(12),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  "Hora de aviso",
                                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  height: 50,
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: contrastColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: contrastColor),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _selectedTime.format(context),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: contrastColor,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.access_time_rounded,
                                        color: contrastColor,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    // MENSAJE INFORMATIVO CARD
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Colors.blueAccent),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              "Recibirá notificaciones cada mes, el día $_selectedDay de cada mes. Recuerde otorgar permiso para recibir notificación.",
                              style: TextStyle(
                                fontSize: 13,
                                color: isDarkMode ? Colors.white70 : Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
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
                label: "Activar Recordatorio",
                onPressed: _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
