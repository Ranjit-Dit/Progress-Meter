import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app/app.dart';
import 'app/progress_controller.dart';
import 'features/progress/data/progress_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    final directory = await getApplicationSupportDirectory();
    final controller = ProgressController(
      JsonProgressRepository(File('${directory.path}/progress_v1.json')),
    );
    await controller.initialize();
    runApp(ProgressMeterApp(controller: controller));
  } catch (error) {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: SelectableText(
                'Your progress could not be opened.\nYour saved file has been preserved.\n\n$error',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
