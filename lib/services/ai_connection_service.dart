import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/ai_provider_settings.dart';
import 'api_http_client.dart';

class AiConnectionResult {
  const AiConnectionResult({
    required this.success,
    required this.message,
    this.statusCode,
  });

  final bool success;
  final String message;
  final int? statusCode;
}

class AiConnectionService {
  AiConnectionService({
    ApiHttpClient? httpClient,
  }) : _httpClient = httpClient ?? createApiHttpClient();

  final ApiHttpClient _httpClient;
  static const int _maxLogSnippet = 600;

  Future<AiConnectionResult> test(AiProviderSettings settings) async {
    if (!settings.hasRequiredFields) {
      return const AiConnectionResult(
        success: false,
        message: 'Incomplete settings.',
      );
    }

    try {
      debugPrint(
        '[AiConnection] start'
        ' provider=${aiProviderTypeKey(settings.providerType)}'
        ' model=${settings.model.trim()}'
        ' baseUrl=${settings.resolvedBaseUrl}'
        ' apiKey=${_maskSecret(settings.apiKey)}',
      );
      final request = _buildRequest(settings);
      debugPrint('[AiConnection] request url=${request.$1} body=${_logSnippet(request.$2)}');
      final response = await _httpClient.postJson(
        url: Uri.parse(request.$1),
        headers: {
          'Authorization': 'Bearer ${settings.apiKey.trim()}',
          'Content-Type': 'application/json',
        },
        body: request.$2,
      );
      debugPrint(
        '[AiConnection] response'
        ' status=${response.statusCode}'
        ' body=${_logSnippet(response.body)}',
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return AiConnectionResult(
          success: true,
          message: 'OK',
          statusCode: response.statusCode,
        );
      }

      return AiConnectionResult(
        success: false,
        message: _truncate('HTTP ${response.statusCode}: ${response.body}'),
        statusCode: response.statusCode,
      );
    } catch (error) {
      debugPrint('[AiConnection] failed error=$error');
      return AiConnectionResult(
        success: false,
        message: _truncate(error.toString()),
      );
    }
  }

  String _truncate(String raw) {
    final normalized = raw.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 220) return normalized;
    return '${normalized.substring(0, 217)}...';
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

  (String, String) _buildRequest(AiProviderSettings settings) {
    switch (settings.providerType) {
      case AiProviderType.siliconFlow:
        return (
          '${settings.resolvedBaseUrl}/chat/completions',
          json.encode({
            'model': settings.model.trim(),
            'messages': [
              {
                'role': 'user',
                'content': 'Reply with OK only.',
              },
            ],
            'max_tokens': 16,
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
                    'text': 'Reply with OK only.',
                  },
                ],
              },
            ],
            'max_output_tokens': 16,
          }),
        );
      case AiProviderType.none:
        return ('', '{}');
    }
  }
}
