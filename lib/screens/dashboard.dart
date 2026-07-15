import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/task.dart';
import '../services/database_helper.dart';
import 'add_task.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<Task>> tasksFuture;

  @override
  void initState() {
    super.initState();
    _refreshTasks();
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
    await DatabaseHelper.instance.delete(id);
    _refreshTasks();
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
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const AddTaskScreen()),
          );
          if (result == true) {
            _refreshTasks();
          }
        },
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
        leading: GestureDetector(
          onTap: () => _toggleTaskStatus(task),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDone ? const Color(0xFF00C853) : Colors.transparent,
              border: Border.all(
                color: isDone ? const Color(0xFF00C853) : Colors.white54,
                width: 2,
              ),
            ),
            child: isDone
                ? const Icon(Icons.check, size: 18, color: Colors.white)
                : null,
          ),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            decoration: isDone ? TextDecoration.lineThrough : null,
            color: isDone ? Colors.white54 : Colors.white,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6.0),
          child: Row(
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
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
          onPressed: () => _deleteTask(task.id!),
        ),
      ),
    ).animate().fade(delay: (100 * index).ms).slideX(begin: 0.2, end: 0);
  }
}
