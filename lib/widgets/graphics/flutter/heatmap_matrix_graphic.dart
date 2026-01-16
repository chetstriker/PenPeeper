import 'package:flutter/material.dart';
import '../graphic_data_models.dart';
import '../graphic_colors.dart';

class HeatmapMatrixGraphic extends StatelessWidget {
  final List<VulnerabilityEntry> data;

  const HeatmapMatrixGraphic({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final categoryBreakdown = DataAggregator.getCategorySeverityBreakdown(data);
    final categoryCounts = DataAggregator.getCategoryCounts(data);
    final severityCounts = DataAggregator.getSeverityCounts(data);

    final sortedCategories = categoryCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final activeSeverities = SeverityColors.severityOrder
        .where((sev) => severityCounts.containsKey(sev))
        .toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Text(
            'Vulnerability Distribution Matrix',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 20),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: _buildMatrix(
                    sortedCategories,
                    activeSeverities,
                    categoryBreakdown,
                    severityCounts,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatrix(
    List<MapEntry<String, int>> categories,
    List<String> severities,
    Map<String, Map<String, int>> breakdown,
    Map<String, int> severityCounts,
  ) {
    return Column(
      children: [
        Row(
          children: [
            _buildHeaderCell('Category', flex: 3),
            ...severities.map((sev) => _buildHeaderCell(sev, flex: 1)),
          ],
        ),
        ...categories.map((cat) {
          return Row(
            children: [
              _buildLabelCell(_abbreviateCategory(cat.key), flex: 3),
              ...severities.map((sev) {
                final count = breakdown[cat.key]?[sev] ?? 0;
                return _buildDataCell(count, sev, flex: 1);
              }),
            ],
          );
        }),
        Row(
          children: [
            _buildHeaderCell('TOTAL', flex: 3, color: Color(0xFF3B82F6)),
            ...severities.map((sev) {
              final count = severityCounts[sev] ?? 0;
              return _buildDataCell(count, sev, flex: 1, isTotal: true);
            }),
          ],
        ),
      ],
    );
  }

  Widget _buildHeaderCell(String text, {int flex = 1, Color? color}) {
    return Expanded(
      flex: flex,
      child: Container(
        height: 40,
        margin: EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: color ?? Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildLabelCell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Container(
        height: 40,
        margin: EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: Color(0xFF334155),
          borderRadius: BorderRadius.circular(4),
        ),
        padding: EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 11,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildDataCell(
    int count,
    String severity, {
    int flex = 1,
    bool isTotal = false,
  }) {
    final isEmpty = count == 0;

    return Expanded(
      flex: flex,
      child: Container(
        height: 40,
        margin: EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: isEmpty
              ? Color(0xFFF1F5F9)
              : isTotal
              ? Color(0xFF3B82F6)
              : SeverityColors.getColor(severity),
          borderRadius: BorderRadius.circular(4),
        ),
        alignment: Alignment.center,
        child: Text(
          isEmpty ? '—' : '$count',
          style: TextStyle(
            color: isEmpty ? Color(0xFFCBD5E1) : Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  String _abbreviateCategory(String category) {
    if (category.length <= 25) return category;
    final words = category.split(' ');
    if (words.length > 2) {
      return '${words.take(2).join(' ')}...';
    }
    return '${category.substring(0, 22)}...';
  }
}
