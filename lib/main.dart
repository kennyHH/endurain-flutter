import 'dart:io';

import 'package:flutter/material.dart';
import 'package:endurain/app.dart';
import 'package:endurain/core/network/endurain_http_overrides.dart';

void main() {
  HttpOverrides.global = EndurainHttpOverrides();
  runApp(const App());
}
