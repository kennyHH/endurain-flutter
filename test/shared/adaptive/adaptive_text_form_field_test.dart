import 'dart:io';

import 'package:endurain/shared/adaptive/adaptive.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Cupertino field aligns with expanded button width',
    (tester) async {
      await tester.pumpWidget(
        CupertinoApp(
          home: SizedBox(
            width: 390,
            height: 220,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const AdaptiveTextFormField(
                  label: 'Server URL',
                  placeholder: 'https://example.com',
                  prefixIcon: Icon(CupertinoIcons.globe),
                ),
                const SizedBox(height: 24),
                AdaptiveButton(label: 'Next', onPressed: () {}, expand: true),
              ],
            ),
          ),
        ),
      );

      final fieldRect = tester.getRect(find.byType(CupertinoTextFormFieldRow));
      final buttonRect = tester.getRect(find.byType(CupertinoButton));

      expect(fieldRect.left, buttonRect.left);
      expect(fieldRect.right, buttonRect.right);
    },
    skip: !Platform.isMacOS && !Platform.isIOS,
  );
}
