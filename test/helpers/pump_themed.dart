import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mislukas/core/theme/app_theme.dart';

/// Monta [child] dentro de una app con el tema de MisLukas.
Future<void> pumpThemed(WidgetTester tester, Widget child) {
  return tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    ),
  );
}
