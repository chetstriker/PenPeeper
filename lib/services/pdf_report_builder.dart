import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_to_pdf/flutter_to_pdf.dart';
import '../models/report_models.dart';
import 'pdf_report_styles.dart';
import 'quill_parser.dart';
import 'report_section_converter.dart';
import '../widgets/vulnerability_graphic_generator.dart';

class PdfReportBuilder {
  final ReportData reportData;
  final String projectName;
  Map<String, int>? tocPages;
  final ExportDelegate? exportDelegate;

  PdfReportBuilder(
    this.reportData,
    this.projectName, {
    this.tocPages,
    this.exportDelegate,
  });

  Future<Map<String, dynamic>> buildFindingsWithCaptureAndMap(
    Map<String, int> pageCapture,
  ) async {
    return await _buildFindingsInternal(pageCapture: pageCapture);
  }

  Future<Map<String, dynamic>> buildFindingsWithMap() async {
    return await _buildFindingsInternal();
  }

  Future<Map<String, dynamic>> _buildFindingsInternal({
    Map<String, int>? pageCapture,
  }) async {
    if (reportData.groupedFindings.isEmpty) {
      return {
        'widgets': <pw.Widget>[],
        'widgetToFindingMap': <int, Map<String, dynamic>>{},
      };
    }

    final widgets = <pw.Widget>[
      pw.Anchor(name: 'findings'),
      pw.Header(
        level: 0,
        child: pw.Text(
          'Detailed Findings',
          style: PdfReportStyles.heading1Style,
        ),
      ),
      pw.SizedBox(height: PdfReportStyles.sectionSpacing),
    ];

    final widgetToFindingMap = <int, Map<String, dynamic>>{};
    String? currentCategory;
    String? currentSubcategory;

    for (final entry in reportData.groupedFindings.entries) {
      final parts = entry.key.split('|');
      final category = parts[0];
      final subcategory = parts[1];
      final findings = entry.value;

      if (currentCategory != category) {
        currentCategory = category;
        _addCategoryHeader(widgets, category, pageCapture);
      }

      if (currentSubcategory != subcategory) {
        currentSubcategory = subcategory;
        _addSubcategoryHeader(widgets, category, subcategory, pageCapture);
      }

      for (final finding in findings) {
        final startIndex = widgets.length;
        widgets.addAll(await _buildFindingItem(finding));
        final endIndex = widgets.length - 1;

        for (int i = startIndex; i <= endIndex; i++) {
          widgetToFindingMap[i] = {
            'id': finding.id,
            'device': finding.deviceName,
            'ip': finding.ipAddress,
          };
        }
      }
    }

    return {'widgets': widgets, 'widgetToFindingMap': widgetToFindingMap};
  }

  void _addCategoryHeader(
    List<pw.Widget> widgets,
    String category,
    Map<String, int>? pageCapture,
  ) {
    if (pageCapture != null) {
      widgets.add(
        pw.Builder(
          builder: (context) {
            pageCapture['Findings:$category'] = context.pageNumber;
            return pw.SizedBox.shrink();
          },
        ),
      );
    }
    widgets.add(pw.SizedBox(height: 15));
    widgets.add(
      pw.Text(category.toUpperCase(), style: PdfReportStyles.heading2Style),
    );
    widgets.add(pw.SizedBox(height: 8));
  }

