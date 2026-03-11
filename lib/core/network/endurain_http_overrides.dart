import 'dart:io';

class EndurainHttpOverrides extends HttpOverrides {
  static bool allowInsecureTls = false;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
          return allowInsecureTls;
        };
    return client;
  }
}
