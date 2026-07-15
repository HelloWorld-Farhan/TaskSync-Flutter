import 'dart:convert';
import 'package:http/http.dart' as http;

class EmailService {
  // Replace this with the actual Google Apps Script Web App URL after deployment
  static const String _scriptUrl = "https://script.google.com/macros/s/AKfycbxxDUGyhKEYuaRPP2p7aFzaX96wJMFn_fxuf8IcJQ5NODnyXM-57_ib0SsxEbIuSIjJ/exec";

  static Future<void> sendEmailNow({
    required String email,
    required String title,
    required String description,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_scriptUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "email": email,
          "subject": "TaskSync Reminder: $title",
          "body": "Hi there! This is your scheduled reminder for: $title.\n\nDetails: $description",
          "timestamp": DateTime.now().millisecondsSinceEpoch,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 302) {
        print("Email successfully sent!");
      } else {
        print("Failed to send email: ${response.body}");
      }
    } catch (e) {
      print("Error sending email: $e");
    }
  }
}