  void _addSubcategoryHeader(
    List<pw.Widget> widgets,
    String category,
    String subcategory,
    Map<String, int>? pageCapture,
  ) {
    if (pageCapture != null) {
      widgets.add(
        pw.Builder(
          builder: (context) {
            pageCapture['Findings:$category|$subcategory'] = context.pageNumber;
            return pw.SizedBox.shrink();
          },
        ),
      );
    }
    widgets.add(
      pw.Padding(
        padding: const pw.EdgeInsets.only(left: 20, top: 10),
        child: pw.Text(
          subcategory,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: PdfReportStyles.darkGray,
          ),
        ),
      ),
    );
  }

  Future<pw.Widget> buildCoverPage() async {
    debugPrint('[PDF_BUILDER] Building cover page');
    debugPrint(
      '[PDF_BUILDER] Summary graphic option: ${reportData.summaryGraphicOption}',
    );
    debugPrint(
      '[PDF_BUILDER] Export delegate available: ${exportDelegate != null}',
    );

    final reportHeaderWidgets =
        reportData.reportHeader != null &&
            reportData.reportHeader!.trim().isNotEmpty
        ? await ReportSectionConverter.convertDeltaToPdf(
            reportData.reportHeader,
          )
        : [
            pw.Text(
              'Penetration Testing Report',
              style: PdfReportStyles.titleStyle,
            ),
          ];

    final widgets = <pw.Widget>[
      ...reportHeaderWidgets,
      pw.SizedBox(height: 40),
    ];

    if (reportData.summaryGraphicOption != null) {
      debugPrint(
        '[PDF_BUILDER] Generating summary graphic for option ${reportData.summaryGraphicOption}',
      );
      final graphicWidget = _buildSummaryGraphicImage(
        reportData.summaryGraphicOption!,
      );
      debugPrint('[PDF_BUILDER] Graphic widget created, adding to cover page');
      widgets.add(graphicWidget);
      widgets.add(pw.SizedBox(height: 40));
    } else {
      debugPrint('[PDF_BUILDER] No summary graphic option selected');
    }

    widgets.add(
      pw.Text(
        'Generated: ${DateTime.now().toString().split('.')[0]}',
        style: PdfReportStyles.smallStyle,
      ),
    );

    return pw.Center(
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.center,
        children: widgets,
      ),
    );
  }

  pw.Widget buildTocPlaceholder() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text('Table of Contents', style: PdfReportStyles.heading1Style),
        pw.SizedBox(height: PdfReportStyles.sectionSpacing),
        pw.Text(
          '(Placeholder for page tracking)',
          style: PdfReportStyles.bodyStyle,
        ),
      ],
    );
  }

  pw.Widget buildTableOfContents() {
    if (tocPages == null) return buildTocPlaceholder();

    final entries = <pw.Widget>[
      pw.Text('Table of Contents', style: PdfReportStyles.heading1Style),
      pw.SizedBox(height: PdfReportStyles.sectionSpacing),
    ];

    _addTocSection(entries, 'Executive Summary');
    _addTocSection(entries, 'Methodology & Scope');
    _addFindingsToc(entries);
    _addTocSection(entries, 'Risk Rating Model');
    _addTocSection(entries, 'Conclusion');

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: entries,
    );
  }

  void _addTocSection(List<pw.Widget> entries, String title) {
    if (tocPages!.containsKey(title)) {
      entries.add(_buildTocEntry(title, tocPages![title]!));
    }
  }

  void _addFindingsToc(List<pw.Widget> entries) {
    if (!tocPages!.containsKey('Findings')) return;

    entries.add(_buildTocEntry('Findings', tocPages!['Findings']!));

    final categoryMap = _collectFindingsCategories();

    for (final category in categoryMap.keys) {
      final categoryKey = 'Findings:$category';
      if (tocPages!.containsKey(categoryKey)) {
        entries.add(
          _buildTocEntry('  $category', tocPages![categoryKey]!, indent: 15),
        );

        for (final subcategory in categoryMap[category]!) {
          final subcategoryKey = 'Findings:$category|$subcategory';
          if (tocPages!.containsKey(subcategoryKey)) {
            entries.add(
              _buildTocEntry(
                '    $subcategory',
                tocPages![subcategoryKey]!,
                indent: 30,
              ),
            );
          }
        }
      }
    }
  }

  Map<String, List<String>> _collectFindingsCategories() {
    final categoryMap = <String, List<String>>{};
    for (final key in tocPages!.keys) {
      if (key.startsWith('Findings:')) {
        final parts = key.substring(9).split('|');
        if (parts.length == 1) {
          if (!categoryMap.containsKey(parts[0])) {
            categoryMap[parts[0]] = [];
          }
        } else if (parts.length == 2) {
          if (!categoryMap.containsKey(parts[0])) {
            categoryMap[parts[0]] = [];
          }
          categoryMap[parts[0]]!.add(parts[1]);
        }
      }
    }
    return categoryMap;
  }

  pw.Widget _buildTocEntry(String title, int page, {double indent = 0}) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: 4, left: indent),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Text(title, style: const pw.TextStyle(fontSize: 10)),
          ),
          pw.Text('$page', style: const pw.TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Future<List<pw.Widget>> buildExecutiveSummary() async {
    return await _buildReportSection(
      reportData.executiveSummary,
      'Executive Summary',
      'exec-summary',
    );
  }

  Future<List<pw.Widget>> buildMethodologyScope() async {
    return await _buildReportSection(
      reportData.methodologyScope,
      'Methodology & Scope',
      'methodology',
    );
  }

  Future<List<pw.Widget>> buildRiskRatingModel() async {
    return await _buildReportSection(
      reportData.riskRatingModel,
      'Risk Rating Model',
      'risk-rating',
    );
  }

  Future<List<pw.Widget>> _buildReportSection(
    String? content,
    String title,
    String anchorName,
  ) async {
    if (content == null || content.trim().isEmpty) return [];

    final widgets = await ReportSectionConverter.convertDeltaToPdf(content);
    return [
      pw.Anchor(name: anchorName),
      pw.Header(
        level: 0,
        child: pw.Text(title, style: PdfReportStyles.heading1Style),
      ),
      pw.SizedBox(height: PdfReportStyles.paragraphSpacing),
      ...widgets,
      pw.SizedBox(height: PdfReportStyles.sectionSpacing),
    ];
  }

  Future<List<pw.Widget>> buildFindingsWithCapture(
    Map<String, int> pageCapture,
  ) async {
    final result = await _buildFindingsInternal(pageCapture: pageCapture);
    return result['widgets'] as List<pw.Widget>;
  }

  Future<List<pw.Widget>> buildFindings() async {
    debugPrint('[PDF_BUILDER] ===== BUILDING FINDINGS =====');
    debugPrint('[PDF_BUILDER] Total findings: ${reportData.findings.length}');
    debugPrint('[PDF_BUILDER] Grouped findings: ${reportData.groupedFindings.length}');
    final result = await _buildFindingsInternal();
    final widgets = result['widgets'] as List<pw.Widget>;
    debugPrint('[PDF_BUILDER] Total widgets: ${widgets.length}');
    return widgets;
  }

  Future<List<pw.Widget>> _buildFindingItem(ReportFinding finding) async {
    debugPrint('[PDF_BUILDER] Building: ${finding.deviceName}');
    final severity = finding.cvssSeverity ?? 'UNKNOWN';

    // Limit description to 5000 chars
    List<pw.Widget> commentWidgets;
    if (finding.comment.length > 5000) {
      commentWidgets = [pw.Text('${finding.comment.substring(0, 5000)}\n[Truncated]', style: const pw.TextStyle(fontSize: 9))];
    } else {
      commentWidgets = await QuillParser.deltaToPdfWidgets(finding.comment, projectName);
    }
    
    // Limit evidence to 5000 chars per chunk
    final evidenceChunks = <String>[];
    if (finding.evidence != null && finding.evidence!.length > 5000) {
      for (int i = 0; i < finding.evidence!.length; i += 5000) {
        evidenceChunks.add(finding.evidence!.substring(i, (i + 5000).clamp(0, finding.evidence!.length)));
      }
    } else if (finding.evidence != null) {
      evidenceChunks.add(finding.evidence!);
    }
    
    // Limit recommendation to 5000 chars
    List<pw.Widget>? recommendationWidgets;
    if (finding.recommendation != null && finding.recommendation!.isNotEmpty) {
      if (finding.recommendation!.length > 5000) {
        recommendationWidgets = [pw.Text('${finding.recommendation!.substring(0, 5000)}\n[Truncated]', style: const pw.TextStyle(fontSize: 9))];
      } else {
        recommendationWidgets = await QuillParser.deltaToPdfWidgets(finding.recommendation, projectName);
      }
    }

    final results = <pw.Widget>[];
    
    // Main finding container
    results.add(
      pw.Padding(
        padding: const pw.EdgeInsets.only(left: 40, top: 10),
        child: pw.Container(
          width: double.infinity,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfReportStyles.lightGray),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
            color: PdfColors.grey50,
          ),
          padding: const pw.EdgeInsets.all(12),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Finding: ${severity.toUpperCase()}',
                style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfReportStyles.textColor,
                ),
              ),
              pw.SizedBox(height: 8),
              _buildDeviceSection(finding),
              if (commentWidgets.isNotEmpty)
                _buildFindingSection(
                  'Description:',
                  commentWidgets,
                  PdfColors.grey800,
                ),
              if (evidenceChunks.isNotEmpty)
                _buildFindingSection(
                  'Evidence:',
                  await QuillParser.deltaToPdfWidgets(evidenceChunks[0], projectName),
                  PdfColors.red900,
                ),
              if (recommendationWidgets != null && recommendationWidgets.isNotEmpty)
                _buildFindingSection(
                  'Recommendation:',
                  recommendationWidgets,
                  PdfColors.green900,
                ),
            ],
          ),
        ),
      ),
    );
    results.add(pw.SizedBox(height: 8));
    
    // Add continuation containers for remaining evidence chunks
    for (int i = 1; i < evidenceChunks.length; i++) {
      results.add(
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 40, top: 4),
          child: pw.Container(
            width: double.infinity,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfReportStyles.lightGray),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
              color: PdfColors.grey50,
            ),
            padding: const pw.EdgeInsets.all(12),
            child: _buildFindingSection(
              'Evidence (continued):',
              await QuillParser.deltaToPdfWidgets(evidenceChunks[i], projectName),
              PdfColors.red900,
            ),
          ),
        ),
      );
      results.add(pw.SizedBox(height: 8));
    }

    return results;
  }

  pw.Widget _buildDeviceSection(ReportFinding finding) {
    return pw.Container(
      width: double.infinity,
      decoration: pw.BoxDecoration(
        border: pw.Border(
          left: pw.BorderSide(color: PdfColors.blue900, width: 4),
        ),
      ),
      padding: const pw.EdgeInsets.all(8),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Device:',
            style: pw.TextStyle(
              fontSize: 10,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Host Name: ${finding.deviceName}',
            style: const pw.TextStyle(fontSize: 9),
            softWrap: true,
          ),
          pw.Text(
            'IP Address: ${finding.ipAddress}',
            style: const pw.TextStyle(fontSize: 9),
            softWrap: true,
          ),
          if (finding.macAddress != null && finding.macAddress!.isNotEmpty)
            pw.Text(
              'MAC Address: ${finding.macAddress}',
              style: const pw.TextStyle(fontSize: 9),
              softWrap: true,
            ),
          if (finding.vendor != null && finding.vendor!.isNotEmpty)
            pw.Text(
              'MAC Vendor: ${finding.vendor}',
              style: const pw.TextStyle(fontSize: 9),
              softWrap: true,
            ),
          if (finding.cvssScore != null)
            pw.Text(
              'CVSS: ${finding.cvssVersion != null && finding.cvssVersion!.startsWith('v') ? finding.cvssVersion : 'v${finding.cvssVersion ?? '3.1'}'} - ${finding.cvssScore!.toStringAsFixed(1)}',
              style: pw.TextStyle(
                fontSize: 9,
                color: PdfReportStyles.criticalColor,
              ),
              softWrap: true,
            ),
          if (finding.cveId != null)
            pw.Text(
              'CVE: ${finding.cveId}',
              style: pw.TextStyle(
                fontSize: 9,
                color: PdfReportStyles.criticalColor,
              ),
              softWrap: true,
            ),
        ],
      ),
    );
  }

  pw.Widget _buildFindingSection(
    String title,
    List<pw.Widget> widgets,
    PdfColor borderColor,
  ) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Container(
        width: double.infinity,
        decoration: pw.BoxDecoration(
          border: pw.Border(
            left: pw.BorderSide(color: borderColor, width: 4),
          ),
        ),
        padding: const pw.EdgeInsets.all(8),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title,
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 4),
            ...widgets,
          ],
        ),
      ),
    );
  }

  Future<List<pw.Widget>> buildConclusion() async {
    return await _buildReportSection(
      reportData.conclusion,
      'Conclusion',
      'conclusion',
    );
  }

  pw.Widget buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'Page ${context.pageNumber}',
        style: PdfReportStyles.smallStyle,
      ),
    );
  }

  pw.Widget _buildSummaryGraphicImage(int option) {
    debugPrint('[PDF_BUILDER] Building summary graphic for option: $option');
    debugPrint(
      '[PDF_BUILDER] Using VulnerabilityGraphicGenerator.generatePdfWidget',
    );

    debugPrint('=== CATEGORY CHECK ===');
    for (var i = 0; i < 3; i++) {
      if (i < reportData.findings.length) {
        debugPrint(
          'Finding $i: category=${reportData.findings[i].category}, subcategory=${reportData.findings[i].subcategory}, severity=${reportData.findings[i].cvssSeverity}',
        );
      }
    }

    // Aggregate findings by HIGH-LEVEL CATEGORY and severity
    // This groups all subcategories under their parent category
    // KEY CHANGE: Use finding.category (not finding.subcategory)
    final aggregated = <String, VulnerabilityEntry>{};
    for (var finding in reportData.findings) {
      final severity = finding.cvssSeverity ?? 'UNKNOWN';
      final category =
          finding.category ?? 'Uncategorized'; // ✅ HIGH-LEVEL CATEGORY

      // Key format: category|severity
      final key = '$category|$severity';

      if (aggregated.containsKey(key)) {
        // This category+severity combination already exists - increment count
        final existing = aggregated[key]!;
        aggregated[key] = VulnerabilityEntry(
          category: existing.category,
          subcategory: existing.subcategory,
          severity: existing.severity,
          count: existing.count + 1, // Add to existing count
        );
      } else {
        // First entry for this category+severity combination
        aggregated[key] = VulnerabilityEntry(
          category: category,
          subcategory: '', // Not used for display
          severity: severity,
          count: 1,
        );
      }
    }

    final data = aggregated.values.toList();

    debugPrint(
      '[PDF_BUILDER] Aggregated ${reportData.findings.length} findings into ${data.length} entries',
    );

    debugPrint('=== VULNERABILITY ENTRIES ===');
    final bySeverity = <String, List<VulnerabilityEntry>>{};
    for (var entry in data) {
      if (!bySeverity.containsKey(entry.severity)) {
        bySeverity[entry.severity] = [];
      }
      bySeverity[entry.severity]!.add(entry);
    }
    for (var severity in bySeverity.keys) {
      debugPrint('$severity:');
      for (var entry in bySeverity[severity]!) {
        debugPrint('  ${entry.category} (${entry.count})');
      }
    }
    debugPrint('============================');

    return VulnerabilityGraphicGenerator.generatePdfWidget(
      option: option,
      data: data,
      width: 600, // ✅ Increased from 500 for more space
      height: 350, // ✅ Increased from 250 for more space
    );
  }
}
