import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:permission_handler/permission_handler.dart';
import '../main.dart'; 

class NotificationService {
  // singleton
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // INICIALIZACION
  Future<void> init() async {
    // La bd de timezones ya se inicializó en main.dart
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    } catch (e) {
      // Fallback seguro a UTC si falla el dispositivo
      tz.setLocalLocation(tz.UTC); 
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@drawable/ic_notification');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        if (response.payload == 'calendar_reminder') {
          navigatorKey.currentState?.pushNamed('/calendar');
        }
      },
    );

    // CREACIÓN DEL CANAL (Obligatorio en Android 8.0+)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'monthly_reminders_v19', // ID debe coincidir con el usado en zonedSchedule
      'Recordatorios Mensuales',
      description: 'Avisos de pagos recurrentes',
      importance: Importance.max,
      playSound: true,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // ADUANA DE PERMISOS
  Future<bool> _requestNotificationPermission() async {
    if (Platform.isAndroid) {
      var status = await Permission.notification.status;
      if (!status.isGranted) {
        // Muestra el cuadro de diálogo de Android pidiendo permiso
        status = await Permission.notification.request();
      }
      return status.isGranted;
    }
    return true; // En iOS se maneja automático con initializationSettingsDarwin
  }

  // VERIFICAR Y SOLICITAR PERMISO DE ALARMAS EXACTAS (ANDROID 12+)
  Future<bool> requestExactAlarmsPermission() async {
    if (Platform.isAndroid) {
      final androidImplementation = flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        final bool canScheduleExact =
            await androidImplementation.canScheduleExactNotifications() ?? false;
        if (!canScheduleExact) {
          final bool? granted =
              await androidImplementation.requestExactAlarmsPermission();
          return granted ?? false;
        }
        return true;
      }
    }
    return true;
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
    // ANTES de programar, pedimos el permiso amablemente.
    bool hasPermission = await _requestNotificationPermission();
    
    // Si el usuario nos niega el permiso, abortamos la programacion
    if (!hasPermission) {
      return; 
    }

    // si hay permiso, constante de detalle de notificaciones
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'monthly_reminders_v19', // Canal ID
      'Recordatorios Mensuales', 
      channelDescription: 'Avisos de pagos recurrentes',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@drawable/ic_notification',
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

    try {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id, 
        title,
        body,
        nextDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
        payload: 'calendar_reminder', 
      );
    } catch (e) {
      await flutterLocalNotificationsPlugin.zonedSchedule(
        id, 
        title,
        body,
        nextDate,
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfMonthAndTime,
        payload: 'calendar_reminder', 
      );
    }
  }

  // CANCELAR NOTIFICACION
  Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id);
  }

  // LOGICA DE CALENDARIO
  tz.TZDateTime _nextInstanceOfDay(int originalDay, int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    // Limpiamos los segundos y milisegundos de 'now' para comparación justa
    final tz.TZDateTime nowClean = tz.TZDateTime(tz.local, now.year, now.month, now.day, now.hour, now.minute);
    
    int daysInCurrentMonth = DateTime(now.year, now.month + 1, 0).day;
    int safeCurrentDay = math.min(originalDay, daysInCurrentMonth);
    
    tz.TZDateTime scheduledDate = tz.TZDateTime(tz.local, now.year, now.month, safeCurrentDay, hour, minute);

    if (scheduledDate.isBefore(nowClean)) {
      int daysInNextMonth = DateTime(now.year, now.month + 2, 0).day;
      int safeNextDay = math.min(originalDay, daysInNextMonth);
      
      // Creamos la fecha siguiente respetando tz.local, SIN USAR DateTime nativo para evitar desfases UTC
      scheduledDate = tz.TZDateTime(tz.local, now.year, now.month + 1, safeNextDay, hour, minute);
    }
    return scheduledDate;
  }
}
