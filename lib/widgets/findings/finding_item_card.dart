import 'package:flutter/material.dart';
import 'package:penpeeper/device_icon_helper.dart';
import 'package:penpeeper/icon_selector_dialog.dart';
import 'package:penpeeper/repositories/device_repository.dart';
import 'package:penpeeper/services/project_data_cache.dart';
import 'package:penpeeper/theme_config.dart';
import 'package:penpeeper/utils/clipboard_helper.dart';
import 'package:penpeeper/widgets/findings/device_tags_widget.dart';
import 'package:penpeeper/widgets/findings/finding_completion_badges.dart';
import 'package:penpeeper/widgets/gradient_border_container.dart';

class FindingItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final int projectId;
  final bool isFlagged;
  final bool showCompletionBadges;
  final List<Widget> actionButtons;
  final Widget? content;
  final VoidCallback? onIconChanged;
  final VoidCallback? onTagsChanged;

  const FindingItemCard({
    super.key,
    required this.item,
    required this.projectId,
    this.isFlagged = false,
    this.showCompletionBadges = false,
    required this.actionButtons,
    this.content,
    this.onIconChanged,
    this.onTagsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final deviceId = item['device_id'] ?? item['id'];
    final deviceName = item['device_name'] ?? item['name'] ?? 'Unknown Device';
    final ipAddress = item['ip_address'] ?? 'Unknown IP';
    final iconType = item['icon_type'] ?? 'unknown';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: IntrinsicHeight(
        child: Row(
          children: [
            if (isFlagged)
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: AppTheme.errorColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                ),
              ),
            Expanded(
              child: GradientBorderContainer(
                borderConfig: isFlagged 
                  ? AppTheme.errorColor.withValues(alpha: 0.5)
                  : (AppTheme.borderPrimaryGradient ?? AppTheme.borderPrimary),
                borderRadius: 8,
                borderWidth: 1,
                backgroundColor: isFlagged ? AppTheme.flaggedItemBackground : AppTheme.surfaceColor,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          InkWell(
                            onTap: () async {
                              final newIconType = await showDialog<String>(
                                context: context,
                                builder: (context) => IconSelectorDialog(currentIconType: iconType),
                              );
                              
                              if (newIconType != null && newIconType != iconType) {
                                await DeviceRepository().updateDeviceIcon(deviceId, newIconType);
                                ProjectDataCache().updateDeviceIcon(deviceId, newIconType);
                                onIconChanged?.call();
                              }
                            },
                            child: Tooltip(
                              message: 'Click to change icon',
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                                ),
                                child: DeviceIconHelper.getIconWidget(iconType, size: showCompletionBadges ? 28 : 40),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildDeviceNameRow(context, deviceName, item),
                                const SizedBox(height: 2),
                                _buildIpAddressRow(context, ipAddress, item, showCompletionBadges),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: actionButtons.map((btn) => Padding(
                              padding: const EdgeInsets.only(left: 6),
                              child: btn,
                            )).toList(),
                          ),
                        ],
                      ),
                      if (!showCompletionBadges) ...[
                        const SizedBox(height: 6),
                        Padding(
                          padding: const EdgeInsets.only(left: 56),
                          child: DeviceTagsWidget(
                            deviceId: deviceId,
                            projectId: projectId,
                            onTagsChanged: onTagsChanged ?? () {},
                          ),
                        ),
                      ],
                      if (showCompletionBadges) ...[
                        const SizedBox(height: 8),
                        DeviceTagsWidget(
                          deviceId: deviceId,
                          projectId: projectId,
                          onTagsChanged: onTagsChanged ?? () {},
                        ),
                      ],
                      if (content != null) ...[
                        const SizedBox(height: 8),
                        content!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceNameRow(BuildContext context, String deviceName, Map<String, dynamic> item) {
    final widgets = <Widget>[
      InkWell(
        onTap: () async {
          await ClipboardHelper.copy(
            deviceName,
            successMessage: 'Hostname copied to clipboard',
            context: context,
          );
        },
        child: Text(
          deviceName,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: AppTheme.fontSizeSubtitle,
            fontWeight: AppTheme.fontWeightSemiBold,
            fontFamily: AppTheme.defaultFontFamily.isEmpty ? null : AppTheme.defaultFontFamily,
            decoration: TextDecoration.underline,
            decorationStyle: TextDecorationStyle.dotted,
          ),
        ),
      ),
    ];

    // Add CVE badge if present
    if (item['cve_id'] != null) {
      widgets.addAll([
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            item['cve_id'],
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontSize: AppTheme.fontSizeBody,
              fontWeight: AppTheme.fontWeightMedium,
            ),
          ),
        ),
      ]);
    }

    // Add CVSS score if present
    if (item['cvss_base_score'] != null) {
      widgets.addAll([
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            item['cvss_base_score'].toStringAsFixed(1),
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontSize: AppTheme.fontSizeBody,
              fontWeight: AppTheme.fontWeightMedium,
            ),
          ),
        ),
      ]);
    }

    return Row(children: widgets);
  }

  Widget _buildIpAddressRow(BuildContext context, String ipAddress, Map<String, dynamic> item, bool showBadges) {
    final widgets = <Widget>[
      Icon(Icons.location_on, color: AppTheme.textSecondary, size: 14),
      const SizedBox(width: 4),
      InkWell(
        onTap: () async {
          await ClipboardHelper.copy(
            ipAddress,
            successMessage: 'IP address copied to clipboard',
            context: context,
          );
        },
        child: Text(
          ipAddress,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: AppTheme.fontSizeBodyMedium,
            fontFamily: AppTheme.monospaceFontFamily.isEmpty ? null : AppTheme.monospaceFontFamily,
            decoration: TextDecoration.underline,
            decorationStyle: TextDecorationStyle.dotted,
          ),
        ),
      ),
    ];

    // Add finding count badge if present
    if (item['count'] != null) {
      widgets.addAll([
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${item['count']} findings',
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontSize: AppTheme.fontSizeBody,
              fontWeight: AppTheme.fontWeightMedium,
              fontFamily: AppTheme.defaultFontFamily.isEmpty ? null : AppTheme.defaultFontFamily,
            ),
          ),
        ),
      ]);
    }

    // Add completion badges if enabled
    if (showBadges) {
      widgets.addAll([
        const SizedBox(width: 12),
        FindingCompletionBadges(finding: item),
        const SizedBox(width: 8),
      ]);
    }

    return Row(children: widgets);
  }
}
