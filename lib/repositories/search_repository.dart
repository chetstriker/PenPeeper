import 'package:penpeeper/repositories/base_repository.dart';
import 'package:penpeeper/repositories/device_repository.dart';
import 'package:penpeeper/database/connection/database_connection.dart';
import 'package:penpeeper/api_database_helper.dart';
import 'package:penpeeper/utils/platform/platform_utils.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

class SearchRepository extends BaseRepository {
  final _dbConnection = DatabaseConnection();

  Future<List<Map<String, dynamic>>> searchDevicesByName(int projectId, String query) async {
    if (kIsWeb) {
      return await ApiDatabaseHelper().searchDevices(projectId, 'HOST', query);
    }
    final db = await _dbConnection.database;
    return await db.rawQuery('''
      SELECT DISTINCT d.id, d.name, d.ip_address, d.icon_type
      FROM devices d
      WHERE d.project_id = ? AND d.name LIKE ?
    ''', [projectId, '%$query%']);
  }

  Future<List<Map<String, dynamic>>> searchDevicesByIP(int projectId, String query) async {
    if (kIsWeb) {
      return await ApiDatabaseHelper().searchDevices(projectId, 'IP', query);
    }
    final db = await _dbConnection.database;
    return await db.rawQuery('''
      SELECT DISTINCT d.id, d.name, d.ip_address, d.icon_type
      FROM devices d
      WHERE d.project_id = ? AND d.ip_address LIKE ?
    ''', [projectId, '%$query%']);
  }

  Future<List<Map<String, dynamic>>> searchDevicesByPort(int projectId, String port) async {
    if (kIsWeb) {
      return await ApiDatabaseHelper().searchDevices(projectId, 'PORT', port);
    }
    final db = await _dbConnection.database;
    return await db.rawQuery('''
      SELECT DISTINCT d.id, d.name, d.ip_address, d.icon_type
      FROM devices d
      JOIN nmap_hosts h ON d.id = h.device_id
      JOIN nmap_ports p ON h.id = p.host_id
      WHERE d.project_id = ? AND p.port = ?
    ''', [projectId, port]);
  }

  Future<List<Map<String, dynamic>>> searchDevicesByService(int projectId, String query) async {
    if (kIsWeb) {
      return await ApiDatabaseHelper().searchDevices(projectId, 'SERVICE', query);
    }
    final db = await _dbConnection.database;
    return await db.rawQuery('''
      SELECT DISTINCT d.id, d.name, d.ip_address, d.icon_type
      FROM devices d
      JOIN nmap_hosts h ON d.id = h.device_id
      JOIN nmap_ports p ON h.id = p.host_id
      WHERE d.project_id = ? AND (p.service_name LIKE ? OR p.product LIKE ?)
    ''', [projectId, '%$query%', '%$query%']);
  }

  Future<List<Map<String, dynamic>>> getDevicesByOperatingSystem(int projectId, String osName) async {
    if (kIsWeb) {
      return await ApiDatabaseHelper().searchDevices(projectId, 'OS', osName);
    }
    final db = await _dbConnection.database;
    return await db.rawQuery('''
      SELECT DISTINCT d.id, d.name, d.ip_address, d.icon_type
      FROM devices d
      JOIN nmap_hosts h ON d.id = h.device_id
      JOIN nmap_os_matches o ON h.id = o.host_id
      WHERE d.project_id = ?
        AND o.name = ?
        AND o.id IN (
          SELECT id FROM nmap_os_matches o2
          WHERE o2.host_id = o.host_id
          ORDER BY o2.accuracy DESC
          LIMIT 1
        )
    ''', [projectId, osName]);
  }

