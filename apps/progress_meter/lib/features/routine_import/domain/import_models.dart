import '../../routines/domain/routine_models.dart';

class ImportToken {
  const ImportToken({
    required this.text,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
  final String text;
  final double x, y, width, height;
  double get centerX => x + width / 2;
  double get centerY => y + height / 2;
  factory ImportToken.fromJson(Map<String, dynamic> json) => ImportToken(
    text: json['text'] as String,
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
    width: (json['width'] as num).toDouble(),
    height: (json['height'] as num).toDouble(),
  );
  Map<String, dynamic> toJson() => {
    'text': text,
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };
}

class ImportPage {
  ImportPage({
    required this.width,
    required this.height,
    required List<ImportToken> tokens,
  }) : tokens = List.unmodifiable(tokens);
  final double width, height;
  final List<ImportToken> tokens;
  factory ImportPage.fromJson(Map<String, dynamic> json) => ImportPage(
    width: (json['width'] as num).toDouble(),
    height: (json['height'] as num).toDouble(),
    tokens: (json['tokens'] as List)
        .map((t) => ImportToken.fromJson(Map<String, dynamic>.from(t as Map)))
        .toList(),
  );
  Map<String, dynamic> toJson() => {
    'width': width,
    'height': height,
    'tokens': tokens.map((t) => t.toJson()).toList(),
  };
}

class ImportTable {
  ImportTable({required this.name, required List<List<String>> rows})
    : rows = List.unmodifiable(rows.map((r) => List<String>.unmodifiable(r)));
  final String name;
  final List<List<String>> rows;
  factory ImportTable.fromJson(Map<String, dynamic> json) => ImportTable(
    name: json['name'] as String,
    rows: (json['rows'] as List)
        .map((r) => (r as List).cast<String>())
        .toList(),
  );
  Map<String, dynamic> toJson() => {'name': name, 'rows': rows};
}

class ImportDocument {
  ImportDocument({
    List<ImportPage> pages = const [],
    List<ImportTable> tables = const [],
    this.usedOcr = false,
    List<String> warnings = const [],
  }) : pages = List.unmodifiable(pages),
       tables = List.unmodifiable(tables),
       warnings = List.unmodifiable(warnings);
  final List<ImportPage> pages;
  final List<ImportTable> tables;
  final bool usedOcr;
  final List<String> warnings;
  factory ImportDocument.fromJson(Map<String, dynamic> json) => ImportDocument(
    pages: (json['pages'] as List? ?? [])
        .map((p) => ImportPage.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList(),
    tables: (json['tables'] as List? ?? [])
        .map((p) => ImportTable.fromJson(Map<String, dynamic>.from(p as Map)))
        .toList(),
    usedOcr: json['usedOcr'] as bool? ?? false,
    warnings: (json['warnings'] as List? ?? []).cast<String>(),
  );
  Map<String, dynamic> toJson() => {
    'pages': pages.map((p) => p.toJson()).toList(),
    'tables': tables.map((t) => t.toJson()).toList(),
    'usedOcr': usedOcr,
    'warnings': warnings,
  };
}

const _unspecified = Object();

class ImportDraft {
  ImportDraft({
    required this.id,
    required this.title,
    required this.kind,
    required Set<int> weekdays,
    this.startMinutes,
    this.endMinutes,
    this.details = '',
    this.location = '',
    this.instructor = '',
    List<String> warnings = const [],
  }) : weekdays = Set.unmodifiable(weekdays),
       warnings = List.unmodifiable(warnings);
  final String id, title, details, location, instructor;
  final RoutineKind kind;
  final Set<int> weekdays;
  final int? startMinutes, endMinutes;
  final List<String> warnings;
  bool get isValid {
    try {
      toRoutineItem();
      return true;
    } catch (_) {
      return false;
    }
  }

  RoutineItem toRoutineItem({String? id}) {
    if (startMinutes == null) {
      throw const FormatException('Choose a start time before importing.');
    }
    return RoutineItem(
      id: id ?? this.id,
      title: title,
      kind: kind,
      weekdays: weekdays,
      startMinutes: startMinutes!,
      endMinutes: kind == RoutineKind.meal ? null : endMinutes,
      details: details,
      location: location,
      instructor: instructor,
    );
  }

  ImportDraft copyWith({
    String? title,
    RoutineKind? kind,
    Set<int>? weekdays,
    Object? startMinutes = _unspecified,
    Object? endMinutes = _unspecified,
    String? details,
    String? location,
    String? instructor,
    List<String>? warnings,
  }) => ImportDraft(
    id: id,
    title: title ?? this.title,
    kind: kind ?? this.kind,
    weekdays: weekdays ?? this.weekdays,
    startMinutes: identical(startMinutes, _unspecified)
        ? this.startMinutes
        : startMinutes as int?,
    endMinutes: identical(endMinutes, _unspecified)
        ? this.endMinutes
        : endMinutes as int?,
    details: details ?? this.details,
    location: location ?? this.location,
    instructor: instructor ?? this.instructor,
    warnings: warnings ?? this.warnings,
  );
}

class ImportResult {
  ImportResult({
    required List<ImportDraft> drafts,
    List<String> warnings = const [],
    this.sourcePages = 0,
  }) : drafts = List.unmodifiable(drafts),
       warnings = List.unmodifiable(warnings);
  final List<ImportDraft> drafts;
  final List<String> warnings;
  final int sourcePages;
}
