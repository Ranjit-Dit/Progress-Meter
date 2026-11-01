import '../../routines/domain/routine_models.dart';

String routineImportIdentity(RoutineItem item) {
  final title = item.title.toLowerCase().replaceAll(
    RegExp(r'[^\p{L}\p{N}+#]', unicode: true),
    '',
  );
  return '${item.kind.name}|$title|${item.startMinutes}|${item.endMinutes}';
}

/// Only missing weekdays are imported; existing routines are never overwritten.
Set<int> newImportDays(RoutineItem item, Iterable<RoutineItem> existing) {
  final key = routineImportIdentity(item);
  final covered = <int>{};
  for (final other in existing) {
    if (routineImportIdentity(other) == key) covered.addAll(other.weekdays);
  }
  return item.weekdays.difference(covered);
}
