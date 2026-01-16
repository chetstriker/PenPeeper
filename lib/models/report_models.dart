class ReportFinding {
  final int id;
  final int deviceId;
  final String deviceName;
  final String ipAddress;
  final String type;
  final String comment;
  final String? evidence;
  final String? recommendation;
  final String? cveId;
  final double? cvssScore;
  final String? cvssSeverity;
  final String? cvssVersion;
  final String? category;
  final String? subcategory;
  final String? macAddress;
  final String? vendor;
  final DateTime createdAt;

  ReportFinding({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.ipAddress,
    required this.type,
    required this.comment,
    this.evidence,
    this.recommendation,
    this.cveId,
    this.cvssScore,
    this.cvssSeverity,
    this.cvssVersion,
    this.category,
    this.subcategory,
    this.macAddress,
    this.vendor,
    required this.createdAt,
  });

  factory ReportFinding.fromMap(Map<String, dynamic> map) {
    return ReportFinding(
      id: map['id'],
      deviceId: map['device_id'],
      deviceName: map['device_name'],
      ipAddress: map['ip_address'],
      type: map['type'],
      comment: map['comment'],
      evidence: map['evidence'],
      recommendation: map['recommendation'],
      cveId: map['cve_id'],
      cvssScore: map['cvss_base_score'] != null ? (map['cvss_base_score'] as num).toDouble() : null,
      cvssSeverity: map['cvss_severity'],
      cvssVersion: map['cvss_version'],
      category: map['category'] ?? 'Uncategorized',
      subcategory: map['subcategory'] ?? 'General',
      macAddress: map['mac_address'],
      vendor: map['vendor'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}

class ReportData {
  final List<ReportFinding> findings;
  final Map<String, List<ReportFinding>> groupedFindings;
  final List<String> availableTags;
  final String? reportHeader;
  final String? executiveSummary;
  final String? methodologyScope;
  final String? riskRatingModel;
  final String? conclusion;
  final String? projectName;
  final int? summaryGraphicOption;
  Map<int, Map<String, dynamic>>? widgetToFindingMap;

  ReportData({
    required this.findings,
    required this.groupedFindings,
    required this.availableTags,
    this.reportHeader,
    this.executiveSummary,
    this.methodologyScope,
    this.riskRatingModel,
    this.conclusion,
    this.projectName,
    this.summaryGraphicOption,
    this.widgetToFindingMap,
  });
}