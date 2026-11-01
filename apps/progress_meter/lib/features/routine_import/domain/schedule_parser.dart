import 'dart:math' as math;

import '../../routines/domain/routine_models.dart';
import 'import_models.dart';

String _clean(String value) => value
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F]'), '')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
String _norm(String value) =>
    value.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '');
const _dayNames = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];
final _dayPattern = RegExp(
  r'\b(mon(?:day)?|tue(?:s(?:day)?)?|wed(?:nesday)?|thu(?:rs?(?:day)?)?|fri(?:day)?|sat(?:urday)?|sun(?:day)?)\b',
  caseSensitive: false,
);
Set<int> parseImportWeekdays(String value) {
  final lower = value.toLowerCase();
  if (RegExp(r'\b(every\s*day|daily|all\s*days)\b').hasMatch(lower)) {
    return {1, 2, 3, 4, 5, 6, 7};
  }
  if (RegExp(r'\bweekdays\b').hasMatch(lower)) return {1, 2, 3, 4, 5};
  if (RegExp(r'\bweekends?\b').hasMatch(lower)) return {6, 7};
  final matches = _dayPattern.allMatches(lower).toList();
  final days = <int>{};
  int index(String day) =>
      _dayNames.indexWhere((d) => d.startsWith(day.substring(0, 3))) + 1;
  for (final match in matches) {
    days.add(index(match.group(1)!));
  }
  if (matches.length == 2) {
    final gap = lower.substring(matches.first.end, matches.last.start).trim();
    if (RegExp(r'^(?:-|–|—|to|through|until)$').hasMatch(gap)) {
      var current = index(matches.first.group(1)!);
      final last = index(matches.last.group(1)!);
      for (var n = 0; n < 7; n++) {
        days.add(current);
        if (current == last) break;
        current = current % 7 + 1;
      }
    }
  }
  return days;
}

class _Clock {
  _Clock(this.hour, this.minute, this.meridiem);
  final int hour, minute;
  final String meridiem;
  int? value([String inherited = '']) {
    final suffix = meridiem.isEmpty ? inherited : meridiem;
    if (minute > 59 || hour > 23 || hour < 0) return null;
    if (suffix.isNotEmpty) {
      if (hour < 1 || hour > 12) return null;
      return (hour % 12 + (suffix == 'pm' ? 12 : 0)) * 60 + minute;
    }
    return hour * 60 + minute;
  }
}

class _Times {
  _Times(this.start, this.end, [this.warning]);
  final int? start, end;
  final String? warning;
}

_Times _times(String text) {
  final pattern = RegExp(
    r'(?<!\d)(\d{1,2})(?::|\.)(\d{2})(?::\d{2})?\s*(a\.?m\.?|p\.?m\.?)?|(?<!\d)(\d{1,2})\s*(a\.?m\.?|p\.?m\.?)',
    caseSensitive: false,
  );
  final clocks = <_Clock>[];
  for (final m in pattern.allMatches(text)) {
    final marker = (m.group(3) ?? m.group(5) ?? '')
        .replaceAll('.', '')
        .toLowerCase();
    clocks.add(
      _Clock(
        int.parse(m.group(1) ?? m.group(4)!),
        m.group(2) == null ? 0 : int.parse(m.group(2)!),
        marker,
      ),
    );
    if (clocks.length == 2) break;
  }
  if (clocks.isEmpty) return _Times(null, null);
  final inherited = clocks.length == 2 ? clocks.last.meridiem : '';
  final start = clocks.first.value(inherited);
  final end = clocks.length == 2 ? clocks.last.value() : null;
  if (start == null || (clocks.length == 2 && end == null)) {
    return _Times(start, end, 'A time could not be read.');
  }
  if (end != null && end <= start) {
    return _Times(
      start,
      end,
      'End time is not later than start time. Review AM/PM or overnight entries.',
    );
  }
  return _Times(start, end);
}

