import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // Para AppColors
import '../utils/currency_format.dart';
import '../utils/country_data.dart'; // Usamos tu nuevo archivo centralizado

class SettingsModal extends StatefulWidget {
  final String initialUserName;
  final Function(String) onProfileUpdated;

  const SettingsModal({
    super.key, 
    required this.initialUserName, 
    required this.onProfileUpdated
  });

  @override
  State<SettingsModal> createState() => _SettingsModalState();
}

class _SettingsModalState extends State<SettingsModal> {
  late TextEditingController _nameController;
  Map<String, String>? _selectedCountry;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialUserName);
    
    // Buscar el país seleccionado actualmente
    try {
      _selectedCountry = CountryData.countries.firstWhere(
        (c) => c['symbol'] == CurrencyFormat.currencySymbol
      );
    } catch (e) {
      _selectedCountry = CountryData.countries[0];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final newName = _nameController.text.trim().isEmpty ? "Usuario" : _nameController.text.trim();
    
    await prefs.setString('user_name', newName);
    
    if (_selectedCountry != null) {
      await prefs.setString('currency_symbol', _selectedCountry!['symbol']!);
      await prefs.setString('user_country', _selectedCountry!['name']!);
      CurrencyFormat.currencySymbol = _selectedCountry!['symbol']!;
    }
    
    if (mounted) {
      // Notificamos al Home que actualice el nombre
      widget.onProfileUpdated(newName);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    // EDGE-TO-EDGE
    final keyboardSpace = MediaQuery.of(context).viewInsets.bottom;
    final systemBottomPadding = MediaQuery.of(context).padding.bottom;
    final totalBottomPadding = keyboardSpace > 0 ? keyboardSpace : systemBottomPadding + 20;

    return Padding(
      padding: EdgeInsets.only(bottom: totalBottomPadding, left: 24, right: 24, top: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 20),
          const Text("Ajustes de Perfil", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          
          // Campo Nombre
          TextField(
            controller: _nameController,
            textCapitalization: TextCapitalization.words,
            style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              labelText: "Tu Nombre",
              floatingLabelStyle: TextStyle(
                color: isDarkMode ? AppColors.primary : Colors.black87,
                fontWeight: FontWeight.bold,
              ),
              prefixIcon: const Icon(Icons.person_outline_rounded),
              filled: true,
              fillColor: isDarkMode ? Colors.white10 : Colors.grey.shade200,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 16),

          // SELECTOR DE PAIS / MONEDA
          LayoutBuilder(
            builder: (context, constraints) {
              return DropdownMenu<Map<String, String>>(
                expandedInsets: EdgeInsets.zero, 
                menuHeight: 250, 
                requestFocusOnTap: false, 
                enableFilter: false, 
                enableSearch: false,
                initialSelection: _selectedCountry,
                hintText: "Selecciona tu país / moneda", 
                textStyle: TextStyle(color: isDarkMode ? Colors.white : Colors.black87, fontSize: 16),
                
                menuStyle: MenuStyle(
                  backgroundColor: WidgetStateProperty.all<Color>(isDarkMode ? AppColors.cardDark : Colors.white),
                  shape: WidgetStateProperty.all<OutlinedBorder>(
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: isDarkMode ? Colors.white10 : Colors.grey.shade200,
                  hintStyle: TextStyle(color: Colors.grey.shade600),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                
                dropdownMenuEntries: CountryData.countries.map((country) {
                  return DropdownMenuEntry<Map<String, String>>(
                    value: country,
                    label: "${country['flag']}  ${country['name']} (${country['symbol']})",
                    style: MenuItemButton.styleFrom(
                      foregroundColor: isDarkMode ? Colors.white : Colors.black87,
                    ),
                  );
                }).toList(),
                
                onSelected: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedCountry = value;
                    });
                  }
                },
              );
            }
          ),
          const SizedBox(height: 30),

          // Botón Guardar
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _saveSettings,
              style: ElevatedButton.styleFrom(
                backgroundColor: isDarkMode ? AppColors.primary : AppColors.primaryLight,
                foregroundColor: isDarkMode ? Colors.black : Colors.white, 
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
              ),
              child: const Text("Guardar Cambios", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}