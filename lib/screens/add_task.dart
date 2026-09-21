import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../services/database_helper.dart';
import '../services/alarm_service.dart';
import '../theme/app_theme.dart';

class AddTaskScreen extends StatefulWidget {
  final String recurrenceType;
  final Task? taskToEdit;

  const AddTaskScreen(
      {super.key, this.recurrenceType = 'Once', this.taskToEdit});

  @override
  State<AddTaskScreen> createState() => _AddTaskScreenState();
}

class _AddTaskScreenState extends State<AddTaskScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  final TextEditingController _customDatesController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  final FocusNode _dateFocusNode = FocusNode();

  bool _isSaving = false;
  late bool _isAm;
  String _dayName = '';
  List<String> _savedEmails = [];

  late AnimationController _saveButtonController;

  final _timeFormatter = MaskTextInputFormatter(
    mask: '##:##',
    filter: {"#": RegExp(r'[0-9]')},
  );
  final _dateFormatter = MaskTextInputFormatter(
    mask: '##/##/####',
    filter: {"#": RegExp(r'[0-9]')},
  );

  @override
  void initState() {
    super.initState();
    _isAm = DateTime.now().hour < 12;
    _saveButtonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadSavedEmails();
    _dateController.addListener(_updateDayName);

    _dateFocusNode.addListener(() {
      if (!_dateFocusNode.hasFocus) {
        String text = _dateController.text.trim();
        if (text.length == 1 || text.length == 2) {
          int? day = int.tryParse(text);
          if (day != null && day >= 1 && day <= 31) {
            DateTime now = DateTime.now();
            String formatted = "${day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
            _dateController.text = formatted;
            _updateDayName();
          }
        }
      }
    });

    if (widget.taskToEdit != null) {
      _titleController.text = widget.taskToEdit!.title;
      _descController.text = widget.taskToEdit!.description;
      _emailController.text = widget.taskToEdit!.recipientEmail;
      _customDatesController.text = widget.taskToEdit!.customDates;

      String dateStr = widget.taskToEdit!.date;
      if (dateStr.contains('-') && dateStr.split('-')[0].length == 4) {
        final parts = dateStr.split('-');
        _dateController.text = '${parts[2]}/${parts[1]}/${parts[0]}';
      } else {
        _dateController.text = dateStr;
      }

      String timeStr = widget.taskToEdit!.time;
      if (timeStr.contains(':')) {
        int h = int.parse(timeStr.split(':')[0]);
        int m = int.parse(timeStr.split(':')[1]);
        _isAm = h < 12;
        if (h == 0) h = 12;
        if (h > 12) h -= 12;
        _timeController.text =
            '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
      }
    }
  }

  Future<void> _loadSavedEmails() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedEmails = prefs.getStringList('saved_emails') ?? [];
    });
  }

  void _updateDayName() {
    String val = _dateController.text;
    if (val.length == 10) {
      final parts = val.split('/');
      if (parts.length == 3) {
        int? d = int.tryParse(parts[0]);
        int? m = int.tryParse(parts[1]);
        int? y = int.tryParse(parts[2]);
        if (d != null && m != null && y != null) {
          try {
            DateTime parsed = DateTime(y, m, d);
            String day = DateFormat('EEEE').format(parsed);
            if (_dayName != day) setState(() => _dayName = day);
            return;
          } catch (_) {}
        }
      }
    }
    if (_dayName.isNotEmpty) setState(() => _dayName = '');
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
    _saveButtonController.dispose();
    _titleController.dispose();
    _descController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _customDatesController.dispose();
    _emailController.dispose();
    _dateFocusNode.dispose();
    super.dispose();
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    await _saveEmail(_emailController.text);

    int hour = int.parse(_timeController.text.split(':')[0]);
    int minute = int.parse(_timeController.text.split(':')[1]);
    if (_isAm && hour == 12) hour = 0;
    if (!_isAm && hour != 12) hour += 12;
    String time24 =
        "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";

    final parts = _dateController.text.split('/');
    String dbDate = '${parts[2]}-${parts[1]}-${parts[0]}';

    final task = Task(
      id: widget.taskToEdit?.id,
      title: _titleController.text,
      description: _descController.text,
      date: dbDate,
      time: time24,
      recipientEmail: _emailController.text,
      recurrenceType:
          widget.taskToEdit?.recurrenceType ?? widget.recurrenceType,
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Row(children: [
          const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(widget.taskToEdit == null ? 'Reminder created!' : 'Reminder updated!'),
        ]),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      Navigator.of(context).pop(true);
    }
  }

  Color _recurrenceColor() {
    switch (widget.recurrenceType) {
      case 'Daily':
        return AppColors.accent;
      case 'Custom':
        return AppColors.warning;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color accentColor = _recurrenceColor();
    final bool isEditing = widget.taskToEdit != null;

    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: Stack(
        children: [
          // Background gradient arc decoration
          Positioned(
            top: -80,
            left: -80,
            right: -80,
            child: Container(
              height: 280,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accentColor.withValues(alpha: 0.18),
                    AppColors.bgDeep.withValues(alpha: 0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(120),
                  bottomRight: Radius.circular(120),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Custom AppBar
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: AppColors.textPrimary, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEditing ? 'Edit Reminder' : 'New Reminder',
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              widget.recurrenceType,
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Type badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 7),
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: accentColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          widget.recurrenceType,
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ).animate().fade(duration: 300.ms).slideY(begin: -0.2, end: 0),

                const SizedBox(height: 16),

                // Form
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Section: Details
                          _sectionLabel('Task Details', Icons.info_outline),
                          const SizedBox(height: 12),

                          _buildField(
                            controller: _titleController,
                            label: 'Task Title',
                            icon: Icons.title_rounded,
                            delay: 100,
                            validator: (val) =>
                                val!.isEmpty ? 'Title cannot be empty' : null,
                          ),
                          const SizedBox(height: 14),

                          _buildField(
                            controller: _descController,
                            label: 'Description',
                            icon: Icons.notes_rounded,
                            maxLines: 3,
                            delay: 150,
                            validator: (val) => val!.isEmpty
                                ? 'Description cannot be empty'
                                : null,
                          ),
                          const SizedBox(height: 22),

                          // Section: Contact
                          _sectionLabel('Send To', Icons.email_outlined),
                          const SizedBox(height: 12),

                          _buildEmailField(delay: 200),
                          const SizedBox(height: 22),

                          // Section: Schedule
                          _sectionLabel('Schedule', Icons.schedule_rounded),
                          const SizedBox(height: 12),

                          // Time + AM/PM row
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: _buildField(
                                  controller: _timeController,
                                  label: 'Time (HH:MM)',
                                  icon: Icons.access_time_rounded,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [_timeFormatter],
                                  delay: 250,
                                  validator: (val) {
                                    if (val == null || val.isEmpty)
                                      return 'Time required';
                                    if (val.length != 5) return 'Use HH:MM';
                                    int? h = int.tryParse(val.split(':')[0]);
                                    int? m = int.tryParse(val.split(':')[1]);
                                    if (h == null || m == null)
                                      return 'Invalid time';
                                    if (h < 1 || h > 12)
                                      return 'Hour: 01-12';
                                    if (m < 0 || m > 59)
                                      return 'Minute: 00-59';
                                    if (_dateController.text.length == 10) {
                                      try {
                                        final dp =
                                            _dateController.text.split('/');
                                        int y = int.parse(dp[2]);
                                        int mon = int.parse(dp[1]);
                                        int d = int.parse(dp[0]);
                                        int h24 = h;
                                        if (_isAm && h24 == 12) h24 = 0;
                                        if (!_isAm && h24 != 12) h24 += 12;
                                        DateTime sel =
                                            DateTime(y, mon, d, h24, m);
                                        if (sel.isBefore(DateTime.now()))
                                          return 'Cannot be in the past';
                                      } catch (_) {}
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              // AM/PM pill toggle
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _isAm = !_isAm),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  curve: Curves.easeInOut,
                                  height: 62,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20),
                                  decoration: BoxDecoration(
                                    gradient: _isAm
                                        ? const LinearGradient(
                                            colors: [
                                              Color(0xFFF59E0B),
                                              Color(0xFFD97706)
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          )
                                        : const LinearGradient(
                                            colors: [
                                              Color(0xFF4F46E5),
                                              Color(0xFF7C3AED)
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (_isAm
                                                ? AppColors.warning
                                                : AppColors.primary)
                                            .withValues(alpha: 0.4),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _isAm
                                            ? Icons.wb_sunny_rounded
                                            : Icons.nights_stay_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _isAm ? 'AM' : 'PM',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ).animate().fade(delay: 250.ms).slideX(begin: 0.1, end: 0),

                          const SizedBox(height: 14),

                          _buildField(
                            controller: _dateController,
                            focusNode: _dateFocusNode,
                            label: 'Date (DD/MM/YYYY)',
                            icon: Icons.calendar_month_rounded,
                            keyboardType: TextInputType.number,
                            inputFormatters: [_dateFormatter],
                            readOnly: true,
                            delay: 300,
                            suffixIcon: Padding(
                              padding: const EdgeInsets.only(right: 8.0, top: 8.0, bottom: 8.0),
                              child: ElevatedButton(
                                onPressed: () {
                                  DateTime tomorrow = DateTime.now().add(const Duration(days: 1));
                                  _dateController.text = "${tomorrow.day.toString().padLeft(2, '0')}/${tomorrow.month.toString().padLeft(2, '0')}/${tomorrow.year}";
                                  _updateDayName();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary.withOpacity(0.2),
                                  foregroundColor: AppColors.primaryGlow,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Tomorrow', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.isEmpty)
                                return 'Date required';
                              if (val.length != 10) return 'Use DD/MM/YYYY';
                              final parts = val.split('/');
                              if (parts.length != 3)
                                return 'Use DD/MM/YYYY';
                              int? d = int.tryParse(parts[0]);
                              int? m = int.tryParse(parts[1]);
                              int? y = int.tryParse(parts[2]);
                              if (d == null || m == null || y == null)
                                return 'Invalid numbers';
                              if (m < 1 || m > 12)
                                return 'Month: 01-12';
                              int maxDays = 31;
                              if (m == 4 || m == 6 || m == 9 || m == 11)
                                maxDays = 30;
                              else if (m == 2) {
                                bool isLeap = (y % 4 == 0 &&
                                    (y % 100 != 0 || y % 400 == 0));
                                maxDays = isLeap ? 29 : 28;
                              }
                              if (d < 1 || d > maxDays)
                                return 'Day: 01-$maxDays for this month';
                              DateTime parsed = DateTime(y, m, d);
                              DateTime today = DateTime(
                                  DateTime.now().year,
                                  DateTime.now().month,
                                  DateTime.now().day);
                              if (parsed.isBefore(today))
                                return 'Date cannot be in the past';
                              return null;
                            },
                          ),

                          // Day name chip
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, anim) =>
                                FadeTransition(
                              opacity: anim,
                              child: SlideTransition(
                                position: Tween<Offset>(
                                  begin: const Offset(0, -0.3),
                                  end: Offset.zero,
                                ).animate(anim),
                                child: child,
                              ),
                            ),
                            child: _dayName.isNotEmpty
                                ? Padding(
                                    key: ValueKey(_dayName),
                                    padding: const EdgeInsets.only(
                                        top: 10, left: 4),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 8),
                                      decoration: BoxDecoration(
                                        gradient: AppColors.primaryGradient,
                                        borderRadius:
                                            BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.primary
                                                .withValues(alpha: 0.3),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                              Icons.event_available_rounded,
                                              color: Colors.white,
                                              size: 14),
                                          const SizedBox(width: 8),
                                          Text(
                                            'It\'s for $_dayName',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : const SizedBox.shrink(key: ValueKey('empty')),
                          ),

                          // 7-day quick select
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: Row(
                                children: List.generate(7, (index) {
                                  DateTime date = DateTime.now().add(Duration(days: index));
                                  bool isToday = index == 0;
                                  String dayLabel = isToday ? 'Today' : DateFormat('EEEE').format(date);
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 10.0),
                                    child: InkWell(
                                      onTap: () {
                                        _dateController.text = "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
                                        _updateDayName();
                                      },
                                      borderRadius: BorderRadius.circular(20),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: AppColors.bgCardAlt,
                                          border: Border.all(color: const Color(0xFF2D3748), width: 1.5),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          dayLabel,
                                          style: const TextStyle(
                                            color: AppColors.textPrimary,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                              ),
                            ).animate().fade(delay: 350.ms).slideX(begin: 0.1, end: 0),
                          ),

                          if (widget.recurrenceType == 'Custom') ...[
                            const SizedBox(height: 14),
                            _buildField(
                              controller: _customDatesController,
                              label: 'Custom Dates (YYYY-MM-DD, ...)',
                              icon: Icons.date_range_rounded,
                              delay: 350,
                              validator: (val) => val!.isEmpty
                                  ? 'Enter at least one date'
                                  : null,
                            ),
                          ],

                          const SizedBox(height: 40),

                          // Save button
                          SizedBox(
                            width: double.infinity,
                            height: 58,
                            child: ElevatedButton(
                              onPressed: _isSaving ? null : _saveTask,
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                              ),
                              child: Ink(
                                decoration: BoxDecoration(
                                  gradient: _isSaving
                                      ? const LinearGradient(
                                          colors: [
                                            Color(0xFF2D3748),
                                            Color(0xFF2D3748),
                                          ],
                                        )
                                      : AppColors.primaryGradient,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: _isSaving
                                      ? []
                                      : [
                                          BoxShadow(
                                            color: AppColors.primary
                                                .withValues(alpha: 0.4),
                                            blurRadius: 16,
                                            offset: const Offset(0, 6),
                                          ),
                                        ],
                                ),
                                child: Container(
                                  alignment: Alignment.center,
                                  child: _isSaving
                                      ? const SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                            strokeWidth: 2.5,
                                          ),
                                        )
                                      : Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              isEditing
                                                  ? Icons.save_rounded
                                                  : Icons.add_alarm_rounded,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              isEditing
                                                  ? 'Update Reminder'
                                                  : 'Save Reminder',
                                              style: const TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ),
                          )
                              .animate()
                              .fade(delay: 400.ms, duration: 400.ms)
                              .slideY(
                                  begin: 0.3,
                                  end: 0,
                                  delay: 400.ms,
                                  duration: 400.ms,
                                  curve: Curves.easeOut),

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primaryGlow, size: 16),
        const SizedBox(width: 8),
        Text(
          text,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(height: 1, color: const Color(0xFF2D3748)),
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    FocusNode? focusNode,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    Widget? suffixIcon,
    int delay = 0,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      validator: validator,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
      decoration: AppTheme.fieldDecoration(label: label, icon: icon, suffixIcon: suffixIcon),
    ).animate().fade(delay: delay.ms, duration: 350.ms).slideX(
        begin: 0.08, end: 0, delay: delay.ms, duration: 350.ms);
  }

  Widget _buildEmailField({int delay = 0}) {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue tv) {
        if (tv.text.isEmpty) return const Iterable<String>.empty();
        return _savedEmails
            .where((e) => e.toLowerCase().contains(tv.text.toLowerCase()));
      },
      onSelected: (s) => _emailController.text = s,
      fieldViewBuilder: (context, textEditingController, focusNode, _) {
        if (textEditingController.text != _emailController.text &&
            _emailController.text.isNotEmpty) {
          textEditingController.text = _emailController.text;
        }
        textEditingController.addListener(() {
          _emailController.text = textEditingController.text;
        });
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          keyboardType: TextInputType.emailAddress,
          style:
              const TextStyle(color: AppColors.textPrimary, fontSize: 15),
          decoration: AppTheme.fieldDecoration(
              label: 'Recipient Gmail', icon: Icons.email_outlined),
          validator: (val) {
            if (val == null || val.isEmpty) return 'Email required';
            if (!RegExp(r"^[a-zA-Z0-9.]+@gmail\.com$").hasMatch(val))
              return 'Enter a valid @gmail.com address';
            return null;
          },
        ).animate().fade(delay: delay.ms).slideX(begin: 0.08, end: 0, delay: delay.ms);
      },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width - 40,
              margin: const EdgeInsets.only(top: 6),
              decoration: BoxDecoration(
                color: AppColors.bgCardAlt,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF2D3748), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shrinkWrap: true,
                  itemCount: options.length,
                  separatorBuilder: (_, __) => const Divider(
                    color: Color(0xFF2D3748),
                    height: 1,
                    indent: 20,
                    endIndent: 20,
                  ),
                  itemBuilder: (context, index) {
                    final option = options.elementAt(index);
                    return ListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.history_rounded,
                            color: AppColors.primaryGlow, size: 16),
                      ),
                      title: Text(option,
                          style: const TextStyle(
                              color: AppColors.textPrimary, fontSize: 14)),
                      onTap: () => onSelected(option),
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
