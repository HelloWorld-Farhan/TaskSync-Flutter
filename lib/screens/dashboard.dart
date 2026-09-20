import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../services/database_helper.dart';
import '../services/alarm_service.dart';
import '../theme/app_theme.dart';
import 'add_task.dart';
import 'add_routine_screen.dart';
import 'routines_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  List<Task> _tasks = [];
  List<Map<String, dynamic>> _routines = [];
  bool _isLoading = true;
  Timer? _refreshTimer;
  late AnimationController _fabController;
  late TabController _tabController;

  // Scoring
  int _todayEarned = 0;
  int _todayTotal = 0;
  List<Map<String, dynamic>> _todayBreakdown = [];
  String _todayDate = '';
  String _todayDayShort = '';

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _tabController = TabController(length: 2, vsync: this);
    _initToday();
    _refreshTasks();
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) => _refreshTasks());
    Future.delayed(const Duration(milliseconds: 300), () => _fabController.forward());
  }

  void _initToday() {
    final now = DateTime.now();
    _todayDate = DateFormat('yyyy-MM-dd').format(now);
    _todayDayShort = DateFormat('EEE').format(now).substring(0, 3); // Mon, Tue...
  }

  @override
  void dispose() {
    _fabController.dispose();
    _tabController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshTasks() async {
    final tasks = await DatabaseHelper.instance.readAllTasks();
    final routines = await DatabaseHelper.instance.readAllRoutines();
    final scoreData = await DatabaseHelper.instance.calculateTodayScore(_todayDate, _todayDayShort);
    if (mounted) {
      setState(() {
        _tasks = tasks;
        _routines = routines;
        _todayEarned = scoreData['earned'] as int;
        _todayTotal = scoreData['total'] as int;
        _todayBreakdown = List<Map<String, dynamic>>.from(scoreData['breakdown']);
        _isLoading = false;
      });
    }
    // Persist today's score
    await DatabaseHelper.instance.saveDailyScore(
      date: _todayDate,
      earnedPoints: _todayEarned,
      totalPoints: _todayTotal,
      breakdown: _todayBreakdown,
    );
  }

  // ---------- Helpers ----------

  List<Task> get _currentTasks {
    final now = DateTime.now();
    return _tasks.where((t) {
      if (t.isCompleted == 1 || t.isCompleted == 2) return false;
      if (t.recurrenceType == 'Daily') return true;
      if (t.recurrenceType == 'Once') {
        try {
          final taskDate = DateTime.parse(t.date);
          return !taskDate.isBefore(DateTime(now.year, now.month, now.day));
        } catch (_) { return true; }
      }
      return true;
    }).toList();
  }

  List<Task> get _historyTasks {
    final now = DateTime.now();
    return _tasks.where((t) {
      if (t.isCompleted == 1 || t.isCompleted == 2) return true;
      if (t.recurrenceType == 'Once') {
        try {
          final taskDate = DateTime.parse(t.date);
          return taskDate.isBefore(DateTime(now.year, now.month, now.day));
        } catch (_) { return false; }
      }
      return false;
    }).toList();
  }

  List<Map<String, dynamic>> get _currentRoutines {
    return _routines; // All routines are "current"
  }

  Future<void> _cancelTask(Task task) async {
    task.isCompleted = 2;
    await DatabaseHelper.instance.update(task);
    await AlarmService.cancelAlarm(task.id!);
    _refreshTasks();
  }

  Future<void> _completeTask(Task task) async {
    task.isCompleted = 1;
    await DatabaseHelper.instance.update(task);
    _refreshTasks();
  }

  // ---------- Score Widget ----------

  String get _scoreText {
    if (_todayTotal == 0) return '—';
    return '$_todayEarned pts';
  }

  double get _scorePercent {
    if (_todayTotal == 0) return 0;
    return _todayEarned / _todayTotal;
  }



  // ---------- Popups ----------

  void _showTaskDetail(Task task) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _TaskDetailSheet(
        task: task,
        onComplete: () { Navigator.pop(context); _completeTask(task); },
        onCancel: () { Navigator.pop(context); _cancelTask(task); },
        onDelete: () async {
          Navigator.pop(context);
          await DatabaseHelper.instance.delete(task.id!);
          _refreshTasks();
        },
      ),
    );
  }

  void _showRoutineDetail(Map<String, dynamic> routine) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _RoutineDetailSheet(
        routine: routine,
        onEdit: () async {
          Navigator.pop(context);
          await Navigator.push(context, MaterialPageRoute(
            builder: (_) => AddRoutineScreen(existingRoutine: routine),
          ));
          _refreshTasks();
        },
        onDelete: () async {
          Navigator.pop(context);
          await DatabaseHelper.instance.deleteRoutine(routine['id'] as int);
          _refreshTasks();
        },
      ),
    );
  }

  void _showScoreboard() async {
    final history = await DatabaseHelper.instance.getDailyScoreHistory();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ScoreboardSheet(
        todayDate: _todayDate,
        todayEarned: _todayEarned,
        todayTotal: _todayTotal,
        todayBreakdown: _todayBreakdown,
        history: history,
      ),
    );
  }

  void _showRecurrenceSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
        decoration: const BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(top: BorderSide(color: AppColors.border, width: 1.5)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(color: AppColors.textMuted, borderRadius: BorderRadius.circular(4)),
            ),
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.add_alarm, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 14),
              Text('New Reminder', style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 24),
            _buildMenuOption('Once', Icons.looks_one_outlined, 'Send once at the scheduled time', AppColors.accent),
            const SizedBox(height: 12),
            _buildMenuOption('Daily', Icons.repeat_rounded, 'Send every day at the same time', AppColors.primaryGlow),
            const SizedBox(height: 12),
            _buildMenuOption('Custom', Icons.date_range_outlined, 'Choose specific dates', AppColors.warning),
            const SizedBox(height: 12),
            _buildRoutineMenuOption(),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOption(String title, IconData icon, String subtitle, Color color) {
    return GestureDetector(
      onTap: () async {
        Navigator.pop(context);
        final result = await Navigator.of(context).push(PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, __, ___) => AddTaskScreen(recurrenceType: title),
          transitionsBuilder: (_, animation, __, child) => SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
            child: child,
          ),
        ));
        if (result == true) _refreshTasks();
      },
      child: _menuCard(title, icon, subtitle, color),
    );
  }

  Widget _buildRoutineMenuOption() {
    return GestureDetector(
      onTap: () async {
        Navigator.pop(context);
        final result = await Navigator.of(context).push(PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, __, ___) => const AddRoutineScreen(),
          transitionsBuilder: (_, animation, __, child) => SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                .animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
            child: child,
          ),
        ));
        if (result == true) _refreshTasks();
      },
      child: _menuCard('Daily Routine', Icons.checklist_rtl_rounded,
          'Set weekly recurring routines by day', AppColors.success),
    );
  }

  Widget _menuCard(String title, IconData icon, String subtitle, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        ])),
        Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.7)),
      ]),
    );
  }

  // ---------- Build ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: SafeArea(
        child: Column(children: [
          _buildAppBar(),
          _buildTabBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildScheduleTab(),
                      _buildRemindersTab(),
                    ],
                  ),
          ),
        ]),
      ),
      floatingActionButton: ScaleTransition(
        scale: CurvedAnimation(parent: _fabController, curve: Curves.elasticOut),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppColors.primaryGlow.withValues(alpha: 0.6),
                blurRadius: 20,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: _showRecurrenceSelector,
            backgroundColor: AppColors.primary,
            splashColor: AppColors.accentLight.withValues(alpha: 0.3),
            elevation: 0,
            highlightElevation: 0,
            icon: const Icon(Icons.add, color: Colors.white),
            label: const Text('New Reminder',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      decoration: const BoxDecoration(
        gradient: AppColors.dashGradient,
        border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5)),
      ),
      child: Row(children: [
        // App name
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ShaderMask(
            shaderCallback: (bounds) => AppColors.accentGradient.createShader(bounds),
            child: const Text('TaskSync', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
          Text(DateFormat('EEEE, d MMM').format(DateTime.now()),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
        ]),
        const Spacer(),
        // Score badge
        GestureDetector(
          onTap: _showScoreboard,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: AppColors.scoreGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 12, spreadRadius: 1)],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.star_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 6),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(_scoreText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                if (_todayTotal > 0)
                  Text('${(_scorePercent * 100).round()}%',
                      style: const TextStyle(color: Colors.white70, fontSize: 10)),
              ]),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      decoration: BoxDecoration(
        color: AppColors.bgMid,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(12),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: AppColors.textMuted,
        labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
        tabs: const [
          Tab(text: '📅  Daily Routine'),
          Tab(text: '🔔  Reminders'),
        ],
      ),
    );
  }

  // ---------- Schedule Tab ----------

  Widget _buildScheduleTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        _sectionHeader('Current Routines', Icons.play_circle_outline, AppColors.success, _currentRoutines.length),
        if (_currentRoutines.isEmpty)
          _emptyState('No routines yet', 'Tap + to add your first daily routine')
        else
          ..._currentRoutines.map((r) => _routineCard(r)).toList(),
        const SizedBox(height: 24),
        _sectionHeader('History', Icons.history_rounded, AppColors.textMuted, 0),
        _routineHistorySection(),
      ],
    );
  }

  Widget _routineHistorySection() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: DatabaseHelper.instance.getDailyScoreHistory(),
      builder: (context, snap) {
        if (!snap.hasData || snap.data!.isEmpty) {
          return _emptyState('No history yet', 'Completed routines will appear here');
        }
        final days = snap.data!.where((d) => d['date'] != _todayDate).take(7).toList();
        if (days.isEmpty) return _emptyState('No past history', 'Check back tomorrow');
        return Column(
          children: days.map((day) {
            final breakdown = List<Map<String, dynamic>>.from(day['breakdown'] as List);
            final routineItems = breakdown.where((b) => b['type'] == 'routine').toList();
            if (routineItems.isEmpty) return const SizedBox.shrink();
            return _historyDayCard(day['date'] as String, routineItems,
                day['earned_points'] as int, day['total_points'] as int);
          }).toList(),
        );
      },
    );
  }

  Widget _routineCard(Map<String, dynamic> routine) {
    final days = (routine['days_of_week'] as String).split(',');
    return GestureDetector(
      onTap: () => _showRoutineDetail(routine),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppColors.cardGradient,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.loop_rounded, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(routine['title'] as String,
                style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 4),
            Text('${_formatTime(routine['start_time'])} – ${_formatTime(routine['end_time'])}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
            const SizedBox(height: 6),
            Wrap(spacing: 4, children: days.map((d) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(d.trim(), style: const TextStyle(color: AppColors.accentLight, fontSize: 10, fontWeight: FontWeight.w600)),
            )).toList()),
          ])),
          const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
        ]),
      ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.05),
    );
  }

  // ---------- Reminders Tab ----------

  Widget _buildRemindersTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
      children: [
        _sectionHeader('Current Reminders', Icons.notifications_active_outlined, AppColors.accent, _currentTasks.length),
        if (_currentTasks.isEmpty)
          _emptyState('No active reminders', 'Tap + to schedule your first reminder')
        else
          ..._currentTasks.map((t) => _taskCard(t, isHistory: false)).toList(),
        const SizedBox(height: 24),
        _sectionHeader('History', Icons.history_rounded, AppColors.textMuted, _historyTasks.length),
        if (_historyTasks.isEmpty)
          _emptyState('No history yet', 'Completed or past reminders appear here')
        else
          ..._historyTasks.map((t) => _taskCard(t, isHistory: true)).toList(),
      ],
    );
  }

  String _formatTime(String time24) {
    try {
      final parts = time24.split(':');
      if (parts.length != 2) return time24;
      int h = int.parse(parts[0].trim());
      int m = int.parse(parts[1].trim());
      String ampm = h >= 12 ? 'PM' : 'AM';
      h = h % 12;
      if (h == 0) h = 12;
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $ampm';
    } catch (e) {
      return time24;
    }
  }

  String _formatTimeRange(String time) {
    if (time.contains(' - ')) {
      final parts = time.split(' - ');
      return '${_formatTime(parts[0])} - ${_formatTime(parts[1])}';
    }
    return _formatTime(time);
  }

  Widget _taskCard(Task task, {required bool isHistory}) {
    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (task.isCompleted == 1) {
      statusColor = AppColors.success;
      statusIcon = Icons.check_circle_rounded;
      statusText = 'Done';
    } else if (task.isCompleted == 2) {
      statusColor = AppColors.danger;
      statusIcon = Icons.cancel_rounded;
      statusText = 'Cancelled';
    } else {
      statusColor = AppColors.accent;
      statusIcon = Icons.pending_rounded;
      statusText = task.recurrenceType;
    }

    return GestureDetector(
      onTap: () => _showTaskDetail(task),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppColors.cardGradient,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isHistory ? AppColors.border.withValues(alpha: 0.5) : AppColors.border, width: 1),
        ),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
            ),
            child: Icon(statusIcon, color: statusColor, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(task.title,
                style: TextStyle(
                  color: isHistory ? AppColors.textSecondary : AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  decoration: task.isCompleted == 2 ? TextDecoration.lineThrough : null,
                )),
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.access_time_rounded, size: 12, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(_formatTime(task.time), style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
              const SizedBox(width: 8),
              const Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(task.date, style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
            ]),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: statusColor.withValues(alpha: 0.2)),
            ),
            child: Text(statusText, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.w600)),
          ),
        ]),
      ).animate().fadeIn(duration: 300.ms).slideX(begin: 0.05),
    );
  }

  // ---------- History Day Card ----------

  Widget _historyDayCard(String date, List<Map<String, dynamic>> items, int earned, int total) {
    final percent = total > 0 ? (earned / total * 100).round() : 0;
    Color pColor = percent >= 80 ? AppColors.success : percent >= 50 ? AppColors.warning : AppColors.danger;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.calendar_month_rounded, color: AppColors.textMuted, size: 16),
          const SizedBox(width: 6),
          Text(date, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('$earned / $total pts', style: TextStyle(color: pColor, fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: pColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Text('$percent%', style: TextStyle(color: pColor, fontSize: 11, fontWeight: FontWeight.w700)),
          ),
        ]),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 8),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(children: [
              Icon(
                item['status'] == 'done'
                    ? Icons.check_circle_outline
                    : item['status'] == 'pending'
                        ? Icons.schedule_rounded
                        : Icons.cancel_outlined,
                color: item['status'] == 'done'
                    ? AppColors.success
                    : item['status'] == 'pending'
                        ? AppColors.warning
                        : AppColors.danger,
                size: 16,
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(item['title'] as String,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
              Text('${item['points']} pts',
                  style: TextStyle(
                    color: item['status'] == 'done' 
                        ? AppColors.success 
                        : item['status'] == 'pending'
                            ? AppColors.textMuted
                            : AppColors.textMuted,
                    fontSize: 12, fontWeight: FontWeight.w600,
                  )),
            ]),
          )).toList(),
        ],
      ]),
    );
  }

  // ---------- Shared Widgets ----------

  Widget _sectionHeader(String title, IconData icon, Color color, int count) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Text(title, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
        if (count > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
            child: Text('$count', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ],
      ]),
    );
  }

  Widget _emptyState(String title, String subtitle) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.bgCard.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border.withValues(alpha: 0.3)),
      ),
      child: Column(children: [
        Icon(Icons.inbox_rounded, size: 48, color: AppColors.textMuted.withValues(alpha: 0.5)),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: AppColors.textMuted, fontSize: 12), textAlign: TextAlign.center),
      ]),
    );
  }
}

