import 'package:flutter/material.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'dart:async';
import '../services/database_helper.dart';

class RoutineAlarmScreen extends StatefulWidget {
  final int routineId;
  final int alarmType; // 1 = start, 2 = end

  const RoutineAlarmScreen({
    super.key,
    required this.routineId,
    required this.alarmType,
  });

  @override
  State<RoutineAlarmScreen> createState() => _RoutineAlarmScreenState();
}

class _RoutineAlarmScreenState extends State<RoutineAlarmScreen> {
  Map<String, dynamic>? routine;
  Timer? _ringTimer;

  @override
  void initState() {
    super.initState();
    _loadRoutine();
    
    // Play ringtone
    FlutterRingtonePlayer().playAlarm();
    
    // Stop after 10 seconds
    _ringTimer = Timer(const Duration(seconds: 10), () {
      FlutterRingtonePlayer().stop();
    });
  }

  Future<void> _loadRoutine() async {
    final data = await DatabaseHelper.instance.getRoutine(widget.routineId);
    setState(() {
      routine = data;
    });
  }

  Future<void> _markDone() async {
    FlutterRingtonePlayer().stop();
    _ringTimer?.cancel();
    
    if (routine != null) {
      String today = DateTime.now().toIso8601String().split('T').first;
      var history = await DatabaseHelper.instance.getRoutineHistoryByDate(widget.routineId, today);
      
      if (history == null) {
        history = {
          'routine_id': widget.routineId,
          'date': today,
          'completed_start': widget.alarmType == 1 ? 1 : 0,
          'completed_end': widget.alarmType == 2 ? 1 : 0,
          'score': 10 // 10 points for completion
        };
        await DatabaseHelper.instance.createRoutineHistory(history);
      } else {
        history = Map<String, dynamic>.from(history);
        if (widget.alarmType == 1) {
          history['completed_start'] = 1;
        } else {
          history['completed_end'] = 1;
        }
        history['score'] = (history['score'] as int) + 10;
        await DatabaseHelper.instance.updateRoutineHistory(history);
      }
    }
    
    if (mounted) Navigator.pop(context);
  }

  void _dismiss() {
    FlutterRingtonePlayer().stop();
    _ringTimer?.cancel();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    FlutterRingtonePlayer().stop();
    _ringTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (routine == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.black87,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.alarm, size: 100, color: Colors.white),
            const SizedBox(height: 32),
            Text(
              widget.alarmType == 1 ? "Start Routine!" : "Routine Finished!",
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 16),
            Text(
              routine!['title'],
              style: const TextStyle(fontSize: 24, color: Colors.white70),
            ),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  onPressed: _dismiss,
                  child: const Text('Dismiss', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  onPressed: _markDone,
                  child: const Text('Done', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
