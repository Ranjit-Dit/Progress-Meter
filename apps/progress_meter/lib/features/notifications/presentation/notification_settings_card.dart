import 'package:flutter/material.dart';

import '../../../common/app_theme.dart';
import '../application/notification_controller.dart';
import '../data/reminder_service.dart';

class NotificationSettingsCard extends StatelessWidget {
  const NotificationSettingsCard({super.key, required this.controller});
  final NotificationController controller;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final c = controller;
      final settings = c.progress.data.reminderSettings;
      return Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.line),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Notifications and reminders',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              const Text(
                'Get reminders for weekly classes and meals, and daily tasks that have a time. macOS delivers scheduled reminders even when the app is closed.',
                style: TextStyle(color: AppColors.muted, height: 1.7),
              ),
              const SizedBox(height: 16),
              if (!c.supported)
                const Text(
                  'Timed notifications are currently available in the macOS app.',
                )
              else ...[
                SwitchListTile.adaptive(
                  key: const Key('notifications-enabled'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Enable timed reminders'),
                  subtitle: Text(
                    c.status.authorization == ReminderAuthorization.denied
                        ? 'Permission is blocked in macOS Settings.'
                        : settings.enabled
                        ? '${c.pendingCount} reminders scheduled'
                        : 'Off until you enable them.',
                  ),
                  value: settings.enabled,
                  onChanged: c.busy ? null : c.setEnabled,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 235,
                      child: DropdownButtonFormField<int>(
                        key: ValueKey(
                          'notification-lead-${settings.leadMinutes}',
                        ),
                        initialValue: settings.leadMinutes,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Remind me',
                        ),
                        items:
                            {
                                  ...[0, 5, 10, 15, 30, 60],
                                  settings.leadMinutes,
                                }
                                .map(
                                  (m) => DropdownMenuItem(
                                    value: m,
                                    child: Text(
                                      m == 0
                                          ? 'At the scheduled time'
                                          : '$m minutes before',
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged: c.busy
                            ? null
                            : (value) {
                                if (value != null) c.setLeadMinutes(value);
                              },
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('notifications-refresh'),
                      onPressed: c.busy ? null : c.refresh,
                      icon: const Icon(Icons.refresh, size: 17),
                      label: const Text('Refresh'),
                    ),
                    OutlinedButton(
                      key: const Key('notifications-test'),
                      onPressed:
                          c.busy ||
                              !settings.enabled ||
                              c.status.authorization !=
                                  ReminderAuthorization.authorized
                          ? null
                          : c.sendTest,
                      child: const Text('Test notification'),
                    ),
                    if (c.status.authorization ==
                            ReminderAuthorization.denied ||
                        c.permissionProblem)
                      TextButton(
                        onPressed: c.openSettings,
                        child: const Text('Open macOS Settings'),
                      ),
                  ],
                ),
                if (c.truncatedCount > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      '${c.truncatedCount} additional reminders exceed the current 64-request limit. Dated tasks are scheduled first; open the app after completing them to refresh the remaining schedule.',
                    ),
                  ),
                if (c.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      c.error!,
                      key: const Key('notifications-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 14),
              const Text(
                'Tasks without a time have no notification. Completed tasks are removed from the schedule. Weekly reminders repeat until their routine is edited or deleted. Focus modes and macOS alert settings can silence banners.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.muted,
                  height: 1.7,
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
