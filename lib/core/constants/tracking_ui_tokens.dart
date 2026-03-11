import 'package:flutter/cupertino.dart';

class TrackingSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
}

class TrackingRadius {
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double pill = 999;
}

class TrackingSemanticColors {
  static const Color success = Color(0xFF2E6EA6);
  static const Color warning = Color(0xFFC77C3F);
  static const Color error = Color(0xFFC53030);
  static const Color info = Color(0xFFF59E6A);
}

class TrackingTypography {
  static const TextStyle title = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );
  static const TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.3,
  );
  static const TextStyle meta = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );
}

Color cupertinoStatusColor(TrackingStatusTone tone) {
  switch (tone) {
    case TrackingStatusTone.idle:
      return CupertinoColors.systemBlue;
    case TrackingStatusTone.recording:
      return CupertinoColors.systemRed;
    case TrackingStatusTone.stopped:
      return CupertinoColors.systemGreen;
  }
}

enum TrackingStatusTone { idle, recording, stopped }
