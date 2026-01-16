import 'package:flutter/material.dart';
import 'package:penpeeper/theme_config.dart';
import 'package:penpeeper/widgets/scan_components/scan_action_button.dart';

class ScanToolbar extends StatelessWidget {
  final bool isScanning;
  final VoidCallback onNmap;
  final VoidCallback onNikto;
  final VoidCallback onSearchsploit;
  final VoidCallback onWhatweb;
  final VoidCallback onEnum4linux;
  final VoidCallback onFfuf;
  final VoidCallback onSnmp;
  final VoidCallback onProcessNmap;

  const ScanToolbar({
    super.key,
    required this.isScanning,
    required this.onNmap,
    required this.onNikto,
    required this.onSearchsploit,
    required this.onWhatweb,
    required this.onEnum4linux,
    required this.onFfuf,
    required this.onSnmp,
    required this.onProcessNmap,
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
            colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
            stops: [0.0, 0.05, 0.95, 1.0],
          ).createShader(bounds);
        },
        blendMode: BlendMode.dstIn,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            ScanActionButton(
              label: 'NMap',
              icon: AppTheme.scanNmapIcon,
              color: AppTheme.scanNmapColor,
              onPressed: isScanning ? null : onNmap,
              tooltip: 'NMap Scan This Device',
              isLoading: isScanning,
            ),
            const SizedBox(width: 8),
            ScanActionButton(
              label: 'SNMP',
              icon: AppTheme.scanSnmpIcon,
              color: AppTheme.scanSnmpColor,
              onPressed: isScanning ? null : onSnmp,
              tooltip: 'SNMP Scan This Device',
            ),
            const SizedBox(width: 8),
            ScanActionButton(
              label: 'Nikto',
              icon: AppTheme.scanNiktoIcon,
              color: AppTheme.scanNiktoColor,
              onPressed: isScanning ? null : onNikto,
              tooltip: 'Nikto Scan This Device',
            ),
            const SizedBox(width: 8),
            ScanActionButton(
              label: 'SearchSploit',
              icon: AppTheme.scanSearchsploitIcon,
              color: AppTheme.scanSearchsploitColor,
              onPressed: isScanning ? null : onSearchsploit,
              tooltip: 'SearchSploit Scan This Device',
            ),
            const SizedBox(width: 8),
            ScanActionButton(
              label: 'WhatWeb',
              icon: AppTheme.scanWhatwebIcon,
              color: AppTheme.scanWhatwebColor,
              onPressed: isScanning ? null : onWhatweb,
              tooltip: 'WhatWeb Scan This Device',
            ),
            const SizedBox(width: 8),
            ScanActionButton(
              label: 'Enum4Linux',
              icon: AppTheme.scanEnum4linuxIcon,
              color: AppTheme.scanEnum4linuxColor,
              onPressed: isScanning ? null : onEnum4linux,
              tooltip: 'Enum4linux-ng Scan This Device',
            ),
            const SizedBox(width: 8),
            ScanActionButton(
              label: 'FFUF',
              icon: AppTheme.scanFfufIcon,
              color: AppTheme.scanFfufColor,
              onPressed: isScanning ? null : onFfuf,
              tooltip: 'FFUF Scan This Device',
            ),
            const SizedBox(width: 8),
            ScanActionButton(
              label: 'PROCESS NMAP',
              icon: AppTheme.scanProcessNmapIcon,
              color: AppTheme.scanProcessNmapColor,
              onPressed: isScanning ? null : onProcessNmap,
              tooltip: 'PROCESS NMAP',
            ),
          ],
        ),
      ),
    );
  }
}
