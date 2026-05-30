import 'dart:io';

import 'package:endurain/shared/adaptive/adaptive.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Cupertino section aligns with form field width',
    (tester) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: SizedBox(
            width: 390,
            height: 320,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: const [
                AdaptiveListSection(
                  header: 'Logged in',
                  children: [AdaptiveListTile(title: 'Server URL')],
                ),
                SizedBox(height: 16),
                AdaptiveTextFormField(
                  label: 'Map tile server URL',
                  placeholder: 'https://example.com',
                ),
              ],
            ),
          ),
        ),
      );

      final sectionTileRect = tester.getRect(find.byType(CupertinoListTile));
      final fieldRect = tester.getRect(find.byType(CupertinoTextFormFieldRow));
      final headerRect = tester.getRect(find.text('Logged in'));

      expect(headerRect.left, fieldRect.left);
      expect(sectionTileRect.left, fieldRect.left);
      expect(sectionTileRect.right, fieldRect.right);
    },
    skip: !Platform.isMacOS && !Platform.isIOS,
  );
}
