// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get error => 'Erro';

  @override
  String get ok => 'OK';

  @override
  String get cancel => 'Cancelar';

  @override
  String get save => 'Guardar';

  @override
  String get back => 'Voltar';

  @override
  String get requiredField => 'Este campo é obrigatório';

  @override
  String get invalidUrl => 'Por favor, insira um URL válido';

  @override
  String get errorGeneric => 'Algo deu errado. Tente novamente.';

  @override
  String get errorNetwork =>
      'Erro de rede. Verifique sua conexão e tente novamente.';

  @override
  String get errorTls =>
      'Falha na conexão segura (TLS/SSL). Verifique cadeia do certificado, hostname e CA confiável.';

  @override
  String get errorAuthentication =>
      'Falha na autenticação. Verifique suas credenciais.';

  @override
  String get errorServer => 'Erro no servidor. Tente novamente mais tarde.';

  @override
  String get errorConfiguration =>
      'A configuração do servidor é inválida. Verifique as definições.';

  @override
  String get errorSso => 'Falha no login único (SSO). Tente novamente.';

  @override
  String get httpsRequiredUrl => 'Por favor, use um URL HTTPS';

  @override
  String get loginTitle => 'Login';

  @override
  String get login => 'Entrar';

  @override
  String get logout => 'Sair';

  @override
  String get logoutConfirmTitle => 'Sair';

  @override
  String get logoutConfirmMessage => 'Tem certeza que deseja sair?';

  @override
  String get logoutServerFailedWarning =>
      'Não foi possível sair do servidor, mas saiu localmente';

  @override
  String get retry => 'Tentar Novamente';

  @override
  String get ssoWebViewTitle => 'Entrar';

  @override
  String get ssoCancel => 'Cancelar';

  @override
  String get ssoAuthenticationFailed =>
      'A autenticação SSO falhou. Tente novamente.';

  @override
  String get ssoAuthenticationCancelled => 'A autenticação SSO foi cancelada.';

  @override
  String get ssoBlockedNavigation =>
      'A navegação foi bloqueada por motivos de segurança.';

  @override
  String ssoSignInWith(String provider) {
    return 'Entrar com $provider';
  }

  @override
  String get ssoOrDivider => 'OU';

  @override
  String get next => 'Próximo';

  @override
  String get username => 'Nome de utilizador';

  @override
  String get usernameHint => 'Insira o seu nome de utilizador';

  @override
  String get password => 'Palavra-passe';

  @override
  String get passwordHint => 'Insira a sua palavra-passe';

  @override
  String get showPassword => 'Mostrar senha';

  @override
  String get mfaTitle => 'Autenticação de Dois Fatores';

  @override
  String get mfaCode => 'Código MFA';

  @override
  String get mfaCodeHint => 'Insira o código de 6 dígitos';

  @override
  String get mfaCodeRequired => 'Por favor, insira o código MFA';

  @override
  String get helpTitle => 'Informação';

  @override
  String get loginServerUrlHelp =>
      'Insira a URL base exata do seu servidor Endurain, incluindo https:// e com o mesmo hostname do certificado. Exemplo: https://train.example.com';

  @override
  String get loginNextHelp =>
      'Próximo verifica as configurações do servidor e os provedores de login disponíveis. Se este passo falhar com TLS, verifique cadeia completa do certificado, hostname/SAN e confiança no Android.';

  @override
  String get loginTlsToggleHelp =>
      'Modo apenas para teste. Quando ativado, a validação do certificado é ignorada para diagnóstico. Se o login só funcionar neste modo, a cadeia de confiança TLS ou hostname do servidor precisa ser corrigida.';

  @override
  String get verify => 'Verificar';

  @override
  String get mapTab => 'Mapa';

  @override
  String get historyTab => 'Histórico';

  @override
  String get historyTitle => 'Histórico de atividades';

  @override
  String get historyDetailTitle => 'Detalhes da atividade';

  @override
  String get historyEmptyTitle => 'Ainda não há atividades';

  @override
  String get historyEmptyBody =>
      'Inicie e pare uma sessão de tracking para ver suas atividades aqui.';

  @override
  String get historyEmptyCtaStart => 'Iniciar primeira atividade';

  @override
  String get historyLoadError =>
      'Não foi possível carregar as atividades. Tente novamente.';

  @override
  String get historyTrackPoints => 'Pontos de trajeto';

  @override
  String get historyTapMapForOverview =>
      'Toque no mapa para abrir visão completa da rota';

  @override
  String get historyGroupToday => 'Hoje';

  @override
  String get historyGroupYesterday => 'Ontem';

  @override
  String get historyGroupThisWeek => 'Esta semana';

  @override
  String get historyGroupOlder => 'Mais antigas';

  @override
  String get historyFilterAll => 'Todos';

  @override
  String get historyRange7d => '7d';

  @override
  String get historyRange30d => '30d';

  @override
  String get historyRange90d => '90d';

  @override
  String get historyRange1y => '1a';

  @override
  String get historyRangeAllTime => 'Todo período';

  @override
  String get historyFilterSort => 'Filtrar e ordenar';

  @override
  String get historyDateRange => 'Período';

  @override
  String get historySortBy => 'Ordenar por';

  @override
  String get historySortNewest => 'Mais recentes';

  @override
  String get historySortOldest => 'Mais antigas';

  @override
  String get historySortLongest => 'Mais longas';

  @override
  String get historySortShortest => 'Mais curtas';

  @override
  String get historyOnlyUnuploaded => 'Somente atividades não enviadas';

  @override
  String get historyUploadPending => 'Envio pendente';

  @override
  String get historyRenameTitle => 'Nome da atividade';

  @override
  String get historyRenameHint => 'ex.: Pedalada noturna';

  @override
  String get historyDeleteAction => 'Eliminar';

  @override
  String get historyDeleteTitle => 'Eliminar atividade?';

  @override
  String get historyDeleteMessage =>
      'Isto remove a atividade da app e (se já enviada) também do servidor.';

  @override
  String get historyDeletedSuccess => 'Atividade eliminada';

  @override
  String get mapCenterOnLocation => 'Centrar na minha localização';

  @override
  String get activityTypeLabel => 'Tipo de atividade';

  @override
  String get activityTypeRun => 'Corrida';

  @override
  String get activityTypeRide => 'Bicicleta';

  @override
  String get activityTypeWalk => 'Caminhada';

  @override
  String get trackingIdle => 'Parado';

  @override
  String get trackingRecording => 'Gravando';

  @override
  String get trackingPaused => 'Pausado';

  @override
  String get trackingStopped => 'Parado';

  @override
  String get trackingStart => 'Iniciar tracking';

  @override
  String get trackingStop => 'Parar tracking';

  @override
  String get trackingDuration => 'Duração';

  @override
  String get trackingDistance => 'Distância';

  @override
  String get trackingDistanceUnitKm => 'km';

  @override
  String get trackingPace => 'Ritmo';

  @override
  String get trackingPaceUnitMinKm => 'min/km';

  @override
  String get trackingAverageSpeed => 'Velocidade média';

  @override
  String get trackingSpeedUnitKmh => 'km/h';

  @override
  String get trackingElevationGain => 'Ganho de elevação';

  @override
  String get trackingElevationUnitM => 'm';

  @override
  String get historyElevationLoss => 'Perda de elevação';

  @override
  String get historyElevationProfile => 'Perfil de elevação';

  @override
  String get historyNoAltitudeData => 'Sem dados de altitude disponíveis';

  @override
  String get trackingPermissionRequired =>
      'A permissão de localização é necessária para iniciar o tracking.';

  @override
  String get trackingGpsSignalLost =>
      'Sem sinal GPS. A gravação continua e a sincronização retoma automaticamente quando o sinal voltar.';

  @override
  String get trackingGpsReady => 'GPS com fix disponível';

  @override
  String get trackingGpsSearching => 'A procurar fix GPS';

  @override
  String get trackingGpsNeedStableFix =>
      'Aguarde um fix GPS estável (3 fixes bons consecutivos) antes de iniciar.';

  @override
  String trackingGpsPreparingCountdown(int seconds, String status) {
    return 'A iniciar em ${seconds}s - $status';
  }

  @override
  String get trackingRetryInBackground => 'Tentar em segundo plano';

  @override
  String get trackingSuspiciousSaveTitle => 'Guardar esta atividade?';

  @override
  String trackingSuspiciousSaveMessage(String duration, String distance) {
    return 'Esta atividade parece muito curta ou incomum ($duration, $distance). Guardar mesmo assim?';
  }

  @override
  String get trackingDiscardAction => 'Descartar';

  @override
  String get trackingDiscardedActivity => 'Atividade descartada';

  @override
  String trackingRepeatLast(String activity) {
    return 'Repetir última: $activity';
  }

  @override
  String get trackingActivitySavedCelebration => 'Atividade guardada';

  @override
  String get routeStatusMatched => 'Rota: ajustada';

  @override
  String get routeStatusFallback => 'Rota: fallback raw';

  @override
  String get routeStatusRaw => 'Rota: GPS bruto';

  @override
  String get apply => 'Aplicar';

  @override
  String get settingsTab => 'Configurações';

  @override
  String get settingsScreen => 'Configurações';

  @override
  String get serverSettings => 'Servidor';

  @override
  String get serverSettingsTitle => 'Definições do servidor';

  @override
  String get loggedIn => 'Autenticado';

  @override
  String get serverUrl => 'URL do servidor';

  @override
  String get serverUrlHint => 'https://example.com';

  @override
  String get tileServerUrl => 'URL do servidor de mapas';

  @override
  String get tileServerUrlHint => 'https://tile.openstreetmap.org/...';

  @override
  String get savedSuccessfully => 'Definições guardadas com sucesso';

  @override
  String get settingsThemeMode => 'Tema';

  @override
  String get settingsThemeSystem => 'Seguir sistema';

  @override
  String get settingsThemeLight => 'Claro';

  @override
  String get settingsThemeDark => 'Escuro';

  @override
  String get settingsThemePreset => 'Preset de cores';

  @override
  String get settingsThemePresetEndurain => 'Endurain';

  @override
  String get settingsThemePresetOcean => 'Oceano';

  @override
  String get settingsThemePresetForest => 'Floresta';

  @override
  String get settingsHighContrast => 'Alto contraste';

  @override
  String get settingsRouteMatchingTitle => 'Correspondência de rota';

  @override
  String get settingsRouteMatchingToggle =>
      'Ativar correspondência de rota (MVP)';

  @override
  String get settingsRouteMatchingDescription =>
      'Usa correspondência de rota com estradas quando disponível e faz fallback automático para GPS suavizado/bruto quando não for possível.';

  @override
  String get settingsRouteDisplayModeTitle => 'Modo de exibição da rota';

  @override
  String get settingsRouteDisplayModeAuto => 'Automático (recomendado)';

  @override
  String get settingsRouteDisplayModeMatched => 'Preferir rota ajustada';

  @override
  String get settingsRouteDisplayModeRaw => 'GPS bruto';

  @override
  String get settingsGpsFilterModeTitle => 'Modo de filtro GPS';

  @override
  String get settingsGpsFilterModeAuto => 'Automático por atividade';

  @override
  String get settingsGpsFilterModeAutoDescription =>
      'Caminhada/Corrida usam filtro mais rígido; Ciclismo fica equilibrado. Melhor padrão.';

  @override
  String get settingsGpsFilterModeNormal => 'Normal (menos rígido)';

  @override
  String get settingsGpsFilterModeNormalDescription =>
      'Aceita mais pontos GPS em áreas com sinal difícil. Pode incluir mais ruído.';

  @override
  String get settingsGpsFilterModeStrict => 'Rígido (urbano)';

  @override
  String get settingsGpsFilterModeStrictDescription =>
      'Rejeita pontos ruidosos de forma mais agressiva. Útil em áreas urbanas densas.';

  @override
  String get settingsRouteMatchingEnabledLabel =>
      'Pré-visualização ajustada ativa';

  @override
  String get settingsAllowInsecureTls => 'Permitir TLS inseguro (apenas teste)';

  @override
  String get settingsAllowInsecureTlsDescription =>
      'Use apenas para diagnóstico em servidores self-hosted. Desativa verificação de confiança do certificado e não é recomendado para uso normal.';
}
