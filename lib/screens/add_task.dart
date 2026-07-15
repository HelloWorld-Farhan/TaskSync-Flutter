import 'package:flutter/material.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../services/database_helper.dart';
import '../services/alarm_service.dart';

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
  final _emailController = TextEditingController();
  final _customDatesController = TextEditingController();
  
  bool _isAm = true;
  String _recurrenceType = 'Once';
  
  final _timeFormatter = MaskTextInputFormatter(
    mask: '##:##', 
    filter: { "#": RegExp(r'[0-9]') },
  );

  final _dateFormatter = MaskTextInputFormatter(
    mask: '####-##-##', 
    filter: { "#": RegExp(r'[0-9]') },
  );

  @override
  void initState() {
    super.initState();
    _loadSavedEmail();
  }

  Future<void> _loadSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final savedEmail = prefs.getString('saved_email');
    if (savedEmail != null) {
      setState(() {
        _emailController.text = savedEmail;
      });
    }
  }

  Future<void> _saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_email', email);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _emailController.dispose();
    _customDatesController.dispose();
    super.dispose();
  }

  Future<void> _saveTask() async {
    if (_formKey.currentState!.validate()) {
      await _saveEmail(_emailController.text);
      
      String finalTime = "${_timeController.text} ${_isAm ? 'AM' : 'PM'}";
      // Convert to 24-hour for the background service parser
      int hour = int.parse(_timeController.text.split(':')[0]);
      int minute = int.parse(_timeController.text.split(':')[1]);
      if (_isAm && hour == 12) hour = 0;
      if (!_isAm && hour != 12) hour += 12;
      String time24 = "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";
      
      final task = Task(
        title: _titleController.text,
        description: _descController.text,
        date: _dateController.text,
        time: time24, // Save as HH:MM 24-hour for easier parsing later
        recipientEmail: _emailController.text,
        recurrenceType: _recurrenceType,
        customDates: _customDatesController.text,
      );

      final createdTask = await DatabaseHelper.instance.create(task);
      await AlarmService.scheduleAlarm(createdTask);

      if (mounted) {
        Navigator.of(context).pop(true);
      }
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
                validator: (val) => val!.isEmpty ? 'This field cannot be empty' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _descController,
                label: 'Description',
                icon: Icons.description,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _emailController,
                label: 'Recipient Gmail ID',
                icon: Icons.email,
                keyboardType: TextInputType.emailAddress,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'This field cannot be empty';
                  if (!RegExp(r"^[a-zA-Z0-9.]+@gmail\.com").hasMatch(val)) {
                    return 'Please enter a valid @gmail.com address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _buildTextField(
                      controller: _timeController,
                      label: 'Time (HH:MM)',
                      icon: Icons.access_time,
                      keyboardType: TextInputType.number,
                      inputFormatters: [_timeFormatter],
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'This field cannot be empty';
                        if (val.length != 5) return 'Invalid time format';
                        return null;
                      },
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
              const SizedBox(height: 16),
              _buildTextField(
                controller: _dateController,
                label: 'Date (YYYY-MM-DD)',
                icon: Icons.calendar_today,
                keyboardType: TextInputType.number,
                inputFormatters: [_dateFormatter],
                validator: (val) {
                  if (val == null || val.isEmpty) return 'This field cannot be empty';
                  if (val.length != 10) return 'Invalid date format';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _recurrenceType,
                dropdownColor: const Color(0xFF231F4C),
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Recurrence',
                  labelStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  prefixIcon: const Icon(Icons.repeat, color: Color(0xFF6B48FF)),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white.withOpacity(0.1))),
                ),
                items: ['Once', 'Daily', 'Custom'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() {
                    _recurrenceType = newValue!;
                  });
                },
              ),
              if (_recurrenceType == 'Custom') ...[
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _customDatesController,
                  label: 'Custom Dates (YYYY-MM-DD, ...)',
                  icon: Icons.date_range,
                  validator: (val) => val!.isEmpty ? 'Enter at least one date' : null,
                ),
              ],
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
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
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
        errorStyle: const TextStyle(color: Colors.redAccent),
      ),
    );
  }
}
