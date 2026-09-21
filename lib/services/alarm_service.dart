import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import 'database_helper.dart';
import 'email_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
void alarmCallback(int id) async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize(isBackground: true);
  
  final task = await DatabaseHelper.instance.getTask(id);
  
  if (task != null) {
    // 1. Check if task is already completed (One-time tasks)
    if (task.isCompleted == 1) return;

    // 2. Prevent glitch fires
    try {
      final dateParts = task.date.split('-');
      final timeParts = task.time.split(':');
      DateTime scheduledTime = DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );
      
      // If we are firing more than 5 minutes before the actual target time, it's a glitch
      if (DateTime.now().isBefore(scheduledTime.subtract(const Duration(minutes: 5)))) {
        print('Ignoring glitch alarm: fired way too early for $scheduledTime');
        return; 
      }
    } catch (e) {
      print('Error parsing date/time for glitch check: $e');
    }

    // Show full screen local notification alarm
    await NotificationService.showFullScreenNotification(
      id, 
      "Reminder: ${task.title}", 
      "It's time for your reminder!", 
      "task_$id",
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction(
          'task_done',
          '✅ Done',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        AndroidNotificationAction(
          'task_cancel',
          '❌ Cancel',
          showsUserInterface: true,
          cancelNotification: true,
        ),
      ]
    );

    // Send email
    bool success = await EmailService.sendEmailNow(
      email: task.recipientEmail,
      title: task.title,
      description: task.description,
    );

    if (!success) {
      await DatabaseHelper.instance.insertPendingEmail(
        task.recipientEmail,
        task.title,
        task.description,
      );
      await AlarmService.startRetryTimer();
    }

    // If Daily, schedule next
    if (task.recurrenceType == 'Daily') {
      DateTime now = DateTime.now();
      DateTime nextTime = now.add(const Duration(days: 1));
      
      task.date = DateFormat('yyyy-MM-dd').format(nextTime);
      await DatabaseHelper.instance.update(task);
      await AlarmService.scheduleAlarm(task);
    } else if (task.recurrenceType == 'Custom' && task.customDates.isNotEmpty) {
      List<String> dates = task.customDates.split(',').map((e) => e.trim()).toList();
      dates.sort();
      
      String? nextDateStr;
      String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      for (String dStr in dates) {
        if (dStr.compareTo(todayStr) > 0) {
          nextDateStr = dStr;
          break;
        }
      }
      
      if (nextDateStr != null) {
        task.date = nextDateStr;
        await DatabaseHelper.instance.update(task);
        await AlarmService.scheduleAlarm(task);
      } else {
        task.isCompleted = 1;
        await DatabaseHelper.instance.update(task);
      }
    } else {
      task.isCompleted = 1;
      await DatabaseHelper.instance.update(task);
    }
  }
}

@pragma('vm:entry-point')
void retryCallback(int id) async {
  WidgetsFlutterBinding.ensureInitialized();
  final pending = await DatabaseHelper.instance.readAllPendingEmails();
  
  if (pending.isEmpty) {
    await AlarmService.stopRetryTimer();
    return;
  }

  bool allSuccess = true;
  for (var emailData in pending) {
    bool success = await EmailService.sendEmailNow(
      email: emailData['email'],
      title: emailData['title'],
      description: emailData['description'],
    );
    if (success) {
      await DatabaseHelper.instance.deletePendingEmail(emailData['id']);
    } else {
      allSuccess = false;
    }
  }

  if (allSuccess) {
    await AlarmService.stopRetryTimer();
  }
}

