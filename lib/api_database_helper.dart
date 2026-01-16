import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:penpeeper/utils/error/error_handler.dart';
import 'package:penpeeper/models/report_section.dart';
import 'api_database_helper_web.dart'
    if (dart.library.io) 'api_database_helper_stub.dart';

class ApiDatabaseHelper {
  static String get baseUrl => getBaseUrl();
  
  Future<List<Map<String, dynamic>>> getProjects() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/projects'));
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      }
      throw Exception('Failed to load projects');
    } catch (e, stack) {
      ErrorHandler.handle(e, stackTrace: stack, context: 'Get projects');
      rethrow;
    }
  }
  
  Future<int> insertProject(String name) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/projects'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'name': name}),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body)['id'];
      }
      throw Exception('Failed to create project');
    } catch (e, stack) {
      ErrorHandler.handle(e, stackTrace: stack, context: 'Insert project');
      rethrow;
    }
  }
  
  Future<List<Map<String, dynamic>>> getDevices(int projectId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/projects/$projectId/devices'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['devices']);
      }
      throw Exception('Failed to load devices');
    } catch (e, stack) {
      ErrorHandler.handle(e, stackTrace: stack, context: 'Get devices');
      rethrow;
    }
  }
  
  Future<int> insertDevice(int projectId, String name, String ipAddress) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/projects/$projectId/devices'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'name': name, 'ip_address': ipAddress}),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body)['id'];
      }
      throw Exception('Failed to add device');
    } catch (e, stack) {
      ErrorHandler.handle(e, stackTrace: stack, context: 'Insert device');
      rethrow;
    }
  }
  
  Future<List<Map<String, dynamic>>> getScans(int deviceId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/devices/$deviceId/scans'));
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      }
      throw Exception('Failed to load scans');
    } catch (e, stack) {
      ErrorHandler.handle(e, stackTrace: stack, context: 'Get scans');
      rethrow;
    }
  }
  
  Future<Map<String, dynamic>> getDeviceDetails(int deviceId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/devices/$deviceId/details'));
      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      throw Exception('Failed to load device details');
    } catch (e, stack) {
      ErrorHandler.handle(e, stackTrace: stack, context: 'Get device details');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getSambaLdapFindings(int deviceId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/devices/$deviceId/samba-ldap-findings'));
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(json.decode(response.body));
      }
      throw Exception('Failed to load SAMBA/LDAP findings');
    } catch (e, stack) {
      ErrorHandler.handle(e, stackTrace: stack, context: 'Get SAMBA/LDAP findings');
      rethrow;
    }
  }

  Future<void> deleteProject(int projectId) async {
    await http.delete(Uri.parse('$baseUrl/projects/$projectId'));
  }

  Future<void> renameProject(int projectId, String newName) async {
    await http.put(
      Uri.parse('$baseUrl/projects/$projectId'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'name': newName}),
    );
  }

  Future<void> deleteDevice(int deviceId) async {
    await http.delete(Uri.parse('$baseUrl/devices/$deviceId'));
  }
  
  Future<List<String>> getDistinctOperatingSystems(int projectId) async {
    final response = await http.get(Uri.parse('$baseUrl/projects/$projectId/os-list'));
    if (response.statusCode == 200) {
      return List<String>.from(json.decode(response.body));
    }
    return [];
  }
  
  Future<List<String>> getDistinctMacVendors(int projectId) async {
    final response = await http.get(Uri.parse('$baseUrl/projects/$projectId/vendors-list'));
    if (response.statusCode == 200) {
      return List<String>.from(json.decode(response.body));
    }
    return [];
  }
  
  Future<List<String>> getDistinctBanners(int projectId) async {
    final response = await http.get(Uri.parse('$baseUrl/projects/$projectId/banners-list'));
    if (response.statusCode == 200) {
      return List<String>.from(json.decode(response.body));
    }
    return [];
  }
  
  Future<List<Map<String, dynamic>>> searchDevices(int projectId, String type, String query) async {
    final response = await http.post(
      Uri.parse('$baseUrl/projects/$projectId/search'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'type': type, 'query': query}),
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    return [];
  }
  
  Future<List<Map<String, dynamic>>> getFlaggedFindings(int projectId) async {
    final response = await http.get(Uri.parse('$baseUrl/projects/$projectId/findings'));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    return [];
  }
  
  Future<List<Map<String, dynamic>>> getFlaggedFindingsForDevice(int deviceId) async {
    final response = await http.get(Uri.parse('$baseUrl/devices/$deviceId/findings'));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    return [];
  }
  
  Future<List<Map<String, dynamic>>> scanFilter(int projectId, String filter) async {
    final response = await http.post(
      Uri.parse('$baseUrl/projects/$projectId/scan-filter'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'filter': filter}),
    );
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    return [];
  }
  
  Future<Map<int, Map<String, dynamic>>> getBatchDeviceMetadata(int projectId, List<int> deviceIds) async {
    final response = await http.post(
      Uri.parse('$baseUrl/projects/$projectId/metadata'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'device_ids': deviceIds}),
    );
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as Map<String, dynamic>;
      return data.map((key, value) => MapEntry(int.parse(key), value as Map<String, dynamic>));
    }
    return {};
  }

  Future<void> addDeviceTag(int deviceId, String tag) async {
    await http.post(
      Uri.parse('$baseUrl/devices/$deviceId/tags'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'tag': tag}),
    );
  }

  Future<void> removeDeviceTag(int deviceId, String tag) async {
    await http.delete(
      Uri.parse('$baseUrl/devices/$deviceId/tags/$tag'),
    );
  }

  Future<List<String>> getDeviceTags(int deviceId) async {
    final response = await http.get(Uri.parse('$baseUrl/devices/$deviceId/tags'));
    if (response.statusCode == 200) {
      return List<String>.from(json.decode(response.body));
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> searchDevicesByTag(int projectId, String tag) async {
    return await searchDevices(projectId, 'TAG', tag);
  }

  Future<List<String>> getAllProjectTags(int projectId) async {
    final response = await http.get(Uri.parse('$baseUrl/projects/$projectId/tags'));
    if (response.statusCode == 200) {
      return List<String>.from(json.decode(response.body));
    }
    return [];
  }

  Future<Set<int>> getDevicesWithFfufFindings(int projectId) async {
    final response = await http.get(Uri.parse('$baseUrl/projects/$projectId/devices/with-ffuf'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((id) => id as int).toSet();
    }
    return {};
  }

  Future<Set<int>> getDevicesWithSambaLdapFindings(int projectId) async {
    final response = await http.get(Uri.parse('$baseUrl/projects/$projectId/devices/with-samba'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((id) => id as int).toSet();
    }
    return {};
  }

  Future<Set<int>> getDevicesWithWhatWebFindings(int projectId) async {
    final response = await http.get(Uri.parse('$baseUrl/projects/$projectId/devices/with-whatweb'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((id) => id as int).toSet();
    }
    return {};
  }

  Future<Set<int>> getDevicesWithSearchSploitFindings(int projectId) async {
    final response = await http.get(Uri.parse('$baseUrl/projects/$projectId/devices/with-searchsploit'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((id) => id as int).toSet();
    }
    return {};
  }

  Future<Set<int>> getDevicesWithVulnersCves(int projectId) async {
    final response = await http.get(Uri.parse('$baseUrl/projects/$projectId/devices/with-vulners'));
    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(response.body);
      return data.map((id) => id as int).toSet();
    }
    return {};
  }

  // Vulnerability Classification methods
  Future<int> insertVulnerabilityClassification({
    required int projectId,
    required int deviceId,
    required int findingId,
    required String category,
    required String subcategory,
    required String description,
    required String mappedOwasp,
    required String mappedCwe,
    required String severityGuideline,
    String? scope,
  }) async {
    final finalScope = scope ?? 'NETWORK';
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/vulnerability-classifications'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'project_id': projectId,
          'device_id': deviceId,
          'finding_id': findingId,
          'category': category,
          'subcategory': subcategory,
          'description': description,
          'mapped_owasp': mappedOwasp,
          'mapped_cwe': mappedCwe,
          'severity_guideline': severityGuideline,
          'scope': finalScope,
        }),
      );
      if (response.statusCode == 200) {
        return json.decode(response.body)['id'];
      }
      throw Exception('Failed to add vulnerability classification');
    } catch (e, stack) {
      ErrorHandler.handle(e, stackTrace: stack, context: 'Insert vulnerability classification');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getVulnerabilityClassifications(int findingId) async {
    final response = await http.get(Uri.parse('$baseUrl/vulnerability-classifications/$findingId'));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    return [];
  }

  Future<void> deleteVulnerabilityClassification(int id) async {
    await http.delete(Uri.parse('$baseUrl/vulnerability-classifications/$id'));
  }



  Future<void> updateFlaggedFindingRecommendation(int findingId, String recommendation) async {
    await http.put(
      Uri.parse('$baseUrl/findings/$findingId/recommendation'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'recommendation': recommendation}),
    );
  }

  Future<void> updateFlaggedFindingEvidence(int findingId, String evidence) async {
    await http.put(
      Uri.parse('$baseUrl/findings/$findingId/evidence'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'evidence': evidence}),
    );
  }

  Future<Map<String, dynamic>?> getVulnerabilityClassificationByFindingId(int findingId) async {
    final response = await http.get(Uri.parse('$baseUrl/vulnerability-classifications/by-finding/$findingId'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data.isNotEmpty ? data : null;
    }
    return null;
  }

  Future<void> updateVulnerabilityClassification(int id, {
    String? category,
    String? subcategory,
    String? scope,
  }) async {
    await http.put(
      Uri.parse('$baseUrl/vulnerability-classifications/$id/update'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'category': category,
        'subcategory': subcategory,
        'scope': scope,
      }),
    );
  }

  // Completion status API endpoints for FINDINGS redesign
  Future<List<Map<String, dynamic>>> getCompleteFlaggedFindings(int projectId) async {
    final response = await http.get(Uri.parse('$baseUrl/projects/$projectId/findings/complete'));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> getIncompleteFlaggedFindings(int projectId) async {
    final response = await http.get(Uri.parse('$baseUrl/projects/$projectId/findings/incomplete'));
    if (response.statusCode == 200) {
      return List<Map<String, dynamic>>.from(json.decode(response.body));
    }
    return [];
  }

  Future<Map<String, dynamic>> getFindingCompletionStatus(int findingId) async {
    final response = await http.get(Uri.parse('$baseUrl/findings/$findingId/completion-status'));
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    return {
      'is_complete': false,
      'missing_criteria': ['evidence', 'recommendation', 'severity', 'category', 'subcategory', 'scope']
    };
  }

  Future<ReportSection?> getReportSection(int projectId, String sectionType) async {
    final response = await http.get(Uri.parse('$baseUrl/projects/$projectId/report-sections/$sectionType'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data != null ? ReportSection.fromMap(data) : null;
    }
    return null;
  }

  Future<void> saveReportSection(ReportSection section) async {
    await http.post(
      Uri.parse('$baseUrl/projects/${section.projectId}/report-sections'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(section.toMap()),
    );
  }

  Future<List<ReportSection>> getAllReportSections(int projectId) async {
    final response = await http.get(Uri.parse('$baseUrl/projects/$projectId/report-sections'));
    if (response.statusCode == 200) {
      final data = List<Map<String, dynamic>>.from(json.decode(response.body));
      return data.map((map) => ReportSection.fromMap(map)).toList();
    }
    return [];
  }

  Future<bool> hasNmapResults(int projectId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/projects/$projectId/has-nmap-results'));
      if (response.statusCode == 200) {
        return json.decode(response.body)['hasResults'] == true;
      }
      return false;
    } catch (e, stack) {
      ErrorHandler.handle(e, stackTrace: stack, context: 'Check NMap results');
      return false;
    }
  }

  Future<Set<int>> getDevicesWithNiktoFindings(int projectId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/projects/$projectId/devices-with-nikto'));
      if (response.statusCode == 200) {
        final data = List<int>.from(json.decode(response.body));
        return data.toSet();
      }
      return {};
    } catch (e, stack) {
      ErrorHandler.handle(e, stackTrace: stack, context: 'Get devices with Nikto findings');
      return {};
    }
  }

  Future<Set<int>> getDevicesWithSnmpFindings(int projectId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/projects/$projectId/devices-with-snmp'));
      if (response.statusCode == 200) {
        final data = List<int>.from(json.decode(response.body));
        return data.toSet();
      }
      return {};
    } catch (e, stack) {
      ErrorHandler.handle(e, stackTrace: stack, context: 'Get devices with SNMP findings');
      return {};
    }
  }

  Future<Set<int>> getDevicesWithNmapScripts(int projectId) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/projects/$projectId/devices-with-nmap-scripts'));
      if (response.statusCode == 200) {
        final data = List<int>.from(json.decode(response.body));
        return data.toSet();
      }
      return {};
    } catch (e, stack) {
      ErrorHandler.handle(e, stackTrace: stack, context: 'Get devices with Nmap Scripts');
      return {};
    }
  }
}
