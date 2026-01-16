import 'package:flutter/material.dart';
import 'package:penpeeper/theme_config.dart';

class NmapScriptRow extends StatefulWidget {
  final Map<String, dynamic> script;

  const NmapScriptRow({super.key, required this.script});

  @override
  State<NmapScriptRow> createState() => _NmapScriptRowState();
}

class _NmapScriptRowState extends State<NmapScriptRow> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final scriptId = widget.script['script_id'] ?? 'unknown';
    final output = widget.script['output'] ?? '';
    final port = widget.script['port'];
    final protocol = widget.script['protocol'] ?? 'tcp';
    final serviceName = widget.script['service_name'] ?? '';

    // Split output into lines and limit to first 3 lines when collapsed
    final lines = output.split('\n');
    final shouldTruncate = lines.length > 3;
    final displayOutput = _isExpanded
        ? output
        : lines.take(3).join('\n') + (shouldTruncate ? '...' : '');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  scriptId,
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (port != null)
                Text(
                  '$port/$protocol',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              if (serviceName.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  '($serviceName)',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              if (shouldTruncate) ...[
                const Spacer(),
                InkWell(
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
                  child: Text(
                    _isExpanded ? 'Show less' : 'Show more',
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(
            displayOutput,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
