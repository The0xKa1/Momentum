import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../models/ai_provider_settings.dart';
import '../models/diet_models.dart';
import 'ai_settings.dart';
import 'api_http_client.dart';

class DietAnalysisResult {
  const DietAnalysisResult({
    required this.status,
    this.summary = '',
    this.calories,
    this.proteinGrams,
    this.carbGrams,
    this.fatGrams,
    this.providerType = AiProviderType.none,
    this.confidence,
    this.errorMessage,
    this.title,
  });

  final DietAnalysisStatus status;
  final String summary;
  final int? calories;
  final double? proteinGrams;
  final double? carbGrams;
  final double? fatGrams;
  final AiProviderType providerType;
  final String? confidence;
  final String? errorMessage;
  final String? title;
}

abstract class DietAnalysisService {
  Future<DietAnalysisResult> analyzeMeal({
    required Uint8List imageBytes,
    required String mimeType,
    required MealType mealType,
    String? note,
  });
}

class ProviderDietAnalysisService implements DietAnalysisService {
  ProviderDietAnalysisService({
    ApiHttpClient? httpClient,
  }) : _httpClient = httpClient ?? createApiHttpClient();

  final ApiHttpClient _httpClient;
  static const int _maxLogSnippet = 600;

  @override
  Future<DietAnalysisResult> analyzeMeal({
    required Uint8List imageBytes,
    required String mimeType,
    required MealType mealType,
    String? note,
  }) async {
    final settings = await AiSettingsController.getSettings();
    if (!settings.isReadyForAnalysis) {
      return const DietAnalysisResult(status: DietAnalysisStatus.pending);
    }

    try {
      debugPrint(
        '[DietAnalysis] start'
        ' provider=${aiProviderTypeKey(settings.providerType)}'
        ' model=${settings.model.trim()}'
        ' baseUrl=${settings.resolvedBaseUrl}'
        ' mealType=${mealTypeKey(mealType)}'
        ' mimeType=$mimeType'
        ' imageBytes=${imageBytes.length}'
        ' apiKey=${_maskSecret(settings.apiKey)}'
        ' note=${_logSnippet(note ?? 'none')}',
      );
      final outputText = await _requestAnalysis(
        settings: settings,
        imageBytes: imageBytes,
        mimeType: mimeType,
        mealType: mealType,
        note: note,
      );
      final payload = _parseJsonPayload(outputText);
      debugPrint('[DietAnalysis] parsed payload=${_logSnippet(json.encode(payload))}');

      return DietAnalysisResult(
        status: DietAnalysisStatus.ai,
        title: _readString(payload, 'title'),
        summary: _readString(payload, 'summary'),
        calories: _readInt(payload, 'calories'),
        proteinGrams: _readDouble(payload, 'proteinGrams'),
        carbGrams: _readDouble(payload, 'carbGrams'),
        fatGrams: _readDouble(payload, 'fatGrams'),
        providerType: settings.providerType,
        confidence: _readString(payload, 'confidence'),
      );
    } catch (error) {
      debugPrint(
        '[DietAnalysis] failed'
        ' provider=${aiProviderTypeKey(settings.providerType)}'
        ' model=${settings.model.trim()}'
        ' baseUrl=${settings.resolvedBaseUrl}'
        ' mealType=${mealTypeKey(mealType)}'
        ' mimeType=$mimeType'
        ' error=$error',
      );
      return DietAnalysisResult(
        status: DietAnalysisStatus.failed,
        providerType: settings.providerType,
        errorMessage: error.toString(),
      );
    }
  }

  Future<String> _requestAnalysis({
    required AiProviderSettings settings,
    required Uint8List imageBytes,
    required String mimeType,
    required MealType mealType,
    String? note,
  }) async {
    final request = _buildAnalysisRequest(
      settings: settings,
      imageBytes: imageBytes,
      mimeType: mimeType,
      mealType: mealType,
      note: note,
    );

    debugPrint(
      '[DietAnalysis] request'
      ' url=${request.$1}'
      ' body=${_logSnippet(request.$2)}',
    );

    final response = await _httpClient.postJson(
      url: Uri.parse(request.$1),
      headers: {
        'Authorization': 'Bearer ${settings.apiKey.trim()}',
        'Content-Type': 'application/json',
      },
      body: request.$2,
    );

    debugPrint(
      '[DietAnalysis] response'
      ' status=${response.statusCode}'
      ' model=${settings.model.trim()}'
      ' provider=${aiProviderTypeKey(settings.providerType)}'
      ' body=${_logSnippet(response.body)}',
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }

    final decoded = json.decode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Unexpected AI response payload.');
    }

