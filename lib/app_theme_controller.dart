import 'package:flutter/material.dart';

final ValueNotifier<ThemeMode> appThemeMode = ValueNotifier(ThemeMode.system);

void setAppThemeMode(ThemeMode mode) {
  if (appThemeMode.value == mode) return;
  appThemeMode.value = mode;
}

void toggleAppTheme(Brightness currentBrightness) {
  final nextMode = currentBrightness == Brightness.dark
      ? ThemeMode.light
      : ThemeMode.dark;
  setAppThemeMode(nextMode);
}
