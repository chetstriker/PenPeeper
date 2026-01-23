import 'dart:convert';
import 'dart:math';
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

class AiConclusionDialog extends StatefulWidget {
  final int projectId;

  const AiConclusionDialog({
    super.key,
    required this.projectId,
  });

  @override
  State<AiConclusionDialog> createState() => _AiConclusionDialogState();
}

class _AiConclusionDialogState extends State<AiConclusionDialog> {
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

  Future<void> _generateConclusion() async {
    setState(() {
      _isGenerating = true;
      _resultController.text = 'Generating conclusion...';
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

      // DEDUPLICATION & CATEGORIZATION
      final Map<String, Map<String, dynamic>> uniqueRecommendations = {};
      final severityCounts = <String, int>{};
      final categoryCounts = <String, int>{};

      for (var finding in findings) {
        final severity = (finding['cvss_severity'] ?? 'Unknown').toString().toUpperCase();
        var category = (finding['category'] ?? '').toString();
        final subcategory = (finding['subcategory'] ?? '').toString();
        final recommendation = finding['recommendation'] ?? '';

        // Parse Quill JSON to extract plain text
        String plainText = recommendation;
        try {
          final parsed = json.decode(recommendation);
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

        // Skip empty recommendations
        if (plainText.isEmpty || plainText == '\n') continue;

        // Auto-categorize if empty
        if (category.isEmpty) {
          category = _autoCategorizeRecommendation(plainText);
        }

        // Create unique key based on severity and first 150 chars of recommendation
        final textKey = plainText.length > 150
            ? plainText.substring(0, 150).trim()
            : plainText.trim();
        final key = '${severity}_$textKey';

        if (uniqueRecommendations.containsKey(key)) {
          // Duplicate found - increment count
          uniqueRecommendations[key]!['count']++;
        } else {
          // New unique recommendation
          final timeline = _determineRemediationTimeline(plainText, severity);
          uniqueRecommendations[key] = {
            'severity': severity,
            'category': category,
            'subcategory': subcategory,
            'text': plainText,
            'count': 1,
            'timeline': timeline,
          };
        }

        // Count severities (all instances)
        severityCounts[severity] = (severityCounts[severity] ?? 0) + 1;

        // Count categories (unique only)
        if (category.isNotEmpty && !uniqueRecommendations.containsKey(key)) {
          final catKey = subcategory.isNotEmpty ? '$category - $subcategory' : category;
          categoryCounts[catKey] = (categoryCounts[catKey] ?? 0) + 1;
        }
      }

      final uniqueCount = uniqueRecommendations.length;
      final totalInstances = findings.length;

      _debugController.text += 'Deduplicated to $uniqueCount unique recommendations (from $totalInstances total)\n\n';
      setState(() {});

      // GROUP BY TIMELINE
      final immediateActions = <Map<String, dynamic>>[];
      final shortTermActions = <Map<String, dynamic>>[];
      final longTermActions = <Map<String, dynamic>>[];

      for (var rec in uniqueRecommendations.values) {
        switch (rec['timeline']) {
          case 'Immediate':
            immediateActions.add(rec);
            break;
          case 'Short-term':
            shortTermActions.add(rec);
            break;
          case 'Long-term':
            longTermActions.add(rec);
            break;
        }
      }

      // Build categorized recommendations text
      final StringBuffer recBuffer = StringBuffer();

      if (immediateActions.isNotEmpty) {
        recBuffer.writeln('IMMEDIATE ACTIONS (0-30 days) - ${immediateActions.length} items:');
        for (var rec in immediateActions.take(10)) {
          final countPrefix = rec['count'] > 1 ? '[${rec['count']} instances] ' : '';
          final truncated = _truncateIntelligently(rec['text'], 300);
          recBuffer.writeln('- ${rec['severity']}: $countPrefix$truncated');
        }
        recBuffer.writeln();
      }

      if (shortTermActions.isNotEmpty) {
        recBuffer.writeln('SHORT-TERM ACTIONS (30-90 days) - ${shortTermActions.length} items:');
        for (var rec in shortTermActions.take(10)) {
          final countPrefix = rec['count'] > 1 ? '[${rec['count']} instances] ' : '';
          final truncated = _truncateIntelligently(rec['text'], 300);
          recBuffer.writeln('- ${rec['severity']}: $countPrefix$truncated');
        }
        recBuffer.writeln();
      }

      if (longTermActions.isNotEmpty) {
        recBuffer.writeln('LONG-TERM ACTIONS (90+ days) - ${longTermActions.length} items:');
        for (var rec in longTermActions.take(10)) {
          final countPrefix = rec['count'] > 1 ? '[${rec['count']} instances] ' : '';
          final truncated = _truncateIntelligently(rec['text'], 300);
          recBuffer.writeln('- ${rec['severity']}: $countPrefix$truncated');
        }
      }

      var recommendationsText = recBuffer.toString();

      // TOKEN MANAGEMENT
      final estimatedTokens = (recommendationsText.length / 4).round();
      if (estimatedTokens > 5000) {
        // Rebuild with smaller limits
        recBuffer.clear();

        if (immediateActions.isNotEmpty) {
          recBuffer.writeln('IMMEDIATE ACTIONS (0-30 days) - ${immediateActions.length} items:');
          for (var rec in immediateActions.take(5)) {
            final countPrefix = rec['count'] > 1 ? '[${rec['count']} instances] ' : '';
            final truncated = _truncateIntelligently(rec['text'], 200);
            recBuffer.writeln('- ${rec['severity']}: $countPrefix$truncated');
          }
          if (immediateActions.length > 5) {
            recBuffer.writeln('  ... and ${immediateActions.length - 5} more');
          }
          recBuffer.writeln();
        }

        if (shortTermActions.isNotEmpty) {
          recBuffer.writeln('SHORT-TERM ACTIONS (30-90 days) - ${shortTermActions.length} items (sample):');
          for (var rec in shortTermActions.take(3)) {
            final countPrefix = rec['count'] > 1 ? '[${rec['count']} instances] ' : '';
            final truncated = _truncateIntelligently(rec['text'], 150);
            recBuffer.writeln('- ${rec['severity']}: $countPrefix$truncated');
          }
          recBuffer.writeln();
        }

        if (longTermActions.isNotEmpty) {
          recBuffer.writeln('LONG-TERM ACTIONS (90+ days) - ${longTermActions.length} items (sample):');
          for (var rec in longTermActions.take(3)) {
            final countPrefix = rec['count'] > 1 ? '[${rec['count']} instances] ' : '';
            final truncated = _truncateIntelligently(rec['text'], 150);
            recBuffer.writeln('- ${rec['severity']}: $countPrefix$truncated');
          }
        }

        recommendationsText = recBuffer.toString();
        _debugController.text += 'Token limit exceeded - reduced recommendation details\n';
        setState(() {});
      }

      final severitySummary = severityCounts.entries.map((e) => '${e.value} ${e.key}').join(', ');
      final topCategories = categoryCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final categorySummary = topCategories.isNotEmpty
          ? topCategories.take(5).map((e) => '${e.key} (${e.value})').join(', ')
          : 'Various security vulnerabilities';
      final scanScope = scanRanges.isNotEmpty ? scanRanges.join(', ') : 'Not specified';

      // Calculate remediation metrics
      final remediationMetrics = _calculateRemediationMetrics(
        immediateActions.length,
        shortTermActions.length,
        longTermActions.length,
        severityCounts,
      );

      final prompt = '''You are a cybersecurity expert writing content for the Conclusion section of a penetration testing report.

IMPORTANT: The section already has a header titled "Conclusion". Do NOT start your response with "Conclusion" as a title or heading. Start directly with the first paragraph of content.

Client: $companyName
Assessment Period: $startDate to $endDate
Scan Scope (IP Addresses/CIDR Ranges): $scanScope
Total Findings: $totalInstances (${uniqueCount} unique vulnerabilities)
Severity Breakdown: $severitySummary
Top Vulnerability Categories: $categorySummary

REMEDIATION SUMMARY:
$remediationMetrics

Remediation Recommendations (Organized by Timeline):
$recommendationsText

Write a professional 2-3 paragraph conclusion that:
1. Summarizes the overall security posture and key findings from the assessment
2. Emphasizes the critical importance of implementing recommended remediations in the specified timelines
3. Highlights the immediate actions that require urgent attention (0-30 days)
4. Acknowledges the short-term and long-term strategic improvements needed
5. Provides forward-looking guidance on maintaining security posture and continuous improvement
6. Concludes with a professional closing statement about the importance of ongoing security practices and regular assessments

WRITING GUIDELINES:
- Use professional, authoritative language appropriate for a formal penetration testing report
- Focus on actionable next steps with specific timelines
- Emphasize the business risk of delayed remediation
- Use the company name "$companyName" directly - avoid phrases like "the organization"
- Balance urgency with constructive, solution-focused language
- Mention the need for follow-up assessments after remediation
- Include reference to establishing a vulnerability management program if high finding count

TONE: Professional, authoritative, solution-focused, emphasizing both urgency and achievability of remediations.''';

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

      final conclusion = response.content;

      _debugController.text += '=== RESPONSE FROM LLM ===\n$conclusion\n';

      setState(() {
        _resultController.text = conclusion;
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

  // Helper method: Auto-categorize recommendations
  String _autoCategorizeRecommendation(String text) {
    final lowerText = text.toLowerCase();

    if (lowerText.contains('upgrade') || lowerText.contains('update') || lowerText.contains('patch')) {
      return 'Software Updates';
    } else if (lowerText.contains('segment') || lowerText.contains('network isolation')) {
      return 'Network Segmentation';
    } else if (lowerText.contains('budget') || lowerText.contains('replace')) {
      return 'Hardware Replacement';
    } else if (lowerText.contains('credential') || lowerText.contains('password')) {
      return 'Access Control';
    } else if (lowerText.contains('disable') || lowerText.contains('remove')) {
      return 'Service Hardening';
    } else if (lowerText.contains('monitor') || lowerText.contains('inventory')) {
      return 'Asset Management';
    } else if (lowerText.contains('configure') || lowerText.contains('setting')) {
      return 'Configuration Management';
    } else if (lowerText.contains('firewall') || lowerText.contains('acl') || lowerText.contains('restrict')) {
      return 'Network Security';
    } else {
      return 'General Security';
    }
  }

  // Helper method: Determine remediation timeline
  String _determineRemediationTimeline(String text, String severity) {
    final lowerText = text.toLowerCase();

    // Immediate (0-30 days) - Critical/High severity + quick actions
    if (severity == 'CRITICAL' && (
        lowerText.contains('disable') ||
            lowerText.contains('remove') ||
            lowerText.contains('patch') ||
            lowerText.contains('credential')
    )) {
      return 'Immediate';
    }

    // Long-term (90+ days) - Budget/replacement items
    if (lowerText.contains('budget') ||
        lowerText.contains('replace') ||
        lowerText.contains('upgrade to')) {
      return 'Long-term';
    }

    // Short-term (30-90 days) - Everything else
    return 'Short-term';
  }

  // Helper method: Intelligent truncation
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

  // Helper method: Calculate remediation metrics
  String _calculateRemediationMetrics(
      int immediateCount,
      int shortTermCount,
      int longTermCount,
      Map<String, int> severityCounts,
      ) {
    final criticalCount = severityCounts['CRITICAL'] ?? 0;
    final highCount = severityCounts['HIGH'] ?? 0;

    final StringBuffer metrics = StringBuffer();

    metrics.writeln('Remediation Timeline Analysis:');
    metrics.writeln('- Immediate Actions (0-30 days): $immediateCount remediations');
    metrics.writeln('- Short-term Actions (30-90 days): $shortTermCount remediations');
    metrics.writeln('- Long-term Strategic Actions (90+ days): $longTermCount remediations');
    metrics.writeln();

    if (criticalCount > 0) {
      metrics.writeln('URGENT: $criticalCount CRITICAL vulnerabilities require immediate attention to prevent potential system compromise.');
    }

    if (highCount > 10) {
      metrics.writeln('IMPORTANT: High number ($highCount) of HIGH severity findings indicates systemic security gaps requiring comprehensive remediation program.');
    }

    final totalCriticalAndHigh = criticalCount + highCount;
    if (totalCriticalAndHigh > 0) {
      final estimatedEffort = _estimateRemediationEffort(totalCriticalAndHigh);
      metrics.writeln('Estimated Remediation Effort: $estimatedEffort');
    }

    return metrics.toString();
  }

  String _estimateRemediationEffort(int criticalAndHighCount) {
    if (criticalAndHighCount < 5) {
      return '1-2 weeks for critical items with dedicated resources';
    } else if (criticalAndHighCount < 15) {
      return '4-6 weeks for comprehensive remediation with adequate staffing';
    } else if (criticalAndHighCount < 30) {
      return '2-3 months for full remediation; recommend phased approach';
    } else {
      return '3-6 months for complete remediation; recommend establishing dedicated security program';
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
                    'AI Conclusion Generator',
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
                  onPressed: _isGenerating ? null : _generateConclusion,
                  icon: _isGenerating
                      ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                      : Icon(Icons.auto_awesome),
                  label: Text(_isGenerating ? 'Generating...' : 'Generate Conclusion'),
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
                    hintText: 'AI-generated conclusion will appear here...',
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