import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../models/ai_provider_settings.dart';
import '../models/diet_models.dart';
import '../services/app_data_repository.dart';
import '../services/ai_settings.dart';
import '../services/app_strings.dart';
import '../services/app_theme.dart';
import '../services/diet_analysis_service.dart';
import '../widgets/premium_widgets.dart';

class DietPage extends StatefulWidget {
  const DietPage({super.key});

  @override
  State<DietPage> createState() => DietPageState();
}

class DietPageState extends State<DietPage> with AutomaticKeepAliveClientMixin {
  DietPageState({
    AppDataRepository? repository,
    DietAnalysisService? analysisService,
  })  : _repository = repository ?? AppDataRepository(),
        _analysisService = analysisService ?? ProviderDietAnalysisService();

  @override
  bool get wantKeepAlive => true;

  final AppDataRepository _repository;
  final DietAnalysisService _analysisService;

  DateTime _selectedDay = _normalizeDate(DateTime.now());
  DietDaySummary? _summary;
  bool _isLoading = true;
  bool _isPicking = false;

  void refreshData() {
    _loadData();
  }

  @override
  void initState() {
    super.initState();
    AiSettingsController.load();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    final summary = await _repository.buildDietDaySummary(_selectedDay);

    if (!mounted) return;
    setState(() {
      _summary = summary;
      _isLoading = false;
    });
  }

  Future<void> _changeDay(int offset) async {
    setState(() {
      _selectedDay = _normalizeDate(_selectedDay.add(Duration(days: offset)));
    });
    await _loadData();
  }

  Future<void> _pickMealPhotoAndCreateEntry() async {
    if (_isPicking) return;
    final strings = AppStrings.of(context);
    final aiSettings = await AiSettingsController.getSettings();

    setState(() {
      _isPicking = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: true,
      );
      if (result == null) return;

      final file = result.files.single;
      final path = (file.path == null || file.path!.isEmpty) ? file.name : file.path!;
      if (path.isEmpty) {
        _showMessage(strings.addPhotoFailed);
        return;
      }

      final now = DateTime.now();
      var entry = DietEntry(
        id: 'meal_${now.microsecondsSinceEpoch}',
        date: _selectedDay,
        mealType: MealType.snack,
        photoPath: path,
        title: '',
        note: '',
        analysisStatus: DietAnalysisStatus.pending,
        analysisSummary: '',
        createdAt: now,
        updatedAt: now,
      );

      await _repository.upsertDietEntry(entry);
      entry = await _analyzeEntryIfEnabled(
        entry,
        aiSettings: aiSettings,
        imageBytes: file.bytes,
      );

      await _loadData();
      if (!mounted) return;
      if (!aiSettings.isReadyForAnalysis) {
        _showMessage(strings.aiManualOnlyHint);
      } else if (entry.analysisStatus == DietAnalysisStatus.failed) {
        _showMessage('${strings.analysisFailurePrefix}${_shortError(entry.analysisError)}');
      }
      await _openEditor(entry);
    } finally {
      if (mounted) {
        setState(() {
          _isPicking = false;
        });
      }
    }
  }

  Future<void> _openEditor(DietEntry entry) async {
    final result = await showModalBottomSheet<_DietEditorResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.appColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => _DietEditorSheet(entry: entry),
    );

    if (result == null) return;

    if (result.deleteEntry) {
      await _repository.deleteDietEntry(entry.id);
    } else if (result.entry != null) {
      await _repository.upsertDietEntry(result.entry!);
    }

