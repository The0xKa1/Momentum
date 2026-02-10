import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/app_strings.dart';
import '../services/rest_sound_settings.dart';
import '../widgets/language_switcher.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              strings.settings,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            _SectionTitle(title: strings.languageSetting),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 320;
                  if (isNarrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.languageSettingLabel,
                          style: const TextStyle(color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: LanguageSwitcher(),
                        ),
                      ],
                    );
                  }
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          strings.languageSettingLabel,
                          style: const TextStyle(color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Flexible(child: LanguageSwitcher()),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            _SectionTitle(title: strings.soundSetting),
            const SizedBox(height: 8),
            const _RestSoundSetting(),
            const SizedBox(height: 20),
            _SectionTitle(title: strings.about),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E1E),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.appTitle,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    strings.splashSubtitle,
                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    strings.aboutStorageHint,
                    style: TextStyle(color: Colors.white.withOpacity(0.6)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
        color: Colors.white.withOpacity(0.5),
      ),
    );
  }
}

class _RestSoundSetting extends StatefulWidget {
  const _RestSoundSetting();

  @override
  State<_RestSoundSetting> createState() => _RestSoundSettingState();
}

class _RestSoundSettingState extends State<_RestSoundSetting> {
  bool _isPicking = false;

  @override
  void initState() {
    super.initState();
    RestSoundController.load();
  }

  String _fileNameFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final idx = normalized.lastIndexOf('/');
    return idx >= 0 ? normalized.substring(idx + 1) : normalized;
  }

  Future<void> _pickSound() async {
    if (_isPicking) return;
    setState(() {
      _isPicking = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
      );
      final path = result?.files.single.path;
      if (path == null || path.isEmpty) {
        return;
      }
      await RestSoundController.setSoundPath(path);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.of(context).invalidSoundFile),
          duration: const Duration(seconds: 1),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPicking = false;
        });
      }
    }
  }

  Future<void> _resetSound() async {
    await RestSoundController.setSoundPath(null);
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ValueListenableBuilder<String?>(
        valueListenable: RestSoundController.restSoundPath,
        builder: (context, path, _) {
          final title = strings.restSoundSetting;
          final detail = (path == null || path.isEmpty)
              ? strings.defaultSound
              : '${strings.soundSelected}: ${_fileNameFromPath(path)}';
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 6),
              Text(
                detail,
                style: TextStyle(color: Colors.white.withOpacity(0.7)),
              ),
              const SizedBox(height: 6),
              Text(
                strings.soundInAppOnly,
                style: TextStyle(color: Colors.white.withOpacity(0.45)),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: _isPicking ? null : _pickSound,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFBB86FC),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      strings.chooseSound,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: _isPicking ? null : _resetSound,
                    child: Text(strings.resetDefault, style: const TextStyle(color: Colors.grey)),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