String? _field(String value) {
  final n = _norm(value);
  if ([
    'day',
    'days',
    'weekday',
    'weekdays',
    'repeatdays',
    'daysoftheweek',
  ].contains(n)) {
    return 'day';
  }
  if ([
    'start',
    'starttime',
    'from',
    'begins',
    'begin',
    'beginning',
  ].contains(n)) {
    return 'start';
  }
  if (['end', 'endtime', 'to', 'finish', 'finishtime', 'until'].contains(n)) {
    return 'end';
  }
  if ([
    'time',
    'timing',
    'timings',
    'period',
    'slot',
    'timeslot',
    'schedule',
  ].contains(n)) {
    return 'time';
  }
  if ([
    'subject',
    'subjectname',
    'coursetitle',
    'title',
    'coursename',
    'class',
    'classname',
  ].contains(n)) {
    return 'title';
  }
  if (['meal', 'mealname', 'food', 'foodroutine'].contains(n)) return 'meal';
  if ([
    'menu',
    'menunotes',
    'foods',
    'fooditems',
    'description',
    'details',
    'notes',
  ].contains(n)) {
    return 'details';
  }
  if ([
    'room',
    'roomno',
    'roomnumber',
    'location',
    'venue',
    'resource',
    'resourcename',
    'classroom',
  ].contains(n)) {
    return 'location';
  }
  if ([
    'teacher',
    'instructor',
    'instructore',
    'couseinstructore',
    'courseinstructor',
    'faculty',
    'facultyname',
    'lecturer',
    'professor',
  ].contains(n)) {
    return 'instructor';
  }
  if (['coursecode', 'subjectcode', 'code'].contains(n)) return 'code';
  if (['component', 'session', 'type', 'classtype'].contains(n)) {
    return 'component';
  }
  if ([
    'coursebucket',
    'bucket',
    'credit',
    'credits',
    'coursecoordinator',
    'coordinator',
    'courseoffering',
    'offering',
    'deptschoolcollege',
    'department',
  ].contains(n)) {
    return 'ignored';
  }
  return null;
}

class _Row {
  _Row(this.fields, this.kind, {this.source = ''});
  final Map<String, String> fields;
  final RoutineKind kind;
  final String source;
}

class _Column {
  _Column(this.x, this.field);
  final double x;
  final String field;
}

class _Schema {
  _Schema(this.columns, this.bottom);
  final List<_Column> columns;
  final double bottom;
}