    final outputText = _extractOutputText(
      settings.providerType,
      Map<String, dynamic>.from(decoded),
    );
    if (outputText.trim().isEmpty) {
      throw const FormatException('Empty AI response.');
    }
    return outputText;
  }

  (String, String) _buildAnalysisRequest({
    required AiProviderSettings settings,
    required Uint8List imageBytes,
    required String mimeType,
    required MealType mealType,
    String? note,
  }) {
    final imageBase64 = base64Encode(imageBytes);
    final prompt = _buildPrompt(
      mealType: mealType,
      note: note,
    );

    switch (settings.providerType) {
      case AiProviderType.siliconFlow:
        return (
          '${settings.resolvedBaseUrl}/chat/completions',
          json.encode({
            'model': settings.model.trim(),
            'messages': [
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'text',
                    'text': prompt,
                  },
                  {
                    'type': 'image_url',
                    'image_url': {
                      'url': 'data:$mimeType;base64,$imageBase64',
                    },
                  },
                ],
              },
            ],
            'max_tokens': 512,
            'response_format': {
              'type': 'json_object',
            },
          }),
        );
      case AiProviderType.openAi:
      case AiProviderType.openAiCompatible:
        return (
          '${settings.resolvedBaseUrl}/responses',
          json.encode({
            'model': settings.model.trim(),
            'input': [
              {
                'role': 'user',
                'content': [
                  {
                    'type': 'input_text',
                    'text': prompt,
                  },
                  {
                    'type': 'input_image',
                    'image_url': 'data:$mimeType;base64,$imageBase64',
                  },
                ],
              },
            ],
          }),
        );
      case AiProviderType.none:
        return ('', '{}');
    }
  }

  String _buildPrompt({
    required MealType mealType,
    String? note,
  }) {
    final noteText = note == null || note.trim().isEmpty ? 'none' : note.trim();
    return '''
Analyze this meal photo for nutrition logging.
Meal type: ${mealTypeKey(mealType)}.
User note: $noteText.

Estimate the meal title, calories, protein grams, carb grams, and fat grams.
If the image is unclear, still respond with the best estimate and lower confidence.
Return JSON only. No markdown. No explanation.

Required JSON shape:
{
  "title": "string",
  "summary": "short sentence",
  "calories": 0,
  "proteinGrams": 0,
  "carbGrams": 0,
  "fatGrams": 0,
  "confidence": "low|medium|high"
}
''';
  }

  String _extractOutputText(AiProviderType providerType, Map<String, dynamic> payload) {
    if (providerType == AiProviderType.siliconFlow) {
      final choices = payload['choices'];
      if (choices is List && choices.isNotEmpty) {
        final first = choices.first;
        if (first is Map) {
          final message = Map<String, dynamic>.from(first)['message'];
          if (message is Map) {
            final content = Map<String, dynamic>.from(message)['content'];
            if (content is String && content.trim().isNotEmpty) {
              return content;
            }
          }
        }
      }
      return '';
    }

    final topLevelOutput = payload['output_text'];
    if (topLevelOutput is String && topLevelOutput.trim().isNotEmpty) {
      return topLevelOutput;
    }

    final output = payload['output'];
    if (output is! List) return '';

    final parts = <String>[];
    for (final item in output) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final content = map['content'];
      if (content is! List) continue;
      for (final block in content) {
        if (block is! Map) continue;
        final blockMap = Map<String, dynamic>.from(block);
        final text = blockMap['text'];
        if (text is String && text.trim().isNotEmpty) {
          parts.add(text);
        }
      }
    }

    return parts.join('\n').trim();
  }

  Map<String, dynamic> _parseJsonPayload(String raw) {
    final trimmed = raw.trim();
    final fenceMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)\s*```').firstMatch(trimmed);
    final candidate = fenceMatch == null ? trimmed : fenceMatch.group(1)!.trim();
    debugPrint('[DietAnalysis] output_text=${_logSnippet(candidate)}');
    final decoded = json.decode(candidate);
    if (decoded is! Map) {
      throw const FormatException('AI response is not a JSON object.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  String _readString(Map<String, dynamic> payload, String key) {
    return (payload[key] ?? '').toString().trim();
  }

  int? _readInt(Map<String, dynamic> payload, String key) {
    return (payload[key] as num?)?.round();
  }

  double? _readDouble(Map<String, dynamic> payload, String key) {
    return (payload[key] as num?)?.toDouble();
  }

  String _maskSecret(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return '(empty)';
    if (trimmed.length <= 8) return '${trimmed.substring(0, 2)}***';
    return '${trimmed.substring(0, 4)}...${trimmed.substring(trimmed.length - 4)}';
  }

  String _logSnippet(String raw) {
    final normalized = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= _maxLogSnippet) return normalized;
    return '${normalized.substring(0, _maxLogSnippet)}...';
  }
}
