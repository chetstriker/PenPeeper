import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:penpeeper/repositories/metadata_repository.dart';
import 'package:penpeeper/repositories/search_repository.dart';
import 'package:penpeeper/services/project_data_cache.dart';
import 'package:penpeeper/models.dart';

/// Service for filtering devices by scan type
class FindingsFilterService {
  final MetadataRepository _metadataRepo;
  final ProjectDataCache _cache;
  final _searchRepo = SearchRepository();

  FindingsFilterService(this._metadataRepo, this._cache);

  /// Filters devices by scan type (FFUF, Nikto, SAMBA, SNMP, WhatWeb, SearchSploit, Vulners)
  Future<List<Map<String, dynamic>>> filterByScanType(int projectId, String filter) async {
    if (!_cache.isValidFor(projectId)) {
      return await _searchRepo.scanFilter(projectId, filter);
    }
    
    final deviceIds = _cache.getDevicesForScanType(filter);
    
    if (deviceIds.isEmpty) {
      return [];
    }
    
    if (kIsWeb) {
      return _buildWebResults(projectId, deviceIds);
    }
    
    return await _buildDesktopResults(deviceIds, filter);
  }

  /// Filters findings by tag
  Future<List<Map<String, dynamic>>> filterFindingsByTag(
    List<Map<String, dynamic>> allFindings,
    String tag,
    Future<List<String>> Function(int deviceId) getDeviceTags,
  ) async {
    final filteredFindings = <Map<String, dynamic>>[];
    
    for (final finding in allFindings) {
      final deviceTags = await getDeviceTags(finding['device_id']);
      if (deviceTags.contains(tag)) {
        filteredFindings.add(finding);
      }
    }
    
    return filteredFindings;
  }

  /// Builds results for web platform
  List<Map<String, dynamic>> _buildWebResults(int projectId, Set<int> deviceIds) {
    final results = <Map<String, dynamic>>[];
    for (final deviceId in deviceIds) {
      final device = _cache.devices.firstWhere(
        (d) => d.id == deviceId,
        orElse: () => Device(
          id: deviceId,
          projectId: projectId,
          name: 'Unknown',
          ipAddress: 'Unknown',
        ),
      );
      final metadata = _cache.deviceMetadata[deviceId] ?? {};
      results.add({
        'id': device.id,
        'name': device.name,
        'ip_address': device.ipAddress,
        'icon_type': device.iconType ?? metadata['os_type'] ?? 'unknown',
        'count': 0,
      });
    }
    return results;
  }

  /// Builds results for desktop platform with counts
  Future<List<Map<String, dynamic>>> _buildDesktopResults(Set<int> deviceIds, String filter) async {
    final database = await _metadataRepo.database;
    final deviceIdsList = deviceIds.toList();
    final deviceIdsStr = deviceIdsList.join(',');
    
    List<Map<String, dynamic>> results;
    
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
      case 'Vulners':
        results = await _filterVulners(database, deviceIdsStr);
        break;
      default:
        results = [];
    }
    
    return await _enrichResults(results);
  }

  /// Filters Vulners CVEs excluding common web server CPEs
  Future<List<Map<String, dynamic>>> _filterVulners(dynamic database, String deviceIdsStr) async {
    final allResults = await database.rawQuery('''
      SELECT d.id, d.name, d.ip_address, d.icon_type, c.id as cve_id, s.output
      FROM devices d
      JOIN nmap_hosts h ON d.id = h.device_id
      JOIN nmap_ports p ON h.id = p.host_id
      JOIN nmap_scripts s ON p.id = s.port_id
      JOIN nmap_cves c ON s.id = c.script_id
      WHERE d.id IN ($deviceIdsStr)
    ''');
    
    const excludedPrefixes = [
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
      deviceCounts[deviceId]!['count'] = (deviceCounts[deviceId]!['count'] as int) + 1;
    }
    
    final results = deviceCounts.values.where((device) => (device['count'] as int) > 0).toList();
    results.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    return results;
  }

  /// Enriches results with icon type metadata
  Future<List<Map<String, dynamic>>> _enrichResults(List<Map<String, dynamic>> results) async {
    final enrichedResults = <Map<String, dynamic>>[];
    for (final result in results) {
      final enriched = Map<String, dynamic>.from(result);
      if (enriched['icon_type'] == null) {
        final metadata = await _metadataRepo.getDeviceMetadata(enriched['id']);
        enriched['icon_type'] = metadata['os_type'];
      }
      enrichedResults.add(enriched);
    }
    return enrichedResults;
  }
}
