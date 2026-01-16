import 'package:flutter/material.dart';
import 'package:penpeeper/device_icon_helper.dart';
import 'package:penpeeper/icon_selector_dialog.dart';
import 'package:penpeeper/repositories/device_repository.dart';
import 'package:penpeeper/repositories/findings_repository.dart';
import 'package:penpeeper/services/project_data_cache.dart';
import 'package:penpeeper/theme_config.dart';
import 'package:penpeeper/utils/clipboard_helper.dart';
import 'package:penpeeper/widgets/findings/action_button.dart';
import 'package:penpeeper/widgets/findings/device_tags_widget.dart';
import 'package:penpeeper/widgets/findings/finding_completion_badges.dart';
import 'package:penpeeper/widgets/findings/rich_comment_viewer.dart';
import 'package:penpeeper/widgets/gradient_border_container.dart';

class FlaggedFindingItem extends StatefulWidget {
  final Map<String, dynamic> finding;
  final int projectId;
  final VoidCallback onDeviceInfo;
  final VoidCallback onJumpToDevice;
  final VoidCallback onFlagFinding;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const FlaggedFindingItem({
    super.key,
    required this.finding,
    required this.projectId,
    required this.onDeviceInfo,
    required this.onJumpToDevice,
    required this.onFlagFinding,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<FlaggedFindingItem> createState() => _FlaggedFindingItemState();
}

class _FlaggedFindingItemState extends State<FlaggedFindingItem> {
  final _deviceRepo = DeviceRepository();
  final _findingsRepo = FindingsRepository();
  final _cache = ProjectDataCache();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _findingsRepo.getFindingCompletionStatus(widget.finding['id']),
      builder: (context, completionSnapshot) {
        final isComplete = completionSnapshot.hasData
            ? (completionSnapshot.data!['is_complete'] as bool? ?? false)
            : false;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: GradientBorderContainer(
            borderConfig: isComplete
                ? (AppTheme.borderPrimaryGradient ??
                    AppTheme.completeStatusColor.withValues(alpha: 0.3))
                : (AppTheme.borderPrimaryGradient ??
                    AppTheme.incompleteStatusColor.withValues(alpha: 0.3)),
            borderRadius: 8,
            borderWidth: 1,
            backgroundColor: isComplete
                ? AppTheme.surfaceColor
                : AppTheme.surfaceColor.withValues(alpha: 0.95),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildDeviceIcon(),
                      const SizedBox(width: 12),
                      Expanded(child: _buildFindingInfo(isComplete)),
                      _buildActionButtons(isComplete),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DeviceTagsWidget(
                    deviceId: widget.finding['device_id'],
                    projectId: widget.projectId,
                    onTagsChanged: () => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  RichCommentViewer(comment: widget.finding['comment'] ?? ''),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDeviceIcon() {
    return InkWell(
      onTap: () async {
        final deviceId = widget.finding['device_id'] as int;
        final currentIconType = widget.finding['icon_type'] ?? 'unknown';
        final newIconType = await showDialog<String>(
          context: context,
          builder: (context) => IconSelectorDialog(
            currentIconType: currentIconType,
          ),
        );

        if (newIconType != null && newIconType != currentIconType) {
          await _deviceRepo.updateDeviceIcon(deviceId, newIconType);
          _cache.updateDeviceIcon(deviceId, newIconType);
          setState(() {});
        }
      },
      child: Tooltip(
        message: 'Click to change icon',
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppTheme.primaryColor.withValues(alpha: 0.3),
            ),
          ),
          child: DeviceIconHelper.getIconWidget(
            widget.finding['icon_type'] ?? 'unknown',
            size: 28,
          ),
        ),
      ),
    );
  }

  Widget _buildFindingInfo(bool isComplete) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            InkWell(
              onTap: () async {
                await ClipboardHelper.copy(
                  widget.finding['device_name'] ?? 'Unknown Device',
                  successMessage: 'Hostname copied to clipboard',
                  context: context,
                );
              },
              child: Text(
                widget.finding['device_name'] ?? 'Unknown Device',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: AppTheme.fontSizeSubtitle,
                  fontWeight: AppTheme.fontWeightSemiBold,
                  fontFamily: AppTheme.defaultFontFamily.isEmpty
                      ? null
                      : AppTheme.defaultFontFamily,
                  decoration: TextDecoration.underline,
                  decorationStyle: TextDecorationStyle.dotted,
                ),
              ),
            ),
            if (widget.finding['cve_id'] != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.finding['cve_id'],
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: AppTheme.fontSizeBody,
                    fontWeight: AppTheme.fontWeightMedium,
                  ),
                ),
              ),
            ],
            if (widget.finding['cvss_base_score'] != null) ...[
              const SizedBox(width: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.finding['cvss_base_score'].toStringAsFixed(1),
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: AppTheme.fontSizeBody,
                    fontWeight: AppTheme.fontWeightMedium,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        SizedBox(
          height: 20,
          child: ShaderMask(
            shaderCallback: (Rect bounds) {
              return LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [Colors.white, Colors.white, Colors.transparent],
                stops: [0.0, 0.9, 1.0],
              ).createShader(bounds);
            },
            blendMode: BlendMode.dstIn,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Icon(Icons.location_on, color: AppTheme.textSecondary, size: 14),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () async {
                      await ClipboardHelper.copy(
                        widget.finding['ip_address'] ?? 'Unknown IP',
                        successMessage: 'IP address copied to clipboard',
                        context: context,
                      );
                    },
                    child: Text(
                      widget.finding['ip_address'] ?? 'Unknown IP',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: AppTheme.fontSizeBodyMedium,
                        fontFamily: AppTheme.defaultFontFamily.isEmpty
                            ? null
                            : AppTheme.defaultFontFamily,
                        decoration: TextDecoration.underline,
                        decorationStyle: TextDecorationStyle.dotted,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FindingCompletionBadges(finding: widget.finding),
                  const SizedBox(width: 8),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(bool isComplete) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ActionButton(
          icon: Icons.info_outline,
          color: AppTheme.actionInfoColor,
          tooltip: 'Device Info',
          onPressed: widget.onDeviceInfo,
        ),
        const SizedBox(width: 6),
        ActionButton(
          icon: Icons.launch,
          color: AppTheme.actionJumpColor,
          tooltip: 'Jump to Device',
          onPressed: widget.onJumpToDevice,
        ),
        const SizedBox(width: 6),
        ActionButton(
          icon: Icons.flag,
          color: AppTheme.actionFlagColor,
          tooltip: 'Add Flag',
          onPressed: widget.onFlagFinding,
        ),
        const SizedBox(width: 6),
        ActionButton(
          icon: Icons.edit,
          color: AppTheme.primaryColor,
          tooltip: isComplete
              ? 'Edit Finding Details'
              : 'Complete Missing Information',
          onPressed: widget.onEdit,
        ),
        const SizedBox(width: 6),
        ActionButton(
          icon: Icons.delete,
          color: AppTheme.deleteButtonColor,
          tooltip: 'Delete Finding',
          onPressed: widget.onDelete,
        ),
      ],
    );
  }
}
