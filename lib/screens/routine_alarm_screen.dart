import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import '../services/database_helper.dart';
import '../services/notification_service.dart';
import '../theme/app_theme.dart';
import 'dashboard.dart';

class RoutineAlarmScreen extends StatefulWidget {
  final int routineId;
  final int alarmType; // 1 = start, 2 = end
  final bool autoConfirmDone;

  const RoutineAlarmScreen({
    super.key,
    required this.routineId,
    required this.alarmType,
    this.autoConfirmDone = false,
  });

  @override
  State<RoutineAlarmScreen> createState() => _RoutineAlarmScreenState();
}

class _RoutineAlarmScreenState extends State<RoutineAlarmScreen>
    with SingleTickerProviderStateMixin {
  Map<String, dynamic>? routine;
  Timer? _ringTimer;
  Timer? _progressTimer;
  Timer? _deductionTimer;
  late AnimationController _pulseController;

  bool _alarmStopped = false;
  bool _responded = false;

  // Countdown for alarm auto-stop
  int _alarmSecondsLeft = 15;

  // For end-alarm deduction tracking
  DateTime? _endAlarmFiredAt;
  double _currentScore = 100.0;
  int _minutesLate = 0;

  // Progress timer for start alarm
  String _progressText = '';
  int _minutesRemaining = 0;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _loadRoutineAndStart();
  }

  Future<void> _loadRoutineAndStart() async {
    final data = await DatabaseHelper.instance.getRoutine(widget.routineId);
    if (!mounted) return;
    setState(() => routine = data);

    if (widget.autoConfirmDone) {
      // Came from persistent notification "Done" button
      await Future.delayed(const Duration(milliseconds: 300));
      _handleDone();
      return;
    }

    // Play calling ringtone
    FlutterRingtonePlayer().playRingtone();

    // Countdown to auto-stop alarm after 10 seconds
    _ringTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() => _alarmSecondsLeft--);
      if (_alarmSecondsLeft <= 0) {
        _stopRingtone();
        timer.cancel();
        // For END alarm — if user hasn't responded after alarm stops, start deduction timer
        if (widget.alarmType == 2 && !_responded) {
          _startDeductionTimer();
        }
      }
    });

    // For END alarm — record when it fired
    if (widget.alarmType == 2) {
      _endAlarmFiredAt = DateTime.now();
    }
  }

  void _stopRingtone() {
    FlutterRingtonePlayer().stop();
    _alarmStopped = true;
  }

  void _startProgressNotification(Map<String, dynamic> r) {
    // Calculate minutes remaining until end time
    final now = DateTime.now();
    final endParts = r['end_time'].toString().split(':');
    final endTime = DateTime(now.year, now.month, now.day,
        int.parse(endParts[0]), int.parse(endParts[1]));
    _minutesRemaining = endTime.difference(now).inMinutes.clamp(0, 1440);

    NotificationService.showRoutineProgressNotification(
      id: widget.routineId * 100 + 99,
      routineTitle: r['title'],
      endTimeStr: r['end_time'],
      payload: 'routine_${widget.routineId}_2',
      endTimeObj: endTime,
    );
  }

  void _startDeductionTimer() {
    // Deduct 0.01 pts per minute after alarm fires and no response
    _deductionTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted || _responded) { _deductionTimer?.cancel(); return; }
      setState(() {
        _minutesLate++;
        _currentScore = (100.0 - (_minutesLate * 0.01)).clamp(0.0, 100.0);
      });
    });
  }

  Future<void> _handleDone() async {
    if (_responded) return;
    _responded = true;

    _stopRingtone();
    _ringTimer?.cancel();
    _deductionTimer?.cancel();

    // Cancel progress notification
    await NotificationService.cancelNotification(widget.routineId * 100 + 99);

    if (routine != null) {
      final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final int scoreToGive = _currentScore.round();

      var history = await DatabaseHelper.instance
          .getRoutineHistoryByDate(widget.routineId, today);

      if (history == null) {
        await DatabaseHelper.instance.createRoutineHistory({
          'routine_id': widget.routineId,
          'date': today,
          'completed_start': widget.alarmType == 1 ? 1 : 0,
          'completed_end': widget.alarmType == 2 ? 1 : 0,
          'score': widget.alarmType == 2 ? scoreToGive : 0,
        });
      } else {
        final updated = Map<String, dynamic>.from(history);
        if (widget.alarmType == 1) {
          updated['completed_start'] = 1;
        } else {
          updated['completed_end'] = 1;
          updated['score'] = scoreToGive;
        }
        await DatabaseHelper.instance.updateRoutineHistory(updated);
      }
    }

    if (mounted) {
      _showResult(true, _currentScore.round());
    }
  }

  Future<void> _handleNotDone() async {
    if (_responded) return;
    _responded = true;

    _stopRingtone();
    _ringTimer?.cancel();
    _deductionTimer?.cancel();

    // Cancel progress notification
    await NotificationService.cancelNotification(widget.routineId * 100 + 99);

    if (routine != null && widget.alarmType == 2) {
      final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      var history = await DatabaseHelper.instance
          .getRoutineHistoryByDate(widget.routineId, today);

      if (history == null) {
        await DatabaseHelper.instance.createRoutineHistory({
          'routine_id': widget.routineId,
          'date': today,
          'completed_start': 0,
          'completed_end': 0,
          'score': 0, // 0 for declining
        });
      } else {
        final updated = Map<String, dynamic>.from(history);
        updated['completed_end'] = 0;
        updated['score'] = 0;
        await DatabaseHelper.instance.updateRoutineHistory(updated);
      }
    }

    if (mounted) {
      _showResult(false, 0);
    }
  }

  void _dismissStartAlarm() {
    _stopRingtone();
    _ringTimer?.cancel();
    if (mounted) Navigator.pop(context);
    SystemNavigator.pop();
  }

  void _showResult(bool isDone, int points) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDone ? AppColors.success.withValues(alpha: 0.1) : AppColors.danger.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(isDone ? Icons.check_circle_rounded : Icons.cancel_rounded,
                  color: isDone ? AppColors.success : AppColors.danger, size: 56),
            ).animate()
             .scale(duration: 400.ms, curve: Curves.easeOutBack)
             .moveY(begin: 30, end: 0, duration: 400.ms),
          const SizedBox(height: 16),
          Text(isDone ? 'Great Work!' : 'Routine Missed',
              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 20)),
          const SizedBox(height: 8),
          Text(isDone ? '+$points points earned' : '0 points — Better luck next time!',
              style: TextStyle(color: isDone ? AppColors.success : AppColors.danger,
                  fontWeight: FontWeight.w600, fontSize: 15))
            .animate(delay: 200.ms)
            .fadeIn(duration: 300.ms)
            .moveY(begin: 10, end: 0, duration: 300.ms),
          if (isDone && _minutesLate > 0) ...[
            const SizedBox(height: 4),
            Text('(${_minutesLate} min late: -${(_minutesLate * 0.01).toStringAsFixed(2)} pts)',
                style: const TextStyle(color: AppColors.textMuted, fontSize: 12)),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context); // Close dialog
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const DashboardScreen()),
                  (route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isDone ? AppColors.success : AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('OK', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ringTimer?.cancel();
    _progressTimer?.cancel();
    _deductionTimer?.cancel();
    if (!_alarmStopped) FlutterRingtonePlayer().stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isStartAlarm = widget.alarmType == 1;

    return PopScope(
      canPop: false, // Prevent back button from dismissing
      onPopInvokedWithResult: (didPop, result) {
        // Intercept hardware back — only allow if responded
        if (_responded) Navigator.pop(context);
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: Scaffold(
          backgroundColor: AppColors.bgDeep,
          body: SafeArea(
            child: routine == null
                ? const Center(child: CircularProgressIndicator(color: AppColors.accent))
                : _buildAlarmUI(isStartAlarm),
          ),
        ),
      ),
    );
  }

  Widget _buildAlarmUI(bool isStartAlarm) {
    final r = routine!;

    return Column(children: [
      // Top header
      Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        child: Column(children: [
          Text(
            DateFormat('EEEE, d MMM yyyy').format(DateTime.now()),
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            DateFormat('HH:mm').format(DateTime.now()),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 18, fontWeight: FontWeight.w600),
          ),
        ]),
      ),

      Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        // Pulsing alarm icon
        AnimatedBuilder(
          animation: _pulseController,
          builder: (_, child) => Transform.scale(
            scale: 1.0 + (_pulseController.value * 0.1),
            child: child,
          ),
          child: Container(
            width: 130, height: 130,
            decoration: BoxDecoration(
              gradient: isStartAlarm ? AppColors.primaryGradient : AppColors.accentGradient,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(
                color: (isStartAlarm ? AppColors.primary : AppColors.accent).withValues(alpha: 0.5),
                blurRadius: 40,
                spreadRadius: 5,
              )],
            ),
            child: Icon(
              isStartAlarm ? Icons.play_arrow_rounded : Icons.stop_rounded,
              color: Colors.white,
              size: 64,
            ),
          ),
        ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),

        const SizedBox(height: 32),

        // Alarm type label
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: (isStartAlarm ? AppColors.primary : AppColors.accent).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: (isStartAlarm ? AppColors.primary : AppColors.accent).withValues(alpha: 0.3)),
          ),
          child: Text(
            isStartAlarm ? '🔔 START ROUTINE' : '⏰ ROUTINE COMPLETE?',
            style: TextStyle(
              color: isStartAlarm ? AppColors.primaryGlow : AppColors.accent,
              fontWeight: FontWeight.w800,
              fontSize: 13,
              letterSpacing: 1.2,
            ),
          ),
        ).animate().fadeIn(duration: 400.ms, delay: 200.ms),

        const SizedBox(height: 20),

        // Routine name
        Text(
          r['title'],
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 32, fontWeight: FontWeight.w900),
          textAlign: TextAlign.center,
        ).animate().fadeIn(duration: 400.ms, delay: 300.ms),

        const SizedBox(height: 8),

        // Time info
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.access_time_rounded, size: 16, color: AppColors.textMuted),
          const SizedBox(width: 6),
          Text(
            '${r['start_time']} – ${r['end_time']}',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 16),
          ),
        ]).animate().fadeIn(duration: 400.ms, delay: 400.ms),

        const SizedBox(height: 12),

        // Score display for end alarm
        if (!isStartAlarm) Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: AppColors.scoreGradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 12)],
          ),
          child: Column(children: [
            Text('Current Score', style: const TextStyle(color: Colors.white70, fontSize: 12)),
            Text('${_currentScore.toStringAsFixed(1)} pts',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 28)),
            if (_minutesLate > 0)
              Text('-${(_minutesLate * 0.01).toStringAsFixed(2)} pts (${_minutesLate} min late)',
                  style: const TextStyle(color: Colors.white60, fontSize: 11)),
          ]),
        ).animate().fadeIn(duration: 400.ms, delay: 500.ms),

        // Alarm countdown
        if (!_alarmStopped) Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(
            'Alarm stops in $_alarmSecondsLeft sec...',
            style: const TextStyle(color: AppColors.textMuted, fontSize: 13),
          ),
        ),
      ])),

      // Action buttons
      Container(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        child: isStartAlarm ? _buildStartButtons() : _buildEndButtons(),
      ).animate().slideY(begin: 0.3, duration: 500.ms, delay: 400.ms, curve: Curves.easeOut),
    ]);
  }

  Widget _buildStartButtons() {
    return Row(children: [
      // Dismiss
      Expanded(child: OutlinedButton.icon(
        icon: const Icon(Icons.close_rounded, size: 20),
        label: const Text('Close Alarm'),
        onPressed: _dismissStartAlarm,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textSecondary,
          side: const BorderSide(color: AppColors.border, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      )),
      const SizedBox(width: 12),
      // Got it
      Expanded(flex: 2, child: ElevatedButton.icon(
        icon: const Icon(Icons.thumb_up_rounded, size: 20),
        label: const Text('Got It! Starting Now'),
        onPressed: _dismissStartAlarm,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      )),
    ]);
  }

  Widget _buildEndButtons() {
    return Column(children: [
      // Done button
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          icon: const Icon(Icons.check_circle_rounded, size: 22),
          label: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('✅  Work Done!', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text('Earn ${_currentScore.toStringAsFixed(0)} points',
                style: const TextStyle(fontSize: 12, color: Colors.white70)),
          ]),
          onPressed: _handleDone,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            elevation: 0,
          ),
        ),
      ),
      const SizedBox(height: 12),
      // Not done button
      SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.cancel_outlined, size: 22),
          label: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('❌  Not Done', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            Text('0 points — routine missed', style: TextStyle(fontSize: 12)),
          ]),
          onPressed: _handleNotTone,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.danger,
            side: const BorderSide(color: AppColors.danger, width: 1.5),
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
      ),
    ]);
  }

  void _handleNotTone() => _handleNotDone();
}