abstract final class ScheduleParser {
  static ImportResult parse(
    ImportDocument document, {
    required RoutineKind defaultKind,
  }) {
    if (document.pages.fold<int>(0, (n, p) => n + p.tokens.length) > 50000) {
      throw const FormatException(
        'The document contains too much text. Import a smaller section.',
      );
    }
    final rows = <_Row>[];
    final warnings = [...document.warnings];
    for (final table in document.tables) {
      rows.addAll(_tableRows(table, defaultKind));
    }
    _Schema? previous;
    for (var index = 0; index < document.pages.length; index++) {
      final page = document.pages[index];
      final tokens = page.tokens
          .where(
            (t) =>
                t.text.trim().isNotEmpty &&
                [t.x, t.y, t.width, t.height].every((v) => v.isFinite),
          )
          .toList();
      final schema = _detectSchema(tokens);
      final active = schema ?? previous;
      final geometry = active == null
          ? <_Row>[]
          : _geometryRows(
              tokens,
              active,
              defaultKind,
              headerPresent: schema != null,
              source: 'Page ${index + 1}',
            );
      if (geometry.isNotEmpty) {
        rows.addAll(geometry);
      } else {
        final grid = _geometryGrid(tokens, defaultKind);
        if (grid.isNotEmpty) {
          rows.addAll(grid);
        } else {
          rows.addAll(_plainRows(tokens, defaultKind));
        }
      }
      if (schema != null) previous = schema;
    }
    final bestTitles = <String, String>{};
    for (final row in rows) {
      final code = _clean(row.fields['code'] ?? '');
      final title = _clean(row.fields['title'] ?? row.fields['meal'] ?? '');
      if (code.isNotEmpty && title.length > (bestTitles[code]?.length ?? 0)) {
        bestTitles[code] = title;
      }
    }
    final drafts = <ImportDraft>[];
    final byKey = <String, int>{};
    for (final row in rows) {
      final f = row.fields;
      final day = parseImportWeekdays(f['day'] ?? '');
      final time = _times(f['time'] ?? f['start'] ?? '');
      final endSeparate = _times(f['end'] ?? '');
      final end = f.containsKey('end') ? endSeparate.start : time.end;
      final code = _clean(f['code'] ?? '');
      var title = _clean(bestTitles[code] ?? f['title'] ?? f['meal'] ?? '');
      if (title.isEmpty && code.isNotEmpty) title = code;
      if (title.isEmpty) continue;
      if (RegExp(
            r'^(break|free|holiday|no class|lunch break|recess|off|[-–—]+)$',
            caseSensitive: false,
          ).hasMatch(title) &&
          row.kind == RoutineKind.classSession) {
        continue;
      }
      if (code.isNotEmpty &&
          !title.toLowerCase().contains(code.toLowerCase())) {
        title = '$code · $title';
      }
      final rowWarnings = <String>[];
      if (day.isEmpty) rowWarnings.add('Choose the repeat days.');
      if (time.start == null) rowWarnings.add('Choose a start time.');
      if (row.kind == RoutineKind.classSession && end == null) {
        rowWarnings.add('Choose an end time.');
      }
      if (time.warning != null) rowWarnings.add(time.warning!);
      if (row.kind == RoutineKind.classSession &&
          time.start != null &&
          end != null &&
          end <= time.start!) {
        rowWarnings.add('Review the class start and end times.');
      }
      if (title.runes.length > 100) {
        title = String.fromCharCodes(title.runes.take(100));
        rowWarnings.add('Long title was shortened; review it.');
      }
      final details = [
        if ((f['component'] ?? '').trim().isNotEmpty)
          'Session: ${_clean(f['component']!)}',
        if ((f['details'] ?? '').trim().isNotEmpty) _clean(f['details']!),
      ].join('\n');
      final draft = ImportDraft(
        id: 'import-${drafts.length}',
        title: title,
        kind: row.kind,
        weekdays: day,
        startMinutes: time.start,
        endMinutes: row.kind == RoutineKind.meal ? null : end,
        details: _limit(details, 1200),
        location: _limit(_clean(f['location'] ?? ''), 160),
        instructor: _limit(_clean(f['instructor'] ?? ''), 160),
        warnings: rowWarnings,
      );
      final identityTitle = code.isNotEmpty ? code : _norm(title);
      final sortedDays = day.toList()..sort();
      final key =
          '${row.kind.name}|$identityTitle|${sortedDays.join(',')}|${time.start}|${draft.endMinutes}';
      final oldIndex = byKey[key];
      if (oldIndex != null) {
        final old = drafts[oldIndex];
        final mergedWarnings = {...old.warnings, ...draft.warnings};
        String merge(String a, String b) {
          if (a.isEmpty) return b;
          if (b.isEmpty || _norm(a).contains(_norm(b))) return a;
          if (_norm(b).contains(_norm(a))) return b;
          mergedWarnings.add(
            'A repeated row contains additional details. Review the combined information.',
          );
          return '$a $b';
        }

        final location = merge(old.location, draft.location);
        final instructor = merge(old.instructor, draft.instructor);
        drafts[oldIndex] = old.copyWith(
          location: _limit(location, 160),
          instructor: _limit(instructor, 160),
          details: old.details.length >= draft.details.length
              ? old.details
              : draft.details,
          warnings: mergedWarnings.toList(),
        );
      } else {
        if (drafts.length >= 200) {
          warnings.add(
            'Only the first 200 routines are shown. Import the remaining pages separately.',
          );
          break;
        }
        byKey[key] = drafts.length;
        drafts.add(draft);
      }
    }
    if (document.usedOcr) {
      warnings.add(
        'Text recognition can misread small print. Review days, times, rooms, and names before importing.',
      );
    }
    if (drafts.isEmpty) {
      warnings.add(
        'No clear weekly routines were found. Try a clearer image or a table with Day, Subject/Meal, Start, and End columns.',
      );
    }
    return ImportResult(
      drafts: drafts,
      warnings: warnings.toSet().toList(),
      sourcePages: document.pages.length,
    );
  }

