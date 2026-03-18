import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:endurain/core/services/secure_storage_service.dart';
import 'package:injectable/injectable.dart';
import 'package:audio_session/audio_session.dart';

const _forceEnglishVoiceCoach = bool.fromEnvironment(
  'ENDURAIN_TTS_ENGLISH_ONLY',
  defaultValue: true,
);

@singleton
class AudioFeedbackService {
  final FlutterTts _tts = FlutterTts();
  final SecureStorageService _storage;
  late final AudioSession _audioSession;
  final Completer<void> _initCompleter = Completer<void>();
  final StreamController<bool> _enabledStreamController =
      StreamController<bool>.broadcast();

  bool _isEnabled = true;
  bool _announceSplits = true;
  bool _announceStart = true;
  bool _announceGps = true;

  double _currentVolume = 0.8;
  String _speechLanguageCode = 'en';
  DateTime? _lastVoiceCoachStateAnnouncementAt;
  static const Duration _voiceCoachToggleAnnouncementCooldown = Duration(
    milliseconds: 500,
  );

  AudioFeedbackService(this._storage) {
    _init();
  }

  Future<void> _ready() => _initCompleter.future;

  Future<void> _init() async {
    try {
      final dynamic voicesRaw = await _tts.getVoices;
      final platformLanguageCode = PlatformDispatcher
          .instance
          .locale
          .languageCode
          .toLowerCase();
      String selectedLanguage = 'en-US';
      if (voicesRaw is List) {
        final normalizedVoices = voicesRaw
            .whereType<Map<Object?, Object?>>()
            .map((voice) => voice)
            .toList();
        selectedLanguage = selectTtsLocale(
          voices: normalizedVoices,
          forceEnglish: _forceEnglishVoiceCoach,
          platformLanguageCode: platformLanguageCode,
        );
      }

      _speechLanguageCode = _forceEnglishVoiceCoach
          ? 'en'
          : _normalizeLanguageCode(selectedLanguage);

      await _tts.setLanguage(selectedLanguage);
      await _tts.setPitch(1.0);
      await _tts.setSpeechRate(0.5);

      final storedEnabled = await _storage.read(key: 'audio_enabled');
      if (storedEnabled != null) {
        _isEnabled = storedEnabled == 'true';
      }
      final storedVolume = await _storage.read(key: 'audio_volume');
      if (storedVolume != null) {
        _currentVolume = (double.tryParse(storedVolume) ?? 0.8).clamp(0.0, 1.0);
      }
      final announceStartRaw = await _storage.read(key: 'audio_announce_start');
      _announceStart = announceStartRaw == null ? true : announceStartRaw == 'true';
      final announceSplitsRaw = await _storage.read(
        key: 'audio_announce_splits',
      );
      _announceSplits =
          announceSplitsRaw == null ? true : announceSplitsRaw == 'true';
      final announceGpsRaw = await _storage.read(key: 'audio_announce_gps');
      _announceGps = announceGpsRaw == null ? true : announceGpsRaw == 'true';
      _emitEnabledChanged();
      await _tts.setVolume(_currentVolume);

      _audioSession = await AudioSession.instance;
      await _audioSession.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions:
              AVAudioSessionCategoryOptions.mixWithOthers,
          avAudioSessionMode: AVAudioSessionMode.spokenAudio,
          avAudioSessionRouteSharingPolicy:
              AVAudioSessionRouteSharingPolicy.defaultPolicy,
          avAudioSessionSetActiveOptions:
              AVAudioSessionSetActiveOptions.notifyOthersOnDeactivation,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.speech,
            flags: AndroidAudioFlags.none,
            usage: AndroidAudioUsage.assistant,
          ),
          androidAudioFocusGainType:
              AndroidAudioFocusGainType.gainTransientMayDuck,
          androidWillPauseWhenDucked: true,
        ),
      );

      await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
        IosTextToSpeechAudioCategoryOptions.duckOthers,
        IosTextToSpeechAudioCategoryOptions.mixWithOthers,
      ]);
    } catch (_) {
    } finally {
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    }
  }

  @visibleForTesting
  static String selectTtsLocale({
    required List<Map<Object?, Object?>> voices,
    required bool forceEnglish,
    required String platformLanguageCode,
  }) {
    String selectedLanguage = 'en-US';
    final englishVoice = voices.firstWhere(
      (voice) =>
          (voice['locale']?.toString().toLowerCase().startsWith('en') ??
              false),
      orElse: () => const <Object?, Object?>{},
    );
    if (forceEnglish) {
      final locale = englishVoice['locale']?.toString();
      if (locale != null && locale.isNotEmpty) {
        return locale;
      }
      return selectedLanguage;
    }
    final matchedPlatformVoice = voices.firstWhere(
      (voice) =>
          (voice['locale']?.toString().toLowerCase().startsWith(
                platformLanguageCode,
              ) ??
              false),
      orElse: () => const <Object?, Object?>{},
    );
    final locale =
        matchedPlatformVoice['locale']?.toString() ??
        englishVoice['locale']?.toString();
    if (locale != null && locale.isNotEmpty) {
      selectedLanguage = locale;
    }
    return selectedLanguage;
  }

  static String _normalizeLanguageCode(String locale) {
    if (locale.isEmpty) return 'en';
    final normalized = locale.toLowerCase().replaceAll('_', '-');
    if (normalized.startsWith('pt')) return 'pt';
    return 'en';
  }

  @visibleForTesting
  static String startPromptForLanguage(String languageCode) {
    if (_normalizeLanguageCode(languageCode) == 'pt') {
      return 'Vamos lá!';
    }
    return "Let's go!";
  }

  @visibleForTesting
  static String splitPromptForLanguage(
    String languageCode, {
    required int km,
    required int paceMinutes,
    required int paceSeconds,
    required double avgSpeedKmh,
  }) {
    final lang = _normalizeLanguageCode(languageCode);
    final paceSecondsLabel = paceSeconds.toString().padLeft(2, '0');
    if (lang == 'pt') {
      return 'Quilómetro $km. Ritmo $paceMinutes minutos e $paceSecondsLabel segundos por quilómetro. Velocidade média ${avgSpeedKmh.toStringAsFixed(1)} quilómetros por hora.';
    }
    return 'Kilometer $km. Pace $paceMinutes minutes and $paceSecondsLabel seconds per kilometer. Average speed ${avgSpeedKmh.toStringAsFixed(1)} kilometers per hour.';
  }

  @visibleForTesting
  static String gpsStatusPromptForLanguage(
    String languageCode, {
    required bool isLost,
  }) {
    if (_normalizeLanguageCode(languageCode) == 'pt') {
      return isLost
          ? 'Sinal de GPS perdido temporariamente.'
          : 'Sinal de GPS recuperado.';
    }
    return isLost ? 'GPS signal temporarily lost.' : 'GPS signal recovered.';
  }

  Future<void> setVolume(double volume) async {
    // Update local state first
    _currentVolume = volume.clamp(0.0, 1.0);

    // Persist immediately to handle app restarts
    await _storage.write(key: 'audio_volume', value: _currentVolume.toString());

    // Apply to engine
    try {
      await _tts.setVolume(_currentVolume);
    } catch (e) {
      debugPrint('Error setting volume: $e');
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
    await _storage.write(key: 'audio_enabled', value: enabled.toString());
    await _storage.write(
      key: 'audio_announce_splits',
      value: announceSplits.toString(),
    );
    await _storage.write(
      key: 'audio_announce_start',
      value: announceStart.toString(),
    );
    await _storage.write(key: 'audio_announce_gps', value: announceGps.toString());
    _emitEnabledChanged();
  }

  void toggleEnabled(bool enabled) {
    _isEnabled = enabled;
    unawaited(_storage.write(key: 'audio_enabled', value: enabled.toString()));
    _emitEnabledChanged();
  }

  bool get isEnabled => _isEnabled;
  Stream<bool> get enabledStream => _enabledStreamController.stream;

  void _emitEnabledChanged() {
    if (!_enabledStreamController.isClosed) {
      _enabledStreamController.add(_isEnabled);
    }
  }

  Future<void> speak(String text) async {
    await _ready();
    if (!_isEnabled) return;
    if (text.isNotEmpty) {
      await _tts.speak(text);
    }
  }

  Future<void> stop() async {
    await _tts.stop();
  }

  @visibleForTesting
  static String voiceCoachStatePrompt({required bool enabled}) {
    return enabled ? 'Voice Coach on' : 'Voice Coach off';
  }

  @visibleForTesting
  static bool shouldAnnounceVoiceCoachState({
    required DateTime? lastAnnouncementAt,
    required DateTime now,
    Duration cooldown = _voiceCoachToggleAnnouncementCooldown,
  }) {
    if (lastAnnouncementAt == null) return true;
    return now.difference(lastAnnouncementAt) >= cooldown;
  }

  Future<void> setEnabledWithAnnouncement(bool enabled) async {
    if (_isEnabled == enabled) return;
    final now = DateTime.now();
    final shouldAnnounce = shouldAnnounceVoiceCoachState(
      lastAnnouncementAt: _lastVoiceCoachStateAnnouncementAt,
      now: now,
    );
    if (shouldAnnounce) {
      _lastVoiceCoachStateAnnouncementAt = now;
    }
    if (enabled) {
      _isEnabled = true;
      await _storage.write(key: 'audio_enabled', value: 'true');
      _emitEnabledChanged();
      if (shouldAnnounce) {
        await speak(voiceCoachStatePrompt(enabled: true));
      }
      return;
    }
    if (shouldAnnounce) {
      await speak(voiceCoachStatePrompt(enabled: false));
    }
    _isEnabled = false;
    await _storage.write(key: 'audio_enabled', value: 'false');
    _emitEnabledChanged();
  }

  Future<void> announceCountdown(int seconds) async {
    if (!_isEnabled || !_announceStart) return;
    await speak(seconds.toString());
  }

  Future<void> announceStart() async {
    if (!_isEnabled || !_announceStart) return;
    await speak(startPromptForLanguage(_speechLanguageCode));
  }

  Future<void> announceSplit({
    required int km,
    required double paceSecondsPerKm,
  }) async {
    if (!_isEnabled || !_announceSplits) return;

    final minutes = (paceSecondsPerKm / 60).floor();
    final seconds = (paceSecondsPerKm % 60).round();
    final avgSpeedKmh = 3600 / paceSecondsPerKm;

    final msg = splitPromptForLanguage(
      _speechLanguageCode,
      km: km,
      paceMinutes: minutes,
      paceSeconds: seconds,
      avgSpeedKmh: avgSpeedKmh,
    );
    await speak(msg);
  }

  Future<void> announceGpsStatus({required bool isLost}) async {
    if (!_isEnabled || !_announceGps) return;
    await speak(gpsStatusPromptForLanguage(_speechLanguageCode, isLost: isLost));
  }
}
