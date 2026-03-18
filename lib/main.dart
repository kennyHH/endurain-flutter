import 'dart:async';
import 'dart:io';
import 'dart:ui'; // For PlatformDispatcher

import 'package:flutter/material.dart';
import 'package:endurain/app.dart';
import 'package:endurain/core/di/injection.dart';
import 'package:endurain/core/network/endurain_http_overrides.dart';
import 'package:endurain/core/utils/startup_error_policy.dart';

bool _appBootstrapped = false;

void main() {
  runZonedGuarded<Future<void>>(
    () async {
      try {
        WidgetsFlutterBinding.ensureInitialized();

        // Catch Flutter framework errors (rendering, etc.)
        FlutterError.onError = (FlutterErrorDetails details) {
          FlutterError.presentError(details);
          if (shouldShowEmergencyStartupError(
            error: details.exception,
            appBootstrapped: _appBootstrapped,
          )) {
            runEmergencyApp(details.exception, details.stack);
          }
        };

        // Catch async platform errors
        PlatformDispatcher.instance.onError = (error, stack) {
          if (shouldShowEmergencyStartupError(
            error: error,
            appBootstrapped: _appBootstrapped,
          )) {
            runEmergencyApp(error, stack);
          }
          return true;
        };

        await configureDependencies();
        HttpOverrides.global = EndurainHttpOverrides();
        _appBootstrapped = true;
        runApp(const App());
      } catch (error, stack) {
        if (shouldShowEmergencyStartupError(
          error: error,
          appBootstrapped: _appBootstrapped,
        )) {
          runEmergencyApp(error, stack);
        }
      }
    },
    (error, stack) {
      if (shouldShowEmergencyStartupError(
        error: error,
        appBootstrapped: _appBootstrapped,
      )) {
        runEmergencyApp(error, stack);
      }
    },
  );
}

void runEmergencyApp(Object error, StackTrace? stack) {
  // Ensure we don't crash loop if the emergency app fails
  try {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.red.shade900,
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'CRITICAL STARTUP ERROR',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please take a screenshot and send to support.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: Text(
                        error.toString(),
                        style: const TextStyle(
                          color: Colors.yellowAccent,
                          fontFamily: 'monospace',
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Stack Trace:',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        stack.toString(),
                        style: const TextStyle(
                          color: Colors.white70,
                          fontFamily: 'monospace',
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  } catch (e) {
    // Last resort: print to console if even the emergency UI fails
    // (User won't see this without ADB, but good for completeness)
    debugPrint('Failed to render emergency UI: $e');
  }
}
