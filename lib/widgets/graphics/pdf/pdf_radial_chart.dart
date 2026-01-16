import 'dart:math' as math;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../graphic_data_models.dart';
import '../graphic_colors.dart';

class PdfRadialChart {
  static pw.Widget build(
    List<VulnerabilityEntry> data,
    double width,
    double height,
  ) {
    final severityCounts = DataAggregator.getSeverityCounts(data);
    final categoryCounts = DataAggregator.getCategoryCounts(data);
    final totalCount = DataAggregator.getTotalCount(data);
    final topCategories = (categoryCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(3)
        .toList();

    return pw.Container(
      width: width,
      height: height,
      color: PdfColors.white,
      padding: const pw.EdgeInsets.all(24),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 280,
            height: 280,
            child: pw.Stack(
              alignment: pw.Alignment.center,
              children: [
                pw.CustomPaint(
                  size: const PdfPoint(280, 280),
                  painter: (canvas, size) =>
                      _drawDonutChart(canvas, size, severityCounts, totalCount),
                ),
                pw.Container(
                  width: 140,
                  height: 140,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey200,
                    shape: pw.BoxShape.circle,
                  ),
                  child: pw.Column(
                    mainAxisAlignment: pw.MainAxisAlignment.center,
                    children: [
                      pw.Text(
                        '$totalCount',
                        style: pw.TextStyle(
                          fontSize: 48,
                          fontWeight: pw.FontWeight.bold,
                          color: const PdfColor.fromInt(0xFF1E293B),
                        ),
                      ),
                      pw.Text(
                        'FINDINGS',
                        style: pw.TextStyle(
                          fontSize: 12,
                          color: const PdfColor.fromInt(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(width: 40),
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                ...PdfSeverityColors.severityOrder
                    .where((sev) => severityCounts.containsKey(sev))
                    .map(
                      (severity) => pw.Padding(
                        padding: const pw.EdgeInsets.only(bottom: 12),
                        child: pw.Row(
                          children: [
                            pw.Container(
                              width: 16,
                              height: 16,
                              decoration: pw.BoxDecoration(
                                color: PdfSeverityColors.getColor(severity),
                                borderRadius: pw.BorderRadius.circular(4),
                              ),
                            ),
                            pw.SizedBox(width: 12),
                            pw.SizedBox(
                              width: 80,
                              child: pw.Text(
                                severity,
                                style: pw.TextStyle(
                                  fontSize: 12,
                                  fontWeight: pw.FontWeight.bold,
                                ),
                              ),
                            ),
                            pw.Text(
                              '${severityCounts[severity]}',
                              style: pw.TextStyle(
                                fontSize: 18,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfSeverityColors.getColor(severity),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                if (topCategories.isNotEmpty) ...[ 
                  pw.SizedBox(height: 20),
                  pw.Container(
                    height: 2,
                    color: const PdfColor.fromInt(0xFFE2E8F0),
                    margin: const pw.EdgeInsets.only(bottom: 15),
                  ),
                  pw.Text(
                    'TOP CATEGORIES',
                    style: pw.TextStyle(
                      fontSize: 12,
                      color: const PdfColor.fromInt(0xFF64748B),
                    ),
                  ),
                  pw.SizedBox(height: 8),
                  ...topCategories.map(
                    (cat) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 4, left: 10),
                      child: pw.Text(
                        '- ${cat.key} (${cat.value})',
                        style: pw.TextStyle(
                          fontSize: 11,
                          fontWeight: pw.FontWeight.normal,
                          color: const PdfColor.fromInt(0xFF1E293B),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static void _drawDonutChart(
    canvas,
    PdfPoint size,
    Map<String, int> severityCounts,
    int totalCount,
  ) {
    final center = PdfPoint(size.x / 2, size.y / 2);
    final radius = size.x / 2;
    final innerRadius = radius * 0.57;
    final strokeWidth = radius - innerRadius;

    double startAngle = -math.pi / 2;

    for (var severity in PdfSeverityColors.severityOrder) {
      if (!severityCounts.containsKey(severity)) continue;

      final count = severityCounts[severity]!;
      final sweepAngle = (count / totalCount) * 2 * math.pi;

      canvas.setStrokeColor(PdfSeverityColors.getColor(severity));
      canvas.setLineWidth(strokeWidth);

      final midRadius = (radius + innerRadius) / 2;

      final startX = center.x + midRadius * math.cos(startAngle);
      final startY = center.y + midRadius * math.sin(startAngle);
      canvas.moveTo(startX, startY);

      final segments = 50;
      for (var i = 1; i <= segments; i++) {
        final angle = startAngle + (sweepAngle * i / segments);
        final x = center.x + midRadius * math.cos(angle);
        final y = center.y + midRadius * math.sin(angle);
        canvas.lineTo(x, y);
      }

      canvas.strokePath();

      startAngle += sweepAngle;
    }
  }
}
