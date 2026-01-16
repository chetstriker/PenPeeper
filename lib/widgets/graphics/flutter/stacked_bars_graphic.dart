import 'package:flutter/material.dart';
import '../graphic_data_models.dart';
import '../graphic_colors.dart';

class StackedBarsGraphic extends StatelessWidget {
  final List<VulnerabilityEntry> data;

  const StackedBarsGraphic({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final categoryBreakdown = DataAggregator.getCategorySeverityBreakdown(data);
    final categoryCounts = DataAggregator.getCategoryCounts(data);
    final totalCount = DataAggregator.getTotalCount(data);
    final severityCounts = DataAggregator.getSeverityCounts(data);

    final sortedCategories = categoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Text(
            '$totalCount Total Vulnerabilities',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 20),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: sortedCategories.map((catEntry) {
                final category = catEntry.key;
                final total = catEntry.value;
                final severities = categoryBreakdown[category] ?? {};

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 120,
                        child: Text(
                          _abbreviateCategory(category),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Row(
                            children: _buildBarSegments(severities, total),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      SizedBox(
                        width: 35,
                        child: Text(
                          '$total',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          SizedBox(height: 15),
          Wrap(
            spacing: 15,
            runSpacing: 8,
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
                          color: Color(0xFF1E293B),
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

  List<Widget> _buildBarSegments(Map<String, int> severities, int total) {
    final segments = <Widget>[];

    for (var severity in SeverityColors.severityOrder) {
      if (!severities.containsKey(severity)) continue;

      final count = severities[severity]!;
      final percentage = count / total;

      if (segments.isNotEmpty) {
        segments.add(Container(width: 2, color: Colors.white));
      }

      segments.add(
        Expanded(
          flex: (percentage * 100).round(),
          child: Container(
            height: 36,
            color: SeverityColors.getColor(severity),
            alignment: Alignment.center,
            child: count > 0
                ? Text(
                    '$count',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  )
                : null,
          ),
        ),
      );
    }

    return segments;
  }

  String _abbreviateCategory(String category) {
    if (category.length <= 20) return category;
    final words = category.split(' ');
    if (words.length > 2) {
      return '${words.take(2).join(' ')}...';
    }
    return '${category.substring(0, 17)}...';
  }
}
