import 'package:endurain/l10n/app_localizations.dart';

/// Validation utility functions
class Validators {
  /// Validate that a field is not empty
  static String? validateRequired(
    String? value,
    AppLocalizations l10n,
    String fieldName,
  ) {
    if (value == null || value.trim().isEmpty) {
      return l10n.requiredField;
    }
    return null;
  }

  /// Validate that a URL is properly formatted
  static String? validateUrl(String? value, AppLocalizations l10n) {
    if (value == null || value.trim().isEmpty) {
      return l10n.requiredField;
    }
    final uri = Uri.tryParse(value.trim());
    if (uri == null ||
        !uri.hasScheme ||
        (!uri.isScheme('http') && !uri.isScheme('https'))) {
      return l10n.invalidUrl;
    }
    return null;
  }

  /// Validate server URL format and enforce HTTPS for production flows.
  static String? validateServerUrl(String? value, AppLocalizations l10n) {
    final baseValidation = validateUrl(value, l10n);
    if (baseValidation != null) {
      return baseValidation;
    }

    final uri = Uri.parse(value!.trim());
    if (uri.isScheme('http')) {
      if (_isLocalOrPrivateHost(uri.host)) {
        return null;
      }
      return l10n.httpsRequiredUrl;
    }

    return null;
  }

  static bool _isLocalOrPrivateHost(String host) {
    final normalized = host.trim().toLowerCase();
    if (normalized.isEmpty) return false;
    if (normalized == 'localhost' || normalized.endsWith('.local')) {
      return true;
    }
    final parts = normalized.split('.');
    if (parts.length == 4) {
      final octets = parts.map(int.tryParse).toList();
      if (octets.any((part) => part == null || part! < 0 || part > 255)) {
        return false;
      }
      final a = octets[0]!;
      final b = octets[1]!;
      if (a == 10) return true;
      if (a == 127) return true;
      if (a == 192 && b == 168) return true;
      if (a == 172 && b >= 16 && b <= 31) return true;
      if (a == 169 && b == 254) return true;
    }
    return false;
  }
}
