import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:endurain/core/constants/map_constants.dart';
import 'package:endurain/core/utils/platform_utils.dart';

class AdaptiveScaffold extends StatelessWidget {
  const AdaptiveScaffold({
    super.key,
    this.title,
    required this.body,
    this.leading,
    this.floatingActionButton,
    this.safeArea = true,
  });

  final String? title;
  final Widget body;
  final Widget? leading;
  final Widget? floatingActionButton;
  final bool safeArea;

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isApplePlatform) {
      final content = safeArea ? SafeArea(child: body) : body;
      final stackedContent = floatingActionButton == null
          ? content
          : Stack(
              children: [
                content,
                SafeArea(
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.all(
                        LocationMarkerConstants.buttonOuterPadding,
                      ),
                      child: floatingActionButton,
                    ),
                  ),
                ),
              ],
            );

      return CupertinoPageScaffold(
        navigationBar: title == null && leading == null
            ? null
            : CupertinoNavigationBar(
                middle: title == null ? null : Text(title!),
                leading: leading,
              ),
        child: stackedContent,
      );
    }

    return Scaffold(
      appBar: title == null && leading == null
          ? null
          : AppBar(
              title: title == null ? null : Text(title!),
              leading: leading,
            ),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }
}
