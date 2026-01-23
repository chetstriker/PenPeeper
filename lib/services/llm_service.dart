import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:penpeeper/models/llm_provider.dart';
import 'package:penpeeper/models/llm_settings.dart';

class LLMService {
  Future<String> testConnection(LLMSettings settings) async {
    try {
      final response = await _sendMessage(
        settings,
        'What is your LLM name and version? Please respond concisely.',
      );
      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<String> _sendMessage(LLMSettings settings, String message) async {
    final timeout = Duration(seconds: settings.timeoutSeconds);

    switch (settings.provider) {
      case LLMProvider.none:
        throw Exception('No AI provider selected');
      case LLMProvider.ollama:
        return await _sendOllama(settings, message, timeout);
      case LLMProvider.lmStudio:
        return await _sendLMStudio(settings, message, timeout);
      case LLMProvider.claude:
        return await _sendClaude(settings, message, timeout);
      case LLMProvider.chatGPT:
        return await _sendChatGPT(settings, message, timeout);
      case LLMProvider.gemini:
        return await _sendGemini(settings, message, timeout);
      case LLMProvider.openRouter:
        return await _sendOpenRouter(settings, message, timeout);
      case LLMProvider.custom:
        throw Exception('Custom provider not yet implemented');
    }
  }

  Future<String> _sendOllama(
      LLMSettings settings, String message, Duration timeout) async {
    final response = await http
        .post(
          Uri.parse('${settings.baseUrl}/api/generate'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'model': settings.modelName,
            'prompt': message,
            'stream': false,
            'options': {
              'temperature': settings.temperature,
              'num_predict': settings.maxTokens,
            },
          }),
        )
        .timeout(timeout);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['response'] as String? ?? 'No response';
    } else {
      throw Exception('Ollama error: ${response.statusCode} - ${response.body}');
    }
  }

