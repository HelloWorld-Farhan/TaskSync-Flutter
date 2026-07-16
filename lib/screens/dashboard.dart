import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';
import '../models/task.dart';
import '../services/database_helper.dart';
import '../services/alarm_service.dart';
import 'add_task.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<Task>> tasksFuture;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _refreshTasks();
    // Refresh every minute to update status when background email sends
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        _refreshTasks();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _refreshTasks() {
    setState(() {
      tasksFuture = DatabaseHelper.instance.readAllTasks();
    });
  }

  Future<void> _toggleTaskStatus(Task task) async {
    task.isCompleted = task.isCompleted == 1 ? 0 : 1;
    await DatabaseHelper.instance.update(task);
    _refreshTasks();
  }

  Future<void> _deleteTask(int id) async {
    await AlarmService.cancelAlarm(id);
    await DatabaseHelper.instance.delete(id);
    _refreshTasks();
  }
  
  Future<void> _cancelTask(Task task) async {
    await AlarmService.cancelAlarm(task.id!);
    task.isCompleted = 2; // 2 = Cancelled
    await DatabaseHelper.instance.update(task);
    _refreshTasks();
  }

  void _confirmCancelTask(Task task) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF24243E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Cancel Reminder?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text(
            'Are you sure you want to permanently cancel this reminder?\n\nTitle: ${task.title}\nDate: ${task.date}\nTime: ${task.time}',
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('No, keep it', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () {
                Navigator.pop(context); // Close confirm
                Navigator.pop(context); // Close details modal
                _cancelTask(task);
              },
              child: const Text('Yes, Cancel', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showRecurrenceSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF24243E),
            borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Make Reminder For', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              _buildRecurrenceOption('Once', Icons.looks_one),
              _buildRecurrenceOption('Daily', Icons.repeat),
              _buildRecurrenceOption('Custom', Icons.date_range),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecurrenceOption(String title, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: const Color(0xFF6B48FF)),
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18)),
      onTap: () async {
        Navigator.pop(context); // Close bottom sheet
        final result = await Navigator.of(context).push(
          MaterialPageRoute(builder: (context) => AddTaskScreen(recurrenceType: title)),
        );
        if (result == true) {
          _refreshTasks();
        }
      },
    );
  }

  void _showTaskDetails(Task task) {
    bool isCancelled = task.isCompleted == 2;
    bool isDone = task.isCompleted == 1;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF24243E),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          title: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF6B48FF), size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  task.title, 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22)
                ),
              ),
            ],
          ),
          contentPadding: const EdgeInsets.all(24),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _detailRow('Description', task.description, Icons.description),
                _detailRow('Email', task.recipientEmail, Icons.email),
                _detailRow('Date', task.date, Icons.calendar_today),
                _detailRow('Time', task.time, Icons.access_time),
                _detailRow('Recurrence', task.recurrenceType, Icons.repeat),
                if (task.recurrenceType == 'Custom') _detailRow('Custom Dates', task.customDates, Icons.date_range),
                
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      isCancelled ? Icons.cancel : (isDone ? Icons.check_circle : Icons.pending_actions),
                      color: isCancelled ? Colors.redAccent : (isDone ? const Color(0xFF00C853) : Colors.orangeAccent),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isCancelled ? 'Status: Cancelled' : (isDone ? 'Status: Completed' : 'Status: On Process'),
                      style: TextStyle(
                        color: isCancelled ? Colors.redAccent : (isDone ? const Color(0xFF00C853) : Colors.orangeAccent),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          actions: [
            if (task.isCompleted == 0)
              TextButton.icon(
                icon: const Icon(Icons.cancel, color: Colors.redAccent, size: 18),
                onPressed: () => _confirmCancelTask(task),
                label: const Text('Cancel Reminder', style: TextStyle(color: Colors.redAccent)),
              ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6B48FF),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Widget _detailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white38, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value.isNotEmpty ? value : 'N/A', style: const TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'My Schedule',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<List<Task>>(
            future: tasksFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Colors.white));
              } else if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyState();
              }

              final tasks = snapshot.data!;
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: tasks.length,
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  return _buildTaskCard(task, index);
                },
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showRecurrenceSelector,
        backgroundColor: const Color(0xFF6B48FF),
        child: const Icon(Icons.add, color: Colors.white),
      ).animate().scale(delay: 500.ms, curve: Curves.elasticOut),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_rounded, size: 80, color: Colors.white.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            'Your day is clear!',
            style: TextStyle(fontSize: 20, color: Colors.white.withOpacity(0.6)),
          ),
        ],
      ).animate().fade().scale(),
    );
  }

  Widget _buildTaskCard(Task task, int index) {
    bool isDone = task.isCompleted == 1;
    bool isCancelled = task.isCompleted == 2;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        onTap: () => _showTaskDetails(task),
        leading: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isCancelled ? Colors.redAccent : (isDone ? const Color(0xFF00C853) : Colors.transparent),
            border: Border.all(
              color: isCancelled ? Colors.redAccent : (isDone ? const Color(0xFF00C853) : Colors.white54),
              width: 2,
            ),
          ),
          child: isCancelled 
            ? const Icon(Icons.close, size: 18, color: Colors.white)
            : (isDone ? const Icon(Icons.check, size: 18, color: Colors.white) : null),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            decoration: isCancelled || isDone ? TextDecoration.lineThrough : null,
            color: isCancelled ? Colors.redAccent.withOpacity(0.8) : (isDone ? Colors.white54 : Colors.white),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.white.withOpacity(0.5)),
                  const SizedBox(width: 4),
                  Text(
                    task.date,
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.access_time, size: 14, color: Colors.white.withOpacity(0.5)),
                  const SizedBox(width: 4),
                  Text(
                    task.time,
                    style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(
                    isCancelled ? Icons.cancel : (isDone ? Icons.check_circle_outline : Icons.pending_actions),
                    size: 14,
                    color: isCancelled ? Colors.redAccent : (isDone ? const Color(0xFF00C853) : Colors.orangeAccent),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isCancelled ? "Cancelled" : (isDone ? "Completed" : "On Process"),
                    style: TextStyle(
                      color: isCancelled ? Colors.redAccent : (isDone ? const Color(0xFF00C853) : Colors.orangeAccent),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      task.recurrenceType,
                      style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          onPressed: () => _deleteTask(task.id!),
        ),
      ),
    ).animate().fade(delay: (100 * index).ms).slideX(begin: 0.2, end: 0);
  }
}