  static String _limit(String value, int max) =>
      String.fromCharCodes(value.runes.take(max));
  static List<_Row> _tableRows(ImportTable table, RoutineKind kind) {
    final rows = table.rows;
    final output = <_Row>[];
    for (var index = 0; index < math.min(rows.length, 30); index++) {
      final header = rows[index];
      final days = {
        for (var col = 0; col < header.length; col++)
          if (parseImportWeekdays(header[col]).isNotEmpty)
            col: parseImportWeekdays(header[col]),
      };
      final timeHeaders = {
        for (var col = 0; col < header.length; col++)
          if (_times(header[col]).start != null) col: _times(header[col]),
      };
      final mealHeaders = <int, String>{};
      for (var col = 0; col < header.length; col++) {
        final meal = RegExp(
          r'\b(breakfast|brunch|lunch|dinner|supper|snacks?)\b',
          caseSensitive: false,
        ).firstMatch(header[col]);
        if (meal != null) mealHeaders[col] = meal.group(0)!;
      }
      if (mealHeaders.isNotEmpty &&
          (kind == RoutineKind.meal || mealHeaders.length >= 2)) {
        for (final cells in rows.skip(index + 1)) {
          final day = cells
              .where((c) => parseImportWeekdays(c).isNotEmpty)
              .firstOrNull;
          if (day == null) continue;
          for (final meal in mealHeaders.entries) {
            if (meal.key >= cells.length || _clean(cells[meal.key]).isEmpty) {
              continue;
            }
            output.add(
              _Row(
                {
                  'meal': meal.value[0].toUpperCase() + meal.value.substring(1),
                  'day': day,
                  'time': header[meal.key],
                  'details': cells[meal.key],
                },
                RoutineKind.meal,
                source: table.name,
              ),
            );
          }
        }
        return output;
      }
      if (days.length >= 2) {
        for (final cells in rows.skip(index + 1)) {
          final times = _times(
            cells.where((c) => _times(c).start != null).firstOrNull ?? '',
          );
          for (final column in days.entries) {
            if (column.key >= cells.length ||
                _clean(cells[column.key]).isEmpty) {
              continue;
            }
            final text = cells[column.key];
            final data = _cellDescription(text);
            output.add(
              _Row(
                {
                  ...data,
                  'day': column.value.map((d) => _dayNames[d - 1]).join(','),
                  'time': _clockText(times),
                },
                kind,
                source: table.name,
              ),
            );
          }
        }
        return output;
      }
      if (timeHeaders.length >= 2) {
        for (final cells in rows.skip(index + 1)) {
          final day = cells
              .where((c) => parseImportWeekdays(c).isNotEmpty)
              .firstOrNull;
          if (day == null) continue;
          for (final column in timeHeaders.entries) {
            if (column.key >= cells.length ||
                _clean(cells[column.key]).isEmpty) {
              continue;
            }
            output.add(
              _Row(
                {
                  ..._cellDescription(cells[column.key]),
                  'day': day,
                  'time': _clockText(column.value),
                },
                kind,
                source: table.name,
              ),
            );
          }
        }
        return output;
      }
      final fields = <int, String>{};
      for (var col = 0; col < header.length; col++) {
        final field = _field(header[col]);
        if (field != null) fields[col] = field;
      }
      if (!fields.values.any((f) => ['title', 'meal', 'code'].contains(f)) ||
          !fields.values.any(
            (f) => ['day', 'time', 'start', 'end'].contains(f),
          )) {
        continue;
      }
      final detected = fields.values.contains('meal') ? RoutineKind.meal : kind;
      for (final cells in rows.skip(index + 1)) {
        final values = <String, String>{};
        for (final field in fields.entries) {
          if (field.key < cells.length && field.value != 'ignored') {
            values[field.value] = cells[field.key];
          }
        }
        if (values.values.every((v) => v.trim().isEmpty)) continue;
        if (values.entries.any((e) => _field(e.value) == e.key)) continue;
        output.add(_Row(values, detected, source: table.name));
      }
      return output;
    }
    for (final cells in rows) {
      output.addAll(_plainText(cells.join(' | '), kind));
    }
    return output;
  }

