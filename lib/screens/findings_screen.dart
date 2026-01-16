import 'package:flutter/material.dart';
import 'package:penpeeper/services/project_data_cache.dart';
import 'package:penpeeper/screens/findings/findings_flagged_screen.dart';
import 'package:penpeeper/theme_config.dart';
import 'package:penpeeper/widgets/findings/index.dart';
import 'package:penpeeper/widgets/gradient_border_container.dart';
import 'package:penpeeper/services/findings/device_search_service.dart';
import 'package:penpeeper/repositories/metadata_repository.dart';
import 'package:penpeeper/repositories/device_repository.dart';
import 'package:penpeeper/repositories/search_repository.dart';
import 'package:penpeeper/screens/project_screen.dart';
import 'package:penpeeper/telnet_client_modal.dart';
import 'package:penpeeper/icon_selector_dialog.dart';
import 'package:penpeeper/services/findings/findings_export_coordinator.dart';
import 'package:penpeeper/services/findings/finding_creation_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:penpeeper/repositories/findings_repository.dart';
import 'package:penpeeper/device_findings_modal.dart';
import 'package:penpeeper/widgets/finding_type_dialog.dart';
import 'package:penpeeper/widgets/cve_search_modal.dart';
import 'package:penpeeper/quill_flag_dialog.dart';

class FindingsTab extends StatefulWidget {
  final int projectId;
  final bool showFindingsOnly;
  final int deviceCount;
  final String projectName;

  const FindingsTab({
    super.key,
    required this.projectId,
    this.showFindingsOnly = false,
    required this.deviceCount,
    required this.projectName,
  });

  @override
  State<FindingsTab> createState() => _FindingsTabState();
}

class _FindingsTabState extends State<FindingsTab> {
  String searchType = 'HOST';
  String searchQuery = '';
  String activeFilter = '';
  String selectedOS = '';
  String selectedVendor = '';
  String selectedBanner = '';
  String selectedTag = '';
  List<Map<String, dynamic>> searchResults = [];
  List<String> availableOS = [];
  List<String> availableVendors = [];
  List<String> availableBanners = [];
  List<String> availableTags = [];
  final TextEditingController _searchController = TextEditingController();
  final _deviceRepo = DeviceRepository();
  final _metadataRepo = MetadataRepository();
  final _findingsRepo = FindingsRepository();
  final _cache = ProjectDataCache();
  final _searchService = DeviceSearchService();
  final _exportCoordinator = FindingsExportCoordinator();
  final _creationService = FindingCreationService();
  Set<int> flaggedDeviceIds = {};
  late String _projectName;

  @override
  void initState() {
    super.initState();
    _projectName = widget.projectName;
    _loadFromCache();
    _cache.addListener(_onCacheChanged);
  }

  void _onCacheChanged() {
    if (mounted) {
      _loadFromCache();
    }
  }

  @override
  void dispose() {
    _cache.removeListener(_onCacheChanged);
    _searchController.dispose();
    super.dispose();
  }



  void _loadFromCache() {
    if (!_cache.isValidFor(widget.projectId)) return;

    setState(() {
      availableOS = List.from(_cache.operatingSystems);
      availableVendors = List.from(_cache.macVendors);
      availableBanners = List.from(_cache.banners);
      availableTags = List.from(_cache.tags);
      debugPrint('FindingsTab: Updated availableTags: ${availableTags.length}');
      flaggedDeviceIds = Set.from(_cache.flaggedDeviceIds);
    });
  }

  Future<void> _refreshFlaggedFindings() async {
    final findings = await _findingsRepo.getFlaggedFindings(widget.projectId);
    final deviceIds = findings.map((f) => f.deviceId).toSet();
    setState(() {
      flaggedDeviceIds = deviceIds;
    });
    // Update global cache to ensure device list reflects changes
    await _cache.reloadFlaggedFindings(widget.projectId);
  }

  Future<void> _searchByOS(String osName) async {
    final results = await _searchService.searchByOS(widget.projectId, osName);
    setState(() {
      searchResults = results;
      activeFilter = '';
    });
  }

