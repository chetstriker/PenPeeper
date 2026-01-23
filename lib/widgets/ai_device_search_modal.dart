import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:penpeeper/models/llm_settings.dart';
import 'package:penpeeper/services/ai_device_search_service.dart';
import 'package:penpeeper/services/unified_llm_client.dart';
import 'package:penpeeper/repositories/device_repository.dart';
import 'package:penpeeper/repositories/findings_repository.dart';
import 'package:penpeeper/repositories/vulnerability_repository.dart';
import 'package:penpeeper/services/findings/finding_creation_service.dart';
import 'package:penpeeper/theme_config.dart';
import 'package:penpeeper/widgets/common/decorated_dialog_title.dart';

class AIDeviceSearchModal extends StatefulWidget {
  final int projectId;
  final LLMSettings llmSettings;
  final VoidCallback onFindingAdded;

  const AIDeviceSearchModal({
    super.key,
    required this.projectId,
    required this.llmSettings,
    required this.onFindingAdded,
  });

  @override
  State<AIDeviceSearchModal> createState() => _AIDeviceSearchModalState();
}

class _AIDeviceSearchModalState extends State<AIDeviceSearchModal> {
  final _aiService = AIDeviceSearchService();
  final _deviceRepo = DeviceRepository();
  final _findingsRepo = FindingsRepository();
  final _vulnRepo = VulnerabilityRepository();
  final _creationService = FindingCreationService();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _devices = [];
  List<Map<String, dynamic>> _filteredDevices = [];
  Map<String, dynamic>? _selectedDevice;
  String _minConfidence = 'Medium';
  String _minSeverity = 'Medium';
  bool _isSearching = false;
  List<Map<String, dynamic>> _results = [];
  Set<String> _addedVulnKeys = {};
  List<Map<String, dynamic>> _existingFindings = [];
  String? _statusMessage;
  LLMUsageMetrics? _tokenUsage;

  // New options for two-phase search
  bool _optimizeForSmallLLM = false;
  bool _enableEnhancement = true;
  SearchProgress? _currentProgress;

