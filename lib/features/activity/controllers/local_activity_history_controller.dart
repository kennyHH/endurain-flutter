import 'package:endurain/core/models/app_exception.dart';
import 'package:endurain/features/activity/models/local_activity_record.dart';
import 'package:endurain/features/activity/repositories/activity_retention_settings_repository.dart';
import 'package:endurain/features/activity/repositories/local_activity_repository.dart';
import 'package:endurain/features/activity/services/activity_upload_service.dart';
import 'package:flutter/foundation.dart';

class LocalActivityHistoryController extends ChangeNotifier {
  LocalActivityHistoryController({
    required LocalActivityRepository repository,
    required ActivityUploadService uploadService,
    ActivityRetentionSettingsRepository? retentionSettingsRepository,
    DateTime Function()? now,
  }) : _repository = repository,
       _uploadService = uploadService,
       _retentionSettingsRepository = retentionSettingsRepository,
       _now = now ?? DateTime.now;

  final LocalActivityRepository _repository;
  final ActivityUploadService _uploadService;
  final ActivityRetentionSettingsRepository? _retentionSettingsRepository;
  final DateTime Function() _now;

  List<LocalActivityRecord> _records = const [];
  Set<String> _busyRecordIds = const {};
  bool _isLoading = false;
  Object? _error;
  bool _isDisposed = false;

  List<LocalActivityRecord> get records => List.unmodifiable(_records);

  bool get isLoading => _isLoading;

  Object? get error => _error;

  bool isBusy(String id) => _busyRecordIds.contains(id);

  LocalActivityRecord? recordById(String id) {
    for (final record in _records) {
      if (record.id == id) {
        return record;
      }
    }
    return null;
  }

  Future<bool> hasGpx(LocalActivityRecord record) {
    return _repository.hasGpx(record);
  }

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    _notifyListeners();
    try {
      _records = await _repository.list();
    } catch (error) {
      _error = error;
    } finally {
      _isLoading = false;
      _notifyListeners();
    }
  }

  Future<void> refresh() => load();

  Future<void> retryUpload(String id) async {
    if (_busyRecordIds.contains(id)) {
      return;
    }
    final record = await _repository.get(id);
    if (record == null) {
      throw const AppException(AppErrorCode.activityLocalActivityNotFound);
    }

    _setBusy(id, busy: true);
    LocalActivityRecord updatedRecord = record;
    final attemptedAt = _now().toUtc();
    try {
      updatedRecord = record.copyWith(
        uploadStatus: LocalActivityUploadStatus.pending,
        updatedAt: attemptedAt,
        lastUploadAttemptAt: attemptedAt,
        lastUploadErrorCode: null,
      );
      await _repository.upsert(updatedRecord);
      _replaceRecord(updatedRecord);

      if (!_uploadService.isConfigured) {
        throw const AppException(AppErrorCode.activityUploadNotConfigured);
      }
      final filePath = await _repository.readGpxFilePath(updatedRecord);
      await _uploadService.uploadGpx(
        ActivityUploadRequest(
          filePath: filePath,
          activityType: updatedRecord.activityType,
        ),
      );

      final uploadedAt = _now().toUtc();
      updatedRecord = updatedRecord.copyWith(
        uploadStatus: LocalActivityUploadStatus.uploaded,
        updatedAt: uploadedAt,
        uploadedAt: uploadedAt,
        lastUploadAttemptAt: attemptedAt,
        lastUploadErrorCode: null,
      );
      await _repository.upsert(updatedRecord);
      if (!await _shouldRetainUploadedGpx()) {
        await _repository.deleteGpx(updatedRecord);
      }
      await load();
    } catch (error) {
      final failedRecord = updatedRecord.copyWith(
        uploadStatus: LocalActivityUploadStatus.failed,
        updatedAt: _now().toUtc(),
        lastUploadAttemptAt: attemptedAt,
        lastUploadErrorCode: _safeUploadErrorCode(error),
      );
      await _repository.upsert(failedRecord);
      _replaceRecord(failedRecord);
      rethrow;
    } finally {
      _setBusy(id, busy: false);
    }
  }

  Future<void> delete(String id) async {
    if (_busyRecordIds.contains(id)) {
      return;
    }
    _setBusy(id, busy: true);
    try {
      await _repository.delete(id);
      await load();
    } finally {
      _setBusy(id, busy: false);
    }
  }

  void _replaceRecord(LocalActivityRecord record) {
    final records = [..._records];
    final index = records.indexWhere((item) => item.id == record.id);
    if (index == -1) {
      records.add(record);
    } else {
      records[index] = record;
    }
    records.sort((left, right) => right.endedAt.compareTo(left.endedAt));
    _records = records;
    _notifyListeners();
  }

  void _setBusy(String id, {required bool busy}) {
    final ids = {..._busyRecordIds};
    if (busy) {
      ids.add(id);
    } else {
      ids.remove(id);
    }
    _busyRecordIds = ids;
    _notifyListeners();
  }

  AppErrorCode _safeUploadErrorCode(Object error) {
    return error is AppException
        ? error.code
        : AppErrorCode.activityUploadFailed;
  }

  Future<bool> _shouldRetainUploadedGpx() async {
    return await _retentionSettingsRepository?.isRetainUploadedGpxEnabled() ??
        true;
  }

  void _notifyListeners() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
