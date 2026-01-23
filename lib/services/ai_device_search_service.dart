import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:penpeeper/models/llm_settings.dart';
import 'package:penpeeper/repositories/device_repository.dart';
import 'package:penpeeper/repositories/metadata_repository.dart';
import 'package:penpeeper/repositories/scan_repository.dart';
import 'package:penpeeper/services/unified_llm_client.dart';
import 'package:penpeeper/utils/platform/platform_utils.dart';
import 'package:http/http.dart' as http;

/// Configuration options for AI device search
class AISearchOptions {
  final bool optimizeForSmallLLM;
  final bool enableTwoPhaseEnhancement;

  const AISearchOptions({
    this.optimizeForSmallLLM = false,
    this.enableTwoPhaseEnhancement = true,
  });
}

/// Tracks progress during two-phase search
class SearchProgress {
  final int currentPhase; // 1 = discovery, 2 = enhancement
  final int totalVulnerabilities;
  final int enhancedCount;
  final String currentOperation;

  const SearchProgress({
    required this.currentPhase,
    required this.totalVulnerabilities,
    required this.enhancedCount,
    required this.currentOperation,
  });
}

class AIDeviceSearchService {
  final _deviceRepo = DeviceRepository();
  final _metadataRepo = MetadataRepository();
  final _scanRepo = ScanRepository();

  LLMUsageMetrics? lastUsage;
  int _totalPromptTokens = 0;
  int _totalCompletionTokens = 0;

  /// Get cumulative token usage across all phases
  LLMUsageMetrics? get cumulativeUsage {
    if (_totalPromptTokens == 0 && _totalCompletionTokens == 0) return null;
    return LLMUsageMetrics(
      promptTokens: _totalPromptTokens,
      completionTokens: _totalCompletionTokens,
      totalTokens: _totalPromptTokens + _totalCompletionTokens,
    );
  }