  Future<String> _sendLMStudio(
      LLMSettings settings, String message, Duration timeout) async {
    final response = await http
        .post(
          Uri.parse('${settings.baseUrl}/chat/completions'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'model': settings.modelName,
            'messages': [
              {'role': 'user', 'content': message}
            ],
            'temperature': settings.temperature,
            'max_tokens': settings.maxTokens,
          }),
        )
        .timeout(timeout);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['choices'][0]['message']['content'] as String? ??
          'No response';
    } else {
      throw Exception(
          'LM Studio error: ${response.statusCode} - ${response.body}');
    }
  }

  Future<String> _sendClaude(
      LLMSettings settings, String message, Duration timeout) async {
    final response = await http
        .post(
          Uri.parse('https://api.anthropic.com/v1/messages'),
          headers: {
            'Content-Type': 'application/json',
            'x-api-key': settings.apiKey ?? '',
            'anthropic-version': '2023-06-01',
          },
          body: json.encode({
            'model': settings.modelName,
            'max_tokens': settings.maxTokens,
            'messages': [
              {'role': 'user', 'content': message}
            ],
            'temperature': settings.temperature,
          }),
        )
        .timeout(timeout);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final content = data['content'] as List;
      if (content.isNotEmpty) {
        return content[0]['text'] as String? ?? 'No response';
      }
      return 'No response';
    } else {
      throw Exception('Claude error: ${response.statusCode} - ${response.body}');
    }
  }

  Future<String> _sendChatGPT(
      LLMSettings settings, String message, Duration timeout) async {
    final response = await http
        .post(
          Uri.parse('https://api.openai.com/v1/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${settings.apiKey ?? ''}',
          },
          body: json.encode({
            'model': settings.modelName,
            'messages': [
              {'role': 'user', 'content': message}
            ],
            'temperature': settings.temperature,
            'max_tokens': settings.maxTokens,
          }),
        )
        .timeout(timeout);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['choices'][0]['message']['content'] as String? ??
          'No response';
    } else {
      throw Exception(
          'ChatGPT error: ${response.statusCode} - ${response.body}');
    }
  }

  Future<String> _sendOpenRouter(
      LLMSettings settings, String message, Duration timeout) async {
    final response = await http
        .post(
          Uri.parse('${settings.baseUrl}/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${settings.apiKey ?? ''}',
          },
          body: json.encode({
            'model': settings.modelName,
            'messages': [
              {'role': 'user', 'content': message}
            ],
            'temperature': settings.temperature,
            'max_tokens': settings.maxTokens,
          }),
        )
        .timeout(timeout);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['choices'][0]['message']['content'] as String? ??
          'No response';
    } else {
      throw Exception(
          'OpenRouter error: ${response.statusCode} - ${response.body}');
    }
  }

  Future<String> _sendGemini(
      LLMSettings settings, String message, Duration timeout) async {
    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/${settings.modelName}:generateContent?key=${settings.apiKey}';

    final response = await http
        .post(
          Uri.parse(url),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'contents': [
              {
                'parts': [
                  {'text': message}
                ]
              }
            ],
            'generationConfig': {
              'temperature': settings.temperature,
              'maxOutputTokens': settings.maxTokens,
            },
          }),
        )
        .timeout(timeout);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final candidates = data['candidates'] as List?;
      if (candidates != null && candidates.isNotEmpty) {
        final content = candidates[0]['content'];
        final parts = content['parts'] as List?;
        if (parts != null && parts.isNotEmpty) {
          return parts[0]['text'] as String? ?? 'No response';
        }
      }
      return 'No response';
    } else {
      throw Exception('Gemini error: ${response.statusCode} - ${response.body}');
    }
  }

  Future<List<String>> fetchAvailableModels(LLMSettings settings) async {
    try {
      switch (settings.provider) {
        case LLMProvider.none:
          return [];
        case LLMProvider.ollama:
          return await _fetchOllamaModels(settings);
        case LLMProvider.lmStudio:
          return await _fetchLMStudioModels(settings);
        case LLMProvider.claude:
          return await _fetchClaudeModels(settings);
        case LLMProvider.chatGPT:
          return await _fetchChatGPTModels(settings);
        case LLMProvider.gemini:
          return await _fetchGeminiModels(settings);
        case LLMProvider.openRouter:
          return await _fetchOpenRouterModels(settings);
        case LLMProvider.custom:
          return [];
      }
    } catch (e) {
      return _getFallbackModels(settings.provider);
    }
  }

  Future<List<String>> _fetchOllamaModels(LLMSettings settings) async {
    final response = await http.get(Uri.parse('${settings.baseUrl}/api/tags'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final models = data['models'] as List?;
      return models?.map((m) => m['name'] as String).toList() ?? [];
    }
    return [];
  }

  Future<List<String>> _fetchLMStudioModels(LLMSettings settings) async {
    final response = await http.get(Uri.parse('${settings.baseUrl}/models'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final models = data['data'] as List?;
      return models?.map((m) => m['id'] as String).toList() ?? [];
    }
    return [];
  }

  Future<List<String>> _fetchClaudeModels(LLMSettings settings) async {
    final response = await http.get(
      Uri.parse('https://api.anthropic.com/v1/models'),
      headers: {
        'x-api-key': settings.apiKey ?? '',
        'anthropic-version': '2023-06-01',
      },
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final models = data['data'] as List?;
      return models?.map((m) => m['id'] as String).toList() ?? [];
    }
    return [];
  }

  Future<List<String>> _fetchChatGPTModels(LLMSettings settings) async {
    final response = await http.get(
      Uri.parse('https://api.openai.com/v1/models'),
      headers: {'Authorization': 'Bearer ${settings.apiKey ?? ''}'},
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final models = data['data'] as List?;
      return models
              ?.map((m) => m['id'] as String)
              .where((id) => id.startsWith('gpt'))
              .toList() ??
          [];
    }
    return [];
  }

  Future<List<String>> _fetchOpenRouterModels(LLMSettings settings) async {
    final response = await http.get(
      Uri.parse('https://openrouter.ai/api/v1/models'),
      headers: {'Authorization': 'Bearer ${settings.apiKey ?? ''}'},
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final models = data['data'] as List?;
      return models?.map((m) => m['id'] as String).toList() ?? [];
    }
    return [];
  }

  Future<List<String>> _fetchGeminiModels(LLMSettings settings) async {
    final response = await http.get(
      Uri.parse(
          'https://generativelanguage.googleapis.com/v1beta/models?key=${settings.apiKey}'),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final models = data['models'] as List?;
      return models
              ?.map((m) => (m['name'] as String).replaceFirst('models/', ''))
              .where((name) => name.contains('gemini'))
              .toList() ??
          [];
    }
    return [];
  }

  List<String> _getFallbackModels(LLMProvider provider) {
    switch (provider) {
      case LLMProvider.none:
        return [];
      case LLMProvider.claude:
        return [
          'claude-opus-4-5-20251101',
          'claude-sonnet-4-5-20250929',
          'claude-haiku-4-5-20251001',
        ];
      case LLMProvider.chatGPT:
        return ['gpt-4o', 'gpt-4-turbo', 'gpt-4', 'gpt-3.5-turbo'];
      case LLMProvider.gemini:
        return ['gemini-1.5-pro', 'gemini-1.5-flash', 'gemini-pro'];
      case LLMProvider.ollama:
        return ['llama2', 'mistral', 'codellama'];
      case LLMProvider.lmStudio:
        return [];
      case LLMProvider.openRouter:
        return ['anthropic/claude-3.5-sonnet', 'openai/gpt-4o', 'google/gemini-pro-1.5'];
      case LLMProvider.custom:
        return [];
    }
  }
}
