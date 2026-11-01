import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

String personalText(Object? value, int maximum, {bool empty = false}) {
  if (value is! String ||
      (!empty && value.trim().isEmpty) ||
      value.runes.length > maximum) {
    throw const FormatException('Invalid personal AI text.');
  }
  return value.trim();
}

Map<String, dynamic> personalMap(Object? value) {
  if (value is! Map) throw const FormatException('Invalid personal AI object.');
  return Map<String, dynamic>.from(value);
}

List<String> personalTexts(Object? value, int maximum, int textMaximum) {
  if (value is! List || value.length > maximum) {
    throw const FormatException('Invalid personal AI list.');
  }
  return value.map((v) => personalText(v, textMaximum)).toList();
}

String personalFingerprint(Object value) =>
    sha256.convert(utf8.encode(jsonEncode(value))).toString();

String personalRandomId([int bytes = 16]) {
  final random = Random.secure();
  return List.generate(
    bytes,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

bool personalRequestId(String value) =>
    RegExp(r'^[A-Za-z0-9_-]{1,80}$').hasMatch(value);

Map<String, dynamic> personalObjectSchema(Map<String, dynamic> properties) => {
  'type': 'object',
  'additionalProperties': false,
  'required': properties.keys.toList(),
  'properties': properties,
};

Map<String, dynamic> personalStringSchema(int maximum) => {
  'type': 'string',
  'minLength': 1,
  'maxLength': maximum,
};
