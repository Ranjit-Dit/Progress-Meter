import '../features/assessment/application/ai_judgment_controller.dart';
import '../features/notifications/application/notification_controller.dart';

import 'package:flutter/material.dart';

import '../common/app_theme.dart';
import '../features/progress/presentation/workspace.dart';
import 'progress_controller.dart';
import '../features/ai_coach/application/coach_controller.dart';
import '../features/testing_lab/application/lab_controller.dart';
import '../features/benchmark_research/application/benchmark_controller.dart';

class ProgressMeterApp extends StatelessWidget {
  const ProgressMeterApp({
    super.key,
    required this.controller,
    this.coachController,
    this.labController,
    this.benchmarkController,
    this.judgmentController,
    this.notificationController,
  });
  final ProgressController controller;
  final CoachController? coachController;
  final LabController? labController;
  final BenchmarkResearchController? benchmarkController;
  final AiJudgmentController? judgmentController;
  final NotificationController? notificationController;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Progress Meter',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: ProgressWorkspace(
      controller: controller,
      coachController: coachController,
      labController: labController,
      benchmarkController: benchmarkController,
      judgmentController: judgmentController,
      notificationController: notificationController,
    ),
  );
}
