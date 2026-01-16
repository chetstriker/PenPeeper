import 'package:flutter_test/flutter_test.dart';
import 'package:penpeeper/models/report_models.dart';
import 'package:penpeeper/services/pdf_report_generator.dart';
import 'package:penpeeper/models/pdf_generation_status.dart';

void main() {
  group('PDF Report Generation Tests', () {
    test('PdfGenerationStatus factory methods work correctly', () {
      final idle = PdfGenerationStatus.idle();
      expect(idle.state, PdfGenerationState.idle);
      expect(idle.progress, 0.0);

      final preparing = PdfGenerationStatus.preparing();
      expect(preparing.state, PdfGenerationState.preparing);
      expect(preparing.progress, 0.1);

      final generating = PdfGenerationStatus.generating('Test Section', 0.5);
      expect(generating.state, PdfGenerationState.generating);
      expect(generating.message, 'Generating Test Section...');
      expect(generating.progress, 0.5);

      final completed = PdfGenerationStatus.completed('/path/to/file.pdf');
      expect(completed.state, PdfGenerationState.completed);
      expect(completed.progress, 1.0);

      final error = PdfGenerationStatus.error('Test error');
      expect(error.state, PdfGenerationState.error);
      expect(error.errorMessage, 'Test error');
    });

    test('ReportData can be created with empty findings', () {
      final reportData = ReportData(
        findings: [],
        groupedFindings: {},
        availableTags: [],
      );

      expect(reportData.findings, isEmpty);
      expect(reportData.groupedFindings, isEmpty);
      expect(reportData.availableTags, isEmpty);
    });

    test('ReportFinding can be created from map', () {
      final map = {
        'id': 1,
        'device_id': 10,
        'device_name': 'Test Device',
        'ip_address': '192.168.1.1',
        'type': 'SQL Injection',
        'comment': 'Test comment',
        'created_at': DateTime.now().toIso8601String(),
      };

      final finding = ReportFinding.fromMap(map);
      expect(finding.id, 1);
      expect(finding.deviceId, 10);
      expect(finding.deviceName, 'Test Device');
      expect(finding.ipAddress, '192.168.1.1');
      expect(finding.type, 'SQL Injection');
    });

    test('PdfReportGenerator can be instantiated', () {
      final generator = PdfReportGenerator();
      expect(generator, isNotNull);
      expect(generator.statusStream, isNotNull);
      generator.dispose();
    });

    test('PDF generation handles empty report data', () async {
      final generator = PdfReportGenerator();
      final reportData = ReportData(
        findings: [],
        groupedFindings: {},
        availableTags: [],
      );

      try {
        final pdf = await generator.generatePdfDocument(reportData);
        expect(pdf, isNotNull);
      } finally {
        generator.dispose();
      }
    });

    test('PDF generation handles report with sections', () async {
      final generator = PdfReportGenerator();
      final reportData = ReportData(
        findings: [],
        groupedFindings: {},
        availableTags: [],
        reportHeader: 'Test Report',
        executiveSummary: 'This is a test summary.',
        methodologyScope: 'Test methodology.',
        riskRatingModel: 'Test risk model.',
        conclusion: 'Test conclusion.',
      );

      try {
        final pdf = await generator.generatePdfDocument(reportData);
        expect(pdf, isNotNull);
      } finally {
        generator.dispose();
      }
    });
  });
}
