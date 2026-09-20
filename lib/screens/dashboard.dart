import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import '../models/task.dart';
import '../services/database_helper.dart';
import '../services/alarm_service.dart';
import '../theme/app_theme.dart';
import 'add_task.dart';
import 'routines_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  List<Task> _tasks = [];
  Map<String, List<Task>> _ongoingGroupedTasks = {};
  Map<String, List<Task>> _previousGroupedTasks = {};
  bool _isLoading = true;
  Timer? _refreshTimer;
  late AnimationController _fabController;

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _refreshTasks();
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) _refreshTasks();
    });
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _fabController.forward();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _fabController.dispose();
    super.dispose();
  }

  Future<void> _refreshTasks() async {
    final data = await DatabaseHelper.instance.readAllTasks();
    data.sort((a, b) {
      int dateCmp = a.date.compareTo(b.date);
      if (dateCmp != 0) return dateCmp;
      return a.time.compareTo(b.time);
    });

    Map<String, List<Task>> ongoing = {};
    Map<String, List<Task>> previous = {};
    for (var task in data) {
      if (task.isCompleted == 0) {
        ongoing.putIfAbsent(task.date, () => []).add(task);
      } else {
        previous.putIfAbsent(task.date, () => []).add(task);
      }
    }

    if (mounted) {
      setState(() {
        _tasks = data;
        _ongoingGroupedTasks = ongoing;
        _previousGroupedTasks = previous;
        _isLoading = false;
      });
    }
  }

  Future<void> _cancelTask(Task task) async {
    await AlarmService.cancelAlarm(task.id!);
    task.isCompleted = 2;
    await DatabaseHelper.instance.update(task);
    _refreshTasks();
  }

  void _confirmCancelTask(Task task) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFF2D3748), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.warning_amber_rounded,
                          color: AppColors.warning, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Cancel Reminder?',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Are you sure you want to permanently cancel this reminder?\n\n'
                  '📌 Title: ${task.title}\n'
                  '📅 Date: ${task.date}\n'
                  '🕐 Time: ${_formatTime(task.time)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 14,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: const BorderSide(color: Color(0xFF2D3748)),
                          ),
                        ),
                        child: const Text('Keep it',
                            style: TextStyle(color: AppColors.textSecondary)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.pop(context);
                          _cancelTask(task);
                        },
                        child: const Text('Yes, Cancel',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ).animate().scale(
              begin: const Offset(0.85, 0.85),
              end: const Offset(1, 1),
              duration: 300.ms,
              curve: Curves.easeOutBack,
            ).fade(duration: 200.ms);
      },
    );
  }

  void _showRecurrenceSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(32)),
            border: const Border(
              top: BorderSide(color: Color(0xFF2D3748), width: 1.5),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: AppColors.textMuted,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.add_alarm,
                        color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'New Reminder',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildRecurrenceOption('Once', Icons.looks_one_outlined,
                  'Send once at the scheduled time', AppColors.primary),
              const SizedBox(height: 12),
              _buildRecurrenceOption('Daily', Icons.repeat_rounded,
                  'Send every day at the same time', AppColors.secondary),
              const SizedBox(height: 12),
              _buildRecurrenceOption('Custom', Icons.date_range_outlined,
                  'Choose specific dates', AppColors.warning),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRecurrenceOption(
      String title, IconData icon, String subtitle, Color color) {
    return GestureDetector(
      onTap: () async {
        Navigator.pop(context);
        final result = await Navigator.of(context).push(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 500),
            pageBuilder: (_, __, ___) =>
                AddTaskScreen(recurrenceType: title),
            transitionsBuilder: (_, animation, __, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOut)),
                child: child,
              );
            },
          ),
        );
        if (result == true) _refreshTasks();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: color.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }

  void _showTaskDetails(Task task) {
    bool isCancelled = task.isCompleted == 2;
    bool isDone = task.isCompleted == 1;

    String dayName = '';
    try {
      DateTime parsed = DateTime.parse(task.date);
      dayName = DateFormat('EEEE').format(parsed);
    } catch (_) {}

    showDialog(
      context: context,
      builder: (context) {
        Color statusColor = isCancelled
            ? AppColors.danger
            : isDone
                ? AppColors.success
                : AppColors.warning;
        String statusText = isCancelled
            ? 'Cancelled'
            : isDone
                ? 'Completed'
                : 'On Process';

        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFF2D3748), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.event_note,
                          color: Colors.white, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            task.title,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (dayName.isNotEmpty)
                            Text(
                              'For $dayName',
                              style: const TextStyle(
                                  color: AppColors.primaryGlow, fontSize: 13),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),
                Container(
                    height: 1, color: const Color(0xFF2D3748)),
                const SizedBox(height: 20),

                // Details
                _detailRow(Icons.description_outlined, 'Description',
                    task.description),
                _detailRow(
                    Icons.email_outlined, 'Email', task.recipientEmail),
                _detailRow(
                    Icons.calendar_today_outlined, 'Date', _formatDate(task.date)),
                _detailRow(
                    Icons.access_time_outlined, 'Time', task.time),
                _detailRow(
                    Icons.repeat_rounded, 'Recurrence', task.recurrenceType),
                if (task.recurrenceType == 'Custom')
                  _detailRow(Icons.date_range_outlined, 'Custom Dates',
                      task.customDates),

                const SizedBox(height: 16),

                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: statusColor.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isCancelled
                            ? Icons.cancel_outlined
                            : isDone
                                ? Icons.check_circle_outline
                                : Icons.pending_actions,
                        color: statusColor,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Status: $statusText',
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Actions
                Row(
                  children: [
                    if (!isCancelled && !isDone)
                      Expanded(
                        child: TextButton.icon(
                          icon: const Icon(Icons.cancel_outlined,
                              color: AppColors.danger, size: 16),
                          label: const Text('Cancel',
                              style: TextStyle(color: AppColors.danger)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: const BorderSide(
                                  color: AppColors.danger, width: 1),
                            ),
                          ),
                          onPressed: () => _confirmCancelTask(task),
                        ),
                      ),
                    if (!isCancelled && !isDone) const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Close',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ).animate().scale(
              begin: const Offset(0.85, 0.85),
              end: const Offset(1, 1),
              duration: 300.ms,
              curve: Curves.easeOutBack,
            ).fade(duration: 200.ms);
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryGlow, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5)),
                const SizedBox(height: 2),
                Text(
                  value.isNotEmpty ? value : 'N/A',
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String time24) {
    if (time24.isEmpty) return '';
    try {
      final parts = time24.split(':');
      int h = int.parse(parts[0]);
      int m = int.parse(parts[1]);
      bool isAm = h < 12;
      int h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '${h12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} ${isAm ? 'AM' : 'PM'}';
    } catch (_) {
      return time24;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.dashGradient),
        child: Stack(
          children: [
            // Background orbs
            Positioned(
              top: -60,
              right: -40,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 80,
              left: -60,
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.secondary.withValues(alpha: 0.07),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Main scaffold
            SafeArea(
              child: CustomScrollView(
                slivers: [
                  // App Bar
                  SliverAppBar(
                    backgroundColor: Colors.transparent,
                    expandedHeight: 120,
                    floating: false,
                    pinned: true,
                    flexibleSpace: FlexibleSpaceBar(
                      titlePadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                      title: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Image.asset('Logo.png', width: 32, height: 32),
                          const SizedBox(width: 10),
                          const Text(
                            'My Schedule',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppColors.bgDeep,
                              AppColors.bgDeep.withValues(alpha: 0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.check_circle_outline, color: AppColors.primaryGlow),
                        tooltip: 'Daily Routines',
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const RoutinesScreen()),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                  ),

                  // Content
                  _isLoading
                      ? const SliverFillRemaining(
                          child: Center(
                            child: CircularProgressIndicator(
                              color: AppColors.primaryGlow,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : _tasks.isEmpty
                          ? SliverFillRemaining(child: _buildEmptyState())
                          : SliverPadding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                              sliver: SliverToBoxAdapter(
                                child: Column(
                                  children: [
                                    _buildHistoryPanel(
                                      'On-Going Tasks', 
                                      _ongoingGroupedTasks, 
                                      Icons.timelapse_rounded,
                                    ),
                                    _buildHistoryPanel(
                                      'Previous Tasks', 
                                      _previousGroupedTasks, 
                                      Icons.history_rounded,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: ScaleTransition(
        scale: CurvedAnimation(
          parent: _fabController,
          curve: Curves.elasticOut,
        ),
        child: FloatingActionButton.extended(
          onPressed: _showRecurrenceSelector,
          backgroundColor: AppColors.primary,
          elevation: 8,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text(
            'New Reminder',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildHistoryPanel(String title, Map<String, List<Task>> grouped, IconData icon) {
    if (grouped.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          collapsedBackgroundColor: AppColors.bgCard.withOpacity(0.5),
          backgroundColor: AppColors.bgCard.withOpacity(0.8),
          iconColor: AppColors.primaryGlow,
          collapsedIconColor: AppColors.textMuted,
          initiallyExpanded: title.contains('On-Going'),
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          title: Row(
            children: [
              Icon(icon, color: AppColors.primaryGlow, size: 22),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: grouped.entries.map((entry) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDateHeader(entry.key, 0),
                      ...entry.value.asMap().entries.map((e) => _buildTaskCard(e.value, e.key)),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.08),
                ),
              )
                  .animate(onPlay: (c) => c.repeat())
                  .scaleXY(
                    begin: 1,
                    end: 1.2,
                    duration: 1500.ms,
                    curve: Curves.easeOut,
                  )
                  .fadeOut(duration: 1500.ms),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.1),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2), width: 2),
                ),
                child: const Icon(
                  Icons.event_note_outlined,
                  size: 44,
                  color: AppColors.primaryGlow,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          const Text(
            'No reminders yet',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Tap + New Reminder to get started',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
        ],
      ).animate().fade(duration: 500.ms).scale(curve: Curves.easeOut),
    );
  }

  Widget _buildDateHeader(String dateString, int groupIndex) {
    String displayText = dateString;
    bool isToday = false;
    try {
      DateTime parsed = DateTime.parse(dateString);
      DateTime now = DateTime.now();
      DateTime today = DateTime(now.year, now.month, now.day);
      DateTime yesterday = today.subtract(const Duration(days: 1));
      DateTime tomorrow = today.add(const Duration(days: 1));
      String dayName = DateFormat('EEEE').format(parsed);
      String formattedDate = DateFormat('dd/MM/yyyy').format(parsed);

      if (parsed == today) {
        displayText = 'Today — $dayName';
        isToday = true;
      } else if (parsed == yesterday) {
        displayText = 'Yesterday — $dayName';
      } else if (parsed == tomorrow) {
        displayText = 'Tomorrow — $dayName';
      } else {
        displayText = '$formattedDate ($dayName)';
      }
    } catch (_) {}

    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              gradient: isToday
                  ? AppColors.primaryGradient
                  : AppColors.tealGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (isToday ? AppColors.primary : AppColors.secondary)
                      .withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isToday ? Icons.today_rounded : Icons.calendar_month_rounded,
                  color: Colors.white,
                  size: 14,
                ),
                const SizedBox(width: 6),
                Text(
                  displayText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              color: const Color(0xFF2D3748),
            ),
          ),
        ],
      ),
    ).animate(delay: (groupIndex * 60).ms).fade().slideX(begin: -0.1, end: 0);
  }

  Widget _buildTaskCard(Task task, int index) {
    bool isDone = task.isCompleted == 1;
    bool isCancelled = task.isCompleted == 2;

    Color statusColor = isCancelled
        ? AppColors.danger
        : isDone
            ? AppColors.success
            : AppColors.warning;

    String statusText = isCancelled
        ? 'Cancelled'
        : isDone
            ? 'Completed'
            : 'On Process';

    IconData statusIcon = isCancelled
        ? Icons.cancel_outlined
        : isDone
            ? Icons.check_circle_outline
            : Icons.pending_actions_outlined;

    return GestureDetector(
      onTap: () => _showTaskDetails(task),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isCancelled
                ? AppColors.danger.withValues(alpha: 0.2)
                : isDone
                    ? AppColors.success.withValues(alpha: 0.2)
                    : const Color(0xFF2D3748),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: statusColor.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            // Left status bar
            Container(
              width: 5,
              height: 90,
              margin: const EdgeInsets.only(left: 1),
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(22),
                  bottomLeft: Radius.circular(22),
                ),
                boxShadow: [
                  BoxShadow(
                    color: statusColor.withValues(alpha: 0.5),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: isCancelled || isDone
                                  ? AppColors.textSecondary
                                  : AppColors.textPrimary,
                              decoration: isCancelled || isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(statusIcon, size: 11, color: statusColor),
                              const SizedBox(width: 4),
                              Text(
                                statusText,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Date + Time row
                    Row(
                      children: [
                        _infoChip(
                          Icons.calendar_today_outlined,
                          _formatDate(task.date),
                          AppColors.primaryGlow,
                        ),
                        const SizedBox(width: 10),
                        _infoChip(
                          Icons.access_time_rounded,
                          _formatTime(task.time),
                          AppColors.secondaryGlow,
                        ),
                        const SizedBox(width: 10),
                        _infoChip(
                          Icons.repeat_rounded,
                          task.recurrenceType,
                          AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Trailing actions
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (task.isCompleted == 0) ...[
                  _actionButton(
                    Icons.edit_outlined,
                    AppColors.secondary,
                    () async {
                      final result = await Navigator.of(context).push(
                        PageRouteBuilder(
                          transitionDuration:
                              const Duration(milliseconds: 500),
                          pageBuilder: (_, __, ___) => AddTaskScreen(
                            recurrenceType: task.recurrenceType,
                            taskToEdit: task,
                          ),
                          transitionsBuilder: (_, animation, __, child) {
                            return SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 1),
                                end: Offset.zero,
                              ).animate(CurvedAnimation(
                                  parent: animation,
                                  curve: Curves.easeOut)),
                              child: child,
                            );
                          },
                        ),
                      );
                      if (result == true) _refreshTasks();
                    },
                  ),
                  const SizedBox(height: 6),
                  _actionButton(
                    Icons.cancel_outlined,
                    AppColors.danger,
                    () => _confirmCancelTask(task),
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(right: 14),
                    child: Icon(
                      isDone ? Icons.check_circle : Icons.cancel,
                      color: statusColor,
                      size: 24,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    ).animate(delay: (index * 80).ms).fade().slideX(begin: 0.15, end: 0);
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color.withValues(alpha: 0.8)),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _actionButton(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 14),
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  String _formatDate(String date) {
    if (date.contains('-') && date.split('-')[0].length == 4) {
      final parts = date.split('-');
      return '${parts[2]}/${parts[1]}/${parts[0]}';
    }
    return date;
  }
}
