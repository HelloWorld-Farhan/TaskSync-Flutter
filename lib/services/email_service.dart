import 'dart:convert';
import 'package:http/http.dart' as http;

class EmailService {
  // Replace this with the actual Google Apps Script Web App URL after deployment
  static const String _scriptUrl = "https://script.google.com/macros/s/AKfycbz5WfPBqEDFcWk7MGqJUoZFn0-D1OS0I4ijv1KhToJNOIOXwlDM9wlHncA56sWN2RBN/exec";

  static Future<void> scheduleEmail({
    required String email,
    required String title,
    required String description,
    required DateTime scheduledTime,
  }) async {
    if (_scriptUrl.contains("YOUR_GOOGLE_APPS_SCRIPT_URL")) {
      print("Warning: Google Apps Script URL not set. Email will not be scheduled.");
      return;
    }

    try {
      final response = await http.post(
        Uri.parse(_scriptUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "subject": "TaskSync Reminder: $title",
          "body": "Hi there! This is your scheduled reminder for: $title.\n\nDetails: $description",
          "timestamp": scheduledTime.millisecondsSinceEpoch,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 302) {
        print("Email successfully scheduled!");
      } else {
        print("Failed to schedule email: ${response.body}");
      }
    } catch (e) {
      print("Error scheduling email: $e");
    }
  }
}
