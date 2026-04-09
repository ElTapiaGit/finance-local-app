import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // Para AppColors
import '../utils/currency_format.dart';
import '../utils/country_data.dart';
import 'home_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final TextEditingController _nameController = TextEditingController();

  // para que el Dropdown
  Map<String, String>? _selectedCountry;

  @override
  void initState() {
    super.initState();
    
    // Auto-detectar el pais despues del primer frame para tener acceso al context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final locale = Localizations.localeOf(context);
      final countryCode = locale.countryCode; 
      
      if (countryCode != null) {
        final mapToCountry = {
          'BO': 'Bolivia',
          'CO': 'Colombia',
          'PE': 'Perú',
          'AR': 'Argentina',
          'MX': 'México',
          'CL': 'Chile',
          'ES': 'España',
          'US': 'Estados Unidos',
        };
        
        final detectedName = mapToCountry[countryCode];
        
        if (detectedName != null) {
          setState(() {
            // Buscamos el pais en nuestra lista oficial
            _selectedCountry = CountryData.countries.firstWhere(
              (c) => c['name'] == detectedName,
              // Si falla por alguna razon, no selecciona nada
              orElse: () => CountryData.countries.first, 
            );
          });
        }
      }
    });
  }

  Future<void> _saveNameAndContinue() async {
    // Validamos que haya puesto nombre Y seleccionado un pais
    if (_nameController.text.trim().isEmpty || _selectedCountry == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _nameController.text.trim());
    await prefs.setString('currency_symbol', _selectedCountry!['symbol']!); 
    await prefs.setString('user_country', _selectedCountry!['name']!); 

    CurrencyFormat.currencySymbol = _selectedCountry!['symbol']!; 

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 80.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset('assets/icon/logo.png', width: 100, height: 100), 
              const SizedBox(height: 30),
              const Text(
                "¡Bienvenido!",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 10),
              const Text(
                "Configura tu perfil para comenzar",
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 40),
              
              // INPUT DE NOMBRE
              TextField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                textAlign: TextAlign.center,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white10,
                  hintText: "¿Cómo te llamas?",
                  hintStyle: TextStyle(color: Colors.grey.shade600),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
              const SizedBox(height: 20),
              
              // SELECTOR DE PAIS / MONEDA (DropdownMenu Perfeccionado)
              DropdownMenu<Map<String, String>>(
                // ANCHO PERFECTO: Toma el 100% del ancho del padre igual que el TextField
                expandedInsets: EdgeInsets.zero, 
                // ALTURA CONTROLADA
                menuHeight: 250, 
                // SOLO LECTURA
                requestFocusOnTap: false, 
                enableFilter: false, 
                enableSearch: false,
                initialSelection: _selectedCountry,
                hintText: "Selecciona tu país / moneda", 
                textStyle: const TextStyle(color: Colors.white, fontSize: 16),
                
                menuStyle: MenuStyle(
                  backgroundColor: WidgetStateProperty.all<Color>(AppColors.cardDark),
                  shape: WidgetStateProperty.all<OutlinedBorder>(
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: Colors.white10,
                  hintStyle: TextStyle(color: Colors.grey.shade600),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                
                dropdownMenuEntries: CountryData.countries.map((country) {
                  return DropdownMenuEntry<Map<String, String>>(
                    value: country,
                    label: "${country['flag']}  ${country['name']} (${country['symbol']})",
                    style: MenuItemButton.styleFrom(
                      foregroundColor: Colors.white, // Color del texto en la lista
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
              ),
              
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _saveNameAndContinue,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  child: const Text("Comenzar", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}