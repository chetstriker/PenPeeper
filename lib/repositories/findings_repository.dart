import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:penpeeper/repositories/base_repository.dart';
import 'package:penpeeper/database/connection/database_connection.dart';
import 'package:penpeeper/api_database_helper.dart';
import 'package:penpeeper/models/finding.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class FindingsRepository extends BaseRepository {
  final _dbConnection = DatabaseConnection();

  /// Empty quill document representation - treat as empty/missing for completion checks
  static const String _quillEmptyValue = '[{"insert":"\\n"}]';

  Future<int> insertFlaggedFinding(
    int deviceId,
    String deviceName,
    String ipAddress,
    String type,
    String comment, {
    String findingType = 'MANUAL',
    int? projectId,
    String? cveId,
    String? confidenceLevel,
    String? vulnerabilityType,
    String? url,
    String? cvssVersion,
    String? attackVector,
    String? attackComplexity,
    String? privilegesRequired,
    String? userInteraction,
    String? scope,
    String? confidentialityImpact,
    String? integrityImpact,
    String? availabilityImpact,
    double? cvssBaseScore,
    String? cvssSeverity,
    String? evidence,
    String? recommendation,
  }) async {
    final data = {
      'device_id': deviceId,
      'device_name': deviceName,
      'ip_address': ipAddress,
      'type': type,
      'comment': comment,
      'finding_type': findingType,
      'created_at': DateTime.now().toIso8601String(),
      if (projectId != null) 'project_id': projectId,
      if (cveId != null) 'cve_id': cveId,
      if (confidenceLevel != null) 'confidence_level': confidenceLevel,
      if (vulnerabilityType != null) 'vulnerability_type': vulnerabilityType,
      if (url != null) 'url': url,
      if (cvssVersion != null) 'cvss_version': cvssVersion,
      if (attackVector != null) 'attack_vector': attackVector,
      if (attackComplexity != null) 'attack_complexity': attackComplexity,
      if (privilegesRequired != null) 'privileges_required': privilegesRequired,
      if (userInteraction != null) 'user_interaction': userInteraction,
      if (scope != null) 'scope': scope,
      if (confidentialityImpact != null)
        'confidentiality_impact': confidentialityImpact,
      if (integrityImpact != null) 'integrity_impact': integrityImpact,
      if (availabilityImpact != null) 'availability_impact': availabilityImpact,
      if (cvssBaseScore != null) 'cvss_base_score': cvssBaseScore,
      if (cvssSeverity != null) 'cvss_severity': cvssSeverity,
      if (evidence != null) 'evidence': evidence,
      if (recommendation != null) 'recommendation': recommendation,
    };

    if (kIsWeb) {
      final response = await http.post(
        Uri.parse('${ApiDatabaseHelper.baseUrl}/findings'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(data),
      );
      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        return result['id'] as int;
      }
      throw Exception('Failed to create finding: ${response.statusCode}');
    }
    final db = await _dbConnection.database;
    return await db.insert('flagged_findings', data);
  }

  Future<List<Finding>> getFlaggedFindings(int projectId) async {
    if (kIsWeb) {
      final maps = await ApiDatabaseHelper().getFlaggedFindings(projectId);
      return maps.map((map) => Finding.fromMap(map)).toList();
    }
    final db = await _dbConnection.database;
    final maps = await db.rawQuery(
      '''
      SELECT ff.*, 
             CASE WHEN ff.device_id = 0 THEN NULL ELSE d.icon_type END as icon_type,
             ff.device_id
      FROM flagged_findings ff
      LEFT JOIN devices d ON ff.device_id = d.id AND ff.device_id != 0
      WHERE (ff.device_id = 0 AND ff.project_id = ?) OR (d.project_id = ?)
      ORDER BY ff.created_at DESC
    ''',
      [projectId, projectId],
    );
    return maps.map((map) => Finding.fromMap(map)).toList();
  }

  Future<List<Finding>> getFlaggedFindingsForDevice(int deviceId) async {
    if (kIsWeb) {
      final maps = await ApiDatabaseHelper().getFlaggedFindingsForDevice(
        deviceId,
      );
      return maps.map((map) => Finding.fromMap(map)).toList();
    }
    final db = await _dbConnection.database;
    final maps = await db.rawQuery(
      '''
      SELECT ff.*, vc.category, vc.subcategory, vc.scope as classification_scope
      FROM flagged_findings ff
      LEFT JOIN vulnerability_classifications vc ON ff.id = vc.finding_id
      WHERE ff.device_id = ?
      ORDER BY ff.created_at DESC
    ''',
      [deviceId],
    );
    return maps.map((map) => Finding.fromMap(map)).toList();
  }

  Future<void> deleteFlaggedFinding(int id) async {
    if (kIsWeb) {
      final response = await http.delete(
        Uri.parse('${ApiDatabaseHelper.baseUrl}/findings/$id'),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to delete finding: ${response.statusCode}');
      }
      return;
    }
    final db = await _dbConnection.database;
    await db.delete('flagged_findings', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateFlaggedFinding(int id, String type, String comment) async {
    if (kIsWeb) {
      final response = await http.put(
        Uri.parse('${ApiDatabaseHelper.baseUrl}/findings/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'type': type, 'comment': comment}),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to update finding: ${response.statusCode}');
      }
      return;
    }
    final db = await _dbConnection.database;
    await db.update(
      'flagged_findings',
      {'type': type, 'comment': comment},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateFlaggedFindingType(int id, String findingType) async {
    if (kIsWeb) {
      final response = await http.put(
        Uri.parse('${ApiDatabaseHelper.baseUrl}/findings/$id'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'finding_type': findingType}),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to update finding type: ${response.statusCode}');
      }
      return;
    }
    final db = await _dbConnection.database;
    await db.update(
      'flagged_findings',
      {'finding_type': findingType},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateFlaggedFindingCvss(
    int id, {
    String? attackVector,
    String? attackComplexity,
    String? privilegesRequired,
    String? userInteraction,
    String? scope,
    String? confidentialityImpact,
    String? integrityImpact,
    String? availabilityImpact,
    double? cvssBaseScore,
    String? cvssSeverity,
  }) async {
    if (kIsWeb) {
      final updates = <String, dynamic>{};
      if (attackVector != null) updates['attack_vector'] = attackVector;
      if (attackComplexity != null) updates['attack_complexity'] = attackComplexity;
      if (privilegesRequired != null) updates['privileges_required'] = privilegesRequired;
      if (userInteraction != null) updates['user_interaction'] = userInteraction;
      if (scope != null) updates['scope'] = scope;
      if (confidentialityImpact != null) updates['confidentiality_impact'] = confidentialityImpact;
      if (integrityImpact != null) updates['integrity_impact'] = integrityImpact;
      if (availabilityImpact != null) updates['availability_impact'] = availabilityImpact;
      if (cvssBaseScore != null) updates['cvss_base_score'] = cvssBaseScore;
      if (cvssSeverity != null) updates['cvss_severity'] = cvssSeverity;
      
      if (updates.isNotEmpty) {
        final response = await http.put(
          Uri.parse('${ApiDatabaseHelper.baseUrl}/findings/$id'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(updates),
        );
        if (response.statusCode != 200) {
          throw Exception('Failed to update CVSS data: ${response.statusCode}');
        }
      }
      return;
    }
    final db = await _dbConnection.database;
    final Map<String, dynamic> updates = {};
    if (attackVector != null) updates['attack_vector'] = attackVector;
    if (attackComplexity != null) {
      updates['attack_complexity'] = attackComplexity;
    }
    if (privilegesRequired != null) {
      updates['privileges_required'] = privilegesRequired;
    }
    if (userInteraction != null) updates['user_interaction'] = userInteraction;
    if (scope != null) updates['scope'] = scope;
    if (confidentialityImpact != null) {
      updates['confidentiality_impact'] = confidentialityImpact;
    }
    if (integrityImpact != null) updates['integrity_impact'] = integrityImpact;
    if (availabilityImpact != null) {
      updates['availability_impact'] = availabilityImpact;
    }
    if (cvssBaseScore != null) updates['cvss_base_score'] = cvssBaseScore;
    if (cvssSeverity != null) updates['cvss_severity'] = cvssSeverity;

    if (updates.isNotEmpty) {
      await db.update(
        'flagged_findings',
        updates,
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> updateFlaggedFindingCveData(
    int id, {
    String? cveId,
    String? confidenceLevel,
    String? vulnerabilityType,
    String? url,
    String? cvssVersion,
    String? findingType,
  }) async {
    final db = await _dbConnection.database;
    final Map<String, dynamic> updates = {};
    if (cveId != null) updates['cve_id'] = cveId;
    if (confidenceLevel != null) updates['confidence_level'] = confidenceLevel;
    if (vulnerabilityType != null) {
      updates['vulnerability_type'] = vulnerabilityType;
    }
    if (url != null) updates['url'] = url;
    if (cvssVersion != null) updates['cvss_version'] = cvssVersion;
    if (findingType != null) updates['finding_type'] = findingType;

    if (updates.isNotEmpty) {
      await db.update(
        'flagged_findings',
        updates,
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> updateFlaggedFindingRecommendation(
    int findingId,
    String recommendation,
  ) async {
    if (kIsWeb) {
      await ApiDatabaseHelper().updateFlaggedFindingRecommendation(
        findingId,
        recommendation,
      );
      return;
    }
    final db = await _dbConnection.database;
    await db.update(
      'flagged_findings',
      {'recommendation': recommendation},
      where: 'id = ?',
      whereArgs: [findingId],
    );
  }

  Future<void> updateFlaggedFindingEvidence(
    int findingId,
    String evidence,
  ) async {
    if (kIsWeb) {
      await ApiDatabaseHelper().updateFlaggedFindingEvidence(
        findingId,
        evidence,
      );
      return;
    }
    final db = await _dbConnection.database;
    await db.update(
      'flagged_findings',
      {'evidence': evidence},
      where: 'id = ?',
      whereArgs: [findingId],
    );
  }

  Future<List<Map<String, dynamic>>> getCompleteFlaggedFindings(
    int projectId,
  ) async {
    if (kIsWeb) {
      return await ApiDatabaseHelper().getCompleteFlaggedFindings(projectId);
    }
    final db = await _dbConnection.database;
    return await db.rawQuery(
      '''
      SELECT ff.*,
             CASE WHEN ff.device_id = 0 THEN NULL ELSE d.icon_type END as icon_type,
             ff.device_id
      FROM flagged_findings ff
      LEFT JOIN devices d ON ff.device_id = d.id AND ff.device_id != 0
      LEFT JOIN vulnerability_classifications vc ON ff.id = vc.finding_id
      WHERE ((ff.device_id = 0 AND ff.project_id = ?) OR (d.project_id = ?))
        AND ff.evidence IS NOT NULL AND ff.evidence != '' AND ff.evidence != ?
        AND ff.recommendation IS NOT NULL AND ff.recommendation != '' AND ff.recommendation != ?
        AND ff.cvss_severity IS NOT NULL AND ff.cvss_severity != ''
        AND vc.category IS NOT NULL AND vc.category != ''
        AND vc.subcategory IS NOT NULL AND vc.subcategory != ''
        AND vc.scope IS NOT NULL AND vc.scope != ''
      ORDER BY ff.created_at DESC
    ''',
      [projectId, projectId, _quillEmptyValue, _quillEmptyValue],
    );
  }

  Future<List<Map<String, dynamic>>> getIncompleteFlaggedFindings(
    int projectId,
  ) async {
    if (kIsWeb) {
      return await ApiDatabaseHelper().getIncompleteFlaggedFindings(projectId);
    }
    final db = await _dbConnection.database;
    return await db.rawQuery(
      '''
      SELECT ff.*,
             CASE WHEN ff.device_id = 0 THEN NULL ELSE d.icon_type END as icon_type,
             ff.device_id
      FROM flagged_findings ff
      LEFT JOIN devices d ON ff.device_id = d.id AND ff.device_id != 0
      LEFT JOIN vulnerability_classifications vc ON ff.id = vc.finding_id
      WHERE ((ff.device_id = 0 AND ff.project_id = ?) OR (d.project_id = ?))
        AND (ff.evidence IS NULL OR ff.evidence = '' OR ff.evidence = ?
             OR ff.recommendation IS NULL OR ff.recommendation = '' OR ff.recommendation = ?
             OR ff.cvss_severity IS NULL OR ff.cvss_severity = ''
             OR vc.category IS NULL OR vc.category = ''
             OR vc.subcategory IS NULL OR vc.subcategory = ''
             OR vc.scope IS NULL OR vc.scope = '')
      ORDER BY ff.created_at DESC
    ''',
      [projectId, projectId, _quillEmptyValue, _quillEmptyValue],
    );
  }

  Future<Map<String, dynamic>> getFindingCompletionStatus(int findingId) async {
    if (kIsWeb) {
      return await ApiDatabaseHelper().getFindingCompletionStatus(findingId);
    }
    final db = await _dbConnection.database;
    final results = await db.rawQuery(
      '''
      SELECT 
        ff.evidence,
        ff.recommendation,
        ff.cvss_severity,
        vc.category,
        vc.subcategory,
        vc.scope
      FROM flagged_findings ff
      LEFT JOIN vulnerability_classifications vc ON ff.id = vc.finding_id
      WHERE ff.id = ?
    ''',
      [findingId],
    );

    if (results.isEmpty) {
      return {
        'is_complete': false,
        'missing_criteria': [
          'evidence',
          'recommendation',
          'severity',
          'category',
          'subcategory',
          'scope',
        ],
      };
    }

    final finding = results.first;
    final missingCriteria = <String>[];

    if (_isEmptyQuillField(finding['evidence'])) {
      missingCriteria.add('evidence');
    }
    if (_isEmptyQuillField(finding['recommendation'])) {
      missingCriteria.add('recommendation');
    }
    if (finding['cvss_severity'] == null || finding['cvss_severity'] == '') {
      missingCriteria.add('severity');
    }
    if (finding['category'] == null || finding['category'] == '') {
      missingCriteria.add('category');
    }
    if (finding['subcategory'] == null || finding['subcategory'] == '') {
      missingCriteria.add('subcategory');
    }
    if (finding['scope'] == null || finding['scope'] == '') {
      missingCriteria.add('scope');
    }

    return {
      'is_complete': missingCriteria.isEmpty,
      'missing_criteria': missingCriteria,
    };
  }

  /// Checks if a quill field value is effectively empty (null, empty string, or quill empty doc)
  static bool _isEmptyQuillField(dynamic value) {
    if (value == null) return true;
    if (value == '') return true;
    if (value == _quillEmptyValue) return true;
    return false;
  }

  Future<List<Map<String, dynamic>>> getFindingsByCompletionStatus(
    int projectId,
    bool isComplete,
  ) async {
    return isComplete
        ? await getCompleteFlaggedFindings(projectId)
        : await getIncompleteFlaggedFindings(projectId);
  }

  Future<List<Map<String, dynamic>>> getFlaggedFindingsRaw(
    int projectId,
  ) async {
    if (kIsWeb) {
      return await ApiDatabaseHelper().getFlaggedFindings(projectId);
    }
    final db = await _dbConnection.database;
    return await db.rawQuery(
      '''
      SELECT ff.*, 
             CASE WHEN ff.device_id = 0 THEN NULL ELSE d.icon_type END as icon_type,
             ff.device_id
      FROM flagged_findings ff
      LEFT JOIN devices d ON ff.device_id = d.id AND ff.device_id != 0
      WHERE (ff.device_id = 0 AND ff.project_id = ?) OR (d.project_id = ?)
      ORDER BY ff.created_at DESC
    ''',
      [projectId, projectId],
    );
  }

  Future<List<Map<String, dynamic>>> getFlaggedFindingsForDeviceRaw(
    int deviceId,
  ) async {
    if (kIsWeb) {
      return await ApiDatabaseHelper().getFlaggedFindingsForDevice(deviceId);
    }
    final db = await _dbConnection.database;
    return await db.rawQuery(
      '''
      SELECT ff.*, vc.category, vc.subcategory, vc.scope as classification_scope
      FROM flagged_findings ff
      LEFT JOIN vulnerability_classifications vc ON ff.id = vc.finding_id
      WHERE ff.device_id = ?
      ORDER BY ff.created_at DESC
    ''',
      [deviceId],
    );
  }
}
