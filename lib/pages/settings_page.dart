import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/app_background.dart';
import '../services/app_strings.dart';
import '../services/app_theme.dart';
import '../services/rest_sound_settings.dart';
import '../widgets/language_switcher.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final colors = context.appColors;
    final theme = Theme.of(context);
    final Uri projectWebsite = Uri.parse('http://fitflow.the0xka1.cc');
    Future<void> openProjectWebsite() async {
      final ok = await launchUrl(projectWebsite, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(strings.openWebsiteFailed),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    }
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              strings.settings,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            _SectionTitle(title: strings.languageSetting),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colors.surface,
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
                          style: TextStyle(color: theme.colorScheme.onSurface),
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
                          style: TextStyle(color: theme.colorScheme.onSurface),
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
            _SectionTitle(title: strings.appearanceSetting),
            const SizedBox(height: 8),
            const _ThemeSchemeSetting(),
            const SizedBox(height: 12),
            const _BackgroundImageSetting(),
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
                color: colors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    strings.appTitle,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    strings.splashSubtitle,
                    style: TextStyle(color: colors.mutedText),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    strings.aboutStorageHint,
                    style: TextStyle(color: colors.subtleText),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _SectionTitle(title: strings.links),
            const SizedBox(height: 8),
            InkWell(
              onTap: openProjectWebsite,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.public, color: colors.mutedText),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            strings.projectWebsite,
                            style: TextStyle(color: theme.colorScheme.onSurface),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            projectWebsite.toString(),
                            style: TextStyle(color: colors.subtleText, fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      strings.openWebsite,
                      style: TextStyle(color: colors.subtleText, fontSize: 12),
                    ),
                    Icon(Icons.chevron_right, color: colors.subtleText),
                  ],
                ),
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
    final colors = context.appColors;
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
        color: colors.subtleText,
      ),
    );
  }
}

class _ThemeSchemeSetting extends StatelessWidget {
  const _ThemeSchemeSetting();

  String _presetLabel(AppStrings strings, String id) {
    switch (id) {
      case 'ember_core':
        return strings.presetEmberCore;
      case 'glacier_mint':
        return strings.presetGlacierMint;
      case 'volt_lime':
        return strings.presetVoltLime;
      case 'midnight_orchid':
      default:
        return strings.presetMidnightOrchid;
    }
  }

  Future<void> _editColor(
    BuildContext context, {
    required String title,
    required Color initialColor,
    required void Function(Color color) onSave,
  }) async {
    final result = await showDialog<Color>(
      context: context,
      builder: (context) => _ColorEditorDialog(
        title: title,
        initialColor: initialColor,
      ),
    );
    if (result != null) {
      onSave(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final colors = context.appColors;
    final theme = Theme.of(context);
    return ValueListenableBuilder<AppThemeConfig>(
      valueListenable: AppThemeController.theme,
      builder: (context, config, _) {
        Future<void> saveCustom({
          Color? primary,
          Color? background,
          Color? surface,
        }) {
          return AppThemeController.setCustomColors(
            primary: primary ?? config.primary,
            background: background ?? config.background,
            surface: surface ?? config.surface,
          );
        }

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.themeSchemeSetting,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ...AppThemeController.presets.map((preset) {
                    return ChoiceChip(
                      label: Text(_presetLabel(strings, preset.id)),
                      selected: !config.isCustom && config.id == preset.id,
                      selectedColor: preset.primary.withValues(alpha: 0.24),
                      backgroundColor: colors.surfaceElevated,
                      side: BorderSide(color: colors.border),
                      labelStyle: TextStyle(color: theme.colorScheme.onSurface),
                      onSelected: (_) => AppThemeController.setPreset(preset.id),
                    );
                  }),
                  ChoiceChip(
                    label: Text(strings.customThemeScheme),
                    selected: config.isCustom,
                    selectedColor: config.primary.withValues(alpha: 0.24),
                    backgroundColor: colors.surfaceElevated,
                    side: BorderSide(color: colors.border),
                    labelStyle: TextStyle(color: theme.colorScheme.onSurface),
                    onSelected: (_) => AppThemeController.setCustomColors(
                      primary: config.primary,
                      background: config.background,
                      surface: config.surface,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _ThemeColorChip(
                    label: strings.accentColor,
                    color: config.primary,
                    onTap: () => _editColor(
                      context,
                      title: strings.accentColor,
                      initialColor: config.primary,
                      onSave: (value) => saveCustom(primary: value),
                    ),
                  ),
                  _ThemeColorChip(
                    label: strings.backgroundColor,
                    color: config.background,
                    onTap: () => _editColor(
                      context,
                      title: strings.backgroundColor,
                      initialColor: config.background,
                      onSave: (value) => saveCustom(background: value),
                    ),
                  ),
                  _ThemeColorChip(
                    label: strings.surfaceColor,
                    color: config.surface,
                    onTap: () => _editColor(
                      context,
                      title: strings.surfaceColor,
                      initialColor: config.surface,
                      onSave: (value) => saveCustom(surface: value),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ThemeColorChip extends StatelessWidget {
  const _ThemeColorChip({
    required this.label,
    required this.color,
    required this.onTap,
  });

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
              ),
            ),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: theme.colorScheme.onSurface)),
          ],
        ),
      ),
    );
  }
}

class _ColorEditorDialog extends StatefulWidget {
  const _ColorEditorDialog({
    required this.title,
    required this.initialColor,
  });

  final String title;
  final Color initialColor;

