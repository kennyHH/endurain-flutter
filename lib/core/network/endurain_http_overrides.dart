import 'dart:io';

/// Allows insecure TLS/SSL connections for self-signed certificates.
/// This should only be used in development or testing environments.
/// In production releases, this should be disabled unless strictly required.
class EndurainHttpOverrides extends HttpOverrides {
  static bool allowInsecureTls = false;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
          // Return true to allow the certificate (insecure)
          // Return false to block it (secure)
          return allowInsecureTls;
        };
    return client;
  }
}
