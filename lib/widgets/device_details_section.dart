import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:penpeeper/models.dart';
import 'package:penpeeper/device_icon_helper.dart';
import 'package:penpeeper/icon_selector_dialog.dart';
import 'package:penpeeper/theme_config.dart';
import 'package:penpeeper/quill_flag_dialog.dart';
import 'package:penpeeper/screens/project_screen.dart';
import 'package:penpeeper/widgets/device_details/index.dart';
import 'package:penpeeper/repositories/project_repository.dart';
import 'package:penpeeper/repositories/device_repository.dart';
import 'package:penpeeper/repositories/metadata_repository.dart';
import 'package:penpeeper/repositories/vulnerability_repository.dart';
import 'package:penpeeper/repositories/findings_repository.dart';
import 'package:penpeeper/repositories/findings_data_repository.dart';
import 'package:penpeeper/widgets/gradient_border_container.dart';
import 'package:penpeeper/services/project_data_cache.dart';
import 'package:penpeeper/widgets/cve_search_modal.dart';
import 'package:penpeeper/widgets/cve_edit_modal.dart';
import 'package:penpeeper/widgets/finding_type_dialog.dart';
import 'package:penpeeper/models/cvss/cvss_data.dart';
import 'package:penpeeper/utils/quill_embed_helper.dart';
import 'package:penpeeper/widgets/custom_image_embed_builder.dart';

class DeviceDetailsSection extends StatefulWidget {
  final Device device;
  final VoidCallback? onIconChanged;

  const DeviceDetailsSection({
    super.key,
    required this.device,
    this.onIconChanged,
  });

  @override
  State<DeviceDetailsSection> createState() => _DeviceDetailsSectionState();
}

class _DeviceDetailsSectionState extends State<DeviceDetailsSection> {
  final _deviceRepo = DeviceRepository();
  final _metadataRepo = MetadataRepository();
  final _vulnerabilityRepo = VulnerabilityRepository();
  final _findingsRepo = FindingsRepository();
  final _findingsDataRepo = FindingsDataRepository();

  Map<String, dynamic> deviceData = {};
  Map<int, Map<String, dynamic>> deviceMetadata = {};
  bool isLoading = true;
  bool osExpanded = false;
  bool ffufExpanded = false;
  bool niktoExpanded = false;
  String? _currentIconType;
  String? _displayName;

  List<Map<String, dynamic>> allFindings = [];

  @override
  void initState() {
    super.initState();
    _loadDeviceDetails();
  }

  Future<void> _loadDeviceDetails() async {
    try {
      final data = await _metadataRepo.getDeviceDetails(widget.device.id);
      final allVulns = await _vulnerabilityRepo.getAllVulnerabilities(
        widget.device.id,
      );
      final findings = (await _findingsRepo.getFlaggedFindingsForDevice(
        widget.device.id,
      )).map((f) => f.toMap()).toList();
      final metadata = await _metadataRepo.getDeviceMetadata(widget.device.id);

      // Check if device name equals IP address and load FQDN if available
      String? displayName;
      try {
        if (widget.device.name == widget.device.ipAddress) {
          final fqdn = await _findingsDataRepo.getFqdnForDevice(
            widget.device.id,
          );
          if (fqdn != null) {
            displayName = fqdn;
          }
        }
      } catch (e, stackTrace) {
        debugPrint('Error loading FQDN: $e');
        debugPrint('Stack trace: $stackTrace');
      }

      // Check if MAC address is null/empty and try to extract from SNMP findings
      try {
        final macAddress = data['mac_address'] as String?;
        if (macAddress == null || macAddress.isEmpty) {
          final macFromSnmp = await _metadataRepo.extractMacFromSnmpFindings(
            widget.device.id,
          );
          if (macFromSnmp != null) {
            // Update the database with the found MAC address
            await _metadataRepo.updateMacAddressInNmapHosts(
              widget.device.id,
              macFromSnmp,
            );
            // Update the data map so it displays
            data['mac_address'] = macFromSnmp;
          }
        }
      } catch (e, stackTrace) {
        debugPrint('Error extracting MAC from SNMP findings: $e');
        debugPrint('Stack trace: $stackTrace');
        // Continue loading other data even if MAC extraction fails
      }

      if (mounted) {
        setState(() {
          deviceData = data;
          allFindings = findings;
          deviceMetadata[widget.device.id] = metadata;
          _displayName = displayName;
          isLoading = false;
        });
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading device details: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
        ),
      );
    }

