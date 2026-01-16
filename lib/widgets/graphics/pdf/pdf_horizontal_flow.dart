import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../graphic_data_models.dart';
import '../graphic_colors.dart';
import 'pdf_helpers.dart';

class PdfHorizontalFlow {
  static pw.Widget build(List<VulnerabilityEntry> data, double width, double height) {
    final totalCount = DataAggregator.getTotalCount(data);
    final severityCounts = DataAggregator.getSeverityCounts(data);
    final categoryBreakdown = DataAggregator.getCategorySeverityBreakdown(data);
    final activeSeverities = PdfSeverityColors.severityOrder.where((sev) => severityCounts.containsKey(sev)).toList();

    return pw.Container(
      width: width,
      height: height,
      color: PdfColors.white,
      padding: const pw.EdgeInsets.all(24),
      child: pw.Column(
        children: [
          pw.Text('$totalCount Vulnerabilities by Severity & Category', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 20),
          pw.Expanded(child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: activeSeverities.map((severity) => pw.Expanded(child: _buildPdfSeverityColumn(severity, severityCounts[severity]!, categoryBreakdown))).toList())),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfSeverityColumn(String severity, int count, Map<String, Map<String, int>> breakdown) {
    final categoryItems = <MapEntry<String, int>>[];
    breakdown.forEach((category, severities) {
      if (severities.containsKey(severity)) categoryItems.add(MapEntry(category, severities[severity]!));
    });
    categoryItems.sort((a, b) => b.value.compareTo(a.value));
    final gradientColors = _getGradientColors(severity);
    final itemBgGradient = _getItemBackgroundGradient(severity);

    return pw.Container(
      margin: const pw.EdgeInsets.symmetric(horizontal: 6),
      decoration: pw.BoxDecoration(gradient: pw.LinearGradient(begin: pw.Alignment.topCenter, end: pw.Alignment.bottomCenter, colors: gradientColors), borderRadius: pw.BorderRadius.circular(12)),
      padding: const pw.EdgeInsets.all(16),
      child: pw.Column(
        children: [
          PdfTextWithShadow.build(severity, pw.TextStyle(color: PdfColors.white, fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          pw.Text('$count', style: pw.TextStyle(color: PdfColors.white, fontSize: 36, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 15),
          pw.Expanded(child: pw.Column(children: categoryItems.map((item) => pw.Container(margin: const pw.EdgeInsets.only(bottom: 6), padding: const pw.EdgeInsets.all(8), constraints: pw.BoxConstraints(minHeight: 30), decoration: pw.BoxDecoration(gradient: itemBgGradient, borderRadius: pw.BorderRadius.circular(6)), child: pw.Row(children: [pw.Expanded(child: PdfTextWithShadow.build(PdfTextHelper.abbreviateCategory(item.key, 20), pw.TextStyle(color: PdfColors.white, fontSize: 10))), pw.SizedBox(width: 4), pw.Text('${item.value}', style: pw.TextStyle(color: PdfColors.white, fontSize: 12, fontWeight: pw.FontWeight.bold))]))).toList())),
        ],
      ),
    );
  }

  static List<PdfColor> _getGradientColors(String severity) {
    switch (severity.toUpperCase()) {
      case 'CRITICAL': return [const PdfColor.fromInt(0xFFDA2525), const PdfColor.fromInt(0xFF9A1B1B)];
      case 'HIGH': return [const PdfColor.fromInt(0xFFEA580C), const PdfColor.fromInt(0xFFC2410C)];
      case 'MEDIUM': return [const PdfColor.fromInt(0xFFF59E0B), const PdfColor.fromInt(0xFFD97706)];
      case 'LOW': return [const PdfColor.fromInt(0xFF10B981), const PdfColor.fromInt(0xFF059669)];
      default: return [PdfColors.grey, PdfColors.grey700];
    }
  }

  static pw.LinearGradient _getItemBackgroundGradient(String severity) {
    switch (severity.toUpperCase()) {
      case 'CRITICAL': return pw.LinearGradient(colors: [const PdfColor.fromInt(0xFFCE4E4E), const PdfColor.fromInt(0xFFCB4D4D)]);
      case 'HIGH': return pw.LinearGradient(colors: [const PdfColor.fromInt(0xFFE1723D), const PdfColor.fromInt(0xFFE0713D)]);
      case 'MEDIUM': return pw.LinearGradient(colors: [const PdfColor.fromInt(0xFFEEA53A), const PdfColor.fromInt(0xFFEDA43A)]);
      case 'LOW': return pw.LinearGradient(colors: [const PdfColor.fromInt(0xFF10B981), const PdfColor.fromInt(0xFF059669)]);
      default: return pw.LinearGradient(colors: [PdfColors.grey600, PdfColors.grey700]);
    }
  }
}
