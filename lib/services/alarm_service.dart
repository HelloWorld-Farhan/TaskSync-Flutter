import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import 'database_helper.dart';
import 'email_service.dart';

@pragma('vm:entry-point')
void alarmCallback(int id) async {
  WidgetsFlutterBinding.ensureInitialized();
  final task = await DatabaseHelper.instance.getTask(id);
  
  if (task != null) {
    // 1. Check if task is already completed (One-time tasks)
    if (task.isCompleted == 1) return;

    // 2. Prevent glitch fires (e.g., from app update/reboot rescheduling future/past alarms incorrectly)
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
      
      // Update DB with new date
      task.date = DateFormat('yyyy-MM-dd').format(nextTime);
      await DatabaseHelper.instance.update(task);
      
      // Schedule next alarm
      await AlarmService.scheduleAlarm(task);
    } else if (task.recurrenceType == 'Custom' && task.customDates.isNotEmpty) {
      // Find the next date in the comma-separated list
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
      // Once
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
    
    // Parse task date and time
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

      // If scheduled time is in the past (e.g. today but past time), and it's daily, add 1 day
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
    // Schedule a periodic alarm every 1 minute to retry sending emails
    await AndroidAlarmManager.periodic(
      const Duration(minutes: 1),
      99999, // Unique ID for retry timer
      retryCallback,
      exact: true,
      wakeup: true,
      rescheduleOnReboot: true,
    );
    print('Started offline retry timer');
  }

  static Future<void> stopRetryTimer() async {
    await AndroidAlarmManager.cancel(99999);
    print('Stopped offline retry timer');
  }
}