    // Check if we have any scan data
    bool hasData =
        deviceData.isNotEmpty &&
        ((deviceData['ports'] != null && deviceData['ports'].isNotEmpty) ||
            (deviceData['cves'] != null && deviceData['cves'].isNotEmpty) ||
            (deviceData['searchsploit_vulnerabilities'] != null &&
                deviceData['searchsploit_vulnerabilities'].isNotEmpty) ||
            (deviceData['whatweb_findings'] != null &&
                deviceData['whatweb_findings'].isNotEmpty) ||
            (deviceData['ffuf_findings'] != null &&
                deviceData['ffuf_findings'].isNotEmpty) ||
            (deviceData['samba_ldap_findings'] != null &&
                deviceData['samba_ldap_findings'].isNotEmpty) ||
            (deviceData['snmp_findings'] != null &&
                deviceData['snmp_findings'].isNotEmpty) ||
            (deviceData['nikto_findings'] != null &&
                deviceData['nikto_findings'].isNotEmpty) ||
            (deviceData['os_matches'] != null &&
                deviceData['os_matches'].isNotEmpty));

    if (!hasData) {
      return Center(
        child: GradientBorderContainer(
          borderConfig:
              AppTheme.borderPrimaryGradient ?? AppTheme.borderPrimary,
          borderRadius: 12,
          borderWidth: 1,
          backgroundColor: AppTheme.surfaceColor,
          child: Container(
            margin: const EdgeInsets.all(32),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  AppTheme.infoOutlineIcon,
                  size: 48,
                  color: AppTheme.primaryColor,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Details Available',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Run an automated scan to populate device details',
                  style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionContainer(
            title: 'Device Information',
            children: [
              _buildIconRow(),
              InfoRow(label: 'Name', value: _displayName ?? widget.device.name),
              InfoRow(label: 'IP Address', value: widget.device.ipAddress),
              if (deviceData['mac_address'] != null &&
                  deviceData['mac_address'].isNotEmpty)
                InfoRow(label: 'MAC Address', value: deviceData['mac_address']),
              if (deviceData['vendor'] != null &&
                  deviceData['vendor'].isNotEmpty)
                InfoRow(label: 'Vendor', value: deviceData['vendor']),
              if (deviceData['netbios_name'] != null &&
                  deviceData['netbios_name'].isNotEmpty)
                InfoRow(
                  label: 'NetBIOS Name',
                  value: deviceData['netbios_name'],
                ),
              if (deviceData['netbios_user'] != null &&
                  deviceData['netbios_user'].isNotEmpty)
                InfoRow(
                  label: 'NetBIOS User',
                  value: deviceData['netbios_user'],
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (deviceData['os_matches'] != null &&
              deviceData['os_matches'].isNotEmpty)
            _buildOsSection(),
          const SizedBox(height: 12),
          if (deviceData['ports'] != null && deviceData['ports'].isNotEmpty)
            _buildPortsSection(),
          const SizedBox(height: 12),
          _buildFlaggedFindingsSection(),
          const SizedBox(height: 12),
          if (deviceData['ffuf_findings'] != null &&
              deviceData['ffuf_findings'].isNotEmpty)
            _buildFfufSection(),
          const SizedBox(height: 12),
          if (deviceData['nikto_findings'] != null &&
              deviceData['nikto_findings'].isNotEmpty)
            _buildNiktoSection(),
          const SizedBox(height: 12),
          if (deviceData['samba_ldap_findings'] != null &&
              deviceData['samba_ldap_findings'].isNotEmpty)
            _buildSambaLdapSection(),
          const SizedBox(height: 12),
          if (deviceData['snmp_findings'] != null &&
              deviceData['snmp_findings'].isNotEmpty)
            _buildSnmpSection(),
          const SizedBox(height: 12),
          if (deviceData['whatweb_findings'] != null &&
              deviceData['whatweb_findings'].isNotEmpty)
            _buildWhatwebSection(),
          const SizedBox(height: 12),
          if (deviceData['cves'] != null && deviceData['cves'].isNotEmpty)
            _buildCveSection(),
          const SizedBox(height: 12),
          if (deviceData['nmap_scripts'] != null &&
              deviceData['nmap_scripts'].isNotEmpty)
            _buildNmapScriptsSection(),
          const SizedBox(height: 12),
          if (deviceData['searchsploit_vulnerabilities'] != null &&
              deviceData['searchsploit_vulnerabilities'].isNotEmpty)
            _buildSearchsploitSection(),
        ],
      ),
    );
  }

  Widget _buildIconRow() {
    final projectState = context.findAncestorStateOfType<ProjectScreenState>();
    final iconType =
        _currentIconType ??
        widget.device.iconType ??
        deviceMetadata[widget.device.id]?['os_type'] ??
        'unknown';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            'Icon: ',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          InkWell(
            onTap: () async {
              final newIconType = await showDialog<String>(
                context: context,
                builder: (context) =>
                    IconSelectorDialog(currentIconType: iconType),
              );

              if (newIconType != null && newIconType != iconType) {
                await _deviceRepo.updateDeviceIcon(
                  widget.device.id,
                  newIconType,
                );
                ProjectDataCache().updateDeviceIcon(
                  widget.device.id,
                  newIconType,
                );
                projectState?.loadDevices();
                widget.onIconChanged?.call();
                if (mounted) {
                  setState(() {
                    _currentIconType = newIconType;
                  });
                }
              }
            },
            child: Tooltip(
              message: 'Click to change icon',
              child: DeviceIconHelper.getIconWidget(iconType, size: 32),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortsSection() {
    return PortsDisplay(
      ports: deviceData['ports'] as List,
      deviceIpAddress: widget.device.ipAddress,
    );
  }

  Widget _buildOsSection() {
    final osMatches = deviceData['os_matches'] as List;
    if (osMatches.isEmpty) return const SizedBox();

    return SectionContainer(
      title: 'Operating System',
      children: [
        InkWell(
          onTap: () {
            if (mounted) {
              setState(() => osExpanded = !osExpanded);
            }
          },
          child: Row(
            children: [
              Expanded(
                child: InfoRow(
                  label: 'OS',
                  value:
                      '${osMatches.first['name']} (${osMatches.first['accuracy']}% accuracy)',
                ),
              ),
              if (osMatches.length > 1)
                Icon(
                  osExpanded
                      ? AppTheme.keyboardArrowUpIcon
                      : AppTheme.keyboardArrowDownIcon,
                  color: AppTheme.primaryColor,
                ),
            ],
          ),
        ),
        if (osExpanded && osMatches.length > 1)
          ...osMatches
              .skip(1)
              .map(
                (os) => Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4),
                  child: InfoRow(
                    label: '',
                    value: '${os['name']} (${os['accuracy']}% accuracy)',
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildCveSection() {
    return ExpandableSection(
      title: 'Nmap Vulners Flagged',
      items: deviceData['cves'] as List,
      itemBuilder: (cve) => CveRow(cve: cve),
    );
  }

  Widget _buildNmapScriptsSection() {
    return ExpandableSection(
      title: 'Nmap Scripts',
      headerColor: AppTheme.sectionHeaderNmapScriptsColor,
      items: deviceData['nmap_scripts'] as List,
      itemBuilder: (script) => NmapScriptRow(script: script),
      initialDisplayCount: 4,
      moreText: 'scripts',
    );
  }

  Widget _buildSearchsploitSection() {
    return ExpandableSection(
      title: 'SearchSploit Flagged',
      headerColor: AppTheme.sectionHeaderSearchsploitColor,
      items: deviceData['searchsploit_vulnerabilities'] as List,
      itemBuilder: (vuln) => _buildSearchsploitRow(vuln),
    );
  }

  Widget _buildSearchsploitRow(Map<String, dynamic> vuln) {
    final title = vuln['title']?.toString() ?? 'Unknown';
    final url = vuln['url']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SelectableText(
            title,
            style: TextStyle(
              color: AppTheme.sectionHeaderSearchsploitColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (url.isNotEmpty)
            InkWell(
              onTap: () async {
                final uri = Uri.parse(url);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri);
                }
              },
              child: SelectableText(
                url,
                style: TextStyle(
                  color: AppTheme.linkColor,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFfufSection() {
    final findings = deviceData['ffuf_findings'] as List;
    if (findings.isEmpty) return const SizedBox();

    final displayedFindings = ffufExpanded
        ? findings
        : findings.take(4).toList();
    final hasMore = findings.length > 4;

    return SectionContainer(
      title: 'Fuzzer Findings (${findings.length})',
      headerColor: AppTheme.sectionHeaderFfufColor,
      trailing: hasMore
          ? InkWell(
              onTap: () {
                if (mounted) {
                  setState(() => ffufExpanded = !ffufExpanded);
                }
              },
              child: Icon(
                ffufExpanded
                    ? AppTheme.keyboardArrowUpIcon
                    : AppTheme.keyboardArrowDownIcon,
                color: Colors.black,
                size: 20,
              ),
            )
          : null,
      children: [
        Table(
          columnWidths: const {
            0: FlexColumnWidth(1),
            1: FixedColumnWidth(80),
            2: FixedColumnWidth(80),
          },
          children: [
            TableRow(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'URL',
                    style: TextStyle(
                      color: AppTheme.sectionHeaderFfufColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Status',
                    style: TextStyle(
                      color: AppTheme.sectionHeaderFfufColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Words',
                    style: TextStyle(
                      color: AppTheme.sectionHeaderFfufColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            for (final finding in displayedFindings)
              _buildFfufTableRow(finding),
          ],
        ),
        if (hasMore && !ffufExpanded)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '... and ${findings.length - 4} more findings',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  TableRow _buildFfufTableRow(Map<String, dynamic> finding) {
    final url = finding['url']?.toString() ?? '';
    final status = finding['status'] as int? ?? 0;
    final words = finding['words'] as int? ?? 0;

    Color statusColor = Colors.grey;
    if (status >= 200 && status < 300) {
      statusColor = Colors.green;
    } else if (status >= 300 && status < 400) {
      statusColor = Colors.orange;
    } else if (status >= 400 && status < 500) {
      statusColor = Colors.red;
    } else if (status >= 500) {
      statusColor = Colors.purple;
    }

    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: SelectableText(
            url,
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            status.toString(),
            style: TextStyle(
              color: statusColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            words.toString(),
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildNiktoSection() {
    final findings = deviceData['nikto_findings'] as List;
    if (findings.isEmpty) return const SizedBox();

    final displayedFindings = niktoExpanded
        ? findings
        : findings.take(4).toList();
    final hasMore = findings.length > 4;

    return SectionContainer(
      title: 'Nikto Findings (${findings.length})',
      headerColor: Colors.deepOrange,
      trailing: hasMore
          ? InkWell(
              onTap: () {
                if (mounted) {
                  setState(() => niktoExpanded = !niktoExpanded);
                }
              },
              child: Icon(
                niktoExpanded
                    ? AppTheme.keyboardArrowUpIcon
                    : AppTheme.keyboardArrowDownIcon,
                color: Colors.black,
                size: 20,
              ),
            )
          : null,
      children: [
        for (final finding in displayedFindings) _buildNiktoRow(finding),
        if (hasMore && !niktoExpanded)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '... and ${findings.length - 4} more findings',
              style: TextStyle(
                color: AppTheme.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNiktoRow(Map<String, dynamic> finding) {
    final itemId = finding['item_id']?.toString() ?? '';
    final description = finding['description']?.toString() ?? '';
    final uri = finding['uri']?.toString() ?? '';
    final namelink = finding['namelink']?.toString() ?? '';
    final iplink = finding['iplink']?.toString() ?? '';
    // Use correct column name from database: references_data
    final references =
        finding['references_data']?.toString() ??
        finding['references']?.toString() ??
        '';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: AppTheme.borderSecondary.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (itemId.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: SelectableText(
                'ID: $itemId',
                style: TextStyle(
                  color: Colors.deepOrange,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          if (description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: SelectableText(
                description,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
              ),
            ),
          if (uri.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: InkWell(
                onTap: () async {
                  final url = Uri.tryParse(uri);
                  if (url != null && await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                },
                child: Text(
                  'URI: $uri',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          if (namelink.isNotEmpty && namelink != iplink)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: InkWell(
                onTap: () async {
                  final url = Uri.tryParse(namelink);
                  if (url != null && await canLaunchUrl(url)) {
                    await launchUrl(url);
                  }
                },
                child: Text(
                  'Link: $namelink',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 12,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          if (references.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: SelectableText(
                'References: $references',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSambaLdapSection() {
    return ExpandableSection(
      title: 'SAMBA/LDAP Findings',
      headerColor: AppTheme.sectionHeaderSambaColor,
      items: deviceData['samba_ldap_findings'] as List,
      itemBuilder: (finding) => _buildSambaLdapRow(finding),
      moreText: 'findings',
    );
  }

  Widget _buildSambaLdapRow(Map<String, dynamic> finding) {
    return _buildTypedFindingRow(
      finding,
      colorMapper: (type) {
        if (type.contains('SMB 1.0') || type.contains('Null Sessions')) {
          return Colors.red;
        }
        if (type.contains('Password') || type.contains('Sessions')) {
          return Colors.orange;
        }
        if (type.contains('Users') ||
            type.contains('Groups') ||
            type.contains('Shares')) {
          return Colors.yellow;
        }
        return Colors.brown;
      },
    );
  }

  Widget _buildSnmpSection() {
    return ExpandableSection(
      title: 'SNMP Findings',
      headerColor: Colors.purple,
      items: deviceData['snmp_findings'] as List,
      itemBuilder: (finding) => _buildSnmpRow(finding),
      moreText: 'findings',
    );
  }

  Widget _buildSnmpRow(Map<String, dynamic> finding) {
    return _buildTypedFindingRow(
      finding,
      colorMapper: (type) {
        if (type.contains('System')) return Colors.blue;
        if (type.contains('Network')) return Colors.green;
        if (type.contains('Process')) return Colors.orange;
        if (type.contains('Windows')) return Colors.red;
        return Colors.purple;
      },
    );
  }

  Widget _buildTypedFindingRow(
    Map<String, dynamic> finding, {
    required Color Function(String) colorMapper,
  }) {
    final findingType = finding['finding_type']?.toString() ?? 'Unknown';
    final findingValue = finding['finding_value']?.toString() ?? 'Unknown';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SelectableText.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$findingType: ',
              style: TextStyle(
                color: colorMapper(findingType),
                fontWeight: FontWeight.bold,
              ),
            ),
            TextSpan(
              text: findingValue,
              style: TextStyle(color: AppTheme.textPrimary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhatwebSection() {
    return SectionContainer(
      title: 'WhatWeb Findings',
      headerColor: AppTheme.sectionHeaderWhatwebColor,
      children: [
        for (final finding in deviceData['whatweb_findings'] as List)
          _buildWhatwebRow(finding),
      ],
    );
  }

  Widget _buildWhatwebRow(Map<String, dynamic> finding) {
    final findingText = finding['finding']?.toString() ?? 'Unknown';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: _buildColoredWhatwebText(findingText),
    );
  }

  Widget _buildColoredWhatwebText(String text) {
    // Regex patterns for WhatWeb
    final titleRegex = RegExp(r'Title:\s*\{string:\s*\[([^\]]*)');
    final headersRegex = RegExp(r'UncommonHeaders:\s*\{string:\s*\[([^\]]*)');
    final passwordRegex = RegExp(r'PasswordField:\s*\{string:\s*\[([^\]]*)');
    final cookiesRegex = RegExp(r'Cookies:\s*\{string:\s*\[([^\]]*)');
    final emailRegex = RegExp(r'Email:\s*\{string:\s*\[([^\]]*)');
    final techRegex = RegExp(
      r'(?<!\w)(WordPress|PHP|Joomla|Magento|Shopify|Python|Ruby|C#|Go|Perl|Rust|Java|AngularJS|React|jQuery|TypeScript|JavaScript|SQL|Apache|Nginx|IIS|Blogger|Google Analytics|Laravel|Cloudflare|Drupal)(?!\w)',
      caseSensitive: false,
    );

    final spans = <TextSpan>[];
    int lastEnd = 0;

    final allMatches = <MapEntry<RegExpMatch, Color>>[];

    // Collect all matches with their colors
    for (final match in titleRegex.allMatches(text)) {
      allMatches.add(MapEntry(match, Colors.green));
    }
    for (final match in headersRegex.allMatches(text)) {
      allMatches.add(MapEntry(match, Colors.orange));
    }
    for (final match in passwordRegex.allMatches(text)) {
      allMatches.add(MapEntry(match, Colors.blue));
    }
    for (final match in cookiesRegex.allMatches(text)) {
      allMatches.add(MapEntry(match, Colors.blue));
    }
    for (final match in emailRegex.allMatches(text)) {
      allMatches.add(MapEntry(match, Colors.red));
    }
    for (final match in techRegex.allMatches(text)) {
      allMatches.add(MapEntry(match, Colors.purple));
    }

    // Sort matches by position and remove overlaps
    allMatches.sort((a, b) => a.key.start.compareTo(b.key.start));

    // Remove overlapping matches
    final filteredMatches = <MapEntry<RegExpMatch, Color>>[];
    for (final entry in allMatches) {
      if (filteredMatches.isEmpty ||
          entry.key.start >= filteredMatches.last.key.end) {
        filteredMatches.add(entry);
      }
    }

    for (final entry in filteredMatches) {
      final match = entry.key;
      final color = entry.value;

      // Add text before match
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: TextStyle(color: AppTheme.textPrimary),
          ),
        );
      }

      // Find the start of the value part [value]
      final valueStart = text.indexOf('[', match.start);
      if (valueStart == -1) {
        // No bracket found, just add the match text
        spans.add(
          TextSpan(
            text: text.substring(match.start, match.end),
            style: TextStyle(color: color),
          ),
        );
        lastEnd = match.end;
        continue;
      }

      final valueEnd = text.indexOf(']', valueStart);
      if (valueEnd == -1) {
        // No closing bracket found, just add from match start to end of text
        spans.add(
          TextSpan(
            text: text.substring(match.start),
            style: TextStyle(color: color),
          ),
        );
        lastEnd = text.length;
        break;
      }

      // Add the key part (uncolored)
      spans.add(
        TextSpan(
          text: text.substring(match.start, valueStart),
          style: TextStyle(color: AppTheme.textPrimary),
        ),
      );

      // Add the colored value part
      spans.add(
        TextSpan(
          text: text.substring(valueStart, valueEnd + 1),
          style: TextStyle(color: color),
        ),
      );

      lastEnd = valueEnd + 1;
    }

    // Add remaining text
    if (lastEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastEnd),
          style: TextStyle(color: AppTheme.textPrimary),
        ),
      );
    }

    // Return colored text if we found matches, otherwise default
    if (spans.isNotEmpty) {
      return SelectableText.rich(TextSpan(children: spans));
    }

    return SelectableText(text, style: TextStyle(color: AppTheme.textPrimary));
  }

  Widget _buildFlaggedFindingsSection() {
    return SectionContainer(
      title: 'Flagged Items',
      headerColor: AppTheme.sectionHeaderFlaggedColor,
      trailing: IconButton(
        icon: const Icon(Icons.add, size: 20),
        onPressed: _addFinding,
        tooltip: 'Add Finding',
        color: Colors.black,
      ),
      children: [
        if (allFindings.isEmpty)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              'No findings flagged',
              style: TextStyle(
                color: AppTheme.textTertiary,
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          for (final finding in allFindings) _buildFlaggedFindingRow(finding),
      ],
    );
  }

  Widget _buildFlaggedFindingRow(Map<String, dynamic> finding) {
    final findingType = finding['finding_type']?.toString() ?? 'MANUAL';
    final type = finding['type']?.toString() ?? 'Unknown';
    final comment = finding['comment']?.toString() ?? '';
    final isCve = findingType == 'CVE';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GradientBorderContainer(
        borderConfig: AppTheme.sectionHeaderFlaggedColor.withValues(alpha: 0.3),
        borderRadius: 6,
        borderWidth: 1,
        backgroundColor: AppTheme.flaggedItemBackground,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isCve)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'CVE',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                Expanded(
                  child: Text(
                    isCve ? (finding['cve_id']?.toString() ?? type) : type,
                    style: TextStyle(
                      color: AppTheme.sectionHeaderFlaggedColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                if (isCve && finding['confidence_level'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: _getConfidenceColor(
                        finding['confidence_level'],
                      ).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      finding['confidence_level'],
                      style: TextStyle(
                        color: _getConfidenceColor(finding['confidence_level']),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (isCve && finding['cvss_base_score'] != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: _getCvssColor(
                        finding['cvss_base_score'],
                      ).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      finding['cvss_base_score'].toStringAsFixed(1),
                      style: TextStyle(
                        color: _getCvssColor(finding['cvss_base_score']),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                IconButton(
                  onPressed: () => _editFlaggedFinding(finding),
                  icon: Icon(AppTheme.editIcon, size: 18),
                  color: AppTheme.primaryColor,
                  tooltip: 'Edit',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => _deleteFlaggedFinding(finding),
                  icon: Icon(AppTheme.deleteIcon, size: 18),
                  color: AppTheme.deleteButtonColor,
                  tooltip: 'Delete',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _buildQuillContent(comment),
          ],
        ),
      ),
    );
  }

  Color _getConfidenceColor(String? level) {
    switch (level) {
      case 'Validated':
        return Colors.green;
      case 'Unsure':
        return Colors.orange;
      default:
        return Colors.yellow;
    }
  }

  Color _getCvssColor(dynamic score) {
    final s = (score as num?)?.toDouble() ?? 0.0;
    if (s >= 9.0) return Colors.red;
    if (s >= 7.0) return Colors.orange;
    if (s >= 4.0) return Colors.yellow;
    return Colors.green;
  }

  Future<void> _deleteFlaggedFinding(Map<String, dynamic> finding) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: Text(
          'Delete Finding',
          style: TextStyle(color: AppTheme.textPrimary),
        ),
        content: Text(
          'Are you sure you want to delete this finding?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.deleteButtonColor,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _findingsRepo.deleteFlaggedFinding(finding['id']);

      ProjectDataCache().updateFindingDeleted(finding['id'], widget.device.id);

      _loadDeviceDetails();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Finding deleted successfully')),
        );
      }
    }
  }

  Future<void> _editFlaggedFinding(Map<String, dynamic> finding) async {
    final findingType = finding['finding_type'] ?? 'MANUAL';

    if (findingType == 'CVE' || finding['cve_id'] != null) {
      await showDialog(
        context: context,
        builder: (context) => CveEditModal(
          finding: finding,
          projectId: widget.device.projectId,
          deviceId: widget.device.id,
          onSaved: () {
            _loadDeviceDetails();
          },
        ),
      );
      return;
    }

    // Edit manual finding
    final projectRepo = ProjectRepository();
    final projects = await projectRepo.getProjects();
    final project = projects.firstWhere((p) => p.id == widget.device.projectId);
    final projectName = project.name;

    final cvssData = CvssData.fromDatabase(finding);
    final flagResult = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => QuillFlagDialog(
        deviceName: widget.device.name,
        projectName: projectName,
        onSubmit: (type, content) {},
        initialComment: finding['comment'],
        initialType: finding['type'],
        isEditing: true,
        initialCvssData: cvssData,
        initialEvidence: finding['evidence'],
        initialRecommendation: finding['recommendation'],
        findingId: finding['id'],
        projectId: widget.device.projectId,
        deviceId: widget.device.id,
      ),
    );

    if (flagResult != null) {
      await _findingsRepo.updateFlaggedFinding(
        finding['id'],
        flagResult['type'],
        flagResult['comment'],
      );

      if (flagResult['evidence'] != null) {
        await _findingsRepo.updateFlaggedFindingEvidence(
          finding['id'],
          flagResult['evidence'],
        );
      }

      if (flagResult['recommendation'] != null) {
        await _findingsRepo.updateFlaggedFindingRecommendation(
          finding['id'],
          flagResult['recommendation'],
        );
      }

      if (flagResult['cvssData'] != null) {
        final cvss = flagResult['cvssData'] as CvssData;
        await _findingsRepo.updateFlaggedFindingCvss(
          finding['id'],
          attackVector: cvss.attackVector?.name,
          attackComplexity: cvss.attackComplexity?.name,
          privilegesRequired: cvss.privilegesRequired?.name,
          userInteraction: cvss.userInteraction?.name,
          scope: cvss.scope?.name,
          confidentialityImpact: cvss.confidentialityImpact?.name,
          integrityImpact: cvss.integrityImpact?.name,
          availabilityImpact: cvss.availabilityImpact?.name,
          cvssBaseScore: cvss.baseScore,
          cvssSeverity: cvss.severity?.name,
        );
      }

      if (flagResult['classification'] != null) {
        final classification =
            flagResult['classification'] as Map<String, dynamic>;
        final vulnRepo = VulnerabilityRepository();
        final existing = await vulnRepo.getVulnerabilityClassifications(
          finding['id'],
        );
        if (existing.isNotEmpty) {
          await vulnRepo.deleteVulnerabilityClassification(existing.first.id);
        }
        if (classification['category'] != null &&
            classification['subcategory'] != null &&
            classification['scope'] != null) {
          await vulnRepo.insertVulnerabilityClassification(
            projectId: widget.device.projectId,
            deviceId: widget.device.id,
            findingId: finding['id'],
            category: classification['category'],
            subcategory: classification['subcategory'],
            description: classification['description'] ?? '',
            mappedOwasp: classification['mapped_owasp'] ?? '',
            mappedCwe: classification['mapped_cwe'] ?? '',
            severityGuideline: classification['severity_guideline'] ?? '',
            scope: classification['scope'],
          );
        }
      }

      final updatedFinding = Map<String, dynamic>.from(finding);
      updatedFinding['type'] = flagResult['type'];
      updatedFinding['comment'] = flagResult['comment'];
      ProjectDataCache().updateFindingUpdated(updatedFinding);

      _loadDeviceDetails();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Finding updated successfully')),
        );
      }
    }
  }

  Widget _buildQuillContent(String comment) {
    try {
      final convertedComment = QuillEmbedHelper.convertDeltaJsonForWeb(comment);
      final delta = jsonDecode(convertedComment ?? comment);
      final document = Document.fromJson(delta);

      final controller = QuillController(
        document: document,
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );

      return QuillEditor(
        controller: controller,
        focusNode: FocusNode(),
        scrollController: ScrollController(),
        config: QuillEditorConfig(
          padding: EdgeInsets.zero,
          embedBuilders: [
            CustomImageEmbedBuilder(),
            ...FlutterQuillEmbeds.editorBuilders(),
          ],
          enableSelectionToolbar: true,
        ),
      );
    } catch (e) {
      return SelectableText(
        comment,
        style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
      );
    }
  }

  Future<void> _addFinding() async {
    final findingType = await showDialog<String>(
      context: context,
      builder: (context) => const FindingTypeDialog(),
    );

    if (findingType == null) return;

    if (findingType == 'CVE') {
      await _addCve();
    } else {
      await _addManualFinding();
    }
  }

  Future<void> _addManualFinding() async {
    final projectRepo = ProjectRepository();
    final projects = await projectRepo.getProjects();
    final project = projects.firstWhere((p) => p.id == widget.device.projectId);
    final projectName = project.name;

    final flagResult = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => QuillFlagDialog(
        deviceName: widget.device.name,
        projectName: projectName,
        onSubmit: (type, content) {},
      ),
    );

    if (flagResult != null) {
      final id = await _findingsRepo.insertFlaggedFinding(
        widget.device.id,
        widget.device.name,
        widget.device.ipAddress,
        flagResult['type'],
        flagResult['comment'],
        findingType: 'MANUAL',
        projectId: widget.device.projectId,
        evidence: flagResult['evidence'],
        recommendation: flagResult['recommendation'],
      );

      if (flagResult['cvssData'] != null) {
        await _updateFindingCvss(id, flagResult['cvssData'] as CvssData);
      }

      if (flagResult['classification'] != null) {
        final classification =
            flagResult['classification'] as Map<String, dynamic>;
        final vulnRepo = VulnerabilityRepository();
        await vulnRepo.insertVulnerabilityClassification(
          projectId: widget.device.projectId,
          deviceId: widget.device.id,
          findingId: id,
          category: classification['category'],
          subcategory: classification['subcategory'],
          description: classification['description'] ?? '',
          mappedOwasp: classification['mapped_owasp'] ?? '',
          mappedCwe: classification['mapped_cwe'] ?? '',
          severityGuideline: classification['severity_guideline'] ?? '',
          scope: classification['scope'],
        );
      }

      _notifyFindingAdded(
        id,
        flagResult['type'],
        flagResult['comment'],
        'MANUAL',
      );
    }
  }

  Future<void> _updateFindingCvss(int findingId, CvssData cvss) async {
    await _findingsRepo.updateFlaggedFindingCvss(
      findingId,
      attackVector: cvss.attackVector?.name,
      attackComplexity: cvss.attackComplexity?.name,
      privilegesRequired: cvss.privilegesRequired?.name,
      userInteraction: cvss.userInteraction?.name,
      scope: cvss.scope?.name,
      confidentialityImpact: cvss.confidentialityImpact?.name,
      integrityImpact: cvss.integrityImpact?.name,
      availabilityImpact: cvss.availabilityImpact?.name,
      cvssBaseScore: cvss.baseScore,
      cvssSeverity: cvss.severity?.name,
    );
  }

  void _notifyFindingAdded(
    int id,
    String type,
    String comment,
    String findingType, {
    Map<String, dynamic>? extraData,
  }) {
    final findingData = {
      'id': id,
      'device_id': widget.device.id,
      'device_name': widget.device.name,
      'device_ip': widget.device.ipAddress,
      'type': type,
      'comment': comment,
      'finding_type': findingType,
      ...?extraData,
    };

    ProjectDataCache().updateFindingAdded(findingData);
    _loadDeviceDetails();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Finding added successfully')),
      );
    }
  }

  Future<void> _addCve() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => CveSearchModal(
        deviceId: widget.device.id,
        projectId: widget.device.projectId,
      ),
    );

    if (result != null) {
      final id = await _findingsRepo.insertFlaggedFinding(
        widget.device.id,
        widget.device.name,
        widget.device.ipAddress,
        'CVE',
        result['description'] ?? '',
        findingType: 'CVE',
        projectId: widget.device.projectId,
        cveId: result['cveId'],
        confidenceLevel: result['confidenceLevel'],
        vulnerabilityType: result['vulnerabilityType'],
        url: result['url'],
        cvssVersion: result['cvssVersion'],
        attackVector: result['attackVector'],
        attackComplexity: result['attackComplexity'],
        privilegesRequired: result['privilegesRequired'],
        userInteraction: result['userInteraction'],
        scope: result['scope'],
        confidentialityImpact: result['confidentialityImpact'],
        integrityImpact: result['integrityImpact'],
        availabilityImpact: result['availabilityImpact'],
        cvssBaseScore: result['cvssScore'],
        cvssSeverity: result['cvssSeverity'],
      );

      _notifyFindingAdded(
        id,
        'CVE',
        result['description'] ?? '',
        'CVE',
        extraData: {
          'cve_id': result['cveId'],
          'confidence_level': result['confidenceLevel'],
          'cvss_base_score': result['cvssScore'],
          'cvss_severity': result['cvssSeverity'],
        },
      );
    }
  }
}
