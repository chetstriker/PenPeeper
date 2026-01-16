import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../graphic_data_models.dart';
import '../graphic_colors.dart';
import 'pdf_helpers.dart';

class PdfCompactCards {
  static pw.Widget build(List<VulnerabilityEntry> data, double width, double height) {
    final severityCounts = DataAggregator.getSeverityCounts(data);
    final categoryCounts = DataAggregator.getCategoryCounts(data);
    final sortedCategories = (categoryCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).toList();

    return pw.Container(
      width: width,
      height: height,
      color: PdfColors.white,
      padding: const pw.EdgeInsets.all(24),
      child: pw.Column(
        children: [
          pw.Text('Security Assessment Summary', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 20),
          pw.Expanded(child: pw.Row(children: [pw.Expanded(child: _buildPdfSeverityCard(severityCounts)), pw.SizedBox(width: 15), pw.Expanded(child: _buildPdfCategoryCard(sortedCategories))])),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfSeverityCard(Map<String, int> severityCounts) {
    return pw.Container(
      decoration: pw.BoxDecoration(gradient: pw.LinearGradient(colors: [const PdfColor.fromInt(0xFF667EEA), const PdfColor.fromInt(0xFF764BA2)]), borderRadius: pw.BorderRadius.circular(12)),
      padding: const pw.EdgeInsets.all(20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('SEVERITY BREAKDOWN', style: pw.TextStyle(color: PdfColors.white, fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 20),
          pw.Expanded(child: pw.GridView(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, children: PdfSeverityColors.severityOrder.where((sev) => severityCounts.containsKey(sev)).map((severity) => pw.Container(decoration: pw.BoxDecoration(color: const PdfColor.fromInt(0xB3A5B4E8), borderRadius: pw.BorderRadius.circular(8)), padding: const pw.EdgeInsets.all(12), child: pw.Center(child: pw.Column(mainAxisSize: pw.MainAxisSize.min, children: [pw.Text(severity, style: pw.TextStyle(color: PdfColors.white, fontSize: 10)), pw.SizedBox(height: 8), pw.Text('${severityCounts[severity]}', style: pw.TextStyle(color: PdfColors.white, fontSize: 32, fontWeight: pw.FontWeight.bold))])))).toList())),
        ],
      ),
    );
  }

  static pw.Widget _buildPdfCategoryCard(List<MapEntry<String, int>> categories) {
    return pw.Container(
      decoration: pw.BoxDecoration(gradient: pw.LinearGradient(colors: [const PdfColor.fromInt(0xFFF59E0B), const PdfColor.fromInt(0xFFEA580C)]), borderRadius: pw.BorderRadius.circular(12)),
      padding: const pw.EdgeInsets.all(20),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text('TOP CATEGORIES', style: pw.TextStyle(color: PdfColors.white, fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 15),
          pw.Expanded(child: pw.Column(children: categories.map((cat) => pw.Container(margin: const pw.EdgeInsets.only(bottom: 8), padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10), decoration: pw.BoxDecoration(color: const PdfColor.fromInt(0xB3FBB96D), borderRadius: pw.BorderRadius.circular(8)), child: pw.Row(children: [pw.Expanded(child: pw.Text(PdfTextHelper.abbreviateCategory(cat.key, 30), style: pw.TextStyle(color: PdfColors.white, fontSize: 11))), pw.Container(padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(12)), child: pw.Text('${cat.value}', style: pw.TextStyle(color: const PdfColor.fromInt(0xFFEA580C), fontWeight: pw.FontWeight.bold, fontSize: 12)))]))).toList())),
        ],
      ),
    );
  }
}
