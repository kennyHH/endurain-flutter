import 'package:drift/drift.dart';
import 'package:endurain/core/models/activity.dart';

// Type converters for ActivityType
class ActivityTypeConverter extends TypeConverter<ActivityType, String> {
  const ActivityTypeConverter();

  @override
  ActivityType fromSql(String fromDb) {
    return ActivityType.values.firstWhere(
      (e) => e.name == fromDb,
      orElse: () => ActivityType.run,
    );
  }

  @override
  String toSql(ActivityType value) {
    return value.name;
  }
}

class Activities extends Table {
  TextColumn get id => text()();
  TextColumn get activityType => text().map(const ActivityTypeConverter())();
  IntColumn get activityTypeId => integer().nullable()();
  DateTimeColumn get startedAt => dateTime()();
  DateTimeColumn get endedAt => dateTime().nullable()();
  TextColumn get name => text().nullable()();
  BoolColumn get uploaded => boolean().withDefault(const Constant(false))();
  RealColumn get distanceMeters => real()();
  TextColumn get qualityMetricsJson => text().nullable()();

  // Storing duration explicitly might be redundant if we have start/end,
  // but good for performance if queries filter by duration.
  // The model calculates it on the fly, but for DB we might want to just rely on start/end.
  // However, the JSON model has 'durationSeconds'. Let's keep it simple and stick to the model fields.

  @override
  Set<Column> get primaryKey => {id};
}

class TrackPoints extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get activityId =>
      text().references(Activities, #id, onDelete: KeyAction.cascade)();
  RealColumn get latitude => real()();
  RealColumn get longitude => real()();
  DateTimeColumn get timestamp => dateTime()();
  RealColumn get altitudeMeters => real().nullable()();
  // Future proofing for Bluetooth sensors
  IntColumn get heartRate => integer().nullable()();
  IntColumn get cadence => integer().nullable()();
  RealColumn get speed => real().nullable()(); // Speed at this point
}