  Future<List<Map<String, dynamic>>> scanFilter(int projectId, String filter) async {
    if (kIsWeb) {
      return await ApiDatabaseHelper().scanFilter(projectId, filter);
    }
    final db = await _dbConnection.database;
    List<Map<String, dynamic>> results = [];
    
    switch (filter) {
      case 'FFUF':
        results = await db.rawQuery('''
          SELECT d.id, d.name, d.ip_address, d.icon_type, COUNT(f.id) as count
          FROM devices d
          JOIN ffuf_findings f ON d.id = f.device_id
          WHERE d.project_id = ?
          GROUP BY d.id, d.name, d.ip_address, d.icon_type
          ORDER BY count DESC
        ''', [projectId]);
        break;
      case 'SAMBA':
        results = await db.rawQuery('''
          SELECT d.id, d.name, d.ip_address, d.icon_type, COUNT(s.id) as count
          FROM devices d
          JOIN samba_ldap_findings s ON d.id = s.device_id
          WHERE d.project_id = ?
          GROUP BY d.id, d.name, d.ip_address, d.icon_type
          ORDER BY count DESC
        ''', [projectId]);
        break;
      case 'WhatWeb':
        results = await db.rawQuery('''
          SELECT d.id, d.name, d.ip_address, d.icon_type, COUNT(w.id) as count
          FROM devices d
          JOIN whatweb_findings w ON d.id = w.device_id
          WHERE d.project_id = ?
          GROUP BY d.id, d.name, d.ip_address, d.icon_type
          ORDER BY count DESC
        ''', [projectId]);
        break;
      case 'SearchSploit':
        results = await db.rawQuery('''
          SELECT d.id, d.name, d.ip_address, d.icon_type, COUNT(v.id) as count
          FROM devices d
          JOIN vulnerabilities v ON d.id = v.device_id
          WHERE d.project_id = ? AND v.type = 'SearchSploit'
          GROUP BY d.id, d.name, d.ip_address, d.icon_type
          ORDER BY count DESC
        ''', [projectId]);
        break;
      case 'Vulners':
        final allResults = await db.rawQuery('''
          SELECT d.id, d.name, d.ip_address, d.icon_type, c.id as cve_id, s.output
          FROM devices d
          JOIN nmap_hosts h ON d.id = h.device_id
          JOIN nmap_ports p ON h.id = p.host_id
          JOIN nmap_scripts s ON p.id = s.port_id
          JOIN nmap_cves c ON s.id = c.script_id
          WHERE d.project_id = ?
        ''', [projectId]);
        
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
          deviceCounts[deviceId]!['count'] = (deviceCounts[deviceId]!['count'] as int) + 1;
        }
        
        results = deviceCounts.values.where((device) => (device['count'] as int) > 0).toList();
        results.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
        break;
    }
    
    final deviceRepo = DeviceRepository();
    for (int i = 0; i < results.length; i++) {
      if (results[i]['icon_type'] == null) {
        final metadata = await deviceRepo.getDeviceMetadata(results[i]['id']);
        results[i]['icon_type'] = metadata['os_type'];
      }
    }
    
