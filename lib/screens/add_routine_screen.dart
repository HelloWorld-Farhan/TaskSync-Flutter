import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';
import '../services/alarm_service.dart';
import '../theme/app_theme.dart';

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

  // Real-time error tracking
  String? _titleError;
  String? _descError;
  String? _daysError;
  String? _timeError;

  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  final List<String> _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final Set<String> _selectedDays = {};
  bool _isSaving = false;

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
      _selectedDays.addAll(daysList.map((d) => d.trim()));
    }

    // Real-time title validation
    _titleController.addListener(() {
      final val = _titleController.text.trim();
      String? err;
      if (val.isEmpty) err = 'Title is required';
      else if (val.length < 3) err = 'Title must be at least 3 characters';
      else if (val.length > 50) err = 'Title must be at most 50 characters';
      if (err != _titleError) setState(() => _titleError = err);
    });

    // Real-time desc validation
    _descController.addListener(() {
      final val = _descController.text.trim();
      String? err;
      if (val.isEmpty) err = 'Description is required';
      else if (val.length > 200) err = 'Max 200 characters';
      if (err != _descError) setState(() => _descError = err);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _selectTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.accent,
            surface: AppColors.bgCard,
            onSurface: AppColors.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
        _validateTimes();
      });
    }
  }

  void _validateTimes() {
    if (_startTime != null && _endTime != null) {
      final start = _startTime!.hour * 60 + _startTime!.minute;
      final end = _endTime!.hour * 60 + _endTime!.minute;
      if (end <= start) {
        setState(() => _timeError = 'End time must be after start time');
      } else {
        setState(() => _timeError = null);
      }
    } else {
      setState(() => _timeError = null);
    }
  }

  void _validateDays() {
    setState(() {
      _daysError = _selectedDays.isEmpty ? 'Select at least one day' : null;
    });
  }

  bool _hasErrors() {
    final title = _titleController.text.trim();
    final desc = _descController.text.trim();
    return title.isEmpty || title.length < 3 || title.length > 50 ||
        desc.isEmpty || desc.length > 200 ||
        _selectedDays.isEmpty ||
        _startTime == null || _endTime == null ||
        _timeError != null;
  }

  Future<void> _saveRoutine() async {
    // Trigger full validation
    final title = _titleController.text.trim();
    final desc = _descController.text.trim();
    bool hasError = false;

    if (title.isEmpty) { setState(() => _titleError = 'Title is required'); hasError = true; }
    else if (title.length < 3) { setState(() => _titleError = 'At least 3 characters'); hasError = true; }

    if (desc.isEmpty) { setState(() => _descError = 'Description is required'); hasError = true; }

    if (_selectedDays.isEmpty) { setState(() => _daysError = 'Select at least one day'); hasError = true; }

    if (_startTime == null || _endTime == null) {
      setState(() => _timeError = 'Please select both start and end time');
      hasError = true;
    } else {
      _validateTimes();
      if (_timeError != null) hasError = true;
    }

    if (hasError) return;

    setState(() => _isSaving = true);

    try {
      String startTimeStr = '${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}';
      String endTimeStr = '${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}';

      final Map<String, dynamic> routineData = {
        'title': title,
        'description': desc,
        'days_of_week': _selectedDays.toList().join(','),
        'start_time': startTimeStr,
        'end_time': endTimeStr,
      };

      if (widget.existingRoutine == null) {
        int id = await DatabaseHelper.instance.createRoutine(routineData);
        routineData['id'] = id;
        await AlarmService.scheduleRoutineAlarm(routineData);
      } else {
        routineData['id'] = widget.existingRoutine!['id'] as int;
        await DatabaseHelper.instance.updateRoutine(routineData);
        await AlarmService.cancelRoutineAlarm(routineData['id'] as int);
        await AlarmService.scheduleRoutineAlarm(routineData);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(children: [
            const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(widget.existingRoutine == null ? 'Routine created!' : 'Routine updated!'),
          ]),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingRoutine != null;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgMid,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEditing ? 'Edit Routine' : 'New Daily Routine',
          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Header
            Container(
              margin: const EdgeInsets.only(bottom: 28),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 16, spreadRadius: 1)],
              ),
              child: Row(children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
                  child: const Icon(Icons.loop_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Daily Routine', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                  SizedBox(height: 4),
                  Text('Set your weekly recurring schedule', style: TextStyle(color: Colors.white70, fontSize: 13)),
                ])),
              ]),
            ),

            // Title field
            _sectionLabel('Routine Title', Icons.title_rounded),
            const SizedBox(height: 8),
            _styledField(
              controller: _titleController,
              hint: 'e.g. Morning Workout',
              icon: Icons.title_rounded,
              error: _titleError,
            ),
            if (_titleError != null) _errorText(_titleError!),

            const SizedBox(height: 20),

            // Description field
            _sectionLabel('Description', Icons.description_outlined),
            const SizedBox(height: 8),
            _styledField(
              controller: _descController,
              hint: 'e.g. 30 min jog + stretching',
              icon: Icons.description_outlined,
              maxLines: 3,
              error: _descError,
            ),
            if (_descError != null) _errorText(_descError!),

            const SizedBox(height: 24),

            // Days selection
            _sectionLabel('Active Days', Icons.calendar_month_rounded),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _daysError != null ? AppColors.danger : AppColors.border, width: 1.5),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _days.map((day) {
                  final isSelected = _selectedDays.contains(day);
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        if (isSelected) _selectedDays.remove(day);
                        else _selectedDays.add(day);
                      });
                      _validateDays();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: isSelected ? AppColors.primaryGradient : null,
                        color: isSelected ? null : AppColors.bgDeep,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isSelected ? AppColors.primary : AppColors.border, width: 1.5),
                      ),
                      child: Text(
                        day,
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textMuted,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            if (_daysError != null) _errorText(_daysError!),

            const SizedBox(height: 24),

            // Time pickers
            _sectionLabel('Routine Time', Icons.access_time_rounded),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _timePicker(
                label: 'Start Time',
                time: _startTime,
                icon: Icons.play_arrow_rounded,
                color: AppColors.success,
                onTap: () => _selectTime(true),
              )),
              const SizedBox(width: 12),
              Expanded(child: _timePicker(
                label: 'End Time',
                time: _endTime,
                icon: Icons.stop_rounded,
                color: AppColors.danger,
                onTap: () => _selectTime(false),
              )),
            ]),
            if (_timeError != null) _errorText(_timeError!),

            const SizedBox(height: 36),

            // Save button
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveRoutine,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _hasErrors() && !_isSaving ? AppColors.bgCard : AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  elevation: 0,
                ),
                child: _isSaving
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(isEditing ? Icons.save_rounded : Icons.add_circle_rounded, size: 20),
                        const SizedBox(width: 8),
                        Text(isEditing ? 'Save Changes' : 'Create Routine',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                      ]),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text, IconData icon) {
    return Row(children: [
      Icon(icon, size: 15, color: AppColors.accentLight),
      const SizedBox(width: 7),
      Text(text, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 13)),
    ]);
  }

  Widget _errorText(String msg) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 4),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, size: 13, color: AppColors.dangerGlow),
        const SizedBox(width: 5),
        Text(msg, style: const TextStyle(color: AppColors.dangerGlow, fontSize: 12)),
      ]),
    );
  }

  Widget _styledField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? error,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: error != null ? AppColors.danger : AppColors.border, width: 1.5),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 14, right: 10),
            child: Icon(icon, color: AppColors.accentLight, size: 20),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: maxLines > 1 ? 16 : 18),
        ),
      ),
    );
  }

  Widget _timePicker({
    required String label,
    required TimeOfDay? time,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: time != null ? color.withValues(alpha: 0.4) : AppColors.border, width: 1.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
          ]),
          const SizedBox(height: 6),
          Text(
            time != null
                ? '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}'
                : 'Tap to set',
            style: TextStyle(
              color: time != null ? AppColors.textPrimary : AppColors.textMuted,
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ]),
      ),
    );
  }
}
