import 'dart:async';
import 'dart:convert';

import 'package:endurain/core/models/activity.dart';
import 'package:endurain/core/services/secure_storage_service.dart';

abstract class ActivityRepository {
  Future<void> create(Activity activity);
  Future<void> update(Activity activity);
  Future<Activity?> getById(String id);
  Future<List<Activity>> listAll();
  Stream<List<Activity>> watchAll();
  Future<void> delete(String id);
}

class InMemoryActivityRepository implements ActivityRepository {
  final Map<String, Activity> _items = <String, Activity>{};
  final StreamController<List<Activity>> _streamController =
      StreamController<List<Activity>>.broadcast(sync: true);

  @override
  Future<void> create(Activity activity) async {
    _items[activity.id] = activity;
    _emit();
  }

  @override
  Future<void> update(Activity activity) async {
    _items[activity.id] = activity;
    _emit();
  }

  @override
  Future<Activity?> getById(String id) async {
    return _items[id];
  }

  @override
  Future<List<Activity>> listAll() async {
    return _sortedItems();
  }

  @override
  Stream<List<Activity>> watchAll() async* {
    yield _sortedItems();
    yield* _streamController.stream;
  }

  @override
  Future<void> delete(String id) async {
    _items.remove(id);
    _emit();
  }

  List<Activity> _sortedItems() {
    final values = _items.values.toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return List<Activity>.unmodifiable(values);
  }

  void _emit() {
    if (!_streamController.isClosed) {
      _streamController.add(_sortedItems());
    }
  }
}

class PersistentActivityRepository implements ActivityRepository {
  PersistentActivityRepository({SecureStorageService? storage})
    : _storage = storage ?? SecureStorageService();

  static const String _activitiesStorageKey = 'activities_v1';

  final SecureStorageService _storage;
  final Map<String, Activity> _items = <String, Activity>{};
  final StreamController<List<Activity>> _streamController =
      StreamController<List<Activity>>.broadcast(sync: true);

  Future<void>? _loadFuture;

  @override
  Future<void> create(Activity activity) async {
    await _ensureLoaded();
    _items[activity.id] = activity;
    await _persistAndEmit();
  }

  @override
  Future<void> update(Activity activity) async {
    await _ensureLoaded();
    _items[activity.id] = activity;
    await _persistAndEmit();
  }

  @override
  Future<Activity?> getById(String id) async {
    await _ensureLoaded();
    return _items[id];
  }

  @override
  Future<List<Activity>> listAll() async {
    await _ensureLoaded();
    return _sortedItems();
  }

  @override
  Stream<List<Activity>> watchAll() async* {
    await _ensureLoaded();
    yield _sortedItems();
    yield* _streamController.stream;
  }

  @override
  Future<void> delete(String id) async {
    await _ensureLoaded();
    _items.remove(id);
    await _persistAndEmit();
  }

  Future<void> _ensureLoaded() {
    _loadFuture ??= _loadFromStorage();
    return _loadFuture!;
  }

  Future<void> _loadFromStorage() async {
    final raw = await _storage.read(key: _activitiesStorageKey);
    if (raw == null || raw.trim().isEmpty) {
      return;
    }
    try {
      final decoded = json.decode(raw);
      if (decoded is! List<dynamic>) {
        return;
      }
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) {
          continue;
        }
        final activity = Activity.fromJson(item);
        _items[activity.id] = activity;
      }
    } catch (_) {
      // Corrupt data should never break app startup.
    }
  }

  Future<void> _persistAndEmit() async {
    final payload = json.encode(
      _items.values.map((activity) => activity.toJson()).toList(),
    );
    await _storage.write(key: _activitiesStorageKey, value: payload);
    _emit();
  }

  List<Activity> _sortedItems() {
    final values = _items.values.toList()
      ..sort((a, b) => a.startedAt.compareTo(b.startedAt));
    return List<Activity>.unmodifiable(values);
  }

  void _emit() {
    if (!_streamController.isClosed) {
      _streamController.add(_sortedItems());
    }
  }
}
