class Routine {
  int? id;
  String title;
  String description;
  String daysOfWeek; // e.g. "Mon,Tue,Wed"
  String startTime;
  String endTime;

  Routine({
    this.id,
    required this.title,
    required this.description,
    required this.daysOfWeek,
    required this.startTime,
    required this.endTime,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'days_of_week': daysOfWeek,
      'start_time': startTime,
      'end_time': endTime,
    };
  }

  factory Routine.fromMap(Map<String, dynamic> map) {
    return Routine(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      daysOfWeek: map['days_of_week'],
      startTime: map['start_time'],
      endTime: map['end_time'],
    );
  }
}
