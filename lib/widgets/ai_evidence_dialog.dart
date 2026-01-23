import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:penpeeper/theme_config.dart';
import 'package:penpeeper/models/llm_settings.dart';
import 'package:penpeeper/repositories/settings_repository.dart';
import 'package:penpeeper/repositories/device_repository.dart';
import 'package:penpeeper/repositories/metadata_repository.dart';
import 'package:penpeeper/repositories/scan_repository.dart';
import 'package:penpeeper/services/unified_llm_client.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AiEvidenceDialog extends StatefulWidget {
  final String descriptionText;
  final int deviceId;
  final String? severity;
  final String? category;
  final String? cvssScore;

  const AiEvidenceDialog({
    super.key,
    required this.descriptionText,
    required this.deviceId,
    this.severity,
    this.category,
    this.cvssScore,
  });

  @override
  State<AiEvidenceDialog> createState() => _AiEvidenceDialogState();
}

class _AiEvidenceDialogState extends State<AiEvidenceDialog> {
  final _resultController = TextEditingController();
  final _debugController = TextEditingController();
  final _settingsRepo = SettingsRepository();
  final _deviceRepo = DeviceRepository();
  final _metadataRepo = MetadataRepository();
  final _scanRepo = ScanRepository();
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

  Future<void> _generateEvidence() async {
    setState(() {
      _isGenerating = true;
      _resultController.text = 'Generating evidence...';
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

      String styleGuidance = _getStyleGuidance(_selectedDetail);

      // Add model-specific instructions for DeepSeek
      String modelSpecificGuidance = '';
      if (settings.modelName.toLowerCase().contains('deepseek')) {
        modelSpecificGuidance = '''

SPECIAL INSTRUCTIONS FOR THIS MODEL:
- You MUST respond in English only - do not include any Chinese characters or phrases
- Provide ONLY the final answer - do NOT include your reasoning process or thinking steps
- The section labels "Evidence Observed:" and "Verification Testing Recommended:" should be plain text, NOT markdown headers
- Commands should be written inline like: "Run the command nmap -sV target" not in separate code blocks
- Do NOT use numbered lists (1., 2., 3.) - write verification steps as flowing paragraphs
- When suggesting multiple tests, use phrases like "First," "Additionally," "Alternatively," not numbers
''';
      }

      // IMPROVED PROMPT with clearer structure and formatting requirements
      final prompt = '''You are a cybersecurity expert documenting evidence for a penetration testing report.

================================================================================
CRITICAL FORMATTING REQUIREMENTS - READ THIS FIRST:
================================================================================
Your response MUST be written in PLAIN TEXT PROSE ONLY.

ABSOLUTELY FORBIDDEN:
- NO markdown headers (##, ###)
- NO bold or italic formatting (**, *, __, _)
- NO bullet points (•, -, *)
- NO numbered lists (1., 2., 3.)
- NO code blocks or backticks (\`\`\`, \`)
- NO special formatting of any kind

REQUIRED FORMAT:
- Write in natural paragraphs using complete sentences
- Use section labels like "Evidence Observed:" or "Verification Needed:" as plain text
- Separate sections with blank lines
- For commands or technical details, write them inline within sentences

================================================================================
VULNERABILITY BEING INVESTIGATED:
================================================================================
${widget.descriptionText}$severityContext$categoryContext

${deviceContext.isNotEmpty ? '================================================================================\n$deviceContext\n' : ''}
================================================================================
YOUR TASK - WRITE TWO DISTINCT SECTIONS:
================================================================================

SECTION 1 - Evidence Already Observed:
Analyze the device context and scan data provided above. Document ONLY what we can actually see from this data that indicates the vulnerability exists. Reference specific:
- Port numbers and service versions actually shown in the scan data
- CVE numbers from vulners output if present
- Script outputs that demonstrate vulnerable configurations
- Service banners or responses that prove the issue
DO NOT invent scan results or commands that were not shown above. Base this section entirely on the data provided.

SECTION 2 - Verification Testing Recommended:
Suggest specific penetration testing commands, tools, or techniques that should be performed next to definitively confirm this vulnerability. Include:
- Exact command syntax for tools like nmap, metasploit, or specialized exploits
- What the expected vulnerable response would look like
- Alternative testing approaches if the primary test fails
- References to exploit databases or security advisories

$styleGuidance$modelSpecificGuidance

================================================================================
FINAL REMINDERS:
================================================================================
- Write ONLY in plain prose without any markdown or special formatting
- Clearly separate observed evidence from recommended testing
- Be specific and technical but stay concise
- Reference actual data from the scans provided above''';

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

      final evidence = response.content;
      final cleanedEvidence = _stripMarkdownFormatting(evidence);

      _debugController.text += '=== RESPONSE FROM LLM ===\n$evidence\n';
      if (cleanedEvidence != evidence) {
        _debugController.text += '\n=== CLEANED RESPONSE ===\n$cleanedEvidence\n';
      }

      setState(() {
        _resultController.text = cleanedEvidence;
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

  /// Strip markdown formatting from LLM response as a fallback
  String _stripMarkdownFormatting(String text) {
    String cleaned = text;

    // Extract code block contents first (preserve the commands inside)
    final codeBlockPattern = RegExp(r'```(?:plaintext|bash|shell|sh|)?\s*\n([\s\S]*?)\n```');
    final codeBlocks = <String>[];
    cleaned = cleaned.replaceAllMapped(codeBlockPattern, (match) {
      final content = match.group(1)?.trim() ?? '';
      codeBlocks.add(content);
      return '<<CODE_BLOCK_${codeBlocks.length - 1}>>'; // Placeholder
    });

    // Extract inline code contents BEFORE removing backticks
    final inlineCodePattern = RegExp(r'`([^`]+)`');
    final inlineCodes = <String>[];
    cleaned = cleaned.replaceAllMapped(inlineCodePattern, (match) {
      final content = match.group(1) ?? '';
      inlineCodes.add(content);
      return '<<INLINE_CODE_${inlineCodes.length - 1}>>';
    });

    // Remove bold/italic but preserve text
    cleaned = cleaned.replaceAll(RegExp(r'\*\*([^*]+)\*\*'), r'$1');
    cleaned = cleaned.replaceAll(RegExp(r'__([^_]+)__'), r'$1');
    cleaned = cleaned.replaceAll(RegExp(r'\*([^*]+)\*'), r'$1');
    cleaned = cleaned.replaceAll(RegExp(r'_([^_]+)_'), r'$1');

    // Remove headers (###, ##, #) but keep the text
    cleaned = cleaned.replaceAll(RegExp(r'^#{1,6}\s+', multiLine: true), '');

    // Convert bullet points to inline text (remove markers)
    cleaned = cleaned.replaceAll(RegExp(r'^\s*[-*•]\s+', multiLine: true), '');

    // Remove numbered list formatting but keep text
    cleaned = cleaned.replaceAll(RegExp(r'^\s*\d+\.\s+', multiLine: true), '');

    // Restore code blocks as inline text
    for (var i = 0; i < codeBlocks.length; i++) {
      cleaned = cleaned.replaceAll('<<CODE_BLOCK_$i>>', codeBlocks[i]);
    }

    // Restore inline codes as plain text
    for (var i = 0; i < inlineCodes.length; i++) {
      cleaned = cleaned.replaceAll('<<INLINE_CODE_$i>>', inlineCodes[i]);
    }

    // Clean up excessive whitespace
    cleaned = cleaned.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    cleaned = cleaned.trim();

    return cleaned;
  }

  String _getStyleGuidance(String detailLevel) {
    switch (detailLevel) {
      case 'Quick':
        return '''SECTION 1 Length: 2-3 sentences stating what scan data shows
SECTION 2 Length: 2-3 sentences with one primary verification test
Total: Under 150 words''';

      case 'Detailed':
        return '''SECTION 1 - Evidence Already Observed (write in prose paragraphs):
Start by identifying what service and version the scan data shows. Quote specific CVE numbers if present in vulners output. Reference any script outputs that demonstrate vulnerable behavior. Explain what each piece of scan data tells us about the vulnerability. If exploit database entries are listed, mention their severity scores.

SECTION 2 - Verification Testing Recommended (write in prose paragraphs):
Provide comprehensive testing guidance. Describe multiple verification approaches starting with the most definitive. Include exact command syntax for network scanning tools, exploitation frameworks, or custom scripts. Explain what responses would confirm the vulnerability. Reference specific exploit modules or proof-of-concept code if available. Suggest alternative testing methods if primary approach is not feasible.

Write thoroughly with technical depth (400-600 words total).''';

      default: // Standard
        return '''SECTION 1 - Evidence Already Observed: 
Write 2-3 paragraphs describing what the scan data reveals about this vulnerability. Reference specific ports, versions, CVEs, or script outputs shown above.

SECTION 2 - Verification Testing Recommended:
Write 2-3 paragraphs suggesting 2-4 specific tests to confirm the vulnerability. Include command examples written inline in your sentences.

Total length: 250-400 words.''';
    }
  }

  Future<String> _fetchRelevantDeviceContext() async {
    final buffer = StringBuffer();

    try {
      final device = await _deviceRepo.getDeviceById(widget.deviceId);
      if (device != null) {
        buffer.writeln('DEVICE CONTEXT:');
        buffer.writeln('Device: ${device.name} (${device.ipAddress})');
        if (device.vendor != null && device.vendor!.isNotEmpty) {
          buffer.writeln('Vendor: ${device.vendor}');
        }
      }

      if (kIsWeb) {
        final response = await http.get(Uri.parse('/api/devices/${widget.deviceId}/details'));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          _appendScanData(buffer, data);
        }
      } else {
        final ports = await _metadataRepo.getNmapPorts(widget.deviceId);
        final scripts = await _metadataRepo.getNmapScripts(widget.deviceId);
        final scans = await _scanRepo.getScansForDevice(widget.deviceId);

        if (ports.isNotEmpty) {
          buffer.writeln('\nOPEN PORTS:');
          for (final port in ports) {
            buffer.write('- Port ${port['port']}/${port['protocol']}: ');
            if (port['product'] != null) buffer.write('${port['product']} ');
            if (port['version'] != null) buffer.write('${port['version']} ');
            if (port['service_name'] != null) buffer.write('(${port['service_name']})');
            buffer.writeln();
          }
        }

        // Include script outputs - especially vulners for CVE data
        if (scripts.isNotEmpty) {
          buffer.writeln('\nSCAN SCRIPTS:');
          for (final script in scripts.take(5)) {
            buffer.writeln('- ${script['script_id']}:');
            final output = script['output'] as String;
            // Truncate long outputs but keep vulners data intact if possible
            if (script['script_id'] == 'vulners' && output.length > 2000) {
              buffer.writeln('  ${output.substring(0, 2000)}...');
            } else {
              buffer.writeln('  ${output.length > 500 ? output.substring(0, 500) + '...' : output}');
            }
          }
        }

        // Include other scan results (nikto, ffuf, etc)
        if (scans.isNotEmpty) {
          buffer.writeln('\nADDITIONAL SCANS:');
          for (final scan in scans.take(3)) {
            buffer.writeln('- ${scan['name']}:');
            final content = scan['content'] as String;
            buffer.writeln('  ${content.length > 500 ? content.substring(0, 500) + '...' : content}');
          }
        }
      }
    } catch (e) {
      buffer.writeln('(Device context unavailable)');
    }

    return buffer.toString();
  }

  void _appendScanData(StringBuffer buffer, Map<String, dynamic> data) {
    final ports = data['ports'] as List?;
    if (ports != null && ports.isNotEmpty) {
      buffer.writeln('\nOPEN PORTS:');
      for (final port in ports.where((p) => p['state'] == 'open')) {
        buffer.write('- Port ${port['port']}/${port['protocol']}: ');
        if (port['product'] != null) buffer.write('${port['product']} ');
        if (port['version'] != null) buffer.write('${port['version']} ');
        if (port['service_name'] != null) buffer.write('(${port['service_name']})');
        buffer.writeln();
      }
    }

    // Include scripts from web API response
    final scripts = data['scripts'] as List?;
    if (scripts != null && scripts.isNotEmpty) {
      buffer.writeln('\nSCAN SCRIPTS:');
      for (final script in scripts.take(5)) {
        buffer.writeln('- ${script['script_id']}:');
        final output = script['output'] as String;
        buffer.writeln('  ${output.length > 500 ? output.substring(0, 500) + '...' : output}');
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
                  Icon(Icons.verified_user, color: AppTheme.primaryColor, size: AppTheme.iconSizeXLarge),
                  const SizedBox(width: 12),
                  Text(
                    'AI Evidence Generator',
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
              Row(
                children: [
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
                  onPressed: _isGenerating ? null : _generateEvidence,
                  icon: _isGenerating
                      ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : Icon(Icons.auto_awesome),
                  label: Text(_isGenerating ? 'Generating...' : 'Generate Evidence'),
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
                    hintText: 'AI-generated evidence will appear here...',
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