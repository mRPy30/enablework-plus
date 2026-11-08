import 'package:flutter/painting.dart';

/// Preserve Android's nonlinear scaling rather than replacing it with a fixed app scale.
class PreferenceTextScaler extends TextScaler {
  const PreferenceTextScaler(this.system, this.multiplier);
  final TextScaler system;
  final double multiplier;
  @override
  double scale(double fontSize) => system.scale(fontSize) * multiplier;
  @override
  double get textScaleFactor => scale(14) / 14;
}
