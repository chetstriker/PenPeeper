import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:penpeeper/database/connection/database_connection.dart';

class FindingsRoutes {
  static Future<shelf.Response?> handle(
    shelf.Request request,
    List<String> parts,
  ) async {
    debugPrint('FindingsRoutes: ${request.method} ${parts.join('/')} - parts.length=${parts.length}');
    if (parts.isNotEmpty) debugPrint('parts[0]=${parts[0]}');
    if (parts.length > 1) debugPrint('parts[1]=${parts[1]}');
    final dbConnection = DatabaseConnection();

    // Handle findings routes first
    if (parts.isNotEmpty && parts[0] == 'findings') {
      // POST /api/findings
      if (parts.length == 1 && request.method == 'POST') {
        final body = json.decode(await request.readAsString());
        final db = await dbConnection.database;
        
        final data = <String, dynamic>{
          'device_id': body['device_id'],
          'device_name': body['device_name'],
          'ip_address': body['ip_address'],
          'type': body['type'],
          'comment': body['comment'],
          'project_id': body['project_id'],
          'finding_type': body['finding_type'] ?? 'MANUAL',
          'created_at': DateTime.now().toIso8601String(),
        };
        
        // Add optional CVSS and CVE fields
        if (body['cve_id'] != null) data['cve_id'] = body['cve_id'];
        if (body['confidence_level'] != null) data['confidence_level'] = body['confidence_level'];
        if (body['vulnerability_type'] != null) data['vulnerability_type'] = body['vulnerability_type'];
        if (body['url'] != null) data['url'] = body['url'];
        if (body['cvss_version'] != null) data['cvss_version'] = body['cvss_version'];
        if (body['attack_vector'] != null) data['attack_vector'] = body['attack_vector'];
        if (body['attack_complexity'] != null) data['attack_complexity'] = body['attack_complexity'];
        if (body['privileges_required'] != null) data['privileges_required'] = body['privileges_required'];
        if (body['user_interaction'] != null) data['user_interaction'] = body['user_interaction'];
        if (body['scope'] != null) data['scope'] = body['scope'];
        if (body['confidentiality_impact'] != null) data['confidentiality_impact'] = body['confidentiality_impact'];
        if (body['integrity_impact'] != null) data['integrity_impact'] = body['integrity_impact'];
        if (body['availability_impact'] != null) data['availability_impact'] = body['availability_impact'];
        if (body['cvss_base_score'] != null) data['cvss_base_score'] = body['cvss_base_score'];
        if (body['cvss_severity'] != null) data['cvss_severity'] = body['cvss_severity'];
        if (body['evidence'] != null) data['evidence'] = body['evidence'];
        if (body['recommendation'] != null) data['recommendation'] = body['recommendation'];
        
        final id = await db.insert('flagged_findings', data);
        return _jsonResponse({'id': id});
      }

      // DELETE /api/findings/:id
      if (parts.length == 2 && request.method == 'DELETE') {
        final findingId = int.tryParse(parts[1]);
        if (findingId != null) {
          final db = await dbConnection.database;
          await db.delete('flagged_findings', where: 'id = ?', whereArgs: [findingId]);
          return _jsonResponse({'success': true});
        }
      }

      // PUT /api/findings/:id
      if (parts.length == 2 && request.method == 'PUT') {
        final findingId = int.tryParse(parts[1]);
        if (findingId != null) {
          final body = json.decode(await request.readAsString());
          final db = await dbConnection.database;
          
          final updates = <String, dynamic>{};
          if (body['type'] != null) updates['type'] = body['type'];
          if (body['comment'] != null) updates['comment'] = body['comment'];
          if (body['attack_vector'] != null) updates['attack_vector'] = body['attack_vector'];
          if (body['attack_complexity'] != null) updates['attack_complexity'] = body['attack_complexity'];
          if (body['privileges_required'] != null) updates['privileges_required'] = body['privileges_required'];
          if (body['user_interaction'] != null) updates['user_interaction'] = body['user_interaction'];
          if (body['scope'] != null) updates['scope'] = body['scope'];
          if (body['confidentiality_impact'] != null) updates['confidentiality_impact'] = body['confidentiality_impact'];
          if (body['integrity_impact'] != null) updates['integrity_impact'] = body['integrity_impact'];
          if (body['availability_impact'] != null) updates['availability_impact'] = body['availability_impact'];
          if (body['cvss_base_score'] != null) updates['cvss_base_score'] = body['cvss_base_score'];
          if (body['cvss_severity'] != null) updates['cvss_severity'] = body['cvss_severity'];
          
          if (updates.isNotEmpty) {
            await db.update(
              'flagged_findings',
              updates,
              where: 'id = ?',
              whereArgs: [findingId],
            );
          }
          return _jsonResponse({'success': true});
        }
      }

      // PUT /api/findings/:id/recommendation
      if (parts.length == 3 && parts[2] == 'recommendation' && request.method == 'PUT') {
        final findingId = int.tryParse(parts[1]);
        if (findingId != null) {
          final body = json.decode(await request.readAsString());
          final db = await dbConnection.database;
          await db.update(
            'flagged_findings',
            {'recommendation': body['recommendation']},
            where: 'id = ?',
            whereArgs: [findingId],
          );
          return _jsonResponse({'success': true});
        }
      }

      // PUT /api/findings/:id/evidence
      if (parts.length == 3 && parts[2] == 'evidence' && request.method == 'PUT') {
        final findingId = int.tryParse(parts[1]);
        if (findingId != null) {
          final body = json.decode(await request.readAsString());
          final db = await dbConnection.database;
          await db.update(
            'flagged_findings',
            {'evidence': body['evidence']},
            where: 'id = ?',
            whereArgs: [findingId],
          );
          return _jsonResponse({'success': true});
        }
      }

      // GET /api/findings/:id/completion-status
      if (parts.length == 3 && parts[2] == 'completion-status' && request.method == 'GET') {
        final findingId = int.tryParse(parts[1]);
        if (findingId != null) {
          try {
            final db = await dbConnection.database;
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
              return _jsonResponse({
                'is_complete': false,
                'missing_criteria': [
                  'evidence',
                  'recommendation',
                  'severity',
                  'category',
                  'subcategory',
                  'scope',
                ],
              });
            }

            final finding = results.first;
            final missingCriteria = <String>[];

            if (finding['evidence'] == null || finding['evidence'] == '') {
              missingCriteria.add('evidence');
            }
            if (finding['recommendation'] == null || finding['recommendation'] == '') {
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

            return _jsonResponse({
              'is_complete': missingCriteria.isEmpty,
              'missing_criteria': missingCriteria,
            });
          } catch (e, stackTrace) {
            print('[FindingsRoutes] Error getting completion status for finding $findingId: $e');
            print('[FindingsRoutes] Stack: $stackTrace');
            return _jsonResponse({
              'is_complete': false,
              'missing_criteria': ['evidence', 'recommendation', 'severity', 'category', 'subcategory', 'scope'],
            });
          }
        }
      }
    }

    // Handle vulnerability-classifications routes
    if (parts.isNotEmpty && parts[0] == 'vulnerability-classifications') {
      // POST /api/vulnerability-classifications
      if (parts.length == 1 && request.method == 'POST') {
        final body = json.decode(await request.readAsString());
        final db = await dbConnection.database;
        final id = await db.insert('vulnerability_classifications', {
          'project_id': body['project_id'],
          'device_id': body['device_id'],
          'finding_id': body['finding_id'],
          'category': body['category'],
          'subcategory': body['subcategory'],
          'description': body['description'],
          'mapped_owasp': body['mapped_owasp'],
          'mapped_cwe': body['mapped_cwe'],
          'severity_guideline': body['severity_guideline'],
          'scope': body['scope'] ?? 'NETWORK',
          'created_at': DateTime.now().toIso8601String(),
        });
        return _jsonResponse({'id': id});
      }

      // GET /api/vulnerability-classifications/:findingId
      if (parts.length == 2 && request.method == 'GET') {
        final findingId = int.tryParse(parts[1]);
        if (findingId != null) {
          try {
            final db = await dbConnection.database;
            final results = await db.query(
              'vulnerability_classifications',
              where: 'finding_id = ?',
              whereArgs: [findingId],
              limit: 1,
            );
            if (results.isNotEmpty) {
              return _jsonResponse(results.first);
            }
            return shelf.Response.notFound(json.encode({'error': 'Classification not found'}));
          } catch (e) {
            return shelf.Response.notFound(json.encode({'error': 'Classification not found'}));
          }
        }
      }
    }

    return null;
  }

  static shelf.Response _jsonResponse(dynamic data) {
    return shelf.Response.ok(
      json.encode(data),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