// ============================================================
// Task Detail Bottom Sheet
// ============================================================

class _TaskDetailSheet extends StatelessWidget {
  final Task task;
  final VoidCallback onComplete;
  final VoidCallback onCancel;
  final VoidCallback onDelete;

  const _TaskDetailSheet({
    required this.task,
    required this.onComplete,
    required this.onCancel,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDone = task.isCompleted == 1;
    final bool isCancelled = task.isCompleted == 2;

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: AppColors.border, width: 1.5)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(color: AppColors.textMuted, borderRadius: BorderRadius.circular(4))),

        // Status badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDone ? AppColors.success.withValues(alpha: 0.1)
                : isCancelled ? AppColors.danger.withValues(alpha: 0.1)
                : AppColors.accent.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isDone ? AppColors.success.withValues(alpha: 0.3)
                : isCancelled ? AppColors.danger.withValues(alpha: 0.3)
                : AppColors.accent.withValues(alpha: 0.3)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(isDone ? Icons.check_circle_rounded : isCancelled ? Icons.cancel_rounded : Icons.pending_rounded,
                color: isDone ? AppColors.success : isCancelled ? AppColors.danger : AppColors.accent, size: 16),
            const SizedBox(width: 6),
            Text(isDone ? 'Completed' : isCancelled ? 'Cancelled' : task.recurrenceType,
                style: TextStyle(color: isDone ? AppColors.success : isCancelled ? AppColors.danger : AppColors.accent,
                    fontWeight: FontWeight.w600, fontSize: 13)),
          ]),
        ),

        const SizedBox(height: 20),
        Text(task.title, style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        if (task.description.isNotEmpty)
          Text(task.description, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              textAlign: TextAlign.center),

        const SizedBox(height: 24),
        const Divider(color: AppColors.border),
        const SizedBox(height: 16),

        // Details grid
        Row(children: [
          _detailChip(Icons.calendar_today_rounded, 'Date', task.date),
          const SizedBox(width: 12),
          _detailChip(Icons.access_time_rounded, 'Time', task.time),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _detailChip(Icons.repeat_rounded, 'Recurrence', task.recurrenceType),
          if (task.recipientEmail.isNotEmpty) ...[
            const SizedBox(width: 12),
            _detailChip(Icons.email_outlined, 'Email', task.recipientEmail, flex: 2),
          ],
        ]),

        const SizedBox(height: 24),

        if (!isDone && !isCancelled) Row(children: [
          Expanded(child: OutlinedButton.icon(
            icon: const Icon(Icons.cancel_outlined, size: 18),
            label: const Text('Cancel'),
            onPressed: onCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          )),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton.icon(
            icon: const Icon(Icons.check_circle_outline, size: 18),
            label: const Text('Done'),
            onPressed: onComplete,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          )),
        ]),

        const SizedBox(height: 12),
        TextButton.icon(
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
          label: const Text('Delete Permanently'),
          onPressed: onDelete,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textMuted,
            textStyle: const TextStyle(fontSize: 13),
          ),
        ),
      ]),
    );
  }

  Widget _detailChip(IconData icon, String label, String value, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bgDeep,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 13, color: AppColors.accentLight),
            const SizedBox(width: 5),
            Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
          ]),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}

