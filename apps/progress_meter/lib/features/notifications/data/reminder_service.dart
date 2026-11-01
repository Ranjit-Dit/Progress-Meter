import 'dart:io';

import 'package:flutter/services.dart';

import '../domain/reminder_plan.dart';

enum ReminderAuthorization { notDetermined, authorized, denied, unsupported }

class ReminderStatus {
  const ReminderStatus(this.authorization, {this.pendingCount = 0});
  final ReminderAuthorization authorization;
  final int pendingCount;
}

abstract interface class ReminderService {
  Future<ReminderStatus> status();
  Future<bool> requestPermission();
  Future<int> replacePlan(List<PlannedReminder> plan);
  Future<void> sendTest();
  Future<void> openSettings();
}

class NativeReminderService implements ReminderService {
  NativeReminderService({MethodChannel? channel, bool? supported})
    : _channel = channel ?? const MethodChannel('progress_meter/reminders'),
      _supported = supported ?? Platform.isMacOS;
  final MethodChannel _channel;
  final bool _supported;

  @override
  Future<ReminderStatus> status() async {
    if (!_supported) {
      return const ReminderStatus(ReminderAuthorization.unsupported);
    }
    try {
      final json = await _channel.invokeMapMethod<String, dynamic>('status');
      final authorization = switch (json?['authorization']) {
        'authorized' => ReminderAuthorization.authorized,
        'denied' => ReminderAuthorization.denied,
        _ => ReminderAuthorization.notDetermined,
      };
      return ReminderStatus(
        authorization,
        pendingCount: json?['pendingCount'] as int? ?? 0,
      );
    } on MissingPluginException {
      return const ReminderStatus(ReminderAuthorization.unsupported);
    }
  }

  @override
  Future<bool> requestPermission() async =>
      _supported &&
      (await _channel.invokeMethod<bool>('requestPermission') ?? false);
  @override
  Future<int> replacePlan(List<PlannedReminder> plan) async {
    if (!_supported) return 0;
    return await _channel.invokeMethod<int>('replacePlan', {
          'reminders': plan.map((r) => r.toJson()).toList(),
        }) ??
        0;
  }

  @override
  Future<void> sendTest() => _channel.invokeMethod<void>('sendTest');
  @override
  Future<void> openSettings() => _channel.invokeMethod<void>('openSettings');
}
