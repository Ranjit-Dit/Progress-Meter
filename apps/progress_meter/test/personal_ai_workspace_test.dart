import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progress_meter/app/app.dart';
import 'package:progress_meter/app/progress_controller.dart';
import 'package:progress_meter/features/progress/data/progress_repository.dart';
import 'package:progress_meter/features/progress/domain/models.dart';

class _Store implements ProgressRepository {
  ProgressData data = ProgressData(studentName: 'Test student');
  var writes = 0;
  @override
  Future<ProgressData?> load() async => data;
  @override
  Future<void> save(ProgressData value) async {
    writes++;
    data = value;
  }
}

Future<void> _tap(WidgetTester t, Finder target) async {
  await t.ensureVisible(target);
  await t.pumpAndSettle();
  await t.tap(target);
  await t.pumpAndSettle();
}

Future<void> _page(WidgetTester t, String title) async {
  await _tap(t, find.byTooltip('Open navigation'));
  await _tap(
    t,
    find.descendant(of: find.byType(Drawer), matching: find.text(title)),
  );
}

void main() {
  testWidgets(
    'personal settings route AI features and are excluded from saved workspace',
    (t) async {
      t.view.devicePixelRatio = 1;
      t.view.physicalSize = const Size(390, 844);
      addTearDown(t.view.reset);
      final store = _Store();
      final controller = ProgressController(store);
      await controller.initialize();
      addTearDown(controller.dispose);
      await t.pumpWidget(ProgressMeterApp(controller: controller));
      await t.pumpAndSettle();
      await _page(t, 'Settings');
      await _tap(t, find.byKey(const Key('ai-provider-configure')));
      final model = find.byKey(const Key('personal-ai-model'));
      final key = find.byKey(const Key('personal-ai-key'));
      await t.ensureVisible(model);
      await t.enterText(model, 'my-private-model');
      await t.ensureVisible(key);
      await t.enterText(key, 'synthetic-user-owned-secret');
      await _tap(t, find.byKey(const Key('personal-ai-use')));
      expect(find.text('OpenAI · my-private-model'), findsOneWidget);
      expect(store.writes, 0);
      expect(
        jsonEncode(controller.data.toJson()),
        isNot(contains('synthetic-user-owned-secret')),
      );
      await _page(t, 'AI Coach');
      expect(find.textContaining('Personal AI configured'), findsOneWidget);
      expect(find.byKey(const Key('coach-personal-ai')), findsOneWidget);
      await _page(t, 'Testing Lab');
      expect(find.textContaining('Personal AI configured'), findsOneWidget);
      expect(find.byKey(const Key('lab-personal-ai')), findsOneWidget);
      await _page(t, 'Settings');
      await _tap(t, find.byKey(const Key('ai-provider-configure')));
      await _tap(t, find.byKey(const Key('personal-ai-backend')));
      expect(find.text('Using the app backend'), findsOneWidget);
      expect(store.writes, 0);
      expect(t.takeException(), isNull);
    },
  );
}