  static String _clockText(_Times t) {
    String clock(int n) =>
        '${(n ~/ 60).toString().padLeft(2, '0')}:${(n % 60).toString().padLeft(2, '0')}';
    return t.start == null
        ? ''
        : '${clock(t.start!)}${t.end == null ? '' : ' - ${clock(t.end!)}'}';
  }

  static Map<String, String> _cellDescription(String text) {
    final lines = text
        .split(RegExp(r'[\n|]'))
        .map(_clean)
        .where((l) => l.isNotEmpty)
        .toList();
    final location = lines
        .where(
          (l) => RegExp(
            r'^(room|location|venue)\s*:',
            caseSensitive: false,
          ).hasMatch(l),
        )
        .map((l) => l.substring(l.indexOf(':') + 1))
        .join(' ');
    final teacher = lines
        .where(
          (l) => RegExp(
            r'^(teacher|instructor|faculty)\s*:',
            caseSensitive: false,
          ).hasMatch(l),
        )
        .map((l) => l.substring(l.indexOf(':') + 1))
        .join(' ');
    final title = lines
        .where(
          (l) => !RegExp(
            r'^(room|location|venue|teacher|instructor|faculty)\s*:',
            caseSensitive: false,
          ).hasMatch(l),
        )
        .join(' ');
    return {'title': title, 'location': location, 'instructor': teacher};
  }

  static List<List<ImportToken>> _lines(List<ImportToken> tokens) {
    final sorted = [...tokens]..sort((a, b) => a.centerY.compareTo(b.centerY));
    final lines = <List<ImportToken>>[];
    for (final token in sorted) {
      List<ImportToken>? target;
      for (final line in lines.reversed.take(3)) {
        if ((line.first.centerY - token.centerY).abs() <
            math.max(.0035, math.min(line.first.height, token.height) * .55)) {
          target = line;
          break;
        }
      }
      if (target == null) {
        lines.add([token]);
      } else {
        target.add(token);
      }
    }
    for (final line in lines) {
      line.sort((a, b) => a.x.compareTo(b.x));
    }
    return lines;
  }

