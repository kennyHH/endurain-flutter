import 'dart:async';

import 'package:endurain/app.dart';
import 'package:endurain/core/services/app_services.dart';
import 'package:endurain/core/services/diagnostics_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

Future<void> main() async {
  final appRunner = runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      final diagnostics = AppServices.instance.diagnostics;
      await diagnostics.initialize();
      diagnostics.recordBreadcrumbSync(DiagnosticsEvents.appStarted);

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        diagnostics.recordFlutterErrorSync(details);
      };
      PlatformDispatcher.instance.onError = (error, stackTrace) {
        diagnostics.recordErrorSync(
          error,
          stackTrace,
          source: DiagnosticsSources.platformDispatcher,
        );
        return false;
      };

      runApp(const App());
    },
    (error, stackTrace) {
      AppServices.instance.diagnostics.recordErrorSync(
        error,
        stackTrace,
        source: DiagnosticsSources.rootZone,
      );
    },
  );
  await appRunner;
}
