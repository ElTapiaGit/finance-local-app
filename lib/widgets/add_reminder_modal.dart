import 'package:finance_local/utils/categories_data.dart';
import 'package:finance_local/widgets/save_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart'; // Para AppColors
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../utils/currency_format.dart';

class AddReminderModal extends StatefulWidget {
  final int? initialDay; //obtenemos el dia del calendario
  const AddReminderModal({super.key, this.initialDay});

  @override
  State<AddReminderModal> createState() => _AddReminderModalState();
}

class _AddReminderModalState extends State<AddReminderModal> {
  // CONTROLADORES
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  // ESTADO
  late int _selectedDay;
  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  bool _showError = false;

  String _selectedCategoryName = 'Servicios'; 
  final List<Map<String, dynamic>> _categories = CategoryData.reminderCategories;

  @override
  void initState() {
    super.initState();
    // Si recibe un dia del calendario, usalo. Si no, usa el dia de hoy.
    _selectedDay = widget.initialDay ?? DateTime.now().day;
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
                  primary: AppColors.primary, // Manecilla y seleccion
                  onPrimary: Colors.black,    // Texto en la seleccion
                  surface: AppColors.cardDark, // Fondo del reloj
                  onSurface: Colors.white,    // Números
                )
              : ColorScheme.light(
                  primary: clockColor,        // Manecilla y seleccion (Verde Oscuro)
                  onPrimary: Colors.white,    // Texto en la seleccion
                  surface: Colors.white,      // Fondo del reloj
                  onSurface: Colors.black,    // Números
                ), dialogTheme: DialogThemeData(backgroundColor: isDarkMode ? AppColors.cardDark : Colors.white),
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final title = _titleController.text.trim();
    
    //OBTENER Y LIMPIAR EL MONTO
    String amountText = _amountController.text.trim();
    amountText = amountText.replaceAll(',', '');

    // VALIDACION VISUAL
    if (title.isEmpty || amountText.isEmpty) {
      setState(() => _showError = true);
      return;
    }

    final amount = double.tryParse(amountText) ?? 0.0;

    // OBTENER DATOS DE LA CATEGORIA SELECCIONADA
    final selectedCat = _categories.firstWhere((c) => c['name'] == _selectedCategoryName);
    // DATOS FIJOS PARA RECORDATORIOS
    final int colorValue = (selectedCat['color'] as Color).toARGB32();
    final int iconCode = (selectedCat['icon'] as IconData).codePoint;

    // GUARDAR EN BD
    final db = DatabaseService();
    final newId = await db.saveReminderAndReturnId(
      title: title,
      amount: amount,
      dayOfMonth: _selectedDay,
      color: colorValue,
      icon: iconCode, //icono para smart match
    );

    // PROGRAMAR NOTIFICACION
    final notifService = NotificationService();
    await notifService.scheduleMonthlyNotification(
      id: newId, 
      title: "¡Momento de pagar!",
      body: "Pagar $title (Bs ${amount.toStringAsFixed(2)})",
      dayOfMonth: _selectedDay,
      hour: _selectedTime.hour,     
      minute: _selectedTime.minute, 
    );

