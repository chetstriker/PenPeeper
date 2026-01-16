import 'package:flutter/material.dart';
import 'package:penpeeper/device_icon_helper.dart';
import 'package:penpeeper/icon_selector_dialog.dart';
import 'package:penpeeper/repositories/device_repository.dart';
import 'package:penpeeper/services/project_data_cache.dart';
import 'package:penpeeper/theme_config.dart';
import 'package:penpeeper/utils/clipboard_helper.dart';
import 'package:penpeeper/widgets/findings/action_button.dart';
import 'package:penpeeper/widgets/findings/device_tags_widget.dart';
import 'package:penpeeper/widgets/gradient_border_container.dart';

class DeviceSearchResultItem extends StatefulWidget {
  final Map<String, dynamic> result;
  final bool isFlagged;
  final int projectId;
  final String activeFilter;
  final VoidCallback onIconChanged;
  final VoidCallback onViewRecords;
  final VoidCallback onDeviceInfo;
  final VoidCallback onJumpToDevice;
  final VoidCallback onFlagFinding;
  final Future<List<int>> Function(int deviceId) getTelnetPorts;
  final void Function(Map<String, dynamic> device, List<int> ports) onOpenTelnet;

  const DeviceSearchResultItem({
    super.key,
    required this.result,
    required this.isFlagged,
    required this.projectId,
    required this.activeFilter,
    required this.onIconChanged,
    required this.onViewRecords,
    required this.onDeviceInfo,
    required this.onJumpToDevice,
    required this.onFlagFinding,
    required this.getTelnetPorts,
    required this.onOpenTelnet,
  });

  @override
  State<DeviceSearchResultItem> createState() => _DeviceSearchResultItemState();
}

class _DeviceSearchResultItemState extends State<DeviceSearchResultItem> {
  final _deviceRepo = DeviceRepository();
  final _cache = ProjectDataCache();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: IntrinsicHeight(
        child: Row(
          children: [
            if (widget.isFlagged)
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
                borderConfig: widget.isFlagged
                    ? AppTheme.errorColor.withValues(alpha: 0.5)
                    : (AppTheme.borderPrimaryGradient ?? AppTheme.borderPrimary),
                borderRadius: 8,
                borderWidth: 1,
                backgroundColor: widget.isFlagged
                    ? AppTheme.flaggedItemBackground
                    : AppTheme.surfaceColor,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildDeviceIcon(),
                          const SizedBox(width: 12),
                          Expanded(child: _buildDeviceInfo()),
                          _buildActionButtons(),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(left: 56),
                        child: DeviceTagsWidget(
                          deviceId: widget.result['id'],
                          projectId: widget.projectId,
                          onTagsChanged: () => setState(() {}),
                        ),
                      ),
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

  Widget _buildDeviceIcon() {
    return InkWell(
      onTap: () async {
        final deviceId = widget.result['id'] as int;
        final currentIconType = widget.result['icon_type'] ?? 'unknown';
        final newIconType = await showDialog<String>(
          context: context,
          builder: (context) => IconSelectorDialog(
            currentIconType: currentIconType,
          ),
        );

        if (newIconType != null && newIconType != currentIconType) {
          await _deviceRepo.updateDeviceIcon(deviceId, newIconType);
          _cache.updateDeviceIcon(deviceId, newIconType);
          widget.result['icon_type'] = newIconType;
          widget.onIconChanged();
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
            widget.result['icon_type'] ?? 'unknown',
            size: 40,
          ),
        ),
      ),
    );
  }

  Widget _buildDeviceInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () async {
            await ClipboardHelper.copy(
              widget.result['name'] ?? 'Unknown Device',
              successMessage: 'Hostname copied to clipboard',
              context: context,
            );
          },
          child: Text(
            widget.result['name'] ?? 'Unknown Device',
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
        const SizedBox(height: 2),
        Row(
          children: [
            Icon(Icons.location_on, color: AppTheme.textSecondary, size: 14),
            const SizedBox(width: 4),
            InkWell(
              onTap: () async {
                await ClipboardHelper.copy(
                  widget.result['ip_address'] ?? 'Unknown IP',
                  successMessage: 'IP address copied to clipboard',
                  context: context,
                );
              },
              child: Text(
                widget.result['ip_address'] ?? 'Unknown IP',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: AppTheme.fontSizeBodyMedium,
                  fontFamily: AppTheme.monospaceFontFamily.isEmpty
                      ? null
                      : AppTheme.monospaceFontFamily,
                  decoration: TextDecoration.underline,
                  decorationStyle: TextDecorationStyle.dotted,
                ),
              ),
            ),
            if (widget.activeFilter.isNotEmpty) ...[
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${widget.result['count'] ?? 0} findings',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: AppTheme.fontSizeBody,
                    fontWeight: AppTheme.fontWeightMedium,
                    fontFamily: AppTheme.defaultFontFamily.isEmpty
                        ? null
                        : AppTheme.defaultFontFamily,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return FutureBuilder<List<int>>(
      future: widget.getTelnetPorts(widget.result['id']),
      builder: (context, snapshot) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.activeFilter.isNotEmpty) ...[
              ActionButton(
                icon: Icons.list_alt,
                color: AppTheme.actionViewRecordsColor,
                tooltip: 'View Records',
                onPressed: widget.onViewRecords,
              ),
              const SizedBox(width: 6),
            ],
            if (snapshot.hasData && snapshot.data!.isNotEmpty) ...[
              ActionButton(
                icon: Icons.terminal,
                color: AppTheme.actionTelnetColor,
                tooltip: 'Telnet Client',
                onPressed: () => widget.onOpenTelnet(
                  widget.result,
                  snapshot.data!,
                ),
              ),
              const SizedBox(width: 6),
            ],
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
              tooltip: 'Flag it',
              onPressed: widget.onFlagFinding,
            ),
          ],
        );
      },
    );
  }
}
