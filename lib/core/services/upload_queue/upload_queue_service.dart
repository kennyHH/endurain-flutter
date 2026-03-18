import 'package:endurain/core/models/activity.dart';
import 'package:injectable/injectable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

@singleton
class UploadQueueService {
  static const _queueKey = 'endurain_upload_queue';

  Future<List<Activity>> getQueue() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = prefs.getStringList(_queueKey) ?? [];
    return jsonList
        .map((e) {
          try {
            return Activity.fromJson(json.decode(e) as Map<String, dynamic>);
          } catch (_) {
            return null;
          }
        })
        .whereType<Activity>()
        .toList();
  }

  Future<void> addToQueue(Activity activity) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = await getQueue();
    
    // Avoid duplicates
    if (queue.any((e) => e.id == activity.id)) return;
    
    queue.add(activity);
    await _saveQueue(prefs, queue);
  }

  Future<void> removeFromQueue(String activityId) async {
    final prefs = await SharedPreferences.getInstance();
    final queue = await getQueue();
    queue.removeWhere((e) => e.id == activityId);
    await _saveQueue(prefs, queue);
  }

  Future<void> _saveQueue(SharedPreferences prefs, List<Activity> queue) async {
    final jsonList = queue.map((e) => json.encode(e.toJson())).toList();
    await prefs.setStringList(_queueKey, jsonList);
  }
  
  Future<void> clearQueue() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey);
  }
}