  static _Schema? _detectSchema(List<ImportToken> tokens) {
    final dayHeaders = tokens.where((t) => _field(t.text) == 'day').toList();
    var inferred = false;
    if (dayHeaders.isEmpty) {
      final times = tokens.where((t) => _field(t.text) == 'time').toList();
      final repeatedDays = tokens
          .where((t) => parseImportWeekdays(t.text).length == 1)
          .toList();
      for (final time in times) {
        final below = repeatedDays.where((t) => t.y > time.y + .02).toList();
        if (below.length < 3) continue;
        final xs = below.map((t) => t.x).toList()..sort();
        final x = xs[xs.length ~/ 2];
        if (below.where((t) => (t.x - x).abs() < .012).length < 3 ||
            x >= time.x) {
          continue;
        }
        dayHeaders.add(
          ImportToken(
            text: 'Day',
            x: x,
            y: time.y,
            width: .025,
            height: time.height,
          ),
        );
        inferred = true;
      }
    }
    for (final day in dayHeaders) {
      final nearby = tokens
          .where((t) => (t.centerY - day.centerY).abs() < .017)
          .toList();
      if (inferred) nearby.add(day);
      final time = nearby
          .where((t) => ['time', 'start'].contains(_field(t.text)))
          .firstOrNull;
      if (time == null) continue;
      final candidates = <_Column>[];
      for (final token in nearby) {
        var field = _field(token.text);
        var x = token.x;
        final norm = _norm(token.text);
        if (norm == 'title' ||
            norm == 'code' ||
            norm == 'bucket' ||
            norm == 'coordinator') {
          final preceding =
              nearby
                  .where(
                    (p) =>
                        p.x <= token.x + .002 &&
                        token.x - p.x < .10 &&
                        (p.centerY - token.centerY).abs() < .014 &&
                        ['course', 'couse', 'subject'].contains(_norm(p.text)),
                  )
                  .toList()
                ..sort(
                  (a, b) =>
                      (a.x - token.x).abs().compareTo((b.x - token.x).abs()),
                );
          if (preceding.isNotEmpty) x = preceding.first.x;
        }
        if (norm == 'name') continue;
        if (norm == 'code') field = 'code';
        if (field != null) candidates.add(_Column(x, field));
      }
      if (inferred) {
        final titleColumn = candidates
            .where((c) => c.field == 'title')
            .firstOrNull;
        if (titleColumn != null) {
          final sessions = tokens
              .where(
                (t) =>
                    t.y > day.y + .02 &&
                    t.x > titleColumn.x &&
                    t.x < day.x &&
                    RegExp(
                      r'^(lecture|practical|tutorial|lab)[\s_-]*\d*$',
                      caseSensitive: false,
                    ).hasMatch(t.text),
              )
              .toList();
          if (sessions.length >= 3) {
            final xs = sessions.map((t) => t.x).toList()..sort();
            final componentX = xs[xs.length ~/ 2];
            candidates.add(_Column(componentX, 'component'));
            final groups = <int, List<double>>{};
            for (final t in tokens) {
              if (t.y > day.y + .02 &&
                  t.x > titleColumn.x + .07 &&
                  t.x < componentX - .015) {
                groups.putIfAbsent((t.x * 150).round(), () => []).add(t.x);
              }
            }
            final repeated = groups.values.where((g) => g.length >= 3).toList();
            if (repeated.isNotEmpty) {
              final most = repeated.map((g) => g.length).reduce(math.max);
              final columns =
                  repeated
                      .where((g) => g.length >= most * .7)
                      .map((g) => g.reduce(math.min))
                      .toList()
                    ..sort();
              if (columns.isNotEmpty) {
                candidates.add(_Column(columns.first, 'ignored'));
              }
            }
          }
        }
      }
      candidates.sort((a, b) => a.x.compareTo(b.x));
      final columns = <_Column>[];
      for (final col in candidates) {
        if (columns.isNotEmpty && (columns.last.x - col.x).abs() < .012) {
          if (columns.last.field == 'ignored' && col.field != 'ignored') {
            columns[columns.length - 1] = col;
          }
          continue;
        }
        columns.add(col);
      }
      if (!columns.any((c) => ['title', 'meal', 'code'].contains(c.field))) {
        continue;
      }
      return _Schema(
        columns,
        nearby.map((t) => t.y + t.height).reduce(math.max),
      );
    }
    return null;
  }

