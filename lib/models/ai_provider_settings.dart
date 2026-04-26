enum AiProviderType {
  none,
  openAi,
  siliconFlow,
  openAiCompatible,
}

AiProviderType parseAiProviderType(String? raw) {
  switch (raw) {
    case 'openai':
      return AiProviderType.openAi;
    case 'siliconflow':
      return AiProviderType.siliconFlow;
    case 'openai_compatible':
      return AiProviderType.openAiCompatible;
    default:
      return AiProviderType.none;
  }
}

String aiProviderTypeKey(AiProviderType providerType) {
  switch (providerType) {
    case AiProviderType.none:
      return 'none';
    case AiProviderType.openAi:
      return 'openai';
    case AiProviderType.siliconFlow:
      return 'siliconflow';
    case AiProviderType.openAiCompatible:
      return 'openai_compatible';
  }
}

class AiProviderSettings {
  const AiProviderSettings({
    required this.providerType,
    required this.apiKey,
    required this.baseUrl,
    required this.model,
    required this.enabled,
  });

  static const AiProviderSettings empty = AiProviderSettings(
    providerType: AiProviderType.none,
    apiKey: '',
    baseUrl: '',
    model: '',
    enabled: false,
  );

  final AiProviderType providerType;
  final String apiKey;
  final String baseUrl;
  final String model;
  final bool enabled;

  bool get hasProvider => providerType != AiProviderType.none;

  bool get hasRequiredFields {
    if (!hasProvider) return false;
    if (apiKey.trim().isEmpty || model.trim().isEmpty) return false;
    if ((providerType == AiProviderType.openAiCompatible ||
            providerType == AiProviderType.siliconFlow) &&
        baseUrl.trim().isEmpty) {
      return false;
    }
    return true;
  }

  bool get isReadyForAnalysis => enabled && hasRequiredFields;

  String get resolvedBaseUrl {
    if (providerType == AiProviderType.openAi) {
      return 'https://api.openai.com/v1';
    }
    if (providerType == AiProviderType.siliconFlow && baseUrl.trim().isEmpty) {
      return 'https://api.siliconflow.cn/v1';
    }
    return baseUrl.trim().replaceAll(RegExp(r'\/+$'), '');
  }

  Map<String, dynamic> toJson() {
    return {
      'providerType': aiProviderTypeKey(providerType),
      'apiKey': apiKey,
      'baseUrl': baseUrl,
      'model': model,
      'enabled': enabled,
    };
  }

  factory AiProviderSettings.fromJson(Map<String, dynamic> data) {
    return AiProviderSettings(
      providerType: parseAiProviderType(data['providerType']?.toString()),
      apiKey: (data['apiKey'] ?? '').toString(),
      baseUrl: (data['baseUrl'] ?? '').toString(),
      model: (data['model'] ?? '').toString(),
      enabled: data['enabled'] == true,
    );
  }

  AiProviderSettings copyWith({
    AiProviderType? providerType,
    String? apiKey,
    String? baseUrl,
    String? model,
    bool? enabled,
  }) {
    return AiProviderSettings(
      providerType: providerType ?? this.providerType,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      enabled: enabled ?? this.enabled,
    );
  }
}
