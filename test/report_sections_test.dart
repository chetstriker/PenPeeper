import 'package:flutter_test/flutter_test.dart';
import 'package:penpeeper/models/report_section.dart';
import 'package:penpeeper/constants/report_section_examples.dart';

void main() {
  group('ReportSection Model Tests', () {
    test('toMap converts model to map correctly', () {
      final now = DateTime.now();
      final section = ReportSection(
        id: 1,
        projectId: 1,
        sectionType: 'executive_summary',
        content: '{"ops":[{"insert":"test"}]}',
        createdAt: now,
        updatedAt: now,
      );

      final map = section.toMap();

      expect(map['id'], 1);
      expect(map['project_id'], 1);
      expect(map['section_type'], 'executive_summary');
      expect(map['content'], '{"ops":[{"insert":"test"}]}');
      expect(map['created_at'], now.toIso8601String());
      expect(map['updated_at'], now.toIso8601String());
    });

    test('fromMap creates model from map correctly', () {
      final now = DateTime.now();
      final map = {
        'id': 1,
        'project_id': 1,
        'section_type': 'methodology_scope',
        'content': '{"ops":[{"insert":"test"}]}',
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final section = ReportSection.fromMap(map);

      expect(section.id, 1);
      expect(section.projectId, 1);
      expect(section.sectionType, 'methodology_scope');
      expect(section.content, '{"ops":[{"insert":"test"}]}');
      expect(section.createdAt, now);
      expect(section.updatedAt, now);
    });

    test('model handles null id correctly', () {
      final now = DateTime.now();
      final section = ReportSection(
        projectId: 1,
        sectionType: 'risk_rating_model',
        content: '{}',
        createdAt: now,
        updatedAt: now,
      );

      expect(section.id, isNull);
      expect(section.projectId, 1);
    });
  });

  group('ReportSectionExamples Tests', () {
    test('executive summary example is not empty', () {
      expect(ReportSectionExamples.executiveSummary, isNotEmpty);
      expect(ReportSectionExamples.executiveSummary.length, greaterThan(100));
    });

    test('methodology scope example is not empty', () {
      expect(ReportSectionExamples.methodologyScope, isNotEmpty);
      expect(ReportSectionExamples.methodologyScope.length, greaterThan(100));
    });

    test('risk rating model example is not empty', () {
      expect(ReportSectionExamples.riskRatingModel, isNotEmpty);
      expect(ReportSectionExamples.riskRatingModel.length, greaterThan(100));
    });

    test('conclusion example is not empty', () {
      expect(ReportSectionExamples.conclusion, isNotEmpty);
      expect(ReportSectionExamples.conclusion.length, greaterThan(100));
    });

    test('executive summary description is not empty', () {
      expect(ReportSectionExamples.executiveSummaryDescription, isNotEmpty);
      expect(ReportSectionExamples.executiveSummaryDescription, contains('decision-makers'));
    });

    test('methodology scope description is not empty', () {
      expect(ReportSectionExamples.methodologyScopeDescription, isNotEmpty);
      expect(ReportSectionExamples.methodologyScopeDescription, contains('Scope'));
    });

    test('risk rating model description is not empty', () {
      expect(ReportSectionExamples.riskRatingModelDescription, isNotEmpty);
      expect(ReportSectionExamples.riskRatingModelDescription, contains('risk scores'));
    });

    test('conclusion description is not empty', () {
      expect(ReportSectionExamples.conclusionDescription, isNotEmpty);
      expect(ReportSectionExamples.conclusionDescription, contains('summary'));
    });

    test('examples contain realistic content', () {
      expect(ReportSectionExamples.executiveSummary, contains('Critical'));
      expect(ReportSectionExamples.methodologyScope, contains('Testing Approach'));
      expect(ReportSectionExamples.riskRatingModel, contains('CVSS'));
      expect(ReportSectionExamples.conclusion, contains('Priority Actions'));
    });
  });

  group('Section Type Validation Tests', () {
    test('valid section types', () {
      final validTypes = [
        'executive_summary',
        'methodology_scope',
        'risk_rating_model',
        'conclusion',
      ];

      for (final type in validTypes) {
        final section = ReportSection(
          projectId: 1,
          sectionType: type,
          content: '{}',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        expect(section.sectionType, type);
      }
    });

    test('section types use underscore format', () {
      expect('executive_summary', contains('_'));
      expect('methodology_scope', contains('_'));
      expect('risk_rating_model', contains('_'));
      expect('conclusion', isNot(contains('_')));
    });
  });

  group('Content Format Tests', () {
    test('content should be valid JSON string', () {
      final validContent = '{"ops":[{"insert":"test"}]}';
      final section = ReportSection(
        projectId: 1,
        sectionType: 'executive_summary',
        content: validContent,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(section.content, validContent);
      expect(() => section.content, returnsNormally);
    });

    test('empty content is allowed', () {
      final section = ReportSection(
        projectId: 1,
        sectionType: 'executive_summary',
        content: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(section.content, isEmpty);
    });
  });

  group('Timestamp Tests', () {
    test('createdAt and updatedAt are set correctly', () {
      final now = DateTime.now();
      final section = ReportSection(
        projectId: 1,
        sectionType: 'executive_summary',
        content: '{}',
        createdAt: now,
        updatedAt: now,
      );

      expect(section.createdAt, now);
      expect(section.updatedAt, now);
    });

    test('updatedAt can be different from createdAt', () {
      final created = DateTime.now();
      final updated = created.add(const Duration(hours: 1));
      
      final section = ReportSection(
        projectId: 1,
        sectionType: 'executive_summary',
        content: '{}',
        createdAt: created,
        updatedAt: updated,
      );

      expect(section.updatedAt.isAfter(section.createdAt), isTrue);
    });
  });
}
