import 'package:endurain/l10n/app_localizations.dart';
import 'package:flutter/material.dart';

class TestMaterialApp extends StatelessWidget {
  const TestMaterialApp({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );
  }
}

class TestScaffoldApp extends StatelessWidget {
  const TestScaffoldApp({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TestMaterialApp(child: Scaffold(body: child));
  }
}
