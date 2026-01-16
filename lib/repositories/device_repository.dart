import 'package:penpeeper/repositories/base_repository.dart';
import 'package:penpeeper/database/connection/database_connection.dart';
import 'package:penpeeper/api_database_helper.dart';
import 'package:penpeeper/services/project_data_cache.dart';
import 'package:penpeeper/models.dart';
import 'package:penpeeper/utils/platform/platform_utils.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class DeviceRepository extends BaseRepository {
  final _dbConnection = DatabaseConnection();

  Future<int> insertDevice(int projectId, String name, String ipAddress) async {
    if (kIsWeb) {
      return await ApiDatabaseHelper().insertDevice(projectId, name, ipAddress);
    }
    final db = await _dbConnection.database;
    return await db.insert('devices', {
      'project_id': projectId,
      'name': name,
      'ip_address': ipAddress,
    });
  }

  Future<List<Device>> getDevices(int projectId) async {
    if (kIsWeb) {
      final maps = await ApiDatabaseHelper().getDevices(projectId);
      return maps.map((map) => Device.fromMap(map)).toList();
    }
    final db = await _dbConnection.database;
    final maps = await db.query('devices', 
      where: 'project_id = ?', 
      whereArgs: [projectId],
      orderBy: 'name ASC'
    );
    return maps.map((map) => Device.fromMap(map)).toList();
  }

  Future<Device?> getDeviceById(int deviceId) async {
    if (kIsWeb) {
      try {
        final response = await http.get(Uri.parse('/api/devices/$deviceId'));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return data.isEmpty ? null : Device.fromMap(data);
        }
      } catch (e) {}
      return null;
    }
    final db = await _dbConnection.database;
    final results = await db.query('devices',
      where: 'id = ?',
      whereArgs: [deviceId],
      limit: 1,
    );
    return results.isNotEmpty ? Device.fromMap(results.first) : null;
  }

  Future<List<Map<String, dynamic>>> getDevicesRaw(int projectId) async {
    if (kIsWeb) {
      return await ApiDatabaseHelper().getDevices(projectId);
    }
    final db = await _dbConnection.database;
    return await db.query('devices', 
      where: 'project_id = ?', 
      whereArgs: [projectId],
      orderBy: 'name ASC'
    );
  }

  Future<Map<String, dynamic>?> getNmapHostData(int deviceId) async {
    if (kIsWeb) {
      try {
        final response = await http.get(Uri.parse('/api/devices/$deviceId/details'));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          // Return mac_address and vendor from the details response
          return {
            'mac_address': data['mac_address'],
            'vendor': data['vendor'],
          };
        }
      } catch (e) {}
      return null;
    }
    final db = await _dbConnection.database;
    final results = await db.query('nmap_hosts',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> deleteDevice(int deviceId) async {
    if (kIsWeb) {
      await ApiDatabaseHelper().deleteDevice(deviceId);
      return;
    }
    final db = await _dbConnection.database;
    await db.delete('scans', where: 'device_id = ?', whereArgs: [deviceId]);
    await db.delete('device_data', where: 'device_id = ?', whereArgs: [deviceId]);
    await db.delete('devices', where: 'id = ?', whereArgs: [deviceId]);
    
    final cache = ProjectDataCache();
    cache.removeDeviceFromScanType('FFUF', deviceId);
    cache.removeDeviceFromScanType('SAMBA', deviceId);
    cache.removeDeviceFromScanType('WhatWeb', deviceId);
    cache.removeDeviceFromScanType('SearchSploit', deviceId);
    cache.removeDeviceFromScanType('Vulners', deviceId);
    cache.updateDeviceDeleted(deviceId);
  }

  Future<void> updateDeviceIcon(int deviceId, String iconType) async {
    if (kIsWeb) {
      await http.put(
        Uri.parse('/api/devices/$deviceId/icon'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'icon_type': iconType}),
      );
      return;
    }
    final db = await _dbConnection.database;
    await db.update('devices', {'icon_type': iconType},
      where: 'id = ?',
      whereArgs: [deviceId],
    );
  }

  Future<void> updateDeviceIconsByMacVendor(int projectId, String vendor, String iconType) async {
    if (kIsWeb) return;
    final db = await _dbConnection.database;
    await db.rawUpdate('''
      UPDATE devices
      SET icon_type = ?
      WHERE id IN (
        SELECT d.id
        FROM devices d
        JOIN nmap_hosts h ON d.id = h.device_id
        WHERE d.project_id = ? AND h.vendor = ?
      )
    ''', [iconType, projectId, vendor]);
  }

  Future<int> getDeviceCount(int projectId) async {
    if (kIsWeb) {
      final devices = await getDevices(projectId);
      return devices.length;
    }
    final db = await _dbConnection.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM devices WHERE project_id = ?',
      [projectId],
    );
    return result.isNotEmpty ? (result.first['count'] as int? ?? 0) : 0;
  }

  Future<List<int>> getTelnetPorts(int deviceId) async {
    if (kIsWeb) {
      try {
        final response = await http.get(Uri.parse('/api/devices/$deviceId/telnet-ports'));
        if (response.statusCode == 200) {
          return List<int>.from(json.decode(response.body));
        }
      } catch (e) {}
      return [];
    }
    final db = await _dbConnection.database;
    final results = await db.rawQuery('''
      SELECT DISTINCT p.port
      FROM nmap_ports p
      JOIN nmap_hosts h ON p.host_id = h.id
      WHERE h.device_id = ?
        AND p.state = 'open'
        AND (LOWER(p.service_name) LIKE '%telnet%' OR p.port = 23)
      ORDER BY p.port ASC
    ''', [deviceId]);
    
    return results.map((r) => r['port'] as int).toList();
  }

  Future<void> saveDeviceData(int deviceId, String section, String content) async {
    if (kIsWeb) {
      await http.post(
        Uri.parse('/api/devices/$deviceId/data'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'section': section, 'content': content}),
      );
      return;
    }
    final db = await _dbConnection.database;
    final existing = await db.query('device_data',
      where: 'device_id = ? AND section = ?',
      whereArgs: [deviceId, section],
      limit: 1,
    );
    
    if (existing.isNotEmpty) {
      await db.update('device_data', {'content': content},
        where: 'device_id = ? AND section = ?',
        whereArgs: [deviceId, section],
      );
    } else {
      await db.insert('device_data', {
        'device_id': deviceId,
        'section': section,
        'content': content,
      });
    }
  }

  Future<String> getDeviceData(int deviceId, String section) async {
    if (kIsWeb) {
      try {
        final response = await http.get(
          Uri.parse('/api/devices/$deviceId/data/$section'),
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          return data['content'] ?? '';
        }
      } catch (e) {}
      return '';
    }
    final db = await _dbConnection.database;
    final results = await db.query('device_data',
      where: 'device_id = ? AND section = ?',
      whereArgs: [deviceId, section],
      limit: 1,
    );
    return results.isNotEmpty ? (results.first['content'] as String? ?? '') : '';
  }

  Future<Map<String, dynamic>> getDeviceDetails(int deviceId) async {
    return await PlatformUtils.platformSpecific(
      web: () => ApiDatabaseHelper().getDeviceDetails(deviceId),
      desktop: () async {
        final db = await _dbConnection.database;
        Map<String, dynamic> result = {};

        // Get device information including NetBIOS fields
        final devices = await db.rawQuery('SELECT netbios_name, netbios_user, mac_address, vendor FROM devices WHERE id = ?', [deviceId]);

        // Add NetBIOS information from devices table if available
        if (devices.isNotEmpty) {
          final device = devices.first;
          if (device['netbios_name'] != null && device['netbios_name'].toString().isNotEmpty) {
            result['netbios_name'] = device['netbios_name'];
          }
          if (device['netbios_user'] != null && device['netbios_user'].toString().isNotEmpty) {
            result['netbios_user'] = device['netbios_user'];
          }
          // Use device table MAC/vendor as fallback if nmap_hosts doesn't have them
          if (device['mac_address'] != null && device['mac_address'].toString().isNotEmpty) {
            result['mac_address'] = device['mac_address'];
          }
          if (device['vendor'] != null && device['vendor'].toString().isNotEmpty) {
            result['vendor'] = device['vendor'];
          }
        }

        final Future<List<Map<String, dynamic>>> hostFuture = db.rawQuery('SELECT * FROM nmap_hosts WHERE device_id = ?', [deviceId]);
        final Future<List<Map<String, dynamic>>> searchsploitFuture = db.query('vulnerabilities', where: 'device_id = ? AND type = ?', whereArgs: [deviceId, 'SearchSploit'], orderBy: 'created_at DESC');
        final Future<List<Map<String, dynamic>>> whatwebFuture = db.query('whatweb_findings', where: 'device_id = ?', whereArgs: [deviceId], orderBy: 'created_at DESC');
        final Future<List<Map<String, dynamic>>> ffufFuture = db.query('ffuf_findings', where: 'device_id = ?', whereArgs: [deviceId], orderBy: 'status ASC, url ASC');
        final Future<List<Map<String, dynamic>>> sambaLdapFuture = db.query('samba_ldap_findings', where: 'device_id = ?', whereArgs: [deviceId], orderBy: 'created_at DESC');
        final Future<List<Map<String, dynamic>>> snmpFuture = db.query('snmp_findings', where: 'device_id = ?', whereArgs: [deviceId], orderBy: 'finding_type ASC');
        final Future<List<Map<String, dynamic>>> niktoFuture = db.query('nikto_findings', where: 'device_id = ?', whereArgs: [deviceId], orderBy: 'created_at DESC');

        final allFutures = await Future.wait([hostFuture, searchsploitFuture, whatwebFuture, ffufFuture, sambaLdapFuture, snmpFuture, niktoFuture]);

        final hosts = allFutures[0];
        result['searchsploit_vulnerabilities'] = allFutures[1];
        result['whatweb_findings'] = allFutures[2];
        result['ffuf_findings'] = allFutures[3];

        // Filter out "not supported" findings for Native OS and Native LAN Manager
        final sambaLdapFindings = allFutures[4];
        final filteredSambaFindings = sambaLdapFindings.where((finding) {
          final type = finding['finding_type']?.toString() ?? '';
          final value = finding['finding_value']?.toString() ?? '';

          if ((type == 'Native OS' || type == 'Native LAN Manager') && value == 'not supported') {
            return false;
          }
          return true;
        }).toList();
        result['samba_ldap_findings'] = filteredSambaFindings;

        result['snmp_findings'] = allFutures[5];
        result['nikto_findings'] = allFutures[6];

        if (hosts.isNotEmpty) {
          final host = hosts.first;
          result['host_status'] = host['status'];
          result['uptime_seconds'] = host['uptime_seconds'];
          result['mac_address'] = host['mac_address'];
          result['vendor'] = host['vendor'];
          final hostId = host['id'];

          final Future<List<Map<String, dynamic>>> osMatchesFuture = db.rawQuery('SELECT * FROM nmap_os_matches WHERE host_id = ? ORDER BY accuracy DESC', [hostId]);
          final Future<List<Map<String, dynamic>>> portsFuture = db.rawQuery('SELECT * FROM nmap_ports WHERE host_id = ? ORDER BY port ASC', [hostId]);
          final Future<List<Map<String, dynamic>>> cvesFuture = db.rawQuery('SELECT c.*, s.output FROM nmap_cves c JOIN nmap_scripts s ON c.script_id = s.id JOIN nmap_ports p ON s.port_id = p.id WHERE p.host_id = ? ORDER BY c.cvss DESC', [hostId]);
          final Future<List<Map<String, dynamic>>> scriptsFuture = db.rawQuery('SELECT s.*, p.port, p.protocol, p.service_name FROM nmap_scripts s JOIN nmap_ports p ON s.port_id = p.id WHERE p.host_id = ? AND s.script_id != \'vulners\' ORDER BY s.script_id ASC, p.port ASC', [hostId]);

          final hostDetailsFutures = await Future.wait([osMatchesFuture, portsFuture, cvesFuture, scriptsFuture]);

          result['os_matches'] = hostDetailsFutures[0];
          result['ports'] = hostDetailsFutures[1];

          final allCves = hostDetailsFutures[2];
          final allScripts = hostDetailsFutures[3];

          // Filter out useless script outputs
          final usefulScripts = allScripts.where((script) {
            final output = (script['output'] as String?) ?? '';
            final scriptId = (script['script_id'] as String?) ?? '';

            // Filter out common useless outputs
            if (output.trim().isEmpty) return false;
            if (output == 'Not Found') return false;
            if (output == 'ERROR: Script execution failed (use -d to debug)') return false;
            if (output.startsWith("Couldn't determine")) return false;
            if (output.startsWith("ERROR:")) return false;
            if (output.contains('Try increasing') && scriptId == 'http-devframework') return false;

            return true;
          }).toList();

          result['nmap_scripts'] = usefulScripts;

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
          
          final cves = allCves.where((cve) {
            final output = ((cve['output'] as String?) ?? '').trim();
            return !excludedPrefixes.any((prefix) => output.startsWith(prefix));
          }).toList();
          
          result['cves'] = cves.map((cve) {
            final Map<String, dynamic> filtered = Map.from(cve);
            filtered.remove('output');
            return filtered;
          }).toList();
        }
        
        return result;
      },
    );
  }

  Future<Map<String, dynamic>> getDeviceMetadata(int deviceId) async {
    final db = await _dbConnection.database;
    
    Map<String, dynamic> metadata = {
      'os_type': 'unknown',
      'has_vulnerabilities': false,
      'has_web_services': false,
      'has_database_services': false,
      'has_http_services': false,
    };
    
    final hosts = await db.rawQuery('SELECT * FROM nmap_hosts WHERE device_id = ?', [deviceId]);
    
    if (hosts.isNotEmpty) {
      final hostId = hosts.first['id'];
      
      final osMatches = await db.rawQuery('SELECT * FROM nmap_os_matches WHERE host_id = ? ORDER BY accuracy DESC LIMIT 1', [hostId]);
      
      if (osMatches.isNotEmpty) {
        final osName = osMatches.first['name'].toString().toLowerCase();
        final cpe = osMatches.first['cpe']?.toString().toLowerCase() ?? '';
        
        if (osName.contains('windows')) {
          metadata['os_type'] = 'windows';
        } else if (osName.contains('vmware') || cpe.contains('vmware')) {
          metadata['os_type'] = 'vmware';
        } else if (osName.contains('linux') || osName.contains('ubuntu') || osName.contains('debian') || osName.contains('centos') || osName.contains('redhat')) {
          metadata['os_type'] = 'linux';
        } else if (osName.contains('router') || osName.contains('switch') || osName.contains('cisco') || osName.contains('juniper') || cpe.contains('cisco')) {
          metadata['os_type'] = 'router';
        } else if (osName.contains('printer') || osName.contains('hp') || osName.contains('canon') || osName.contains('epson')) {
          metadata['os_type'] = 'printer';
        } else if (osName.contains('firewall') || osName.contains('pfsense') || osName.contains('fortinet')) {
          metadata['os_type'] = 'firewall';
        }
      } else {
        final serviceCheck = await db.rawQuery('SELECT product, cpe FROM nmap_ports WHERE host_id = ? AND (product IS NOT NULL OR cpe IS NOT NULL)', [hostId]);
        
        for (final row in serviceCheck) {
          final product = row['product']?.toString().toLowerCase() ?? '';
          final cpe = row['cpe']?.toString().toLowerCase() ?? '';
          
          if (product.contains('vmware') || cpe.contains('vmware')) {
            metadata['os_type'] = 'vmware';
            break;
          } else if (cpe.contains('cisco')) {
            metadata['os_type'] = 'router';
            break;
          }
        }
      }
      
      final cves = await db.rawQuery('SELECT COUNT(*) as count FROM nmap_cves c JOIN nmap_scripts s ON c.script_id = s.id JOIN nmap_ports p ON s.port_id = p.id WHERE p.host_id = ?', [hostId]);
      if (cves.isNotEmpty && (cves.first['count'] as int) > 0) {
        metadata['has_vulnerabilities'] = true;
      }
      
      final webPorts = await db.rawQuery("SELECT COUNT(*) as count FROM nmap_ports WHERE host_id = ? AND (port IN (80, 443, 8080, 8443, 8000, 8888) OR service_name LIKE '%http%' OR service_name LIKE '%web%')", [hostId]);
      if (webPorts.isNotEmpty && (webPorts.first['count'] as int) > 0) {
        metadata['has_web_services'] = true;
      }
      
      final dbPorts = await db.rawQuery("SELECT COUNT(*) as count FROM nmap_ports WHERE host_id = ? AND (port IN (3306, 5432, 1433, 1521, 27017, 6379) OR service_name LIKE '%mysql%' OR service_name LIKE '%postgres%' OR service_name LIKE '%mssql%' OR service_name LIKE '%oracle%' OR service_name LIKE '%mongo%' OR service_name LIKE '%redis%')", [hostId]);
      if (dbPorts.isNotEmpty && (dbPorts.first['count'] as int) > 0) {
        metadata['has_database_services'] = true;
      }
      
      final httpPorts = await db.rawQuery("SELECT COUNT(*) as count FROM nmap_ports WHERE host_id = ? AND (service_name = 'http' OR service_name = 'https' OR service_name LIKE '%httpapi%')", [hostId]);
      if (httpPorts.isNotEmpty && (httpPorts.first['count'] as int) > 0) {
        metadata['has_http_services'] = true;
      }
    }
    
    return metadata;
  }

  Future<Map<int, Map<String, dynamic>>> getBatchDeviceMetadata(int projectId, List<int> deviceIds) async {
    if (deviceIds.isEmpty) return {};
    
    return await PlatformUtils.platformSpecific(
      web: () => ApiDatabaseHelper().getBatchDeviceMetadata(projectId, deviceIds),
      desktop: () async {
        final db = await _dbConnection.database;
        final result = <int, Map<String, dynamic>>{};
        
        for (final deviceId in deviceIds) {
          result[deviceId] = {
            'os_type': 'unknown',
            'has_vulnerabilities': false,
            'has_web_services': false,
            'has_database_services': false,
            'has_http_services': false,
            'has_flags': false,
          };
        }
        
        final deviceIdsStr = deviceIds.join(',');
        final hosts = await db.rawQuery('SELECT device_id, id as host_id FROM nmap_hosts WHERE device_id IN ($deviceIdsStr)');
        
        final deviceToHostMap = <int, int>{};
        for (final host in hosts) {
          deviceToHostMap[host['device_id'] as int] = host['host_id'] as int;
        }
        
        if (deviceToHostMap.isNotEmpty) {
          final hostIds = deviceToHostMap.values.toList();
          final hostIdsStr = hostIds.join(',');
          
          final osMatches = await db.rawQuery('SELECT host_id, name, cpe, accuracy, ROW_NUMBER() OVER (PARTITION BY host_id ORDER BY accuracy DESC) as rn FROM nmap_os_matches WHERE host_id IN ($hostIdsStr)');
          
          for (final osMatch in osMatches) {
            if (osMatch['rn'] == 1) {
              final hostId = osMatch['host_id'] as int;
              final deviceId = deviceToHostMap.entries.firstWhere((e) => e.value == hostId).key;
              
              final osName = osMatch['name'].toString().toLowerCase();
              final cpe = osMatch['cpe']?.toString().toLowerCase() ?? '';
              
              String osType = 'unknown';
              if (osName.contains('windows')) {
                osType = 'windows';
              } else if (osName.contains('vmware') || cpe.contains('vmware')) {
                osType = 'vmware';
              } else if (osName.contains('linux') || osName.contains('ubuntu') || osName.contains('debian') || osName.contains('centos') || osName.contains('redhat')) {
                osType = 'linux';
              } else if (osName.contains('router') || osName.contains('switch') || osName.contains('cisco') || osName.contains('juniper') || cpe.contains('cisco')) {
                osType = 'router';
              } else if (osName.contains('printer') || osName.contains('hp') || osName.contains('canon') || osName.contains('epson')) {
                osType = 'printer';
              } else if (osName.contains('firewall') || osName.contains('pfsense') || osName.contains('fortinet')) {
                osType = 'firewall';
              }
              
              result[deviceId]!['os_type'] = osType;
            }
          }
          
          final vulnCounts = await db.rawQuery('SELECT p.host_id, COUNT(*) as count FROM nmap_cves c JOIN nmap_scripts s ON c.script_id = s.id JOIN nmap_ports p ON s.port_id = p.id WHERE p.host_id IN ($hostIdsStr) GROUP BY p.host_id');
          for (final vulnCount in vulnCounts) {
            final hostId = vulnCount['host_id'] as int;
            final deviceId = deviceToHostMap.entries.firstWhere((e) => e.value == hostId).key;
            result[deviceId]!['has_vulnerabilities'] = (vulnCount['count'] as int) > 0;
          }
          
          final webCounts = await db.rawQuery("SELECT host_id, COUNT(*) as count FROM nmap_ports WHERE host_id IN ($hostIdsStr) AND (port IN (80, 443, 8080, 8443, 8000, 8888) OR service_name LIKE '%http%' OR service_name LIKE '%web%') GROUP BY host_id");
          for (final webCount in webCounts) {
            final hostId = webCount['host_id'] as int;
            final deviceId = deviceToHostMap.entries.firstWhere((e) => e.value == hostId).key;
            result[deviceId]!['has_web_services'] = (webCount['count'] as int) > 0;
          }
          
          final dbCounts = await db.rawQuery("SELECT host_id, COUNT(*) as count FROM nmap_ports WHERE host_id IN ($hostIdsStr) AND (port IN (3306, 5432, 1433, 1521, 27017, 6379) OR service_name LIKE '%mysql%' OR service_name LIKE '%postgres%' OR service_name LIKE '%mssql%' OR service_name LIKE '%oracle%' OR service_name LIKE '%mongo%' OR service_name LIKE '%redis%') GROUP BY host_id");
          for (final dbCount in dbCounts) {
            final hostId = dbCount['host_id'] as int;
            final deviceId = deviceToHostMap.entries.firstWhere((e) => e.value == hostId).key;
            result[deviceId]!['has_database_services'] = (dbCount['count'] as int) > 0;
          }
          
          final httpCounts = await db.rawQuery("SELECT host_id, COUNT(*) as count FROM nmap_ports WHERE host_id IN ($hostIdsStr) AND (service_name = 'http' OR service_name = 'https' OR service_name LIKE '%httpapi%') GROUP BY host_id");
          for (final httpCount in httpCounts) {
            final hostId = httpCount['host_id'] as int;
            final deviceId = deviceToHostMap.entries.firstWhere((e) => e.value == hostId).key;
            result[deviceId]!['has_http_services'] = (httpCount['count'] as int) > 0;
          }
        }
        
        final flaggedDevices = await db.rawQuery('SELECT DISTINCT device_id FROM flagged_findings WHERE device_id IN ($deviceIdsStr)');
        for (final row in flaggedDevices) {
          final deviceId = row['device_id'] as int;
          result[deviceId]!['has_flags'] = true;
        }
        
        return result;
      },
    );
  }

  Future<List<Map<String, dynamic>>> getHttpTargets(int projectId) async {
    final db = await _dbConnection.database;
    return await db.rawQuery('''
      SELECT DISTINCT d.id, d.ip_address, GROUP_CONCAT(DISTINCT p.port) as ports
      FROM devices d
      JOIN nmap_hosts h ON d.id = h.device_id
      JOIN nmap_ports p ON h.id = p.host_id
      WHERE d.project_id = ? AND (p.port IN (80, 443, 8080, 8443) OR p.service_name LIKE '%http%') AND p.state = 'open'
      GROUP BY d.id, d.ip_address
    ''', [projectId]);
  }

  Future<List<Map<String, dynamic>>> getHttpTargetsForDevice(int deviceId) async {
    final db = await _dbConnection.database;
    return await db.rawQuery('''
      SELECT DISTINCT d.id, d.ip_address, GROUP_CONCAT(DISTINCT p.port) as ports
      FROM devices d
      JOIN nmap_hosts h ON d.id = h.device_id
      JOIN nmap_ports p ON h.id = p.host_id
      WHERE d.id = ? AND (p.port IN (80, 443, 8080, 8443) OR p.service_name LIKE '%http%') AND p.state = 'open'
      GROUP BY d.id, d.ip_address
    ''', [deviceId]);
  }

  Future<List<Map<String, dynamic>>> getSambaLdapTargets(int projectId) async {
    final db = await _dbConnection.database;
    return await db.rawQuery('''
      SELECT DISTINCT d.id, d.ip_address
      FROM devices d
      JOIN nmap_hosts h ON d.id = h.device_id
      JOIN nmap_ports p ON h.id = p.host_id
      WHERE d.project_id = ? AND p.port IN (139, 389, 445, 636) AND p.state = 'open'
      GROUP BY d.id, d.ip_address
    ''', [projectId]);
  }

  Future<List<Map<String, dynamic>>> getSambaLdapTargetsForDevice(int deviceId) async {
    final db = await _dbConnection.database;
    return await db.rawQuery('''
      SELECT DISTINCT d.id, d.ip_address
      FROM devices d
      JOIN nmap_hosts h ON d.id = h.device_id
      JOIN nmap_ports p ON h.id = p.host_id
      WHERE d.id = ? AND p.port IN (139, 389, 445, 636) AND p.state = 'open'
      GROUP BY d.id, d.ip_address
    ''', [deviceId]);
  }

  Future<void> moveDeviceToProject(int deviceId, int newProjectId) async {
    if (kIsWeb) {
      await http.put(
        Uri.parse('/api/devices/$deviceId/move'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'project_id': newProjectId}),
      );
      return;
    }

    final db = await _dbConnection.database;

    String? oldProjectName;
    String? newProjectName;
    List<String> imagesToMove = [];

    // Start a transaction to ensure all updates succeed or fail together
    await db.transaction((txn) async {
      // Get the device to find its current project_id
      final deviceResults = await txn.query(
        'devices',
        where: 'id = ?',
        whereArgs: [deviceId],
        limit: 1,
      );

      if (deviceResults.isEmpty) {
        throw Exception('Device not found');
      }

      final oldProjectId = deviceResults.first['project_id'] as int;

      // Get old and new project names for path updates
      final oldProjectResults = await txn.query(
        'projects',
        where: 'id = ?',
        whereArgs: [oldProjectId],
        limit: 1,
      );

      final newProjectResults = await txn.query(
        'projects',
        where: 'id = ?',
        whereArgs: [newProjectId],
        limit: 1,
      );

      if (oldProjectResults.isEmpty || newProjectResults.isEmpty) {
        throw Exception('Project not found');
      }

      oldProjectName = oldProjectResults.first['name'] as String;
      newProjectName = newProjectResults.first['name'] as String;

      // Update image paths in flagged_findings if project names are different
      if (oldProjectName != newProjectName) {
        final findings = await txn.query(
          'flagged_findings',
          where: 'device_id = ?',
          whereArgs: [deviceId],
        );

        for (final finding in findings) {
          final id = finding['id'] as int;
          final comment = finding['comment'] as String?;
          final recommendation = finding['recommendation'] as String?;
          final evidence = finding['evidence'] as String?;

          // Extract image references from all three fields to track files to move
          final allContent = [comment, recommendation, evidence]
              .where((c) => c != null)
              .join(' ');

          debugPrint('[MOVE] Scanning finding $id for images in project $oldProjectName');

          // Find all image references with various path formats
          // Pattern matches both absolute and relative paths with various separators
          final imageExtensions = ['.png', '.jpg', '.jpeg', '.gif', '.bmp', '.webp'];
          for (final ext in imageExtensions) {
            // Match paths containing the old project name and ending with the extension
            // This handles: C:\\...\\uploads\\PROJECT\\file.ext or uploads\\PROJECT\\file.ext
            final pattern = RegExp(
              r'[A-Za-z]?:?[\\/\\\\]*(?:[^\\/\\\\"\s<>]+[\\/\\\\]+)*uploads[\\/\\\\]+' +
              RegExp.escape(oldProjectName!) +
              r'[\\/\\\\]+[^"\s<>]+?' +
              RegExp.escape(ext),
              caseSensitive: false,
            );

            final matches = pattern.allMatches(allContent);
            for (final match in matches) {
              var imagePath = match.group(0);
              if (imagePath != null) {
                debugPrint('[MOVE] Found image reference: $imagePath');
                // Normalize to single backslashes for file operations
                imagePath = imagePath.replaceAll('\\\\', '\\');
                if (!imagesToMove.contains(imagePath)) {
                  imagesToMove.add(imagePath);
                  debugPrint('[MOVE] Added to move list: $imagePath');
                }
              }
            }
          }

          debugPrint('[MOVE] Found ${imagesToMove.length} total images to move so far');

          // Build all possible path format variations for replacement
          // We need to handle both relative and absolute paths
          final dbDir = Directory.current.path;

          // Relative paths
          final oldWindowsPath = 'uploads\\$oldProjectName';
          final newWindowsPath = 'uploads\\$newProjectName';
          final oldWindowsPathEscaped = 'uploads\\\\$oldProjectName'; // JSON escaped
          final newWindowsPathEscaped = 'uploads\\\\$newProjectName'; // JSON escaped
          final oldLinuxPath = 'uploads/$oldProjectName';
          final newLinuxPath = 'uploads/$newProjectName';

          // Absolute paths (for Windows and Linux)
          final oldAbsoluteWindowsPath = path.join(dbDir, 'uploads', oldProjectName!).replaceAll('/', '\\');
          final newAbsoluteWindowsPath = path.join(dbDir, 'uploads', newProjectName!).replaceAll('/', '\\');
          final oldAbsoluteWindowsPathEscaped = oldAbsoluteWindowsPath.replaceAll('\\', '\\\\'); // JSON escaped
          final newAbsoluteWindowsPathEscaped = newAbsoluteWindowsPath.replaceAll('\\', '\\\\'); // JSON escaped
          final oldAbsoluteLinuxPath = path.join(dbDir, 'uploads', oldProjectName!).replaceAll('\\', '/');
          final newAbsoluteLinuxPath = path.join(dbDir, 'uploads', newProjectName!).replaceAll('\\', '/');

          // Update paths in all three fields - handle both regular and JSON-escaped paths
          var updatedComment = comment;
          var updatedRecommendation = recommendation;
          var updatedEvidence = evidence;

          if (updatedComment != null) {
            updatedComment = updatedComment
                // Absolute paths first (more specific)
                .replaceAll(oldAbsoluteWindowsPathEscaped, newAbsoluteWindowsPathEscaped)
                .replaceAll(oldAbsoluteWindowsPath, newAbsoluteWindowsPath)
                .replaceAll(oldAbsoluteLinuxPath, newAbsoluteLinuxPath)
                // Then relative paths
                .replaceAll(oldWindowsPathEscaped, newWindowsPathEscaped)
                .replaceAll(oldWindowsPath, newWindowsPath)
                .replaceAll(oldLinuxPath, newLinuxPath);
          }

          if (updatedRecommendation != null) {
            updatedRecommendation = updatedRecommendation
                // Absolute paths first (more specific)
                .replaceAll(oldAbsoluteWindowsPathEscaped, newAbsoluteWindowsPathEscaped)
                .replaceAll(oldAbsoluteWindowsPath, newAbsoluteWindowsPath)
                .replaceAll(oldAbsoluteLinuxPath, newAbsoluteLinuxPath)
                // Then relative paths
                .replaceAll(oldWindowsPathEscaped, newWindowsPathEscaped)
                .replaceAll(oldWindowsPath, newWindowsPath)
                .replaceAll(oldLinuxPath, newLinuxPath);
          }

          if (updatedEvidence != null) {
            updatedEvidence = updatedEvidence
                // Absolute paths first (more specific)
                .replaceAll(oldAbsoluteWindowsPathEscaped, newAbsoluteWindowsPathEscaped)
                .replaceAll(oldAbsoluteWindowsPath, newAbsoluteWindowsPath)
                .replaceAll(oldAbsoluteLinuxPath, newAbsoluteLinuxPath)
                // Then relative paths
                .replaceAll(oldWindowsPathEscaped, newWindowsPathEscaped)
                .replaceAll(oldWindowsPath, newWindowsPath)
                .replaceAll(oldLinuxPath, newLinuxPath);
          }

          // Only update if something changed
          if (updatedComment != comment ||
              updatedRecommendation != recommendation ||
              updatedEvidence != evidence) {
            debugPrint('[MOVE] Updating paths in finding $id:');
            if (updatedComment != comment) debugPrint('[MOVE]   - Comment updated');
            if (updatedRecommendation != recommendation) debugPrint('[MOVE]   - Recommendation updated');
            if (updatedEvidence != evidence) debugPrint('[MOVE]   - Evidence updated');

            await txn.update(
              'flagged_findings',
              {
                if (updatedComment != null) 'comment': updatedComment,
                if (updatedRecommendation != null) 'recommendation': updatedRecommendation,
                if (updatedEvidence != null) 'evidence': updatedEvidence,
              },
              where: 'id = ?',
              whereArgs: [id],
            );
          }
        }
      }

      // Update devices table
      await txn.update(
        'devices',
        {'project_id': newProjectId},
        where: 'id = ?',
        whereArgs: [deviceId],
      );

      // Update flagged_findings table
      await txn.update(
        'flagged_findings',
        {'project_id': newProjectId},
        where: 'device_id = ?',
        whereArgs: [deviceId],
      );

      // Update nmap_hosts table (if project_id column exists)
      try {
        await txn.update(
          'nmap_hosts',
          {'project_id': newProjectId},
          where: 'device_id = ?',
          whereArgs: [deviceId],
        );
      } catch (e) {
        // Column might not exist, that's okay - nmap_hosts is linked via device_id
        debugPrint('Note: nmap_hosts project_id update skipped (column may not exist): $e');
      }

      // Update snmp_findings table
      await txn.update(
        'snmp_findings',
        {'project_id': newProjectId},
        where: 'device_id = ?',
        whereArgs: [deviceId],
      );

      // Update vulnerability_classifications table
      await txn.update(
        'vulnerability_classifications',
        {'project_id': newProjectId},
        where: 'device_id = ?',
        whereArgs: [deviceId],
      );
    });

    // After successful transaction, physically move the image files
    debugPrint('[MOVE] Transaction completed. Moving ${imagesToMove.length} image files...');

    if (oldProjectName != null &&
        newProjectName != null &&
        oldProjectName != newProjectName &&
        imagesToMove.isNotEmpty) {
      try {
        final dbDir = Directory.current.path;
        final newUploadDir = path.join(dbDir, 'uploads', newProjectName!);

        debugPrint('[MOVE] Creating destination directory: $newUploadDir');

        // Ensure new project uploads directory exists
        final newDir = Directory(newUploadDir);
        if (!await newDir.exists()) {
          await newDir.create(recursive: true);
        }

        // Move each image file
        int successCount = 0;
        for (final imagePath in imagesToMove) {
          // Normalize path separators
          final normalizedPath = imagePath.replaceAll('\\', path.separator).replaceAll('/', path.separator);
          final oldFile = File(normalizedPath);

          debugPrint('[MOVE] Processing: $normalizedPath');

          if (await oldFile.exists()) {
            // Extract filename from path
            final filename = path.basename(normalizedPath);
            final newFilePath = path.join(newUploadDir, filename);

            // Move the file
            try {
              await oldFile.copy(newFilePath);
              await oldFile.delete();
              successCount++;
              debugPrint('[MOVE] ✓ Moved: $filename');
            } catch (e) {
              debugPrint('[MOVE] ✗ Failed to move $filename: $e');
              // Continue with other files even if one fails
            }
          } else {
            debugPrint('[MOVE] ✗ File not found: $normalizedPath');
          }
        }

        debugPrint('[MOVE] Successfully moved $successCount/${imagesToMove.length} image(s) for device $deviceId');
      } catch (e) {
        debugPrint('[MOVE] Error moving image files: $e');
        // Don't throw - database updates are already committed and paths are updated
      }
    } else {
      debugPrint('[MOVE] No images to move (oldProject=$oldProjectName, newProject=$newProjectName, images=${imagesToMove.length})');
    }
  }
}