// ============================================================
// Routine Detail Bottom Sheet
// ============================================================

class _RoutineDetailSheet extends StatelessWidget {
  final Map<String, dynamic> routine;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _RoutineDetailSheet({required this.routine, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final days = (routine['days_of_week'] as String).split(',');

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: AppColors.border, width: 1.5)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(color: AppColors.textMuted, borderRadius: BorderRadius.circular(4))),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(gradient: AppColors.primaryGradient, shape: BoxShape.circle),
          child: const Icon(Icons.loop_rounded, color: Colors.white, size: 32),
        ),

        const SizedBox(height: 16),
        Text(routine['title'] as String,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center),
        const SizedBox(height: 8),
        if ((routine['description'] as String).isNotEmpty)
          Text(routine['description'] as String,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 14), textAlign: TextAlign.center),

        const SizedBox(height: 20),
        const Divider(color: AppColors.border),
        const SizedBox(height: 16),

        // Time
        Row(children: [
          Expanded(child: _infoTile(Icons.play_arrow_rounded, 'Start', routine['start_time'] as String, AppColors.success)),
          const SizedBox(width: 12),
          Expanded(child: _infoTile(Icons.stop_rounded, 'End', routine['end_time'] as String, AppColors.danger)),
        ]),

        const SizedBox(height: 12),
        // Days
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppColors.bgDeep, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.calendar_month_rounded, size: 13, color: AppColors.accentLight),
              SizedBox(width: 5),
              Text('Active Days', style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
            ]),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: days.map((d) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(d.trim(), style: const TextStyle(color: AppColors.accentLight, fontWeight: FontWeight.w600, fontSize: 12)),
            )).toList()),
          ]),
        ),

        const SizedBox(height: 24),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Delete'),
            onPressed: onDelete,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.danger),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          )),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton.icon(
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text('Edit'),
            onPressed: onEdit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          )),
        ]),
      ]),
    );
  }

  Widget _infoTile(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.bgDeep, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        ]),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
      ]),
    );
  }
}