  static List<_Row> _geometryRows(
    List<ImportToken> tokens,
    _Schema schema,
    RoutineKind kind, {
    required bool headerPresent,
    required String source,
  }) {
    final dayCol = schema.columns.where((c) => c.field == 'day').firstOrNull;
    if (dayCol == null) return [];
    double endFor(_Column col) {
      final index = schema.columns.indexOf(col);
      return index + 1 < schema.columns.length
          ? schema.columns[index + 1].x - .002
          : 1;
    }

    final dayEnd = endFor(dayCol);
    final anchors =
        tokens
            .where(
              (t) =>
                  t.centerX >= dayCol.x - .004 &&
                  t.centerX < dayEnd &&
                  parseImportWeekdays(t.text).isNotEmpty &&
                  (!headerPresent || t.y > schema.bottom),
            )
            .toList()
          ..sort((a, b) => a.centerY.compareTo(b.centerY));
    if (anchors.isEmpty) return [];
    final rows = <_Row>[];
    for (var index = 0; index < anchors.length; index++) {
      final anchor = anchors[index];
      final upper = index == 0
          ? headerPresent
                ? schema.bottom
                : 0
          : (anchors[index - 1].centerY + anchor.centerY) / 2;
      final lower = index == anchors.length - 1
          ? anchors.length > 1
                ? math.min(
                    1.0,
                    anchor.centerY +
                        (anchor.centerY - anchors[index - 1].centerY) / 2,
                  )
                : 1.0
          : (anchor.centerY + anchors[index + 1].centerY) / 2;
      final cells = <String, String>{};
      for (final col in schema.columns) {
        if (col.field == 'ignored') continue;
        final words = tokens
            .where(
              (t) =>
                  t.centerY >= upper &&
                  t.centerY < lower &&
                  t.centerX >= col.x - .004 &&
                  t.centerX < endFor(col),
            )
            .toList();
        final value = _lines(words)
            .map((line) => line.map((t) => t.text).join(' '))
            .join(' ');
        cells[col.field] = _clean(value);
      }
      if (cells['day'] == null) cells['day'] = anchor.text;
      rows.add(
        _Row(
          cells,
          schema.columns.any((c) => c.field == 'meal')
              ? RoutineKind.meal
              : kind,
          source: source,
        ),
      );
    }
    return rows;
  }

  static List<_Row> _geometryGrid(List<ImportToken> tokens, RoutineKind kind) {
    final lines = _lines(tokens);
    for (final line in lines) {
      final headerDays = line
          .where((t) => parseImportWeekdays(t.text).isNotEmpty)
          .toList();
      if (headerDays.length < 2) continue;
      final dayXs = headerDays.map((t) => t.x).toList()..sort();
      final columns = [0.0, ...dayXs];
      final rows = <List<String>>[
        ['Time', ...headerDays.map((t) => t.text)],
      ];
      final following = lines.where((l) => l.first.y > line.first.y + .003);
      for (final l in following) {
        final row = List.filled(columns.length, '');
        for (final t in l) {
          var col = 0;
          for (var j = 1; j < columns.length; j++) {
            if (t.centerX >= columns[j] - .005) col = j;
          }
          row[col] = '${row[col]} ${t.text}'.trim();
        }
        if (_times(row.first).start != null) rows.add(row);
      }
      if (rows.length > 1) {
        return _tableRows(ImportTable(name: 'Timetable', rows: rows), kind);
      }
    }
    return [];
  }

  static List<_Row> _plainRows(List<ImportToken> tokens, RoutineKind kind) =>
      _lines(tokens)
          .expand((line) => _plainText(line.map((t) => t.text).join(' '), kind))
          .toList();
  static List<_Row> _plainText(String text, RoutineKind kind) {
    final day = parseImportWeekdays(text);
    final times = _times(text);
    if (day.isEmpty || times.start == null) return [];
    var title = text
        .replaceAll(_dayPattern, '')
        .replaceAll(
          RegExp(
            r'\b(daily|every\s*day|weekdays|weekends)\b',
            caseSensitive: false,
          ),
          '',
        );
    title = title.replaceAll(
      RegExp(
        r'(?<!\d)\d{1,2}(?::|\.)\d{2}(?::\d{2})?\s*(?:a\.?m\.?|p\.?m\.?)?|(?<!\d)\d{1,2}\s*(?:a\.?m\.?|p\.?m\.?)',
        caseSensitive: false,
      ),
      '',
    );
    title = title
        .replaceAll(
          RegExp(r'\b(to|from|through|until)\b', caseSensitive: false),
          '',
        )
        .replaceAll(RegExp(r'^[\s|,:;–—-]+|[\s|,:;–—-]+$'), '');
    if (_clean(title).isEmpty) return [];
    return [
      _Row({
        'title': _clean(title),
        'day': day.map((d) => _dayNames[d - 1]).join(','),
        'time': _clockText(times),
      }, kind),
    ];
  }
}
