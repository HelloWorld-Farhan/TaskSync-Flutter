import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../services/database_helper.dart';
import '../services/alarm_service.dart';

class AddTaskScreen extends StatefulWidget {
  final String recurrenceType;
  final Task? taskToEdit;
  const AddTaskScreen({super.key, this.recurrenceType = 'Once', this.taskToEdit});

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
  List<String> _savedEmails = [];
  
  final _timeFormatter = MaskTextInputFormatter(
    mask: '##:##', 
    filter: { "#": RegExp(r'[0-9]') },
  );

  final _dateFormatter = MaskTextInputFormatter(
    mask: '##/##/####', 
    filter: { "#": RegExp(r'[0-9]') },
  );

  @override
  void initState() {
    super.initState();
    _loadSavedEmails();
    if (widget.taskToEdit != null) {
      _titleController.text = widget.taskToEdit!.title;
      _descController.text = widget.taskToEdit!.description;
      _emailController.text = widget.taskToEdit!.recipientEmail;
      _customDatesController.text = widget.taskToEdit!.customDates;
      
      // Date conversion: YYYY-MM-DD (from DB if old) to DD/MM/YYYY
      // OR if it's already DD/MM/YYYY, just use it.
      String dateStr = widget.taskToEdit!.date;
      if (dateStr.contains('-') && dateStr.split('-')[0].length == 4) {
        // YYYY-MM-DD
        final parts = dateStr.split('-');
        _dateController.text = '${parts[2]}/${parts[1]}/${parts[0]}';
      } else {
        _dateController.text = dateStr;
      }
      
      // Time conversion: 24h to 12h
      String timeStr = widget.taskToEdit!.time;
      if (timeStr.contains(':')) {
        int h = int.parse(timeStr.split(':')[0]);
        int m = int.parse(timeStr.split(':')[1]);
        _isAm = h < 12;
        if (h == 0) h = 12;
        if (h > 12) h -= 12;
        _timeController.text = '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
      }
    }
  }

