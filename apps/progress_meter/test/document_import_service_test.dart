import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progress_meter/features/routine_import/data/document_import_service.dart';
import 'package:progress_meter/features/routine_import/domain/import_models.dart';
import 'package:progress_meter/features/routines/domain/routine_models.dart';

const _channel = MethodChannel('progress_meter/test_document_reader');
final _pdfBytes = Uint8List.fromList('%PDF-1.7\n'.codeUnits);
final _xlsBytes = Uint8List.fromList([208, 207, 17, 224, 161, 177, 26, 225]);

Map<String, dynamic> _nativeDocument({bool usedOcr = false}) => {
  'pages': [
    {
      'width': 1000,
      'height': 1200,
      'tokens': [
        {'text': 'Monday', 'x': .1, 'y': .2, 'width': .1, 'height': .02},
        {'text': '09:00', 'x': .3, 'y': .2, 'width': .08, 'height': .02},
      ],
    },
  ],
  'usedOcr': usedOcr,
  'warnings': <String>[],
};

ImportResult _emptyResult(
  ImportDocument document, {
  required RoutineKind defaultKind,
}) => ImportResult(drafts: [], warnings: []);

LocalRoutineImportService _service({
  bool nativeSupported = true,
  Future<XFile?> Function()? picker,
  SpreadsheetDecoder? spreadsheetDecoder,
  ImportDocumentParser? parser,
  bool parseInBackground = false,
}) => LocalRoutineImportService(
  channel: _channel,
  nativeSupported: nativeSupported,
  picker: picker,
  spreadsheetDecoder: spreadsheetDecoder,
  parser: parser ?? _emptyResult,
  parseInBackground: parseInBackground,
);

Future<ImportResult> _extract(
  LocalRoutineImportService service, {
  String name = 'schedule.pdf',
  Uint8List? bytes,
}) => service.extract(
  SelectedRoutineFile(name: name, bytes: bytes ?? _pdfBytes),
  defaultKind: RoutineKind.classSession,
);

Matcher _failure(String code) =>
    isA<ImportFailure>().having((e) => e.code, 'code', code);

class _SizeOnlyFile extends XFile {
  _SizeOnlyFile(this.reportedBytes) : super('/not-read/private-schedule.pdf');
  final int reportedBytes;
  int reads = 0;
  @override
  String get name => 'schedule.pdf';
  @override
  Future<int> length() async => reportedBytes;
  @override
  Future<Uint8List> readAsBytes() async {
    reads++;
    throw StateError('The oversized source must not be read.');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(_channel, null));

  test(
    'cancelling file selection returns no import and changes nothing',
    () async {
      final service = _service(picker: () async => null);
      expect(await service.pickFile(), isNull);
    },
  );

  test('file selection checks size before reading source bytes', () async {
    final source = _SizeOnlyFile(
      LocalRoutineImportService.maximumDocumentBytes + 1,
    );
    await expectLater(
      _service(picker: () async => source).pickFile(),
      throwsA(_failure('file_too_large')),
    );
    expect(source.reads, 0);
  });

  test(
    'selection retains a basename and bytes rather than an absolute path',
    () async {
      final source = XFile.fromData(_pdfBytes, path: '/private/schedule.PDF');
      final file = await _service(picker: () async => source).pickFile();
      expect(file!.name, 'schedule.PDF');
      expect(file.bytes, _pdfBytes);
      expect(
        SelectedRoutineFile(
          name: '/private/folder/plan.pdf',
          bytes: _pdfBytes,
        ).name,
        'plan.pdf',
      );
      expect(() => file.bytes[0] = 0, throwsUnsupportedError);
    },
  );

  test('unsupported, empty, disguised, and oversized files never reach the native reader', () async {
    var nativeCalls = 0;
    messenger.setMockMethodCallHandler(_channel, (_) async {
      nativeCalls++;
      return _nativeDocument();
    });
    final service = _service();
    await expectLater(
      _extract(service, name: 'script.exe'),
      throwsA(_failure('unsupported_type')),
    );
    await expectLater(
      _extract(service, bytes: Uint8List(0)),
      throwsA(_failure('empty_file')),
    );
    await expectLater(
      _extract(
        service,
        bytes: Uint8List.fromList('<html>not a PDF</html>'.codeUnits),
      ),
      throwsA(_failure('invalid_file_type')),
    );
    await expectLater(
      _extract(service, name: 'plan.xlsx', bytes: _pdfBytes),
      throwsA(_failure('invalid_file_type')),
    );
    await expectLater(
      _extract(
        service,
        bytes: Uint8List(LocalRoutineImportService.maximumDocumentBytes + 1),
      ),
      throwsA(_failure('file_too_large')),
    );
    expect(nativeCalls, 0);
  });

  test('PDF extraction sends local bytes through the documented channel and preserves geometry', () async {
    MethodCall? received;
    ImportDocument? document;
    RoutineKind? selectedKind;
    messenger.setMockMethodCallHandler(_channel, (call) async {
      received = call;
      return _nativeDocument();
    });
    final service = _service(
      parser: (value, {required defaultKind}) {
        document = value;
        selectedKind = defaultKind;
        return _emptyResult(value, defaultKind: defaultKind);
      },
    );
    await _extract(service);
    expect(received!.method, 'readDocument');
    expect((received!.arguments as Map)['name'], 'schedule.pdf');
    expect((received!.arguments as Map)['bytes'], _pdfBytes);
    expect(document!.pages, hasLength(1));
    expect(document!.pages.single.tokens.first.text, 'Monday');
    expect(document!.pages.single.tokens.first.x, .1);
    expect(document!.usedOcr, isFalse);
    expect(selectedKind, RoutineKind.classSession);
  });

