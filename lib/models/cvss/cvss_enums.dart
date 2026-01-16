import 'dart:math';

enum AttackVector {
  network(0.85, 'Network', '(Remote) - An attacker can exploit the weakness over the network (often the Internet) without prior access to the target machine; this is the easiest-to-reach vector.'),
  adjacent(0.62, 'Adjacent', '(Same LAN, Wi-Fi, or ISP block) - The attacker must be on the same local or shared network — closer than “Network” but not physically at the device.'),
  local(0.55, 'Local', '(Authenticated / Local Access) — The attacker needs local logon access to an account on the machine (or must run code on it) to exploit the weakness.'),
  physical(0.2, 'Physical', '(Physically There) No log in account, but have physical access to the hardware itself (touching it, stealing it, plugging in media) to take advantage of the weakness.');

  final double value;
  final String label;
  final String description;
  const AttackVector(this.value, this.label, this.description);
}

enum AttackComplexity {
  low(0.77, 'Low', 'No special conditions exist'),
  high(0.44, 'High', 'Success depends on conditions beyond attacker control');

  final double value;
  final String label;
  final String description;
  const AttackComplexity(this.value, this.label, this.description);
}

enum PrivilegesRequired {
  none(0.85, 0.85, 'None', 'No privileges required'),
  low(0.62, 0.68, 'Low', 'Basic user privileges required'),
  high(0.27, 0.5, 'High', 'Administrator privileges required');

  final double unchangedValue;
  final double changedValue;
  final String label;
  final String description;
  const PrivilegesRequired(this.unchangedValue, this.changedValue, this.label, this.description);

  double getValue(bool scopeChanged) => scopeChanged ? changedValue : unchangedValue;
}

enum UserInteraction {
  none(0.85, 'None', 'No user interaction required'),
  required(0.62, 'Required', 'User must take some action');

  final double value;
  final String label;
  final String description;
  const UserInteraction(this.value, this.label, this.description);
}

enum Scope {
  unchanged('Unchanged', 'The vulnerability affects only the vulnerable component'),
  changed('Changed', 'The vulnerability affects resources beyond its security scope');

  final String label;
  final String description;
  const Scope(this.label, this.description);
}

enum Impact {
  none(0.0, 'None', 'No impact'),
  low(0.22, 'Low', 'Minor impact'),
  high(0.56, 'High', 'Total impact');

  final double value;
  final String label;
  final String description;
  const Impact(this.value, this.label, this.description);
}

enum CvssSeverity {
  none('None'),
  low('Low'),
  medium('Medium'),
  high('High'),
  critical('Critical');

  final String label;
  const CvssSeverity(this.label);

  static CvssSeverity fromScore(double score) {
    if (score == 0.0) return none;
    if (score < 4.0) return low;
    if (score < 7.0) return medium;
    if (score < 9.0) return high;
    return critical;
  }
}

class CvssCalculator {
  static double calculateBaseScore({
    required AttackVector attackVector,
    required AttackComplexity attackComplexity,
    required PrivilegesRequired privilegesRequired,
    required UserInteraction userInteraction,
    required Scope scope,
    required Impact confidentialityImpact,
    required Impact integrityImpact,
    required Impact availabilityImpact,
  }) {
    final scopeChanged = scope == Scope.changed;
    
    final impactScore = 1 - ((1 - confidentialityImpact.value) * 
                             (1 - integrityImpact.value) * 
                             (1 - availabilityImpact.value));
    
    final impact = scopeChanged 
        ? 7.52 * (impactScore - 0.029) - 3.25 * pow(impactScore - 0.02, 15)
        : 6.42 * impactScore;
    
    if (impact <= 0) return 0.0;
    
    final exploitability = 8.22 * attackVector.value * 
                          attackComplexity.value * 
                          privilegesRequired.getValue(scopeChanged) * 
                          userInteraction.value;
    
    final baseScore = scopeChanged 
        ? min(1.08 * (impact + exploitability), 10.0)
        : min(impact + exploitability, 10.0);
    
    return (baseScore * 10).roundToDouble() / 10;
  }
}
