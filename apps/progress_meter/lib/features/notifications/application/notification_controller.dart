import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../app/progress_controller.dart';
import '../data/reminder_service.dart';
import '../domain/reminder_plan.dart';

class NotificationController extends ChangeNotifier {
  NotificationController({required this.progress, ReminderService? service})
    : service = service ?? NativeReminderService() {
    progress.addListener(_changed);
  }
  final ProgressController progress;
  final ReminderService service;
  ReminderStatus status = const ReminderStatus(
    ReminderAuthorization.notDetermined,
  );
  bool busy = false;
  bool permissionProblem = false;
  String? error;
  int pendingCount = 0, truncatedCount = 0;
  bool get supported =>
      status.authorization != ReminderAuthorization.unsupported;
  bool _closed = false, _dirty = false;
  String? _fingerprint;
  Future<void>? _syncing;

  Future<void> initialize() => refresh();
  void _changed() {
    final next = jsonEncode({
      'settings': progress.data.reminderSettings.toJson(),
      'routines': progress.data.routines.map((r) => r.toJson()).toList(),
      'tasks': progress.data.dailyTasks.map((t) => t.toJson()).toList(),
    });
    if (next == _fingerprint || _closed) return;
    _fingerprint = next;
    unawaited(refresh());
  }

  Future<void> refresh() {
    if (_closed) return Future.value();
    _dirty = true;
    return _syncing ??= _sync().whenComplete(() {
      _syncing = null;
      if (_dirty && !_closed) unawaited(refresh());
    });
  }

  Future<void> _sync() async {
    while (_dirty && !_closed) {
      _dirty = false;
      try {
        final latest = await service.status();
        if (_closed) return;
        status = latest;
        pendingCount = latest.pendingCount;
        if (supported) {
          final plan = ReminderPlanner.build(
            routines: progress.data.routines,
            tasks: progress.data.dailyTasks,
            settings: progress.data.reminderSettings,
          );
          truncatedCount = plan.truncatedCount;
          pendingCount = await service.replacePlan(
            latest.authorization == ReminderAuthorization.authorized
                ? plan.reminders
                : [],
          );
        }
        if (status.authorization == ReminderAuthorization.authorized) {
          permissionProblem = false;
        }
        error = null;
      } catch (_) {
        if (!_closed) {
          error =
              'Reminders could not be updated. Please refresh and try again.';
        }
      }
      if (!_closed) notifyListeners();
    }
  }

  Future<void> setEnabled(bool enabled) async {
    if (busy || _closed) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      if (enabled) {
        permissionProblem = false;
        try {
          status = await service.status();
          if (!supported) throw StateError('unsupported');
          if (status.authorization != ReminderAuthorization.authorized &&
              !await service.requestPermission().timeout(
                const Duration(seconds: 45),
              )) {
            status = await service.status();
            permissionProblem = true;
            error = 'Notifications are blocked. Allow Progress Meter in macOS Notification Settings, then enable reminders again.';
            return;
          }
        } catch (_) {
          permissionProblem = true;
          error = 'macOS could not request notification access. Open macOS Settings, allow Progress Meter notifications, then enable reminders again.';
          return;
        }
      }
      await progress.updateReminderSettings(
        progress.data.reminderSettings.copyWith(enabled: enabled),
      );
      await refresh();
    } catch (_) {
      error = 'Your reminder preference could not be saved. Please try again.';
    } finally {
      if (!_closed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> setLeadMinutes(int minutes) async {
    if (busy || _closed) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await progress.updateReminderSettings(
        progress.data.reminderSettings.copyWith(leadMinutes: minutes),
      );
      await refresh();
    } catch (_) {
      error = 'Your reminder time could not be saved. Please try again.';
    } finally {
      if (!_closed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> sendTest() async {
    if (busy || _closed) return;
    busy = true;
    error = null;
    notifyListeners();
    try {
      await service.sendTest();
    } catch (_) {
      error = 'A test notification could not be scheduled. Check macOS notification permission.';
    } finally {
      if (!_closed) {
        busy = false;
        notifyListeners();
      }
    }
  }

  Future<void> openSettings() async {
    try {
      await service.openSettings();
    } catch (_) {
      if (!_closed) {
        error = 'Open System Settings → Notifications → Progress Meter.';
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _closed = true;
    progress.removeListener(_changed);
    super.dispose();
  }
}
