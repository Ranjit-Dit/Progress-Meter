import 'dart:convert';
import 'dart:io';

import '../domain/models.dart';

abstract interface class ProgressRepository {
  Future<ProgressData?> load();
  Future<void> save(ProgressData data);
}

/// Atomic replacement protects the last complete save from interrupted writes.
/// Invalid data is deliberately surfaced to the caller, never replaced by demos.
class JsonProgressRepository implements ProgressRepository {
  JsonProgressRepository(this.file);
  final File file;

  @override
  Future<ProgressData?> load() async {
    if (!await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      return ProgressData.fromJson(Map<String, dynamic>.from(decoded as Map));
    } on FileSystemException {
      rethrow;
    } catch (error) {
      throw FormatException('Saved progress could not be read: $error');
    }
  }

  @override
  Future<void> save(ProgressData data) async {
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(
      const JsonEncoder.withIndent('  ').convert(data.toJson()),
      flush: true,
    );
    await temporary.rename(file.path);
  }
}
