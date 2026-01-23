import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:penpeeper/theme_config.dart';
import 'package:penpeeper/models/llm_settings.dart';
import 'package:penpeeper/repositories/settings_repository.dart';
import 'package:penpeeper/repositories/findings_repository.dart';
import 'package:penpeeper/repositories/report_repository.dart';
import 'package:penpeeper/repositories/project_repository.dart';
import 'package:penpeeper/services/unified_llm_client.dart';
import 'package:intl/intl.dart';

class AiExecutiveSummaryDialog extends StatefulWidget {
  final int projectId;

  const AiExecutiveSummaryDialog({
    super.key,
    required this.projectId,
  });

  @override
  State<AiExecutiveSummaryDialog> createState() => _AiExecutiveSummaryDialogState();
}

class _AiExecutiveSummaryDialogState extends State<AiExecutiveSummaryDialog> {
  final _resultController = TextEditingController();
  final _debugController = TextEditingController();
  final _settingsRepo = SettingsRepository();
  final _findingsRepo = FindingsRepository();
  final _reportRepo = ReportRepository();
  final _projectRepo = ProjectRepository();
  bool _isGenerating = false;
  bool _showDebug = false;
  String? _statusMessage;
  LLMUsageMetrics? _tokenUsage;

  @override
  void dispose() {
    _resultController.dispose();
    _debugController.dispose();
    super.dispose();
  }

