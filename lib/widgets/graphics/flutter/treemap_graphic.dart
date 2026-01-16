import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../graphic_data_models.dart';
import '../graphic_colors.dart';

class TreemapGraphic extends StatelessWidget {
  final List<VulnerabilityEntry> data;

  const TreemapGraphic({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final totalCount = DataAggregator.getTotalCount(data);
    final severityCounts = DataAggregator.getSeverityCounts(data);

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Text(
            '$totalCount Vulnerabilities Across ${DataAggregator.getCategoryCounts(data).length} Categories',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 20),
          SizedBox(
            height: 280,
            child: CustomPaint(
              size: Size(double.infinity, 280),
              painter: TreemapPainter(data),
            ),
          ),
          SizedBox(height: 15),
          Wrap(
            spacing: 15,
            alignment: WrapAlignment.center,
            children: SeverityColors.severityOrder
                .where((sev) => severityCounts.containsKey(sev))
                .map(
                  (severity) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: SeverityColors.getColor(severity),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      SizedBox(width: 6),
                      Text(
                        '$severity (${severityCounts[severity]})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class TreemapPainter extends CustomPainter {
  final List<VulnerabilityEntry> data;

  TreemapPainter(this.data);

  @override
  void paint(canvas, Size size) {
    final totalCount = DataAggregator.getTotalCount(data);
    final categoryBreakdown = DataAggregator.getCategorySeverityBreakdown(data);

    final items = <MapEntry<String, MapEntry<String, int>>>[];
    categoryBreakdown.forEach((category, severities) {
      severities.forEach((severity, count) {
        items.add(MapEntry(category, MapEntry(severity, count)));
      });
    });
    items.sort((a, b) => b.value.value.compareTo(a.value.value));

    double x = 0, y = 0;
    double remainingWidth = size.width;
    double remainingHeight = size.height;

    for (var item in items) {
      final area = (item.value.value / totalCount) * size.width * size.height;
      final width = math.min(
        remainingWidth,
        math.sqrt(area * (remainingWidth / remainingHeight)),
      );
      final height = area / width;

      final rect = Rect.fromLTWH(x, y, width, height);

      final paint = Paint()
        ..color = SeverityColors.getColor(item.value.key)
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect.deflate(2), Radius.circular(4)),
        paint,
      );

      final textSpan = TextSpan(
        text: '${item.value.value}\n${_abbreviate(item.key)}\n${item.value.key}',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: width > 60 ? 12 : 9,
        ),
      );

      final textPainter = TextPainter(
        text: textSpan,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );

      textPainter.layout(maxWidth: width - 8);
      textPainter.paint(
        canvas,
        Offset(
          x + (width - textPainter.width) / 2,
          y + (height - textPainter.height) / 2,
        ),
      );

      y += height;
      remainingHeight -= height;

      if (remainingHeight < 20) {
        x += width;
        y = 0;
        remainingWidth -= width;
        remainingHeight = size.height;
      }
    }
  }

  String _abbreviate(String text) {
    if (text.length <= 15) return text;
    final words = text.split(' ');
    if (words.length > 1) {
      return '${words.map((w) => w[0]).join('')}.';
    }
    return '${text.substring(0, 12)}...';
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
