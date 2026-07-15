class Task {
  int? id;
  String title;
  String description;
  String date;
  String time;
  String recipientEmail;
  String recurrenceType;
  String customDates;
  int isCompleted;

  Task({
    this.id,
    required this.title,
    required this.description,
    required this.date,
    required this.time,
    required this.recipientEmail,
    this.recurrenceType = 'Once',
    this.customDates = '',
    this.isCompleted = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'date': date,
      'time': time,
      'recipientEmail': recipientEmail,
      'recurrenceType': recurrenceType,
      'customDates': customDates,
      'isCompleted': isCompleted,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      date: map['date'],
      time: map['time'],
      recipientEmail: map['recipientEmail'] ?? '',
      recurrenceType: map['recurrenceType'] ?? 'Once',
      customDates: map['customDates'] ?? '',
      isCompleted: map['isCompleted'],
    );
  }
}
