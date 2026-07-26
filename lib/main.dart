import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'screens/dashboard.dart';
import 'services/alarm_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AndroidAlarmManager.initialize();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Attempt to process any pending offline emails on startup
  retryCallback(0);

  runApp(const TaskSyncApp());
}

class TaskSyncApp extends StatelessWidget {
  const TaskSyncApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TaskSync',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const SplashScreen(),
    );
  }
}

// ─── Splash Screen ───────────────────────────────────────────────────────────

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

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulse = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 700),
            pageBuilder: (_, __, ___) => const DashboardScreen(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.08),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                  ),
                  child: child,
                ),
              );
            },
          ),
        );
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
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: const [
                  Color(0xFF0A0E1A),
                  Color(0xFF130D2E),
                  Color(0xFF071828),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [
                  0.0,
                  _bgController.value,
                  1.0,
                ],
              ),
            ),
            child: child,
          );
        },
        child: Stack(
          children: [
            // Decorative blurred orbs
            Positioned(
              top: -80,
              right: -60,
              child: _Orb(color: const Color(0xFF7C3AED), size: 280, opacity: 0.18),
            ),
            Positioned(
              bottom: -100,
              left: -80,
              child: _Orb(color: const Color(0xFF06B6D4), size: 320, opacity: 0.12),
            ),
            Positioned(
              top: 200,
              left: -40,
              child: _Orb(color: const Color(0xFF4F46E5), size: 160, opacity: 0.10),
            ),

            // Main content
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Pulsing ring around logo
                    AnimatedBuilder(
                      animation: _pulse,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pulse.value,
                          child: child,
                        );
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer glow ring
                          Container(
                            width: 148,
                            height: 148,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF7C3AED).withValues(alpha: 0.25),
                                width: 2,
                              ),
                            ),
                          )
                              .animate(onPlay: (c) => c.repeat())
                              .scaleXY(
                                begin: 1.0,
                                end: 1.15,
                                duration: 1800.ms,
                                curve: Curves.easeOut,
                              )
                              .fadeOut(duration: 1800.ms),
                          // Logo container
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(32),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF7C3AED).withValues(alpha: 0.5),
                                  blurRadius: 30,
                                  spreadRadius: 5,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Image.asset(
                                'Logo.png',
                                width: 76,
                                height: 76,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .scale(
                          begin: const Offset(0.3, 0.3),
                          end: const Offset(1, 1),
                          duration: 700.ms,
                          curve: Curves.elasticOut,
                        )
                        .fadeIn(duration: 400.ms),

                    const SizedBox(height: 36),

                    // App name
                    Text(
                      'TaskSync',
                      style: GoogleFonts.outfit(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.5,
                        color: Colors.white,
                      ),
                    )
                        .animate()
                        .fade(delay: 350.ms, duration: 500.ms)
                        .slideY(begin: 0.4, end: 0, delay: 350.ms, duration: 500.ms, curve: Curves.easeOut),

                    const SizedBox(height: 10),

                    // Tagline
                    Text(
                      'Sync your day, perfectly.',
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: const Color(0xFF94A3B8),
                        letterSpacing: 0.4,
                      ),
                    )
                        .animate()
                        .fade(delay: 600.ms, duration: 500.ms)
                        .slideY(begin: 0.4, end: 0, delay: 600.ms, duration: 500.ms, curve: Curves.easeOut),

                    const SizedBox(height: 48),

                    // Shimmer line loader
                    _ShimmerLine()
                        .animate()
                        .fade(delay: 900.ms, duration: 400.ms),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;

  const _Orb({required this.color, required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: 0),
          ],
        ),
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
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
    _anim = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
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
                Color(0xFF1A2035),
                Color(0xFFA78BFA),
                Color(0xFF06B6D4),
                Color(0xFF1A2035),
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