  Future<void> _searchByVendor(String vendor) async {
    final results = await _searchService.searchByVendor(widget.projectId, vendor);
    setState(() {
      searchResults = results;
      activeFilter = '';
    });
  }

  Future<void> _searchByBanner(String banner) async {
    final results = await _searchService.searchByBanner(widget.projectId, banner);
    setState(() {
      searchResults = results;
      activeFilter = '';
    });
  }

  Future<void> _searchByTag(String tag) async {
    final results = await _searchService.searchByTag(widget.projectId, tag);
    setState(() {
      searchResults = results;
      activeFilter = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.showFindingsOnly) {
      return FindingsFlaggedScreen(
        projectId: widget.projectId,
        projectName: _projectName,
        availableTags: availableTags,
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppTheme.backgroundGradient,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderPrimary),
            ),
            padding: const EdgeInsets.all(12),
            child: Stack(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      FindingsFilterBar(
                        availableOS: availableOS,
                        availableVendors: availableVendors,
                        availableBanners: availableBanners,
                        availableTags: availableTags,
                        selectedOS: selectedOS,
                        selectedVendor: selectedVendor,
                        selectedBanner: selectedBanner,
                        selectedTag: selectedTag,
                        onOSSelected: (os) {
                          setState(() {
                            selectedBanner = '';
                            selectedVendor = '';
                            selectedTag = '';
                            selectedOS = os;
                          });
                          if (os.isNotEmpty) {
                            _searchByOS(os);
                          } else {
                            setState(() => searchResults = []);
                          }
                        },
                        onVendorSelected: (vendor) {
                          setState(() {
                            selectedBanner = '';
                            selectedOS = '';
                            selectedTag = '';
                            selectedVendor = vendor;
                          });
                          if (vendor.isNotEmpty) {
                            _searchByVendor(vendor);
                          } else {
                            setState(() => searchResults = []);
                          }
                        },
                        onBannerSelected: (banner) {
                          setState(() {
                            selectedOS = '';
                            selectedVendor = '';
                            selectedTag = '';
                            selectedBanner = banner;
                          });
                          if (banner.isNotEmpty) {
                            _searchByBanner(banner);
                          } else {
                            setState(() => searchResults = []);
                          }
                        },
                        onTagSelected: (tag) {
                          setState(() {
                            selectedOS = '';
                            selectedVendor = '';
                            selectedBanner = '';
                            selectedTag = tag;
                          });
                          if (tag.isNotEmpty) {
                            _searchByTag(tag);
                          } else {
                            setState(() => searchResults = []);
                          }
                        },
                        onScanTypeSelected: (type) {
                          if (type.isNotEmpty) {
                            setState(() {
                              selectedBanner = '';
                              selectedOS = '';
                              selectedVendor = '';
                              selectedTag = '';
                            });
                            _showFilterResults(type);
                          } else {
                            setState(() {
                              searchResults = [];
                              activeFilter = '';
                            });
                          }
                        },
                      ),
                      const SizedBox(width: 16),
                      FindingsSearchBar(
                        searchController: _searchController,
                        searchType: searchType,
                        onSearchTypeChanged: (type) =>
                            setState(() => searchType = type),
                        onSearch: _performSearch,
                        onSearchQueryChanged: (query) => searchQuery = query,
                        showPortAndService: !widget.showFindingsOnly,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      width: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            AppTheme.surfaceColor.withValues(alpha: 0.0),
                            AppTheme.surfaceColor,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: searchResults.isEmpty
                ? const Center(
                    child: DeviceSearchPrompt(hasDevices: true),
                  )
                : _buildResultsTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsTable() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GradientBorderContainer(
            borderConfig:
                AppTheme.borderPrimaryGradient ?? AppTheme.borderPrimary,
            borderRadius: 8,
            borderWidth: 1,
            backgroundColor: AppTheme.surfaceColor,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.devices, color: AppTheme.textPrimary, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '${searchResults.length} Device${searchResults.length != 1 ? 's' : ''} Found',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: AppTheme.fontWeightSemiBold,
                      fontSize: AppTheme.fontSizeBodyLarge,
                      fontFamily: AppTheme.defaultFontFamily.isEmpty
                          ? null
                          : AppTheme.defaultFontFamily,
                    ),
                  ),
                  if (activeFilter.isNotEmpty) ...[
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        activeFilter,
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: AppTheme.fontWeightMedium,
                          fontSize: AppTheme.fontSizeBody,
                          fontFamily: AppTheme.defaultFontFamily.isEmpty
                              ? null
                              : AppTheme.defaultFontFamily,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (selectedVendor.isNotEmpty)
                    Tooltip(
                      message: 'Change the OS Icon for All Listed Below',
                      child: IconButton(
                        onPressed: _changeIconsForVendor,
                        icon: Icon(
                          Icons.edit,
                          color: AppTheme.textPrimary,
                          size: 16,
                        ),
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                      ),
                    ),
                  if (selectedVendor.isNotEmpty) const SizedBox(width: 4),
                  if (selectedVendor.isNotEmpty)
                    Tooltip(
                      message: 'Export Distinct MAC Vendors',
                      child: IconButton(
                        onPressed: _exportVendorList,
                        icon: Icon(
                          Icons.list,
                          color: AppTheme.textPrimary,
                          size: 16,
                        ),
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                      ),
                    ),
                  if (selectedVendor.isNotEmpty) const SizedBox(width: 4),
                  if (selectedOS.isNotEmpty)
                    Tooltip(
                      message: 'Export a list of all Operating Systems',
                      child: IconButton(
                        onPressed: _exportOSList,
                        icon: Icon(
                          Icons.computer,
                          color: AppTheme.textPrimary,
                          size: 16,
                        ),
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                      ),
                    ),
                  if (activeFilter.isNotEmpty)
                    Tooltip(
                      message: 'Export Results',
                      child: IconButton(
                        onPressed: _exportFilterResults,
                        icon: Icon(
                          Icons.computer,
                          color: AppTheme.textPrimary,
                          size: 16,
                        ),
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                      ),
                    ),
                  if (selectedBanner.isNotEmpty)
                    Tooltip(
                      message: 'Export Distinct Banners',
                      child: IconButton(
                        onPressed: _exportBannerList,
                        icon: Icon(
                          Icons.list,
                          color: AppTheme.textPrimary,
                          size: 16,
                        ),
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: activeFilter.isNotEmpty
                        ? 'Export Summary'
                        : 'Export to CSV',
                    child: IconButton(
                      onPressed: _exportToCSV,
                      icon: Icon(
                        Icons.file_download,
                        color: AppTheme.textPrimary,
                        size: 16,
                      ),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                final result = searchResults[index];
                final isFlagged = flaggedDeviceIds.contains(result['id']);
                return DeviceSearchResultItem(
                  result: result,
                  isFlagged: isFlagged,
                  projectId: widget.projectId,
                  activeFilter: activeFilter,
                  onIconChanged: () => setState(() {}),
                  onViewRecords: () => FindingsModalHelper.showRecordModal(
                    context: context,
                    device: result,
                    activeFilter: activeFilter,
                    metadataRepo: _metadataRepo,
                  ),
                  onDeviceInfo: () => FindingsModalHelper.showDeviceInfo(
                    context: context,
                    device: result,
                    projectId: widget.projectId,
                    deviceRepo: _deviceRepo,
                  ),
                  onJumpToDevice: () => _jumpToDevice(result),
                  onFlagFinding: () => _flagFinding(result),
                  getTelnetPorts: (deviceId) => _metadataRepo.getTelnetPorts(deviceId),
                  onOpenTelnet: _openTelnetClient,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _performSearch() async {
    if (searchQuery.isEmpty) return;

    setState(() {
      selectedBanner = '';
      selectedOS = '';
      selectedVendor = '';
      selectedTag = '';
    });

    List<Map<String, dynamic>> results = [];

    if (searchType == 'HOST') {
      results = await _searchService.searchByName(widget.projectId, searchQuery);
    } else if (searchType == 'IP') {
      results = await _searchService.searchByIP(widget.projectId, searchQuery);
    } else if (searchType == 'PORT') {
      results = await _searchService.searchByPort(widget.projectId, searchQuery);
    } else {
      results = await _searchService.searchByService(widget.projectId, searchQuery);
    }

    setState(() {
      searchResults = results;
      activeFilter = '';
    });
  }

  /// Shows filtered results for a specific scan type using cached device mappings.
  /// This method uses the pre-computed cache from ProjectDataCache for instant filtering.
  /// Falls back to database queries if cache is not available.
  Future<void> _showFilterResults(String filter) async {
    final stopwatch = Stopwatch()..start();

    debugPrint('_showFilterResults called for filter: $filter');
    debugPrint(
      'Cache valid: ${_cache.isValidFor(widget.projectId)}, projectId: ${widget.projectId}',
    );
    debugPrint(
      'Cache projectId: ${_cache.projectId}, isLoaded: ${_cache.isLoaded}',
    );

    if (!_cache.isValidFor(widget.projectId)) {
      debugPrint('Cache not loaded, falling back to database query');
      final searchRepo = SearchRepository();
      final results = await searchRepo.scanFilter(
        widget.projectId,
        filter,
      );
      stopwatch.stop();
      debugPrint(
        'Filter results loaded in ${stopwatch.elapsedMilliseconds}ms for filter: $filter (fallback)',
      );
      setState(() {
        searchResults = results;
        activeFilter = filter;
      });
      return;
    }

    final deviceIds = _cache.getDevicesForScanType(filter);
    debugPrint('Cached device IDs for $filter: ${deviceIds.length} devices');

    if (deviceIds.isEmpty && !kIsWeb) {
      stopwatch.stop();
      debugPrint(
        'Filter results loaded in ${stopwatch.elapsedMilliseconds}ms for filter: $filter',
      );
      setState(() {
        searchResults = [];
        activeFilter = filter;
      });
      return;
    }

    if (kIsWeb) {
      final searchRepo = SearchRepository();
      final results = await searchRepo.scanFilter(
        widget.projectId,
        filter,
      );
      stopwatch.stop();
      debugPrint(
        'Filter results loaded in ${stopwatch.elapsedMilliseconds}ms for filter: $filter (web)',
      );
      setState(() {
        searchResults = results;
        activeFilter = filter;
      });
      return;
    }

    final database = await _metadataRepo.database;
    final deviceIdsList = deviceIds.toList();
    final deviceIdsStr = deviceIdsList.join(',');

    List<Map<String, dynamic>> results = [];

    switch (filter) {
      case 'FFUF':
        results = await database.rawQuery('''
          SELECT d.id, d.name, d.ip_address, d.icon_type, COUNT(f.id) as count
          FROM devices d
          JOIN ffuf_findings f ON d.id = f.device_id
          WHERE d.id IN ($deviceIdsStr)
          GROUP BY d.id, d.name, d.ip_address, d.icon_type
          ORDER BY count DESC
        ''');
        break;
      case 'SAMBA':
        results = await database.rawQuery('''
          SELECT d.id, d.name, d.ip_address, d.icon_type, COUNT(s.id) as count
          FROM devices d
          JOIN samba_ldap_findings s ON d.id = s.device_id
          WHERE d.id IN ($deviceIdsStr)
          GROUP BY d.id, d.name, d.ip_address, d.icon_type
          ORDER BY count DESC
        ''');
        break;
      case 'WhatWeb':
        results = await database.rawQuery('''
          SELECT d.id, d.name, d.ip_address, d.icon_type, COUNT(w.id) as count
          FROM devices d
          JOIN whatweb_findings w ON d.id = w.device_id
          WHERE d.id IN ($deviceIdsStr)
          GROUP BY d.id, d.name, d.ip_address, d.icon_type
          ORDER BY count DESC
        ''');
        break;
      case 'SearchSploit':
        results = await database.rawQuery('''
          SELECT d.id, d.name, d.ip_address, d.icon_type, COUNT(v.id) as count
          FROM devices d
          JOIN vulnerabilities v ON d.id = v.device_id
          WHERE d.id IN ($deviceIdsStr) AND v.type = 'SearchSploit'
          GROUP BY d.id, d.name, d.ip_address, d.icon_type
          ORDER BY count DESC
        ''');
        break;
      case 'Nikto':
        results = await database.rawQuery('''
          SELECT d.id, d.name, d.ip_address, d.icon_type, COUNT(n.id) as count
          FROM devices d
          JOIN nikto_findings n ON d.id = n.device_id
          WHERE d.id IN ($deviceIdsStr)
          GROUP BY d.id, d.name, d.ip_address, d.icon_type
          ORDER BY count DESC
        ''');
        break;
      case 'SNMP':
        results = await database.rawQuery('''
          SELECT d.id, d.name, d.ip_address, d.icon_type, COUNT(s.id) as count
          FROM devices d
          JOIN snmp_findings s ON d.id = s.device_id
          WHERE d.id IN ($deviceIdsStr)
          GROUP BY d.id, d.name, d.ip_address, d.icon_type
          ORDER BY count DESC
        ''');
        break;
      case 'Nmap Scripts':
        results = await database.rawQuery('''
          SELECT d.id, d.name, d.ip_address, d.icon_type, COUNT(s.id) as count
          FROM devices d
          JOIN nmap_hosts h ON d.id = h.device_id
          JOIN nmap_ports p ON h.id = p.host_id
          JOIN nmap_scripts s ON p.id = s.port_id
          WHERE d.id IN ($deviceIdsStr)
            AND s.script_id != 'vulners'
            AND s.output IS NOT NULL
            AND s.output != ''
            AND s.output != 'Not Found'
            AND s.output NOT LIKE 'ERROR:%'
            AND s.output NOT LIKE 'Couldn''t determine%'
          GROUP BY d.id, d.name, d.ip_address, d.icon_type
          ORDER BY count DESC
        ''');
        break;
      case 'Vulners':
        final allResults = await database.rawQuery('''
          SELECT d.id, d.name, d.ip_address, d.icon_type, c.id as cve_id, s.output
          FROM devices d
          JOIN nmap_hosts h ON d.id = h.device_id
          JOIN nmap_ports p ON h.id = p.host_id
          JOIN nmap_scripts s ON p.id = s.port_id
          JOIN nmap_cves c ON s.id = c.script_id
          WHERE d.id IN ($deviceIdsStr)
        ''');

        final excludedPrefixes = [
          'cpe:/a:apache:http_server:',
          'cpe:/a:microsoft:iis:',
          'cpe:/a:nginx:nginx:',
          'cpe:/a:php:php:',
          'cpe:/a:genivia:gsoap:',
          'cpe:/a:goahead:goahead:',
          'cpe:/a:boa:boa:',
          'cpe:/a:microsoft:sql_server:',
          'cpe:/a:mysql:mysql:',
          'cpe:/a:mariadb:mariadb:',
          'cpe:/a:postgresql:postgresql',
          'cpe:/a:openssl:openssl:',
          'cpe:/a:net-snmp:net-snmp:',
        ];

        final filteredResults = allResults.where((row) {
          final output = ((row['output'] as String?) ?? '').trim();
          return !excludedPrefixes.any((prefix) => output.startsWith(prefix));
        }).toList();

        final deviceCounts = <int, Map<String, dynamic>>{};
        for (final row in filteredResults) {
          final deviceId = row['id'] as int;
          if (!deviceCounts.containsKey(deviceId)) {
            deviceCounts[deviceId] = {
              'id': row['id'],
              'name': row['name'],
              'ip_address': row['ip_address'],
              'icon_type': row['icon_type'],
              'count': 0,
            };
          }
          deviceCounts[deviceId]!['count'] =
              (deviceCounts[deviceId]!['count'] as int) + 1;
        }

        results = deviceCounts.values
            .where((device) => (device['count'] as int) > 0)
            .toList();
        results.sort(
          (a, b) => (b['count'] as int).compareTo(a['count'] as int),
        );
        break;
    }

    final enrichedResults = <Map<String, dynamic>>[];
    for (final result in results) {
      final enriched = Map<String, dynamic>.from(result);
      if (enriched['icon_type'] == null || 
          enriched['icon_type'] == '' || 
          enriched['icon_type'] == 'unknown') {
        final metadata = await _metadataRepo.getDeviceMetadata(enriched['id']);
        if (metadata['os_type'] != null && metadata['os_type'] != 'unknown') {
          enriched['icon_type'] = metadata['os_type'];
        }
      }
      enrichedResults.add(enriched);
    }

    stopwatch.stop();
    debugPrint(
      'Filter results loaded in ${stopwatch.elapsedMilliseconds}ms for filter: $filter',
    );

    setState(() {
      searchResults = enrichedResults;
      activeFilter = filter;
    });
  }



  void _jumpToDevice(Map<String, dynamic> device) {
    final projectState = context.findAncestorStateOfType<ProjectScreenState>();
    projectState?.jumpToDevice(device['id']);
  }

  Future<void> _openTelnetClient(
    Map<String, dynamic> device,
    List<int> telnetPorts,
  ) async {
    await showDialog(
      context: context,
      builder: (context) => TelnetClientModal(
        ipAddress: device['ip_address'],
        telnetPorts: telnetPorts,
      ),
    );
  }



  Future<void> _flagFinding(Map<String, dynamic> result) async {
    final deviceName = result['name'] ?? 'Unknown Device';
    final ipAddress = result['ip_address'] ?? 'Unknown IP';

    final existingFindings = (await _findingsRepo.getFlaggedFindingsForDevice(result['id']))
        .map((f) => f.toMap())
        .toList();

    if (existingFindings.isNotEmpty) {
      await showDialog(
        context: context,
        builder: (context) => DeviceFindingsModal(
          deviceName: deviceName,
          ipAddress: ipAddress,
          deviceId: result['id'],
          existingFindings: existingFindings,
          onFindingAdded: _refreshFlaggedFindings,
          projectName: _projectName,
          projectId: widget.projectId,
        ),
      );
      return;
    }

    final findingType = await showDialog<String>(
      context: context,
      builder: (context) => const FindingTypeDialog(),
    );

    if (findingType == null) return;

    if (findingType == 'CVE') {
      await _handleCveFinding(result, deviceName, ipAddress);
    } else {
      await _handleManualFinding(result, deviceName, ipAddress);
    }
  }

  Future<void> _handleCveFinding(
    Map<String, dynamic> result,
    String deviceName,
    String ipAddress,
  ) async {
    final cveResult = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => CveSearchModal(
        deviceId: result['id'],
        projectId: widget.projectId,
      ),
    );

    if (cveResult == null) return;

    await _creationService.createCveFinding(
      deviceId: result['id'],
      deviceName: deviceName,
      ipAddress: ipAddress,
      projectId: widget.projectId,
      cveData: cveResult,
    );

    await _refreshFlaggedFindings();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('CVE ${cveResult['cveId']} added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _handleManualFinding(
    Map<String, dynamic> result,
    String deviceName,
    String ipAddress,
  ) async {
    final flagResult = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => QuillFlagDialog(
        deviceName: deviceName,
        onSubmit: (type, content) {},
        projectName: _projectName,
      ),
    );

    if (flagResult == null) return;

    final findingId = await _creationService.createManualFinding(
      deviceId: result['id'],
      deviceName: deviceName,
      ipAddress: ipAddress,
      flagData: flagResult,
    );

    if (flagResult['classification'] != null) {
      try {
        await _creationService.saveClassification(
          findingId: findingId,
          projectId: widget.projectId,
          deviceId: result['id'],
          classification: flagResult['classification'],
        );
      } catch (e) {
        debugPrint('Error saving classification: $e');
      }
    }

    if (flagResult['cvssData'] != null) {
      await _creationService.saveCvssData(
        findingId: findingId,
        cvssData: flagResult['cvssData'],
      );
    }

    await _refreshFlaggedFindings();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Finding flagged as ${flagResult['type']}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _exportVendorList() async {
    if (availableVendors.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No vendors to export')));
      }
      return;
    }

    try {
      final filePath = await _exportCoordinator.exportVendorList(availableVendors);

      if (filePath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Vendor list exported${kIsWeb ? '' : ' to $filePath'}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _exportBannerList() async {
    if (availableBanners.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No banners to export')));
      }
      return;
    }

    try {
      final filePath = await _exportCoordinator.exportBannerList(availableBanners);

      if (filePath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Banner list exported${kIsWeb ? '' : ' to $filePath'}',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _exportOSList() async {
    if (availableOS.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No operating systems to export')),
        );
      }
      return;
    }

    try {
      final filePath = await _exportCoordinator.exportOSList(availableOS);

      if (filePath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OS list exported${kIsWeb ? '' : ' to $filePath'}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _exportFilterResults() async {
    if (searchResults.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No results to export')));
      }
      return;
    }

    try {
      final filePath = await _exportCoordinator.exportFilterResults(
        devices: searchResults,
        filter: activeFilter,
        getRecords: (deviceId, filter) async {
          final database = await _metadataRepo.database;
          switch (filter) {
            case 'FFUF':
              return await database.query(
                'ffuf_findings',
                where: 'device_id = ?',
                whereArgs: [deviceId],
              );
            case 'SAMBA':
              return await database.query(
                'samba_ldap_findings',
                where: 'device_id = ?',
                whereArgs: [deviceId],
              );
            case 'WhatWeb':
              return await database.query(
                'whatweb_findings',
                where: 'device_id = ?',
                whereArgs: [deviceId],
              );
            case 'SearchSploit':
              return await database.query(
                'vulnerabilities',
                where: 'device_id = ? AND type = ?',
                whereArgs: [deviceId, 'SearchSploit'],
              );
            case 'Nikto':
              return await database.query(
                'nikto_findings',
                where: 'device_id = ?',
                whereArgs: [deviceId],
              );
            case 'SNMP':
              return await database.query(
                'snmp_findings',
                where: 'device_id = ?',
                whereArgs: [deviceId],
              );
            case 'Nmap Scripts':
              return await database.rawQuery(
                '''
                SELECT s.*, p.port, p.protocol, p.service_name
                FROM nmap_scripts s
                JOIN nmap_ports p ON s.port_id = p.id
                JOIN nmap_hosts h ON p.host_id = h.id
                WHERE h.device_id = ?
                  AND s.script_id != 'vulners'
                  AND s.output IS NOT NULL
                  AND s.output != ''
                  AND s.output != 'Not Found'
                  AND s.output NOT LIKE 'ERROR:%'
                  AND s.output NOT LIKE 'Couldn''t determine%'
                ORDER BY s.script_id ASC, p.port ASC
              ''',
                [deviceId],
              );
            case 'Vulners':
              return await database.rawQuery(
                '''
                SELECT c.*
                FROM nmap_cves c
                JOIN nmap_scripts s ON c.script_id = s.id
                JOIN nmap_ports p ON s.port_id = p.id
                JOIN nmap_hosts h ON p.host_id = h.id
                WHERE h.device_id = ?
                ORDER BY c.cvss DESC
              ''',
                [deviceId],
              );
            default:
              return [];
          }
        },
      );

      if (filePath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Results exported${kIsWeb ? '' : ' to $filePath'}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _changeIconsForVendor() async {
    if (selectedVendor.isEmpty) return;

    final newIconType = await showDialog<String>(
      context: context,
      builder: (context) => IconSelectorDialog(currentIconType: 'unknown'),
    );

    if (newIconType != null) {
      await _deviceRepo.updateDeviceIconsByMacVendor(
        widget.projectId,
        selectedVendor,
        newIconType,
      );
      setState(() {
        for (var result in searchResults) {
          result['icon_type'] = newIconType;
        }
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Updated icons for all $selectedVendor devices'),
        ),
      );
    }
  }















  Future<void> _exportToCSV() async {
    if (searchResults.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No data to export')));
      }
      return;
    }

    try {
      final filePath = await _exportCoordinator.exportSearchResults(
        searchResults,
        activeFilter,
      );

      if (filePath != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Exported${kIsWeb ? '' : ' to $filePath'}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }
}
