import 'dart:io';

/// A user's personal provider connection. Credentials deliberately have no
/// JSON representation and belong only to the current app session.
enum AiProvider {
  openai,
  anthropic,
  gemini,
  deepseek,
  groq,
  openrouter,
  custom,
}

extension AiProviderDetails on AiProvider {
  String get label => switch (this) {
    AiProvider.openai => 'OpenAI',
    AiProvider.anthropic => 'Anthropic',
    AiProvider.gemini => 'Google Gemini',
    AiProvider.deepseek => 'DeepSeek',
    AiProvider.groq => 'Groq',
    AiProvider.openrouter => 'OpenRouter',
    AiProvider.custom => 'Custom OpenAI-compatible',
  };

  Uri? get defaultBaseUrl => switch (this) {
    AiProvider.openai => Uri.parse('https://api.openai.com/v1'),
    AiProvider.anthropic => Uri.parse('https://api.anthropic.com/v1'),
    AiProvider.gemini => Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta',
    ),
    AiProvider.deepseek => Uri.parse('https://api.deepseek.com'),
    AiProvider.groq => Uri.parse('https://api.groq.com/openai/v1'),
    AiProvider.openrouter => Uri.parse('https://openrouter.ai/api/v1'),
    AiProvider.custom => null,
  };
}

class AiProviderException implements Exception {
  const AiProviderException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => message;
}

class AiProviderConfig {
  AiProviderConfig({
    required this.provider,
    required String model,
    required String apiKey,
    Uri? baseUrl,
  }) : model = model.trim(),
       apiKey = apiKey.trim(),
       baseUrl = _baseUrl(provider, baseUrl) {
    if (this.model.isEmpty ||
        this.model == this.apiKey ||
        this.model.length > 100 ||
        this.model.runes.any((v) => v < 33 || v > 126)) {
      throw const AiProviderException(
        'invalid_configuration',
        'Enter a model ID of 1–100 printable characters without spaces.',
      );
    }
    if (this.apiKey.isEmpty ||
        this.apiKey.length > 4096 ||
        apiKey.contains('\r') ||
        apiKey.contains('\n') ||
        this.apiKey.runes.any((v) => v < 33 || v > 126)) {
      throw const AiProviderException(
        'invalid_configuration',
        'Enter a valid API key without spaces or line breaks.',
      );
    }
  }

  final AiProvider provider;
  final String model;
  final String apiKey;
  final Uri baseUrl;
  String get auditModel => '${provider.name}/$model';
  bool get supportsWebSearch => provider == AiProvider.openai;

  static Uri _baseUrl(AiProvider provider, Uri? supplied) {
    final uri = supplied ?? provider.defaultBaseUrl;
    if (uri == null ||
        uri.scheme != 'https' ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.toString().length > 2048 ||
        uri.pathSegments.any((s) => s == '.' || s == '..')) {
      throw const AiProviderException(
        'invalid_configuration',
        'Use an HTTPS API base URL without credentials, query, or fragment.',
      );
    }
    final normalized = uri.replace(
      path: uri.path.replaceFirst(RegExp(r'/+$'), ''),
    );
    if (provider != AiProvider.custom &&
        normalized != provider.defaultBaseUrl) {
      throw const AiProviderException(
        'invalid_configuration',
        'Provider presets use their official API endpoint. Choose Custom for another service.',
      );
    }
    return normalized;
  }

  @override
  String toString() => 'AiProviderConfig(${provider.name}, credentials hidden)';
}

class AiMessage {
  AiMessage(this.role, this.text) {
    if (!['user', 'assistant'].contains(role) || text.isEmpty) {
      throw const AiProviderException(
        'invalid_request',
        'The AI request contains an invalid message.',
      );
    }
  }
  final String role;
  final String text;
}

class AiSource {
  AiSource({required this.url, required this.title}) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        uri.scheme != 'https' ||
        !uri.host.contains('.') ||
        InternetAddress.tryParse(uri.host) != null ||
        [
          'localhost',
          'local',
          'internal',
          'test',
          'invalid',
          'example',
        ].any((s) => uri.host == s || uri.host.endsWith('.$s')) ||
        (uri.hasPort && uri.port != 443) ||
        uri.userInfo.isNotEmpty ||
        uri.hasFragment ||
        url.length > 2048 ||
        title.trim().isEmpty ||
        title.length > 300) {
      throw const AiProviderException(
        'invalid_response',
        'The AI web search returned an invalid source.',
      );
    }
  }
  final String url;
  final String title;
}

class AiJsonResponse {
  AiJsonResponse({
    required Map<String, dynamic> data,
    required this.model,
    List<AiSource> sources = const [],
  }) : data = Map.unmodifiable(data),
       sources = List.unmodifiable(sources);
  final Map<String, dynamic> data;
  final String model;
  final List<AiSource> sources;
}
