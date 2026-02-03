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

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: currentValue,
              dropdownColor: const Color(0xFF1E1E1E),
              iconEnabledColor: Colors.white70,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              items: [
                DropdownMenuItem(
                  value: 'system',
                  child: Text(
                    strings.followSystem,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                DropdownMenuItem(
                  value: 'zh_CN',
                  child: Text(
                    strings.chineseSimplified,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                DropdownMenuItem(
                  value: 'en_US',
                  child: Text(
                    strings.english,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                if (value == 'system') {
                  AppLocaleController.setLocale(null);
                } else if (value == 'zh_CN') {
                  AppLocaleController.setLocale(const Locale('zh', 'CN'));
                } else if (value == 'en_US') {
                  AppLocaleController.setLocale(const Locale('en', 'US'));
                }
              },
            ),
          ),
        );
      },
    );
  }
}
