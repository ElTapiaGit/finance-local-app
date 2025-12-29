import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:io';
import '../main.dart'; 

class NotificationService {
  // singleton
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // INICIALIZACION
  Future<void> init() async {
    // configurar zona horaria real
    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('America/La_Paz'));
    } catch (e) {
      tz.setLocalLocation(tz.UTC); 
    }

    // configuracion android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@android:drawable/ic_dialog_info');

    // configuracion ios
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    // CLAVE PARA EL DEEP LINKING 
    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      // ejecuta cuando el usuario TOCA la notificación
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload == 'calendar_reminder') {
          navigatorKey.currentState?.pushNamed('/calendar');
        }
      },
    );
    
    // PEDIR PERMISO EN ANDROID 13+ 
    if (Platform.isAndroid) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    }
  }
  //FUNCIONES DE LECTURA
  // Verificar si la app se abrio desde una notificacion cerrada
  Future<String?> getPendingNotificationPayload() async {
    final NotificationAppLaunchDetails? details = 
        await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
    
    if (details != null && details.didNotificationLaunchApp) {
      return details.notificationResponse?.payload;
    }
    return null;
  }
  
  // PROGRAMAR NOTIFICACION MENSUAL 
  Future<void> scheduleMonthlyNotification({
    required int id,
    required String title,
    required String body,
    required int dayOfMonth, 
    int hour = 9,  
    int minute = 0, 
  }) async {
    // constante de detalle de notificaciones
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'monthly_reminders_v19', // Canal ID
      'Recordatorios Mensuales', 
      channelDescription: 'Avisos de pagos recurrentes',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@android:drawable/ic_dialog_info',
      // ongoing: false, //falso para borrar notificacion 
    );

    const DarwinNotificationDetails darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails, 
      macOS: darwinDetails,
    );

    final tz.TZDateTime nextDate = _nextInstanceOfDay(dayOfMonth, hour, minute);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id, 
      title,
      body,
      nextDate,
      notificationDetails,
      //Hace que se repita cada mes en ese dia y hora
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      // Obligatorio en v17+
      //uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      // Repeticion mensual
      matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
      // AGREGAMOS EL PAYLOAD (LA ETIQUETA)
      payload: 'calendar_reminder', 
    );
  }

  // CANCELAR NOTIFICACION
  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  // LOGICA DE CALENDARIO
  tz.TZDateTime _nextInstanceOfDay(int day, int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    // Nota: Si el usuario pone día 31 y el mes solo tiene 30, la librería suele ajustar o lanzar error.
    // Creamos la fecha objetivo intentando respetar el mes actual
    
    //para meses cortos
    int safeDay = day;
    int daysInCurrentMonth = DateTime(now.year, now.month + 1, 0).day;
    if (safeDay > daysInCurrentMonth) {
      safeDay = daysInCurrentMonth;
    }
    // Generamos una fecha base segura
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, safeDay, hour, minute);

    if (scheduledDate.isBefore(now)) {
      // Si la fecha ya pasó este mes, pasamos al siguiente
      scheduledDate = tz.TZDateTime(tz.local, now.year, now.month + 1, day, hour, minute);
    }
    return scheduledDate;
  }
}
