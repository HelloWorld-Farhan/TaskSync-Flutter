import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'screens/dashboard.dart';
import 'services/alarm_service.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';
import 'screens/routine_alarm_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AndroidAlarmManager.initialize();
  await NotificationService.initialize();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Attempt to process any pending offline emails on startup
  retryCallback(0);

  // Check if launched by notification
  final NotificationAppLaunchDetails? notificationAppLaunchDetails =
      await NotificationService.flutterLocalNotificationsPlugin
          .getNotificationAppLaunchDetails();

  String? initialRoute;
  if (notificationAppLaunchDetails?.didNotificationLaunchApp ?? false) {
    if (notificationAppLaunchDetails?.notificationResponse?.payload != null) {
      initialRoute =
          notificationAppLaunchDetails!.notificationResponse!.payload;
    }
  }

  runApp(TaskSyncApp(initialRoutePayload: initialRoute));
}

class TaskSyncApp extends StatelessWidget {
  final String? initialRoutePayload;
  const TaskSyncApp({super.key, this.initialRoutePayload});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'TaskSync',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: _getInitialScreen(),
    );
  }

  Widget _getInitialScreen() {
    if (initialRoutePayload != null &&
        initialRoutePayload!.startsWith('routine_')) {
      final parts = initialRoutePayload!.split('_');
      if (parts.length == 3) {
        int routineId = int.tryParse(parts[1]) ?? 0;
        int type = int.tryParse(parts[2]) ?? 0;
        return RoutineAlarmScreen(routineId: routineId, alarmType: type);
      }
    }
    return const SplashScreen();
  }
}

// ─── Splash Screen — Crimson Velvet ──────────────────────────────────────────

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _bgController;
  late AnimationController _pulseController;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _bgController =
        AnimationController(vsync: this, duration: const Duration(seconds: 5))
          ..repeat(reverse: true);
    _pulseController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.95, end: 1.06).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 800),
          pageBuilder: (_, __, ___) => const DashboardScreen(),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(
                  CurvedAnimation(parent: animation, curve: Curves.easeOut)),
              child: child,
            ),
          ),
        ));
      }
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, child) => Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: const [
                Color(0xFF1A0A0D),
                Color(0xFF3D1519),
                Color(0xFF1A0A0D),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: [0.0, _bgController.value.clamp(0.3, 0.7), 1.0],
            ),
          ),
          child: child,
        ),
        child: Stack(children: [
          // Crimson glow orbs
          Positioned(
              top: -100,
              right: -80,
              child: _Orb(color: AppColors.accent, size: 300, opacity: 0.22)),
          Positioned(
              bottom: -120,
              left: -100,
              child: _Orb(color: AppColors.primary, size: 350, opacity: 0.18)),
          Positioned(
              top: 180,
              left: -50,
              child:
                  _Orb(color: AppColors.primaryGlow, size: 180, opacity: 0.12)),
          Positioned(
              bottom: 200,
              right: -40,
              child:
                  _Orb(color: AppColors.accentLight, size: 140, opacity: 0.10)),

          SafeArea(
            child: Center(
              child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Pulsing logo
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (_, child) =>
                          Transform.scale(scale: _pulse.value, child: child),
                      child: Stack(alignment: Alignment.center, children: [
                        // Expanding ring 1
                        Container(
                            width: 160,
                            height: 160,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppColors.accent
                                        .withValues(alpha: 0.20),
                                    width: 2)))
                            .animate(onPlay: (c) => c.repeat())
                            .scaleXY(
                                begin: 1.0,
                                end: 1.18,
                                duration: 1600.ms,
                                curve: Curves.easeOut)
                            .fadeOut(duration: 1600.ms),
                        // Expanding ring 2
                        Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: AppColors.primaryGlow
                                        .withValues(alpha: 0.15),
                                    width: 1.5)))
                            .animate(onPlay: (c) => c.repeat())
                            .scaleXY(
                                begin: 1.0,
                                end: 1.12,
                                duration: 2000.ms,
                                curve: Curves.easeOut)
                            .fadeOut(duration: 2000.ms),
                        // Logo box
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(32),
                            boxShadow: [
                              BoxShadow(
                                  color: AppColors.accent.withValues(alpha: 0.5),
                                  blurRadius: 40,
                                  spreadRadius: 8,
                                  offset: const Offset(0, 8)),
                              BoxShadow(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  spreadRadius: 2),
                            ],
                          ),
                          child: Center(
                              child:
                                  Image.asset('Logo.png', width: 76, height: 76)),
                        ),
                      ]),
                    )
                        .animate()
                        .scale(
                            begin: const Offset(0.3, 0.3),
                            end: const Offset(1, 1),
                            duration: 800.ms,
                            curve: Curves.elasticOut)
                        .fadeIn(duration: 500.ms),

                    const SizedBox(height: 40),

                    ShaderMask(
                      shaderCallback: (bounds) =>
                          AppColors.accentGradient.createShader(bounds),
                      child: Text('TaskSync',
                          style: GoogleFonts.outfit(
                              fontSize: 42,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.5,
                              color: Colors.white)),
                    )
                        .animate()
                        .fade(delay: 400.ms, duration: 600.ms)
                        .slideY(
                            begin: 0.3,
                            end: 0,
                            delay: 400.ms,
                            duration: 600.ms,
                            curve: Curves.easeOut),

                    const SizedBox(height: 10),

                    Text('Sync your day, perfectly.',
                        style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.5))
                        .animate()
                        .fade(delay: 700.ms, duration: 500.ms)
                        .slideY(
                            begin: 0.3,
                            end: 0,
                            delay: 700.ms,
                            duration: 500.ms,
                            curve: Curves.easeOut),

                    const SizedBox(height: 56),
                    _ShimmerLine()
                        .animate()
                        .fade(delay: 1000.ms, duration: 400.ms),
                  ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;
  const _Orb(
      {required this.color, required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(colors: [
          color.withValues(alpha: opacity),
          color.withValues(alpha: 0),
        ]),
      ),
    );
  }
}

class _ShimmerLine extends StatefulWidget {
  @override
  State<_ShimmerLine> createState() => _ShimmerLineState();
}

class _ShimmerLineState extends State<_ShimmerLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
    _anim = Tween<double>(begin: -1.5, end: 2.5)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 4,
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [
                Color(0xFF2C0F12),
                Color(0xFF9B3A41),
                Color(0xFFC0464F),
                Color(0xFF2C0F12),
              ],
              stops: [
                (_anim.value - 0.5).clamp(0.0, 1.0),
                (_anim.value).clamp(0.0, 1.0),
                (_anim.value + 0.1).clamp(0.0, 1.0),
                (_anim.value + 0.5).clamp(0.0, 1.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
