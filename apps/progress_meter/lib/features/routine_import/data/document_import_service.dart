import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';

import '../../routines/domain/routine_models.dart';
import '../domain/import_models.dart';
import '../domain/schedule_parser.dart';
import 'spreadsheet_reader.dart';

/// A document chosen by the user. Absolute paths are deliberately not retained.
class SelectedRoutineFile {
  SelectedRoutineFile({required String name, required Uint8List bytes})
    : name = name.split(RegExp(r'[/\\]')).last,
      bytes = Uint8List.fromList(bytes).asUnmodifiableView();

  final String name;
  final Uint8List bytes;
}

class ImportFailure implements Exception {
  const ImportFailure(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => message;
}

abstract interface class RoutineImportService {
  Future<SelectedRoutineFile?> pickFile();
  Future<ImportResult> extract(
    SelectedRoutineFile file, {
    required RoutineKind defaultKind,
  });
}

typedef SpreadsheetDecoder = Future<ImportDocument> Function(
  Uint8List bytes, {
  required String filename,
});
typedef ImportDocumentParser = ImportResult Function(
  ImportDocument document, {
  required RoutineKind defaultKind,
});

/// Local-only extraction. No document or source bytes are sent to a server.
class LocalRoutineImportService implements RoutineImportService {
  LocalRoutineImportService({
    MethodChannel? channel,
    bool? nativeSupported,
    Future<XFile?> Function()? picker,
    SpreadsheetDecoder? spreadsheetDecoder,
    ImportDocumentParser? parser,
    this.parseInBackground = true,
  }) : _channel =
           channel ?? const MethodChannel('progress_meter/document_reader'),
       _nativeSupported = nativeSupported ?? Platform.isMacOS,
       _picker = picker ?? _pickRoutineFile,
       _spreadsheetDecoder = spreadsheetDecoder ?? SpreadsheetReader.read,
       _parser = parser ?? ScheduleParser.parse;

  static const maximumDocumentBytes = 20 * 1024 * 1024;
  static const maximumSpreadsheetBytes = 10 * 1024 * 1024;
  static const _maximumPages = 12;
  static const _maximumTokens = 50000;
  static const _nativeTimeout = Duration(minutes: 2);
  final MethodChannel _channel;
  final bool _nativeSupported;
  final Future<XFile?> Function() _picker;
  final SpreadsheetDecoder _spreadsheetDecoder;
  final ImportDocumentParser _parser;
  final bool parseInBackground;

  static Future<XFile?> _pickRoutineFile() => openFile(
    confirmButtonText: 'Extract routine',
    acceptedTypeGroups: const [
      XTypeGroup(
        label: 'Routine documents',
        extensions: [
          'pdf',
          'png',
          'jpg',
          'jpeg',
          'heic',
          'heif',
          'webp',
          'xls',
          'xlsx',
        ],
        uniformTypeIdentifiers: [
          'com.adobe.pdf',
          'public.image',
          'com.microsoft.excel.xls',
          'org.openxmlformats.spreadsheetml.sheet',
        ],
        mimeTypes: [
          'application/pdf',
          'image/png',
          'image/jpeg',
          'image/heic',
          'image/heif',
          'image/webp',
          'application/vnd.ms-excel',
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        ],
      ),
    ],
  );

  @override
  Future<SelectedRoutineFile?> pickFile() async {
    try {
      final picked = await _picker();
      if (picked == null) return null;
      final type = _fileType(picked.name);
      final size = await picked.length();
      _validateSize(size, type);
      final file = SelectedRoutineFile(
        name: picked.name,
        bytes: await picked.readAsBytes(),
      );
      _validateBytes(file, type);
      return file;
    } on ImportFailure {
      rethrow;
    } catch (_) {
      throw const ImportFailure(
        'file_unavailable',
        'This file could not be opened. Choose a local file you can read and try again.',
      );
    }
  }

