import 'package:penpeeper/models/report_models.dart';
import 'package:penpeeper/repositories/findings_repository.dart';
import 'package:penpeeper/repositories/tag_repository.dart';
import 'package:penpeeper/repositories/vulnerability_repository.dart';
import 'package:penpeeper/repositories/device_repository.dart';
import 'package:penpeeper/repositories/report_section_repository.dart';
import 'package:penpeeper/repositories/project_repository.dart';

class ReportService {
  final _findingsRepo = FindingsRepository();
  final _tagRepo = TagRepository();
  final _vulnRepo = VulnerabilityRepository();
  final _deviceRepo = DeviceRepository();
  final _reportSectionRepo = ReportSectionRepository();
  final _projectRepo = ProjectRepository();

  Future<ReportData> getReportData(int projectId, {List<String>? selectedTags}) async {
    // Get project name first
    final projects = await _projectRepo.getProjects();
    final project = projects.firstWhere((p) => p.id == projectId, orElse: () => throw Exception('Project not found'));
    final projectName = project.name;
    
    // Get completed findings only
    final findingsData = await _findingsRepo.getCompleteFlaggedFindings(projectId);
    
    // Enrich findings with vulnerability classification and device data
    final enrichedFindings = <Map<String, dynamic>>[];
    for (final finding in findingsData) {
      final enriched = Map<String, dynamic>.from(finding);
      
      // Get vulnerability classification if exists
      final classification = await _vulnRepo.getVulnerabilityClassificationByFindingId(finding['id'] as int);
      if (classification != null) {
        enriched['category'] = classification.category;
        enriched['subcategory'] = classification.subcategory;
      }
      
      // Normalize severity to uppercase (graphic expects UPPERCASE)
      if (enriched['cvss_severity'] != null && enriched['cvss_severity'].toString().isNotEmpty) {
        // Already has severity - just uppercase it
        enriched['cvss_severity'] = enriched['cvss_severity'].toString().toUpperCase();
      } else {
        // Calculate from CVSS score if missing
        final cvssScore = enriched['cvss_base_score'];
        if (cvssScore != null) {
          enriched['cvss_severity'] = _calculateSeverityFromScore(cvssScore);
        }
      }
      
      // Get device MAC and vendor information (skip for non-device findings)
      final deviceId = finding['device_id'] as int;
      if (deviceId != 0) {
        final deviceData = await _getDeviceData(deviceId);
        enriched['mac_address'] = deviceData['mac_address'];
        enriched['vendor'] = deviceData['vendor'];
      } else {
        enriched['mac_address'] = null;
        enriched['vendor'] = null;
      }
      
      enrichedFindings.add(enriched);
    }
    
    // Convert to ReportFinding objects
    final findings = enrichedFindings.map((data) => ReportFinding.fromMap(data)).toList();
    
    // Filter by tags if specified
    List<ReportFinding> filteredFindings = findings;
    if (selectedTags != null && selectedTags.isNotEmpty) {
      final taggedDeviceIds = await _getDeviceIdsByTags(projectId, selectedTags);
      filteredFindings = findings.where((f) => taggedDeviceIds.contains(f.deviceId)).toList();
    }
    
    // Group findings by Category → Subcategory
    final groupedFindings = _groupFindings(filteredFindings);
    
    // Get available tags
    final availableTags = await _getAvailableTags(projectId);
    
    // Get report sections
    final reportHeader = await _reportSectionRepo.getReportSection(projectId, 'report_header');
    final executiveSummary = await _reportSectionRepo.getReportSection(projectId, 'executive_summary');
    final methodologyScope = await _reportSectionRepo.getReportSection(projectId, 'methodology_scope');
    final riskRatingModel = await _reportSectionRepo.getReportSection(projectId, 'risk_rating_model');
    final conclusion = await _reportSectionRepo.getReportSection(projectId, 'conclusion');
    final summaryGraphic = await _reportSectionRepo.getReportSection(projectId, 'summary_graphic');

    print('[REPORT_SERVICE] Summary graphic section: ${summaryGraphic?.content}');
    // Default to option 1 if no record exists or parsing fails
    final graphicOption = summaryGraphic != null ? (int.tryParse(summaryGraphic.content) ?? 1) : 1;
    print('[REPORT_SERVICE] Parsed graphic option: $graphicOption');
    
    return ReportData(
      findings: filteredFindings,
      groupedFindings: groupedFindings,
      availableTags: availableTags,
      reportHeader: reportHeader?.content,
      executiveSummary: executiveSummary?.content,
      methodologyScope: methodologyScope?.content,
      riskRatingModel: riskRatingModel?.content,
      conclusion: conclusion?.content,
      projectName: projectName,
      summaryGraphicOption: graphicOption,
    );
  }

