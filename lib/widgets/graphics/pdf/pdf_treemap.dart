import 'dart:math' as math;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../graphic_data_models.dart';
import '../graphic_colors.dart';

class PdfTreemap {
  static pw.Widget build(List<VulnerabilityEntry> data, double width, double height) {
    final totalCount = DataAggregator.getTotalCount(data);
    final severityCounts = DataAggregator.getSeverityCounts(data);

    return pw.Container(
      width: width,
      color: PdfColors.white,
      padding: const pw.EdgeInsets.all(24),
      child: pw.Column(
        children: [
          pw.Text('$totalCount Vulnerabilities Across ${DataAggregator.getCategoryCounts(data).length} Categories', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 20),
          pw.Container(width: width - 48, height: 300, child: pw.CustomPaint(painter: (canvas, size) => _drawTreemap(canvas, size, data))),
          pw.SizedBox(height: 15),
          pw.Wrap(spacing: 15, alignment: pw.WrapAlignment.center, children: PdfSeverityColors.severityOrder.where((sev) => severityCounts.containsKey(sev)).map((severity) => pw.Row(mainAxisSize: pw.MainAxisSize.min, children: [pw.Container(width: 12, height: 12, decoration: pw.BoxDecoration(color: PdfSeverityColors.getColor(severity), borderRadius: pw.BorderRadius.circular(2))), pw.SizedBox(width: 6), pw.Text('$severity (${severityCounts[severity]})', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))])).toList()),
        ],
      ),
    );
  }

  static void _drawTreemap(canvas, PdfPoint size, List<VulnerabilityEntry> data) {
    final totalCount = DataAggregator.getTotalCount(data);
    if (totalCount == 0 || size.x <= 0 || size.y <= 0) return;
    final categoryBreakdown = DataAggregator.getCategorySeverityBreakdown(data);
    final items = <MapEntry<String, MapEntry<String, int>>>[];
    categoryBreakdown.forEach((category, severities) {
      severities.forEach((severity, count) {
        if (count > 0) items.add(MapEntry(category, MapEntry(severity, count)));
      });
    });
    items.sort((a, b) => b.value.value.compareTo(a.value.value));
    if (items.isEmpty) return;
    double x = 0, y = 0, remainingWidth = size.x, remainingHeight = size.y;
    for (var item in items) {
      final area = (item.value.value / totalCount) * size.x * size.y;
      if (area <= 0 || remainingWidth <= 0 || remainingHeight <= 0) continue;
      final aspectRatio = remainingWidth / remainingHeight;
      if (aspectRatio.isNaN || aspectRatio.isInfinite) continue;
      final width = math.min(remainingWidth, math.sqrt(area * aspectRatio));
      if (width <= 0 || width.isNaN || width.isInfinite) continue;
      final height = area / width;
      if (height <= 0 || height.isNaN || height.isInfinite) continue;
      canvas..setFillColor(PdfSeverityColors.getColor(item.value.key))..drawRRect(x + 2.0, y + 2.0, width - 4.0, height - 4.0, 4.0, 4.0)..fillPath();
      y += height;
      remainingHeight -= height;
      if (remainingHeight < 20.0) {
        x += width;
        y = 0;
        remainingWidth -= width;
        remainingHeight = size.y;
      }
    }
  }
}
