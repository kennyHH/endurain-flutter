import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:endurain/core/database/tables.dart';
import 'package:endurain/core/models/activity.dart';
import 'package:endurain/core/services/encryption_service.dart';
import 'package:injectable/injectable.dart';

part 'app_database.g.dart';

@singleton
@DriftDatabase(tables: [Activities, TrackPoints])
class AppDatabase extends _$AppDatabase {
  // Default constructor uses the real database connection
  AppDatabase() : super(_openConnection());

  // Constructor for testing
  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          await m.addColumn(activities, activities.qualityMetricsJson);
        }
        if (from < 3) {
          await m.addColumn(activities, activities.activityTypeId);
        }
      },
    );
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'endurain.sqlite'));

    // Fetch the encryption key
    final encryptionService = EncryptionService();
    final key = await encryptionService.getDatabaseEncryptionKey();

    return NativeDatabase.createInBackground(
      file,
      setup: (database) {
        // Activate SQLCipher encryption
        database.execute("PRAGMA key = '$key';");
      },
    );
  });
}
