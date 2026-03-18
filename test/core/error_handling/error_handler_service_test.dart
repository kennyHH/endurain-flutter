import 'package:endurain/core/error_handling/app_error.dart';
import 'package:endurain/core/error_handling/error_handler_service.dart';
import 'package:endurain/core/error_handling/error_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ErrorHandlerService', () {
    testWidgets('shows ErrorOverlay when showError is called', (tester) async {
      final service = ErrorHandlerService();
      
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  service.showError(
                    context: context,
                    error: NetworkError(message: 'No internet'),
                  );
                },
                child: const Text('Show Error'),
              );
            },
          ),
        ),
      ));

      await tester.tap(find.text('Show Error'));
      await tester.pumpAndSettle();

      expect(find.byType(ErrorOverlay), findsOneWidget);
      expect(find.text('Network Error'), findsOneWidget);
      expect(find.text('No internet'), findsOneWidget);
    });

    testWidgets('calls onRetry when retry button is pressed', (tester) async {
      final service = ErrorHandlerService();
      var retryCalled = false;

      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  service.showError(
                    context: context,
                    error: UploadError(message: 'Upload failed'),
                    onRetry: () => retryCalled = true,
                  );
                },
                child: const Text('Show Error'),
              );
            },
          ),
        ),
      ));

      await tester.tap(find.text('Show Error'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(retryCalled, isTrue);
      expect(find.byType(ErrorOverlay), findsNothing);
    });
  });
}