  @override
  State<_ColorEditorDialog> createState() => _ColorEditorDialogState();
}

class _ColorEditorDialogState extends State<_ColorEditorDialog> {
  late double _red;
  late double _green;
  late double _blue;

  @override
  void initState() {
    super.initState();
    _red = widget.initialColor.r.toDouble();
    _green = widget.initialColor.g.toDouble();
    _blue = widget.initialColor.b.toDouble();
  }

  Color get _currentColor => Color.fromARGB(
        255,
        _red.round(),
        _green.round(),
        _blue.round(),
      );

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              color: _currentColor,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 12),
          _RgbSlider(
            label: 'R',
            value: _red,
            activeColor: Colors.redAccent,
            onChanged: (value) => setState(() => _red = value),
          ),
          _RgbSlider(
            label: 'G',
            value: _green,
            activeColor: Colors.greenAccent,
            onChanged: (value) => setState(() => _green = value),
          ),
          _RgbSlider(
            label: 'B',
            value: _blue,
            activeColor: Colors.lightBlueAccent,
            onChanged: (value) => setState(() => _blue = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            AppStrings.of(context).cancel,
            style: TextStyle(color: colors.subtleText),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _currentColor),
          style: ElevatedButton.styleFrom(
            backgroundColor: _currentColor,
            foregroundColor: _currentColor.computeLuminance() > 0.45 ? Colors.black : Colors.white,
          ),
          child: Text(
            AppStrings.of(context).saveThemeScheme,
            style: TextStyle(color: theme.colorScheme.onPrimary),
          ),
        ),
      ],
    );
  }
}

class _RgbSlider extends StatelessWidget {
  const _RgbSlider({
    required this.label,
    required this.value,
    required this.activeColor,
    required this.onChanged,
  });

  final String label;
  final double value;
  final Color activeColor;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 24,
          child: Text(label, style: TextStyle(color: theme.colorScheme.onSurface)),
        ),
        Expanded(
          child: Slider(
            min: 0,
            max: 255,
            value: value,
            activeColor: activeColor,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 32,
          child: Text(
            value.round().toString(),
            textAlign: TextAlign.right,
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
        ),
      ],
    );
  }
}

class _BackgroundImageSetting extends StatefulWidget {
  const _BackgroundImageSetting();

  @override
  State<_BackgroundImageSetting> createState() => _BackgroundImageSettingState();
}

class _BackgroundImageSettingState extends State<_BackgroundImageSetting> {
  bool _isPicking = false;

  String _fileNameFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final idx = normalized.lastIndexOf('/');
    return idx >= 0 ? normalized.substring(idx + 1) : normalized;
  }

  Future<void> _pickImage() async {
    if (_isPicking) return;
    setState(() {
      _isPicking = true;
    });
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image);
      final path = result?.files.single.path;
      if (path == null || path.isEmpty) {
        return;
      }
      await AppBackgroundController.setImagePath(path);
    } finally {
      if (!mounted) return;
      setState(() {
        _isPicking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final colors = context.appColors;
    final theme = Theme.of(context);
    return ValueListenableBuilder<AppBackgroundConfig>(
      valueListenable: AppBackgroundController.background,
      builder: (context, config, _) {
        final imageDetail = config.imagePath == null || config.imagePath!.isEmpty
            ? strings.noBackgroundImage
            : '${strings.backgroundImageSelected}: ${_fileNameFromPath(config.imagePath!)}';
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                strings.backgroundImageSetting,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(imageDetail, style: TextStyle(color: colors.mutedText)),
              const SizedBox(height: 6),
              Text(strings.backgroundImageHint, style: TextStyle(color: colors.subtleText)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: _isPicking ? null : _pickImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: colors.accentForeground,
                    ),
                    child: Text(strings.chooseBackgroundImage),
                  ),
                  TextButton(
                    onPressed: _isPicking ? null : () => AppBackgroundController.setImagePath(null),
                    child: Text(strings.clearBackgroundImage, style: TextStyle(color: colors.subtleText)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _BackgroundSlider(
                label: strings.backgroundOverlay,
                value: config.overlayOpacity,
                max: 0.85,
                displayValue: '${(config.overlayOpacity * 100).round()}%',
                onChanged: AppBackgroundController.setOverlayOpacity,
              ),
              const SizedBox(height: 8),
              _BackgroundSlider(
                label: strings.backgroundBlur,
                value: config.blurSigma,
                max: 12,
                displayValue: config.blurSigma.toStringAsFixed(1),
                onChanged: AppBackgroundController.setBlurSigma,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BackgroundSlider extends StatelessWidget {
  const _BackgroundSlider({
    required this.label,
    required this.value,
    required this.max,
    required this.displayValue,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double max;
  final String displayValue;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
        ),
        Expanded(
          child: Slider(
            min: 0,
            max: max,
            value: value.clamp(0.0, max),
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 44,
          child: Text(
            displayValue,
            textAlign: TextAlign.right,
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
        ),
      ],
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
    final colors = context.appColors;
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colors.surface,
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
              Text(title, style: TextStyle(color: theme.colorScheme.onSurface)),
              const SizedBox(height: 6),
              Text(
                detail,
                style: TextStyle(color: colors.mutedText),
              ),
              const SizedBox(height: 6),
              Text(
                strings.soundForForegroundAndBackground,
                style: TextStyle(color: colors.subtleText),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton(
                    onPressed: _isPicking ? null : _pickSound,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: colors.accentForeground,
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
                    child: Text(strings.resetDefault, style: TextStyle(color: colors.subtleText)),
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
