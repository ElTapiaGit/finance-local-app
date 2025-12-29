// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart'; 
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'screens/home_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/calendar_screen.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';

// variable global para Deep Linking
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

FirebaseAnalytics? analytics;
void main() async {
  //aseguramos la vinculacion con el motor grafico
  WidgetsFlutterBinding.ensureInitialized(); 
  
  await Hive.initFlutter();
  //debugPrint("✅ Hive inicializado correctamente.");
  try {
    // Inicializar Firebase
    await Firebase.initializeApp();
    analytics = FirebaseAnalytics.instance; // Guardamos la instancia
    //debugPrint("✅ Firebase inicializado correctamente");
  } catch (e) {
    //debugPrint("⚠️ Error inicializando Firebase: $e");
    // La app continuará funcionando aunque Firebase falle (offline mode implícito)
  }

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  // UI System Overlay (Rapido)
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark, 
    statusBarBrightness: Brightness.light, 
  ));

  // Bloqueo de orientacion 
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  // LANZAMOS LA APP
  runApp(const ExpenseTrackerApp());
}

// COLORES GLOBALES 
class AppColors {
  static const Color primary = Color(0xFF13EC5B); 
  static const Color primaryLight = Color(0xFF0B8E36);
  static const Color backgroundDark = Color(0xFF102216); 
  static const Color cardDark = Color(0xFF1C2C20); 
  static const Color textGrayLight = Color(0xFF9DB9A6); 
}

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, 

      title: 'Finance Local',
      debugShowCheckedModeBanner: false,
      // FIREBASE ANALYTICSn
      navigatorObservers: [
        if (analytics != null) 
          FirebaseAnalyticsObserver(analytics: analytics!),
      ],
      // ARREGLAR EL CALENDARIO 
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en', 'US'), // Inglés
        Locale('es', 'ES'), // Español
      ],
      // temas light y dark 
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: const Color(0xFFF6F8F6),
        //color base
        colorScheme: const ColorScheme.light(primary: AppColors.primary, secondary: AppColors.primary),
        // appBar transparente
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle.dark,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        //colores del cursor
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: AppColors.primaryLight, // Verde Oscuro dn light
          selectionColor: AppColors.primaryLight.withValues(alpha:  0.3),
          selectionHandleColor: AppColors.primaryLight, // La burbuja debajo del cursor
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.backgroundDark,
        cardColor: AppColors.cardDark,
        colorScheme: const ColorScheme.dark(primary: AppColors.primary, secondary: AppColors.primary, surface: AppColors.cardDark),
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle.light,
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        //colores del cursor
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: AppColors.primary, 
          selectionColor: AppColors.primary.withValues(alpha:  0.3),
          selectionHandleColor: AppColors.primary,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system, 
      // Esto permite que NotificationService llame a '/calendar'
      routes: {
        '/home': (context) => const HomeScreen(),
        '/calendar': (context) => const CalendarScreen(),
      },
      //pantalla inicail al Splash de carga
      home: const SplashScreen(), 
    );
  }
}

// WIDGET PANTALLA DE CARGA 
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  
  @override
  void initState() {
    super.initState();
    // Ejecutamos la carga después de que el primer frame se haya dibujado
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeApp();
    });
  }

  Future<void> _initializeApp() async {
    try {
      // Carga paralela para ganar milisegundos
      await Future.wait([
        DatabaseService().init(),
        NotificationService().init(),
        initializeDateFormatting('es', null),
      ]);

      // VERIFICAR SI VENIMOS DE UNA NOTIFICACION (APP CERRADA)
      final String? payload = await NotificationService().getPendingNotificationPayload();
      
      if (mounted) {
        if (payload == 'calendar_reminder') {
          // Venimos de notificacion -> Directo al Calendario
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const CalendarScreen()),
          );
          return; 
        }

        // VERIFICAR SI YA TIENE NOMBRE GUARDADO
        final prefs = await SharedPreferences.getInstance();
        final String? savedName = prefs.getString('user_name');

        if (savedName != null && savedName.isNotEmpty) {
          // Ya tiene nombre -> Al Home
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
          );
        } else {
          // No tiene nombre -> A la pantalla de Bienvenida
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const WelcomeScreen()), // Importa el archivo
          );
        }
      }
      
    } catch (e) {
      //debugPrint("❌ Error inicializando: $e");
      // Si falla algo, por seguridad mandamos al Home o reintentamos
      if (mounted) {
         Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
         );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode ? AppColors.backgroundDark : Colors.white;
    final accentColor = isDarkMode ? AppColors.primary : AppColors.backgroundDark;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // LOGO 
            Image.asset(
              'assets/icon/logo.png',
              width: 150, 
              height: 150, 
            ),
            const SizedBox(height: 24),
            // TEXTO
            Text(
              "Finance Local",
              style: TextStyle(
                fontSize: 28, 
                fontWeight: FontWeight.bold,
                color: accentColor,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 48),
            // INDICADOR DE CARGA
            CircularProgressIndicator(
              color: accentColor,
              strokeWidth: 3,
            )
          ],
        ),
      ),
    );
  }
}