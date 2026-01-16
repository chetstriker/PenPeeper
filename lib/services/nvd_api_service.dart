import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:penpeeper/api_database_helper.dart';

class NvdApiService {
  static const String _apiKey = '581aaf06-657f-4940-ae07-5542c1fe53ee';
  static const String _baseUrl = 'https://services.nvd.nist.gov/rest/json/cves/2.0';

  Future<Map<String, dynamic>?> fetchCveData(String cveId) async {
    if (kIsWeb) {
      return await _fetchCveDataWeb(cveId);
    } else {
      return await _fetchCveDataDirect(cveId);
    }
  }

  Future<Map<String, dynamic>?> _fetchCveDataWeb(String cveId) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiDatabaseHelper.baseUrl}/cve/lookup'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'cveId': cveId}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseCveResponse(data, cveId);
      } else {
        debugPrint('CVE API error: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('CVE API exception: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchCveDataDirect(String cveId) async {
    try {
      final uri = Uri.parse('$_baseUrl?cveId=$cveId');
      final response = await http.get(
        uri,
        headers: {'apiKey': _apiKey},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseCveResponse(data, cveId);
      } else {
        debugPrint('NVD API error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('NVD API exception: $e');
      return null;
    }
  }

  Map<String, dynamic>? _parseCveResponse(Map<String, dynamic> data, String cveId) {
    try {
      final vulnerabilities = data['vulnerabilities'] as List?;
      if (vulnerabilities == null || vulnerabilities.isEmpty) return null;

      final cve = vulnerabilities[0]['cve'] as Map<String, dynamic>;
      
      // Extract description
      String description = '';
      final descriptions = cve['descriptions'] as List?;
      if (descriptions != null) {
        for (var desc in descriptions) {
          if (desc['lang'] == 'en') {
            description = desc['value'] ?? '';
            break;
          }
        }
      }

      // Extract CVSS data with version - dynamically find newest version
      double? cvssScore;
      String? cvssVersion;
      String? attackVector, attackComplexity, privilegesRequired, userInteraction, scope;
      String? confidentialityImpact, integrityImpact, availabilityImpact, cvssSeverity;

      final metrics = cve['metrics'] as Map<String, dynamic>?;
      if (metrics != null) {
        // Find all CVSS metric keys and extract their versions
        final cvssMetrics = <String, double>{};
        for (var key in metrics.keys) {
          if (key.startsWith('cvssMetric')) {
            // Extract version from key (e.g., cvssMetricV40 -> 4.0, cvssMetricV31 -> 3.1)
            final versionStr = key.replaceFirst('cvssMetricV', '');
            double? version;

            if (versionStr.length >= 2) {
              // Parse version string (e.g., "40" -> 4.0, "31" -> 3.1, "3" -> 3.0, "2" -> 2.0)
              final majorStr = versionStr.substring(0, 1);
              final minorStr = versionStr.length > 1 ? versionStr.substring(1) : '0';
              version = double.tryParse('$majorStr.$minorStr');
            }

            if (version != null && metrics[key] is List && (metrics[key] as List).isNotEmpty) {
              cvssMetrics[key] = version;
            }
          }
        }

        // Sort by version descending and pick the newest
        if (cvssMetrics.isNotEmpty) {
          final sortedKeys = cvssMetrics.keys.toList()
            ..sort((a, b) => cvssMetrics[b]!.compareTo(cvssMetrics[a]!));

          final newestKey = sortedKeys.first;
          final newestVersion = cvssMetrics[newestKey]!;
          cvssVersion = newestVersion.toStringAsFixed(1);

          final metricList = metrics[newestKey] as List;
          final cvssData = metricList[0]['cvssData'] as Map<String, dynamic>?;

          if (cvssData != null) {
            cvssScore = (cvssData['baseScore'] as num?)?.toDouble();
            cvssSeverity = cvssData['baseSeverity'] as String?;
            attackVector = cvssData['attackVector'] as String?;
            attackComplexity = cvssData['attackComplexity'] as String?;
            privilegesRequired = cvssData['privilegesRequired'] as String?;
            userInteraction = cvssData['userInteraction'] as String?;
            scope = cvssData['scope'] as String?;
            confidentialityImpact = cvssData['confidentialityImpact'] as String?;
            integrityImpact = cvssData['integrityImpact'] as String?;
            availabilityImpact = cvssData['availabilityImpact'] as String?;
          }
        }
      }

      // Extract vulnerability type from CWE
      String vulnerabilityType = 'Unknown';
      final weaknesses = cve['weaknesses'] as List?;
      if (weaknesses != null && weaknesses.isNotEmpty) {
        final weaknessDesc = weaknesses[0]['description'] as List?;
        if (weaknessDesc != null && weaknessDesc.isNotEmpty) {
          vulnerabilityType = weaknessDesc[0]['value'] ?? 'Unknown';
        }
      }

      return {
        'description': description,
        'vulnerabilityType': vulnerabilityType,
        'cvssScore': cvssScore ?? 0.0,
        'cvssVersion': cvssVersion,
        'attackVector': attackVector,
        'attackComplexity': attackComplexity,
        'privilegesRequired': privilegesRequired,
        'userInteraction': userInteraction,
        'scope': scope,
        'confidentialityImpact': confidentialityImpact,
        'integrityImpact': integrityImpact,
        'availabilityImpact': availabilityImpact,
        'cvssSeverity': cvssSeverity,
        'url': 'https://nvd.nist.gov/vuln/detail/$cveId',
      };
    } catch (e) {
      debugPrint('Error parsing CVE response: $e');
      return null;
    }
  }
}
