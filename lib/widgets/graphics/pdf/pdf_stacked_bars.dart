import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../graphic_data_models.dart';
import '../graphic_colors.dart';
import 'pdf_helpers.dart';

class PdfStackedBars {
  static pw.Widget build(List<VulnerabilityEntry> data, double width, double height) {
    final categoryBreakdown = DataAggregator.getCategorySeverityBreakdown(data);
    final categoryCounts = DataAggregator.getCategoryCounts(data);
    final totalCount = DataAggregator.getTotalCount(data);
    final severityCounts = DataAggregator.getSeverityCounts(data);
    final sortedCategories = categoryCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return pw.Container(
      width: width,
      color: PdfColors.white,
      padding: const pw.EdgeInsets.all(24),
      child: pw.Column(
        children: [
          pw.Text('$totalCount Total Vulnerabilities', style: pw.TextStyle(fontSize: 28, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 20),
          ...sortedCategories.map((catEntry) {
            final category = catEntry.key;
            final total = catEntry.value;
            final severities = categoryBreakdown[category] ?? {};
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Row(
                children: [
                  pw.SizedBox(width: 120, child: pw.Text(PdfTextHelper.abbreviateCategory(category, 20), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.right)),
                  pw.SizedBox(width: 12),
                  pw.Expanded(child: pw.ClipRRect(horizontalRadius: 6, verticalRadius: 6, child: pw.Row(children: _buildPdfBarSegments(severities, total)))),
                  pw.SizedBox(width: 12),
                  pw.SizedBox(width: 35, child: pw.Text('$total', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  static List<pw.Widget> _buildPdfBarSegments(Map<String, int> severities, int total) {
    final segments = <pw.Widget>[];
    for (var severity in PdfSeverityColors.severityOrder) {
      if (!severities.containsKey(severity)) continue;
      final count = severities[severity]!;
      final percentage = count / total;
      if (segments.isNotEmpty) segments.add(pw.Container(width: 2, color: PdfColors.white));
      segments.add(pw.Expanded(flex: (percentage * 100).round(), child: pw.Container(height: 36.0, color: PdfSeverityColors.getColor(severity), alignment: pw.Alignment.center, child: count > 0 ? pw.Text('$count', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 13)) : null)));
    }
    return segments;
  }
}
