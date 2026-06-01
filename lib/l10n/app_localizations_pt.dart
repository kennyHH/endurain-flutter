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
  String get errorActivityUploadFailed => 'Não foi possível enviar a atividade';

  @override
  String errorActivityUploadFailedWithDetails(String details) {
    return 'Não foi possível enviar a atividade: $details';
  }

  @override
  String get errorActivityUploadNotConfigured =>
      'O envio de atividades ainda não está configurado';

  @override
  String get errorFetchIdentityProvidersFailed =>
      'Não foi possível carregar os provedores de identidade';

  @override
  String errorFetchIdentityProvidersFailedWithDetails(String details) {
    return 'Não foi possível carregar os provedores de identidade: $details';
  }

  @override
  String get errorFetchProvidersFailed =>
      'Não foi possível carregar os provedores de login';

  @override
  String errorFetchProvidersFailedWithDetails(String details) {
    return 'Não foi possível carregar os provedores de login: $details';
  }

  @override
  String get errorFetchServerSettingsFailed =>
      'Não foi possível carregar as definições do servidor';

  @override
  String errorFetchServerSettingsFailedWithDetails(String details) {
    return 'Não foi possível carregar as definições do servidor: $details';
  }

  @override
  String get errorLoginError => 'Não foi possível iniciar sessão';

  @override
  String errorLoginErrorWithDetails(String details) {
    return 'Não foi possível iniciar sessão: $details';
  }

  @override
  String get errorLoginFailed => 'Falha ao iniciar sessão';

  @override
  String errorLoginFailedWithDetails(String details) {
    return 'Falha ao iniciar sessão: $details';
  }

  @override
  String get errorMfaVerificationError =>
      'Não foi possível verificar o código MFA';

  @override
  String errorMfaVerificationErrorWithDetails(String details) {
    return 'Não foi possível verificar o código MFA: $details';
  }

  @override
  String get errorMfaVerificationFailed => 'Falha na verificação MFA';

  @override
  String errorMfaVerificationFailedWithDetails(String details) {
    return 'Falha na verificação MFA: $details';
  }

  @override
  String get errorNoSessionIdReceived =>
      'O servidor não devolveu um ID de sessão';

  @override
  String get errorNotAuthenticated => 'Não tem sessão iniciada';

  @override
  String get errorPkceVerifierMissing =>
      'O verificador de login não foi encontrado';

  @override
  String get errorPkceVerifierMissingRestartLogin =>
      'O verificador de login não foi encontrado. Inicie sessão novamente.';

  @override
  String get errorServerUrlNotConfigured =>
      'O URL do servidor não está configurado';

  @override
  String get errorSessionExpired =>
      'A sua sessão expirou. Inicie sessão novamente.';

  @override
  String get errorSsoTokenExchangeError =>
      'Não foi possível concluir o login SSO';

  @override
  String errorSsoTokenExchangeErrorWithDetails(String details) {
    return 'Não foi possível concluir o login SSO: $details';
  }

  @override
  String get errorTokenExchangeError => 'Não foi possível concluir o login';

  @override
  String errorTokenExchangeErrorWithDetails(String details) {
    return 'Não foi possível concluir o login: $details';
  }

  @override
  String get errorTokenExchangeFailed => 'Falha na troca de token';

  @override
  String errorTokenExchangeFailedWithDetails(String details) {
    return 'Falha na troca de token: $details';
  }

  @override
  String get errorUnexpectedResponseFormat =>
      'O servidor devolveu uma resposta inesperada';

  @override
  String get errorUnsupportedHttpMethod => 'Método HTTP não suportado';

  @override
  String errorUnsupportedHttpMethodWithDetails(String details) {
    return 'Método HTTP não suportado: $details';
  }

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
  String get ssoBrowserLaunchFailed =>
      'Não foi possível abrir o login SSO no navegador do sistema';

  @override
  String get ssoMissingSessionId =>
      'O retorno do SSO não incluiu um ID de sessão';

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
  String get verify => 'Verificar';

  @override
  String get activityDiscard => 'Descartar';

  @override
  String get activityDiscardConfirmMessage =>
      'Isto irá apagar os pontos gravados para esta atividade.';

  @override
  String get activityDiscardConfirmTitle => 'Descartar atividade?';

  @override
  String get activityLocationPermissionDenied =>
      'É necessária permissão de localização para gravar uma atividade.';

  @override
  String get activityLocationPermissionDeniedForever =>
      'A permissão de localização está bloqueada. Abra as definições para permitir o acesso à localização.';

  @override
  String get activityLocationServiceDisabled =>
      'Os serviços de localização estão desativados.';

  @override
  String get activityLocationStreamFailed =>
      'As atualizações de localização pararam inesperadamente.';

  @override
  String get activityOpenSettings => 'Abrir definições';

  @override
  String get activityPause => 'Pausar';

  @override
  String get activityRecordingEmpty => 'Não foram gravados pontos GPS.';

  @override
  String get activityRecordingFailed => 'A gravação falhou.';

  @override
  String get activityResume => 'Retomar';

  @override
  String get activityRetryUpload => 'Tentar envio novamente';

  @override
  String get activityStart => 'Iniciar';

  @override
  String get activityBackgroundTrackingHint =>
      'A gravação continua enquanto a app fica em segundo plano no Android e em computadores.';

  @override
  String get activityBackgroundPermissionHint =>
      'O rastreamento em segundo plano no iPhone e iPad precisa de Localização definida como Sempre. Abra as definições antes de gravar se quiser um registo sem interrupções.';

  @override
  String get activityBackgroundPermissionRequired =>
      'O rastreamento em segundo plano no iPhone e iPad precisa de Localização definida como Sempre.';

  @override
  String get activityTrackingNotificationTitle => 'A gravar atividade';

  @override
  String get activityTrackingNotificationText =>
      'O Endurain está a registar a sua localização para gravar esta atividade.';

  @override
  String get activityStatDistance => 'Distância';

  @override
  String get activityStatDuration => 'Tempo';

  @override
  String get activityStatSpeed => 'Velocidade';

  @override
  String get activityStop => 'Parar';

  @override
  String get activityStopAndSave => 'Parar e guardar';

  @override
  String get activityStopConfirmMessage =>
      'Escolha se pretende guardar esta gravação ou descartá-la.';

  @override
  String get activityStopConfirmTitle => 'Terminar atividade?';

  @override
  String get activityStopping => 'A parar';

  @override
  String get activityTypeHike => 'Caminhada';

  @override
  String get activityTypeLabel => 'Tipo de atividade';

  @override
  String get activityTypeOther => 'Outra';

  @override
  String get activityTypeRide => 'Ciclismo';

  @override
  String get activityTypeRun => 'Corrida';

  @override
  String get activityTypeWalk => 'Passeio';

  @override
  String get activityUploadFailed => 'Falha no envio';

  @override
  String get activityUploadReady => 'Pronto para enviar';

  @override
  String get activityUploaded => 'Enviado';

  @override
  String get activityUploading => 'A enviar';

  @override
  String get mapTab => 'Mapa';

  @override
  String get myLocation => 'A minha localização';

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
  String get notConfigured => 'Não configurado';

  @override
  String get notLoggedIn => 'Sem sessão iniciada';

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
}
