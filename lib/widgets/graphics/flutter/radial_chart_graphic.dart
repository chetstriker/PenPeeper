import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../graphic_data_models.dart';
import '../graphic_colors.dart';

class RadialChartGraphic extends StatelessWidget {
  final List<VulnerabilityEntry> data;

  const RadialChartGraphic({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final severityCounts = DataAggregator.getSeverityCounts(data);
    final categoryCounts = DataAggregator.getCategoryCounts(data);
    final totalCount = DataAggregator.getTotalCount(data);
    final topCategories = (categoryCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .take(3)
        .toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          SizedBox(
            width: 280,
            height: 280,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: Size(280, 280),
                  painter: DonutChartPainter(severityCounts, totalCount),
                ),
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '$totalCount',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      Text(
                        'FINDINGS',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 40),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ...SeverityColors.severityOrder
                    .where((sev) => severityCounts.containsKey(sev))
                    .map(
                      (severity) => Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          children: [
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                color: SeverityColors.getColor(severity),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                severity,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                            ),
                            Text(
                              '${severityCounts[severity]}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: SeverityColors.getColor(severity),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                if (topCategories.isNotEmpty) ...[ 
                  SizedBox(height: 20),
                  Container(
                    height: 2,
                    color: Color(0xFFE2E8F0),
                    margin: EdgeInsets.only(bottom: 15),
                  ),
                  Text(
                    'TOP CATEGORIES',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      letterSpacing: 1.2,
                    ),
                  ),
                  SizedBox(height: 8),
                  ...topCategories.map(
                    (cat) => Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        '• ${cat.key} (${cat.value})',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1E293B),
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
}

class DonutChartPainter extends CustomPainter {
  final Map<String, int> severityCounts;
  final int totalCount;

  DonutChartPainter(this.severityCounts, this.totalCount);

  @override
  void paint(canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final innerRadius = radius * 0.57;

    double startAngle = -math.pi / 2;

    for (var severity in SeverityColors.severityOrder) {
      if (!severityCounts.containsKey(severity)) continue;

      final count = severityCounts[severity]!;
      final sweepAngle = (count / totalCount) * 2 * math.pi;

      final paint = Paint()
        ..color = SeverityColors.getColor(severity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = radius - innerRadius;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: (radius + innerRadius) / 2),
        startAngle,
        sweepAngle,
        false,
        paint,
      );

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
