import 'dart:convert';
import 'package:http/http.dart' as http;

/// Represents the result of an LLM request with rich metadata
class LLMResponse {
  final String content;
  final bool success;
  final String? errorMessage;
  final String? errorType;
  final LLMUsageMetrics? usage;
  final Duration? responseTime;
  final int statusCode;
  final String provider;
  
  LLMResponse({
    required this.content,
    required this.success,
    this.errorMessage,
    this.errorType,
    this.usage,
    this.responseTime,
    required this.statusCode,
    required this.provider,
  });
  
  /// User-friendly error message for display
  String get userFriendlyError {
    if (success) return '';
    
    switch (errorType) {
      case LLMErrorType.quotaExceeded:
        return 'API quota exceeded. Please check your $provider subscription or try again later.';
      case LLMErrorType.authenticationError:
        return 'Authentication failed. Please check your API key in settings.';
      case LLMErrorType.timeout:
        return 'Request timed out. Try increasing the timeout in settings or use a faster model.';
      case LLMErrorType.rateLimitExceeded:
        return 'Rate limit exceeded. Please wait a moment and try again.';
      case LLMErrorType.modelNotFound:
        return 'Model not found. Please check the model name in settings.';
      case LLMErrorType.invalidRequest:
        return 'Invalid request. $errorMessage';
      case LLMErrorType.contentTooLarge:
        return 'Request too large. Try reducing the amount of scan data or use a model with larger context.';
      case LLMErrorType.emptyResponse:
        return 'Received empty response from $provider. This may be a temporary issue - try again.';
      case LLMErrorType.networkError:
        return 'Network error. Please check your internet connection.';
      case LLMErrorType.serverError:
        return '$provider server error. Please try again later.';
      case LLMErrorType.truncatedResponse:
        return 'Response was truncated (likely hit token limit). Try reducing max_tokens or input length.';
      case LLMErrorType.connectionRefused:
        return 'Cannot connect to $provider. Check that the service is running and the URL is correct.';
      default:
        return errorMessage ?? 'Unknown error occurred';
    }
  }
  
  bool get isRecoverable {
    return errorType == LLMErrorType.timeout ||
           errorType == LLMErrorType.rateLimitExceeded ||
           errorType == LLMErrorType.networkError ||
           errorType == LLMErrorType.serverError ||
           errorType == LLMErrorType.emptyResponse;
  }
}

/// Token usage metrics for cost tracking and optimization
class LLMUsageMetrics {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  
  LLMUsageMetrics({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });
  
  /// Estimated cost in USD (approximate, provider-dependent)
  double estimateCost(String provider, String model) {
    switch (provider.toLowerCase()) {
      case 'claude':
        if (model.contains('opus')) {
          return (promptTokens * 0.000015) + (completionTokens * 0.000075);
        } else if (model.contains('sonnet')) {
          return (promptTokens * 0.000003) + (completionTokens * 0.000015);
        } else if (model.contains('haiku')) {
          return (promptTokens * 0.00000025) + (completionTokens * 0.00000125);
        }
        break;
      case 'chatgpt':
        if (model.contains('gpt-4')) {
          return (promptTokens * 0.00003) + (completionTokens * 0.00006);
        } else if (model.contains('gpt-3.5')) {
          return (promptTokens * 0.0000005) + (completionTokens * 0.0000015);
        }
        break;
      case 'gemini':
        if (model.contains('pro')) {
          return (promptTokens * 0.00000125) + (completionTokens * 0.00000375);
        }
        break;
      case 'openrouter':
        // OpenRouter varies by model - this is just an estimate
        return (promptTokens * 0.000002) + (completionTokens * 0.000006);
    }
    return 0.0; // Free for local models
  }
  
  @override
  String toString() {
    return 'Prompt: $promptTokens tokens | Completion: $completionTokens tokens | Total: $totalTokens tokens';
  }
}

