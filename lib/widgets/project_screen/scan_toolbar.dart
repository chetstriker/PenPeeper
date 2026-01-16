import 'package:flutter/material.dart';
import 'package:penpeeper/theme_config.dart';

class ScanToolbar extends StatelessWidget {
  final VoidCallback onAddHost;
  final VoidCallback onNmapScan;
  final VoidCallback onNiktoScan;
  final VoidCallback onSearchsploitScan;
  final VoidCallback onWhatwebScan;
  final VoidCallback onEnum4linuxScan;
  final VoidCallback onFfufScan;
  final VoidCallback onSnmpScan;
  final bool hasDevices;
  final bool hasNmapResults;

  const ScanToolbar({
    super.key,
    required this.onAddHost,
    required this.onNmapScan,
    required this.onNiktoScan,
    required this.onSearchsploitScan,
    required this.onWhatwebScan,
    required this.onEnum4linuxScan,
    required this.onFfufScan,
    required this.onSnmpScan,
    this.hasDevices = true,
    this.hasNmapResults = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ShaderMask(
        shaderCallback: (bounds) {
          return const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent,
            ],
            stops: [0.0, 0.05, 0.95, 1.0],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            Tooltip(
              message: 'Add Host or CIDR Range',
              child: TextButton.icon(
                onPressed: onAddHost,
                icon: Icon(
                  AppTheme.scanAddIcon,
                  color: AppTheme.scanAddColor,
                  size: 20,
                ),
                label: Text(
                  'ADD',
                  style: TextStyle(color: AppTheme.scanAddColor),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: hasDevices
                  ? 'NMap Scan All Devices'
                  : 'Devices must exist first. Click ADD to add devices to the project.',
              child: TextButton.icon(
                onPressed: hasDevices ? onNmapScan : null,
                icon: Icon(
                  AppTheme.scanNmapIcon,
                  color: hasDevices ? AppTheme.scanNmapColor : Colors.grey,
                  size: 20,
                ),
                label: Text(
                  'NMap',
                  style: TextStyle(
                    color: hasDevices ? AppTheme.scanNmapColor : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: hasNmapResults
                  ? 'SNMP Scan All Devices'
                  : 'NMap scan must be completed first',
              child: TextButton.icon(
                onPressed: hasNmapResults ? onSnmpScan : null,
                icon: Icon(
                  AppTheme.scanSnmpIcon,
                  color: hasNmapResults ? AppTheme.scanSnmpColor : Colors.grey,
                  size: 20,
                ),
                label: Text(
                  'SNMP',
                  style: TextStyle(
                    color: hasNmapResults
                        ? AppTheme.scanSnmpColor
                        : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: hasNmapResults
                  ? 'Nikto Scan All Web Servers'
                  : 'NMap scan must be completed first',
              child: TextButton.icon(
                onPressed: hasNmapResults ? onNiktoScan : null,
                icon: Icon(
                  AppTheme.scanNiktoIcon,
                  color: hasNmapResults ? AppTheme.scanNiktoColor : Colors.grey,
                  size: 20,
                ),
                label: Text(
                  'Nikto',
                  style: TextStyle(
                    color: hasNmapResults
                        ? AppTheme.scanNiktoColor
                        : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: hasNmapResults
                  ? 'SearchSploit Scan All Devices'
                  : 'NMap scan must be completed first',
              child: TextButton.icon(
                onPressed: hasNmapResults ? onSearchsploitScan : null,
                icon: Icon(
                  AppTheme.scanSearchsploitIcon,
                  color: hasNmapResults
                      ? AppTheme.scanSearchsploitColor
                      : Colors.grey,
                  size: 20,
                ),
                label: Text(
                  'SearchSploit',
                  style: TextStyle(
                    color: hasNmapResults
                        ? AppTheme.scanSearchsploitColor
                        : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: hasNmapResults
                  ? 'WhatWeb Scan All Web Servers'
                  : 'NMap scan must be completed first',
              child: TextButton.icon(
                onPressed: hasNmapResults ? onWhatwebScan : null,
                icon: Icon(
                  AppTheme.scanWhatwebIcon,
                  color: hasNmapResults
                      ? AppTheme.scanWhatwebColor
                      : Colors.grey,
                  size: 20,
                ),
                label: Text(
                  'WhatWeb',
                  style: TextStyle(
                    color: hasNmapResults
                        ? AppTheme.scanWhatwebColor
                        : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: hasNmapResults
                  ? 'Enum4linux-ng Scan All SAMBA and LDAP Devices'
                  : 'NMap scan must be completed first',
              child: TextButton.icon(
                onPressed: hasNmapResults ? onEnum4linuxScan : null,
                icon: Icon(
                  AppTheme.scanEnum4linuxIcon,
                  color: hasNmapResults
                      ? AppTheme.scanEnum4linuxColor
                      : Colors.grey,
                  size: 20,
                ),
                label: Text(
                  'Enum4Linux',
                  style: TextStyle(
                    color: hasNmapResults
                        ? AppTheme.scanEnum4linuxColor
                        : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: hasNmapResults
                  ? 'FFUF Scan All Web Servers'
                  : 'NMap scan must be completed first',
              child: TextButton.icon(
                onPressed: hasNmapResults ? onFfufScan : null,
                icon: Icon(
                  AppTheme.scanFfufIcon,
                  color: hasNmapResults ? AppTheme.scanFfufColor : Colors.grey,
                  size: 20,
                ),
                label: Text(
                  'FFUF',
                  style: TextStyle(
                    color: hasNmapResults
                        ? AppTheme.scanFfufColor
                        : Colors.grey,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 180), // Padding for Magic Button overlap
          ],
        ),
      ),
    );
  }
}
