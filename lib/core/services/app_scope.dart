import 'package:flutter/widgets.dart';
import 'package:endurain/core/services/app_services.dart';

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  static AppServices servicesOf(BuildContext context, {bool listen = true}) {
    final scope = listen
        ? context.dependOnInheritedWidgetOfExactType<AppScope>()
        : context.getElementForInheritedWidgetOfExactType<AppScope>()?.widget
              as AppScope?;

    return scope?.services ?? AppServices.instance;
  }

  @override
  bool updateShouldNotify(AppScope oldWidget) {
    return services != oldWidget.services;
  }
}