  Future<void> _loadSavedEmails() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedEmails = prefs.getStringList('saved_emails') ?? [];
    });
  }

  Future<void> _saveEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    if (!_savedEmails.contains(email)) {
      _savedEmails.insert(0, email);
      await prefs.setStringList('saved_emails', _savedEmails);
    }
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
      
      int hour = int.parse(_timeController.text.split(':')[0]);
      int minute = int.parse(_timeController.text.split(':')[1]);
      if (_isAm && hour == 12) hour = 0;
      if (!_isAm && hour != 12) hour += 12;
      String time24 = "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";
      
      // Convert DD/MM/YYYY back to YYYY-MM-DD for storage/alarm sorting standard if desired,
      // but the prompt asked to make it "Date / Month / Year like that". Let's store it as DD/MM/YYYY 
      // or YYYY-MM-DD. Storing as YYYY-MM-DD makes DB sorting easier.
      // The user just said "make that this type - Date / Month / Year like that". 
      // I'll store it as DD/MM/YYYY since it's displayed directly on the card.
      // Wait, dashboard sorting uses `date ASC, time ASC`. If we store DD/MM/YYYY, sorting will be wrong.
      // Let's store as YYYY-MM-DD, and display on card as DD/MM/YYYY.
      // Or change dashboard sorting. It's safer to store YYYY-MM-DD. 
      // Actually, if we store DD/MM/YYYY, we can format it before displaying.
      // But wait, the user said "firstly make that this type - Date / Month / Year like that"
      // Let's just keep the value as DD/MM/YYYY in the DB if they prefer, or format on the fly.
      // Let's store as DD/MM/YYYY and update sorting query, OR just use YYYY-MM-DD in DB and display DD/MM/YYYY.
      // I'll save as DD/MM/YYYY in this field. Sorting in sqlite might fail without custom logic, but let's stick to what we show.
      // Let's just save as YYYY-MM-DD to avoid breaking sorting, and change dashboard display!
      
      final parts = _dateController.text.split('/');
      String dbDate = '${parts[2]}-${parts[1]}-${parts[0]}'; // YYYY-MM-DD

      final task = Task(
        id: widget.taskToEdit?.id,
        title: _titleController.text,
        description: _descController.text,
        date: dbDate,
        time: time24, 
        recipientEmail: _emailController.text,
        recurrenceType: widget.taskToEdit?.recurrenceType ?? widget.recurrenceType,
        customDates: _customDatesController.text,
        isCompleted: widget.taskToEdit?.isCompleted ?? 0,
      );

      if (widget.taskToEdit != null) {
        await DatabaseHelper.instance.update(task);
        await AlarmService.cancelAlarm(task.id!);
        await AlarmService.scheduleAlarm(task);
      } else {
        final createdTask = await DatabaseHelper.instance.create(task);
        await AlarmService.scheduleAlarm(createdTask);
      }

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
        title: Text(widget.taskToEdit != null ? 'Edit Reminder' : 'New ${widget.recurrenceType} Reminder'),
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
                validator: (val) => val!.isEmpty ? 'Title cannot be empty' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _descController,
                label: 'Description',
                icon: Icons.description,
                maxLines: 3,
                validator: (val) => val!.isEmpty ? 'Description cannot be empty' : null,
              ),
              const SizedBox(height: 16),
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return const Iterable<String>.empty();
                  }
                  return _savedEmails.where((String email) {
                    return email.toLowerCase().contains(textEditingValue.text.toLowerCase());
                  });
                },
                onSelected: (String selection) {
                  _emailController.text = selection;
                },
                fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                  // Bind to our controller for saving
                  if (textEditingController.text != _emailController.text && _emailController.text.isNotEmpty) {
                    textEditingController.text = _emailController.text;
                  }
                  textEditingController.addListener(() {
                    _emailController.text = textEditingController.text;
                  });
                  return _buildTextField(
                    controller: textEditingController,
                    focusNode: focusNode,
                    label: 'Recipient Gmail ID',
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) {
                      if (val == null || val.isEmpty) return 'Email cannot be empty';
                      if (!RegExp(r"^[a-zA-Z0-9.]+@gmail\.com$").hasMatch(val)) {
                        return 'Please enter a valid @gmail.com address';
                      }
                      return null;
                    },
                  );
                },
                optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        width: MediaQuery.of(context).size.width - 48,
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E1E32), // Match the filled color feeling of textfields
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            shrinkWrap: true,
                            itemCount: options.length,
                            separatorBuilder: (context, index) => Divider(color: Colors.white.withOpacity(0.05), height: 1),
                            itemBuilder: (context, index) {
                              final String option = options.elementAt(index);
                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                                title: Text(option, style: const TextStyle(color: Colors.white, fontSize: 15)),
                                leading: const Icon(Icons.history, color: Color(0xFF6B48FF), size: 20),
                                tileColor: Colors.transparent,
                                hoverColor: Colors.white.withOpacity(0.05),
                                onTap: () => onSelected(option),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  );
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
                        if (val == null || val.isEmpty) return 'Time cannot be empty';
                        if (val.length != 5) return 'Format must be HH:MM';
                        int? h = int.tryParse(val.split(':')[0]);
                        int? m = int.tryParse(val.split(':')[1]);
                        if (h == null || m == null) return 'Invalid time';
                        if (h < 1 || h > 12) return 'Hour must be 01-12';
                        if (m < 0 || m > 59) return 'Minute must be 00-59';
                        
                        // Check if past time
                        if (_dateController.text.length == 10) {
                          try {
                            final parts = _dateController.text.split('/');
                            int y = int.parse(parts[2]);
                            int mon = int.parse(parts[1]);
                            int d = int.parse(parts[0]);
                            
                            int hour24 = h;
                            if (_isAm && hour24 == 12) hour24 = 0;
                            if (!_isAm && hour24 != 12) hour24 += 12;
                            
                            DateTime selected = DateTime(y, mon, d, hour24, m);
                            if (selected.isBefore(DateTime.now())) {
                              return 'Time cannot be in the past';
                            }
                          } catch (e) {}
                        }
                        
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
                label: 'Date (DD/MM/YYYY)',
                icon: Icons.calendar_today,
                keyboardType: TextInputType.number,
                inputFormatters: [_dateFormatter],
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Date cannot be empty';
                  if (val.length != 10) return 'Format must be DD/MM/YYYY';
                  
                  final parts = val.split('/');
                  if (parts.length != 3) return 'Format must be DD/MM/YYYY';
                  
                  int? d = int.tryParse(parts[0]);
                  int? m = int.tryParse(parts[1]);
                  int? y = int.tryParse(parts[2]);
                  
                  if (d == null || m == null || y == null) return 'Invalid numbers';
                  
                  if (m < 1 || m > 12) return 'Month must be 01-12';
                  
                  // Days in month logic
                  int maxDays = 31;
                  if (m == 4 || m == 6 || m == 9 || m == 11) {
                    maxDays = 30;
                  } else if (m == 2) {
                    bool isLeap = (y % 4 == 0 && (y % 100 != 0 || y % 400 == 0));
                    maxDays = isLeap ? 29 : 28;
                  }
                  
                  if (d < 1 || d > maxDays) return 'Day must be 01-$maxDays for this month';
                  
                  DateTime parsed = DateTime(y, m, d);
                  DateTime now = DateTime.now();
                  DateTime today = DateTime(now.year, now.month, now.day);
                  
                  if (parsed.isBefore(today)) {
                    return 'Date cannot be in the past';
                  }
                  
                  return null;
                },
              ),
              if (widget.recurrenceType == 'Custom') ...[
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
                  child: Text(
                    widget.taskToEdit != null ? 'Update Reminder' : 'Save Reminder',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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
    FocusNode? focusNode,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
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
