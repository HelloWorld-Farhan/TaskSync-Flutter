class RoutineHistory {
  int? id;
  int routineId;
  String date;
  int completedStart;
  int completedEnd;
  int score;

  RoutineHistory({
    this.id,
    required this.routineId,
    required this.date,
    this.completedStart = 0,
    this.completedEnd = 0,
    this.score = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'routine_id': routineId,
      'date': date,
      'completed_start': completedStart,
      'completed_end': completedEnd,
      'score': score,
    };
  }

  factory RoutineHistory.fromMap(Map<String, dynamic> map) {
    return RoutineHistory(
      id: map['id'],
      routineId: map['routine_id'],
      date: map['date'],
      completedStart: map['completed_start'],
      completedEnd: map['completed_end'],
      score: map['score'],
    );
  }
}
