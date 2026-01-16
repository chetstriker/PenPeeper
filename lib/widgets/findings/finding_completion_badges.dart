import 'package:flutter/material.dart';
import 'package:penpeeper/repositories/findings_repository.dart';
import 'package:penpeeper/theme_config.dart';

class FindingCompletionBadges extends StatelessWidget {
  final Map<String, dynamic> finding;

  const FindingCompletionBadges({
    super.key,
    required this.finding,
  });

  String _getCriteriaDisplayName(String criteria) {
    switch (criteria) {
      case 'evidence': return 'Evidence';
      case 'recommendation': return 'Recommendation';
      case 'severity': return 'Severity';
      case 'category': return 'Category';
      case 'subcategory': return 'Subcategory';
      case 'scope': return 'Scope';
      default: return criteria;
    }
  }

  String _getCriteriaTooltip(String criteria) {
    switch (criteria) {
      case 'evidence': return 'Missing Evidence: Add detailed proof or screenshots of the vulnerability';
      case 'recommendation': return 'Missing Recommendation: Add remediation steps or security advice';
      case 'severity': return 'Missing Severity: Set CVSS score and severity level';
      case 'category': return 'Missing Category: Classify the vulnerability type (e.g., Authentication, Authorization)';
      case 'subcategory': return 'Missing Subcategory: Specify the exact vulnerability subtype';
      case 'scope': return 'Missing Scope: Define attack vector scope (Network, Adjacent, Local, Physical)';
      default: return 'Missing required field: $criteria';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: FindingsRepository().getFindingCompletionStatus(finding['id']),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();
        
        final status = snapshot.data!;
        final isComplete = status['is_complete'] as bool;
        final missingCriteria = List<String>.from(status['missing_criteria'] ?? []);
        
        final badges = <Widget>[];
        
        // Add finding type badge first (only for "Needs Investigating")
        if (finding['type'] == 'Needs Investigating') {
          badges.add(Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.warningColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppTheme.warningColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppTheme.searchIcon, color: AppTheme.warningColor, size: 12),
                const SizedBox(width: 4),
                Text(
                  finding['type'],
                  style: TextStyle(
                    color: AppTheme.warningColor,
                    fontSize: AppTheme.fontSizeSmall,
                    fontWeight: AppTheme.fontWeightMedium,
                  ),
                ),
              ],
            ),
          ));
        }
        
        if (isComplete) {
          badges.add(Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.completeStatusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppTheme.completeStatusColor.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(AppTheme.completeStatusIcon, color: AppTheme.completeStatusColor, size: 12),
                const SizedBox(width: 4),
                Text(
                  'Complete',
                  style: TextStyle(
                    color: AppTheme.completeStatusColor,
                    fontSize: AppTheme.fontSizeSmall,
                    fontWeight: AppTheme.fontWeightMedium,
                  ),
                ),
              ],
            ),
          ));
        } else {
          // Add missing criteria badges
          badges.addAll(missingCriteria.map((criteria) => Tooltip(
            message: _getCriteriaTooltip(criteria),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.missingCriteriaColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: AppTheme.missingCriteriaColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(AppTheme.missingCriteriaIcon, color: AppTheme.missingCriteriaColor, size: 12),
                  const SizedBox(width: 4),
                  Text(
                    _getCriteriaDisplayName(criteria),
                    style: TextStyle(
                      color: AppTheme.missingCriteriaColor,
                      fontSize: AppTheme.fontSizeSmall,
                      fontWeight: AppTheme.fontWeightMedium,
                    ),
                  ),
                ],
              ),
            ),
          )));
        }
        
        return Wrap(
          spacing: 4,
          runSpacing: 4,
          children: badges,
        );
      },
    );
  }
}
