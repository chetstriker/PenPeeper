import 'cvss_enums.dart';

class CvssData {
  final AttackVector? attackVector;
  final AttackComplexity? attackComplexity;
  final PrivilegesRequired? privilegesRequired;
  final UserInteraction? userInteraction;
  final Scope? scope;
  final Impact? confidentialityImpact;
  final Impact? integrityImpact;
  final Impact? availabilityImpact;
  final double? baseScore;
  final CvssSeverity? severity;

  CvssData({
    this.attackVector,
    this.attackComplexity,
    this.privilegesRequired,
    this.userInteraction,
    this.scope,
    this.confidentialityImpact,
    this.integrityImpact,
    this.availabilityImpact,
    this.baseScore,
    this.severity,
  });

  bool get isComplete =>
      attackVector != null &&
      attackComplexity != null &&
      privilegesRequired != null &&
      userInteraction != null &&
      scope != null &&
      confidentialityImpact != null &&
      integrityImpact != null &&
      availabilityImpact != null;

  CvssData calculate() {
    if (!isComplete) return this;
    
    final score = CvssCalculator.calculateBaseScore(
      attackVector: attackVector!,
      attackComplexity: attackComplexity!,
      privilegesRequired: privilegesRequired!,
      userInteraction: userInteraction!,
      scope: scope!,
      confidentialityImpact: confidentialityImpact!,
      integrityImpact: integrityImpact!,
      availabilityImpact: availabilityImpact!,
    );
    
    return copyWith(
      baseScore: score,
      severity: CvssSeverity.fromScore(score),
    );
  }

  CvssData copyWith({
    AttackVector? attackVector,
    AttackComplexity? attackComplexity,
    PrivilegesRequired? privilegesRequired,
    UserInteraction? userInteraction,
    Scope? scope,
    Impact? confidentialityImpact,
    Impact? integrityImpact,
    Impact? availabilityImpact,
    double? baseScore,
    CvssSeverity? severity,
  }) {
    return CvssData(
      attackVector: attackVector ?? this.attackVector,
      attackComplexity: attackComplexity ?? this.attackComplexity,
      privilegesRequired: privilegesRequired ?? this.privilegesRequired,
      userInteraction: userInteraction ?? this.userInteraction,
      scope: scope ?? this.scope,
      confidentialityImpact: confidentialityImpact ?? this.confidentialityImpact,
      integrityImpact: integrityImpact ?? this.integrityImpact,
      availabilityImpact: availabilityImpact ?? this.availabilityImpact,
      baseScore: baseScore ?? this.baseScore,
      severity: severity ?? this.severity,
    );
  }

  factory CvssData.fromDatabase(Map<String, dynamic> data) {
    return CvssData(
      attackVector: _parseAttackVector(data['attack_vector']),
      attackComplexity: _parseAttackComplexity(data['attack_complexity']),
      privilegesRequired: _parsePrivilegesRequired(data['privileges_required']),
      userInteraction: _parseUserInteraction(data['user_interaction']),
      scope: _parseScope(data['scope']),
      confidentialityImpact: _parseImpact(data['confidentiality_impact']),
      integrityImpact: _parseImpact(data['integrity_impact']),
      availabilityImpact: _parseImpact(data['availability_impact']),
      baseScore: data['cvss_base_score'],
      severity: _parseSeverity(data['cvss_severity']),
    );
  }

  Map<String, dynamic> toDatabase() {
    return {
      'attack_vector': attackVector?.name,
      'attack_complexity': attackComplexity?.name,
      'privileges_required': privilegesRequired?.name,
      'user_interaction': userInteraction?.name,
      'scope': scope?.name,
      'confidentiality_impact': confidentialityImpact?.name,
      'integrity_impact': integrityImpact?.name,
      'availability_impact': availabilityImpact?.name,
      'cvss_base_score': baseScore,
      'cvss_severity': severity?.name,
    };
  }

  static AttackVector? _parseAttackVector(String? value) {
    if (value == null) return null;
    return AttackVector.values.firstWhere((e) => e.name == value, orElse: () => AttackVector.network);
  }

  static AttackComplexity? _parseAttackComplexity(String? value) {
    if (value == null) return null;
    return AttackComplexity.values.firstWhere((e) => e.name == value, orElse: () => AttackComplexity.low);
  }

  static PrivilegesRequired? _parsePrivilegesRequired(String? value) {
    if (value == null) return null;
    return PrivilegesRequired.values.firstWhere((e) => e.name == value, orElse: () => PrivilegesRequired.none);
  }

  static UserInteraction? _parseUserInteraction(String? value) {
    if (value == null) return null;
    return UserInteraction.values.firstWhere((e) => e.name == value, orElse: () => UserInteraction.none);
  }

  static Scope? _parseScope(String? value) {
    if (value == null) return null;
    return Scope.values.firstWhere((e) => e.name == value, orElse: () => Scope.unchanged);
  }

  static Impact? _parseImpact(String? value) {
    if (value == null) return null;
    return Impact.values.firstWhere((e) => e.name == value, orElse: () => Impact.none);
  }

  static CvssSeverity? _parseSeverity(String? value) {
    if (value == null) return null;
    return CvssSeverity.values.firstWhere((e) => e.name == value, orElse: () => CvssSeverity.none);
  }
}