/// Standard error types across all providers
class LLMErrorType {
  static const String quotaExceeded = 'quota_exceeded';
  static const String authenticationError = 'authentication_error';
  static const String timeout = 'timeout';
  static const String rateLimitExceeded = 'rate_limit_exceeded';
  static const String modelNotFound = 'model_not_found';
  static const String invalidRequest = 'invalid_request';
  static const String contentTooLarge = 'content_too_large';
  static const String emptyResponse = 'empty_response';
  static const String networkError = 'network_error';
  static const String serverError = 'server_error';
  static const String truncatedResponse = 'truncated_response';
  static const String connectionRefused = 'connection_refused';
  static const String unknown = 'unknown';
}

/// Settings for an LLM request
class LLMRequestConfig {
  final String provider;
  final String modelName;
  final String? apiKey;
  final String? baseUrl;
  final double temperature;
  final int maxTokens;
  final int timeoutSeconds;
  final String? systemPrompt;
  
  LLMRequestConfig({
    required this.provider,
    required this.modelName,
    this.apiKey,
    this.baseUrl,
    this.temperature = 0.7,
    this.maxTokens = 1000,
    this.timeoutSeconds = 60,
    this.systemPrompt,
  });
}

/// Unified LLM client that handles all providers
class UnifiedLLMClient {
  
