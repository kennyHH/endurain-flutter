enum RouteDisplayMode { auto, matched, raw }

RouteDisplayMode routeDisplayModeFromStorage(String? raw) {
  switch (raw) {
    case 'matched':
      return RouteDisplayMode.matched;
    case 'raw':
      return RouteDisplayMode.raw;
    case 'auto':
    default:
      return RouteDisplayMode.auto;
  }
}

String routeDisplayModeToStorage(RouteDisplayMode mode) {
  switch (mode) {
    case RouteDisplayMode.auto:
      return 'auto';
    case RouteDisplayMode.matched:
      return 'matched';
    case RouteDisplayMode.raw:
      return 'raw';
  }
}
