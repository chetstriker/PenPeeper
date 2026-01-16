import 'package:flutter/foundation.dart';
import 'package:penpeeper/database_helper.dart';
import 'package:penpeeper/utils/pdf_debug_helper.dart';

/// Utility to query and debug specific findings
class FindingDebugQuery {
  /// Queries finding by ID and runs comprehensive debug analysis
  static Future<void> debugFinding(int findingId) async {
    debugPrint('\n========================================');
    debugPrint('FINDING DEBUG QUERY: ID $findingId');
    debugPrint('========================================\n');
    
    try {
      final db = await DatabaseHelper().database;
      final results = await db.query(
        'flagged_findings',
        where: 'id = ?',
        whereArgs: [findingId],
      );
      
      if (results.isEmpty) {
        debugPrint('ERROR: Finding ID $findingId not found');
        return;
      }
      
      final finding = results.first;
      
      // Print basic info
      debugPrint('=== BASIC INFO ===');
      debugPrint('ID: ${finding['id']}');
      debugPrint('Device ID: ${finding['device_id']}');
      debugPrint('Device Name: ${finding['device_name']}');
      debugPrint('IP Address: ${finding['ip_address']}');
      debugPrint('Type: ${finding['type']}');
      debugPrint('Finding Type: ${finding['finding_type']}');
      debugPrint('CVE ID: ${finding['cve_id']}');
      debugPrint('CVSS Score: ${finding['cvss_base_score']}');
      debugPrint('CVSS Severity: ${finding['cvss_severity']}');
      debugPrint('');
      
      // Print field lengths
      debugPrint('=== FIELD LENGTHS ===');
      final comment = finding['comment'] as String?;
      final evidence = finding['evidence'] as String?;
      final recommendation = finding['recommendation'] as String?;
      
      debugPrint('Comment: ${comment?.length ?? 0} characters');
      debugPrint('Evidence: ${evidence?.length ?? 0} characters');
      debugPrint('Recommendation: ${recommendation?.length ?? 0} characters');
      debugPrint('');
      
      // Get project name
      final projectId = finding['project_id'];
      final projectResults = await db.query(
        'projects',
        columns: ['name'],
        where: 'id = ?',
        whereArgs: [projectId],
      );
      final projectName = projectResults.isNotEmpty ? projectResults.first['name'] as String : 'Unknown';
      
      debugPrint('Project: $projectName (ID: $projectId)');
      debugPrint('');
      
      // Dump raw delta JSON
      PdfDebugHelper.dumpDeltaJson(finding);
      
      // Analyze content
      debugPrint('\n=== CONTENT ANALYSIS ===');
      final analysis = await PdfDebugHelper.analyzeFinding(finding, projectName);
      
      debugPrint('\nComment Analysis:');
      final commentAnalysis = analysis['comment_analysis'] as Map<String, dynamic>;
      debugPrint('  Has Content: ${commentAnalysis['has_content']}');
      debugPrint('  Text Length: ${commentAnalysis['text_length']}');
      debugPrint('  Image Count: ${commentAnalysis['image_count']}');
      debugPrint('  Estimated Pages: ${commentAnalysis['estimated_pages']}');
      if (commentAnalysis['issues'] != null && (commentAnalysis['issues'] as List).isNotEmpty) {
        debugPrint('  ISSUES:');
        for (final issue in commentAnalysis['issues'] as List) {
          debugPrint('    - $issue');
        }
      }
      
      if (commentAnalysis['image_count'] > 0) {
        debugPrint('  Image Details:');
        for (final imageInfo in commentAnalysis['image_details'] as List) {
          debugPrint('    Image ${imageInfo['image_number']}:');
          debugPrint('      Status: ${imageInfo['status']}');
          debugPrint('      Source: ${imageInfo['source']}');
          if (imageInfo['size_mb'] != null) {
            debugPrint('      Size: ${imageInfo['size_mb']} MB');
          }
          if (imageInfo['has_issue'] == true) {
            debugPrint('      ISSUE: ${imageInfo['issue']}');
          }
        }
      }
      
      debugPrint('\nEvidence Analysis:');
      final evidenceAnalysis = analysis['recommendation_analysis'] as Map<String, dynamic>;
      debugPrint('  Has Content: ${evidenceAnalysis['has_content']}');
      debugPrint('  Text Length: ${evidenceAnalysis['text_length']}');
      debugPrint('  Image Count: ${evidenceAnalysis['image_count']}');
      debugPrint('  Estimated Pages: ${evidenceAnalysis['estimated_pages']}');
      if (evidenceAnalysis['issues'] != null && (evidenceAnalysis['issues'] as List).isNotEmpty) {
        debugPrint('  ISSUES:');
        for (final issue in evidenceAnalysis['issues'] as List) {
          debugPrint('    - $issue');
        }
      }
      
      if (evidenceAnalysis['image_count'] > 0) {
        debugPrint('  Image Details:');
        for (final imageInfo in evidenceAnalysis['image_details'] as List) {
          debugPrint('    Image ${imageInfo['image_number']}:');
          debugPrint('      Status: ${imageInfo['status']}');
          debugPrint('      Source: ${imageInfo['source']}');
          if (imageInfo['size_mb'] != null) {
            debugPrint('      Size: ${imageInfo['size_mb']} MB');
          }
          if (imageInfo['has_issue'] == true) {
            debugPrint('      ISSUE: ${imageInfo['issue']}');
          }
        }
      }
      
      // Test rendering
      debugPrint('\n=== RENDER TEST ===');
      final renderTest = await PdfDebugHelper.testRenderFinding(finding, projectName);
      debugPrint('Comment Widgets: ${renderTest['comment_widgets']}');
      debugPrint('Recommendation Widgets: ${renderTest['recommendation_widgets']}');
      debugPrint('Total Widgets: ${renderTest['total_widgets']}');
      
      if (renderTest['errors'] != null && (renderTest['errors'] as List).isNotEmpty) {
        debugPrint('RENDER ERRORS:');
        for (final error in renderTest['errors'] as List) {
          debugPrint('  - $error');
        }
      }
      
      debugPrint('\n========================================');
      debugPrint('DEBUG QUERY COMPLETE');
      debugPrint('========================================\n');
      
    } catch (e, stack) {
      debugPrint('ERROR during debug query: $e');
      debugPrint('Stack: $stack');
    }
  }
}
