// This screen is kept for future standalone use.
// The main scoreboard is now shown as a bottom sheet from the dashboard.
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ScoreboardScreen extends StatelessWidget {
  const ScoreboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgDeep,
      appBar: AppBar(
        backgroundColor: AppColors.bgMid,
        title: const Text('Scoreboard', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppColors.textSecondary),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppColors.border),
        ),
      ),
      body: const Center(
        child: Text('Tap the score badge on the home screen to view your scoreboard.',
            style: TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
      ),
    );
  }
}
