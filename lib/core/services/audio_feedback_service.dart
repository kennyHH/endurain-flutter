import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';

class AudioFeedbackService {
  final FlutterTts _tts = FlutterTts();
  bool _isEnabled = true;
  bool _announceSplits = true;
  bool _announceStart = true;
  bool _announceGps = true;
  
  static final AudioFeedbackService _instance = AudioFeedbackService._internal();
  factory AudioFeedbackService() => _instance;
  
  AudioFeedbackService._internal() {
    _init();
  }

  Future<void> _init() async {
    // await _tts.setLanguage("en-US"); // Commented out to prevent error if not ready
    // We defer language setting to explicit call or check
    // Actually, user wants English only.
    try {
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.5);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      
      // Configure iOS audio session
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.duckOthers,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
      );
    } catch (e) {
      print("TTS Init Error: $e");
    }
  }

  Future<void> updateSettings({
    required bool enabled,
    required bool announceSplits,
    required bool announceStart,
    bool announceGps = true,
  }) async {
    _isEnabled = enabled;
    _announceSplits = announceSplits;
    _announceStart = announceStart;
    _announceGps = announceGps;
  }
  
  void toggleEnabled(bool enabled) {
    _isEnabled = enabled;
  }
  
  bool get isEnabled => _isEnabled;

  Future<void> speak(String text) async {
    if (!_isEnabled) return;
    if (text.isNotEmpty) {
      await _tts.speak(text);
    }
  }

  Future<void> stop() async {
    await _tts.stop();
  }

  Future<void> announceCountdown(int seconds) async {
    if (!_isEnabled || !_announceStart) return;
    await speak(seconds.toString());
  }

  Future<void> announceStart() async {
    if (!_isEnabled || !_announceStart) return;
    await speak("Go!");
  }

  Future<void> announceSplit({
    required int km,
    required double paceSecondsPerKm,
  }) async {
    if (!_isEnabled || !_announceSplits) return;
    
    final minutes = (paceSecondsPerKm / 60).floor();
    final seconds = (paceSecondsPerKm % 60).round();
    
    // "Kilometer 1. Pace 5:30"
    final msg = "Kilometer $km. Pace $minutes ${seconds.toString().padLeft(2, '0')}";
    await speak(msg);
  }
  
  Future<void> announceGpsStatus({required bool isLost}) async {
    if (!_isEnabled || !_announceGps) return;
    if (isLost) {
      await speak("GPS signal lost");
    } else {
      await speak("GPS signal recovered");
    }
  }
}
