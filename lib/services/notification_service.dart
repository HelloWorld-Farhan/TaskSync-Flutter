import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import '../main.dart';
import '../screens/routine_alarm_screen.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        final payload = response.payload ?? '';
        if (payload.startsWith('routine_')) {
          final parts = payload.split('_');
          if (parts.length >= 3) {
            int routineId = int.tryParse(parts[1]) ?? 0;
            int type = int.tryParse(parts[2]) ?? 0;
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                  builder: (_) => RoutineAlarmScreen(routineId: routineId, alarmType: type))
            );
          }
        }
        // Handle action buttons from persistent notifications
        if (response.actionId == 'done_action') {
          final parts = payload.split('_');
          if (parts.length >= 3) {
            int routineId = int.tryParse(parts[1]) ?? 0;
            navigatorKey.currentState?.push(
              MaterialPageRoute(
                  builder: (_) => RoutineAlarmScreen(routineId: routineId, alarmType: 2, autoConfirmDone: true))
            );
          }
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Create notification channels
    const AndroidNotificationChannel alarmChannel = AndroidNotificationChannel(
      'routine_alarm_channel',
      'Routine Alarms',
      description: 'Full screen alarm notifications for routines',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
    );

    const AndroidNotificationChannel progressChannel = AndroidNotificationChannel(
      'routine_progress_channel',
      'Routine Progress',
      description: 'Ongoing timer notification during routine',
      importance: Importance.low,
      playSound: false,
      enableVibration: false,
    );

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(alarmChannel);

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(progressChannel);
  }

  /// Full-screen alarm notification (shown on lock screen too)
  static Future<void> showFullScreenNotification(
      int id, String title, String body, String payload) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'routine_alarm_channel',
      'Routine Alarms',
      channelDescription: 'Full screen alarm notifications for routines',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      playSound: true,
      enableVibration: true,
      ongoing: false,
      autoCancel: true,
      showWhen: true,
    );

    final NotificationDetails details = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: details,
      payload: payload,
    );
  }

  /// Persistent ongoing notification while routine timer is running
  /// Cannot be dismissed by user — has "Done" action button
  static Future<void> showRoutineProgressNotification({
    required int id,
    required String routineTitle,
    required String endTime,
    required String payload,
    required int minutesRemaining,
  }) async {
    final List<AndroidNotificationAction> actions = [
      const AndroidNotificationAction(
        'done_action',
        '✅ Mark Done',
        showsUserInterface: true,
        cancelNotification: false,
      ),
    ];

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'routine_progress_channel',
      'Routine Progress',
      channelDescription: 'Ongoing timer notification during routine',
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      autoCancel: false,
      onlyAlertOnce: true,
      playSound: false,
      enableVibration: false,
      showProgress: false,
      actions: actions,
      subText: 'Routine in Progress',
      usesChronometer: true,
      chronometerCountDown: true,
      when: DateTime.now().add(Duration(minutes: minutesRemaining)).millisecondsSinceEpoch,
    );

    final NotificationDetails details = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      id: id,
      title: '⏱ $routineTitle',
      body: 'Ends at $endTime · Complete it to earn 100 pts',
      notificationDetails: details,
      payload: payload,
    );
  }

  /// Cancel a specific notification
  static Future<void> cancelNotification(int id) async {
    await flutterLocalNotificationsPlugin.cancel(id: id, tag: null);
  }

  /// Cancel all notifications
  static Future<void> cancelAllNotifications() async {
    await flutterLocalNotificationsPlugin.cancelAll();
  }
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // Background tap — handled by system
}
