import 'package:flutter/material.dart';
import 'package:penpeeper/models/cvss/cvss_enums.dart';
import 'package:penpeeper/models/cvss/cvss_data.dart';
import 'package:penpeeper/theme_config.dart';
import 'package:penpeeper/widgets/gradient_border_container.dart';

class CvssCalculatorSidebar extends StatefulWidget {
  final CvssData? initialData;
  final Function(CvssData) onSave;

  const CvssCalculatorSidebar({
    super.key,
    this.initialData,
    required this.onSave,
  });

  @override
  State<CvssCalculatorSidebar> createState() => _CvssCalculatorSidebarState();
}

class _CvssCalculatorSidebarState extends State<CvssCalculatorSidebar> {
  late CvssData _cvssData;

  @override
  void initState() {
    super.initState();
    _cvssData = widget.initialData ?? CvssData();
  }

  void _updateMetric(CvssData newData) {
    setState(() {
      _cvssData = newData.calculate();
    });
  }

  Color _getSeverityColor() {
    if (_cvssData.severity == null) return Colors.grey;
    switch (_cvssData.severity!) {
      case CvssSeverity.none:
        return Colors.grey;
      case CvssSeverity.low:
        return Colors.green;
      case CvssSeverity.medium:
        return Colors.yellow;
      case CvssSeverity.high:
        return Colors.orange;
      case CvssSeverity.critical:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 350,
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.cardBackground,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(Icons.calculate, color: AppTheme.primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  'CVSS Calculator',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),

          // Score Display
          if (_cvssData.baseScore != null)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getSeverityColor().withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _getSeverityColor(), width: 2),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.textPrimary.withValues(alpha: 0.5),
                    blurRadius: 6,
                    offset: const Offset(2, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    _cvssData.baseScore!.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: _getSeverityColor(),
                      shadows: [
                        Shadow(
                          color: AppTheme.textPrimary.withValues(alpha: 0.8),
                          blurRadius: 3,
                          offset: const Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _cvssData.severity!.label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _getSeverityColor(),
                      shadows: [
                        Shadow(
                          color: AppTheme.textPrimary.withValues(alpha: 0.8),
                          blurRadius: 3,
                          offset: const Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Metrics
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildDropdown<AttackVector>(
                  'Attack Vector',
                  AttackVector.values,
                  _cvssData.attackVector,
                  (v) => _updateMetric(_cvssData.copyWith(attackVector: v)),
                ),
                _buildDropdown<AttackComplexity>(
                  'Attack Complexity',
                  AttackComplexity.values,
                  _cvssData.attackComplexity,
                  (v) => _updateMetric(_cvssData.copyWith(attackComplexity: v)),
                ),
                _buildDropdown<PrivilegesRequired>(
                  'Privileges Required',
                  PrivilegesRequired.values,
                  _cvssData.privilegesRequired,
                  (v) => _updateMetric(_cvssData.copyWith(privilegesRequired: v)),
                ),
                _buildDropdown<UserInteraction>(
                  'User Interaction',
                  UserInteraction.values,
                  _cvssData.userInteraction,
                  (v) => _updateMetric(_cvssData.copyWith(userInteraction: v)),
                ),
                _buildDropdown<Scope>(
                  'Scope',
                  Scope.values,
                  _cvssData.scope,
                  (v) => _updateMetric(_cvssData.copyWith(scope: v)),
                ),
                _buildDropdown<Impact>(
                  'Confidentiality',
                  Impact.values,
                  _cvssData.confidentialityImpact,
                  (v) => _updateMetric(_cvssData.copyWith(confidentialityImpact: v)),
                ),
                _buildDropdown<Impact>(
                  'Integrity',
                  Impact.values,
                  _cvssData.integrityImpact,
                  (v) => _updateMetric(_cvssData.copyWith(integrityImpact: v)),
                ),
                _buildDropdown<Impact>(
                  'Availability',
                  Impact.values,
                  _cvssData.availabilityImpact,
                  (v) => _updateMetric(_cvssData.copyWith(availabilityImpact: v)),
                ),
              ],
            ),
          ),

          // Actions
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _cvssData.isComplete
                        ? () => widget.onSave(_cvssData)
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Save CVSS'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown<T>(
    String label,
    List<T> values,
    T? currentValue,
    Function(T) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GradientBorderContainer(
        borderConfig: AppTheme.borderSecondaryGradient ?? AppTheme.borderSecondary,
        borderRadius: 8,
        borderWidth: 1,
        backgroundColor: AppTheme.cardBackground,
        child: DropdownButtonFormField<T>(
          initialValue: currentValue,
          dropdownColor: AppTheme.cardBackground,
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
          iconEnabledColor: AppTheme.textPrimary,
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(color: AppTheme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          items: values.map((value) {
            String itemLabel = '';
            String? description;
            
            if (value is AttackVector) {
              itemLabel = value.label.toUpperCase();
              description = value.description;
            } else if (value is AttackComplexity) {
              itemLabel = value.label.toUpperCase();
              description = value.description;
            } else if (value is PrivilegesRequired) {
              itemLabel = value.label.toUpperCase();
              description = value.description;
            } else if (value is UserInteraction) {
              itemLabel = value.label.toUpperCase();
              description = value.description;
            } else if (value is Scope) {
              itemLabel = value.label.toUpperCase();
              description = value.description;
            } else if (value is Impact) {
              itemLabel = value.label.toUpperCase();
              description = value.description;
            }

            return DropdownMenuItem<T>(
              value: value,
              child: Tooltip(
                message: description ?? '',
                child: Text(itemLabel, style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      ),
    );
  }
}
