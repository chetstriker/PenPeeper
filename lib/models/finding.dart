class Finding {
  final int id;
  final int deviceId;
  final String deviceName;
  final String ipAddress;
  final String type;
  final String comment;
  final String? evidence;
  final String? recommendation;
  final DateTime createdAt;
  final String? attackVector;
  final String? attackComplexity;
  final String? privilegesRequired;
  final String? userInteraction;
  final String? scope;
  final String? confidentialityImpact;
  final String? integrityImpact;
  final String? availabilityImpact;
  final double? cvssBaseScore;
  final String? cvssSeverity;
  final String? cveId;
  final String? confidenceLevel;
  final String? vulnerabilityType;
  final String? url;
  final String findingType;
  final String? cvssVersion;
  final int? projectId;
  final String? iconType;

  Finding({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.ipAddress,
    required this.type,
    required this.comment,
    this.evidence,
    this.recommendation,
    required this.createdAt,
    this.attackVector,
    this.attackComplexity,
    this.privilegesRequired,
    this.userInteraction,
    this.scope,
    this.confidentialityImpact,
    this.integrityImpact,
    this.availabilityImpact,
    this.cvssBaseScore,
    this.cvssSeverity,
    this.cveId,
    this.confidenceLevel,
    this.vulnerabilityType,
    this.url,
    this.findingType = 'MANUAL',
    this.cvssVersion,
    this.projectId,
    this.iconType,
  });

  factory Finding.fromMap(Map<String, dynamic> map) {
    return Finding(
      id: map['id'] as int,
      deviceId: map['device_id'] as int,
      deviceName: map['device_name'] as String,
      ipAddress: map['ip_address'] as String,
      type: map['type'] as String,
      comment: map['comment'] as String,
      evidence: map['evidence'] as String?,
      recommendation: map['recommendation'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      attackVector: map['attack_vector'] as String?,
      attackComplexity: map['attack_complexity'] as String?,
      privilegesRequired: map['privileges_required'] as String?,
      userInteraction: map['user_interaction'] as String?,
      scope: map['scope'] as String?,
      confidentialityImpact: map['confidentiality_impact'] as String?,
      integrityImpact: map['integrity_impact'] as String?,
      availabilityImpact: map['availability_impact'] as String?,
      cvssBaseScore: map['cvss_base_score'] != null ? (map['cvss_base_score'] as num).toDouble() : null,
      cvssSeverity: map['cvss_severity'] as String?,
      cveId: map['cve_id'] as String?,
      confidenceLevel: map['confidence_level'] as String?,
      vulnerabilityType: map['vulnerability_type'] as String?,
      url: map['url'] as String?,
      findingType: map['finding_type'] as String? ?? 'MANUAL',
      cvssVersion: map['cvss_version'] as String?,
      projectId: map['project_id'] as int?,
      iconType: map['icon_type'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'device_id': deviceId,
      'device_name': deviceName,
      'ip_address': ipAddress,
      'type': type,
      'comment': comment,
      if (evidence != null) 'evidence': evidence,
      if (recommendation != null) 'recommendation': recommendation,
      'created_at': createdAt.toIso8601String(),
      if (attackVector != null) 'attack_vector': attackVector,
      if (attackComplexity != null) 'attack_complexity': attackComplexity,
      if (privilegesRequired != null) 'privileges_required': privilegesRequired,
      if (userInteraction != null) 'user_interaction': userInteraction,
      if (scope != null) 'scope': scope,
      if (confidentialityImpact != null) 'confidentiality_impact': confidentialityImpact,
      if (integrityImpact != null) 'integrity_impact': integrityImpact,
      if (availabilityImpact != null) 'availability_impact': availabilityImpact,
      if (cvssBaseScore != null) 'cvss_base_score': cvssBaseScore,
      if (cvssSeverity != null) 'cvss_severity': cvssSeverity,
      if (cveId != null) 'cve_id': cveId,
      if (confidenceLevel != null) 'confidence_level': confidenceLevel,
      if (vulnerabilityType != null) 'vulnerability_type': vulnerabilityType,
      if (url != null) 'url': url,
      'finding_type': findingType,
      if (cvssVersion != null) 'cvss_version': cvssVersion,
      if (projectId != null) 'project_id': projectId,
      if (iconType != null) 'icon_type': iconType,
    };
  }
}
