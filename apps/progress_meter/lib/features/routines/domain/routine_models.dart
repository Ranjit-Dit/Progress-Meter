enum RoutineKind {
  classSession('Class'),
  meal('Food');

  const RoutineKind(this.label);
  final String label;
}

void _requiredText(String value, String field, int maximum) {
  if (value.trim().isEmpty || value.runes.length > maximum) {
    throw ArgumentError.value(
      value,
      field,
      'Must contain 1–$maximum characters.',
    );
  }
}

void _optionalText(String value, String field, int maximum) {
  if (value.runes.length > maximum) {
    throw ArgumentError.value(
      value,
      field,
      'Must contain at most $maximum characters.',
    );
  }
}

Set<int> _weekdays(Set<int> values) {
  if (values.isEmpty || values.any((day) => day < 1 || day > 7)) {
    throw ArgumentError.value(
      values,
      'weekdays',
      'Choose at least one weekday, Monday 1 through Sunday 7.',
    );
  }
  return Set.unmodifiable(values);
}

Set<int> _daysFromJson(Object? value) {
  if (value is! List || value.any((day) => day is! int)) {
    throw const FormatException('Routine weekdays must be a list of integers.');
  }
  final values = value.cast<int>();
  if (values.toSet().length != values.length) {
    throw const FormatException('Routine weekdays cannot contain duplicates.');
  }
  return values.toSet();
}

/// A weekly local-time schedule. Classes have an interval; food has a time.
class RoutineItem {
  RoutineItem({
    required this.id,
    required String title,
    required this.kind,
    required Set<int> weekdays,
    required this.startMinutes,
    this.endMinutes,
    String details = '',
    String location = '',
    String instructor = '',
  }) : title = title.trim(),
       details = details.trim(),
       location = location.trim(),
       instructor = instructor.trim(),
       weekdays = _weekdays(weekdays) {
    _requiredText(id, 'routine.id', 256);
    _requiredText(this.title, 'routine.title', 100);
    _optionalText(this.details, 'routine.details', 1200);
    _optionalText(this.location, 'routine.location', 160);
    _optionalText(this.instructor, 'routine.instructor', 160);
    if (startMinutes < 0 || startMinutes > 1439) {
      throw ArgumentError.value(
        startMinutes,
        'startMinutes',
        'Must be a minute within the day.',
      );
    }
    if (kind == RoutineKind.classSession &&
        (endMinutes == null ||
            endMinutes! <= startMinutes ||
            endMinutes! > 1439)) {
      throw ArgumentError.value(
        endMinutes,
        'endMinutes',
        'A class must end after it starts on the same day.',
      );
    }
    if (kind == RoutineKind.meal && endMinutes != null) {
      throw ArgumentError.value(
        endMinutes,
        'endMinutes',
        'Food routines use a single planned time.',
      );
    }
  }

  final String id;
  final String title;
  final RoutineKind kind;
  final Set<int> weekdays;
  final int startMinutes;
  final int? endMinutes;
  final String details;
  final String location;
  final String instructor;

  RoutineItem copyWith({
    String? title,
    Set<int>? weekdays,
    int? startMinutes,
    int? endMinutes,
    String? details,
    String? location,
    String? instructor,
  }) => RoutineItem(
    id: id,
    title: title ?? this.title,
    kind: kind,
    weekdays: weekdays ?? this.weekdays,
    startMinutes: startMinutes ?? this.startMinutes,
    endMinutes: endMinutes ?? this.endMinutes,
    details: details ?? this.details,
    location: location ?? this.location,
    instructor: instructor ?? this.instructor,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'kind': kind.name,
    'weekdays': weekdays.toList()..sort(),
    'startMinutes': startMinutes,
    'endMinutes': endMinutes,
    'details': details,
    'location': location,
    'instructor': instructor,
  };

  factory RoutineItem.fromJson(Map<String, dynamic> json) => RoutineItem(
    id: json['id'] as String,
    title: json['title'] as String,
    kind: RoutineKind.values.byName(json['kind'] as String),
    weekdays: _daysFromJson(json['weekdays']),
    startMinutes: json['startMinutes'] as int,
    endMinutes: json['endMinutes'] as int?,
    details: json['details'] as String? ?? '',
    location: json['location'] as String? ?? '',
    instructor: json['instructor'] as String? ?? '',
  );
}

/// Uses calendar fields directly: schedules and completions belong to local days.
DateTime routineDate(DateTime date) {
  if (date.year < 1 || date.year > 9999) {
    throw ArgumentError.value(
      date,
      'date',
      'Routine dates must use years 1–9999.',
    );
  }
  return DateTime(date.year, date.month, date.day);
}

String routineDateKey(DateTime date) {
  final day = routineDate(date);
  return '${day.year.toString().padLeft(4, '0')}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
}

DateTime routineDateFromKey(String key) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(key)) {
    throw ArgumentError.value(
      key,
      'dateKey',
      'Use a calendar date in YYYY-MM-DD format.',
    );
  }
  final year = int.parse(key.substring(0, 4));
  final month = int.parse(key.substring(5, 7));
  final day = int.parse(key.substring(8, 10));
  final parsed = DateTime(year, month, day);
  if (year < 1 ||
      parsed.year != year ||
      parsed.month != month ||
      parsed.day != day) {
    throw ArgumentError.value(
      key,
      'dateKey',
      'This calendar date does not exist.',
    );
  }
  return parsed;
}

/// One completion on one calendar date; never a permanent weekly checkbox.
class RoutineCompletion {
  RoutineCompletion({required this.routineId, required this.dateKey}) {
    _requiredText(routineId, 'completion.routineId', 256);
    routineDateFromKey(dateKey);
  }

  final String routineId;
  final String dateKey;
  String get key => '$routineId@$dateKey';
  DateTime get date => routineDateFromKey(dateKey);

  Map<String, dynamic> toJson() => {'routineId': routineId, 'dateKey': dateKey};

  factory RoutineCompletion.fromJson(Map<String, dynamic> json) =>
      RoutineCompletion(
        routineId: json['routineId'] as String,
        dateKey: json['dateKey'] as String,
      );
}
