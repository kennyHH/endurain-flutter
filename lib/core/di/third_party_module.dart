import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:injectable/injectable.dart';

@module
abstract class ThirdPartyModule {
  @singleton
  http.Client get httpClient {
    // Create a custom IOClient with a SecurityContext that allows robust connections
    // This helps with "HandshakeException: Handshake error in client" on some Android devices
    final ioClient = HttpClient()
      ..badCertificateCallback = ((X509Certificate cert, String host, int port) {
        // We can add logic here to allow insecure TLS if user enabled it in settings
        // For now, return false (secure by default) but we use IOClient to have control
        return false;
      });

    // Set connection timeout on the native client
    ioClient.connectionTimeout = const Duration(seconds: 15);

    return IOClient(ioClient);
  }

  @singleton
  Duration get defaultTimeout => const Duration(seconds: 15);

  @Named('phaseADiagnostics')
  @singleton
  bool get phaseADiagnostics => const bool.fromEnvironment(
    'ENDURAIN_PHASE_A_DIAGNOSTICS',
    defaultValue: false,
  );

  @Named('phaseBDistanceConsistency')
  @singleton
  bool get phaseBDistanceConsistency => const bool.fromEnvironment(
    'ENDURAIN_PHASE_B_DISTANCE_CONSISTENCY',
    defaultValue: false,
  );
}