class AlarmService {
  static Future<void> scheduleAlarm(Task task) async {
    if (task.id == null) return;
    
    try {
      final dateParts = task.date.split('-');
      final timeParts = task.time.split(':');
      
      DateTime scheduledTime = DateTime(
        int.parse(dateParts[0]),
        int.parse(dateParts[1]),
        int.parse(dateParts[2]),
        int.parse(timeParts[0]),
        int.parse(timeParts[1]),
      );

      if (scheduledTime.isBefore(DateTime.now()) && task.recurrenceType == 'Daily') {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
        task.date = DateFormat('yyyy-MM-dd').format(scheduledTime);
        await DatabaseHelper.instance.update(task);
      }

      if (scheduledTime.isAfter(DateTime.now())) {
        await AndroidAlarmManager.oneShotAt(
          scheduledTime,
          task.id!,
          alarmCallback,
          exact: true,
          wakeup: true,
          rescheduleOnReboot: true,
        );
        print('Alarm scheduled for $scheduledTime (Task ID: ${task.id})');
      } else {
         print('Cannot schedule alarm in the past: $scheduledTime');
      }
    } catch (e) {
      print('Error parsing date/time for alarm: $e');
    }
  }
  
  static Future<void> cancelAlarm(int id) async {
    await AndroidAlarmManager.cancel(id);
  }

  static Future<void> startRetryTimer() async {
    await AndroidAlarmManager.periodic(
      const Duration(minutes: 1),
      99999,
      retryCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );
  }

  static Future<void> stopRetryTimer() async {
    await AndroidAlarmManager.cancel(99999);
  }

  // --- Routine Alarms ---
  static Future<void> scheduleRoutineAlarm(Map<String, dynamic> routine) async {
    int routineId = routine['id'];
    DateTime now = DateTime.now();
    final startParts = routine['start_time'].toString().split(':');
    final endParts = routine['end_time'].toString().split(':');
    
    DateTime startTime = DateTime(now.year, now.month, now.day, int.parse(startParts[0]), int.parse(startParts[1]));
    DateTime endTime = DateTime(now.year, now.month, now.day, int.parse(endParts[0]), int.parse(endParts[1]));

    if (startTime.isBefore(now)) startTime = startTime.add(const Duration(days: 1));
    if (endTime.isBefore(now)) endTime = endTime.add(const Duration(days: 1));

    int startId = routineId * 100 + 1;
    int endId = routineId * 100 + 2;

    await AndroidAlarmManager.periodic(
      const Duration(days: 1),
      startId,
      routineAlarmCallback,
      startAt: startTime,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );
    
    await AndroidAlarmManager.periodic(
      const Duration(days: 1),
      endId,
      routineAlarmCallback,
      startAt: endTime,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );
  }
  
  static Future<void> cancelRoutineAlarm(int routineId) async {
    await AndroidAlarmManager.cancel(routineId * 100 + 1);
    await AndroidAlarmManager.cancel(routineId * 100 + 2);
  }
}

@pragma('vm:entry-point')
void routineAlarmCallback(int id) async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.initialize(isBackground: true);
  
  int routineId = id ~/ 100;
  int type = id % 100;
  
  final routine = await DatabaseHelper.instance.getRoutine(routineId);
  if (routine == null) return;

  List<String> days = routine['days_of_week'].toString().split(',');
  List<String> weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  String todayStr = weekDays[DateTime.now().weekday - 1];
  
  if (!days.contains(todayStr)) return;

  if (type == 2) {
    final now = DateTime.now();
    final nowStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final history = await DatabaseHelper.instance.getRoutineHistoryByDate(routineId, nowStr);
    
    // If it's already completed or cancelled (score >= 0), don't fire end alarm
    if (history != null && (history['score'] as int) >= 0) {
      return;
    }
  }

  String title = routine['title'];
  String body = type == 1 ? "Time to start your routine!" : "Routine time is over!";
  String payload = "routine_${routineId}_$type";
  
  List<AndroidNotificationAction> actions = [
    const AndroidNotificationAction('routine_doing', '🏃 Doing it', showsUserInterface: true, cancelNotification: true),
    const AndroidNotificationAction('routine_end_done', '✅ Done', showsUserInterface: true, cancelNotification: true),
    const AndroidNotificationAction('routine_cancel', '❌ Cancel', showsUserInterface: true, cancelNotification: true),
  ];
  
  await NotificationService.showFullScreenNotification(id, title, body, payload, actions: actions);
}

