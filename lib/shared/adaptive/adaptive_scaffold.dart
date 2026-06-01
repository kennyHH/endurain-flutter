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
      return CupertinoPageScaffold(
        navigationBar: title == null && leading == null
            ? null
            : CupertinoNavigationBar(
                middle: title == null ? null : Text(title!),
                leading: leading,
              ),
        child: _withFloatingActionButton(content),
      );
    }

    return Scaffold(
      appBar: title == null && leading == null
          ? null
          : AppBar(
              title: title == null ? null : Text(title!),
              leading: leading,
            ),
      body: _withFloatingActionButton(body),
    );
  }

  /// Stacks [floatingActionButton] over [content] at the bottom-right using the
  /// SafeArea inset + [LocationMarkerConstants.buttonOuterPadding] model so the
  /// button lines up identically on every platform. Returns [content] unchanged
  /// when no floating action button is provided.
  Widget _withFloatingActionButton(Widget content) {
    if (floatingActionButton == null) {
      return content;
    }

    return Stack(
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
  }
}