    // CERRAR Y CONFIRMAR
    if (context.mounted) {
      // ignore: use_build_context_synchronously
      Navigator.pop(context);  
      // ignore: use_build_context_synchronously
      final timeStr = _selectedTime.format(context); 
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Alarma creada: Día $_selectedDay a las $timeStr", style: TextStyle(color: isDarkMode ? const Color(0xFF221A1A) : Colors.white, fontWeight: FontWeight.bold),),
          backgroundColor: isDarkMode ? AppColors.primary.withValues(alpha: 0.9) : AppColors.primaryLight.withValues(alpha: 0.9),
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final keyboardSpace = MediaQuery.of(context).viewInsets.bottom; // Altura del teclado
    final contrastColor = isDarkMode ? AppColors.primary : AppColors.primaryLight;

    return Padding(
      // Empuja el modal hacia arriba
      padding: EdgeInsets.only(bottom: keyboardSpace),
      child: SizedBox(
        height: 650, // altura fija modal
        child: Column(
          children: [
            // INDICADOR DE ARRASTRE
            const SizedBox(height: 20),
            Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
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
                      onChanged: (_) {
                        if (_showError) setState(() => _showError = false);
                      },
                      decoration: InputDecoration(
                        labelText: "Nombre del servicio (Ej: Netflix)",
                        labelStyle: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87,),
                        prefixIcon: const Icon(Icons.label_outline_rounded),
                        filled: true,
                        fillColor: isDarkMode ? Colors.white10 : Colors.grey.shade100,
                        
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: _showError ? const BorderSide(color: Colors.red) : BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: _showError 
                            ? const BorderSide(color: Colors.red, width: 2)
                            : BorderSide(color: contrastColor, width: 2),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),

                    // INPUT DE MONTO
                    TextField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      // bloqueo de maximo dos decimales
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                        CurrencyInputFormatter(),
                      ],
                      decoration: InputDecoration(
                        labelText: "Monto Mensual (Bs)",
                        labelStyle: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black87,),
                        prefixIcon: const Icon(Icons.attach_money_rounded),
                        filled: true,
                        fillColor: isDarkMode ? Colors.white10 : Colors.grey.shade100,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: _showError ? const BorderSide(color: Colors.red) : BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: _showError 
                            ? const BorderSide(color: Colors.red, width: 2)
                            : BorderSide(color: contrastColor, width: 2),
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),
                    // SELECTOR DE CATEGORIA
                    Align(alignment: Alignment.centerLeft, child: Text("Categoría", style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontWeight: FontWeight.w600))),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 70,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _categories.length,
                        itemBuilder: (context, index) {
                          final cat = _categories[index];
                          final isSelected = _selectedCategoryName == cat['name'];
                          return GestureDetector(
                            // Bloqueamos seleccion si esta cargando
                            onTap: () => setState(() => _selectedCategoryName = cat['name']),
                            child: Container(
                              margin: const EdgeInsets.only(right: 16),
                              child: Column(
                                children: [
                                  Container(
                                    width: 45, height: 45,
                                    decoration: BoxDecoration(
                                      color: isSelected ? cat['color'] : (isDarkMode ? Colors.white10 : Colors.grey.shade100),
                                      shape: BoxShape.circle,
                                      border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                                    ),
                                    child: Icon(cat['icon'], color: isSelected ? Colors.white : Colors.grey, size: 20),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(cat['name'], style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? (isDarkMode ? Colors.white : Colors.black) : Colors.grey))
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
                              Text("Día del mes", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              const SizedBox(height: 8),
                              
                              Container(
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
                                    Icon(Icons.calendar_today_rounded, 
                                      size: 16, 
                                      color: isDarkMode ? Colors.white54 : Colors.grey.shade600
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "Día $_selectedDay",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold, 
                                        fontSize: 16,
                                        color: isDarkMode ? Colors.white70 : Colors.black87
                                      ),
                                    ),
                                  ],
                                )
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
                                Text("Hora de aviso", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
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
                                          color: contrastColor
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(
                                        Icons.access_time_rounded,
                                        color: contrastColor,
                                        size: 20,
                                      )
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20,),
                    //MENSAJE INFROMATIVO CARD
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3))
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline_rounded, color: Colors.blueAccent,),
                          const SizedBox(width: 12,),
                          Expanded(
                            child: Text(
                              "Resivira notificaciones cada mes, el día $_selectedDay de cada mes. Recuerde otorgar permiso para recibir notificacion.",
                              style: TextStyle(
                                fontSize: 13,
                                color: isDarkMode ? Colors.white70 : Colors.black87
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
                onPressed: _save, // Pasamos la función limpia
              ),
            ),
          ],
        ),
      ),
    );
  }
}
