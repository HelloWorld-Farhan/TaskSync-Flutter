import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/task.dart';
import '../services/database_helper.dart';
import '../services/email_service.dart';

class AddTaskScreen extends StatefulWidget {
  const AddTaskScreen({super.key});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  
  bool _isAm = true;
  String _userEmail = ""; // In a real app, load this from SharedPreferences

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  void _formatTime(String value) {
    if (value.length == 1 && int.tryParse(value) != null) {
      if (int.parse(value) > 0 && int.parse(value) <= 9) {
        _timeController.text = "0$value:00";
        _timeController.selection = TextSelection.fromPosition(
          TextPosition(offset: _timeController.text.length),
        );
      }
    } else if (value.length == 2 && !value.contains(':')) {
       _timeController.text = "$value:00";
       _timeController.selection = TextSelection.fromPosition(
          TextPosition(offset: _timeController.text.length),
        );
    }
  }

  void _formatDate(String value) {
    // Auto insert slashes for MM/DD/YYYY
    if (value.length == 2 && !value.contains('/')) {
      _dateController.text = "$value/";
      _dateController.selection = TextSelection.fromPosition(
        TextPosition(offset: _dateController.text.length),
      );
    } else if (value.length == 5 && value.split('/').length == 2) {
      _dateController.text = "$value/";
      _dateController.selection = TextSelection.fromPosition(
        TextPosition(offset: _dateController.text.length),
      );
    }
  }

  Future<void> _saveTask() async {
    if (_formKey.currentState!.validate()) {
      String finalTime = "${_timeController.text} ${_isAm ? 'AM' : 'PM'}";
      
      final task = Task(
        title: _titleController.text,
        description: _descController.text,
        date: _dateController.text,
        time: finalTime,
      );

      await DatabaseHelper.instance.create(task);

      // Attempt to schedule an email if an email address is provided (mock setup for now)
      if (_userEmail.isNotEmpty) {
        try {
          // Parse MM/DD/YYYY and HH:MM AM/PM to DateTime (simplified for demo)
          // In production, use intl DateFormat parsing
          EmailService.scheduleEmail(
            email: _userEmail,
            title: task.title,
            description: task.description,
            scheduledTime: DateTime.now().add(const Duration(minutes: 5)), // Demo logic
          );
        } catch (e) {
          print("Could not schedule email: $e");
        }
      }

      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0C29),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('New Reminder'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTextField(
                controller: _titleController,
                label: 'Task Title',
                icon: Icons.title,
                validator: (val) => val!.isEmpty ? 'Enter a title' : null,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _descController,
                label: 'Description',
                icon: Icons.description,
                maxLines: 3,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildTextField(
                      controller: _timeController,
                      label: 'Time (HH:MM)',
                      icon: Icons.access_time,
                      keyboardType: TextInputType.number,
                      onChanged: _formatTime,
                      validator: (val) => val!.isEmpty ? 'Enter time' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 1,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _isAm = !_isAm;
                        });
                      },
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6B48FF).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF6B48FF)),
                        ),
                        child: Center(
                          child: Text(
                            _isAm ? 'AM' : 'PM',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF9D84FF),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _dateController,
                label: 'Date (MM/DD/YYYY)',
                icon: Icons.calendar_today,
                keyboardType: TextInputType.number,
                onChanged: _formatDate,
                validator: (val) => val!.isEmpty ? 'Enter date' : null,
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _saveTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B48FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Save Reminder',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    void Function(String)? onChanged,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      validator: validator,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: const Color(0xFF6B48FF)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF6B48FF)),
        ),
      ),
    );
  }
}