  test('image OCR stays local and passes the requested food import scope to the parser', () async {
    ImportDocument? document;
    RoutineKind? selectedKind;
    messenger.setMockMethodCallHandler(
      _channel,
      (_) async => _nativeDocument(usedOcr: true),
    );
    final service = _service(
      parser: (value, {required defaultKind}) {
        document = value;
        selectedKind = defaultKind;
        return _emptyResult(value, defaultKind: defaultKind);
      },
    );
    await service.extract(
      SelectedRoutineFile(
        name: 'menu.png',
        bytes: Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]),
      ),
      defaultKind: RoutineKind.meal,
    );
    expect(document!.usedOcr, isTrue);
    expect(selectedKind, RoutineKind.meal);
  });

  test(
    'missing native support is actionable and never silently uploads a PDF',
    () async {
      var nativeCalls = 0;
      messenger.setMockMethodCallHandler(_channel, (_) async {
        nativeCalls++;
        return _nativeDocument();
      });
      await expectLater(
        _extract(_service(nativeSupported: false)),
        throwsA(_failure('unsupported_platform')),
      );
      expect(nativeCalls, 0);
    },
  );

  test(
    'legacy Excel uses its local decoder without a native document reader',
    () async {
      var nativeCalls = 0;
      Uint8List? bytes;
      String? filename;
      messenger.setMockMethodCallHandler(_channel, (_) async {
        nativeCalls++;
        return _nativeDocument();
      });
      final service = _service(
        nativeSupported: false,
        spreadsheetDecoder: (value, {required filename}) async {
          bytes = value;
          return ImportDocument();
        },
        parser: (value, {required defaultKind}) =>
            _emptyResult(value, defaultKind: defaultKind),
      );
      final capturing = _service(
        nativeSupported: false,
        spreadsheetDecoder: (value, {required String filename}) async {
          bytes = value;
          return ImportDocument(warnings: [filename]);
        },
        parser: (value, {required defaultKind}) {
          filename = value.warnings.single;
          return _emptyResult(value, defaultKind: defaultKind);
        },
      );
      await _extract(service, name: 'classes.xls', bytes: _xlsBytes);
      await _extract(capturing, name: 'classes.xls', bytes: _xlsBytes);
      expect(bytes, _xlsBytes);
      expect(filename, 'classes.xls');
      expect(nativeCalls, 0);
    },
  );

  test('Excel has its own smaller size limit before decoding', () async {
    var decodes = 0;
    final service = _service(
      spreadsheetDecoder: (_, {required filename}) async {
        decodes++;
        return ImportDocument();
      },
    );
    await expectLater(
      _extract(
        service,
        name: 'large.xlsx',
        bytes: Uint8List(LocalRoutineImportService.maximumSpreadsheetBytes + 1),
      ),
      throwsA(_failure('file_too_large')),
    );
    expect(decodes, 0);
  });

  test('plugin absence and encrypted PDFs produce friendly errors', () async {
    await expectLater(
      _extract(_service()),
      throwsA(_failure('reader_unavailable')),
    );
    messenger.setMockMethodCallHandler(
      _channel,
      (_) async => throw PlatformException(
        code: 'encrypted_pdf',
        message: '/private/secret-name.pdf',
      ),
    );
    await expectLater(_extract(_service()), throwsA(_failure('encrypted_pdf')));
  });

  test('untrusted native errors and workbook errors never expose their raw messages', () async {
    const secret = 'private-name-and-secret-value';
    messenger.setMockMethodCallHandler(
      _channel,
      (_) async => throw PlatformException(code: 'unknown', message: secret),
    );
    try {
      await _extract(_service());
      fail('Expected a local reader failure');
    } on ImportFailure catch (error) {
      expect(error.message, isNot(contains(secret)));
      expect(error.code, 'extraction_failed');
    }
    final service = _service(
      spreadsheetDecoder: (_, {required filename}) async =>
          throw FormatException(secret),
    );
    try {
      await _extract(service, name: 'broken.xls', bytes: _xlsBytes);
      fail('Expected a workbook failure');
    } on ImportFailure catch (error) {
      expect(error.message, isNot(contains(secret)));
      expect(error.code, 'invalid_document');
    }
  });

  test(
    'malformed geometry and too many pages are rejected before parsing',
    () async {
      var parses = 0;
      final service = _service(
        parser: (value, {required defaultKind}) {
          parses++;
          return _emptyResult(value, defaultKind: defaultKind);
        },
      );
      final bad = _nativeDocument();
      (((bad['pages'] as List).single as Map)['tokens'] as List).first['x'] =
          -.1;
      messenger.setMockMethodCallHandler(_channel, (_) async => bad);
      await expectLater(
        _extract(service),
        throwsA(_failure('invalid_document')),
      );
      final excessive = _nativeDocument();
      excessive['pages'] = List.generate(
        13,
        (_) => {'width': 1000, 'height': 1200, 'tokens': []},
      );
      messenger.setMockMethodCallHandler(_channel, (_) async => excessive);
      await expectLater(_extract(service), throwsA(_failure('too_many_pages')));
      expect(parses, 0);
    },
  );

  test('background parsing can return an import result without retaining the native channel', () async {
    messenger.setMockMethodCallHandler(
      _channel,
      (_) async => _nativeDocument(),
    );
    final result = await _extract(_service(parseInBackground: true));
    expect(result.drafts, isEmpty);
  });
}