  Future<Set<int>> _getDeviceIdsByTags(int projectId, List<String> tags) async {
    final deviceIds = <int>{};
    for (final tag in tags) {
      final taggedDevices = await _tagRepo.searchDevicesByTag(projectId, tag);
      deviceIds.addAll(taggedDevices.map((d) => d['id'] as int));
    }
    return deviceIds;
  }

  Future<List<String>> _getAvailableTags(int projectId) async {
    return await _tagRepo.getAllProjectTags(projectId);
  }

  Map<String, List<ReportFinding>> _groupFindings(List<ReportFinding> findings) {
    final grouped = <String, List<ReportFinding>>{};
    
    for (final finding in findings) {
      final category = finding.category ?? 'Uncategorized';
      final subcategory = finding.subcategory ?? 'General';
      
      final key = '$category|$subcategory';
      
      if (!grouped.containsKey(key)) {
        grouped[key] = [];
      }
      grouped[key]!.add(finding);
    }
    
    // Sort findings within each group by IP address
    for (final key in grouped.keys) {
      grouped[key]!.sort((a, b) => a.ipAddress.compareTo(b.ipAddress));
    }
    
    // Sort groups alphabetically by category, then subcategory
    final sortedKeys = grouped.keys.toList()..sort((a, b) {
      final aParts = a.split('|');
      final bParts = b.split('|');
      
      // Compare category alphabetically
      final categoryCompare = aParts[0].compareTo(bParts[0]);
      if (categoryCompare != 0) return categoryCompare;
      
      // Compare subcategory alphabetically
      return aParts[1].compareTo(bParts[1]);
    });
    
    final sortedGrouped = <String, List<ReportFinding>>{};
    for (final key in sortedKeys) {
      sortedGrouped[key] = grouped[key]!;
    }
    
    return sortedGrouped;
  }

  Future<Map<String, dynamic>> _getDeviceData(int deviceId) async {
    final device = await _deviceRepo.getDeviceById(deviceId);
    
    // Try to get MAC and vendor from device table first
    String? macAddress = device?.macAddress;
    String? vendor = device?.vendor;
    
    // If not in device table, try nmap_hosts table
    if ((macAddress == null || macAddress.isEmpty) && device != null) {
      final nmapData = await _deviceRepo.getNmapHostData(deviceId);
      macAddress = nmapData?['mac_address'];
      vendor = nmapData?['vendor'];
    }
    
    return {
      'mac_address': macAddress,
      'vendor': vendor,
    };
  }

  /// Calculate severity rating from CVSS score
  /// CVSS 9.0-10.0 = CRITICAL
  /// CVSS 7.0-8.9  = HIGH  
  /// CVSS 4.0-6.9  = MEDIUM
  /// CVSS 0.1-3.9  = LOW
  /// CVSS 0.0      = INFO
  String _calculateSeverityFromScore(dynamic score) {
    final numScore = score is double ? score : double.tryParse(score.toString()) ?? 0.0;
    
    if (numScore >= 9.0) return 'CRITICAL';
    if (numScore >= 7.0) return 'HIGH';
    if (numScore >= 4.0) return 'MEDIUM';
    if (numScore > 0.0) return 'LOW';
    return 'INFO';
  }
}