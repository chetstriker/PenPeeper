import 'package:flutter/material.dart';
import '../graphic_data_models.dart';
import '../graphic_colors.dart';

class HorizontalFlowGraphic extends StatelessWidget {
  final List<VulnerabilityEntry> data;

  const HorizontalFlowGraphic({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final totalCount = DataAggregator.getTotalCount(data);
    final severityCounts = DataAggregator.getSeverityCounts(data);
    final categoryBreakdown = DataAggregator.getCategorySeverityBreakdown(data);

    final activeSeverities = SeverityColors.severityOrder
        .where((sev) => severityCounts.containsKey(sev))
        .toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Text(
            '$totalCount Vulnerabilities by Severity & Category',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 20),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: activeSeverities.map((severity) {
                return Expanded(
                  child: _buildSeverityColumn(
                    severity,
                    severityCounts[severity]!,
                    categoryBreakdown,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeverityColumn(
    String severity,
    int count,
    Map<String, Map<String, int>> breakdown,
  ) {
    final categoryItems = <MapEntry<String, int>>[];
    breakdown.forEach((category, severities) {
      if (severities.containsKey(severity)) {
        categoryItems.add(MapEntry(category, severities[severity]!));
      }
    });
    categoryItems.sort((a, b) => b.value.compareTo(a.value));

    final baseColor = SeverityColors.getColor(severity);

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [baseColor, Color.lerp(baseColor, Colors.black, 0.2)!],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          Text(
            severity,
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
          SizedBox(height: 10),
          Text(
            '$count',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 15),
          Expanded(
            child: ListView.builder(
              itemCount: categoryItems.length,
              itemBuilder: (context, index) {
                final item = categoryItems[index];
                return Container(
                  margin: EdgeInsets.only(bottom: 6),
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _abbreviateCategory(item.key),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        '${item.value}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _abbreviateCategory(String category) {
    if (category.length <= 20) return category;
    final words = category.split(' ');
    if (words.length > 2) {
      return words.take(2).join(' ');
    }
    return '${category.substring(0, 17)}...';
  }
}
