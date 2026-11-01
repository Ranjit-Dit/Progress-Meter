class ReminderSettings {
  const ReminderSettings({this.enabled = false, this.leadMinutes = 10})
    : assert(leadMinutes >= 0 && leadMinutes <= 60);

  final bool enabled;
  final int leadMinutes;

  ReminderSettings copyWith({bool? enabled, int? leadMinutes}) {
    final minutes = leadMinutes ?? this.leadMinutes;
    if (minutes < 0 || minutes > 60) {
      throw ArgumentError('Choose a reminder lead time from 0 to 60 minutes.');
    }
    return ReminderSettings(
      enabled: enabled ?? this.enabled,
      leadMinutes: minutes,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'leadMinutes': leadMinutes,
  };

  factory ReminderSettings.fromJson(Map<String, dynamic> json) {
    final enabled = json['enabled'];
    final minutes = json['leadMinutes'];
    if (enabled is! bool || minutes is! int || minutes < 0 || minutes > 60) {
      throw const FormatException('Invalid reminder settings.');
    }
    return ReminderSettings(enabled: enabled, leadMinutes: minutes);
  }
}