  @override
  Future<ImportResult> extract(
    SelectedRoutineFile file, {
    required RoutineKind defaultKind,
  }) async {
    final type = _fileType(file.name);
    _validateBytes(file, type);
    try {
      final ImportDocument document;
      if (type == _ImportFileType.spreadsheet) {
        document = await _spreadsheetDecoder(file.bytes, filename: file.name);
      } else {
        if (!_nativeSupported) {
          throw const ImportFailure(
            'unsupported_platform',
            'Local image and PDF extraction is available in the macOS app. Excel workbooks can be imported on other native platforms.',
          );
        }
        final response = await _channel
            .invokeMethod<Object?>('readDocument', {
              'bytes': file.bytes,
              'name': file.name,
            })
            .timeout(_nativeTimeout);
        document = _decodeNativeDocument(response);
      }
      final parser = _parser;
      if (!parseInBackground) return parser(document, defaultKind: defaultKind);
      return await Isolate.run(
        () => parser(document, defaultKind: defaultKind),
      );
    } on ImportFailure {
      rethrow;
    } on TimeoutException {
      throw const ImportFailure(
        'timeout',
        'Extraction took too long. Try fewer PDF pages or a smaller, clearer image.',
      );
    } on MissingPluginException {
      throw const ImportFailure(
        'reader_unavailable',
        'The local document reader is unavailable. Rebuild or reopen the updated macOS app and try again.',
      );
    } on PlatformException catch (error) {
      throw _nativeFailure(error.code);
    } catch (_) {
      throw ImportFailure(
        'invalid_document',
        type == _ImportFileType.spreadsheet
            ? 'This workbook could not be read. Use an unlocked Excel .xlsx or .xls workbook and try again.'
            : 'This document could not be read. Try an unlocked PDF or a clearer supported image.',
      );
    }
  }

  static _ImportFileType _fileType(String name) {
    final dot = name.lastIndexOf('.');
    final extension = dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
    return switch (extension) {
      'xls' || 'xlsx' => _ImportFileType.spreadsheet,
      'pdf' => _ImportFileType.pdf,
      'png' ||
      'jpg' ||
      'jpeg' ||
      'heic' ||
      'heif' ||
      'webp' => _ImportFileType.image,
      _ => throw const ImportFailure(
        'unsupported_type',
        'Choose a PDF, Excel .xlsx/.xls workbook, or PNG, JPEG, HEIC, or WebP image.',
      ),
    };
  }

  static void _validateSize(int size, _ImportFileType type) {
    if (size <= 0) {
      throw const ImportFailure(
        'empty_file',
        'This file is empty. Choose a document containing your schedule.',
      );
    }
    final limit = type == _ImportFileType.spreadsheet
        ? maximumSpreadsheetBytes
        : maximumDocumentBytes;
    if (size > limit) {
      throw ImportFailure(
        'file_too_large',
        type == _ImportFileType.spreadsheet
            ? 'Choose an Excel workbook smaller than 10 MB.'
            : 'Choose a PDF or image smaller than 20 MB.',
      );
    }
  }

  static void _validateBytes(SelectedRoutineFile file, _ImportFileType type) {
    final bytes = file.bytes;
    _validateSize(bytes.length, type);
    final extension = file.name
        .substring(file.name.lastIndexOf('.') + 1)
        .toLowerCase();
    bool starts(List<int> signature) =>
        bytes.length >= signature.length &&
        Iterable<int>.generate(signature.length)
            .every((i) => bytes[i] == signature[i]);
    bool isAscii(int start, String text) =>
        bytes.length >= start + text.length &&
        Iterable<int>.generate(text.length)
            .every((i) => bytes[start + i] == text.codeUnitAt(i));
    final valid = switch (extension) {
      'pdf' => String.fromCharCodes(bytes.take(1024)).contains('%PDF-'),
      'png' => starts([137, 80, 78, 71, 13, 10, 26, 10]),
      'jpg' || 'jpeg' => starts([255, 216, 255]),
      'webp' => isAscii(0, 'RIFF') && isAscii(8, 'WEBP'),
      'heic' || 'heif' =>
        isAscii(4, 'ftyp') &&
            bytes.length >= 16 &&
            ['heic', 'heix', 'hevc', 'hevx', 'mif1', 'msf1'].any(
              (brand) => String.fromCharCodes(
                bytes.sublist(8, bytes.length.clamp(8, 64)),
              ).contains(brand),
            ),
      'xlsx' => starts([80, 75, 3, 4]),
      'xls' => starts([208, 207, 17, 224, 161, 177, 26, 225]),
      _ => false,
    };
    if (!valid) {
      throw const ImportFailure(
        'invalid_file_type',
        'The file contents do not match its format. Export a fresh PDF, supported image, or Excel workbook and try again.',
      );
    }
  }

