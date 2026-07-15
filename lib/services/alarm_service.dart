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
    // Send email immediately
    await EmailService.sendEmailNow(
      email: task.recipientEmail,
      title: task.title,
      description: task.description,
    );

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
}