  /// Two-phase search: Discovery + Enhancement
  ///
  /// Phase 1: Quick discovery of vulnerabilities with basic info
  /// Phase 2: Detailed enhancement of evidence and recommendations for each
  Future<Map<String, dynamic>> searchDeviceWithAI({
    required int deviceId,
    required int projectId,
    required LLMSettings settings,
    required String minConfidence,
    required String minSeverity,
    AISearchOptions options = const AISearchOptions(),
    Function(SearchProgress)? onProgress,
  }) async {
    // Reset cumulative usage
    _totalPromptTokens = 0;
    _totalCompletionTokens = 0;

    debugPrint('\n>>> [Phase 1] Gathering device data for device $deviceId...');
    final deviceData = await _gatherDeviceData(deviceId, projectId);
    debugPrint('Device data gathered:');
    debugPrint('  - Device: ${deviceData['device'] != null ? 'YES' : 'NO'}');
    debugPrint('  - Ports: ${(deviceData['ports'] as List?)?.length ?? 0}');
    debugPrint('  - Scripts: ${(deviceData['scripts'] as List?)?.length ?? 0}');
    debugPrint('  - Scans: ${(deviceData['scans'] as List?)?.length ?? 0}');

    // =========================================================================
    // PHASE 1: DISCOVERY
    // =========================================================================
    debugPrint('\n>>> [Phase 1] Building discovery prompt...');
    onProgress?.call(SearchProgress(
      currentPhase: 1,
      totalVulnerabilities: 0,
      enhancedCount: 0,
      currentOperation: 'Discovering vulnerabilities...',
    ));

    final discoveryPrompt = _buildDiscoveryPrompt(
      deviceData,
      minConfidence,
      minSeverity,
      optimizeForSmallLLM: options.optimizeForSmallLLM,
    );
    debugPrint('Discovery prompt length: ${discoveryPrompt.length} characters');
    debugPrint('\n=== DISCOVERY PROMPT ===\n$discoveryPrompt\n=== END PROMPT ===\n');

    debugPrint('\n>>> [Phase 1] Sending discovery request to LLM (${settings.provider.name})...');
    final discoveryResponse = await UnifiedLLMClient.sendRequest(
      config: LLMRequestConfig(
        provider: settings.provider.name,
        modelName: settings.modelName,
        apiKey: settings.apiKey,
        baseUrl: settings.baseUrl,
        temperature: settings.temperature,
        maxTokens: options.optimizeForSmallLLM ? 2000 : settings.maxTokens,
        timeoutSeconds: settings.timeoutSeconds,
      ),
      prompt: discoveryPrompt,
    );

    if (!discoveryResponse.success) {
      throw Exception(discoveryResponse.userFriendlyError);
    }

    // Track usage
    if (discoveryResponse.usage != null) {
      _totalPromptTokens += discoveryResponse.usage!.promptTokens;
      _totalCompletionTokens += discoveryResponse.usage!.completionTokens;
    }
    lastUsage = discoveryResponse.usage;

    debugPrint('Discovery response length: ${discoveryResponse.content.length} characters');
    if (discoveryResponse.usage != null) {
      debugPrint('Phase 1 tokens: ${discoveryResponse.usage}');
    }

    debugPrint('\n>>> [Phase 1] Parsing discovery response...');
    var result = _parseResponse(discoveryResponse.content, deviceId);
    final vulnerabilities = result['vulnerabilities'] as List? ?? [];
    debugPrint('Phase 1 complete: ${vulnerabilities.length} vulnerabilities discovered');

    // If no vulnerabilities or enhancement disabled, return discovery results
    if (vulnerabilities.isEmpty || !options.enableTwoPhaseEnhancement) {
      debugPrint('Returning discovery results (no enhancement phase)');
      return result;
    }

    // =========================================================================
    // PHASE 2: ENHANCEMENT
    // =========================================================================
    debugPrint('\n>>> [Phase 2] Enhancing ${vulnerabilities.length} vulnerabilities...');

    final enhancedVulnerabilities = <Map<String, dynamic>>[];

    for (var i = 0; i < vulnerabilities.length; i++) {
      final vuln = vulnerabilities[i] as Map<String, dynamic>;
      debugPrint('\n>>> [Phase 2] Enhancing vulnerability ${i + 1}/${vulnerabilities.length}: ${vuln['problem']}');

      onProgress?.call(SearchProgress(
        currentPhase: 2,
        totalVulnerabilities: vulnerabilities.length,
        enhancedCount: i,
        currentOperation: 'Enhancing: ${vuln['problem']}',
      ));

      try {
        final enhanced = await _enhanceVulnerability(
          vuln: vuln,
          deviceData: deviceData,
          settings: settings,
          optimizeForSmallLLM: options.optimizeForSmallLLM,
        );
        enhancedVulnerabilities.add(enhanced);
        debugPrint('  Enhanced successfully');
      } catch (e) {
        debugPrint('  Enhancement failed: $e - using discovery data');
        enhancedVulnerabilities.add(vuln); // Fall back to discovery data
      }
    }

    result['vulnerabilities'] = enhancedVulnerabilities;

    debugPrint('\n>>> Search complete. Total tokens used: $_totalPromptTokens prompt + $_totalCompletionTokens completion');

    onProgress?.call(SearchProgress(
      currentPhase: 2,
      totalVulnerabilities: vulnerabilities.length,
      enhancedCount: vulnerabilities.length,
      currentOperation: 'Complete',
    ));

    return result;
  }

  /// Phase 2: Enhance a single vulnerability with detailed evidence and recommendations
  Future<Map<String, dynamic>> _enhanceVulnerability({
    required Map<String, dynamic> vuln,
    required Map<String, dynamic> deviceData,
    required LLMSettings settings,
    bool optimizeForSmallLLM = false,
  }) async {
    final enhancementPrompt = _buildEnhancementPrompt(
      vuln: vuln,
      deviceData: deviceData,
      optimizeForSmallLLM: optimizeForSmallLLM,
    );

    debugPrint('  Enhancement prompt length: ${enhancementPrompt.length} characters');

    final response = await UnifiedLLMClient.sendRequest(
      config: LLMRequestConfig(
        provider: settings.provider.name,
        modelName: settings.modelName,
        apiKey: settings.apiKey,
        baseUrl: settings.baseUrl,
        temperature: settings.temperature,
        maxTokens: optimizeForSmallLLM ? 1500 : 2500,
        timeoutSeconds: settings.timeoutSeconds,
      ),
      prompt: enhancementPrompt,
    );

    if (!response.success) {
      throw Exception(response.userFriendlyError);
    }

    // Track usage
    if (response.usage != null) {
      _totalPromptTokens += response.usage!.promptTokens;
      _totalCompletionTokens += response.usage!.completionTokens;
    }
    lastUsage = cumulativeUsage;

    // Parse enhancement response and merge with discovery data
    final enhanced = _parseEnhancementResponse(response.content, vuln);
    return enhanced;
  }

