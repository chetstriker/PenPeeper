# AI Integration Feature

## Overview
Added AI Integration section to the Settings screen that allows users to connect to local and cloud-based LLMs.

## Files Created

### 1. `lib/models/llm_provider.dart`
- Enum defining supported LLM providers (Ollama, LM Studio, Claude, ChatGPT, Gemini, Custom)
- Helper methods for display names, API key requirements, and default URLs

### 2. `lib/models/llm_settings.dart`
- Model class for storing LLM configuration
- JSON serialization/deserialization
- Default settings factory

### 3. `lib/services/llm_service.dart`
- Service class handling API communication with all providers
- Test connection method that asks LLM for its name/version
- Model fetching with fallback to hardcoded lists
- Provider-specific API implementations:
  - Ollama: `/api/generate` endpoint
  - LM Studio: OpenAI-compatible `/chat/completions`
  - Claude: Anthropic Messages API
  - ChatGPT: OpenAI Chat Completions API
  - Gemini: Google Generative Language API

## Files Modified

### `lib/screens/settings_screen.dart`
- Added AI Integration section above Debug Logging
- Provider dropdown with all supported LLMs
- Conditional fields based on provider:
  - Base URL (for local LLMs)
  - API Key (for cloud LLMs, obscured)
  - Model selection (dropdown or text field)
- Refresh button to fetch available models
- Test Integration button opens modal dialog
- Settings auto-save to database
- Test dialog shows real-time connection test results

## Features

### Provider Support
- **Ollama**: Local LLM server (default: http://localhost:11434)
- **LM Studio**: Local LLM server (default: http://localhost:1234/v1)
- **Claude**: Anthropic API with API key
- **ChatGPT**: OpenAI API with API key
- **Gemini**: Google API with API key
- **Custom**: Placeholder for future custom implementations

### Model Management
- Automatic model fetching from provider APIs
- Fallback to hardcoded model lists if API fails
- Manual model entry if no models available
- Refresh button to reload model list

### Test Integration
- Modal dialog with test results
- Sends test message: "What is your LLM name and version?"
- Displays response or error in read-only field
- Real-time status updates during connection

## Usage

1. Navigate to Settings screen
2. Scroll to "AI Integration" section
3. Select provider from dropdown
4. Enter required credentials:
   - Base URL for local providers
   - API Key for cloud providers
5. Click "Refresh" to load available models
6. Select or enter model name
7. Click "Test Integration" to verify connection
8. Settings are automatically saved

## API Endpoints Used

### Ollama
- Models: `GET {baseUrl}/api/tags`
- Generate: `POST {baseUrl}/api/generate`

### LM Studio
- Models: `GET {baseUrl}/models`
- Chat: `POST {baseUrl}/chat/completions`

### Claude
- Models: `GET https://api.anthropic.com/v1/models`
- Messages: `POST https://api.anthropic.com/v1/messages`

### ChatGPT
- Models: `GET https://api.openai.com/v1/models`
- Chat: `POST https://api.openai.com/v1/chat/completions`

### Gemini
- Models: `GET https://generativelanguage.googleapis.com/v1beta/models`
- Generate: `POST https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent`

## Storage
Settings are stored in the database using SettingsRepository with key `llm_settings` as JSON.

## Error Handling
- Network errors displayed in test dialog
- Model fetch failures fall back to hardcoded lists
- Invalid API keys show error messages
- Timeout handling (default 30 seconds)

## Future Enhancements
- Custom provider implementation
- Temperature and max tokens configuration
- System prompt customization
- Multiple saved configurations
- Integration with other app features
