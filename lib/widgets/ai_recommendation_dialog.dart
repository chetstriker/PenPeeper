import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:penpeeper/theme_config.dart';
import 'package:penpeeper/models/llm_settings.dart';
import 'package:penpeeper/repositories/settings_repository.dart';
import 'package:penpeeper/repositories/device_repository.dart';
import 'package:penpeeper/services/unified_llm_client.dart';
import 'package:penpeeper/database/connection/database_connection.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AiRecommendationDialog extends StatefulWidget {
  final String descriptionText;
  final int deviceId;
  final String? severity;
  final String? category;
  final String? cvssScore;

  const AiRecommendationDialog({
    super.key,
    required this.descriptionText,
    required this.deviceId,
    this.severity,
    this.category,
    this.cvssScore,
  });

  @override
  State<AiRecommendationDialog> createState() => _AiRecommendationDialogState();
}

class _AiRecommendationDialogState extends State<AiRecommendationDialog> {
  final _resultController = TextEditingController();
  final _debugController = TextEditingController();
  final _settingsRepo = SettingsRepository();
  final _deviceRepo = DeviceRepository();
  bool _isGenerating = false;
  bool _showDebug = false;
  String _selectedDetail = 'Standard';
  bool _includeDeviceContext = true;
  String? _statusMessage;
  LLMUsageMetrics? _tokenUsage;

  @override
  void dispose() {
    _resultController.dispose();
    _debugController.dispose();
    super.dispose();
  }

  Future<void> _generateRecommendation() async {
    setState(() {
      _isGenerating = true;
      _resultController.text = 'Generating recommendation...';
      _debugController.text = 'Starting generation process...\n';
      _statusMessage = null;
      _tokenUsage = null;
    });

    try {
      final settingsJson = await _settingsRepo.getSetting('llm_settings', '');
      if (settingsJson.isEmpty) {
        throw Exception('LLM settings not configured');
      }

      final settings = LLMSettings.fromJson(json.decode(settingsJson));
      _debugController.text += 'Provider: ${settings.provider.displayName}\n';
      _debugController.text += 'Model: ${settings.modelName}\n';
      _debugController.text += 'Detail Level: $_selectedDetail\n';
      _debugController.text += 'Include Device Context: $_includeDeviceContext\n\n';
      setState(() {});

      String deviceContext = '';
      if (widget.deviceId != 0 && _includeDeviceContext) {
        deviceContext = await _fetchRelevantDeviceContext();
        _debugController.text += 'Device context fetched\n\n';
        setState(() {});
      }

      // Build severity context
      String severityContext = '';
      if (widget.severity != null && widget.severity!.isNotEmpty) {
        severityContext = '\nSeverity: ${widget.severity}';
        if (widget.cvssScore != null && widget.cvssScore!.isNotEmpty) {
          severityContext += ' (CVSS ${widget.cvssScore})';
        }
      }

      String categoryContext = '';
      if (widget.category != null && widget.category!.isNotEmpty) {
        categoryContext = '\nCategory: ${widget.category}';
      }

      // Determine recommendation style based on detail level
      String styleGuidance = _getStyleGuidance(_selectedDetail);

      final prompt = '''You are a cybersecurity expert writing a penetration testing report recommendation.

VULNERABILITY DESCRIPTION:
${widget.descriptionText}$severityContext$categoryContext${deviceContext.isNotEmpty ? '\n\n$deviceContext' : ''}

$styleGuidance

IMPORTANT: 
- Write for technical staff who will implement the fix
- Use specific commands, file paths, and configuration settings where applicable
- Do NOT use markdown headers or excessive formatting (no ##, **)
- Write in clear, professional prose''';

      _debugController.text += '=== PROMPT SENT TO LLM ===\n$prompt\n\n';
      setState(() {});

      final response = await UnifiedLLMClient.sendRequest(
        config: LLMRequestConfig(
          provider: settings.provider.name,
          modelName: settings.modelName,
          apiKey: settings.apiKey,
          baseUrl: settings.baseUrl,
          temperature: settings.temperature,
          maxTokens: settings.maxTokens,
          timeoutSeconds: settings.timeoutSeconds,
        ),
        prompt: prompt,
      );

      if (!response.success) {
        throw Exception(response.userFriendlyError);
      }

      final recommendation = response.content;

      _debugController.text += '=== RESPONSE FROM LLM ===\n$recommendation\n';

      setState(() {
        _resultController.text = recommendation;
        _tokenUsage = response.usage;
        _isGenerating = false;
      });
    } catch (e, stackTrace) {
      setState(() {
        _statusMessage = 'Error: $e';
        _resultController.text = 'Error: $e';
        _debugController.text += '\n=== ERROR ===\n$e\n\nStack Trace:\n$stackTrace';
        _isGenerating = false;
      });
    }
  }