    await _loadData();
  }

  Future<DietEntry> _analyzeEntryIfEnabled(
    DietEntry entry, {
    required AiProviderSettings aiSettings,
    required Uint8List? imageBytes,
  }) async {
    if (!aiSettings.isReadyForAnalysis || imageBytes == null || imageBytes.isEmpty) {
      return entry;
    }

    final analysis = await _analysisService.analyzeMeal(
      imageBytes: imageBytes,
      mimeType: _mimeTypeFromPath(entry.photoPath),
      mealType: entry.mealType,
      note: entry.note,
    );

    final analyzedEntry = entry.copyWith(
      title: (analysis.title ?? '').trim().isEmpty ? entry.title : analysis.title!.trim(),
      calories: analysis.calories,
      proteinGrams: analysis.proteinGrams,
      carbGrams: analysis.carbGrams,
      fatGrams: analysis.fatGrams,
      analysisStatus: analysis.status,
      analysisSummary: analysis.summary,
      analysisProvider: aiProviderTypeKey(analysis.providerType),
      analysisConfidence: analysis.confidence,
      analysisError: analysis.errorMessage,
      clearAnalysisError: analysis.errorMessage == null,
      analyzedAt: analysis.status == DietAnalysisStatus.ai ? DateTime.now() : null,
      clearAnalyzedAt: analysis.status != DietAnalysisStatus.ai,
      updatedAt: DateTime.now(),
    );

    await _repository.upsertDietEntry(analyzedEntry);
    return analyzedEntry;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final summary = _summary;

    return Scaffold(
      body: SafeArea(
        child: PremiumPageShell(
          padding: EdgeInsets.zero,
          child: _isLoading || summary == null
              ? const Center(child: CircularProgressIndicator())
              : ValueListenableBuilder<AiProviderSettings>(
                  valueListenable: AiSettingsController.settings,
                  builder: (context, aiSettings, _) {
                    final strings = AppStrings.of(context);
                    return RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
                        children: [
                          _DietHero(
                            dateLabel: _formatDate(summary.date),
                            calories: summary.totalCalories,
                            protein: summary.totalProteinGrams,
                            carbs: summary.totalCarbGrams,
                            fat: summary.totalFatGrams,
                            onPreviousDay: () => _changeDay(-1),
                            onNextDay: () => _changeDay(1),
                            onAddMeal: _pickMealPhotoAndCreateEntry,
                            isPicking: _isPicking,
                            aiReady: aiSettings.isReadyForAnalysis,
                          ),
                          const SizedBox(height: 18),
                          Row(
                            children: [
                              Expanded(child: SectionEyebrow(strings.meals)),
                              Text(
                                summary.entries.length.toString(),
                                style: TextStyle(
                                  color: context.appColors.subtleText,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (summary.entries.isEmpty)
                            _DietEmptyState(
                              onAddMeal: _pickMealPhotoAndCreateEntry,
                              aiReady: aiSettings.isReadyForAnalysis,
                            )
                          else
                            ...summary.entries.map(
                              (entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _DietEntryTile(
                                  entry: entry,
                                  onTap: () => _openEditor(entry),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _DietHero extends StatelessWidget {
  const _DietHero({
    required this.dateLabel,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.onPreviousDay,
    required this.onNextDay,
    required this.onAddMeal,
    required this.isPicking,
    required this.aiReady,
  });

  final String dateLabel;
  final int calories;
  final double protein;
  final double carbs;
  final double fat;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;
  final VoidCallback onAddMeal;
  final bool isPicking;
  final bool aiReady;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final colors = context.appColors;
    final theme = Theme.of(context);

    return PremiumSurface(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
      radius: 30,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: SectionEyebrow(strings.diet)),
              PremiumIconButton(
                icon: Icons.chevron_left,
                onPressed: onPreviousDay,
              ),
              const SizedBox(width: 8),
              PremiumIconButton(
                icon: Icons.chevron_right,
                onPressed: onNextDay,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            strings.dietTitle,
            style: TextStyle(
              fontSize: 34,
              height: 0.98,
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            dateLabel,
            style: TextStyle(
              color: colors.subtleText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      calories.toString(),
                      style: TextStyle(
                        fontSize: 46,
                        height: 0.95,
                        fontWeight: FontWeight.w900,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      strings.calories,
                      style: TextStyle(
                        color: colors.subtleText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: isPicking ? null : onAddMeal,
                icon: const Icon(Icons.add_a_photo_outlined),
                label: Text(strings.addMeal),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: colors.accentForeground,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PremiumStatPill(
                label: strings.aiAnalysis,
                value: aiReady ? strings.aiEnabled : strings.manualRecord,
              ),
              PremiumStatPill(label: strings.protein, value: '${_formatNumber(protein)}g'),
              PremiumStatPill(label: strings.carbs, value: '${_formatNumber(carbs)}g'),
              PremiumStatPill(label: strings.fat, value: '${_formatNumber(fat)}g'),
            ],
          ),
        ],
      ),
    );
  }
}

class _DietEmptyState extends StatelessWidget {
  const _DietEmptyState({
    required this.onAddMeal,
    required this.aiReady,
  });

  final VoidCallback onAddMeal;
  final bool aiReady;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final colors = context.appColors;
    return PremiumSurface(
      radius: 26,
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      child: Column(
        children: [
          Icon(
            Icons.photo_outlined,
            size: 38,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.85),
          ),
          const SizedBox(height: 14),
          Text(
            strings.noMealsYet,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            aiReady ? strings.aiReadyHint : strings.aiManualOnlyHint,
            style: TextStyle(color: colors.subtleText),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          ElevatedButton(
            onPressed: onAddMeal,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: colors.accentForeground,
            ),
            child: Text(strings.addMeal),
          ),
        ],
      ),
    );
  }
}

class _DietEntryTile extends StatelessWidget {
  const _DietEntryTile({
    required this.entry,
    required this.onTap,
  });

  final DietEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final colors = context.appColors;
    final title = _displayTitle(entry, strings);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: PremiumSurface(
        radius: 24,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: colors.surfaceElevated,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: colors.border),
              ),
              child: Icon(
                Icons.photo_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mealTypeLabel(strings, entry.mealType),
                    style: TextStyle(
                      color: colors.subtleText,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _nutritionLine(strings, entry),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.mutedText,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _StatusChip(status: entry.analysisStatus),
                const SizedBox(height: 10),
                Text(
                  entry.calories?.toString() ?? '--',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.status,
  });

  final DietAnalysisStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final theme = Theme.of(context);
    final strings = AppStrings.of(context);
    final label = dietStatusLabel(strings, status);
    final highlight = status == DietAnalysisStatus.manual || status == DietAnalysisStatus.ai;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: highlight
            ? theme.colorScheme.primary.withValues(alpha: 0.18)
            : colors.surfaceElevated,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlight ? theme.colorScheme.primary.withValues(alpha: 0.4) : colors.border,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: highlight ? theme.colorScheme.primary : colors.subtleText,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DietEditorSheet extends StatefulWidget {
  const _DietEditorSheet({
    required this.entry,
  });

  final DietEntry entry;

  @override
  State<_DietEditorSheet> createState() => _DietEditorSheetState();
}

class _DietEditorSheetState extends State<_DietEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late final TextEditingController _caloriesController;
  late final TextEditingController _proteinController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatController;
  late MealType _mealType;

  @override
  void initState() {
    super.initState();
    _mealType = widget.entry.mealType;
    _titleController = TextEditingController(text: widget.entry.title);
    _noteController = TextEditingController(text: widget.entry.note);
    _caloriesController = TextEditingController(text: widget.entry.calories?.toString() ?? '');
    _proteinController = TextEditingController(text: _nullableDoubleText(widget.entry.proteinGrams));
    _carbsController = TextEditingController(text: _nullableDoubleText(widget.entry.carbGrams));
    _fatController = TextEditingController(text: _nullableDoubleText(widget.entry.fatGrams));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    super.dispose();
  }

  void _save() {
    final strings = AppStrings.of(context);
    final caloriesText = _caloriesController.text.trim();
    final proteinText = _proteinController.text.trim();
    final carbsText = _carbsController.text.trim();
    final fatText = _fatController.text.trim();

    final calories = caloriesText.isEmpty ? null : int.tryParse(caloriesText);
    final protein = proteinText.isEmpty ? null : double.tryParse(proteinText);
    final carbs = carbsText.isEmpty ? null : double.tryParse(carbsText);
    final fat = fatText.isEmpty ? null : double.tryParse(fatText);

    if ((caloriesText.isNotEmpty && calories == null) ||
        (proteinText.isNotEmpty && protein == null) ||
        (carbsText.isNotEmpty && carbs == null) ||
        (fatText.isNotEmpty && fat == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(strings.pleaseEnterValidNumbers),
          duration: const Duration(seconds: 1),
        ),
      );
      return;
    }

    final hasManualData = calories != null ||
        protein != null ||
        carbs != null ||
        fat != null ||
        _titleController.text.trim().isNotEmpty ||
        _noteController.text.trim().isNotEmpty;
    final status = hasManualData ? DietAnalysisStatus.manual : DietAnalysisStatus.pending;

    Navigator.pop(
      context,
      _DietEditorResult(
        entry: widget.entry.copyWith(
          mealType: _mealType,
          title: _titleController.text.trim(),
          note: _noteController.text.trim(),
          calories: calories,
          proteinGrams: protein,
          carbGrams: carbs,
          fatGrams: fat,
          clearCalories: caloriesText.isEmpty,
          clearProteinGrams: proteinText.isEmpty,
          clearCarbGrams: carbsText.isEmpty,
          clearFatGrams: fatText.isEmpty,
          analysisStatus: status,
          analysisSummary: hasManualData ? strings.manualEntry : '',
          clearAnalysisProvider: hasManualData,
          clearAnalysisConfidence: hasManualData,
          clearAnalysisError: true,
          clearAnalyzedAt: hasManualData,
          updatedAt: DateTime.now(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final colors = context.appColors;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SectionEyebrow(strings.photo),
                        const SizedBox(height: 8),
                        Text(
                          _displayTitle(widget.entry, strings),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _fileNameFromPath(widget.entry.photoPath),
                          style: TextStyle(color: colors.subtleText, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _StatusChip(status: widget.entry.analysisStatus),
                ],
              ),
              const SizedBox(height: 18),
              if (widget.entry.analysisStatus == DietAnalysisStatus.failed) ...[
                PremiumSurface(
                  padding: const EdgeInsets.all(14),
                  radius: 18,
                  color: colors.surfaceElevated,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.analysisErrorTitle,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.entry.analysisError?.trim().isNotEmpty == true
                            ? widget.entry.analysisError!
                            : strings.analysisErrorEmpty,
                        style: TextStyle(
                          color: colors.subtleText,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
              ],
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: MealType.values.map((mealType) {
                  return ChoiceChip(
                    label: Text(mealTypeLabel(strings, mealType)),
                    selected: _mealType == mealType,
                    onSelected: (_) {
                      setState(() {
                        _mealType = mealType;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 18),
              _EditorField(
                controller: _titleController,
                label: strings.mealTitle,
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 12),
              _EditorField(
                controller: _noteController,
                label: strings.notes,
                keyboardType: TextInputType.multiline,
                maxLines: 3,
              ),
              const SizedBox(height: 18),
              SectionEyebrow(strings.nutrition),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _EditorField(
                      controller: _caloriesController,
                      label: strings.calories,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _EditorField(
                      controller: _proteinController,
                      label: '${strings.protein} (g)',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _EditorField(
                      controller: _carbsController,
                      label: '${strings.carbs} (g)',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _EditorField(
                      controller: _fatController,
                      label: '${strings.fat} (g)',
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context, const _DietEditorResult(deleteEntry: true));
                      },
                      child: Text(strings.removeEntry),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _save,
                      child: Text(strings.save),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EditorField extends StatelessWidget {
  const _EditorField({
    required this.controller,
    required this.label,
    required this.keyboardType,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final TextInputType keyboardType;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: colors.subtleText),
        filled: true,
        fillColor: colors.surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: colors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary),
        ),
      ),
    );
  }
}

class _DietEditorResult {
  const _DietEditorResult({
    this.entry,
    this.deleteEntry = false,
  });

  final DietEntry? entry;
  final bool deleteEntry;
}

String mealTypeLabel(AppStrings strings, MealType mealType) {
  switch (mealType) {
    case MealType.breakfast:
      return strings.breakfast;
    case MealType.lunch:
      return strings.lunch;
    case MealType.dinner:
      return strings.dinner;
    case MealType.snack:
      return strings.snack;
  }
}

String dietStatusLabel(AppStrings strings, DietAnalysisStatus status) {
  switch (status) {
    case DietAnalysisStatus.ai:
      return strings.aiAnalyzed;
    case DietAnalysisStatus.manual:
      return strings.manualEntry;
    case DietAnalysisStatus.failed:
      return strings.analysisFailed;
    case DietAnalysisStatus.pending:
      return strings.pendingAnalysis;
  }
}

String _formatDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

DateTime _normalizeDate(DateTime date) {
  return DateTime.utc(date.year, date.month, date.day);
}

String _formatNumber(double value) {
  return value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1);
}

String _nullableDoubleText(double? value) {
  if (value == null) return '';
  return _formatNumber(value);
}

String _fileNameFromPath(String path) {
  if (path.isEmpty) return '';
  final normalized = path.replaceAll('\\', '/');
  final index = normalized.lastIndexOf('/');
  return index >= 0 ? normalized.substring(index + 1) : normalized;
}

String _displayTitle(DietEntry entry, AppStrings strings) {
  if (entry.title.trim().isNotEmpty) return entry.title.trim();
  final fileName = _fileNameFromPath(entry.photoPath);
  if (fileName.isNotEmpty) return fileName;
  return strings.untitledMeal;
}

String _nutritionLine(AppStrings strings, DietEntry entry) {
  final calories = entry.calories?.toString() ?? '--';
  final protein = entry.proteinGrams == null ? '--' : _formatNumber(entry.proteinGrams!);
  final carbs = entry.carbGrams == null ? '--' : _formatNumber(entry.carbGrams!);
  final fat = entry.fatGrams == null ? '--' : _formatNumber(entry.fatGrams!);
  return '$calories kcal  ·  P $protein  ·  C $carbs  ·  F $fat';
}

String _shortError(String? raw) {
  if (raw == null || raw.trim().isEmpty) return 'unknown';
  final normalized = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (normalized.length <= 120) return normalized;
  return '${normalized.substring(0, 117)}...';
}

String _mimeTypeFromPath(String path) {
  final lowerPath = path.toLowerCase();
  if (lowerPath.endsWith('.png')) return 'image/png';
  if (lowerPath.endsWith('.webp')) return 'image/webp';
  if (lowerPath.endsWith('.gif')) return 'image/gif';
  return 'image/jpeg';
}
