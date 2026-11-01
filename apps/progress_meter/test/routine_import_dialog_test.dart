import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progress_meter/app/progress_controller.dart';
import 'package:progress_meter/common/app_theme.dart';
import 'package:progress_meter/features/progress/data/progress_repository.dart';
import 'package:progress_meter/features/progress/domain/models.dart';
import 'package:progress_meter/features/routine_import/data/document_import_service.dart';
import 'package:progress_meter/features/routine_import/domain/import_models.dart';
import 'package:progress_meter/features/routine_import/presentation/routine_import_dialog.dart';
import 'package:progress_meter/features/routines/domain/routine_models.dart';

class _Repo implements ProgressRepository {
  ProgressData data = ProgressData();
  bool fail = false;
  @override
  Future<ProgressData?> load() async => data;
  @override
  Future<void> save(ProgressData value) async {
    if (fail) throw StateError('disk');
    data = value;
  }
}

class _Service implements RoutineImportService {
  _Service(this.drafts);
  final List<ImportDraft> drafts;
  bool fail = false, cancel = false;
  @override
  Future<SelectedRoutineFile?> pickFile() async => cancel
      ? null
      : SelectedRoutineFile(name: 'schedule.pdf', bytes: Uint8List(1));
  @override
  Future<ImportResult> extract(
    SelectedRoutineFile file, {
    required RoutineKind defaultKind,
  }) async {
    if (fail) throw const ImportFailure('test', 'Try a clearer image.');
    return ImportResult(drafts: drafts);
  }
}

ImportDraft _draft(String id, {bool valid = true}) => ImportDraft(
  id: id,
  title: 'Algorithms',
  kind: RoutineKind.classSession,
  weekdays: valid ? {1} : {},
  startMinutes: valid ? 540 : null,
  endMinutes: valid ? 600 : null,
);
Future<ProgressController> _open(
  WidgetTester tester,
  _Repo repo,
  _Service service, {
  Size size = const Size(1000, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final c = ProgressController(repo);
  await c.initialize();
  addTearDown(c.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showRoutineImportDialog(
              context,
              controller: c,
              service: service,
            ),
            child: const Text('Open importer'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open importer'));
  await tester.pumpAndSettle();
  return c;
}

Future<void> _pick(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('import-choose-file')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('preview is editable, saves one batch and skips repeats', (
    tester,
  ) async {
    final repo = _Repo();
    final c = await _open(tester, repo, _Service([_draft('a'), _draft('b')]));
    await _pick(tester);
    expect(find.text('Import 1 routine'), findsOneWidget);
    expect(find.text('Already in your plan or selected above'), findsOneWidget);
    expect(c.data.routines, isEmpty);
    await tester.tap(find.byKey(const Key('import-save')));
    await tester.pumpAndSettle();
    expect(c.data.routines, hasLength(1));
    expect(find.text('Import your routine'), findsNothing);
  });
  testWidgets('missing times and days stay empty until corrected', (
    tester,
  ) async {
    final c = await _open(
      tester,
      _Repo(),
      _Service([_draft('a', valid: false)]),
    );
    await _pick(tester);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('import-save')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('import-edit-a')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('import-edit-start')))
          .controller!
          .text,
      isEmpty,
    );
    await tester.tap(find.byKey(const Key('import-edit-day-2')));
    await tester.enterText(find.byKey(const Key('import-edit-start')), '14:00');
    await tester.enterText(find.byKey(const Key('import-edit-end')), '15:00');
    await tester.tap(find.byKey(const Key('import-edit-apply')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('import-save')));
    await tester.pumpAndSettle();
    expect(c.data.routines.single.weekdays, {2});
    expect(c.data.routines.single.startMinutes, 840);
  });
  testWidgets('failure can retry; cancelling preview never changes routines', (
    tester,
  ) async {
    final service = _Service([_draft('a')])..fail = true;
    final c = await _open(tester, _Repo(), service);
    await _pick(tester);
    expect(find.text('Try a clearer image.'), findsOneWidget);
    service.fail = false;
    await _pick(tester);
    await tester.tap(find.byKey(const Key('import-cancel')));
    await tester.pumpAndSettle();
    expect(c.data.routines, isEmpty);
  });
  testWidgets('failed save retains preview and original plan', (tester) async {
    final repo = _Repo()..fail = true;
    final c = await _open(tester, repo, _Service([_draft('a')]));
    await _pick(tester);
    await tester.tap(find.byKey(const Key('import-save')));
    await tester.pumpAndSettle();
    expect(c.data.routines, isEmpty);
    expect(find.textContaining('could not be saved'), findsOneWidget);
    repo.fail = false;
    await tester.tap(find.byKey(const Key('import-save')));
    await tester.pumpAndSettle();
    expect(c.data.routines, hasLength(1));
  });
  testWidgets('narrow window shows picker and preview without overflow', (
    tester,
  ) async {
    await _open(
      tester,
      _Repo(),
      _Service([_draft('a')]),
      size: const Size(440, 720),
    );
    expect(tester.takeException(), isNull);
    await _pick(tester);
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('import-save')), findsOneWidget);
  });
}