// ============================================================
// Scoreboard Bottom Sheet
// ============================================================

class _ScoreboardSheet extends StatelessWidget {
  final String todayDate;
  final int todayEarned;
  final int todayTotal;
  final List<Map<String, dynamic>> todayBreakdown;
  final List<Map<String, dynamic>> history;

  const _ScoreboardSheet({
    required this.todayDate,
    required this.todayEarned,
    required this.todayTotal,
    required this.todayBreakdown,
    required this.history,
  });

  @override
  Widget build(BuildContext context) {
    final percent = todayTotal > 0 ? (todayEarned / todayTotal * 100).round() : 0;
    Color pColor = percent >= 80 ? AppColors.success : percent >= 50 ? AppColors.warning : AppColors.danger;
    final past = history.where((d) => d['date'] != todayDate).take(10).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          border: Border(top: BorderSide(color: AppColors.border, width: 1.5)),
        ),
        child: ListView(controller: ctrl, padding: const EdgeInsets.fromLTRB(24, 12, 24, 36), children: [
          Center(child: Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: AppColors.textMuted, borderRadius: BorderRadius.circular(4)))),

          // Header
          Row(children: [
            ShaderMask(
              shaderCallback: (b) => AppColors.scoreGradient.createShader(b),
              child: const Icon(Icons.star_rounded, size: 28, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Text('Scoreboard', style: TextStyle(color: AppColors.textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
          ]),

          const SizedBox(height: 20),

          // Today's score hero
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.scoreGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 20, spreadRadius: 2)],
            ),
            child: Column(children: [
              Text(() {
                try {
                  final d = DateTime.parse(todayDate);
                  return DateFormat("d MMM yyyy (EEEE)").format(d);
                } catch (_) {
                  return todayDate;
                }
              }(), style: const TextStyle(color: Colors.white70, fontSize: 13)),
              const SizedBox(height: 8),
              Text('$todayEarned pts', style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w900)),
              Text('out of $todayTotal pts', style: const TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: todayTotal > 0 ? todayEarned / todayTotal : 0,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  color: Colors.white,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Text('$percent% achieved', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ]),
          ),

          if (todayBreakdown.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text("Today's Breakdown", style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 12),
            ...todayBreakdown.map((item) => _breakdownRow(item)).toList(),
          ],

          if (past.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text('Past Days', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 12),
            ...past.map((day) {
              final e = day['earned_points'] as int;
              final t = day['total_points'] as int;
              final p = t > 0 ? (e / t * 100).round() : 0;
              Color c = p >= 80 ? AppColors.success : p >= 50 ? AppColors.warning : AppColors.danger;
              final breakdown = List<Map<String, dynamic>>.from(day['breakdown'] as List);

              return ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: Row(children: [
                  const Icon(Icons.calendar_month_rounded, color: AppColors.textMuted, size: 16),
                  const SizedBox(width: 8),
                  Text(() {
                      try { return DateFormat("d MMM yyyy (EEEE)").format(DateTime.parse(day['date'] as String)); }
                      catch (_) { return day['date'] as String; }
                    }(), style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600, fontSize: 12)),
                  const Spacer(),
                  Text('$e / $t', style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: c.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text('$p%', style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
                ]),
                children: breakdown.map((item) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: _breakdownRow(item),
                )).toList(),
              );
            }).toList(),
          ],
        ]),
      ),
    );
  }

  Widget _breakdownRow(Map<String, dynamic> item) {
    final isDone = item['status'] == 'done';
    final pts = item['points'] as int;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgDeep,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(children: [
        Icon(isDone ? Icons.check_circle_rounded : Icons.cancel_rounded,
            color: isDone ? AppColors.success : AppColors.danger, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item['title'] as String,
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
          Text(item['time'] as String, style: const TextStyle(color: AppColors.textMuted, fontSize: 11)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('$pts pts', style: TextStyle(
              color: isDone ? AppColors.success : AppColors.textMuted,
              fontWeight: FontWeight.w700, fontSize: 14)),
          Text('/ ${item['max']} max', style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
        ]),
      ]),
    );
  }
}
