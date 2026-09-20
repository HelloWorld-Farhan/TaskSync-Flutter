import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../theme/app_theme.dart';
import 'add_routine_screen.dart';
import 'routine_detail_screen.dart';
import 'scoreboard_screen.dart';

class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key});

  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  List<Map<String, dynamic>> routines = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadRoutines();
  }

  Future<void> _loadRoutines() async {
    setState(() => isLoading = true);
    final data = await DatabaseHelper.instance.readAllRoutines();
    setState(() {
      routines = data;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Routines', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ScoreboardScreen()),
              );
            },
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : routines.isEmpty
              ? _buildEmptyState()
              : _buildRoutinesList(),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          if (routines.length >= 3) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('You can only create up to 3 routines.')),
            );
            return;
          }
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddRoutineScreen()),
          );
          _loadRoutines();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule, size: 80, color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text('No routines found', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Tap + to create up to 3 daily routines', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildRoutinesList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: routines.length,
      itemBuilder: (context, index) {
        final routine = routines[index];
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(routine['title'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(routine['description']),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 16, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 4),
                    Expanded(child: Text(routine['days_of_week'], style: TextStyle(color: Theme.of(context).colorScheme.primary))),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Theme.of(context).colorScheme.secondary),
                    const SizedBox(width: 4),
                    Text('${routine['start_time']} - ${routine['end_time']}', style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
                  ],
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RoutineDetailScreen(routine: routine),
                ),
              );
              _loadRoutines();
            },
          ),
        );
      },
    );
  }
}