  Future<Map<String, dynamic>> _gatherDeviceData(int deviceId, int projectId) async {
    return await PlatformUtils.platformSpecific(
      web: () => _gatherDeviceDataWeb(deviceId, projectId),
      desktop: () => _gatherDeviceDataDesktop(deviceId, projectId),
    );
  }

  Future<Map<String, dynamic>> _gatherDeviceDataWeb(int deviceId, int projectId) async {
    try {
      final response = await http.get(
        Uri.parse('/api/devices/$deviceId/ai-data?projectId=$projectId'),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      debugPrint('Error gathering device data from API: $e');
    }
    return {};
  }

  Future<Map<String, dynamic>> _gatherDeviceDataDesktop(int deviceId, int projectId) async {
    final device = await _deviceRepo.getDevice(deviceId);
    final ports = await _metadataRepo.getNmapPorts(deviceId);
    final scripts = await _metadataRepo.getNmapScripts(deviceId);
    final scans = await _scanRepo.getScansForDevice(deviceId);

    return {
      'device': device,
      'ports': ports,
      'scripts': scripts,
      'scans': scans,
    };
  }

  // ===========================================================================
  // PHASE 1: DISCOVERY PROMPT
  // ===========================================================================
  String _buildDiscoveryPrompt(
      Map<String, dynamic> deviceData,
      String minConfidence,
      String minSeverity,
      {bool optimizeForSmallLLM = false}
      ) {
    final device = deviceData['device'] as Map<String, dynamic>?;
    final ports = deviceData['ports'] as List? ?? [];
    final scripts = deviceData['scripts'] as List? ?? [];
    final scans = deviceData['scans'] as List? ?? [];

    // More aggressive compression for small LLMs
    final processedScripts = _compressScripts(scripts, aggressive: optimizeForSmallLLM);
    final processedScans = _compressScans(scans, aggressive: optimizeForSmallLLM);

    final buffer = StringBuffer();

    // Role and task
    buffer.writeln('You are an expert penetration tester analyzing network scan data.');
    buffer.writeln('TASK: Identify security vulnerabilities from the scan data below.');
    buffer.writeln();

    if (optimizeForSmallLLM) {
      // Simplified prompt for smaller models
      buffer.writeln('RULES:');
      buffer.writeln('- Return ONLY valid JSON');
      buffer.writeln('- Maximum 5 vulnerabilities');
      buffer.writeln('- Focus on highest severity issues');
      buffer.writeln('- Brief descriptions (1-2 sentences)');
      buffer.writeln();

      buffer.writeln('SEVERITY: Critical > High > Medium > Low');
      buffer.writeln('CONFIDENCE: Confirmed > High > Medium > Low');
      buffer.writeln();

      buffer.writeln('FILTER: Only return vulnerabilities with:');
      buffer.writeln('- Confidence: $minConfidence or higher');
      buffer.writeln('- Severity: $minSeverity or higher');
      buffer.writeln();
    } else {
      // Full prompt for capable models
      buffer.writeln('ASSESSMENT METHODOLOGY:');
      buffer.writeln('1. Check for known CVEs affecting specific software versions');
      buffer.writeln('2. Identify misconfigurations (default credentials, unnecessary services)');
      buffer.writeln('3. Detect outdated/vulnerable software versions');
      buffer.writeln('4. Find information disclosure vulnerabilities');
      buffer.writeln('5. Identify missing security controls');
      buffer.writeln();

      buffer.writeln('SEVERITY LEVELS:');
      buffer.writeln('- Critical: RCE, auth bypass, data breach with no user interaction');
      buffer.writeln('- High: Significant impact requiring minimal interaction or local access');
      buffer.writeln('- Medium: Requires specific conditions or user interaction');
      buffer.writeln('- Low: Minor concerns or limited information disclosure');
      buffer.writeln();

      buffer.writeln('CONFIDENCE LEVELS:');
      buffer.writeln('- Confirmed: Version EXACTLY matches vulnerable range AND CVE/exploit exists');
      buffer.writeln('- High: Version likely vulnerable but patch level uncertain');
      buffer.writeln('- Medium: Probable vulnerability based on service/version');
      buffer.writeln('- Low: Potential vulnerability requiring investigation');
      buffer.writeln();

      buffer.writeln('FILTERING REQUIREMENTS:');
      buffer.writeln('Return ONLY vulnerabilities meeting BOTH:');
      buffer.writeln('- Minimum Confidence: $minConfidence or higher (${_getHigherConfidenceLevels(minConfidence).join(", ")})');
      buffer.writeln('- Minimum Severity: $minSeverity or higher (${_getHigherSeverityLevels(minSeverity).join(", ")})');
      buffer.writeln();

      buffer.writeln('If NO vulnerabilities meet thresholds, return empty array.');
      buffer.writeln('Limit to top 10 most critical findings.');
      buffer.writeln();

      buffer.writeln('CVE ATTRIBUTION - CRITICAL:');
      buffer.writeln('- ONLY attribute CVEs to the service where they were detected');
      buffer.writeln('- If CVE found in SSH vulners output, it applies ONLY to SSH');
      buffer.writeln('- DO NOT invent vulnerabilities for ports without scan data');
      buffer.writeln();

      buffer.writeln('DESCRIPTION REQUIREMENTS:');
      buffer.writeln('Each description MUST include:');
      buffer.writeln('- Vulnerability name or class');
      buffer.writeln('- Affected versions');
      buffer.writeln('- Impact type (RCE, DoS, privilege escalation, etc.)');
      buffer.writeln('- Attack conditions');
      buffer.writeln();
      buffer.writeln('GOOD: "CVE-2024-6387 (regreSSHion): Race condition in OpenSSH sshd affects 8.5p1-9.7p1. Unauthenticated RCE via timing attack."');
      buffer.writeln('BAD: "SSH is vulnerable to a security flaw"');
      buffer.writeln();
    }

    // Model response rules
    buffer.writeln('RESPONSE RULES:');
    buffer.writeln('- Output ONLY valid JSON');
    buffer.writeln('- No markdown formatting');
    buffer.writeln('- No explanations or reasoning text');
    buffer.writeln('- English only');
    buffer.writeln();

    // CVSS guidance (condensed)
    buffer.writeln('CVSS: AV(NETWORK/ADJACENT/LOCAL/PHYSICAL), AC(LOW/HIGH), PR(NONE/LOW/HIGH), UI(NONE/REQUIRED), S(CHANGED/UNCHANGED), C/I/A(NONE/LOW/HIGH)');
    buffer.writeln();

    // Device data
    buffer.writeln('DEVICE DATA:');
    buffer.writeln('```json');
    buffer.writeln(JsonEncoder.withIndent('  ').convert({
      'device': {
        'id': device?['id'],
        'name': device?['name'],
        'ip_address': device?['ip_address'],
        'mac_address': device?['mac_address'],
        'vendor': device?['vendor'],
      },
      'open_ports': ports.map((port) => {
        'port': port['port'],
        'protocol': port['protocol'],
        'service': port['service_name'],
        'product': port['product'],
        'version': port['version'],
      }).toList(),
      'nmap_scripts': processedScripts,
      'additional_scans': processedScans,
    }));
    buffer.writeln('```');
    buffer.writeln();

    // Output format - Note: evidence and recommendation are brief in discovery phase
    buffer.writeln('OUTPUT FORMAT:');
    buffer.writeln('{');
    buffer.writeln('  "device_id": ${device?['id'] ?? 0},');
    buffer.writeln('  "vulnerabilities": [');
    buffer.writeln('    {');
    buffer.writeln('      "problem": "Specific title with CVE if known",');
    buffer.writeln('      "cve": "CVE-XXXX-XXXXX or empty string",');
    buffer.writeln('      "description": "Detailed: name, versions, impact, conditions",');
    buffer.writeln('      "severity": "Low|Medium|High|Critical",');
    buffer.writeln('      "confidence": "Low|Medium|High|Confirmed",');
    buffer.writeln('      "evidence": "Brief: port/service/version detected",');
    buffer.writeln('      "recommendation": "Brief: primary remediation action",');
    buffer.writeln('      "attack_vector": "NETWORK|ADJACENT|LOCAL|PHYSICAL",');
    buffer.writeln('      "attack_complexity": "LOW|HIGH",');
    buffer.writeln('      "privileges_required": "NONE|LOW|HIGH",');
    buffer.writeln('      "user_interaction": "NONE|REQUIRED",');
    buffer.writeln('      "scope": "CHANGED|UNCHANGED",');
    buffer.writeln('      "confidentiality_impact": "NONE|LOW|HIGH",');
    buffer.writeln('      "integrity_impact": "NONE|LOW|HIGH",');
    buffer.writeln('      "availability_impact": "NONE|LOW|HIGH"');
    buffer.writeln('    }');
    buffer.writeln('  ]');
    buffer.writeln('}');
    buffer.writeln();
    buffer.writeln('Return ONLY the JSON. No preamble.');

    return buffer.toString();
  }

  // ===========================================================================
  // PHASE 2: ENHANCEMENT PROMPT
  // ===========================================================================
  String _buildEnhancementPrompt({
    required Map<String, dynamic> vuln,
    required Map<String, dynamic> deviceData,
    bool optimizeForSmallLLM = false,
  }) {
    final device = deviceData['device'] as Map<String, dynamic>?;
    final ports = deviceData['ports'] as List? ?? [];
    final scripts = deviceData['scripts'] as List? ?? [];
    final scans = deviceData['scans'] as List? ?? [];

    final buffer = StringBuffer();

    buffer.writeln('You are a cybersecurity expert writing detailed findings for a penetration testing report.');
    buffer.writeln();

    buffer.writeln('VULNERABILITY TO DOCUMENT:');
    buffer.writeln('- Problem: ${vuln['problem']}');
    buffer.writeln('- CVE: ${vuln['cve'] ?? 'N/A'}');
    buffer.writeln('- Severity: ${vuln['severity']}');
    buffer.writeln('- Description: ${vuln['description']}');
    buffer.writeln();

    buffer.writeln('DEVICE CONTEXT:');
    buffer.writeln('Device: ${device?['name']} (${device?['ip_address']})');
    if (device?['vendor'] != null) {
      buffer.writeln('Vendor: ${device?['vendor']}');
    }
    buffer.writeln();

    // Include relevant ports
    buffer.writeln('OPEN PORTS:');
    for (final port in ports) {
      final portNum = port['port'];
      final protocol = port['protocol'] ?? 'tcp';
      final service = port['service_name'] ?? '';
      final product = port['product'] ?? '';
      final version = port['version'] ?? '';
      buffer.writeln('- Port $portNum/$protocol: $product $version ($service)');
    }
    buffer.writeln();

    // Include relevant scan data (compressed)
    if (scripts.isNotEmpty) {
      buffer.writeln('SCAN SCRIPTS:');
      for (final script in scripts) {
        final scriptId = script['script_id'];
        var output = script['output'] as String;
        if (output.length > 1500) {
          output = '${output.substring(0, 1500)}...';
        }
        buffer.writeln('- $scriptId:\n  $output');
      }
      buffer.writeln();
    }

    if (scans.isNotEmpty && !optimizeForSmallLLM) {
      buffer.writeln('ADDITIONAL SCANS:');
      for (final scan in scans.take(3)) { // Limit to 3 most relevant
        final scanType = scan['name'] ?? 'Unknown';
        var content = scan['content'] as String;
        if (content.length > 1000) {
          content = '${content.substring(0, 1000)}...';
        }
        buffer.writeln('- $scanType:\n  $content');
      }
      buffer.writeln();
    }

    buffer.writeln('================================================================================');
    buffer.writeln('YOUR TASK: Generate detailed EVIDENCE and RECOMMENDATION sections.');
    buffer.writeln('================================================================================');
    buffer.writeln();

    if (optimizeForSmallLLM) {
      buffer.writeln('EVIDENCE (2-3 sentences):');
      buffer.writeln('- What scan data proves the vulnerability');
      buffer.writeln('- Include verification command');
      buffer.writeln();
      buffer.writeln('RECOMMENDATION (2-3 sentences):');
      buffer.writeln('- How to fix it');
      buffer.writeln('- Include specific command');
      buffer.writeln();
    } else {
      buffer.writeln('EVIDENCE SECTION (write in prose, 150-250 words):');
      buffer.writeln('1. DETECTION: Reference specific scan data (port, service version, script output)');
      buffer.writeln('2. CVE PROOF: State CVE, CVSS score, why this version is affected');
      buffer.writeln('3. EXPLOITS: Available exploit references (PACKETSTORM, GitHub PoCs, Metasploit modules)');
      buffer.writeln('4. VERIFICATION: Include specific command(s) to confirm the finding');
      buffer.writeln();
      buffer.writeln('RECOMMENDATION SECTION (write in prose, 150-250 words):');
      buffer.writeln('1. PRIMARY FIX: State the main remediation action');
      buffer.writeln('2. COMMANDS: Include actual command(s) to implement the fix');
      buffer.writeln('3. VERIFICATION: How to confirm the fix was successful');
      buffer.writeln('4. BEST PRACTICES: Additional hardening steps relevant to this vulnerability');
      buffer.writeln();
    }

    buffer.writeln('FORMATTING RULES:');
    buffer.writeln('- Write in plain prose (no markdown headers, no bullet points)');
    buffer.writeln('- Include commands inline in sentences');
    buffer.writeln('- Be specific and technical');
    buffer.writeln();

    buffer.writeln('OUTPUT FORMAT (JSON only):');
    buffer.writeln('{');
    buffer.writeln('  "evidence": "Your detailed evidence text here",');
    buffer.writeln('  "recommendation": "Your detailed recommendation text here"');
    buffer.writeln('}');
    buffer.writeln();
    buffer.writeln('Return ONLY the JSON. No explanations.');

    return buffer.toString();
  }

  List<Map<String, dynamic>> _compressScripts(List scripts, {bool aggressive = false}) {
    return scripts.map((script) {
      final scriptId = script['script_id'] as String;
      var output = script['output'] as String;

      if (scriptId == 'vulners') {
        output = _compressVulnersOutput(output, aggressive: aggressive);
      } else {
        final maxLen = aggressive ? 1000 : 2000;
        if (output.length > maxLen) {
          output = '${output.substring(0, maxLen)}... [truncated]';
        }
      }

      return {'script_id': scriptId, 'output': output};
    }).toList();
  }

  String _compressVulnersOutput(String output, {bool aggressive = false}) {
    final cvePattern = RegExp(r'(CVE-\d{4}-\d+)\s+(\d+\.\d+)');
    final matches = cvePattern.allMatches(output);

    final minCvss = aggressive ? 8.0 : 7.0;
    final Map<String, double> uniqueCVEs = {};
    for (final match in matches) {
      final cve = match.group(1)!;
      final cvss = double.parse(match.group(2)!);

      if (cvss >= minCvss) {
        if (!uniqueCVEs.containsKey(cve) || cvss > uniqueCVEs[cve]!) {
          uniqueCVEs[cve] = cvss;
        }
      }
    }

    final compressed = StringBuffer();
    compressed.writeln('High-severity CVEs (CVSS >= $minCvss):');
    final entries = uniqueCVEs.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final limit = aggressive ? 10 : 20;
    for (final entry in entries.take(limit)) {
      compressed.writeln('  ${entry.key} (CVSS ${entry.value})');
    }

    return compressed.toString();
  }

  List<Map<String, dynamic>> _compressScans(List scans, {bool aggressive = false}) {
    final maxLen = aggressive ? 2000 : 5000;
    final maxScans = aggressive ? 3 : 10;

    return scans.where((scan) {
      final content = scan['content'] as String;
      return content.trim().isNotEmpty && content.length > 50;
    }).take(maxScans).map((scan) {
      var content = scan['content'] as String;

      if (content.length > maxLen) {
        content = '${content.substring(0, maxLen)}... [truncated]';
      }

      return {'scan_type': scan['name'], 'content': content};
    }).toList();
  }

  List<String> _getHigherSeverityLevels(String minSeverity) {
    const levels = ['Low', 'Medium', 'High', 'Critical'];
    final index = levels.indexOf(minSeverity);
    return index >= 0 ? levels.sublist(index + 1) : [];
  }

  List<String> _getHigherConfidenceLevels(String minConfidence) {
    const levels = ['Low', 'Medium', 'High', 'Confirmed'];
    final index = levels.indexOf(minConfidence);
    return index >= 0 ? levels.sublist(index + 1) : [];
  }

  Map<String, dynamic> _parseResponse(String response, int deviceId) {
    try {
      debugPrint('Attempting to parse JSON from response...');

      // Remove markdown code blocks if present
      var cleanResponse = response.trim();
      if (cleanResponse.startsWith('```json')) {
        cleanResponse = cleanResponse.substring(7);
      }
      if (cleanResponse.startsWith('```')) {
        cleanResponse = cleanResponse.substring(3);
      }
      if (cleanResponse.endsWith('```')) {
        cleanResponse = cleanResponse.substring(0, cleanResponse.length - 3);
      }
      cleanResponse = cleanResponse.trim();

      final jsonStart = cleanResponse.indexOf('{');
      final jsonEnd = cleanResponse.lastIndexOf('}') + 1;

      if (jsonStart >= 0 && jsonEnd > jsonStart) {
        final jsonStr = cleanResponse.substring(jsonStart, jsonEnd);
        debugPrint('Extracted JSON (length ${jsonStr.length})');

        // Check if JSON looks incomplete
        if (!jsonStr.endsWith('}') || jsonStr.split('{').length != jsonStr.split('}').length) {
          debugPrint('WARNING: JSON appears incomplete - response may have been truncated');
        }

        final parsed = json.decode(jsonStr);
        debugPrint('JSON parsed successfully');
        return parsed;
      }

      debugPrint('ERROR: No valid JSON found in response');
      return {'device_id': deviceId, 'vulnerabilities': [], 'error': 'No valid JSON in response'};
    } catch (e, stack) {
      debugPrint('ERROR parsing LLM response: $e');
      debugPrint('Stack: $stack');
      return {'device_id': deviceId, 'vulnerabilities': [], 'error': e.toString()};
    }
  }

  Map<String, dynamic> _parseEnhancementResponse(String response, Map<String, dynamic> originalVuln) {
    try {
      // Remove markdown formatting
      var cleanResponse = response.trim();
      if (cleanResponse.startsWith('```json')) {
        cleanResponse = cleanResponse.substring(7);
      }
      if (cleanResponse.startsWith('```')) {
        cleanResponse = cleanResponse.substring(3);
      }
      if (cleanResponse.endsWith('```')) {
        cleanResponse = cleanResponse.substring(0, cleanResponse.length - 3);
      }
      cleanResponse = cleanResponse.trim();

      final jsonStart = cleanResponse.indexOf('{');
      final jsonEnd = cleanResponse.lastIndexOf('}') + 1;

      if (jsonStart >= 0 && jsonEnd > jsonStart) {
        final jsonStr = cleanResponse.substring(jsonStart, jsonEnd);
        final enhanced = json.decode(jsonStr) as Map<String, dynamic>;

        // Merge enhanced fields with original vulnerability
        final result = Map<String, dynamic>.from(originalVuln);
        if (enhanced['evidence'] != null && (enhanced['evidence'] as String).isNotEmpty) {
          result['evidence'] = enhanced['evidence'];
        }
        if (enhanced['recommendation'] != null && (enhanced['recommendation'] as String).isNotEmpty) {
          result['recommendation'] = enhanced['recommendation'];
        }

        return result;
      }

      debugPrint('Could not parse enhancement response, using original');
      return originalVuln;
    } catch (e) {
      debugPrint('Error parsing enhancement: $e');
      return originalVuln;
    }
  }
}