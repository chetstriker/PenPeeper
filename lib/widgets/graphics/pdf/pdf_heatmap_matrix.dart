import 'dart:math' as math;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../graphic_data_models.dart';
import '../graphic_colors.dart';
import 'pdf_helpers.dart';

class PdfHeatmapMatrix {
  static pw.Widget build(List<VulnerabilityEntry> data, double width, double height) {
    final categoryBreakdown = DataAggregator.getCategorySeverityBreakdown(data);
    final categoryCounts = DataAggregator.getCategoryCounts(data);
    final severityCounts = DataAggregator.getSeverityCounts(data);
    final sortedCategories = categoryCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final activeSeverities = ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW'];
    final totalRows = sortedCategories.length + 2;
    final availableHeight = height - 80;
    final cellHeight = math.min(40.0, availableHeight / totalRows);

    final children = <pw.Widget>[
      pw.Text('Vulnerability Distribution Matrix', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 20),
      pw.Row(children: [_buildPdfHeaderCell('Category', flex: 3, height: cellHeight), ...activeSeverities.map((sev) => _buildPdfHeaderCell(sev, flex: 1, height: cellHeight))]),
    ];

    for (final cat in sortedCategories) {
      children.add(pw.Row(children: [_buildPdfLabelCell(PdfTextHelper.abbreviateCategory(cat.key, 25), flex: 3, height: cellHeight), ...activeSeverities.map((sev) {
        final count = categoryBreakdown[cat.key]?[sev] ?? 0;
        return _buildPdfDataCell(count, sev, flex: 1, height: cellHeight);
      })]));
    }

    children.add(pw.Row(children: [_buildPdfHeaderCell('TOTAL', flex: 3, color: const PdfColor.fromInt(0xFF3B82F6), height: cellHeight), ...activeSeverities.map((sev) {
      final count = severityCounts[sev] ?? 0;
      return _buildPdfDataCell(count, sev, flex: 1, isTotal: true, height: cellHeight);
    })]));

    return pw.Container(width: width, color: PdfColors.white, padding: const pw.EdgeInsets.all(24), child: pw.Column(children: children));
  }

  static pw.Widget _buildPdfHeaderCell(String text, {int flex = 1, PdfColor? color, double height = 40}) {
    return pw.Expanded(flex: flex, child: pw.Container(height: height, margin: const pw.EdgeInsets.all(1), decoration: pw.BoxDecoration(color: color ?? const PdfColor.fromInt(0xFF1E293B), borderRadius: pw.BorderRadius.circular(4)), alignment: pw.Alignment.center, child: pw.Text(text, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: math.min(12, height * 0.3)), textAlign: pw.TextAlign.center)));
  }

  static pw.Widget _buildPdfLabelCell(String text, {int flex = 1, double height = 40}) {
    return pw.Expanded(flex: flex, child: pw.Container(height: height, margin: const pw.EdgeInsets.all(1), decoration: pw.BoxDecoration(color: const PdfColor.fromInt(0xFF334155), borderRadius: pw.BorderRadius.circular(4)), padding: const pw.EdgeInsets.symmetric(horizontal: 8), alignment: pw.Alignment.centerLeft, child: pw.Text(text, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: math.min(11, height * 0.275)), maxLines: 1, overflow: pw.TextOverflow.clip)));
  }

  static pw.Widget _buildPdfDataCell(int count, String severity, {int flex = 1, bool isTotal = false, double height = 40}) {
    final isEmpty = count == 0 && !isTotal;
    return pw.Expanded(flex: flex, child: pw.Container(height: height, margin: const pw.EdgeInsets.all(1), decoration: pw.BoxDecoration(color: isEmpty ? const PdfColor.fromInt(0xFFF1F5F9) : isTotal ? const PdfColor.fromInt(0xFF3B82F6) : PdfSeverityColors.getColor(severity), borderRadius: pw.BorderRadius.circular(4)), alignment: pw.Alignment.center, child: pw.Text(isEmpty ? '-' : '$count', style: pw.TextStyle(color: isEmpty ? const PdfColor.fromInt(0xFFCBD5E1) : PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: math.min(16, height * 0.4)))));
  }
}
