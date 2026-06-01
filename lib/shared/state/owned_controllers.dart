import 'package:flutter/widgets.dart';

/// Mixin that removes the repetitive "own-or-injected controller" bookkeeping
/// from [State] classes.
///
/// Screens commonly accept an optional controller for testing and otherwise
/// build one locally. Each screen then has to remember to add a listener,
/// remove that listener in `dispose`, and only dispose the controller when it
/// owns it. Forgetting the ownership check leaks or double-disposes
/// controllers.
///
/// This mixin centralizes that logic. Register controllers in `initState` with
/// [registerController]; the mixin attaches the optional listener and, on
/// dispose, detaches the listener and disposes only the controllers it created.
///
/// Example:
/// ```dart
/// class _MyScreenState extends State<MyScreen> with OwnedControllers {
///   late final MyController _controller;
///
///   @override
///   void initState() {
///     super.initState();
///     _controller = registerController(
///       widget.controller,
///       _createController,
///       onChanged: _handleControllerChanged,
///     );
///   }
/// }
/// ```
mixin OwnedControllers<T extends StatefulWidget> on State<T> {
  final List<_OwnedController> _ownedControllers = <_OwnedController>[];

  /// Returns [injected] when provided, otherwise the result of [create].
  ///
  /// When [onChanged] is given it is registered as a listener and removed
  /// automatically on dispose. The controller is disposed on dispose only when
  /// it was created locally (i.e. [injected] was null).
  C registerController<C extends ChangeNotifier>(
    C? injected,
    C Function() create, {
    VoidCallback? onChanged,
  }) {
    final controller = injected ?? create();
    if (onChanged != null) {
      controller.addListener(onChanged);
    }
    _ownedControllers.add(
      _OwnedController(
        controller: controller,
        owns: injected == null,
        onChanged: onChanged,
      ),
    );
    return controller;
  }

  @override
  void dispose() {
    for (final owned in _ownedControllers) {
      owned.detachAndDispose();
    }
    _ownedControllers.clear();
    super.dispose();
  }
}

class _OwnedController {
  _OwnedController({
    required this.controller,
    required this.owns,
    required this.onChanged,
  });

  final ChangeNotifier controller;
  final bool owns;
  final VoidCallback? onChanged;

  void detachAndDispose() {
    final listener = onChanged;
    if (listener != null) {
      controller.removeListener(listener);
    }
    if (owns) {
      controller.dispose();
    }
  }
}
