bool shouldShowEmergencyStartupError({
  required Object error,
  required bool appBootstrapped,
}) {
  return !appBootstrapped;
}
