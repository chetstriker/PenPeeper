import 'package:flutter/material.dart';
import 'package:penpeeper/theme_config.dart';
import 'package:penpeeper/services/scan_status_service.dart';

class EnhancedStatusBar extends StatelessWidget {
  final void Function(String scanType)? onCancel;

  const EnhancedStatusBar({super.key, this.onCancel});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ScanStatusService(),
      builder: (context, _) {
        final statuses = ScanStatusService().statuses;
        if (statuses.isEmpty) return const SizedBox.shrink();

        return _buildStatusBar(context, statuses);
      },
    );
  }

  Widget _buildStatusBar(BuildContext context, List<ScanStatusInfo> statuses) {
    return Container(
      constraints: const BoxConstraints(
        minHeight: 40,
        maxHeight: 200, // Allow up to 5 status lines at 40px each
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        border: Border(
          top: BorderSide(color: AppTheme.borderPrimary, width: 1),
        ),
      ),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: statuses.length,
        itemBuilder: (context, index) {
          return _buildStatusRow(context, statuses[index], index == 0);
        },
      ),
    );
  }

  Widget _buildStatusRow(
    BuildContext context,
    ScanStatusInfo status,
    bool isFirst,
  ) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppTheme.borderSecondary.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _getScanTypeColor(status.scanType).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _getScanTypeColor(
                  status.scanType,
                ).withValues(alpha: 0.3),
                width: 1,
              ),
            ),
            child: Text(
              status.scanType,
              style: TextStyle(
                color: _getScanTypeColor(status.scanType),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              status.message,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (onCancel != null)
            Tooltip(
              message: 'Cancel ${_getCancelButtonLabel(status.scanType)} scans',
              child: IconButton(
                icon: const Icon(Icons.cancel, color: Colors.red, size: 18),
                onPressed: () => onCancel!(status.scanType),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),
        ],
      ),
    );
  }

  String _getCancelButtonLabel(String scanType) {
    final type = scanType.toUpperCase();
    if (type.contains('NMAP')) return 'NMap';
    if (type.contains('NIKTO')) return 'Nikto';
    if (type.contains('SEARCHSPLOIT')) return 'SearchSploit';
    if (type.contains('WHATWEB')) return 'WhatWeb';
    if (type.contains('FFUF') || type.contains('FUZZER')) return 'FFUF';
    if (type.contains('ENUM4LINUX') ||
        type.contains('SAMBA') ||
        type.contains('LDAP')) {
      return 'Enum4Linux';
    }
    if (type.contains('SNMP')) return 'SNMP';
    return scanType;
  }

  Color _getScanTypeColor(String scanType) {
    switch (scanType.toUpperCase()) {
      case 'NMAP':
      case 'AUTO NMAP':
        return Colors.blue;
      case 'NIKTO':
      case 'NIKTO AUTO':
        return Colors.orange;
      case 'SEARCHSPLOIT':
      case 'AUTO SEARCHSPLOIT':
        return Colors.purple;
      case 'WHATWEB':
      case 'AUTO WHATWEB':
        return Colors.green;
      case 'FUZZER':
      case 'AUTO FUZZER':
      case 'FFUF':
        return Colors.cyan;
      case 'SAMBA/LDAP':
      case 'AUTO SAMBA/LDAP':
      case 'ENUM4LINUX':
        return Colors.brown;
      case 'SNMP':
      case 'SNMP AUTO':
        return Colors.indigo;
      case 'ADD DEVICE':
        return Colors.teal;
      default:
        return AppTheme.primaryColor;
    }
  }
}
