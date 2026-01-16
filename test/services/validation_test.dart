import 'package:flutter_test/flutter_test.dart';
import 'package:penpeeper/services/export_import/validation_service.dart';

void main() {
  group('ValidationService', () {
    final service = ValidationService();

    group('validateArchiveStructure', () {
      test('should pass with valid structure', () {
        final metadata = {
          'version': '1.0',
          'exportedAt': '2024-01-01T00:00:00.000Z',
          'projects': [{'name': 'Test'}],
        };
        final projects = [{'name': 'Test'}];

        final result = service.validateArchiveStructure(metadata, projects);

        expect(result.isValid, true);
        expect(result.errors, isEmpty);
      });

      test('should fail with missing version', () {
        final metadata = {
          'exportedAt': '2024-01-01T00:00:00.000Z',
          'projects': [],
        };

        final result = service.validateArchiveStructure(metadata, []);

        expect(result.isValid, false);
        expect(result.errors, contains('Missing version field'));
      });

      test('should fail with unsupported version', () {
        final metadata = {
          'version': '2.0',
          'exportedAt': '2024-01-01T00:00:00.000Z',
          'projects': [],
        };

        final result = service.validateArchiveStructure(metadata, []);

        expect(result.isValid, false);
        expect(result.errors, contains('Unsupported version: 2.0'));
      });
    });

    group('validateProjectData', () {
      test('should pass with valid project', () {
        final project = {
          'name': 'Test Project',
          'created_at': '2024-01-01T00:00:00.000Z',
          'devices': [],
        };

        final result = service.validateProjectData(project);

        expect(result.isValid, true);
        expect(result.errors, isEmpty);
      });

      test('should fail with empty name', () {
        final project = {'name': ''};

        final result = service.validateProjectData(project);

        expect(result.isValid, false);
        expect(result.errors, contains('Project name is required'));
      });

      test('should fail with invalid CVSS score', () {
        final project = {
          'name': 'Test',
          'findings': [
            {'cvss_base_score': 15.0}
          ],
        };

        final result = service.validateProjectData(project);

        expect(result.isValid, false);
        expect(result.errors.first, contains('CVSS score must be between 0.0 and 10.0'));
      });
    });

    group('validateForeignKeys', () {
      test('should pass with valid references', () {
        final project = {
          'devices': [{'id': 1}],
          'nmap_hosts': [{'id': 10, 'device_id': 1}],
          'nmap_ports': [{'id': 100, 'host_id': 10}],
        };

        final errors = service.validateForeignKeys(project);

        expect(errors, isEmpty);
      });

      test('should fail with invalid device reference', () {
        final project = {
          'devices': [{'id': 1}],
          'nmap_hosts': [{'id': 10, 'device_id': 999}],
        };

        final errors = service.validateForeignKeys(project);

        expect(errors, isNotEmpty);
        expect(errors.first, contains('references non-existent device'));
      });
    });

    group('validateFileReferences', () {
      test('should pass with valid paths', () {
        final project = {
          'upload_files': [
            {'file_path': 'uploads/project/file.png'}
          ],
        };

        final result = service.validateFileReferences(project);

        expect(result, true);
      });

      test('should fail with path traversal', () {
        final project = {
          'upload_files': [
            {'file_path': '../../../etc/passwd'}
          ],
        };

        final result = service.validateFileReferences(project);

        expect(result, false);
      });
    });
  });
}