  Widget _buildStatusBar() {
    if (_statusMessage == null && _tokenUsage == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _statusMessage != null ? AppTheme.errorColor.withOpacity(0.1) : AppTheme.successColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
        border: Border.all(
          color: _statusMessage != null ? AppTheme.errorColor : AppTheme.successColor,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _statusMessage != null ? Icons.error_outline : Icons.check_circle_outline,
            color: _statusMessage != null ? AppTheme.errorColor : AppTheme.successColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _statusMessage ?? 'Tokens: ${_tokenUsage?.totalTokens ?? 0} (Prompt: ${_tokenUsage?.promptTokens ?? 0}, Response: ${_tokenUsage?.completionTokens ?? 0})',
              style: TextStyle(
                color: _statusMessage != null ? AppTheme.errorColor : AppTheme.successColor,
                fontSize: AppTheme.fontSizeBody,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStyleGuidance(String detailLevel) {
    switch (detailLevel) {
      case 'Quick':
        return '''Write a CONCISE recommendation (2-3 sentences):
1. State the primary remediation action
2. Provide one specific command or configuration change
3. Mention the expected result

Keep it under 100 words.''';

      case 'Detailed':
        return '''Write a COMPREHENSIVE recommendation that includes:
1. **Root Cause Analysis**: Why this vulnerability exists
2. **Immediate Remediation**: Step-by-step instructions with specific commands
3. **Verification Steps**: How to confirm the fix was successful
4. **Long-term Prevention**: Configuration management, monitoring, and policies to prevent recurrence
5. **Reference Links**: Official documentation or security advisories when relevant
6. **Risk Assessment**: What could happen if this is not fixed

Provide detailed technical guidance with examples.''';

      default: // Standard
        return '''Write a clear, actionable recommendation:
1. Explain how to remediate the vulnerability
2. Provide specific steps or configuration changes with actual commands/settings
3. Include verification method to confirm the fix
4. Add key security best practices relevant to this issue

Keep it thorough but concise (250-400 words).''';
    }
  }

  Future<String> _fetchRelevantDeviceContext() async {
    final buffer = StringBuffer();

    try {
      // Only fetch basic device info - not full scans
      final device = await _deviceRepo.getDeviceById(widget.deviceId);
      if (device != null) {
        buffer.writeln('DEVICE CONTEXT:');
        buffer.writeln('Device: ${device.name} (${device.ipAddress})');
        if (device.vendor != null && device.vendor!.isNotEmpty) {
          buffer.writeln('Vendor: ${device.vendor}');
        }
      }

      // Determine if we need port/service info based on vulnerability description
      final needsServiceInfo = _vulnerabilityNeedsServiceContext();

      if (needsServiceInfo) {
        if (kIsWeb) {
          final response = await http.get(Uri.parse('/api/devices/${widget.deviceId}/details'));
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            _appendRelevantServices(buffer, data);
          }
        } else {
          final db = await DatabaseConnection().database;
          final hosts = await db.query('nmap_hosts', where: 'device_id = ?', whereArgs: [widget.deviceId]);
          if (hosts.isNotEmpty) {
            final hostId = hosts.first['id'];
            final ports = await db.query(
              'nmap_ports',
              where: 'host_id = ? AND state = ?',
              whereArgs: [hostId, 'open'],
              orderBy: 'port ASC',
              limit: 10, // Only top 10 most relevant ports
            );

            if (ports.isNotEmpty) {
              buffer.writeln('\nKey Services:');
              for (final port in ports) {
                // Only include if service has useful info
                if (port['service_name'] != null || port['product'] != null) {
                  buffer.write('- Port ${port['port']}: ');
                  if (port['product'] != null) buffer.write('${port['product']} ');
                  if (port['version'] != null) buffer.write('${port['version']} ');
                  if (port['service_name'] != null) buffer.write('(${port['service_name']})');
                  buffer.writeln();
                }
              }
            }
          }
        }
      }
    } catch (e) {
      buffer.writeln('(Device context unavailable)');
    }

    return buffer.toString();
  }

  bool _vulnerabilityNeedsServiceContext() {
    final desc = widget.descriptionText.toLowerCase();

    // Check if vulnerability description mentions services/ports
    final serviceKeywords = [
      'ssh', 'rdp', 'http', 'ftp', 'smtp', 'telnet', 'mysql', 'postgresql',
      'smb', 'ldap', 'dns', 'snmp', 'port', 'service', 'daemon', 'server'
    ];

    return serviceKeywords.any((keyword) => desc.contains(keyword));
  }

  void _appendRelevantServices(StringBuffer buffer, Map<String, dynamic> data) {
    final ports = data['ports'] as List?;
    if (ports != null && ports.isNotEmpty) {
      final openPorts = ports.where((p) => p['state'] == 'open').take(10);
      if (openPorts.isNotEmpty) {
        buffer.writeln('\nKey Services:');
        for (final port in openPorts) {
          if (port['service_name'] != null || port['product'] != null) {
            buffer.write('- Port ${port['port']}: ');
            if (port['product'] != null) buffer.write('${port['product']} ');
            if (port['version'] != null) buffer.write('${port['version']} ');
            if (port['service_name'] != null) buffer.write('(${port['service_name']})');
            buffer.writeln();
          }
        }
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceColor,
      child: Container(
        width: 700,
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.psychology, color: AppTheme.primaryColor, size: AppTheme.iconSizeXLarge),
                  const SizedBox(width: 12),
                  Text(
                    'AI Recommendation Generator',
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
              const SizedBox(height: 24),

              // SETTINGS ROW
              Row(
                children: [
                  // Detail Level Dropdown
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Detail Level:',
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeBody,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.inputBackground,
                            borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                            border: Border.all(color: AppTheme.borderPrimary),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedDetail,
                            isExpanded: true,
                            underline: Container(),
                            dropdownColor: AppTheme.surfaceColor,
                            style: TextStyle(color: AppTheme.textPrimary),
                            items: ['Quick', 'Standard', 'Detailed'].map((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (String? newValue) {
                              if (newValue != null) {
                                setState(() {
                                  _selectedDetail = newValue;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Device Context Checkbox
                  Expanded(
                    child: CheckboxListTile(
                      title: Text(
                        'Include Device Context',
                        style: TextStyle(
                          fontSize: AppTheme.fontSizeBody,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      subtitle: Text(
                        'Add device/service info',
                        style: TextStyle(
                          fontSize: AppTheme.fontSizeSmall,
                          color: AppTheme.textTertiary,
                        ),
                      ),
                      value: _includeDeviceContext,
                      onChanged: (bool? value) {
                        setState(() {
                          _includeDeviceContext = value ?? true;
                        });
                      },
                      activeColor: AppTheme.primaryColor,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _generateRecommendation,
                  icon: _isGenerating
                      ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : Icon(Icons.auto_awesome),
                  label: Text(_isGenerating ? 'Generating...' : 'Generate Recommendation'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Result:',
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeBodyLarge,
                      fontWeight: AppTheme.fontWeightMedium,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _showDebug = !_showDebug;
                      });
                    },
                    icon: Icon(
                      _showDebug ? Icons.visibility_off : Icons.bug_report,
                      size: 16,
                    ),
                    label: Text(_showDebug ? 'Hide Debug' : 'Show Debug'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildStatusBar(),
              Container(
                width: double.infinity,
                height: 300,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.inputBackground,
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                  border: Border.all(color: AppTheme.borderPrimary),
                ),
                child: TextField(
                  controller: _resultController,
                  maxLines: null,
                  expands: true,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: AppTheme.fontSizeBody,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'AI-generated recommendation will appear here...',
                    hintStyle: TextStyle(color: AppTheme.textTertiary),
                  ),
                ),
              ),
              if (_showDebug) ...[
                const SizedBox(height: 16),
                Text(
                  'Debug Information:',
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeBodyLarge,
                    fontWeight: AppTheme.fontWeightMedium,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
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
                    child: SelectableText(
                      _debugController.text.isEmpty
                          ? 'Debug information will appear here...'
                          : _debugController.text,
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontFamily: AppTheme.monospaceFontFamily,
                        fontSize: AppTheme.fontSizeBody,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}