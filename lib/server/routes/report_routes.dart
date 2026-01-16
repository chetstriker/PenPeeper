import 'dart:convert';
import 'package:shelf/shelf.dart' as shelf;
import 'package:penpeeper/database_helper.dart';
import 'package:penpeeper/repositories/findings_repository.dart';
import 'package:penpeeper/repositories/vulnerability_repository.dart';
import 'package:penpeeper/repositories/tag_repository.dart';
import 'package:penpeeper/database/connection/database_connection.dart';
import 'package:penpeeper/services/quill_parser.dart';
import 'package:penpeeper/services/pdf_report_generator.dart';
import 'package:penpeeper/services/report_service.dart';

class ReportRoutes {
  static Future<shelf.Response?> handle(
    shelf.Request request,
    List<String> parts,
    DatabaseHelper db,
  ) async {
    if (parts.isEmpty || parts[0] != 'projects') return null;

    final projectId = int.tryParse(parts[1]);
    if (projectId == null) return null;

    final dbConnection = DatabaseConnection();

    // GET /api/projects/:id/report-sections/:sectionType
    if (parts.length == 4 &&
        parts[2] == 'report-sections' &&
        request.method == 'GET') {
      final sectionType = parts[3];
      final db = await dbConnection.database;
      final results = await db.query(
        'report_sections',
        where: 'project_id = ? AND section_type = ?',
        whereArgs: [projectId, sectionType],
        limit: 1,
      );
      return _jsonResponse(results.isNotEmpty ? results.first : null);
    }

    // POST /api/projects/:id/report-sections
    if (parts.length == 3 &&
        parts[2] == 'report-sections' &&
        request.method == 'POST') {
      final body = json.decode(await request.readAsString());
      final db = await dbConnection.database;
      
      // Check if exists
      final existing = await db.query(
        'report_sections',
        where: 'project_id = ? AND section_type = ?',
        whereArgs: [projectId, body['section_type']],
      );
      
      if (existing.isNotEmpty) {
        await db.update(
          'report_sections',
          {
            'content': body['content'],
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'project_id = ? AND section_type = ?',
          whereArgs: [projectId, body['section_type']],
        );
      } else {
        await db.insert('report_sections', {
          'project_id': projectId,
          'section_type': body['section_type'],
          'content': body['content'],
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
      return _jsonResponse({'success': true});
    }

    // GET /api/projects/:id/report-sections
    if (parts.length == 3 &&
        parts[2] == 'report-sections' &&
        request.method == 'GET') {
      final db = await dbConnection.database;
      final sections = await db.query(
        'report_sections',
        where: 'project_id = ?',
        whereArgs: [projectId],
      );
      return _jsonResponse(sections);
    }

    // GET /api/projects/:id/report-data
    if (parts.length == 3 &&
        parts[2] == 'report-data' &&
        request.method == 'GET') {
      final tagFilter = request.url.queryParameters['tag'];
      return await _handleReportData(projectId, tagFilter);
    }

    // POST /api/projects/:id/generate-report
    if (parts.length == 3 &&
        parts[2] == 'generate-report' &&
        request.method == 'POST') {
      final body = json.decode(await request.readAsString());
      return await _handleGenerateReport(projectId, body);
    }

    // POST /api/projects/:id/generate-pdf
    if (parts.length == 3 &&
        parts[2] == 'generate-pdf' &&
        request.method == 'POST') {
      final body = json.decode(await request.readAsString());
      return await _handleGeneratePdf(projectId, body);
    }

    return null;
  }

  static Future<shelf.Response> _handleReportData(
    int projectId,
    String? tagFilter,
  ) async {
    try {
      final findingsRepo = FindingsRepository();
      final vulnRepo = VulnerabilityRepository();
      final tagRepo = TagRepository();

      final findingsData = await findingsRepo.getFlaggedFindings(projectId);
      final enrichedFindings = <Map<String, dynamic>>[];

      for (final finding in findingsData) {
        final enriched = finding.toMap();
        final classification = await vulnRepo
            .getVulnerabilityClassificationByFindingId(finding.id);
        if (classification != null) {
          enriched['category'] = classification.category;
          enriched['subcategory'] = classification.subcategory;
        }
        enrichedFindings.add(enriched);
      }

      List<Map<String, dynamic>> filteredFindings = enrichedFindings;
      if (tagFilter != null && tagFilter != 'all') {
        final taggedDevices = await tagRepo.searchDevicesByTag(
          projectId,
          tagFilter,
        );
        final taggedDeviceIds = taggedDevices.map((d) => d['id'] as int).toSet();
        filteredFindings = enrichedFindings
            .where((f) => taggedDeviceIds.contains(f['device_id']))
            .toList();
      }

      final availableTags = await tagRepo.getAllProjectTags(projectId);

      return _jsonResponse({
        'findings': filteredFindings,
        'availableTags': availableTags,
      });
    } catch (e) {
      return shelf.Response.internalServerError(
        body: json.encode({'error': 'Failed to load report data: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  static Future<shelf.Response> _handleGenerateReport(
    int projectId,
    Map<String, dynamic> body,
  ) async {
    try {
      final format = body['format'] as String;
      final projectName = body['projectName'] as String;
      final tagFilter = body['tagFilter'] as String?;

      final reportDataResponse = await _handleReportData(projectId, tagFilter);
      if (reportDataResponse.statusCode != 200) {
        return reportDataResponse;
      }

      final reportDataJson = json.decode(
        await reportDataResponse.readAsString(),
      );

      String content;
      String mimeType;
      String filename;

      if (format == 'rtf') {
        content = await _generateRTFContent(reportDataJson, projectName);
        mimeType = 'application/rtf';
        filename = '${projectName}_Report.rtf';
      } else if (format == 'html') {
        content = _generateHTMLContent(reportDataJson, projectName);
        mimeType = 'text/html';
        filename = '${projectName}_Report.html';
      } else {
        return shelf.Response.badRequest(
          body: json.encode({'error': 'Unsupported format: $format'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      return shelf.Response.ok(
        content,
        headers: {
          'Content-Type': mimeType,
          'Content-Disposition': 'attachment; filename="$filename"',
        },
      );
    } catch (e) {
      return shelf.Response.internalServerError(
        body: json.encode({'error': 'Failed to generate report: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  static Future<shelf.Response> _handleGeneratePdf(
    int projectId,
    Map<String, dynamic> body,
  ) async {
    try {
      final projectName = body['projectName'] as String;
      final tagFilter = body['tagFilter'] as String?;

      final reportService = ReportService();
      final reportData = await reportService.getReportData(
        projectId,
        selectedTags: tagFilter != null && tagFilter != 'all'
            ? [tagFilter]
            : [],
      );

      final pdfGenerator = PdfReportGenerator();
      final pdfDoc = await pdfGenerator.generatePdfDocument(reportData);
      final pdfBytes = await pdfDoc.save();

      return shelf.Response.ok(
        pdfBytes,
        headers: {
          'Content-Type': 'application/pdf',
          'Content-Disposition':
              'attachment; filename="${projectName}_Report.pdf"',
        },
      );
    } catch (e) {
      return shelf.Response.internalServerError(
        body: json.encode({'error': 'Failed to generate PDF: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  static Future<String> _generateRTFContent(
    Map<String, dynamic> reportData,
    String projectName,
  ) async {
    QuillParser.resetColorTable();
    final findings = List<Map<String, dynamic>>.from(reportData['findings']);
    final buffer = StringBuffer();
    final contentBuffer = StringBuffer();

    final processedFindings = <Map<String, dynamic>>[];
    for (final finding in findings) {
      final processed = Map<String, dynamic>.from(finding);
      processed['rtf_comment'] = await QuillParser.deltaToRTF(
        finding['comment'],
      );
      if (finding['evidence'] != null) {
        processed['rtf_evidence'] = await QuillParser.deltaToRTF(
          finding['evidence'],
        );
      }
      if (finding['recommendation'] != null) {
        processed['rtf_recommendation'] = await QuillParser.deltaToRTF(
          finding['recommendation'],
        );
      }
      processedFindings.add(processed);
    }

    buffer.writeln(
      r'{\rtf1\ansi\deff0 {\fonttbl {\f0\fswiss\fcharset0 Arial;}{\f1\fmodern\fcharset0 Courier New;}}',
    );
    buffer.writeln(QuillParser.buildColorTable());
    buffer.writeln(r'\f0\fs20 ');

    contentBuffer.writeln(r'\fs28\b Penetration Testing Report\b0\fs24\par');
    contentBuffer.writeln('\\fs20 Project: $projectName\\par');
    contentBuffer.writeln(
      'Generated: ${DateTime.now().toString().split('.')[0]}\\par\\par',
    );
    contentBuffer.writeln('\\fs24\\b Executive Summary\\b0\\fs20\\par');
    contentBuffer.writeln(
      'Total Findings: ${processedFindings.length}\\par\\par',
    );

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final finding in processedFindings) {
      final category = finding['category'] ?? 'Uncategorized';
      final subcategory = finding['subcategory'] ?? 'General';
      final cvssScore = (finding['cvss_base_score'] ?? 0.0).toString();
      final ip = finding['ip_address'];
      final key = '$category|$subcategory|$cvssScore|$ip';

      if (!grouped.containsKey(key)) grouped[key] = [];
      grouped[key]!.add(finding);
    }

    String? currentCategory;
    for (final entry in grouped.entries) {
      final parts = entry.key.split('|');
      final category = parts[0];
      if (currentCategory != category) {
        currentCategory = category;
        contentBuffer.writeln('\\fs22\\b $category\\b0\\fs20\\par');
      }
      contentBuffer.writeln(
        '\\tab ${parts[1]} - CVSS ${parts[2]} - IP: ${parts[3]}\\par',
      );
      for (final finding in entry.value) {
        contentBuffer.writeln('\\tab\\tab\\bullet ${finding['type']}:\\par');
        if (finding['rtf_comment'] != null &&
            finding['rtf_comment'].isNotEmpty) {
          contentBuffer.writeln(
            '\\tab\\tab\\tab ${finding['rtf_comment']}\\par',
          );
        }
        if (finding['rtf_evidence'] != null &&
            finding['rtf_evidence'].isNotEmpty) {
          contentBuffer.writeln(
            '\\tab\\tab\\tab\\b Evidence:\\b0 ${finding['rtf_evidence']}\\par',
          );
        }
        if (finding['rtf_recommendation'] != null &&
            finding['rtf_recommendation'].isNotEmpty) {
          contentBuffer.writeln(
            '\\tab\\tab\\tab\\b Recommendation:\\b0 ${finding['rtf_recommendation']}\\par',
          );
        }
      }
    }

    buffer.write(contentBuffer.toString());
    buffer.writeln('}');
    return buffer.toString();
  }

  static String _generateHTMLContent(
    Map<String, dynamic> reportData,
    String projectName,
  ) {
    final findings = List<Map<String, dynamic>>.from(reportData['findings']);
    final buffer = StringBuffer();

    buffer.writeln('<!DOCTYPE html><html><head>');
    buffer.writeln('<title>Penetration Testing Report - $projectName</title>');
    buffer.writeln(
      '<style>body{font-family:Arial,sans-serif;margin:20px}.header{border-bottom:2px solid #333;padding-bottom:20px}h1{color:#333}h2{color:#555;border-bottom:1px solid #ddd}.cvss{padding:2px 8px;border-radius:3px;color:white;font-weight:bold}.critical{background:#dc3545}.high{background:#fd7e14}.medium{background:#ffc107;color:#000}.low{background:#28a745}</style>',
    );
    buffer.writeln('</head><body>');
    buffer.writeln('<div class="header"><h1>Penetration Testing Report</h1>');
    buffer.writeln('<p><strong>Project:</strong> $projectName</p>');
    buffer.writeln(
      '<p><strong>Generated:</strong> ${DateTime.now().toString().split('.')[0]}</p></div>',
    );
    buffer.writeln('<h2>Executive Summary</h2>');
    buffer.writeln(
      '<p><strong>Total Findings:</strong> ${findings.length}</p>',
    );

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final finding in findings) {
      final category = finding['category'] ?? 'Uncategorized';
      final subcategory = finding['subcategory'] ?? 'General';
      final cvssScore = (finding['cvss_base_score'] ?? 0.0).toString();
      final ip = finding['ip_address'];
      final key = '$category|$subcategory|$cvssScore|$ip';

      if (!grouped.containsKey(key)) grouped[key] = [];
      grouped[key]!.add(finding);
    }

    buffer.writeln('<h2>Detailed Findings</h2>');
    String? currentCategory;
    for (final entry in grouped.entries) {
      final parts = entry.key.split('|');
      final category = parts[0];
      if (currentCategory != category) {
        currentCategory = category;
        buffer.writeln('<h3>$category</h3>');
      }
      final cvssClass = _getCvssClass(double.tryParse(parts[2]) ?? 0.0);
      buffer.writeln(
        '<h4>${parts[1]} - <span class="cvss $cvssClass">CVSS ${parts[2]}</span> - IP: ${parts[3]}</h4>',
      );
      buffer.writeln('<ul>');
      for (final finding in entry.value) {
        final comment = QuillParser.deltaToHTML(finding['comment']);
        buffer.writeln('<li><strong>${finding['type']}:</strong>');
        buffer.writeln('<div>$comment</div>');
        if (finding['evidence'] != null &&
            finding['evidence'].toString().isNotEmpty) {
          final evidence = QuillParser.deltaToHTML(finding['evidence']);
          buffer.writeln('<div><strong>Evidence:</strong> $evidence</div>');
        }
        if (finding['recommendation'] != null &&
            finding['recommendation'].toString().isNotEmpty) {
          final recommendation = QuillParser.deltaToHTML(
            finding['recommendation'],
          );
          buffer.writeln(
            '<div><strong>Recommendation:</strong> $recommendation</div>',
          );
        }
        buffer.writeln('</li>');
      }
      buffer.writeln('</ul>');
    }

    buffer.writeln('</body></html>');
    return buffer.toString();
  }

  static String _getCvssClass(double score) {
    if (score >= 9.0) return 'critical';
    if (score >= 7.0) return 'high';
    if (score >= 4.0) return 'medium';
    if (score >= 0.1) return 'low';
    return 'low';
  }

  static shelf.Response _jsonResponse(dynamic data) {
    return shelf.Response.ok(
      json.encode(data),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
