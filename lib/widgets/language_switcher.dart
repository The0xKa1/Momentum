import 'package:flutter/material.dart';
import '../services/app_locale.dart';
import '../services/app_strings.dart';

class LanguageSwitcher extends StatelessWidget {
  const LanguageSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: AppLocaleController.locale,
      builder: (context, locale, _) {
        final String currentValue = locale == null
            ? 'system'
            : '${locale.languageCode}_${locale.countryCode ?? ''}';
        final strings = AppStrings.of(context);

        return LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 220;
            return SegmentedButton<String>(
              segments: [
                ButtonSegment(
                  value: 'system',
                  label: Text(isCompact ? 'A' : strings.followSystem),
                ),
                ButtonSegment(
                  value: 'zh_CN',
                  label: Text(isCompact ? '中' : strings.chineseSimplified),
                ),
                ButtonSegment(
                  value: 'en_US',
                  label: Text(isCompact ? 'EN' : strings.english),
                ),
              ],
              selected: {currentValue},
              onSelectionChanged: (value) {
                if (value.isEmpty) return;
                final selected = value.first;
                if (selected == 'system') {
                  AppLocaleController.setLocale(null);
                } else if (selected == 'zh_CN') {
                  AppLocaleController.setLocale(const Locale('zh', 'CN'));
                } else if (selected == 'en_US') {
                  AppLocaleController.setLocale(const Locale('en', 'US'));
                }
              },
              showSelectedIcon: false,
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color?>(
                  (states) => states.contains(WidgetState.selected)
                      ? const Color(0xFFBB86FC)
                      : const Color(0xFF2C2C2C),
                ),
                foregroundColor: WidgetStateProperty.resolveWith<Color?>(
                  (states) => states.contains(WidgetState.selected)
                      ? Colors.black
                      : Colors.white,
                ),
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                textStyle: WidgetStateProperty.all(
                  const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                side: WidgetStateProperty.all(
                  BorderSide(color: Colors.white.withOpacity(0.08)),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