  @override
  void initState() {
    super.initState();
    _loadDevices();
    _loadExistingFindings();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDevices() async {
    final deviceList = await _deviceRepo.getDevices(widget.projectId);
    setState(() {
      _devices = deviceList.where((d) => d.id != 0).map((d) => {
        'id': d.id,
        'name': d.name,
        'ip_address': d.ipAddress,
      }).toList();
      _filteredDevices = _devices;
    });
  }

  Future<void> _loadExistingFindings() async {
    final findings = await _findingsRepo.getFlaggedFindings(widget.projectId);
    _existingFindings = findings.map((f) => {
      'device_id': f.deviceId,
      'cve_id': f.cveId,
      'comment': f.comment,
    }).toList();
  }

  void _filterDevices(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredDevices = _devices;
      } else {
        _filteredDevices = _devices.where((d) {
          final name = (d['name'] ?? '').toString().toLowerCase();
          final ip = (d['ip_address'] ?? '').toString().toLowerCase();
          final q = query.toLowerCase();
          return name.contains(q) || ip.contains(q);
        }).toList();
      }
    });
  }

  Future<void> _searchSingleDevice() async {
    if (_selectedDevice == null) return;
    setState(() {
      _isSearching = true;
      _results = [];
      _statusMessage = null;
      _tokenUsage = null;
      _currentProgress = null;
    });

    try {
      debugPrint('=== AI Device Search: Single Device (Two-Phase) ===');
      debugPrint('Device ID: ${_selectedDevice!['id']}');
      debugPrint('Device Name: ${_selectedDevice!['name']}');
      debugPrint('Min Confidence: $_minConfidence');
      debugPrint('Min Severity: $_minSeverity');
      debugPrint('Optimize for Small LLM: $_optimizeForSmallLLM');
      debugPrint('Enable Enhancement (Phase 2): $_enableEnhancement');
      debugPrint('LLM Provider: ${widget.llmSettings.provider.name}');
      debugPrint('LLM Model: ${widget.llmSettings.modelName}');

      final result = await _aiService.searchDeviceWithAI(
        deviceId: _selectedDevice!['id'],
        projectId: widget.projectId,
        settings: widget.llmSettings,
        minConfidence: _minConfidence,
        minSeverity: _minSeverity,
        options: AISearchOptions(
          optimizeForSmallLLM: _optimizeForSmallLLM,
          enableTwoPhaseEnhancement: _enableEnhancement,
        ),
        onProgress: (progress) {
          setState(() {
            _currentProgress = progress;
          });
        },
      );

      debugPrint('LLM Response received:');
      debugPrint('Device ID: ${result['device_id']}');
      if (result.containsKey('error')) {
        debugPrint('ERROR in result: ${result['error']}');
      }
      debugPrint('Vulnerabilities found: ${(result['vulnerabilities'] as List?)?.length ?? 0}');
      if (result['vulnerabilities'] != null) {
        for (var i = 0; i < (result['vulnerabilities'] as List).length; i++) {
          final vuln = result['vulnerabilities'][i];
          debugPrint('  [$i] ${vuln['problem']} - ${vuln['severity']} (${vuln['confidence']})');
        }
      }

      if ((result['vulnerabilities'] as List?)?.isEmpty ?? true) {
        debugPrint('\nWARNING: No vulnerabilities found!');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No vulnerabilities found meeting the specified criteria.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 5),
            ),
          );
        }
      }

      debugPrint('=== End AI Device Search ===');

      setState(() {
        _results = [result];
        _tokenUsage = _aiService.cumulativeUsage;
        _currentProgress = null;
      });
    } catch (e, stack) {
      debugPrint('=== AI Device Search ERROR ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stack');
      debugPrint('=== End Error ===');
      setState(() {
        _statusMessage = 'Error: $e';
        _currentProgress = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _searchAllDevices() async {
    setState(() {
      _isSearching = true;
      _results = [];
      _statusMessage = null;
      _tokenUsage = null;
      _currentProgress = null;
    });

    try {
      debugPrint('=== AI Device Search: All Devices (Two-Phase) ===');
      debugPrint('Total devices: ${_devices.length}');
      debugPrint('Min Confidence: $_minConfidence');
      debugPrint('Min Severity: $_minSeverity');
      debugPrint('Optimize for Small LLM: $_optimizeForSmallLLM');
      debugPrint('Enable Enhancement: $_enableEnhancement');

      for (var i = 0; i < _devices.length; i++) {
        final device = _devices[i];
        debugPrint('\n--- Processing device ${i + 1}/${_devices.length} ---');
        debugPrint('Device ID: ${device['id']}, Name: ${device['name']}');

        setState(() {
          _currentProgress = SearchProgress(
            currentPhase: 1,
            totalVulnerabilities: 0,
            enhancedCount: 0,
            currentOperation: 'Scanning device ${i + 1}/${_devices.length}: ${device['name']}',
          );
        });

        try {
          final result = await _aiService.searchDeviceWithAI(
            deviceId: device['id'],
            projectId: widget.projectId,
            settings: widget.llmSettings,
            minConfidence: _minConfidence,
            minSeverity: _minSeverity,
            options: AISearchOptions(
              optimizeForSmallLLM: _optimizeForSmallLLM,
              enableTwoPhaseEnhancement: _enableEnhancement,
            ),
            onProgress: (progress) {
              setState(() {
                _currentProgress = SearchProgress(
                  currentPhase: progress.currentPhase,
                  totalVulnerabilities: progress.totalVulnerabilities,
                  enhancedCount: progress.enhancedCount,
                  currentOperation: 'Device ${i + 1}/${_devices.length}: ${progress.currentOperation}',
                );
              });
            },
          );
          debugPrint('Vulnerabilities found: ${(result['vulnerabilities'] as List?)?.length ?? 0}');
          setState(() {
            _results = [..._results, result];
            _tokenUsage = _aiService.cumulativeUsage;
          });
        } catch (e) {
          debugPrint('Error processing device ${device['id']}: $e');
        }
      }

      debugPrint('\n=== All Devices Search Complete ===');
      debugPrint('Total results: ${_results.length}');
      final totalVulns = _results.fold<int>(0, (sum, r) => sum + ((r['vulnerabilities'] as List?)?.length ?? 0));
      debugPrint('Total vulnerabilities: $totalVulns');
      debugPrint('=== End AI Device Search ===');
    } catch (e, stack) {
      debugPrint('=== AI Device Search ERROR ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stack');
      debugPrint('=== End Error ===');
      setState(() => _statusMessage = 'Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() {
        _isSearching = false;
        _currentProgress = null;
      });
    }
  }

  Future<void> _addToFlaggedFindings(Map<String, dynamic> vuln, int deviceId, int vulnIndex) async {
    final device = _devices.firstWhere((d) => d['id'] == deviceId);
    final deviceName = device['name'] ?? 'Unknown';
    final ipAddress = device['ip_address'] ?? 'Unknown';

    // Build combined evidence (no more verification_tips)
    final evidenceParts = <String>[];
    if (vuln['confidence'] != null && (vuln['confidence'] as String).isNotEmpty) {
      evidenceParts.add('Confidence: ${vuln['confidence']}');
    }
    if (vuln['evidence'] != null && (vuln['evidence'] as String).isNotEmpty) {
      evidenceParts.add(vuln['evidence'] as String);
    }
    final combinedEvidence = evidenceParts.join('\n\n');

    final hasCve = vuln['cve'] != null && (vuln['cve'] as String).isNotEmpty;

    if (hasCve) {
      await _createCveFinding(vuln, deviceId, deviceName, ipAddress, combinedEvidence);
    } else {
      await _createManualFinding(vuln, deviceId, deviceName, ipAddress, combinedEvidence);
    }

    widget.onFindingAdded();
    setState(() {
      _addedVulnKeys.add('$deviceId-$vulnIndex');
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Finding added successfully'), backgroundColor: Colors.green),
      );
    }
  }

  Future<void> _createCveFinding(Map<String, dynamic> vuln, int deviceId, String deviceName, String ipAddress, String evidence) async {
    final cveData = {
      'cveId': vuln['cve'],
      'description': vuln['description'],
      'cvssScore': _severityToScore(vuln['severity']),
      'severity': vuln['severity'],
    };

    final findingId = await _creationService.createCveFinding(
      deviceId: deviceId,
      deviceName: deviceName,
      ipAddress: ipAddress,
      projectId: widget.projectId,
      cveData: cveData,
    );

    await _findingsRepo.updateFlaggedFindingEvidence(findingId, _toQuillDelta(evidence));
    await _findingsRepo.updateFlaggedFindingRecommendation(findingId, _toQuillDelta(vuln['recommendation'] ?? ''));
    await _findingsRepo.updateFlaggedFindingType(findingId, 'AI');

    await _findingsRepo.updateFlaggedFindingCvss(
      findingId,
      attackVector: _normalizeValue(vuln['attack_vector']),
      attackComplexity: _normalizeValue(vuln['attack_complexity']),
      privilegesRequired: _normalizeValue(vuln['privileges_required']),
      userInteraction: _normalizeValue(vuln['user_interaction']),
      scope: _normalizeValue(vuln['scope']),
      confidentialityImpact: _normalizeValue(vuln['confidentiality_impact']),
      integrityImpact: _normalizeValue(vuln['integrity_impact']),
      availabilityImpact: _normalizeValue(vuln['availability_impact']),
      cvssBaseScore: _severityToScore(vuln['severity']),
      cvssSeverity: (vuln['severity'] ?? 'MEDIUM').toString().toUpperCase(),
    );
  }

  Future<void> _createManualFinding(Map<String, dynamic> vuln, int deviceId, String deviceName, String ipAddress, String evidence) async {
    final flagData = {
      'type': 'AI',
      'comment': _toQuillDelta(vuln['description'] ?? ''),
      'evidence': _toQuillDelta(evidence),
      'recommendation': _toQuillDelta(vuln['recommendation'] ?? ''),
    };

    final findingId = await _creationService.createManualFinding(
      deviceId: deviceId,
      deviceName: deviceName,
      ipAddress: ipAddress,
      flagData: flagData,
    );

    await _findingsRepo.updateFlaggedFindingType(findingId, 'AI');

    await _findingsRepo.updateFlaggedFindingCvss(
      findingId,
      attackVector: _normalizeValue(vuln['attack_vector']) ?? 'NETWORK',
      attackComplexity: _normalizeValue(vuln['attack_complexity']) ?? 'LOW',
      privilegesRequired: _normalizeValue(vuln['privileges_required']) ?? 'NONE',
      userInteraction: _normalizeValue(vuln['user_interaction']) ?? 'NONE',
      scope: _normalizeValue(vuln['scope']) ?? 'UNCHANGED',
      confidentialityImpact: _normalizeValue(vuln['confidentiality_impact']) ?? _severityToImpact(vuln['severity']),
      integrityImpact: _normalizeValue(vuln['integrity_impact']) ?? _severityToImpact(vuln['severity']),
      availabilityImpact: _normalizeValue(vuln['availability_impact']) ?? _severityToImpact(vuln['severity']),
      cvssBaseScore: _severityToScore(vuln['severity']),
      cvssSeverity: (vuln['severity'] ?? 'MEDIUM').toString().toUpperCase(),
    );
  }

  String? _normalizeValue(dynamic value) {
    if (value == null) return null;
    final str = value.toString().toUpperCase();
    return str.isEmpty ? null : str;
  }

  String _toQuillDelta(String text) {
    if (text.isEmpty) return jsonEncode([{"insert": "\n"}]);
    return jsonEncode([{"insert": "$text\n"}]);
  }

  double _severityToScore(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return 9.0;
      case 'high':
        return 7.5;
      case 'medium':
        return 5.0;
      case 'low':
        return 3.0;
      default:
        return 5.0;
    }
  }

  String _severityToImpact(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
      case 'high':
        return 'HIGH';
      case 'medium':
        return 'LOW';
      case 'low':
        return 'NONE';
      default:
        return 'LOW';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceColor,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
              children: [
                const Expanded(child: DecoratedDialogTitle('Search Devices With AI')),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  tooltip: 'Close',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Two-Phase AI Search: Phase 1 discovers vulnerabilities, Phase 2 enhances each with detailed evidence and recommendations.',
                      style: TextStyle(color: AppTheme.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Device and filter dropdowns (first row)
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Device', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      DropdownButtonHideUnderline(
                        child: DropdownButton2<Map<String, dynamic>>(
                          isExpanded: true,
                          hint: Text('Select Device', style: TextStyle(color: AppTheme.textSecondary)),
                          value: _selectedDevice,
                          items: _filteredDevices.map((device) {
                            return DropdownMenuItem(
                              value: device,
                              child: Text(
                                '${device['name']} (${device['ip_address']})',
                                style: TextStyle(color: AppTheme.textPrimary),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) => setState(() => _selectedDevice = value),
                          buttonStyleData: ButtonStyleData(
                            height: 50,
                            decoration: BoxDecoration(
                              border: Border.all(color: AppTheme.borderPrimary),
                              borderRadius: BorderRadius.circular(8),
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
                            searchController: _searchController,
                            searchInnerWidgetHeight: 50,
                            searchInnerWidget: Container(
                              padding: const EdgeInsets.all(8),
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText: 'Search devices...',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onChanged: _filterDevices,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Min Confidence', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      DropdownButtonHideUnderline(
                        child: DropdownButton2<String>(
                          isExpanded: true,
                          value: _minConfidence,
                          items: ['Low', 'Medium', 'High', 'Confirmed'].map((conf) {
                            return DropdownMenuItem(
                              value: conf,
                              child: Text(conf, style: TextStyle(color: AppTheme.textPrimary)),
                            );
                          }).toList(),
                          onChanged: (value) => setState(() => _minConfidence = value!),
                          buttonStyleData: ButtonStyleData(
                            height: 50,
                            decoration: BoxDecoration(
                              border: Border.all(color: AppTheme.borderPrimary),
                              borderRadius: BorderRadius.circular(8),
                              color: AppTheme.surfaceColor,
                            ),
                          ),
                          dropdownStyleData: DropdownStyleData(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: AppTheme.surfaceColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Min Severity', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      DropdownButtonHideUnderline(
                        child: DropdownButton2<String>(
                          isExpanded: true,
                          value: _minSeverity,
                          items: ['Low', 'Medium', 'High', 'Critical'].map((sev) {
                            return DropdownMenuItem(
                              value: sev,
                              child: Text(sev, style: TextStyle(color: AppTheme.textPrimary)),
                            );
                          }).toList(),
                          onChanged: (value) => setState(() => _minSeverity = value!),
                          buttonStyleData: ButtonStyleData(
                            height: 50,
                            decoration: BoxDecoration(
                              border: Border.all(color: AppTheme.borderPrimary),
                              borderRadius: BorderRadius.circular(8),
                              color: AppTheme.surfaceColor,
                            ),
                          ),
                          dropdownStyleData: DropdownStyleData(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: AppTheme.surfaceColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // New options row with checkboxes
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderPrimary),
              ),
              child: Row(
                children: [
                  // Enable Enhancement checkbox
                  Expanded(
                    child: Row(
                      children: [
                        Checkbox(
                          value: _enableEnhancement,
                          onChanged: (value) => setState(() => _enableEnhancement = value ?? true),
                          activeColor: AppTheme.primaryColor,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Enable Phase 2 Enhancement',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'Generate detailed evidence & recommendations (uses more tokens)',
                                style: TextStyle(
                                  color: AppTheme.textTertiary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 24),

                  // Optimize for Small LLM checkbox
                  Expanded(
                    child: Row(
                      children: [
                        Checkbox(
                          value: _optimizeForSmallLLM,
                          onChanged: (value) => setState(() => _optimizeForSmallLLM = value ?? false),
                          activeColor: AppTheme.warningColor,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Optimize for Smaller LLMs (<13B)',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                'Reduces prompt size and limits output (for 7B-13B models)',
                                style: TextStyle(
                                  color: AppTheme.textTertiary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Search buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isSearching ? null : _searchSingleDevice,
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Search Selected'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isSearching ? null : _searchAllDevices,
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Search All'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Status and progress
            _buildStatusBar(),

            // Progress indicator during search
            if (_isSearching && _currentProgress != null)
              _buildProgressIndicator(),

            // Results or loading
            if (_isSearching && _currentProgress == null)
              const Center(child: CircularProgressIndicator())
            else if (_results.isNotEmpty)
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.4,
                child: _buildResultsTable(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    final progress = _currentProgress!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primaryColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Phase ${progress.currentPhase}: ${progress.currentPhase == 1 ? "Discovery" : "Enhancement"}',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            progress.currentOperation,
            style: TextStyle(color: AppTheme.textPrimary),
          ),
          if (progress.currentPhase == 2 && progress.totalVulnerabilities > 0) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress.enhancedCount / progress.totalVulnerabilities,
              backgroundColor: AppTheme.borderPrimary,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
            const SizedBox(height: 4),
            Text(
              'Enhanced ${progress.enhancedCount} of ${progress.totalVulnerabilities} vulnerabilities',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResultsTable() {
    final allVulns = <Map<String, dynamic>>[];
    var vulnIndex = 0;
    for (final result in _results) {
      final deviceId = result['device_id'];
      final vulns = result['vulnerabilities'] as List? ?? [];
      for (final vuln in vulns) {
        final vulnKey = '$deviceId-$vulnIndex';
        if (!_addedVulnKeys.contains(vulnKey) && !_isDuplicate(vuln, deviceId)) {
          allVulns.add({...vuln as Map<String, dynamic>, 'device_id': deviceId, 'vuln_index': vulnIndex});
        }
        vulnIndex++;
      }
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.borderPrimary),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text('Device', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
                Expanded(flex: 2, child: Text('Problem', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
                Expanded(flex: 1, child: Text('CVE', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
                Expanded(flex: 1, child: Text('Severity', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
                Expanded(flex: 1, child: Text('Confidence', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
                Expanded(flex: 1, child: Text('Action', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary))),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: allVulns.length,
              itemBuilder: (context, index) {
                final vuln = allVulns[index];
                final deviceId = vuln['device_id'];
                final device = _devices.firstWhere((d) => d['id'] == deviceId);

                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: AppTheme.borderPrimary)),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text('${device['name']} (${device['ip_address']})', style: TextStyle(color: AppTheme.textPrimary))),
                      Expanded(
                        flex: 2,
                        child: Tooltip(
                          message: vuln['description'] ?? '',
                          child: Text(
                            vuln['problem'] ?? '',
                            style: TextStyle(color: AppTheme.textPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      Expanded(flex: 1, child: Text(vuln['cve'] ?? '', style: TextStyle(color: AppTheme.textPrimary))),
                      Expanded(flex: 1, child: _buildSeverityBadge(vuln['severity'] ?? 'Medium')),
                      Expanded(flex: 1, child: Text(vuln['confidence'] ?? '', style: TextStyle(color: AppTheme.textPrimary))),
                      Expanded(
                        flex: 1,
                        child: Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _addToFlaggedFindings(vuln, deviceId, vuln['vuln_index']),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                ),
                                child: const Text('Add', style: TextStyle(fontSize: 12)),
                              ),
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              icon: Icon(Icons.info_outline, size: 18, color: AppTheme.textSecondary),
                              tooltip: 'View Details',
                              onPressed: () => _showVulnDetails(vuln),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showVulnDetails(Map<String, dynamic> vuln) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: AppTheme.surfaceColor,
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        vuln['problem'] ?? 'Vulnerability Details',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _buildDetailSection('CVE', vuln['cve']),
                _buildDetailSection('Severity', vuln['severity']),
                _buildDetailSection('Confidence', vuln['confidence']),
                _buildDetailSection('Description', vuln['description']),
                _buildDetailSection('Evidence', vuln['evidence']),
                _buildDetailSection('Recommendation', vuln['recommendation']),

                const SizedBox(height: 16),
                Text(
                  'CVSS Metrics',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _buildCvssChip('AV', vuln['attack_vector']),
                    _buildCvssChip('AC', vuln['attack_complexity']),
                    _buildCvssChip('PR', vuln['privileges_required']),
                    _buildCvssChip('UI', vuln['user_interaction']),
                    _buildCvssChip('S', vuln['scope']),
                    _buildCvssChip('C', vuln['confidentiality_impact']),
                    _buildCvssChip('I', vuln['integrity_impact']),
                    _buildCvssChip('A', vuln['availability_impact']),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailSection(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: TextStyle(color: AppTheme.textPrimary),
          ),
        ],
      ),
    );
  }

  Widget _buildCvssChip(String label, String? value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$label:${value ?? 'N/A'}',
        style: TextStyle(
          fontSize: 12,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }

  Widget _buildSeverityBadge(String severity) {
    Color color;
    switch (severity.toLowerCase()) {
      case 'critical':
        color = Colors.purple;
        break;
      case 'high':
        color = Colors.red;
        break;
      case 'medium':
        color = Colors.orange;
        break;
      case 'low':
        color = Colors.yellow;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color),
      ),
      child: Text(
        severity,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildStatusBar() {
    if (_statusMessage == null && _tokenUsage == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _statusMessage != null ? AppTheme.errorColor.withOpacity(0.1) : AppTheme.successColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
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
              _statusMessage ?? 'Total Tokens: ${_tokenUsage?.totalTokens ?? 0} (Prompt: ${_tokenUsage?.promptTokens ?? 0}, Response: ${_tokenUsage?.completionTokens ?? 0})',
              style: TextStyle(
                color: _statusMessage != null ? AppTheme.errorColor : AppTheme.successColor,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isDuplicate(Map<String, dynamic> vuln, int deviceId) {
    final cve = vuln['cve']?.toString().trim() ?? '';
    final problem = vuln['problem']?.toString().trim().toLowerCase() ?? '';

    for (final finding in _existingFindings) {
      if (finding['device_id'] != deviceId) continue;

      final existingCve = finding['cve_id']?.toString().trim() ?? '';
      if (cve.isNotEmpty && existingCve.isNotEmpty && cve == existingCve) {
        return true;
      }

      final existingComment = finding['comment']?.toString().trim().toLowerCase() ?? '';
      if (problem.isNotEmpty && existingComment.contains(problem)) {
        return true;
      }
    }
    return false;
  }
}