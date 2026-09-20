import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../services/alarm_service.dart';
import 'package:intl/intl.dart';

class AddRoutineScreen extends StatefulWidget {
  final Map<String, dynamic>? existingRoutine;
  const AddRoutineScreen({super.key, this.existingRoutine});

  @override
  State<AddRoutineScreen> createState() => _AddRoutineScreenState();
}

class _AddRoutineScreenState extends State<AddRoutineScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final Set<String> _selectedDays = {};

  @override
  void initState() {
    super.initState();
    if (widget.existingRoutine != null) {
      _titleController.text = widget.existingRoutine!['title'];
      _descController.text = widget.existingRoutine!['description'];
      
      final startParts = widget.existingRoutine!['start_time'].split(':');
      _startTime = TimeOfDay(hour: int.parse(startParts[0]), minute: int.parse(startParts[1]));
      
      final endParts = widget.existingRoutine!['end_time'].split(':');
      _endTime = TimeOfDay(hour: int.parse(endParts[0]), minute: int.parse(endParts[1]));

      final daysList = widget.existingRoutine!['days_of_week'].split(',');
      _selectedDays.addAll(daysList);
    }
  }

  Future<void> _selectTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) _startTime = picked;
        else _endTime = picked;
      });
    }
  }

  Future<void> _saveRoutine() async {
    if (_formKey.currentState!.validate()) {
      if (_startTime == null || _endTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select start and end time')));
        return;
      }
      if (_selectedDays.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select at least one day')));
        return;
      }

      String startTimeStr = '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}';
      String endTimeStr = '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}';

      Map<String, dynamic> routineData = {
        'title': _titleController.text,
        'description': _descController.text,
        'days_of_week': _selectedDays.toList().join(','),
        'start_time': startTimeStr,
        'end_time': endTimeStr,
      };

      if (widget.existingRoutine == null) {
        int id = await DatabaseHelper.instance.createRoutine(routineData);
        routineData['id'] = id;
        await AlarmService.scheduleRoutineAlarm(routineData);
      } else {
        routineData['id'] = widget.existingRoutine!['id'];
        await DatabaseHelper.instance.updateRoutine(routineData);
        await AlarmService.cancelRoutineAlarm(routineData['id']);
        await AlarmService.scheduleRoutineAlarm(routineData);
      }

      if (mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existingRoutine == null ? 'New Routine' : 'Edit Routine'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title', border: OutlineInputBorder()),
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
              maxLines: 3,
              validator: (v) => v!.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 24),
            const Text('Select Days', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _days.map((day) {
                final isSelected = _selectedDays.contains(day);
                return FilterChip(
                  label: Text(day),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) _selectedDays.add(day);
                      else _selectedDays.remove(day);
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectTime(true),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'Start Time', border: OutlineInputBorder()),
                      child: Text(_startTime?.format(context) ?? 'Select Time'),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectTime(false),
                    child: InputDecorator(
                      decoration: const InputDecoration(labelText: 'End Time', border: OutlineInputBorder()),
                      child: Text(_endTime?.format(context) ?? 'Select Time'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _saveRoutine,
              child: const Text('Save Routine', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }
}
