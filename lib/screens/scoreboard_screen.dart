import 'package:flutter/material.dart';
import '../services/database_helper.dart';

class ScoreboardScreen extends StatefulWidget {
  const ScoreboardScreen({super.key});

  @override
  State<ScoreboardScreen> createState() => _ScoreboardScreenState();
}

class _ScoreboardScreenState extends State<ScoreboardScreen> {
  List<Map<String, dynamic>> routines = [];
  Map<int, int> scores = {};
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadScores();
  }

  Future<void> _loadScores() async {
    final dbRoutines = await DatabaseHelper.instance.readAllRoutines();
    Map<int, int> calcScores = {};

    for (var r in dbRoutines) {
      int id = r['id'];
      final history = await DatabaseHelper.instance.readRoutineHistory(id);
      int totalScore = 0;
      for (var h in history) {
        totalScore += (h['score'] as int);
      }
      calcScores[id] = totalScore;
    }

    setState(() {
      routines = dbRoutines;
      scores = calcScores;
      // Sort routines by score descending
      routines.sort((a, b) => (scores[b['id']] ?? 0).compareTo(scores[a['id']] ?? 0));
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scoreboard')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : routines.isEmpty
              ? const Center(child: Text('No routines to score yet!'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: routines.length,
                  itemBuilder: (context, index) {
                    final routine = routines[index];
                    final score = scores[routine['id']] ?? 0;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(routine['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: Text(
                          '$score pts',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
