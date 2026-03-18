import 'package:endurain/core/services/audio_feedback_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AudioFeedbackService localized speech templates', () {
    test('voice coach toggle prompts are always English', () {
      expect(
        AudioFeedbackService.voiceCoachStatePrompt(enabled: true),
        'Voice Coach on',
      );
      expect(
        AudioFeedbackService.voiceCoachStatePrompt(enabled: false),
        'Voice Coach off',
      );
    });

    test('voice coach state announcements respect cooldown', () {
      final t0 = DateTime(2026, 1, 1, 12, 0, 0);
      expect(
        AudioFeedbackService.shouldAnnounceVoiceCoachState(
          lastAnnouncementAt: null,
          now: t0,
        ),
        isTrue,
      );
      expect(
        AudioFeedbackService.shouldAnnounceVoiceCoachState(
          lastAnnouncementAt: t0,
          now: t0.add(const Duration(milliseconds: 300)),
        ),
        isFalse,
      );
      expect(
        AudioFeedbackService.shouldAnnounceVoiceCoachState(
          lastAnnouncementAt: t0,
          now: t0.add(const Duration(milliseconds: 500)),
        ),
        isTrue,
      );
    });

    test('selects English locale when English-only mode is enabled', () {
      final locale = AudioFeedbackService.selectTtsLocale(
        voices: const <Map<Object?, Object?>>[
          <Object?, Object?>{'locale': 'de-DE'},
          <Object?, Object?>{'locale': 'en-GB'},
        ],
        forceEnglish: true,
        platformLanguageCode: 'de',
      );
      expect(locale, 'en-GB');
    });

    test('falls back to en-US when English voice is unavailable', () {
      final locale = AudioFeedbackService.selectTtsLocale(
        voices: const <Map<Object?, Object?>>[
          <Object?, Object?>{'locale': 'de-DE'},
          <Object?, Object?>{'locale': 'fr-FR'},
        ],
        forceEnglish: true,
        platformLanguageCode: 'de',
      );
      expect(locale, 'en-US');
    });

    test('uses English start prompt by default', () {
      expect(AudioFeedbackService.startPromptForLanguage('en'), "Let's go!");
      expect(AudioFeedbackService.startPromptForLanguage('de'), "Let's go!");
    });

    test('uses Portuguese start prompt for pt locale', () {
      expect(AudioFeedbackService.startPromptForLanguage('pt'), 'Vamos lá!');
      expect(AudioFeedbackService.startPromptForLanguage('pt-BR'), 'Vamos lá!');
    });

    test('builds English split prompt with pace and average speed', () {
      final msg = AudioFeedbackService.splitPromptForLanguage(
        'en',
        km: 3,
        paceMinutes: 5,
        paceSeconds: 7,
        avgSpeedKmh: 11.34,
      );

      expect(
        msg,
        'Kilometer 3. Pace 5 minutes and 07 seconds per kilometer. Average speed 11.3 kilometers per hour.',
      );
    });

    test('builds Portuguese split prompt with pace and average speed', () {
      final msg = AudioFeedbackService.splitPromptForLanguage(
        'pt',
        km: 2,
        paceMinutes: 4,
        paceSeconds: 59,
        avgSpeedKmh: 12.01,
      );

      expect(
        msg,
        'Quilómetro 2. Ritmo 4 minutos e 59 segundos por quilómetro. Velocidade média 12.0 quilómetros por hora.',
      );
    });

    test('builds English GPS status prompts', () {
      expect(
        AudioFeedbackService.gpsStatusPromptForLanguage('en', isLost: true),
        'GPS signal temporarily lost.',
      );
      expect(
        AudioFeedbackService.gpsStatusPromptForLanguage('en', isLost: false),
        'GPS signal recovered.',
      );
    });

    test('builds Portuguese GPS status prompts', () {
      expect(
        AudioFeedbackService.gpsStatusPromptForLanguage('pt', isLost: true),
        'Sinal de GPS perdido temporariamente.',
      );
      expect(
        AudioFeedbackService.gpsStatusPromptForLanguage('pt-PT', isLost: false),
        'Sinal de GPS recuperado.',
      );
    });
  });
}