    return results;
  }

  Future<List<String>> getDistinctOperatingSystems(int projectId) async {
    return await PlatformUtils.platformSpecific(
      web: () async {
        debugPrint('SearchRepository.getDistinctOperatingSystems: Calling API for project $projectId');
        final result = await ApiDatabaseHelper().getDistinctOperatingSystems(projectId);
        debugPrint('SearchRepository.getDistinctOperatingSystems: API returned ${result.length} items');
        return result;
      },
      desktop: () async {
        final db = await _dbConnection.database;
        final results = await db.rawQuery('''
          SELECT DISTINCT o.name
          FROM nmap_os_matches o
          JOIN nmap_hosts h ON o.host_id = h.id
          JOIN devices d ON h.device_id = d.id
          WHERE d.project_id = ?
            AND o.id IN (
              SELECT id FROM nmap_os_matches o2
              WHERE o2.host_id = o.host_id
              ORDER BY o2.accuracy DESC
              LIMIT 1
            )
          ORDER BY o.name ASC
        ''', [projectId]);
        return results.map((r) => r['name'] as String).toList();
      },
    );
  }

  Future<List<String>> getDistinctMacVendors(int projectId) async {
    return await PlatformUtils.platformSpecific(
      web: () async {
        debugPrint('SearchRepository.getDistinctMacVendors: Calling API for project $projectId');
        final result = await ApiDatabaseHelper().getDistinctMacVendors(projectId);
        debugPrint('SearchRepository.getDistinctMacVendors: API returned ${result.length} items');
        return result;
      },
      desktop: () async {
        final db = await _dbConnection.database;
        final results = await db.rawQuery('''
          SELECT DISTINCT h.vendor
          FROM nmap_hosts h
          JOIN devices d ON h.device_id = d.id
          WHERE d.project_id = ?
            AND h.vendor IS NOT NULL
            AND h.vendor != ''
          ORDER BY h.vendor ASC
        ''', [projectId]);
        return results.map((r) => r['vendor'] as String).toList();
      },
    );
  }

  Future<List<String>> getDistinctBanners(int projectId) async {
    return await PlatformUtils.platformSpecific(
      web: () async {
        debugPrint('SearchRepository.getDistinctBanners: Calling API for project $projectId');
        final result = await ApiDatabaseHelper().getDistinctBanners(projectId);
        debugPrint('SearchRepository.getDistinctBanners: API returned ${result.length} items');
        return result;
      },
      desktop: () async {
        final db = await _dbConnection.database;
        final results = await db.rawQuery('''
          SELECT DISTINCT (p.product || ' ' || COALESCE(p.version, '')) as banner
          FROM nmap_ports p
          JOIN nmap_hosts h ON p.host_id = h.id
          JOIN devices d ON h.device_id = d.id
          WHERE d.project_id = ?
            AND p.product IS NOT NULL
            AND p.product != ''
          ORDER BY banner ASC
        ''', [projectId]);
        return results.map((r) => r['banner'] as String).toList();
      },
    );
  }

  Future<List<Map<String, dynamic>>> getDevicesByMacVendor(int projectId, String vendor) async {
    return await PlatformUtils.platformSpecific(
      web: () => ApiDatabaseHelper().searchDevices(projectId, 'VENDOR', vendor),
      desktop: () async {
        final db = await _dbConnection.database;
        return await db.rawQuery('''
          SELECT d.*
          FROM devices d
          JOIN nmap_hosts h ON d.id = h.device_id
          WHERE d.project_id = ? AND h.vendor = ?
          ORDER BY d.name ASC
        ''', [projectId, vendor]);
      },
    );
  }

  Future<List<Map<String, dynamic>>> getDevicesByBanner(int projectId, String banner) async {
    return await PlatformUtils.platformSpecific(
      web: () => ApiDatabaseHelper().searchDevices(projectId, 'BANNER', banner),
      desktop: () async {
        final db = await _dbConnection.database;
        return await db.rawQuery('''
          SELECT DISTINCT d.*
          FROM devices d
          JOIN nmap_hosts h ON d.id = h.device_id
          JOIN nmap_ports p ON h.id = p.host_id
          WHERE d.project_id = ? AND (p.product || ' ' || COALESCE(p.version, '')) = ?
          ORDER BY d.name ASC
        ''', [projectId, banner]);
      },
    );
  }

  Future<Set<int>> getDevicesWithFfufFindings(int projectId) async {
    if (kIsWeb) {
      return await ApiDatabaseHelper().getDevicesWithFfufFindings(projectId);
    }
    final db = await _dbConnection.database;
    final results = await db.rawQuery('''
      SELECT DISTINCT d.id
      FROM devices d
      JOIN ffuf_findings f ON d.id = f.device_id
      WHERE d.project_id = ?
    ''', [projectId]);
    return results.map((r) => r['id'] as int).toSet();
  }

  Future<Set<int>> getDevicesWithSambaLdapFindings(int projectId) async {
    if (kIsWeb) {
      return await ApiDatabaseHelper().getDevicesWithSambaLdapFindings(projectId);
    }
    final db = await _dbConnection.database;
    final results = await db.rawQuery('''
      SELECT DISTINCT d.id
      FROM devices d
      JOIN samba_ldap_findings s ON d.id = s.device_id
      WHERE d.project_id = ?
    ''', [projectId]);
    return results.map((r) => r['id'] as int).toSet();
  }

  Future<Set<int>> getDevicesWithWhatWebFindings(int projectId) async {
    if (kIsWeb) {
      return await ApiDatabaseHelper().getDevicesWithWhatWebFindings(projectId);
    }
    final db = await _dbConnection.database;
    final results = await db.rawQuery('''
      SELECT DISTINCT d.id
      FROM devices d
      JOIN whatweb_findings w ON d.id = w.device_id
      WHERE d.project_id = ?
    ''', [projectId]);
    return results.map((r) => r['id'] as int).toSet();
  }

  Future<Set<int>> getDevicesWithSearchSploitFindings(int projectId) async {
    if (kIsWeb) {
      return await ApiDatabaseHelper().getDevicesWithSearchSploitFindings(projectId);
    }
    final db = await _dbConnection.database;
    final results = await db.rawQuery('''
      SELECT DISTINCT d.id
      FROM devices d
      JOIN vulnerabilities v ON d.id = v.device_id
      WHERE d.project_id = ? AND v.type = 'SearchSploit'
    ''', [projectId]);
    return results.map((r) => r['id'] as int).toSet();
  }

  Future<Set<int>> getDevicesWithVulnersCves(int projectId) async {
    if (kIsWeb) {
      return await ApiDatabaseHelper().getDevicesWithVulnersCves(projectId);
    }
    final db = await _dbConnection.database;
    
    final allResults = await db.rawQuery('''
      SELECT DISTINCT d.id, s.output
      FROM devices d
      JOIN nmap_hosts h ON d.id = h.device_id
      JOIN nmap_ports p ON h.id = p.host_id
      JOIN nmap_scripts s ON p.id = s.port_id
      JOIN nmap_cves c ON s.id = c.script_id
      WHERE d.project_id = ?
    ''', [projectId]);
    
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
    
    final deviceIds = <int>{};
    for (final row in allResults) {
      final output = ((row['output'] as String?) ?? '').trim();
      final shouldExclude = excludedPrefixes.any((prefix) => output.startsWith(prefix));
      if (!shouldExclude) {
        deviceIds.add(row['id'] as int);
      }
    }
    
    return deviceIds;
  }
}
