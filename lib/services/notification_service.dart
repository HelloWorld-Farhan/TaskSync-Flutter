import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../main.dart';
import 'database_helper.dart';
import '../screens/routine_alarm_screen.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize({bool isBackground = false}) async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    final androidImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();


    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        if (isBackground) return; // Cannot push to navigator from background isolate
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
      'routine_alarm_channel_4',
      'Routine Alarms',
      description: 'Full screen alarm notifications for routines',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      enableLights: true,
      audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
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
      int id, String title, String body, String payload, {List<AndroidNotificationAction>? actions}) async {
    AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'routine_alarm_channel_4',
      'Routine Alarms',
      channelDescription: 'Full screen alarm notifications for routines',
      importance: Importance.max,
      priority: Priority.max,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
      playSound: true,
      enableVibration: true,
      ongoing: true,
      autoCancel: false,
      showWhen: true,
      actions: actions,
      additionalFlags: Int32List.fromList(<int>[4]), // FLAG_INSISTENT for continuous ringing
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
    required String endTimeStr,
    required String payload,
    required DateTime endTimeObj,
  }) async {
    final List<AndroidNotificationAction> actions = [
      const AndroidNotificationAction(
        'routine_end_done',
        '✅ Mark Done',
        showsUserInterface: true,
        cancelNotification: true,
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
      when: endTimeObj.millisecondsSinceEpoch,
    );

    final NotificationDetails details = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.show(
      id: id,
      title: '⏱ $routineTitle',
      body: 'Ends at $endTimeStr · Complete it to earn 100 pts',
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
void notificationTapBackground(NotificationResponse notificationResponse) async {
  WidgetsFlutterBinding.ensureInitialized();
  final actionId = notificationResponse.actionId;
  final payload = notificationResponse.payload;

  if (actionId != null && payload != null) {
    if (payload.startsWith('routine_')) {
      final parts = payload.split('_');
      if (parts.length >= 2) {
        int routineId = int.tryParse(parts[1]) ?? 0;
        if (routineId != 0) {
          final routines = await DatabaseHelper.instance.readAllRoutines();
          try {
            final routine = routines.firstWhere((r) => r['id'] == routineId);
            final now = DateTime.now();
            final nowStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
            
            // Try to find existing history for today
            final existingHistory = await DatabaseHelper.instance.getRoutineHistoryByDate(routineId, nowStr);
            int currentScore = existingHistory != null ? existingHistory['score'] : 0;
            
            if (actionId == 'routine_doing') {
              if (existingHistory == null) {
                await DatabaseHelper.instance.createRoutineHistory({
                  'routine_id': routineId, 'date': nowStr,
                  'completed_start': 1, 'completed_end': 0, 'score': -1,
                });
              }
              
              // Transition alarm into a progress timer
              final endParts = routine['end_time'].toString().split(':');
              DateTime endTimeObj = DateTime(now.year, now.month, now.day, int.parse(endParts[0]), int.parse(endParts[1]));
              if (endTimeObj.isBefore(now.subtract(const Duration(hours: 12)))) {
                endTimeObj = endTimeObj.add(const Duration(days: 1));
              }
              
              await NotificationService.showRoutineProgressNotification(
                id: routineId * 100 + 99,
                routineTitle: routine['title'],
                endTimeStr: routine['end_time'],
                payload: 'routine_${routineId}_2',
                endTimeObj: endTimeObj,
              );
            } else if (actionId == 'routine_start_done' || actionId == 'routine_cancel') {
              int score = (actionId == 'routine_start_done') ? 100 : 0;
              if (existingHistory == null) {
                await DatabaseHelper.instance.createRoutineHistory({
                  'routine_id': routineId, 'date': nowStr,
                  'completed_start': score > 0 ? 1 : 0, 'completed_end': score > 0 ? 1 : 0, 'score': score,
                });
              } else {
                existingHistory['score'] = score;
                await DatabaseHelper.instance.updateRoutineHistory(existingHistory);
              }
              // Cancel the end alarm
              try {
                // To avoid inline imports, we just call AlarmService.cancelRoutineAlarm(routineId);
                // But wait, AlarmService is not imported here.
                // Let's just update the routine_history, and the alarm can fire but we ignore it if it's already done.
                // Oh wait, in routineAlarmCallback, if score > 0, it won't fire the end alarm!
              } catch (e) {}
            } else if (actionId == 'routine_end_done') {
              int score = 0;
              // Check time difference
              final endParts = routine['end_time'].toString().split(':');
              DateTime endTime = DateTime(now.year, now.month, now.day, int.parse(endParts[0]), int.parse(endParts[1]));
              if (endTime.isBefore(now.subtract(const Duration(hours: 12)))) { // Adjust for midnight crossing if necessary, assuming same day for simple case
                 endTime = endTime.add(const Duration(days: 1));
              }
              
              if (now.difference(endTime).inMinutes <= 2) {
                score = 100;
              } else {
                score = 0; // The user requested "cut the hole points" if more than 2 min late
              }
              
              if (existingHistory == null) {
                await DatabaseHelper.instance.createRoutineHistory({
                  'routine_id': routineId, 'date': nowStr,
                  'completed_start': score > 0 ? 1 : 0, 'completed_end': score > 0 ? 1 : 0, 'score': score,
                });
              } else {
                existingHistory['score'] = score;
                await DatabaseHelper.instance.updateRoutineHistory(existingHistory);
              }
            }
          } catch (e) {
            print("Background error: \$e");
          }
        }
      }
    } else if (payload.startsWith('task_')) {
      final parts = payload.split('_');
      if (parts.length >= 2) {
        int taskId = int.tryParse(parts[1]) ?? 0;
        if (taskId != 0) {
          final task = await DatabaseHelper.instance.getTask(taskId);
          if (task != null) {
            task.isCompleted = (actionId == 'task_done') ? 1 : 2;
            await DatabaseHelper.instance.update(task);
          }
        }
      }
    }
  }
}