  static ImportDocument _decodeNativeDocument(Object? response) {
    if (response is! Map ||
        response['pages'] is! List ||
        response['usedOcr'] is! bool) {
      throw const FormatException('Invalid local reader response.');
    }
    final pages = response['pages'] as List;
    if (pages.length > _maximumPages) {
      throw const ImportFailure(
        'too_many_pages',
        'Choose a PDF with 12 pages or fewer.',
      );
    }
    var tokenCount = 0;
    var textLength = 0;
    for (final value in pages) {
      if (value is! Map || value['tokens'] is! List) {
        throw const FormatException('Invalid page.');
      }
      for (final dimension in ['width', 'height']) {
        final number = value[dimension];
        if (number is! num ||
            !number.isFinite ||
            number <= 0 ||
            number > 100000) {
          throw const FormatException('Invalid page dimensions.');
        }
      }
      for (final item in value['tokens'] as List) {
        if (item is! Map || item['text'] is! String) {
          throw const FormatException('Invalid word.');
        }
        tokenCount++;
        textLength += (item['text'] as String).length;
        if (tokenCount > _maximumTokens || textLength > 2000000) {
          throw const ImportFailure(
            'document_too_complex',
            'This document has too much text. Choose just the pages containing your schedule.',
          );
        }
        for (final coordinate in ['x', 'y', 'width', 'height']) {
          final number = item[coordinate];
          if (number is! num || !number.isFinite || number < 0 || number > 1) {
            throw const FormatException('Invalid word bounds.');
          }
        }
      }
    }
    return ImportDocument.fromJson(Map<String, dynamic>.from(response));
  }

  static ImportFailure _nativeFailure(String code) => switch (code) {
    'document_too_large' || 'file_too_large' => const ImportFailure(
      'file_too_large',
      'Choose a PDF or image smaller than 20 MB.',
    ),
    'pdf_page_limit' ||
    'image_page_limit' ||
    'too_many_pages' => const ImportFailure(
      'too_many_pages',
      'Choose a PDF with 12 pages or fewer.',
    ),
    'locked_pdf' ||
    'encrypted_pdf' ||
    'password_required' => const ImportFailure(
      'encrypted_pdf',
      'Unlock this PDF and save an unprotected copy before importing it.',
    ),
    'image_too_large' => const ImportFailure(
      'image_too_large',
      'This image is too large to process. Resize it and try again.',
    ),
    'ocr_unavailable' => const ImportFailure(
      'ocr_unavailable',
      'Local text recognition could not finish. Try a sharper image or a searchable PDF.',
    ),
    'no_text' => const ImportFailure(
      'no_text',
      'No readable text was found. Try a sharper, well-lit image or a searchable PDF.',
    ),
    'unsupported_type' => const ImportFailure(
      'unsupported_type',
      'This document format is not supported by the local reader.',
    ),
    _ => const ImportFailure(
      'extraction_failed',
      'The local reader could not extract this file. Try a clearer image or a fresh, unlocked PDF.',
    ),
  };
}

enum _ImportFileType { pdf, image, spreadsheet }
