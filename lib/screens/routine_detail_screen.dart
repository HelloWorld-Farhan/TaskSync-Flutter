import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../services/alarm_service.dart';
import 'add_routine_screen.dart';

class RoutineDetailScreen extends StatefulWidget {
  final Map<String, dynamic> routine;
  const RoutineDetailScreen({super.key, required this.routine});

  @override
  State<RoutineDetailScreen> createState() => _RoutineDetailScreenState();
}

class _RoutineDetailScreenState extends State<RoutineDetailScreen> {
  late Map<String, dynamic> routine;
  List<Map<String, dynamic>> history = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    routine = widget.routine;
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final data = await DatabaseHelper.instance.readRoutineHistory(routine['id']);
    setState(() {
      history = data;
      isLoading = false;
    });
  }

  Future<void> _deleteRoutine() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Routine?'),
        content: const Text('Are you sure you want to delete this routine? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('DELETE', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      final doubleConfirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Final Confirmation'),
          content: const Text('Are you REALLY sure? All history will be lost.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('YES, DELETE', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
          ],
        ),
      );

      if (doubleConfirm == true) {
        await AlarmService.cancelRoutineAlarm(routine['id']);
        await DatabaseHelper.instance.deleteRoutine(routine['id']);
        if (mounted) Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Routine Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => AddRoutineScreen(existingRoutine: routine)),
              );
              // Reload routine data
              final updated = await DatabaseHelper.instance.getRoutine(routine['id']);
              if (updated != null) {
                setState(() => routine = updated);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteRoutine,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(routine['title'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(routine['description'], style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Schedule', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        const Divider(),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 20),
                            const SizedBox(width: 8),
                            Text(routine['days_of_week'], style: const TextStyle(fontSize: 16)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 20),
                            const SizedBox(width: 8),
                            Text('${routine['start_time']} to ${routine['end_time']}', style: const TextStyle(fontSize: 16)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Completion History', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                history.isEmpty
                    ? const Text('No history available yet.')
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: history.length,
                        itemBuilder: (context, index) {
                          final h = history[index];
                          bool completedStart = h['completed_start'] == 1;
                          bool completedEnd = h['completed_end'] == 1;
                          int score = h['score'];
                          return ListTile(
                            title: Text(h['date']),
                            subtitle: Text('Score: $score'),
                            trailing: Icon(
                              completedStart && completedEnd ? Icons.check_circle : Icons.warning,
                              color: completedStart && completedEnd ? Colors.green : Colors.orange,
                            ),
                          );
                        },
                      )
              ],
            ),
    );
  }
}
