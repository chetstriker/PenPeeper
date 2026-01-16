import 'package:flutter_test/flutter_test.dart';
import 'package:penpeeper/repositories/findings_repository.dart';
import 'package:penpeeper/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('Findings Completion Logic Tests', () {
    late FindingsRepository findingsRepo;
    late DatabaseHelper dbHelper;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      dbHelper = DatabaseHelper();
      findingsRepo = FindingsRepository();
      
      // Initialize the database
      await dbHelper.database;
    });

    tearDown(() async {
      // Clean up test data
      final db = await dbHelper.database;
      await db.delete('flagged_findings');
      await db.delete('vulnerability_classifications');
    });

    test('should identify complete finding with all required fields', () async {
      final db = await dbHelper.database;
      
      // Insert test finding with all required fields
      final findingId = await db.insert('flagged_findings', {
        'device_id': 1,
        'device_name': 'Test Device',
        'ip_address': '192.168.1.1',
        'type': 'Issue',
        'comment': 'Test evidence',
        'evidence': 'Test evidence',
        'recommendation': 'Test recommendation',
        'cvss_severity': 'HIGH',
        'created_at': DateTime.now().toIso8601String(),
        'project_id': 1,
      });

      await db.insert('vulnerability_classifications', {
        'project_id': 1,
        'device_id': 1,
        'finding_id': findingId,
        'category': 'Authentication',
        'subcategory': 'Weak Passwords',
        'description': 'Test description',
        'mapped_owasp': 'A07:2021',
        'mapped_cwe': 'CWE-521',
        'severity_guideline': 'HIGH',
        'scope': 'NETWORK',
        'created_at': DateTime.now().toIso8601String(),
      });

      final status = await findingsRepo.getFindingCompletionStatus(findingId);
      
      expect(status['is_complete'], true);
      expect(status['missing_criteria'], isEmpty);
    });

    test('should identify incomplete finding missing evidence', () async {
      final db = await dbHelper.database;
      
      final findingId = await db.insert('flagged_findings', {
        'device_id': 1,
        'device_name': 'Test Device',
        'ip_address': '192.168.1.1',
        'type': 'Issue',
        'comment': 'Test comment',
        'evidence': '', // Missing evidence
        'recommendation': 'Test recommendation',
        'cvss_severity': 'HIGH',
        'created_at': DateTime.now().toIso8601String(),
        'project_id': 1,
      });

      await db.insert('vulnerability_classifications', {
        'project_id': 1,
        'device_id': 1,
        'finding_id': findingId,
        'category': 'Authentication',
        'subcategory': 'Weak Passwords',
        'description': 'Test description',
        'mapped_owasp': 'A07:2021',
        'mapped_cwe': 'CWE-521',
        'severity_guideline': 'HIGH',
        'scope': 'NETWORK',
        'created_at': DateTime.now().toIso8601String(),
      });

      final status = await findingsRepo.getFindingCompletionStatus(findingId);
      
      expect(status['is_complete'], false);
      expect(status['missing_criteria'], contains('evidence'));
    });

    test('should identify incomplete finding missing classification', () async {
      final db = await dbHelper.database;
      
      final findingId = await db.insert('flagged_findings', {
        'device_id': 1,
        'device_name': 'Test Device',
        'ip_address': '192.168.1.1',
        'type': 'Issue',
        'comment': 'Test comment',
        'evidence': 'Test evidence',
        'recommendation': 'Test recommendation',
        'cvss_severity': 'HIGH',
        'created_at': DateTime.now().toIso8601String(),
        'project_id': 1,
      });

      // No classification inserted

      final status = await findingsRepo.getFindingCompletionStatus(findingId);
      
      expect(status['is_complete'], false);
      expect(status['missing_criteria'], containsAll(['category', 'subcategory', 'scope']));
    });

    test('should filter complete findings correctly', () async {
      final db = await dbHelper.database;
      
      // Insert complete finding
      final completeFindingId = await db.insert('flagged_findings', {
        'device_id': 1,
        'device_name': 'Complete Device',
        'ip_address': '192.168.1.1',
        'type': 'Issue',
        'comment': 'Complete comment',
        'evidence': 'Complete evidence',
        'recommendation': 'Complete recommendation',
        'cvss_severity': 'HIGH',
        'created_at': DateTime.now().toIso8601String(),
        'project_id': 1,
      });

      await db.insert('vulnerability_classifications', {
        'project_id': 1,
        'device_id': 1,
        'finding_id': completeFindingId,
        'category': 'Authentication',
        'subcategory': 'Weak Passwords',
        'description': 'Test description',
        'mapped_owasp': 'A07:2021',
        'mapped_cwe': 'CWE-521',
        'severity_guideline': 'HIGH',
        'scope': 'NETWORK',
        'created_at': DateTime.now().toIso8601String(),
      });

      // Insert incomplete finding
      await db.insert('flagged_findings', {
        'device_id': 2,
        'device_name': 'Incomplete Device',
        'ip_address': '192.168.1.2',
        'type': 'Issue',
        'comment': 'Test comment',
        'evidence': '', // Missing evidence
        'recommendation': 'Test recommendation',
        'cvss_severity': 'HIGH',
        'created_at': DateTime.now().toIso8601String(),
        'project_id': 1,
      });

      final completeFindings = await findingsRepo.getCompleteFlaggedFindings(1);
      final incompleteFindings = await findingsRepo.getIncompleteFlaggedFindings(1);

      expect(completeFindings.length, 1);
      expect(completeFindings.first['device_name'], 'Complete Device');
      expect(incompleteFindings.length, 1);
      expect(incompleteFindings.first['device_name'], 'Incomplete Device');
    });
  });
}