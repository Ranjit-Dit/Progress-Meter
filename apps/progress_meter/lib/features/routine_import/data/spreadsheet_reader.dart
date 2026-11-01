import 'dart:isolate';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'package:excel_community/excel_community.dart';

import '../domain/import_models.dart';

abstract final class SpreadsheetReader {
  static Future<ImportDocument> read(
    Uint8List bytes, {
    required String filename,
  }) => Isolate.run(() => decode(bytes, filename: filename));

  static ImportDocument decode(Uint8List bytes, {required String filename}) {
    if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
      throw const FormatException(
        'Choose an Excel workbook smaller than 10 MB.',
      );
    }
    var prepared = bytes;
    if (bytes.length >= 4 && bytes[0] == 80 && bytes[1] == 75) {
      final directory = ZipDirectory()..read(InputMemoryStream(bytes));
      if (directory.fileHeaders.isEmpty ||
          directory.fileHeaders.length > 1000) {
        throw const FormatException('This workbook has too many components.');
      }
      var expanded = 0;
      for (final header in directory.fileHeaders) {
        expanded += header.uncompressedSize;
        if (header.uncompressedSize > 20 * 1024 * 1024 ||
            expanded > 50 * 1024 * 1024) {
          throw const FormatException(
            'This workbook expands to too much data.',
          );
        }
      }
      final archive = ZipDecoder().decodeBytes(bytes);
      final normalized = Archive();
      var changed = false;
      var sheetCount = 0;
      for (final file in archive) {
        if (!RegExp(r'^xl/worksheets/[^/]+\.xml$').hasMatch(file.name)) {
          normalized.add(file);
          continue;
        }
        if (++sheetCount > 20) {
          throw const FormatException('Use at most 20 sheets.');
        }
        final xml = XmlDocument.parse(utf8.decode(file.content));
        var sheetChanged = false;
        var cellCount = 0;
        for (final cell in xml.findAllElements('c')) {
          if (++cellCount > 30000) {
            throw const FormatException('Use at most 30,000 cells.');
          }
          final ref = cell.getAttribute('r');
          if (ref != null) {
            final index = CellIndex.indexByString(ref);
            if (index.rowIndex >= 2000 || index.columnIndex >= 50) {
              throw const FormatException(
                'Use at most 2,000 rows and 50 columns.',
              );
            }
          }
          // The decoder drops string formula caches. Treat the saved result as
          // plain text before decoding; the formula itself is never evaluated.
          if (cell.getAttribute('t') == 'str') {
            final saved = cell.getElement('v')?.innerText;
            if (saved == null) continue;
            cell.setAttribute('t', 'inlineStr');
            cell.children.clear();
            cell.children.add(
              XmlElement(XmlName.parts('is'), [], [
                XmlElement(XmlName.parts('t'), [], [XmlText(saved)]),
              ]),
            );
            sheetChanged = true;
          }
        }
        normalized.add(
          sheetChanged
              ? ArchiveFile.string(file.name, xml.toXmlString())
              : file,
        );
        changed = changed || sheetChanged;
      }
      if (changed) {
        prepared = Uint8List.fromList(ZipEncoder().encode(normalized));
      }
    }
    // Values and cached formula results only. No formulas or macros execute.
    final book = Excel.decodeBytes(prepared);
    if (book.tables.length > 20) {
      throw const FormatException('Import a workbook with at most 20 sheets.');
    }
    var cells = 0;
    final tables = <ImportTable>[];
    final warnings = <String>[];
    for (final entry in book.tables.entries) {
      final sheet = entry.value;
      if (sheet.maxRows > 2000 || sheet.maxColumns > 50) {
        throw const FormatException(
          'Use a schedule with at most 2,000 rows and 50 columns per sheet.',
        );
      }
      cells += sheet.maxRows * sheet.maxColumns;
      if (cells > 30000) {
        throw const FormatException(
          'Import a smaller workbook (at most 30,000 cells).',
        );
      }
      final rows = <List<String>>[];
      for (var r = 0; r < sheet.maxRows; r++) {
        final row = <String>[];
        for (var c = 0; c < sheet.maxColumns; c++) {
          final cell = sheet.cell(
            CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r),
          );
          if (cell.value case FormulaCellValue(cachedValue: null)) {
            warnings.add(
              'Some formulas have no saved result. Fill any missing values in the preview.',
            );
          }
          final value = cell.displayText;
          if (value.length > 4000) {
            throw const FormatException(
              'A workbook cell contains too much text.',
            );
          }
          row.add(value);
        }
        rows.add(row);
      }
      for (final span in sheet.spannedItems) {
        final ends = span.split(':');
        if (ends.length != 2) continue;
        final start = CellIndex.indexByString(ends[0]);
        final end = CellIndex.indexByString(ends[1]);
        if (start.rowIndex < 0 ||
            start.columnIndex < 0 ||
            end.rowIndex >= rows.length ||
            end.columnIndex >= sheet.maxColumns) {
          continue;
        }
        final value = rows[start.rowIndex][start.columnIndex];
        for (var r = start.rowIndex; r <= end.rowIndex; r++) {
          for (var c = start.columnIndex; c <= end.columnIndex; c++) {
            if (rows[r][c].isEmpty) rows[r][c] = value;
          }
        }
      }
      if (rows.any((r) => r.any((v) => v.trim().isNotEmpty))) {
        tables.add(ImportTable(name: entry.key, rows: rows));
      }
    }
    return ImportDocument(tables: tables, warnings: warnings.toSet().toList());
  }
}
