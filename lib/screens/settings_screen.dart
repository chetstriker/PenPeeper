import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:penpeeper/theme_config.dart';
import 'package:penpeeper/theme_loader.dart';
import 'package:penpeeper/repositories/settings_repository.dart';
import 'package:penpeeper/widgets/gradient_button.dart';
import 'package:http/http.dart' as http;
import 'package:penpeeper/utils/error/error_handler.dart';
import 'package:penpeeper/utils/debug_logger.dart';
import 'package:penpeeper/api_database_helper.dart';
import 'package:penpeeper/services/app_paths_service.dart';
import 'package:penpeeper/models/llm_provider.dart';
import 'package:penpeeper/models/llm_settings.dart';
import 'package:penpeeper/services/llm_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settingsRepo = SettingsRepository();
  List<String> availableThemes = [];
  String selectedTheme = 'crimson';
  final _pingAddressController = TextEditingController();
  final _pingResultController = TextEditingController();
  bool _isPinging = false;
  int _concurrentScanCount = 3;
  
  // LLM Integration fields
  LLMProvider _selectedProvider = LLMProvider.none;
  final _baseUrlController = TextEditingController();
  final _apiKeyController = TextEditingController();
  final _modelSearchController = TextEditingController();
  String _selectedModel = '';
  List<String> _availableModels = [];
  bool _isLoadingModels = false;
  final _llmService = LLMService();
  double _temperature = 0.7;
  int _maxTokens = 4000;
  int _timeoutSeconds = 120;

  @override
  void initState() {
    super.initState();
    _loadThemes();
    _loadSavedTheme();
    _loadConcurrentScanCount();
    _loadLLMSettings();
  }

  @override
  void dispose() {
    _pingAddressController.dispose();
    _pingResultController.dispose();
    _baseUrlController.dispose();
    _apiKeyController.dispose();
    _modelSearchController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedTheme() async {
    final savedTheme = await _settingsRepo.getSetting('theme', 'default');
    setState(() {
      selectedTheme = savedTheme;
    });
  }

  Future<void> _loadConcurrentScanCount() async {
    final count = await _settingsRepo.getIntSetting('concurrent_scan_count', 3);
    setState(() {
      _concurrentScanCount = count;
    });
  }

  Future<void> _saveConcurrentScanCount(int value) async {
    await _settingsRepo.setIntSetting('concurrent_scan_count', value);
    setState(() {
      _concurrentScanCount = value;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Concurrent scan count set to $value'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _loadThemes() async {
    final themes = await ThemeLoader.getAvailableThemes();
    setState(() {
      availableThemes = themes;
      if (!themes.contains(selectedTheme) && themes.isNotEmpty) {
        selectedTheme = themes.first;
      }
    });
  }


  Future<void> _runPing() async {
    final address = _pingAddressController.text.trim();
    if (address.isEmpty) {
      setState(() {
        _pingResultController.text = 'Please enter an address to ping';
      });
      return;
    }

    setState(() {
      _isPinging = true;
      _pingResultController.text = 'Pinging $address...';
    });

    try {
      if (kIsWeb) {
        final response = await http.post(
          Uri.parse('${ApiDatabaseHelper.baseUrl}/ping'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'address': address}),
        );
        final result = json.decode(response.body);
        setState(() {
          _pingResultController.text = result['output'] ?? 'No output';
          _isPinging = false;
        });
      } else if (Platform.isWindows) {
        final result = await Process.run('wsl', ['ping', '-c', '4', address]);
        setState(() {
          _pingResultController.text = result.stdout.toString();
          _isPinging = false;
        });
      } else {
        final result = await Process.run('ping', ['-c', '4', address]);
        setState(() {
          _pingResultController.text = result.stdout.toString();
          _isPinging = false;
        });
      }
    } catch (e, stack) {
      ErrorHandler.handle(
        e,
        stackTrace: stack,
        onUserMessage: (msg) => setState(() {
          _pingResultController.text = 'Ping failed: $msg';
          _isPinging = false;
        }),
        context: 'Ping address',
      );
    }
  }

  Future<void> _loadLLMSettings() async {
    final settingsJson = await _settingsRepo.getSetting('llm_settings', '');
    if (settingsJson.isNotEmpty) {
      try {
        final settings = LLMSettings.fromJson(json.decode(settingsJson));
        setState(() {
          _selectedProvider = settings.provider;
          _baseUrlController.text = settings.baseUrl ?? '';
          _apiKeyController.text = settings.apiKey ?? '';
          _selectedModel = settings.modelName;
          _temperature = settings.temperature;
          _maxTokens = settings.maxTokens;
          _timeoutSeconds = settings.timeoutSeconds;
        });
      } catch (e) {
        debugPrint('Error loading LLM settings: $e');
      }
    } else {
      // Set default base URL only if provider is not 'none'
      if (_selectedProvider != LLMProvider.none) {
        _baseUrlController.text = _selectedProvider.defaultBaseUrl;
      }
    }
  }

  Future<void> _saveLLMSettings({double? temperature, int? maxTokens, int? timeoutSeconds}) async {
    final settings = LLMSettings(
      provider: _selectedProvider,
      baseUrl: _baseUrlController.text.trim(),
      apiKey: _apiKeyController.text.trim(),
      modelName: _selectedModel,
      temperature: temperature ?? _temperature,
      maxTokens: maxTokens ?? _maxTokens,
      timeoutSeconds: timeoutSeconds ?? _timeoutSeconds,
    );
    
    if (temperature != null) _temperature = temperature;
    if (maxTokens != null) _maxTokens = maxTokens;
    if (timeoutSeconds != null) _timeoutSeconds = timeoutSeconds;
    
    await _settingsRepo.setSetting('llm_settings', json.encode(settings.toJson()));
  }

  double _getTemperature() {
    return _temperature;
  }

  int _getMaxTokens() {
    return _maxTokens;
  }

  int _getTimeoutSeconds() {
    return _timeoutSeconds;
  }

  Future<void> _loadModels() async {
    setState(() {
      _isLoadingModels = true;
      _availableModels = [];
    });

    try {
      final settings = LLMSettings(
        provider: _selectedProvider,
        baseUrl: _baseUrlController.text.trim(),
        apiKey: _apiKeyController.text.trim(),
        modelName: '',
      );
      final models = await _llmService.fetchAvailableModels(settings);
      models.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      setState(() {
        _availableModels = models;
        _isLoadingModels = false;
        if (models.isNotEmpty && !models.contains(_selectedModel)) {
          _selectedModel = models.first;
        }
      });
    } catch (e) {
      setState(() {
        _isLoadingModels = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load models: $e')),
        );
      }
    }
  }

  void _showTestIntegrationDialog() {
    showDialog(
      context: context,
      builder: (context) => _TestIntegrationDialog(
        settings: LLMSettings(
          provider: _selectedProvider,
          baseUrl: _baseUrlController.text.trim(),
          apiKey: _apiKeyController.text.trim(),
          modelName: _selectedModel,
        ),
        llmService: _llmService,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppTheme.backgroundGradient,
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConcurrentScanSection(),
            const SizedBox(height: 24),
            _buildPingTestSection(),
            const SizedBox(height: 24),
            _buildAIIntegrationSection(),
            const SizedBox(height: 24),
            _buildDebugLoggingSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildConcurrentScanSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: Border.all(color: AppTheme.borderPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.speed,
                color: AppTheme.primaryColor,
                size: AppTheme.iconSizeXLarge,
              ),
              const SizedBox(width: 12),
              Text(
                'Scan Performance',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeLargeTitle,
                  fontWeight: AppTheme.fontWeightSemiBold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Concurrent Scans',
            style: TextStyle(
              fontSize: AppTheme.fontSizeBodyLarge,
              fontWeight: AppTheme.fontWeightMedium,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Number of devices to scan simultaneously (1-10). Higher values improve speed but use more resources.',
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _concurrentScanCount.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: _concurrentScanCount.toString(),
                  activeColor: AppTheme.primaryColor,
                  inactiveColor: AppTheme.borderPrimary,
                  onChanged: (value) {
                    setState(() {
                      _concurrentScanCount = value.toInt();
                    });
                  },
                  onChangeEnd: (value) {
                    _saveConcurrentScanCount(value.toInt());
                  },
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.inputBackground,
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                  border: Border.all(color: AppTheme.borderPrimary),
                ),
                child: Text(
                  '$_concurrentScanCount',
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeBodyLarge,
                    fontWeight: AppTheme.fontWeightSemiBold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.inputBackground,
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
              border: Border.all(color: AppTheme.borderPrimary),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.textSecondary,
                  size: AppTheme.iconSizeMedium,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _concurrentScanCount == 1
                        ? 'Sequential scanning (safest, slowest)'
                        : _concurrentScanCount <= 3
                            ? 'Balanced performance (recommended)'
                            : _concurrentScanCount <= 6
                                ? 'High performance (requires good hardware)'
                                : 'Maximum performance (CPU/memory intensive)',
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeBody,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPingTestSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: Border.all(color: AppTheme.borderPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.network_ping,
                color: AppTheme.primaryColor,
                size: AppTheme.iconSizeXLarge,
              ),
              const SizedBox(width: 12),
              Text(
                'Ping Test',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeLargeTitle,
                  fontWeight: AppTheme.fontWeightSemiBold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pingAddressController,
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Address (IP or hostname)',
                    labelStyle: TextStyle(color: AppTheme.textSecondary),
                    hintText: '192.168.1.1 or google.com',
                    hintStyle: TextStyle(color: AppTheme.textTertiary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GradientButton(
                label: _isPinging ? 'Pinging...' : 'Ping',
                icon: Icons.send,
                backgroundConfig: AppTheme.primaryButtonGradient ?? AppTheme.primaryColor,
                onPressed: _isPinging ? null : _runPing,
                textColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                iconSize: AppTheme.iconSizeMedium,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            height: 200,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.inputBackground,
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
              border: Border.all(color: AppTheme.borderPrimary),
            ),
            child: SingleChildScrollView(
              child: Text(
                _pingResultController.text.isEmpty
                    ? 'Ping results will appear here'
                    : _pingResultController.text,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontFamily: AppTheme.monospaceFontFamily,
                  fontSize: AppTheme.fontSizeBody,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugLoggingSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: Border.all(color: AppTheme.borderPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bug_report,
                color: AppTheme.primaryColor,
                size: AppTheme.iconSizeXLarge,
              ),
              const SizedBox(width: 12),
              Text(
                'Debug Logging',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeLargeTitle,
                  fontWeight: AppTheme.fontWeightSemiBold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enable Session Logging',
                      style: TextStyle(
                        fontSize: AppTheme.fontSizeBodyLarge,
                        fontWeight: AppTheme.fontWeightMedium,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Log errors and debug messages to file for this session. (Resets on restart)',
                      style: TextStyle(
                        fontSize: AppTheme.fontSizeBody,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: DebugLogger().isEnabled,
                activeThumbColor: AppTheme.primaryColor,
                onChanged: (value) async {
                  if (value) {
                    await DebugLogger().enable();
                  } else {
                    await DebugLogger().disable();
                  }
                  setState(() {});
                },
              ),
            ],
          ),
          if (DebugLogger().isEnabled) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.inputBackground,
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                border: Border.all(color: AppTheme.borderPrimary),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                        size: AppTheme.iconSizeMedium,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          kIsWeb
                              ? 'Logging is active. Sending logs to host...'
                              : 'Logging is active',
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeBody,
                            fontWeight: AppTheme.fontWeightMedium,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!kIsWeb) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.folder_outlined,
                          color: AppTheme.textTertiary,
                          size: AppTheme.iconSizeSmall,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SelectableText(
                            AppPathsService().debugLogPath,
                            style: TextStyle(
                              fontSize: AppTheme.fontSizeBody,
                              color: AppTheme.textSecondary,
                              fontFamily: AppTheme.monospaceFontFamily,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildAIIntegrationSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: Border.all(color: AppTheme.borderPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.psychology,
                color: AppTheme.primaryColor,
                size: AppTheme.iconSizeXLarge,
              ),
              const SizedBox(width: 12),
              Text(
                'AI Integration',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeLargeTitle,
                  fontWeight: AppTheme.fontWeightSemiBold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Provider',
            style: TextStyle(
              fontSize: AppTheme.fontSizeBodyLarge,
              fontWeight: AppTheme.fontWeightMedium,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<LLMProvider>(
            value: _selectedProvider,
            style: TextStyle(color: AppTheme.textPrimary),
            dropdownColor: AppTheme.surfaceColor,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                borderSide: BorderSide(color: AppTheme.borderPrimary),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                borderSide: BorderSide(color: AppTheme.borderPrimary),
              ),
            ),
            items: LLMProvider.values.map((provider) {
              return DropdownMenuItem(
                value: provider,
                child: Text(provider.displayName),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedProvider = value;
                  if (value != LLMProvider.none) {
                    _baseUrlController.text = value.defaultBaseUrl;
                  } else {
                    _baseUrlController.text = '';
                  }
                  _availableModels = [];
                  _selectedModel = '';
                });
                _saveLLMSettings();
              }
            },
          ),
          if (_selectedProvider != LLMProvider.none && _selectedProvider.requiresBaseUrl) ...[
            const SizedBox(height: 16),
            Text(
              'Base URL',
              style: TextStyle(
                fontSize: AppTheme.fontSizeBodyLarge,
                fontWeight: AppTheme.fontWeightMedium,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _baseUrlController,
              style: TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: _selectedProvider.defaultBaseUrl,
                hintStyle: TextStyle(color: AppTheme.textTertiary),
              ),
            ),
          ],
          if (_selectedProvider != LLMProvider.none && _selectedProvider.requiresApiKey) ...[
            const SizedBox(height: 16),
            Text(
              'API Key',
              style: TextStyle(
                fontSize: AppTheme.fontSizeBodyLarge,
                fontWeight: AppTheme.fontWeightMedium,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _apiKeyController,
              obscureText: true,
              style: TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Enter API key',
                hintStyle: TextStyle(color: AppTheme.textTertiary),
              ),
              onChanged: (_) => _saveLLMSettings(),
            ),
          ],
          if (_selectedProvider != LLMProvider.none) ...[
            const SizedBox(height: 16),
            Text(
              'Temperature (${(_selectedProvider == LLMProvider.none ? 0.7 : _getTemperature()).toStringAsFixed(1)})',
              style: TextStyle(
                fontSize: AppTheme.fontSizeBodyLarge,
                fontWeight: AppTheme.fontWeightMedium,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Slider(
              value: _getTemperature(),
              min: 0.0,
              max: 2.0,
              divisions: 20,
              activeColor: AppTheme.primaryColor,
              inactiveColor: AppTheme.borderPrimary,
              onChanged: (value) {
                setState(() {});
                _saveLLMSettings(temperature: value);
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Max Tokens: ${_getMaxTokens()}',
              style: TextStyle(
                fontSize: AppTheme.fontSizeBodyLarge,
                fontWeight: AppTheme.fontWeightMedium,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Slider(
              value: _getMaxTokens().toDouble(),
              min: 100,
              max: 32000,
              divisions: 319,
              activeColor: AppTheme.primaryColor,
              inactiveColor: AppTheme.borderPrimary,
              onChanged: (value) {
                setState(() {});
                _saveLLMSettings(maxTokens: value.toInt());
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Timeout (seconds): ${_getTimeoutSeconds()}',
              style: TextStyle(
                fontSize: AppTheme.fontSizeBodyLarge,
                fontWeight: AppTheme.fontWeightMedium,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Slider(
              value: _getTimeoutSeconds().toDouble(),
              min: 10,
              max: 360,
              divisions: 35,
              activeColor: AppTheme.primaryColor,
              inactiveColor: AppTheme.borderPrimary,
              onChanged: (value) {
                setState(() {});
                _saveLLMSettings(timeoutSeconds: value.toInt());
              },
            ),
          ],
          if (_selectedProvider != LLMProvider.none) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Model',
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeBodyLarge,
                      fontWeight: AppTheme.fontWeightMedium,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                GradientButton(
                  label: 'Refresh',
                  icon: Icons.refresh,
                  backgroundConfig: AppTheme.primaryButtonGradient ?? AppTheme.primaryColor,
                  onPressed: _isLoadingModels ? null : _loadModels,
                  textColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  iconSize: AppTheme.iconSizeSmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_isLoadingModels)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: CircularProgressIndicator(color: AppTheme.primaryColor),
                ),
              )
            else if (_availableModels.isEmpty)
              TextField(
                onChanged: (value) {
                  setState(() {
                    _selectedModel = value;
                  });
                  _saveLLMSettings();
                },
                controller: TextEditingController(text: _selectedModel),
                style: TextStyle(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Enter model name',
                  hintStyle: TextStyle(color: AppTheme.textTertiary),
                ),
              )
            else
              DropdownButtonHideUnderline(
                child: DropdownButton2<String>(
                  isExpanded: true,
                  hint: Text('Select Model', style: TextStyle(color: AppTheme.textSecondary)),
                  value: _availableModels.contains(_selectedModel) ? _selectedModel : null,
                  items: _availableModels.map((model) {
                    return DropdownMenuItem(
                      value: model,
                      child: Text(model, style: TextStyle(color: AppTheme.textPrimary)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedModel = value;
                      });
                      _saveLLMSettings();
                    }
                  },
                  buttonStyleData: ButtonStyleData(
                    height: 50,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.borderPrimary),
                      borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                      color: AppTheme.surfaceColor,
                    ),
                  ),
                  dropdownStyleData: DropdownStyleData(
                    maxHeight: 300,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: AppTheme.surfaceColor,
                    ),
                  ),
                  dropdownSearchData: DropdownSearchData(
                    searchController: _modelSearchController,
                    searchInnerWidgetHeight: 50,
                    searchInnerWidget: Container(
                      padding: const EdgeInsets.all(8),
                      child: TextField(
                        controller: _modelSearchController,
                        decoration: InputDecoration(
                          hintText: 'Search models...',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onChanged: (value) {
                          debugPrint('[Model Search] Query: "$value"');
                          final matches = _availableModels.where((m) => m.toLowerCase().contains(value.toLowerCase())).length;
                          debugPrint('[Model Search] Matching results: $matches / ${_availableModels.length}');
                        },
                      ),
                    ),
                    searchMatchFn: (item, searchValue) {
                      return item.value.toString().toLowerCase().contains(searchValue.toLowerCase());
                    },
                  ),
                  onMenuStateChange: (isOpen) {
                    if (!isOpen) {
                      _modelSearchController.clear();
                    }
                  },
                ),
              ),
            const SizedBox(height: 16),
            Center(
              child: GradientButton(
                label: 'Test Integration',
                icon: Icons.play_arrow,
                backgroundConfig: AppTheme.primaryButtonGradient ?? AppTheme.primaryColor,
                onPressed: _selectedModel.isEmpty ? null : _showTestIntegrationDialog,
                textColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TestIntegrationDialog extends StatefulWidget {
  final LLMSettings settings;
  final LLMService llmService;

  const _TestIntegrationDialog({
    required this.settings,
    required this.llmService,
  });

  @override
  State<_TestIntegrationDialog> createState() => _TestIntegrationDialogState();
}

class _TestIntegrationDialogState extends State<_TestIntegrationDialog> {
  bool _isTesting = false;
  String _result = '';

  @override
  void initState() {
    super.initState();
    _runTest();
  }

  Future<void> _runTest() async {
    setState(() {
      _isTesting = true;
      _result = 'Connecting to ${widget.settings.provider.displayName}...\n';
    });

    try {
      final response = await widget.llmService.testConnection(widget.settings);
      setState(() {
        _result += '\nSuccess!\n\nResponse:\n$response';
        _isTesting = false;
      });
    } catch (e) {
      setState(() {
        _result += '\nError:\n$e';
        _isTesting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceColor,
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.psychology,
                  color: AppTheme.primaryColor,
                  size: AppTheme.iconSizeXLarge,
                ),
                const SizedBox(width: 12),
                Text(
                  'Test AI Integration',
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeLargeTitle,
                    fontWeight: AppTheme.fontWeightSemiBold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(Icons.close, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              height: 300,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.inputBackground,
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                border: Border.all(color: AppTheme.borderPrimary),
              ),
              child: SingleChildScrollView(
                child: SelectableText(
                  _result.isEmpty ? 'Waiting for response...' : _result,
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontFamily: AppTheme.monospaceFontFamily,
                    fontSize: AppTheme.fontSizeBody,
                  ),
                ),
              ),
            ),
            if (_isTesting) ...[
              const SizedBox(height: 16),
              Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
