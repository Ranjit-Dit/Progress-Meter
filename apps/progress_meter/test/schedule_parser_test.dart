import 'dart:typed_data';
import 'dart:io';
import 'dart:convert';

import 'package:archive/archive.dart';

import 'package:excel_community/excel_community.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progress_meter/features/routine_import/data/spreadsheet_reader.dart';
import 'package:progress_meter/features/routine_import/domain/import_models.dart';
import 'package:progress_meter/features/routine_import/domain/schedule_parser.dart';
import 'package:progress_meter/features/routines/domain/routine_models.dart';

ImportResult parse(
  List<List<String>> rows, {
  RoutineKind kind = RoutineKind.classSession,
}) => ScheduleParser.parse(
  ImportDocument(
    tables: [ImportTable(name: 'Weekly plan', rows: rows)],
  ),
  defaultKind: kind,
);
ImportToken word(String text, double x, double y, {double width = .07}) =>
    ImportToken(text: text, x: x, y: y, width: width, height: .012);

void main() {
  test('list columns preserve title, days, room, teacher and AM/PM', () {
    final result = parse([
      [
        'Course code',
        'Course title',
        'Day',
        'Start time',
        'End time',
        'Room',
        'Teacher',
        'Coordinator',
      ],
      [
        'CS101',
        'Algorithms',
        'Mon–Wed',
        '2:00 pm',
        '3:30 pm',
        'Lab 2',
        'Dr Lee',
        'Ignore me',
      ],
    ]);
    final draft = result.drafts.single;
    expect(draft.isValid, isTrue);
    expect(draft.weekdays, {1, 2, 3});
    expect(draft.startMinutes, 840);
    expect(draft.endMinutes, 930);
    expect(draft.instructor, 'Dr Lee');
    expect(draft.location, 'Lab 2');
    expect(draft.title, 'CS101 · Algorithms');
  });
  test(
    'incomplete and reversed class times remain editable without defaults',
    () {
      final result = parse([
        ['Subject', 'Day', 'Time'],
        ['Physics', '', ''],
        ['Math', 'Tue', '14:00–13:00'],
      ]);
      expect(result.drafts, hasLength(2));
      expect(result.drafts.first.weekdays, isEmpty);
      expect(result.drafts.first.startMinutes, isNull);
      expect(result.drafts.every((d) => !d.isValid), isTrue);
    },
  );
  test('food tables extract menus and everyday repeat without end time', () {
    final draft = parse([
      ['Meal', 'Days', 'Time', 'Menu'],
      ['Breakfast', 'Daily', '8:00 AM', 'Fruit and oats'],
    ]).drafts.single;
    expect(draft.kind, RoutineKind.meal);
    expect(draft.weekdays.length, 7);
    expect(draft.details, 'Fruit and oats');
    expect(draft.toRoutineItem().endMinutes, isNull);
  });
  test('weekly grids handle days across columns and rows', () {
    final across = parse([
      ['Time', 'Monday', 'Tuesday'],
      ['09:00–10:00', 'Physics\nRoom: Lab 1', 'Math'],
      ['10:00–11:00', 'Break', 'Algorithms'],
    ]);
    expect(across.drafts, hasLength(3));
    expect(across.drafts.first.location.trim(), 'Lab 1');
    final down = parse([
      ['Day', '09:00–10:00', '10:00–11:00'],
      ['Monday', 'Physics', 'Math'],
      ['Tuesday', 'Algorithms', ''],
    ]);
    expect(down.drafts, hasLength(3));
  });
  test('geometry carries columns across pages and excludes coordinator', () {
    final headers = [
      word('Course', .03, .10),
      word('Code', .03, .115),
      word('Course', .15, .10),
      word('Title', .23, .10),
      word('Day', .42, .10),
      word('Time', .52, .10),
      word('Resource', .66, .10),
      word('Name', .73, .10),
      word('Course', .81, .10),
      word('instructore', .81, .115),
      word('Course', .93, .10),
      word('Coordinator', .93, .115),
    ];
    List<ImportToken> row(double y, {String title = 'Physics'}) => [
      word('PH101', .03, y),
      word(title, .15, y, width: .15),
      word('Thursday', .42, y),
      word('11:00', .52, y),
      word('12:00', .59, y),
      word('Lab', .66, y),
      word('Dr Lee', .81, y),
      word('Other Person', .93, y),
    ];
    final result = ScheduleParser.parse(
      ImportDocument(
        pages: [
          ImportPage(
            width: 1000,
            height: 1000,
            tokens: [...headers, ...row(.22)],
          ),
          ImportPage(width: 1000, height: 1000, tokens: row(.07, title: 'Phy')),
        ],
      ),
      defaultKind: RoutineKind.classSession,
    );
    expect(result.drafts, hasLength(1));
    expect(result.drafts.single.title, 'PH101 · Physics');
    expect(result.drafts.single.instructor, 'Dr Lee');
    expect(result.drafts.single.startMinutes, 660);
    expect(result.drafts.single.endMinutes, 720);
  });
  test('OCR warns and long imports are capped at 200', () {
    final rows = [
      ['Subject', 'Day', 'Time'],
      for (var i = 0; i < 205; i++) ['Class $i', 'Mon', '09:00–10:00'],
    ];
    final result = ScheduleParser.parse(
      ImportDocument(
        usedOcr: true,
        tables: [ImportTable(name: 'Plan', rows: rows)],
      ),
      defaultKind: RoutineKind.classSession,
    );
    expect(result.drafts, hasLength(200));
    expect(result.warnings.any((w) => w.contains('recognition')), isTrue);
  });
  test('xlsx is decoded with merged weekdays', () async {
    final book = Excel.createExcel();
    final sheet = book['Sheet1'];
    for (final row in [
      ['Subject', 'Day', 'Start', 'End'],
      ['Physics', 'Monday', '09:00', '10:00'],
      ['Math', '', '10:00', '11:00'],
    ]) {
      sheet.appendRow(row.map(TextCellValue.new).toList());
    }
    sheet.merge(CellIndex.indexByString('B2'), CellIndex.indexByString('B3'));
    final doc = await SpreadsheetReader.read(
      Uint8List.fromList(book.encode()!),
      filename: 'plan.xlsx',
    );
    final drafts = ScheduleParser.parse(
      doc,
      defaultKind: RoutineKind.classSession,
    ).drafts;
    expect(drafts, hasLength(2));
    expect(drafts.last.title, 'Math');
    expect(drafts.last.weekdays, {1});
    expect(drafts.every((d) => d.isValid), isTrue);
  });
  test('oversized workbook dimensions are rejected before row allocation', () {
    final book = Excel.createExcel();
    book['Sheet1'].cell(CellIndex.indexByString('A2001')).value = TextCellValue(
      'Too far',
    );
    expect(
      () => SpreadsheetReader.decode(
        Uint8List.fromList(book.encode()!),
        filename: 'large.xlsx',
      ),
      throwsFormatException,
    );
  });
  test('legacy xls reads real BIFF data into valid routines', () async {
    final doc = await SpreadsheetReader.read(
      await File('test/fixtures/schedule.xls').readAsBytes(),
      filename: 'schedule.xls',
    );
    final drafts = ScheduleParser.parse(
      doc,
      defaultKind: RoutineKind.classSession,
    ).drafts;
    expect(drafts.map((d) => d.title), ['Algorithms', 'Physics']);
    expect(drafts.map((d) => d.startMinutes), [540, 840]);
    expect(drafts.every((d) => d.isValid), isTrue);
  });
  test('formula extraction uses saved values and never formula text', () {
    final book = Excel.createExcel();
    book['Sheet1'].appendRow(
      ['Subject', 'Day', 'Time'].map(TextCellValue.new).toList(),
    );
    book['Sheet1'].appendRow(
      ['Placeholder', 'Monday', '09:00–10:00'].map(TextCellValue.new).toList(),
    );
    final archive = ZipDecoder().decodeBytes(book.encode()!);
    final patched = Archive();
    for (final file in archive) {
      if (file.name == 'xl/worksheets/sheet1.xml') {
        final xml = utf8
            .decode(file.content)
            .replaceFirst(
              RegExp(r'<c\b[^>]*r="A2"[^>]*>.*?</c>'),
              '<c r="A2" t="str"><f>"Saved subject"</f><v>Saved subject</v></c>',
            );
        patched.add(ArchiveFile.string(file.name, xml));
      } else {
        patched.add(file);
      }
    }
    final doc = SpreadsheetReader.decode(
      Uint8List.fromList(ZipEncoder().encode(patched)),
      filename: 'formula.xlsx',
    );
    final draft = ScheduleParser.parse(
      doc,
      defaultKind: RoutineKind.classSession,
    ).drafts.single;
    expect(draft.title, 'Saved subject');
  });
  test('meal grids retain menu and require missing times to be corrected', () {
    final result = parse([
      ['Day', 'Breakfast 08:00', 'Lunch'],
      ['Mon', 'Fruit and oats', 'Rice and vegetables'],
      ['Tue', 'Toast and eggs', 'Soup'],
    ], kind: RoutineKind.meal);
    expect(result.drafts.length, 4);
    expect(result.drafts.first.title, 'Breakfast');
    expect(result.drafts.first.startMinutes, 480);
    expect(result.drafts.first.details, 'Fruit and oats');
    expect(result.drafts[1].startMinutes, isNull);
    expect(result.drafts[1].isValid, isFalse);
  });
  test('missing OCR day header can be inferred from a repeated day column', () {
    final tokens = [word('Subject', .1, .1), word('Time', .55, .1)];
    for (var i = 0; i < 3; i++) {
      final y = .25 + i * .12;
      tokens.addAll([
        word('Physics', .1, y),
        word('Monday', .4, y),
        word('09:00', .55, y),
        word('10:00', .65, y),
      ]);
    }
    final result = ScheduleParser.parse(
      ImportDocument(
        usedOcr: true,
        pages: [ImportPage(width: 1000, height: 1000, tokens: tokens)],
      ),
      defaultKind: RoutineKind.classSession,
    );
    expect(result.drafts.single.title, 'Physics');
    expect(result.drafts.single.weekdays, {1});
    expect(result.drafts.single.isValid, isTrue);
  });
}
