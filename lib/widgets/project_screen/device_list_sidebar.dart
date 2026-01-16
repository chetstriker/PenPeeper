import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:penpeeper/models.dart';
import 'package:penpeeper/theme_config.dart';
import 'package:penpeeper/device_icon_helper.dart';
import 'package:penpeeper/icon_selector_dialog.dart';
import 'package:penpeeper/widgets/gradient_button.dart';
import 'package:penpeeper/services/project_data_cache.dart';

class DeviceListSidebar extends StatefulWidget {
  final List<Device> devices;
  final Device? selectedDevice;
  final Set<int> failedDeviceIds;
  final Map<int, Map<String, dynamic>> deviceMetadata;
  final bool isLoadingDevices;
  final String deviceLoadingStatus;
  final int devicesLoaded;
  final int totalDevices;
  final ScrollController scrollController;
  final VoidCallback onAddDevice;
  final VoidCallback onSearchDevice;
  final Function(Device) onDeviceSelected;
  final Function(Device) onDeleteDevice;
  final Function(Device, String) onIconChanged;

  const DeviceListSidebar({
    super.key,
    required this.devices,
    required this.selectedDevice,
    required this.failedDeviceIds,
    required this.deviceMetadata,
    required this.isLoadingDevices,
    required this.deviceLoadingStatus,
    required this.devicesLoaded,
    required this.totalDevices,
    required this.scrollController,
    required this.onAddDevice,
    required this.onSearchDevice,
    required this.onDeviceSelected,
    required this.onDeleteDevice,
    required this.onIconChanged,
  });

  @override
  State<DeviceListSidebar> createState() => _DeviceListSidebarState();
}

class _DeviceListSidebarState extends State<DeviceListSidebar> {
  final FocusNode _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Widget _getOsIcon(BuildContext context, String osType, Device device) {
    final icon = DeviceIconHelper.getIconWidget(osType, size: 16);
    
    return InkWell(
      onTap: () async {
        final newIconType = await showDialog<String>(
          context: context,
          builder: (context) => IconSelectorDialog(currentIconType: osType),
        );

        if (newIconType != null && newIconType != osType) {
          widget.onIconChanged(device, newIconType);
        }
      },
      child: Tooltip(
        message: 'Click to change icon',
        child: icon,
      ),
    );
  }

  void _scrollToIndex(int index) {
    if (!widget.scrollController.hasClients) return;

    const itemHeight = 80.0;
    final position = widget.scrollController.position;
    final viewportHeight = position.viewportDimension;
    final currentScroll = position.pixels;
    
    final targetTop = index * itemHeight;
    final targetBottom = (index + 1) * itemHeight;

    if (targetTop < currentScroll) {
      widget.scrollController.animateTo(
        targetTop,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    } else if (targetBottom > currentScroll + viewportHeight) {
      widget.scrollController.animateTo(
        targetBottom - viewportHeight,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 250,
      color: AppTheme.surfaceColor,
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent && widget.devices.isNotEmpty) {
            if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
              final currentIndex = widget.selectedDevice != null
                  ? widget.devices.indexWhere((d) => d.id == widget.selectedDevice!.id)
                  : -1;
              final nextIndex = (currentIndex + 1) % widget.devices.length;
              widget.onDeviceSelected(widget.devices[nextIndex]);
              _scrollToIndex(nextIndex);
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
              final currentIndex = widget.selectedDevice != null
                  ? widget.devices.indexWhere((d) => d.id == widget.selectedDevice!.id)
                  : 0;
              final prevIndex = currentIndex <= 0 ? widget.devices.length - 1 : currentIndex - 1;
              widget.onDeviceSelected(widget.devices[prevIndex]);
              _scrollToIndex(prevIndex);
              return KeyEventResult.handled;
            }
          }
          return KeyEventResult.ignored;
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: GradientButton(
                      label: 'Add Device(s)',
                      icon: AppTheme.addIcon,
                      backgroundConfig: AppTheme.primaryButtonGradient ?? AppTheme.primaryColor,
                      onPressed: widget.onAddDevice,
                      textColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Device Search',
                    child: IconButton(
                      onPressed: widget.onSearchDevice,
                      icon: Icon(AppTheme.searchIcon, color: AppTheme.primaryColor),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: widget.isLoadingDevices
                  ? Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            widget.deviceLoadingStatus,
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (widget.totalDevices > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: LinearProgressIndicator(
                                value: widget.devicesLoaded / widget.totalDevices,
                                backgroundColor: AppTheme.borderPrimary,
                                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                              ),
                            ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: widget.scrollController,
                      itemCount: widget.devices.length,
                      itemBuilder: (context, index) {
                        final device = widget.devices[index];
                        final isFailed = widget.failedDeviceIds.contains(device.id);
                        final metadata = widget.deviceMetadata[device.id] ?? {};
                        final isSelected = widget.selectedDevice?.id == device.id;
                        final cache = ProjectDataCache();
                        final hasFlags = cache.flaggedDeviceIds.contains(device.id);
                        
                        return Stack(
                          children: [
                            Container(
                              height: 80.0,
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.primaryColor.withValues(alpha: 0.3) : null,
                                border: isSelected ? Border.all(color: AppTheme.primaryColor, width: 2) : null,
                              ),
                              child: ListTile(
                                dense: true,
                                leading: _getOsIcon(
                                  context,
                                  device.iconType ?? metadata['os_type'] ?? 'unknown',
                                  device,
                                ),
                                title: Text(
                                  device.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isFailed 
                                        ? Colors.red 
                                        : metadata['has_http_services'] == true
                                            ? Colors.green
                                            : null,
                                    fontWeight: isSelected ? FontWeight.bold : null,
                                  ),
                                ),
                                subtitle: Text(
                                  device.ipAddress,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isFailed 
                                        ? Colors.red.withValues(alpha: 0.7)
                                        : metadata['has_database_services'] == true
                                            ? Colors.blue
                                            : null,
                                    fontWeight: isSelected ? FontWeight.w500 : null,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: Icon(AppTheme.deleteIcon, size: 18, color: AppTheme.iconSecondary),
                                  onPressed: () => widget.onDeleteDevice(device),
                                ),
                                onTap: () {
                                  widget.onDeviceSelected(device);
                                  _focusNode.requestFocus();
                                },
                              ),
                            ),
                            if (hasFlags)
                              Positioned.fill(
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: FractionallySizedBox(
                                    heightFactor: 0.7,
                                    child: Container(
                                      width: 20,
                                      color: Colors.red,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
