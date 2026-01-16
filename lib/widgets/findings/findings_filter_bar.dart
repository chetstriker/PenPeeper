import 'package:flutter/material.dart';
import 'package:penpeeper/theme_config.dart';

class FindingsFilterBar extends StatelessWidget {
  final List<String> availableOS;
  final List<String> availableVendors;
  final List<String> availableBanners;
  final List<String> availableTags;
  final String selectedOS;
  final String selectedVendor;
  final String selectedBanner;
  final String selectedTag;
  final ValueChanged<String> onOSSelected;
  final ValueChanged<String> onVendorSelected;
  final ValueChanged<String> onBannerSelected;
  final ValueChanged<String> onTagSelected;
  final ValueChanged<String> onScanTypeSelected;

  const FindingsFilterBar({
    super.key,
    required this.availableOS,
    required this.availableVendors,
    required this.availableBanners,
    required this.availableTags,
    required this.selectedOS,
    required this.selectedVendor,
    required this.selectedBanner,
    required this.selectedTag,
    required this.onOSSelected,
    required this.onVendorSelected,
    required this.onBannerSelected,
    required this.onTagSelected,
    required this.onScanTypeSelected,
  });

  @override
  Widget build(BuildContext context) {
    debugPrint('FindingsFilterBar: Building with ${availableTags.length} tags: $availableTags');
    return Row(
      children: [
        _buildFilterButton(
          context: context,
          label: 'Search by OS',
          icon: AppTheme.searchOsIcon,
          iconColor: AppTheme.searchOsIconColor,
          borderColor: AppTheme.searchOsBorderColor,
          items: ['', ...availableOS],
          allLabel: 'All OS',
          onSelected: onOSSelected,
        ),
        const SizedBox(width: 16),
        _buildFilterButton(
          context: context,
          label: 'Search by MAC Vendor',
          icon: AppTheme.searchVendorIcon,
          iconColor: AppTheme.searchVendorIconColor,
          borderColor: AppTheme.searchVendorBorderColor,
          items: ['', ...availableVendors],
          allLabel: 'All Vendors',
          onSelected: onVendorSelected,
        ),
        const SizedBox(width: 16),
        _buildFilterButton(
          context: context,
          label: 'Search by Banner',
          icon: AppTheme.searchBannerIcon,
          iconColor: AppTheme.searchBannerIconColor,
          borderColor: AppTheme.searchBannerBorderColor,
          items: ['', ...availableBanners],
          allLabel: 'All Banners',
          onSelected: onBannerSelected,
        ),
        const SizedBox(width: 16),
        _buildFilterButton(
          context: context,
          label: 'Search by Tag',
          icon: AppTheme.searchTagIcon,
          iconColor: AppTheme.searchTagIconColor,
          borderColor: AppTheme.searchTagBorderColor,
          items: ['', ...availableTags],
          allLabel: 'All Tags',
          onSelected: onTagSelected,
        ),
        const SizedBox(width: 16),
        _buildScanTypeFilter(context),
      ],
    );
  }

  Widget _buildFilterButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required Color iconColor,
    required Color borderColor,
    required List<String> items,
    required String allLabel,
    required ValueChanged<String> onSelected,
  }) {
    return PopupMenuButton<String>(
      tooltip: label,
      onSelected: onSelected,
      itemBuilder: (context) => [
        PopupMenuItem(
          value: '',
          child: Text(allLabel, style: const TextStyle(fontWeight: FontWeight.w500)),
        ),
        const PopupMenuDivider(height: 1),
        ...items.skip(1).expand((item) => [
          PopupMenuItem(
            value: item,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(item),
            ),
          ),
          if (item != items.last) const PopupMenuDivider(height: 1),
        ]),
      ],
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: borderColor, width: 1),
            right: BorderSide(color: borderColor, width: 1),
            bottom: BorderSide(color: borderColor, width: 3),
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
              const SizedBox(width: 8),
              Icon(Icons.arrow_drop_down, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanTypeFilter(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Search by Scan Type',
      onSelected: onScanTypeSelected,
      itemBuilder: (context) => const [
        PopupMenuItem(value: '', child: Text('All Results', style: TextStyle(fontWeight: FontWeight.w500))),
        PopupMenuDivider(height: 1),
        PopupMenuItem(value: 'FFUF', child: Text('FFUF Findings')),
        PopupMenuDivider(height: 1),
        PopupMenuItem(value: 'Nikto', child: Text('Nikto Findings')),
        PopupMenuDivider(height: 1),
        PopupMenuItem(value: 'SAMBA', child: Text('SAMBA/LDAP')),
        PopupMenuDivider(height: 1),
        PopupMenuItem(value: 'SNMP', child: Text('SNMP Findings')),
        PopupMenuDivider(height: 1),
        PopupMenuItem(value: 'WhatWeb', child: Text('WhatWeb Findings')),
        PopupMenuDivider(height: 1),
        PopupMenuItem(value: 'SearchSploit', child: Text('SearchSploit')),
        PopupMenuDivider(height: 1),
        PopupMenuItem(value: 'Vulners', child: Text('Vulners CVEs')),
        PopupMenuDivider(height: 1),
        PopupMenuItem(value: 'Nmap Scripts', child: Text('Nmap Scripts')),
      ],
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: AppTheme.searchScanTypeBorderColor, width: 1),
            right: BorderSide(color: AppTheme.searchScanTypeBorderColor, width: 1),
            bottom: BorderSide(color: AppTheme.searchScanTypeBorderColor, width: 3),
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppTheme.searchScanTypeIcon, color: AppTheme.searchScanTypeIconColor, size: 20),
              const SizedBox(width: 8),
              Text('Search by Scan Type', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6))),
              const SizedBox(width: 8),
              Icon(Icons.arrow_drop_down, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6), size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
