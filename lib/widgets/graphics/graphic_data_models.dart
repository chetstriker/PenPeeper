import 'dart:convert';

/// Data model for vulnerability entries
class VulnerabilityEntry {
  final String category;
  final String subcategory;
  final String severity;
  final int count;

  VulnerabilityEntry({
    required this.category,
    required this.subcategory,
    required this.severity,
    required this.count,
  });

  factory VulnerabilityEntry.fromMap(Map<String, dynamic> map) {
    return VulnerabilityEntry(
      category: map['category'] ?? '',
      subcategory: map['subcategory'] ?? '',
      severity: map['severity'] ?? '',
      count: map['count'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'category': category,
      'subcategory': subcategory,
      'severity': severity,
      'count': count,
    };
  }

  static List<VulnerabilityEntry> fromCsv(String csvData) {
    final lines = csvData.trim().split('\n');
    if (lines.isEmpty) return [];
    final startIndex = lines[0].toLowerCase().contains('category') ? 1 : 0;
    return lines.skip(startIndex).map((line) {
      final parts = line.split(',').map((e) => e.trim().replaceAll('"', '')).toList();
      if (parts.length < 4) return null;
      return VulnerabilityEntry(
        category: parts[0],
        subcategory: parts[1],
        severity: parts[2],
        count: int.tryParse(parts[3]) ?? 0,
      );
    }).where((e) => e != null).cast<VulnerabilityEntry>().toList();
  }

  static List<VulnerabilityEntry> fromJson(String jsonData) {
    final List<dynamic> jsonList = json.decode(jsonData);
    return jsonList.map((item) => VulnerabilityEntry.fromMap(item)).toList();
  }
}

class DataAggregator {
  static Map<String, int> getSeverityCounts(List<VulnerabilityEntry> data) {
    final counts = <String, int>{};
    for (var entry in data) {
      counts[entry.severity] = (counts[entry.severity] ?? 0) + entry.count;
    }
    return counts;
  }

  static Map<String, int> getCategoryCounts(List<VulnerabilityEntry> data) {
    final counts = <String, int>{};
    for (var entry in data) {
      counts[entry.category] = (counts[entry.category] ?? 0) + entry.count;
    }
    return counts;
  }

  static Map<String, Map<String, int>> getCategorySeverityBreakdown(
    List<VulnerabilityEntry> data,
  ) {
    final breakdown = <String, Map<String, int>>{};
    for (var entry in data) {
      if (!breakdown.containsKey(entry.category)) {
        breakdown[entry.category] = {};
      }
      breakdown[entry.category]![entry.severity] =
          (breakdown[entry.category]![entry.severity] ?? 0) + entry.count;
    }
    return breakdown;
  }

  static int getTotalCount(List<VulnerabilityEntry> data) {
    return data.fold(0, (sum, entry) => sum + entry.count);
  }
}
