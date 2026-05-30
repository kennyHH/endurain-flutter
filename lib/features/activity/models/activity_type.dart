enum ActivityType {
  run('run'),
  ride('ride'),
  walk('walk'),
  hike('hike'),
  other('other');

  const ActivityType(this.apiValue);

  final String apiValue;

  static ActivityType fromApiValue(String? value) {
    for (final type in values) {
      if (type.apiValue == value) {
        return type;
      }
    }
    return ActivityType.other;
  }
}
