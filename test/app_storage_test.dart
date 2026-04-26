import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fitflow/services/app_storage.dart';
import 'package:fitflow/services/weight_unit_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('exportBackupJson includes persisted application data', () async {
    SharedPreferences.setMockInitialValues({
      'events_data': '{"a":1}',
      'diet_entries': '[{"id":"1"}]',
      'ai_provider_settings': '{"providerType":"openai","apiKey":"sk-test","model":"gpt-4.1-mini","enabled":true}',
      'weight_unit': 'lb',
      'app_background_overlay_opacity': 0.42,
      'app_theme_custom_primary': 123456,
    });

    final raw = await AppStorageController.exportBackupJson();
    final decoded = json.decode(raw) as Map<String, dynamic>;
    final prefs = Map<String, dynamic>.from(decoded['prefs'] as Map);

    expect(decoded['meta'], isA<Map>());
    expect(prefs['events_data'], '{"a":1}');
    expect(prefs['diet_entries'], '[{"id":"1"}]');
    expect(
      prefs['ai_provider_settings'],
      '{"providerType":"openai","apiKey":"sk-test","model":"gpt-4.1-mini","enabled":true}',
    );
    expect(prefs['weight_unit'], 'lb');
    expect(prefs['app_background_overlay_opacity'], 0.42);
    expect(prefs['app_theme_custom_primary'], 123456);
  });

  test('importBackupJson replaces known keys and reloads controllers', () async {
    SharedPreferences.setMockInitialValues({
      'events_data': '{"old":true}',
      'weight_unit': 'lb',
      'app_theme_preset_id': 'custom',
      'app_theme_custom_primary': 99,
    });

    final backup = json.encode({
      'meta': {'app': 'fitflow', 'version': 1},
      'prefs': {
        'diet_entries': '[{"id":"meal"}]',
        'ai_provider_settings': '{"providerType":"openai","apiKey":"sk-next","model":"gpt-4.1-mini","enabled":true}',
        'completed_plans': '{"done":[]}',
        'weight_unit': 'kg',
      },
    });

    await AppStorageController.importBackupJson(backup);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('events_data'), isNull);
    expect(prefs.getString('diet_entries'), '[{"id":"meal"}]');
    expect(
      prefs.getString('ai_provider_settings'),
      '{"providerType":"openai","apiKey":"sk-next","model":"gpt-4.1-mini","enabled":true}',
    );
    expect(prefs.getString('completed_plans'), '{"done":[]}');
    expect(prefs.getString('weight_unit'), 'kg');
    expect(prefs.getString('app_theme_preset_id'), isNull);
    expect(prefs.getInt('app_theme_custom_primary'), isNull);
    expect(WeightUnitController.unit.value, WeightUnit.kg);
  });
}
