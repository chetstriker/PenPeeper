import 'package:flutter/services.dart';
import 'dart:convert';
import 'package:penpeeper/repositories/findings_repository.dart';
import 'package:penpeeper/repositories/vulnerability_repository.dart';
import 'package:penpeeper/models/cvss/cvss_data.dart';

class FindingCreationService {
  final _findingsRepo = FindingsRepository();
  final _vulnRepo = VulnerabilityRepository();

  Future<int> createCveFinding({
    required int deviceId,
    required String deviceName,
    required String ipAddress,
    required int projectId,
    required Map<String, dynamic> cveData,
  }) async {
    return await _findingsRepo.insertFlaggedFinding(
      deviceId,
      deviceName,
      ipAddress,
      'CVE',
      cveData['description'],
      findingType: 'CVE',
      projectId: projectId,
      cveId: cveData['cveId'],
      confidenceLevel: cveData['confidenceLevel'],
      vulnerabilityType: cveData['vulnerabilityType'],
      url: cveData['url'],
      cvssVersion: cveData['cvssVersion'],
      attackVector: cveData['attackVector'],
      attackComplexity: cveData['attackComplexity'],
      privilegesRequired: cveData['privilegesRequired'],
      userInteraction: cveData['userInteraction'],
      scope: cveData['scope'],
      confidentialityImpact: cveData['confidentialityImpact'],
      integrityImpact: cveData['integrityImpact'],
      availabilityImpact: cveData['availabilityImpact'],
      cvssBaseScore: cveData['cvssScore'],
      cvssSeverity: cveData['cvssSeverity'],
    );
  }

  Future<int> createManualFinding({
    required int deviceId,
    required String deviceName,
    required String ipAddress,
    required Map<String, dynamic> flagData,
  }) async {
    final findingId = await _findingsRepo.insertFlaggedFinding(
      deviceId,
      deviceName,
      ipAddress,
      flagData['type'],
      flagData['comment'],
    );

    if (flagData['evidence'] != null && flagData['evidence'].toString().isNotEmpty) {
      await _findingsRepo.updateFlaggedFindingEvidence(findingId, flagData['evidence']);
    }
    if (flagData['recommendation'] != null && flagData['recommendation'].toString().isNotEmpty) {
      await _findingsRepo.updateFlaggedFindingRecommendation(findingId, flagData['recommendation']);
    }

    return findingId;
  }

  Future<void> saveClassification({
    required int findingId,
    required int projectId,
    required int deviceId,
    required Map<String, dynamic> classification,
  }) async {
    if (classification['category'] == null || classification['subcategory'] == null) {
      return;
    }

    final existing = await _vulnRepo.getVulnerabilityClassifications(findingId);
    if (existing.isNotEmpty) {
      await _vulnRepo.deleteVulnerabilityClassification(existing.first.id);
    }

    final jsonString = await rootBundle.loadString('assets/vulnerability_taxonomy_full.json');
    final List<dynamic> taxonomyData = json.decode(jsonString);
    final category = taxonomyData.firstWhere(
      (item) => item['Category'] == classification['category'],
      orElse: () => {},
    );
    
    if (category.isEmpty) return;

    final subcategories = (category['Subcategories'] as List).cast<Map<String, dynamic>>();
    final subcategoryData = subcategories.firstWhere(
      (item) => item['Subcategory'] == classification['subcategory'],
      orElse: () => {},
    );
    
    if (subcategoryData.isEmpty) return;

    await _vulnRepo.insertVulnerabilityClassification(
      projectId: projectId,
      deviceId: deviceId,
      findingId: findingId,
      category: classification['category'],
      subcategory: classification['subcategory'],
      description: subcategoryData['Description'] ?? '',
      mappedOwasp: subcategoryData['Mapped_OWASP'] ?? '',
      mappedCwe: subcategoryData['Mapped_CWE'] ?? '',
      severityGuideline: subcategoryData['Severity_Guideline'] ?? '',
      scope: classification['scope'] ?? 'NETWORK',
    );
  }

  Future<void> saveCvssData({
    required int findingId,
    required CvssData cvssData,
  }) async {
    await _findingsRepo.updateFlaggedFindingCvss(
      findingId,
      attackVector: cvssData.attackVector?.name,
      attackComplexity: cvssData.attackComplexity?.name,
      privilegesRequired: cvssData.privilegesRequired?.name,
      userInteraction: cvssData.userInteraction?.name,
      scope: cvssData.scope?.name,
      confidentialityImpact: cvssData.confidentialityImpact?.name,
      integrityImpact: cvssData.integrityImpact?.name,
      availabilityImpact: cvssData.availabilityImpact?.name,
      cvssBaseScore: cvssData.baseScore,
      cvssSeverity: cvssData.severity?.name,
    );
  }
}