  /// Main entry point for LLM requests
  static Future<LLMResponse> sendRequest({
    required LLMRequestConfig config,
    required String prompt,
    int maxRetries = 3,
    Duration retryDelay = const Duration(seconds: 2),
  }) async {
    final startTime = DateTime.now();
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final response = await _sendRequestOnce(config, prompt);
        
        // Check for recoverable errors
        if (!response.success && response.isRecoverable && attempt < maxRetries) {
          await Future.delayed(retryDelay * attempt); // Exponential backoff
          continue;
        }
        
        // Add response time
        final duration = DateTime.now().difference(startTime);
        return LLMResponse(
          content: response.content,
          success: response.success,
          errorMessage: response.errorMessage,
          errorType: response.errorType,
          usage: response.usage,
          responseTime: duration,
          statusCode: response.statusCode,
          provider: config.provider,
        );
      } catch (e) {
        if (attempt == maxRetries) {
          return LLMResponse(
            content: '',
            success: false,
            errorMessage: e.toString(),
            errorType: LLMErrorType.unknown,
            statusCode: 0,
            provider: config.provider,
            responseTime: DateTime.now().difference(startTime),
          );
        }
        await Future.delayed(retryDelay * attempt);
      }
    }
    
    // Shouldn't reach here, but just in case
    return LLMResponse(
      content: '',
      success: false,
      errorMessage: 'All retry attempts failed',
      errorType: LLMErrorType.unknown,
      statusCode: 0,
      provider: config.provider,
      responseTime: DateTime.now().difference(startTime),
    );
  }
  
  static Future<LLMResponse> _sendRequestOnce(LLMRequestConfig config, String prompt) async {
    switch (config.provider.toLowerCase()) {
      case 'ollama':
        return await _sendOllama(config, prompt);
      case 'lmstudio':
      case 'lm studio':
        return await _sendLMStudio(config, prompt);
      case 'claude':
        return await _sendClaude(config, prompt);
      case 'chatgpt':
      case 'openai':
        return await _sendChatGPT(config, prompt);
      case 'gemini':
        return await _sendGemini(config, prompt);
      case 'openrouter':
        return await _sendOpenRouter(config, prompt);
      default:
        return LLMResponse(
          content: '',
          success: false,
          errorMessage: 'Unsupported provider: ${config.provider}',
          errorType: LLMErrorType.invalidRequest,
          statusCode: 0,
          provider: config.provider,
        );
    }
  }
  
  // ============================================================================
  // Provider-specific implementations
  // ============================================================================
  
  static Future<LLMResponse> _sendOllama(LLMRequestConfig config, String prompt) async {
    try {
      final url = config.baseUrl ?? 'http://localhost:11434';
      
      final requestBody = {
        'model': config.modelName,
        'prompt': prompt,
        'stream': false,
        'options': {
          'temperature': config.temperature,
          'num_predict': config.maxTokens,
        },
      };
      
      // Add system prompt for supported models
      if (config.systemPrompt != null) {
        requestBody['system'] = config.systemPrompt!;
      }
      
      final response = await http.post(
        Uri.parse('$url/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      ).timeout(Duration(seconds: config.timeoutSeconds));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final content = data['response'] as String? ?? '';
        
        if (content.isEmpty) {
          return LLMResponse(
            content: '',
            success: false,
            errorMessage: 'Ollama returned empty response',
            errorType: LLMErrorType.emptyResponse,
            statusCode: 200,
            provider: 'Ollama',
          );
        }
        
        // Ollama provides token counts in some versions
        final promptTokens = data['prompt_eval_count'] as int? ?? _estimateTokenCount(prompt);
        final completionTokens = data['eval_count'] as int? ?? _estimateTokenCount(content);
        
        // Check if response was truncated
        final finishReason = data['done_reason'] as String?;
        if (finishReason == 'length') {
          return LLMResponse(
            content: content,
            success: false,
            errorMessage: 'Response truncated due to token limit',
            errorType: LLMErrorType.truncatedResponse,
            usage: LLMUsageMetrics(
              promptTokens: promptTokens,
              completionTokens: completionTokens,
              totalTokens: promptTokens + completionTokens,
            ),
            statusCode: 200,
            provider: 'Ollama',
          );
        }
        
        return LLMResponse(
          content: content,
          success: true,
          usage: LLMUsageMetrics(
            promptTokens: promptTokens,
            completionTokens: completionTokens,
            totalTokens: promptTokens + completionTokens,
          ),
          statusCode: 200,
          provider: 'Ollama',
        );
      } else if (response.statusCode == 404) {
        return LLMResponse(
          content: '',
          success: false,
          errorMessage: 'Model ${config.modelName} not found. Run: ollama pull ${config.modelName}',
          errorType: LLMErrorType.modelNotFound,
          statusCode: 404,
          provider: 'Ollama',
        );
      } else {
        return _parseErrorResponse('Ollama', response);
      }
    } on http.ClientException catch (e) {
      if (e.message.contains('Connection refused')) {
        return LLMResponse(
          content: '',
          success: false,
          errorMessage: 'Cannot connect to Ollama. Is it running?',
          errorType: LLMErrorType.connectionRefused,
          statusCode: 0,
          provider: 'Ollama',
        );
      }
      return _networkError('Ollama', e.toString());
    } on TimeoutException {
      return _timeoutError('Ollama', config.timeoutSeconds);
    } catch (e) {
      return _unknownError('Ollama', e.toString());
    }
  }
  
  static Future<LLMResponse> _sendLMStudio(LLMRequestConfig config, String prompt) async {
    try {
      final url = config.baseUrl ?? 'http://localhost:1234';
      
      final messages = <Map<String, String>>[];
      if (config.systemPrompt != null) {
        messages.add({'role': 'system', 'content': config.systemPrompt!});
      }
      messages.add({'role': 'user', 'content': prompt});
      
      final response = await http.post(
        Uri.parse('$url/v1/chat/completions'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'model': config.modelName,
          'messages': messages,
          'temperature': config.temperature,
          'max_tokens': config.maxTokens,
        }),
      ).timeout(Duration(seconds: config.timeoutSeconds));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final content = data['choices']?[0]?['message']?['content'] as String? ?? '';
        
        if (content.isEmpty) {
          return LLMResponse(
            content: '',
            success: false,
            errorMessage: 'LM Studio returned empty response',
            errorType: LLMErrorType.emptyResponse,
            statusCode: 200,
            provider: 'LM Studio',
          );
        }
        
        final usage = data['usage'] as Map<String, dynamic>?;
        final finishReason = data['choices']?[0]?['finish_reason'] as String?;
        
        return LLMResponse(
          content: content,
          success: finishReason != 'length',
          errorMessage: finishReason == 'length' ? 'Response truncated' : null,
          errorType: finishReason == 'length' ? LLMErrorType.truncatedResponse : null,
          usage: usage != null
              ? LLMUsageMetrics(
                  promptTokens: usage['prompt_tokens'] ?? 0,
                  completionTokens: usage['completion_tokens'] ?? 0,
                  totalTokens: usage['total_tokens'] ?? 0,
                )
              : null,
          statusCode: 200,
          provider: 'LM Studio',
        );
      } else {
        return _parseErrorResponse('LM Studio', response);
      }
    } on http.ClientException catch (e) {
      if (e.message.contains('Connection refused')) {
        return LLMResponse(
          content: '',
          success: false,
          errorMessage: 'Cannot connect to LM Studio. Is the server running?',
          errorType: LLMErrorType.connectionRefused,
          statusCode: 0,
          provider: 'LM Studio',
        );
      }
      return _networkError('LM Studio', e.toString());
    } on TimeoutException {
      return _timeoutError('LM Studio', config.timeoutSeconds);
    } catch (e) {
      return _unknownError('LM Studio', e.toString());
    }
  }
  
  static Future<LLMResponse> _sendClaude(LLMRequestConfig config, String prompt) async {
    try {
      if (config.apiKey == null || config.apiKey!.isEmpty) {
        return LLMResponse(
          content: '',
          success: false,
          errorMessage: 'Claude API key not configured',
          errorType: LLMErrorType.authenticationError,
          statusCode: 0,
          provider: 'Claude',
        );
      }
      
      final requestBody = {
        'model': config.modelName,
        'max_tokens': config.maxTokens,
        'messages': [
          {'role': 'user', 'content': prompt}
        ],
      };
      
      if (config.systemPrompt != null) {
        requestBody['system'] = config.systemPrompt! as Object;
      }
      
      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': config.apiKey!,
          'anthropic-version': '2023-06-01',
        },
        body: json.encode(requestBody),
      ).timeout(Duration(seconds: config.timeoutSeconds));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final content = data['content'] as List?;
        
        if (content == null || content.isEmpty) {
          return LLMResponse(
            content: '',
            success: false,
            errorMessage: 'Claude returned empty response',
            errorType: LLMErrorType.emptyResponse,
            statusCode: 200,
            provider: 'Claude',
          );
        }
        
        final text = content[0]['text'] as String? ?? '';
        final usage = data['usage'] as Map<String, dynamic>?;
        final stopReason = data['stop_reason'] as String?;
        
        return LLMResponse(
          content: text,
          success: stopReason != 'max_tokens',
          errorMessage: stopReason == 'max_tokens' ? 'Response truncated' : null,
          errorType: stopReason == 'max_tokens' ? LLMErrorType.truncatedResponse : null,
          usage: usage != null
              ? LLMUsageMetrics(
                  promptTokens: usage['input_tokens'] ?? 0,
                  completionTokens: usage['output_tokens'] ?? 0,
                  totalTokens: (usage['input_tokens'] ?? 0) + (usage['output_tokens'] ?? 0),
                )
              : null,
          statusCode: 200,
          provider: 'Claude',
        );
      } else if (response.statusCode == 401) {
        return LLMResponse(
          content: '',
          success: false,
          errorMessage: 'Invalid API key',
          errorType: LLMErrorType.authenticationError,
          statusCode: 401,
          provider: 'Claude',
        );
      } else if (response.statusCode == 429) {
        final data = json.decode(response.body);
        final errorMessage = data['error']?['message'] as String?;
        
        if (errorMessage?.contains('quota') == true) {
          return LLMResponse(
            content: '',
            success: false,
            errorMessage: errorMessage,
            errorType: LLMErrorType.quotaExceeded,
            statusCode: 429,
            provider: 'Claude',
          );
        } else {
          return LLMResponse(
            content: '',
            success: false,
            errorMessage: errorMessage ?? 'Rate limit exceeded',
            errorType: LLMErrorType.rateLimitExceeded,
            statusCode: 429,
            provider: 'Claude',
          );
        }
      } else {
        return _parseErrorResponse('Claude', response);
      }
    } on TimeoutException {
      return _timeoutError('Claude', config.timeoutSeconds);
    } catch (e) {
      return _unknownError('Claude', e.toString());
    }
  }
  
  static Future<LLMResponse> _sendChatGPT(LLMRequestConfig config, String prompt) async {
    try {
      if (config.apiKey == null || config.apiKey!.isEmpty) {
        return LLMResponse(
          content: '',
          success: false,
          errorMessage: 'OpenAI API key not configured',
          errorType: LLMErrorType.authenticationError,
          statusCode: 0,
          provider: 'ChatGPT',
        );
      }
      
      final messages = <Map<String, String>>[];
      if (config.systemPrompt != null) {
        messages.add({'role': 'system', 'content': config.systemPrompt!});
      }
      messages.add({'role': 'user', 'content': prompt});
      
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${config.apiKey}',
        },
        body: json.encode({
          'model': config.modelName,
          'messages': messages,
          'temperature': config.temperature,
          'max_tokens': config.maxTokens,
        }),
      ).timeout(Duration(seconds: config.timeoutSeconds));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final content = data['choices']?[0]?['message']?['content'] as String? ?? '';
        
        if (content.isEmpty) {
          return LLMResponse(
            content: '',
            success: false,
            errorMessage: 'ChatGPT returned empty response',
            errorType: LLMErrorType.emptyResponse,
            statusCode: 200,
            provider: 'ChatGPT',
          );
        }
        
        final usage = data['usage'] as Map<String, dynamic>?;
        final finishReason = data['choices']?[0]?['finish_reason'] as String?;
        
        return LLMResponse(
          content: content,
          success: finishReason != 'length',
          errorMessage: finishReason == 'length' ? 'Response truncated' : null,
          errorType: finishReason == 'length' ? LLMErrorType.truncatedResponse : null,
          usage: usage != null
              ? LLMUsageMetrics(
                  promptTokens: usage['prompt_tokens'] ?? 0,
                  completionTokens: usage['completion_tokens'] ?? 0,
                  totalTokens: usage['total_tokens'] ?? 0,
                )
              : null,
          statusCode: 200,
          provider: 'ChatGPT',
        );
      } else if (response.statusCode == 401) {
        return LLMResponse(
          content: '',
          success: false,
          errorMessage: 'Invalid API key',
          errorType: LLMErrorType.authenticationError,
          statusCode: 401,
          provider: 'ChatGPT',
        );
      } else if (response.statusCode == 429) {
        final data = json.decode(response.body);
        final errorMessage = data['error']?['message'] as String?;
        
        if (errorMessage?.contains('quota') == true || errorMessage?.contains('billing') == true) {
          return LLMResponse(
            content: '',
            success: false,
            errorMessage: errorMessage,
            errorType: LLMErrorType.quotaExceeded,
            statusCode: 429,
            provider: 'ChatGPT',
          );
        } else {
          return LLMResponse(
            content: '',
            success: false,
            errorMessage: errorMessage ?? 'Rate limit exceeded',
            errorType: LLMErrorType.rateLimitExceeded,
            statusCode: 429,
            provider: 'ChatGPT',
          );
        }
      } else if (response.statusCode == 400) {
        final data = json.decode(response.body);
        final errorMessage = data['error']?['message'] as String? ?? 'Bad request';
        
        if (errorMessage.contains('maximum context length')) {
          return LLMResponse(
            content: '',
            success: false,
            errorMessage: errorMessage,
            errorType: LLMErrorType.contentTooLarge,
            statusCode: 400,
            provider: 'ChatGPT',
          );
        } else if (errorMessage.contains('model') && errorMessage.contains('does not exist')) {
          return LLMResponse(
            content: '',
            success: false,
            errorMessage: errorMessage,
            errorType: LLMErrorType.modelNotFound,
            statusCode: 400,
            provider: 'ChatGPT',
          );
        }
        
        return LLMResponse(
          content: '',
          success: false,
          errorMessage: errorMessage,
          errorType: LLMErrorType.invalidRequest,
          statusCode: 400,
          provider: 'ChatGPT',
        );
      } else {
        return _parseErrorResponse('ChatGPT', response);
      }
    } on TimeoutException {
      return _timeoutError('ChatGPT', config.timeoutSeconds);
    } catch (e) {
      return _unknownError('ChatGPT', e.toString());
    }
  }
  
  static Future<LLMResponse> _sendGemini(LLMRequestConfig config, String prompt) async {
    try {
      if (config.apiKey == null || config.apiKey!.isEmpty) {
        return LLMResponse(
          content: '',
          success: false,
          errorMessage: 'Gemini API key not configured',
          errorType: LLMErrorType.authenticationError,
          statusCode: 0,
          provider: 'Gemini',
        );
      }
      
      if (config.modelName.isEmpty) {
        return LLMResponse(
          content: '',
          success: false,
          errorMessage: 'Gemini model name not specified',
          errorType: LLMErrorType.modelNotFound,
          statusCode: 0,
          provider: 'Gemini',
        );
      }
      
      final url = 'https://generativelanguage.googleapis.com/v1beta/models/${config.modelName}:generateContent?key=${config.apiKey}';
      
      final requestBody = {
        'contents': [
          {
            'parts': [
              {'text': prompt}
            ]
          }
        ],
        'generationConfig': {
          'temperature': config.temperature,
          'maxOutputTokens': config.maxTokens,
        },
      };
      
      if (config.systemPrompt != null) {
        requestBody['systemInstruction'] = {
          'parts': [
            {'text': config.systemPrompt!}
          ]
        };
      }
      
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      ).timeout(Duration(seconds: config.timeoutSeconds));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final candidates = data['candidates'] as List?;
        
        if (candidates == null || candidates.isEmpty) {
          return LLMResponse(
            content: '',
            success: false,
            errorMessage: 'Gemini returned no candidates',
            errorType: LLMErrorType.emptyResponse,
            statusCode: 200,
            provider: 'Gemini',
          );
        }
        
        final content = candidates[0]['content'];
        final parts = content['parts'] as List?;
        
        if (parts == null || parts.isEmpty) {
          return LLMResponse(
            content: '',
            success: false,
            errorMessage: 'Gemini returned empty response',
            errorType: LLMErrorType.emptyResponse,
            statusCode: 200,
            provider: 'Gemini',
          );
        }
        
        final text = parts[0]['text'] as String? ?? '';
        final finishReason = candidates[0]['finishReason'] as String?;
        final usage = data['usageMetadata'] as Map<String, dynamic>?;
        
        return LLMResponse(
          content: text,
          success: finishReason != 'MAX_TOKENS',
          errorMessage: finishReason == 'MAX_TOKENS' ? 'Response truncated' : null,
          errorType: finishReason == 'MAX_TOKENS' ? LLMErrorType.truncatedResponse : null,
          usage: usage != null
              ? LLMUsageMetrics(
                  promptTokens: usage['promptTokenCount'] ?? 0,
                  completionTokens: usage['candidatesTokenCount'] ?? 0,
                  totalTokens: usage['totalTokenCount'] ?? 0,
                )
              : null,
          statusCode: 200,
          provider: 'Gemini',
        );
      } else if (response.statusCode == 400) {
        final data = json.decode(response.body);
        final errorMessage = data['error']?['message'] as String? ?? 'Bad request';
        
        if (errorMessage.contains('API key')) {
          return LLMResponse(
            content: '',
            success: false,
            errorMessage: errorMessage,
            errorType: LLMErrorType.authenticationError,
            statusCode: 400,
            provider: 'Gemini',
          );
        } else if (errorMessage.contains('model')) {
          return LLMResponse(
            content: '',
            success: false,
            errorMessage: errorMessage,
            errorType: LLMErrorType.modelNotFound,
            statusCode: 400,
            provider: 'Gemini',
          );
        }
        
        return LLMResponse(
          content: '',
          success: false,
          errorMessage: errorMessage,
          errorType: LLMErrorType.invalidRequest,
          statusCode: 400,
          provider: 'Gemini',
        );
      } else if (response.statusCode == 429) {
        return LLMResponse(
          content: '',
          success: false,
          errorMessage: 'Rate limit or quota exceeded',
          errorType: LLMErrorType.rateLimitExceeded,
          statusCode: 429,
          provider: 'Gemini',
        );
      } else {
        return _parseErrorResponse('Gemini', response);
      }
    } on TimeoutException {
      return _timeoutError('Gemini', config.timeoutSeconds);
    } catch (e) {
      return _unknownError('Gemini', e.toString());
    }
  }
  
  static Future<LLMResponse> _sendOpenRouter(LLMRequestConfig config, String prompt) async {
    try {
      if (config.apiKey == null || config.apiKey!.isEmpty) {
        return LLMResponse(
          content: '',
          success: false,
          errorMessage: 'OpenRouter API key not configured',
          errorType: LLMErrorType.authenticationError,
          statusCode: 0,
          provider: 'OpenRouter',
        );
      }
      
      final messages = <Map<String, String>>[];
      if (config.systemPrompt != null) {
        messages.add({'role': 'system', 'content': config.systemPrompt!});
      }
      messages.add({'role': 'user', 'content': prompt});
      
      final response = await http.post(
        Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${config.apiKey}',
          'HTTP-Referer': 'https://github.com/penpeeper/penpeeper',
          'X-Title': 'PenPeeper Security Scanner',
        },
        body: json.encode({
          'model': config.modelName,
          'messages': messages,
          'temperature': config.temperature,
          'max_tokens': config.maxTokens,
        }),
      ).timeout(Duration(seconds: config.timeoutSeconds));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final choices = data['choices'] as List?;
        
        if (choices == null || choices.isEmpty) {
          return LLMResponse(
            content: '',
            success: false,
            errorMessage: 'OpenRouter returned no choices',
            errorType: LLMErrorType.emptyResponse,
            statusCode: 200,
            provider: 'OpenRouter',
          );
        }
        
        final content = choices[0]['message']?['content'] as String? ?? '';
        
        if (content.trim().isEmpty) {
          return LLMResponse(
            content: '',
            success: false,
            errorMessage: 'OpenRouter returned empty content',
            errorType: LLMErrorType.emptyResponse,
            statusCode: 200,
            provider: 'OpenRouter',
          );
        }
        
        final usage = data['usage'] as Map<String, dynamic>?;
        final finishReason = choices[0]['finish_reason'] as String?;
        
        return LLMResponse(
          content: content,
          success: finishReason != 'length',
          errorMessage: finishReason == 'length' ? 'Response truncated' : null,
          errorType: finishReason == 'length' ? LLMErrorType.truncatedResponse : null,
          usage: usage != null
              ? LLMUsageMetrics(
                  promptTokens: usage['prompt_tokens'] ?? 0,
                  completionTokens: usage['completion_tokens'] ?? 0,
                  totalTokens: usage['total_tokens'] ?? 0,
                )
              : null,
          statusCode: 200,
          provider: 'OpenRouter',
        );
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        return LLMResponse(
          content: '',
          success: false,
          errorMessage: 'Invalid API key',
          errorType: LLMErrorType.authenticationError,
          statusCode: response.statusCode,
          provider: 'OpenRouter',
        );
      } else if (response.statusCode == 429) {
        final data = json.decode(response.body);
        final errorMessage = data['error']?['message'] as String?;
        
        if (errorMessage?.contains('credits') == true || errorMessage?.contains('quota') == true) {
          return LLMResponse(
            content: '',
            success: false,
            errorMessage: errorMessage ?? 'Quota exceeded',
            errorType: LLMErrorType.quotaExceeded,
            statusCode: 429,
            provider: 'OpenRouter',
          );
        } else {
          return LLMResponse(
            content: '',
            success: false,
            errorMessage: errorMessage ?? 'Rate limit exceeded',
            errorType: LLMErrorType.rateLimitExceeded,
            statusCode: 429,
            provider: 'OpenRouter',
          );
        }
      } else if (response.statusCode == 400) {
        final data = json.decode(response.body);
        final errorMessage = data['error']?['message'] as String? ?? 'Bad request';
        
        if (errorMessage.contains('model')) {
          return LLMResponse(
            content: '',
            success: false,
            errorMessage: errorMessage,
            errorType: LLMErrorType.modelNotFound,
            statusCode: 400,
            provider: 'OpenRouter',
          );
        } else if (errorMessage.contains('context_length')) {
          return LLMResponse(
            content: '',
            success: false,
            errorMessage: errorMessage,
            errorType: LLMErrorType.contentTooLarge,
            statusCode: 400,
            provider: 'OpenRouter',
          );
        }
        
        return LLMResponse(
          content: '',
          success: false,
          errorMessage: errorMessage,
          errorType: LLMErrorType.invalidRequest,
          statusCode: 400,
          provider: 'OpenRouter',
        );
      } else {
        return _parseErrorResponse('OpenRouter', response);
      }
    } on TimeoutException {
      return _timeoutError('OpenRouter', config.timeoutSeconds);
    } catch (e) {
      return _unknownError('OpenRouter', e.toString());
    }
  }
  
  // ============================================================================
  // Helper methods
  // ============================================================================
  
  /// Parse generic error responses
  static LLMResponse _parseErrorResponse(String provider, http.Response response) {
    String errorMessage = 'HTTP ${response.statusCode}';
    String errorType = LLMErrorType.serverError;
    
    try {
      final data = json.decode(response.body);
      errorMessage = data['error']?['message'] ?? data['error'] ?? errorMessage;
    } catch (e) {
      errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
    }
    
    if (response.statusCode >= 500) {
      errorType = LLMErrorType.serverError;
    } else if (response.statusCode == 400) {
      errorType = LLMErrorType.invalidRequest;
    }
    
    return LLMResponse(
      content: '',
      success: false,
      errorMessage: errorMessage,
      errorType: errorType,
      statusCode: response.statusCode,
      provider: provider,
    );
  }
  
  static LLMResponse _timeoutError(String provider, int timeoutSeconds) {
    return LLMResponse(
      content: '',
      success: false,
      errorMessage: 'Request timed out after $timeoutSeconds seconds',
      errorType: LLMErrorType.timeout,
      statusCode: 0,
      provider: provider,
    );
  }
  
  static LLMResponse _networkError(String provider, String details) {
    return LLMResponse(
      content: '',
      success: false,
      errorMessage: 'Network error: $details',
      errorType: LLMErrorType.networkError,
      statusCode: 0,
      provider: provider,
    );
  }
  
  static LLMResponse _unknownError(String provider, String details) {
    return LLMResponse(
      content: '',
      success: false,
      errorMessage: 'Unexpected error: $details',
      errorType: LLMErrorType.unknown,
      statusCode: 0,
      provider: provider,
    );
  }
  
  /// Rough token estimation for providers that don't report it
  static int _estimateTokenCount(String text) {
    // Rough approximation: 1 token ≈ 4 characters for English
    return (text.length / 4).ceil();
  }
}

// TimeoutException import
class TimeoutException implements Exception {
  final String? message;
  TimeoutException([this.message]);
  
  @override
  String toString() => message ?? 'TimeoutException';
}