  Future<void> _generateSummary() async {
    setState(() {
      _isGenerating = true;
      _resultController.text = 'Generating executive summary...';
      _debugController.text = 'Starting generation process...\n';
      _statusMessage = null;
      _tokenUsage = null;
    });

    try {
      final companyName = await _reportRepo.getReportSection(widget.projectId, 'company_name');
      final startDate = await _reportRepo.getReportSection(widget.projectId, 'start_date');
      final endDate = await _reportRepo.getReportSection(widget.projectId, 'end_date');
      final scanRanges = await _projectRepo.getScanRanges(widget.projectId);

      if (companyName.isEmpty || startDate.isEmpty || endDate.isEmpty) {
        setState(() {
          _resultController.text = 'Error: Please fill in Company Name, Start Date, and End Date in the Report tab first.';
          _debugController.text = 'Validation failed: Missing required fields in report sections';
          _isGenerating = false;
        });
        return;
      }

      final settingsJson = await _settingsRepo.getSetting('llm_settings', '');
      if (settingsJson.isEmpty) {
        throw Exception('LLM settings not configured');
      }

      final settings = LLMSettings.fromJson(json.decode(settingsJson));
      _debugController.text += 'Provider: ${settings.provider.displayName}\n';
      _debugController.text += 'Model: ${settings.modelName}\n\n';
      setState(() {});

      final findings = await _findingsRepo.getFlaggedFindingsRaw(widget.projectId);

      if (findings.isEmpty) {
        setState(() {
          _resultController.text = 'No findings available for this project.';
          _debugController.text += 'No findings found for project ${widget.projectId}';
          _isGenerating = false;
        });
        return;
      }

      _debugController.text += 'Found ${findings.length} findings\n';
      setState(() {});

      // DEDUPLICATION & PROCESSING
      final Map<String, Map<String, dynamic>> uniqueFindings = {};
      final severityCounts = <String, int>{};
      final categoryCounts = <String, int>{};

      for (var finding in findings) {
        final severity = (finding['cvss_severity'] ?? 'Unknown').toString().toUpperCase();
        var category = (finding['category'] ?? '').toString();
        final subcategory = (finding['subcategory'] ?? '').toString();
        final comment = finding['comment'] ?? 'No description';

        // Parse Quill JSON to extract plain text
        String plainText = comment;
        try {
          final parsed = json.decode(comment);
          if (parsed is List) {
            plainText = parsed.map((op) {
              if (op is Map && op.containsKey('insert')) {
                return op['insert'].toString();
              }
              return '';
            }).join('').trim();
          }
        } catch (e) {
          // If not JSON, use as-is
        }

        // Auto-categorize if empty
        if (category.isEmpty) {
          category = _autoCategorize(plainText);
        }

        // Create unique key based on severity and first 150 chars of text
        final textKey = plainText.length > 150
            ? plainText.substring(0, 150).trim()
            : plainText.trim();
        final key = '${severity}_$textKey';

        if (uniqueFindings.containsKey(key)) {
          // Duplicate found - increment count
          uniqueFindings[key]!['count']++;
        } else {
          // New unique finding
          uniqueFindings[key] = {
            'severity': severity,
            'category': category,
            'subcategory': subcategory,
            'text': plainText,
            'count': 1,
          };
        }

        // Count severities (all instances)
        severityCounts[severity] = (severityCounts[severity] ?? 0) + 1;

        // Count categories (unique only)
        if (category.isNotEmpty && !uniqueFindings.containsKey(key)) {
          final catKey = subcategory.isNotEmpty ? '$category - $subcategory' : category;
          categoryCounts[catKey] = (categoryCounts[catKey] ?? 0) + 1;
        }
      }

      final uniqueCount = uniqueFindings.length;
      final totalInstances = findings.length;

      _debugController.text += 'Deduplicated to $uniqueCount unique findings (from $totalInstances total)\n\n';
      setState(() {});

      // Build findings text with smarter truncation
      var findingsText = uniqueFindings.values.map((f) {
        final severity = f['severity'];
        final category = f['category'];
        final subcategory = f['subcategory'];
        final plainText = f['text'];
        final count = f['count'];

        final countPrefix = count > 1 ? '[$count instances] ' : '';
        final categoryInfo = category.isNotEmpty
            ? ' | Category: $category${subcategory.isNotEmpty ? ' - $subcategory' : ''}'
            : '';
        final truncated = _truncateIntelligently(plainText, 400);

        return '- Severity: $severity$categoryInfo | Finding: $countPrefix$truncated';
      }).join('\n');

      // TOKEN MANAGEMENT - Limit to top 20 if prompt too large
      final estimatedTokens = (findingsText.length / 4).round();
      if (estimatedTokens > 6000) {
        final topFindings = uniqueFindings.values
            .toList()
          ..sort((a, b) {
            // Sort by severity priority: CRITICAL > HIGH > MEDIUM > LOW > UNKNOWN
            const severityOrder = {'CRITICAL': 0, 'HIGH': 1, 'MEDIUM': 2, 'LOW': 3, 'UNKNOWN': 4};
            final aPriority = severityOrder[a['severity']] ?? 5;
            final bPriority = severityOrder[b['severity']] ?? 5;
            return aPriority.compareTo(bPriority);
          });

        final limitedFindings = topFindings.take(20).toList();

        findingsText = limitedFindings.map((f) {
          final severity = f['severity'];
          final category = f['category'];
          final subcategory = f['subcategory'];
          final plainText = f['text'];
          final count = f['count'];

          final countPrefix = count > 1 ? '[$count instances] ' : '';
          final categoryInfo = category.isNotEmpty
              ? ' | Category: $category${subcategory.isNotEmpty ? ' - $subcategory' : ''}'
              : '';
          final truncated = _truncateIntelligently(plainText, 400);

          return '- Severity: $severity$categoryInfo | Finding: $countPrefix$truncated';
        }).join('\n');

        findingsText += '\n\n[Note: Showing top 20 critical findings. ${uniqueCount - 20} additional findings were analyzed but not detailed here to maintain context length.]';

        _debugController.text += 'Token limit exceeded - limited to top 20 findings\n';
        setState(() {});
      }

      final severitySummary = severityCounts.entries.map((e) => '${e.value} ${e.key}').join(', ');
      final topCategories = categoryCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final categorySummary = topCategories.isNotEmpty
          ? topCategories.take(5).map((e) => '${e.key} (${e.value})').join(', ')
          : 'Various security vulnerabilities';
      final scanScope = scanRanges.isNotEmpty ? scanRanges.join(', ') : 'Not specified';

      // Generate attack scenarios
      final attackScenarios = _generateAttackScenarios(uniqueFindings.values.toList());

      final prompt = '''You are a cybersecurity expert writing content for the Executive Summary section of a penetration testing report.

IMPORTANT: The section already has a header titled "Executive Summary". Do NOT start your response with "Executive Summary" as a title or heading. Start directly with the first paragraph of content.

Client: $companyName
Assessment Period: $startDate to $endDate
Scan Scope (IP Addresses/CIDR Ranges): $scanScope
Total Findings: $totalInstances (${uniqueCount} unique vulnerabilities, with some appearing on multiple systems)
Severity Breakdown: $severitySummary
Top Vulnerability Categories: $categorySummary

BUSINESS IMPACT CONTEXT:
- CRITICAL findings: Immediate risk of data breach, operational disruption, or regulatory violation. These vulnerabilities can be exploited remotely with little to no authentication required.
- HIGH findings: Significant vulnerabilities that could be exploited with moderate effort, potentially leading to unauthorized access or service degradation.
- MEDIUM findings: Security weaknesses requiring specific conditions to exploit, but still pose a tangible risk to the organization.
- LOW findings: Minor security concerns that should be addressed as part of routine security improvements.

Common Attack Scenarios Identified:
$attackScenarios

Detailed Findings (representative sample):
$findingsText

Write a professional 3-4 paragraph executive summary that:
1. Opens with the assessment scope and timeframe
2. Provides a high-level analysis of the security posture based on the number and severity of findings
3. Highlights the most critical vulnerabilities and common vulnerability patterns found
4. Emphasizes the potential business impact including: data loss, operational downtime, compliance violations, reputational damage, and financial impact
5. Concludes with the overall risk level and urgency of remediation with specific recommended timeline (immediate, urgent, planned)

WRITING GUIDELINES:
- Use professional, non-technical language appropriate for C-level executives
- Focus on business impact and risk, not technical implementation details
- Use the company name "$companyName" directly - avoid phrases like "the organization" or "the client"
- Be specific about risks rather than using generic security language
- Quantify impact where possible (e.g., "18 critical vulnerabilities affecting production systems")
- Maintain a professional but urgent tone that motivates action without causing panic''';

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

      final summary = response.content;

      _debugController.text += '=== RESPONSE FROM LLM ===\n$summary\n';

      setState(() {
        _resultController.text = summary;
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

// Helper method: Auto-categorize findings based on keywords
  String _autoCategorize(String text) {
    final lowerText = text.toLowerCase();

    if (lowerText.contains('end of life') || lowerText.contains('eol') || lowerText.contains('end-of-life')) {
      return 'End of Life Systems';
    } else if ((lowerText.contains('default') || lowerText.contains('hardcoded')) &&
        (lowerText.contains('credential') || lowerText.contains('password'))) {
      return 'Default/Hardcoded Credentials';
    } else if (lowerText.contains('remote code execution') || lowerText.contains('rce')) {
      return 'Remote Code Execution';
    } else if (lowerText.contains('buffer overflow')) {
      return 'Buffer Overflow';
    } else if (lowerText.contains('authentication bypass') || lowerText.contains('auth bypass')) {
      return 'Authentication Bypass';
    } else if (lowerText.contains('sql injection') || lowerText.contains('sqli')) {
      return 'Injection Vulnerabilities';
    } else if (lowerText.contains('cross-site scripting') || lowerText.contains('xss')) {
      return 'Cross-Site Scripting';
    } else if (lowerText.contains('privilege escalation')) {
      return 'Privilege Escalation';
    } else if (lowerText.contains('information disclosure') || lowerText.contains('data leak')) {
      return 'Information Disclosure';
    } else if (lowerText.contains('outdated') || lowerText.contains('unpatched')) {
      return 'Outdated Software';
    } else if (lowerText.contains('misconfigur')) {
      return 'System Misconfiguration';
    } else {
      return 'Security Vulnerability';
    }
  }

// Helper method: Intelligent truncation at sentence boundaries
  String _truncateIntelligently(String text, int maxLength) {
    if (text.length <= maxLength) return text;

    // Try to break at sentence boundary
    final sentences = text.split(RegExp(r'[.!?]\s+'));
    String result = '';

    for (var sentence in sentences) {
      if (result.length + sentence.length + 2 < maxLength) {
        result += sentence + '. ';
      } else {
        break;
      }
    }

    // If we got at least one complete sentence, use that
    if (result.trim().isNotEmpty && result.length > 100) {
      return result.trim();
    }

    // Otherwise, hard truncate at word boundary
    final truncated = text.substring(0, maxLength);
    final lastSpace = truncated.lastIndexOf(' ');

    if (lastSpace > maxLength * 0.8) {
      return truncated.substring(0, lastSpace) + '...';
    }

    return truncated + '...';
  }

// Helper method: Generate attack scenarios based on findings
  String _generateAttackScenarios(List<Map<String, dynamic>> findings) {
    final scenarios = <String>[];

    final criticalCount = findings.where((f) => f['severity'] == 'CRITICAL').length;
    final highCount = findings.where((f) => f['severity'] == 'HIGH').length;

    final hasDefaultCreds = findings.any((f) =>
    f['text'].toString().toLowerCase().contains('default') &&
        f['text'].toString().toLowerCase().contains('credential'));

    final hasEOL = findings.any((f) =>
    f['text'].toString().toLowerCase().contains('end of life') ||
        f['text'].toString().toLowerCase().contains('eol'));

    final hasRCE = findings.any((f) =>
    f['text'].toString().toLowerCase().contains('remote code execution') ||
        f['text'].toString().toLowerCase().contains('rce'));

    final hasAuthBypass = findings.any((f) =>
    f['text'].toString().toLowerCase().contains('authentication bypass') ||
        f['text'].toString().toLowerCase().contains('auth bypass'));

    final hasBufferOverflow = findings.any((f) =>
        f['text'].toString().toLowerCase().contains('buffer overflow'));

    final hasHardcodedCreds = findings.any((f) =>
        f['text'].toString().toLowerCase().contains('hardcoded'));

    // Build scenario descriptions
    if (hasDefaultCreds || hasHardcodedCreds) {
      scenarios.add('- Default/hardcoded credentials provide immediate unauthorized access to critical systems');
    }

    if (hasRCE) {
      scenarios.add('- Remote code execution vulnerabilities enable attackers to take complete control of affected systems');
    }

    if (hasAuthBypass) {
      scenarios.add('- Authentication bypass vulnerabilities allow attackers to circumvent security controls');
    }

    if (hasBufferOverflow) {
      scenarios.add('- Buffer overflow vulnerabilities can be exploited for system compromise and privilege escalation');
    }

    if (hasEOL) {
      scenarios.add('- End-of-life systems lack vendor support and security patches, creating persistent exposure to known exploits');
    }

    if (criticalCount > 5) {
      scenarios.add('- Multiple critical attack paths indicate systemic security gaps requiring immediate organizational response');
    }

    if (highCount > 10) {
      scenarios.add('- Large number of high-severity findings suggests inadequate security controls and monitoring');
    }

    // Add default if no specific scenarios identified
    if (scenarios.isEmpty) {
      return '- Standard penetration testing attack vectors were evaluated against the target infrastructure';
    }

    return scenarios.join('\n');
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
                    'AI Executive Summary Generator',
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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                  border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Make sure to fill in Company Name, Start Date, and End Date in the Report tab first.',
                        style: TextStyle(color: AppTheme.textPrimary, fontSize: AppTheme.fontSizeBody),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _generateSummary,
                  icon: _isGenerating
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Icon(Icons.auto_awesome),
                  label: Text(_isGenerating ? 'Generating...' : 'Generate Summary'),
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
                    hintText: 'AI-generated summary will appear here...',
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
