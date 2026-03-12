import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum WeightUnit { kg, lb }

class WeightUnitController {
  static const String _prefsWeightUnitKey = 'weight_unit';
  static const double _kgToLbFactor = 2.2046226218;

  static final ValueNotifier<WeightUnit> unit =
      ValueNotifier<WeightUnit>(WeightUnit.kg);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsWeightUnitKey);
    unit.value = raw == 'lb' ? WeightUnit.lb : WeightUnit.kg;
  }

  static Future<void> setUnit(WeightUnit value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsWeightUnitKey, value == WeightUnit.lb ? 'lb' : 'kg');
    unit.value = value;
  }

  static String shortLabel(WeightUnit value) {
    return value == WeightUnit.lb ? 'lb' : 'kg';
  }

  static double fromKg(double value, WeightUnit unit) {
    return unit == WeightUnit.lb ? value * _kgToLbFactor : value;
  }

  static double toKg(double value, WeightUnit unit) {
    return unit == WeightUnit.lb ? value / _kgToLbFactor : value;
  }

  static String formatWeight(double kgValue, WeightUnit unit) {
    return '${formatNumber(fromKg(kgValue, unit))} ${shortLabel(unit)}';
  }

  static String formatNumber(double value) {
    final rounded = value.toStringAsFixed(1);
    if (rounded.endsWith('.0')) {
      return rounded.substring(0, rounded.length - 2);
    }
    return rounded;
  }
}
