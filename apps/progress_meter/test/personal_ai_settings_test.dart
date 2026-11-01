import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progress_meter/common/app_theme.dart';
import 'package:progress_meter/features/ai_connection/domain/ai_provider.dart';
import 'package:progress_meter/features/ai_connection/presentation/ai_provider_settings.dart';

class _Selection {
  AiProviderSelection? value;
  bool completed = false;
}

Future<_Selection> _open(
  WidgetTester tester, {
  AiProviderConfig? current,
  Future<void> Function(AiProviderConfig)? testConnection,
  Size size = const Size(900, 1000),
  double textScale = 1,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final selection = _Selection();
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              selection.value = await showAiProviderSettings(
                context,
                current: current,
                testConnection: testConnection,
              );
              selection.completed = true;
            },
            child: const Text('Open personal AI'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open personal AI'));
  await tester.pumpAndSettle();
  return selection;
}

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(Key(key));
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> _fill(
  WidgetTester tester, {
  String model = 'my-text-model',
  String key = 'personal-secret-value',
}) async {
  await tester.ensureVisible(find.byKey(const Key('personal-ai-model')));
  await tester.enterText(find.byKey(const Key('personal-ai-model')), model);
  await tester.ensureVisible(find.byKey(const Key('personal-ai-key')));
  await tester.enterText(find.byKey(const Key('personal-ai-key')), key);
  await tester.pumpAndSettle();
}

Future<void> _provider(WidgetTester tester, AiProvider provider) async {
  await _tap(tester, 'personal-ai-provider');
  await tester.tap(find.text(provider.label).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('personal settings validate fields and keep the key obscured', (
    tester,
  ) async {
    final selection = await _open(tester);
    final keyField = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('personal-ai-key')),
        matching: find.byType(TextField),
      ),
    );
    expect(keyField.obscureText, isTrue);
    expect(keyField.autocorrect, isFalse);
    expect(keyField.enableSuggestions, isFalse);
    expect(find.textContaining('excluded from backups'), findsOneWidget);
    await _tap(tester, 'personal-ai-use');
    expect(selection.completed, isFalse);
    expect(find.text('Enter a model ID.'), findsOneWidget);
    expect(find.text('Paste your API key.'), findsOneWidget);

    await _fill(tester);
    await _tap(tester, 'personal-ai-use');
    expect(selection.completed, isTrue);
    expect(selection.value!.config!.provider, AiProvider.openai);
    expect(selection.value!.config!.model, 'my-text-model');
    expect(selection.value!.config!.apiKey, 'personal-secret-value');
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing providers clears the typed credential', (tester) async {
    await _open(tester);
    await _fill(tester);
    await _provider(tester, AiProvider.anthropic);
    final keyField = tester.widget<TextFormField>(
      find.byKey(const Key('personal-ai-key')),
    );
    expect(keyField.controller!.text, isEmpty);
    final notice = tester.widget<Text>(
      find.byKey(const Key('personal-ai-privacy')),
    );
    expect(notice.data, contains('api.anthropic.com'));
    expect(notice.data, isNot(contains('personal-secret-value')));
    expect(tester.takeException(), isNull);
  });

  testWidgets('custom connections require a valid HTTPS endpoint', (
    tester,
  ) async {
    final selection = await _open(tester);
    await _provider(tester, AiProvider.custom);
    final endpoint = find.byKey(const Key('personal-ai-base-url'));
    await tester.ensureVisible(endpoint);
    await tester.enterText(endpoint, 'http://example.com/v1');
    await _fill(tester);
    await _tap(tester, 'personal-ai-use');
    expect(selection.completed, isFalse);
    expect(find.textContaining('Enter an HTTPS base URL'), findsOneWidget);

    await tester.ensureVisible(endpoint);
    await tester.enterText(endpoint, 'https://models.example/v1');
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('personal-ai-key')))
          .controller!
          .text,
      isEmpty,
      reason: 'Changing a host requires a new credential paste.',
    );
    await _fill(tester, key: 'custom-personal-key');
    await _tap(tester, 'personal-ai-use');
    expect(selection.value!.config!.provider, AiProvider.custom);
    expect(
      selection.value!.config!.baseUrl,
      Uri.parse('https://models.example/v1'),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('connection checks are explicit and cleared after edits', (
    tester,
  ) async {
    var calls = 0;
    final selection = await _open(
      tester,
      testConnection: (config) async {
        calls++;
        expect(config.apiKey, 'personal-secret-value');
      },
    );
    expect(calls, 0);
    await _fill(tester);
    expect(calls, 0);
    await _tap(tester, 'personal-ai-test');
    expect(calls, 1);
    expect(find.byKey(const Key('personal-ai-verified')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('personal-ai-model')));
    await tester.enterText(
      find.byKey(const Key('personal-ai-model')),
      'another-text-model',
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('personal-ai-verified')), findsNothing);
    expect(selection.completed, isFalse);
  });

  testWidgets('provider failures never show arbitrary error text', (
    tester,
  ) async {
    await _open(
      tester,
      testConnection: (_) async {
        throw StateError('upstream exposed personal-secret-value');
      },
    );
    await _fill(tester);
    await _tap(tester, 'personal-ai-test');
    final error = tester.widget<Text>(
      find.byKey(const Key('personal-ai-error')),
    );
    expect(error.data, contains('Could not verify'));
    expect(error.data, isNot(contains('personal-secret-value')));
    expect(error.data, isNot(contains('upstream exposed')));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'pending checks lock the form and ignore completion after close',
    (tester) async {
      final pending = Completer<void>();
      await _open(tester, testConnection: (_) => pending.future);
      await _fill(tester);
      final test = find.byKey(const Key('personal-ai-test'));
      await tester.ensureVisible(test);
      await tester.tap(test);
      await tester.pump();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('personal-ai-model')))
            .enabled,
        isFalse,
      );
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('personal-ai-use')))
            .onPressed,
        isNull,
      );
      expect(
        tester
            .widget<IconButton>(find.byKey(const Key('personal-ai-close')))
            .onPressed,
        isNull,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      pending.complete();
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cancel preserves the connection and backend is a distinct choice',
    (tester) async {
      final config = AiProviderConfig(
        provider: AiProvider.openai,
        model: 'saved-session-model',
        apiKey: 'saved-session-key',
      );
      final cancelled = await _open(tester, current: config);
      await _fill(tester, model: 'unsaved-model', key: 'unsaved-key');
      await _tap(tester, 'personal-ai-close');
      expect(cancelled.completed, isTrue);
      expect(cancelled.value, isNull);
      expect(config.model, 'saved-session-model');
      expect(config.apiKey, 'saved-session-key');

      final backend = await _open(tester, current: config);
      await _tap(tester, 'personal-ai-backend');
      expect(backend.completed, isTrue);
      expect(backend.value, isNotNull);
      expect(backend.value!.config, isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('personal AI settings fit a phone keyboard with larger text', (
    tester,
  ) async {
    final selection = await _open(
      tester,
      size: const Size(390, 844),
      textScale: 1.6,
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 310);
    await tester.pumpAndSettle();
    await _fill(tester);
    final use = find.byKey(const Key('personal-ai-use'));
    await tester.ensureVisible(use);
    await tester.pumpAndSettle();
    expect(tester.getRect(use).bottom, lessThanOrEqualTo(534));
    expect(tester.takeException(), isNull);
    await tester.tap(use);
    await tester.pumpAndSettle();
    expect(selection.value!.config, isNotNull);
  });
}
