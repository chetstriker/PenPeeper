import 'package:penpeeper/repositories/base_repository.dart';
import 'package:penpeeper/database/connection/database_connection.dart';
import 'package:penpeeper/api_database_helper.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:http/http.dart' as http;
import 'dart:convert';

class MetadataRepository extends BaseRepository {
  final _dbConnection = DatabaseConnection();
  Future<Map<String, dynamic>> getDeviceDetails(int deviceId) async {
    if (kIsWeb) {
      return await ApiDatabaseHelper().getDeviceDetails(deviceId);
    }
    final db = await _dbConnection.database;

    // Get device information including NetBIOS fields
    final devices = await db.rawQuery('''
      SELECT netbios_name, netbios_user, mac_address, vendor FROM devices WHERE id = ?
    ''', [deviceId]);

    Map<String, dynamic> result = {};

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

    final hosts = await db.rawQuery('''
      SELECT * FROM nmap_hosts WHERE device_id = ?
    ''', [deviceId]);
    
    if (hosts.isNotEmpty) {
      final host = hosts.first;
      result['host_status'] = host['status'];
      result['uptime_seconds'] = host['uptime_seconds'];
      result['mac_address'] = host['mac_address'];
      result['vendor'] = host['vendor'];
      
      final hostId = host['id'];
      
      final osMatches = await db.rawQuery('''
        SELECT * FROM nmap_os_matches WHERE host_id = ? ORDER BY accuracy DESC
      ''', [hostId]);
      result['os_matches'] = osMatches;
      
      final ports = await db.rawQuery('''
        SELECT * FROM nmap_ports WHERE host_id = ? ORDER BY port ASC
      ''', [hostId]);
      result['ports'] = ports;
      
      final allCves = await db.rawQuery('''
        SELECT c.*, s.output FROM nmap_cves c
        JOIN nmap_scripts s ON c.script_id = s.id
        JOIN nmap_ports p ON s.port_id = p.id
        WHERE p.host_id = ?
        ORDER BY c.cvss DESC
      ''', [hostId]);
      
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
      
      final finalCves = cves.map((cve) {
        final Map<String, dynamic> filtered = Map.from(cve);
        filtered.remove('output');
        return filtered;
      }).toList();
      result['cves'] = finalCves;

      // Get all nmap scripts excluding vulners (already shown as CVEs) and useless outputs
      final allScripts = await db.rawQuery('''
        SELECT s.*, p.port, p.protocol, p.service_name
        FROM nmap_scripts s
        JOIN nmap_ports p ON s.port_id = p.id
        WHERE p.host_id = ? AND s.script_id != 'vulners'
        ORDER BY s.script_id ASC, p.port ASC
      ''', [hostId]);

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
    }

    final searchsploitVulns = await db.query('vulnerabilities',
      where: 'device_id = ? AND type = ?',
      whereArgs: [deviceId, 'SearchSploit'],
      orderBy: 'created_at DESC',
    );
    result['searchsploit_vulnerabilities'] = searchsploitVulns;
    
    final whatwebFindings = await db.query('whatweb_findings',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'created_at DESC',
    );
    result['whatweb_findings'] = whatwebFindings;
    
    final ffufFindings = await db.query('ffuf_findings',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'status ASC, url ASC',
    );
    result['ffuf_findings'] = ffufFindings;
    
    final sambaLdapFindings = await db.query('samba_ldap_findings',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'created_at DESC',
    );
    // Filter out "not supported" findings for Native OS and Native LAN Manager
    final filteredSambaFindings = sambaLdapFindings.where((finding) {
      final type = finding['finding_type']?.toString() ?? '';
      final value = finding['finding_value']?.toString() ?? '';

      if ((type == 'Native OS' || type == 'Native LAN Manager') &&
          value == 'not supported') {
        return false;
      }
      return true;
    }).toList();
    result['samba_ldap_findings'] = filteredSambaFindings;
    
    final snmpFindings = await db.query('snmp_findings',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'finding_type ASC',
    );
    result['snmp_findings'] = snmpFindings;

    final niktoFindings = await db.query('nikto_findings',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'created_at DESC',
    );
    result['nikto_findings'] = niktoFindings;

    return result;
  }

  Future<Map<String, dynamic>> getDeviceMetadata(int deviceId) async {
    if (kIsWeb) {
      return {
        'os_type': 'unknown',
        'has_vulnerabilities': false,
        'has_web_services': false,
        'has_database_services': false,
        'has_http_services': false,
      };
    }
    final db = await _dbConnection.database;
    
    Map<String, dynamic> metadata = {
      'os_type': 'unknown',
      'has_vulnerabilities': false,
      'has_web_services': false,
      'has_database_services': false,
      'has_http_services': false,
    };
    
    final hosts = await db.rawQuery('''
      SELECT * FROM nmap_hosts WHERE device_id = ?
    ''', [deviceId]);
    
    if (hosts.isNotEmpty) {
      final hostId = hosts.first['id'];
      
      final osMatches = await db.rawQuery('''
        SELECT * FROM nmap_os_matches WHERE host_id = ? ORDER BY accuracy DESC LIMIT 1
      ''', [hostId]);
      
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
      }
      
      final cves = await db.rawQuery('''
        SELECT COUNT(*) as count FROM nmap_cves c
        JOIN nmap_scripts s ON c.script_id = s.id
        JOIN nmap_ports p ON s.port_id = p.id
        WHERE p.host_id = ?
      ''', [hostId]);
      
      if (cves.isNotEmpty && (cves.first['count'] as int) > 0) {
        metadata['has_vulnerabilities'] = true;
      }
      
      final webPorts = await db.rawQuery('''
        SELECT COUNT(*) as count FROM nmap_ports 
        WHERE host_id = ? AND (port IN (80, 443, 8080, 8443, 8000, 8888) OR service_name LIKE '%http%' OR service_name LIKE '%web%')
      ''', [hostId]);
      
      if (webPorts.isNotEmpty && (webPorts.first['count'] as int) > 0) {
        metadata['has_web_services'] = true;
      }
      
      final dbPorts = await db.rawQuery('''
        SELECT COUNT(*) as count FROM nmap_ports 
        WHERE host_id = ? AND (port IN (3306, 5432, 1433, 1521, 27017, 6379) OR service_name LIKE '%mysql%' OR service_name LIKE '%postgres%' OR service_name LIKE '%mssql%' OR service_name LIKE '%oracle%' OR service_name LIKE '%mongo%' OR service_name LIKE '%redis%')
      ''', [hostId]);
      
      if (dbPorts.isNotEmpty && (dbPorts.first['count'] as int) > 0) {
        metadata['has_database_services'] = true;
      }
      
      final httpPorts = await db.rawQuery('''
        SELECT COUNT(*) as count FROM nmap_ports 
        WHERE host_id = ? AND (service_name = 'http' OR service_name = 'https' OR service_name LIKE '%httpapi%')
      ''', [hostId]);
      
      if (httpPorts.isNotEmpty && (httpPorts.first['count'] as int) > 0) {
        metadata['has_http_services'] = true;
      }
    }
    
    return metadata;
  }

  Future<Map<int, Map<String, dynamic>>> getBatchDeviceMetadata(int projectId, List<int> deviceIds) async {
    if (deviceIds.isEmpty) return {};
    
    if (kIsWeb) {
      return await ApiDatabaseHelper().getBatchDeviceMetadata(projectId, deviceIds);
    }
    
    final db = await _dbConnection.database;
    final result = <int, Map<String, dynamic>>{};
    
    for (final deviceId in deviceIds) {
      result[deviceId] = {
        'os_type': 'unknown',
        'has_vulnerabilities': false,
        'has_web_services': false,
        'has_database_services': false,
        'has_http_services': false,
      };
    }
    
    final deviceIdsStr = deviceIds.join(',');
    
    final hosts = await db.rawQuery('''
      SELECT device_id, id as host_id FROM nmap_hosts WHERE device_id IN ($deviceIdsStr)
    ''');
    
    final deviceToHostMap = <int, int>{};
    for (final host in hosts) {
      deviceToHostMap[host['device_id'] as int] = host['host_id'] as int;
    }
    
    if (deviceToHostMap.isNotEmpty) {
      final hostIds = deviceToHostMap.values.toList();
      final hostIdsStr = hostIds.join(',');
      
      final osMatches = await db.rawQuery('''
        SELECT host_id, name, cpe, accuracy,
               ROW_NUMBER() OVER (PARTITION BY host_id ORDER BY accuracy DESC) as rn
        FROM nmap_os_matches 
        WHERE host_id IN ($hostIdsStr)
      ''');
      
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
      
      // Check for database services
      final dbServices = await db.rawQuery('''
        SELECT host_id FROM nmap_ports 
        WHERE host_id IN ($hostIdsStr) 
          AND (service_name LIKE '%sql%' OR service_name LIKE '%database%' 
               OR service_name = 'mysql' OR service_name = 'postgresql' 
               OR service_name = 'mongodb' OR service_name = 'oracle')
        GROUP BY host_id
      ''');
      for (final row in dbServices) {
        final hostId = row['host_id'] as int;
        final deviceId = deviceToHostMap.entries.firstWhere((e) => e.value == hostId).key;
        result[deviceId]!['has_database_services'] = true;
      }
      
      // Check for HTTP services
      final httpServices = await db.rawQuery('''
        SELECT host_id FROM nmap_ports 
        WHERE host_id IN ($hostIdsStr) 
          AND (service_name = 'http' OR service_name = 'https' OR service_name LIKE '%httpapi%')
        GROUP BY host_id
      ''');
      for (final row in httpServices) {
        final hostId = row['host_id'] as int;
        final deviceId = deviceToHostMap.entries.firstWhere((e) => e.value == hostId).key;
        result[deviceId]!['has_http_services'] = true;
      }
    }
    
    // Check for flagged findings
    final flaggedDevices = await db.rawQuery('''
      SELECT DISTINCT device_id FROM flagged_findings 
      WHERE device_id IN ($deviceIdsStr)
    ''');
    for (final row in flaggedDevices) {
      final deviceId = row['device_id'] as int;
      result[deviceId]!['has_flags'] = true;
    }
    
    return result;
  }

  Future<List<Map<String, dynamic>>> getHttpTargets(int projectId) async {
    if (kIsWeb) return [];
    final db = await _dbConnection.database;
    
    return await db.rawQuery('''
      SELECT DISTINCT d.id, d.ip_address,
             GROUP_CONCAT(DISTINCT p.port) as ports
      FROM devices d
      JOIN nmap_hosts h ON d.id = h.device_id
      JOIN nmap_ports p ON h.id = p.host_id
      WHERE d.project_id = ? 
        AND (p.port IN (80, 443, 8080, 8443) 
             OR p.service_name LIKE '%http%')
        AND p.state = 'open'
      GROUP BY d.id, d.ip_address
    ''', [projectId]);
  }

  Future<List<Map<String, dynamic>>> getHttpTargetsForDevice(int deviceId) async {
    if (kIsWeb) return [];
    final db = await _dbConnection.database;
    
    return await db.rawQuery('''
      SELECT DISTINCT d.id, d.ip_address,
             GROUP_CONCAT(DISTINCT p.port) as ports
      FROM devices d
      JOIN nmap_hosts h ON d.id = h.device_id
      JOIN nmap_ports p ON h.id = p.host_id
      WHERE d.id = ? 
        AND (p.port IN (80, 443, 8080, 8443) 
             OR p.service_name LIKE '%http%')
        AND p.state = 'open'
      GROUP BY d.id, d.ip_address
    ''', [deviceId]);
  }

  Future<List<Map<String, dynamic>>> getSambaLdapTargets(int projectId) async {
    if (kIsWeb) return [];

    debugPrint('=== getSambaLdapTargets (BATCH) START ===');
    debugPrint('Project ID: $projectId');

    try {
      final db = await _dbConnection.database;
      debugPrint('Database connection obtained successfully');

      // First, get all devices in this project
      final allDevices = await db.rawQuery(
        'SELECT id, ip_address, name FROM devices WHERE project_id = ?',
        [projectId]
      );
      debugPrint('Total devices in project: ${allDevices.length}');

      if (allDevices.isEmpty) {
        debugPrint('No devices found in project!');
        debugPrint('=== getSambaLdapTargets (BATCH) END ===');
        return [];
      }

      // Check NMAP data for all devices
      final devicesWithNmap = await db.rawQuery('''
        SELECT COUNT(DISTINCT h.device_id) as count
        FROM nmap_hosts h
        JOIN devices d ON h.device_id = d.id
        WHERE d.project_id = ?
      ''', [projectId]);
      debugPrint('Devices with NMAP data: ${devicesWithNmap.first['count']} of ${allDevices.length}');

      // Get total port count across all devices
      final totalPorts = await db.rawQuery('''
        SELECT COUNT(*) as count
        FROM nmap_ports p
        JOIN nmap_hosts h ON p.host_id = h.id
        JOIN devices d ON h.device_id = d.id
        WHERE d.project_id = ?
      ''', [projectId]);
      debugPrint('Total NMAP ports across all devices: ${totalPorts.first['count']}');

      // Check for devices with SAMBA/LDAP ports (any state)
      final devicesWithSambaPorts = await db.rawQuery('''
        SELECT DISTINCT d.id, d.name, d.ip_address,
               COUNT(DISTINCT p.port) as port_count,
               GROUP_CONCAT(DISTINCT p.port || ':' || p.state) as port_states
        FROM devices d
        JOIN nmap_hosts h ON d.id = h.device_id
        JOIN nmap_ports p ON h.id = p.host_id
        WHERE d.project_id = ?
          AND p.port IN (139, 389, 445, 636)
        GROUP BY d.id, d.name, d.ip_address
      ''', [projectId]);

      debugPrint('Devices with SAMBA/LDAP ports (any state): ${devicesWithSambaPorts.length}');
      for (final device in devicesWithSambaPorts) {
        debugPrint('  Device ${device['id']} (${device['ip_address']} - ${device['name']}):');
        debugPrint('    Ports: ${device['port_states']}');
      }

      // Now get devices with OPEN SAMBA/LDAP ports only
      final results = await db.rawQuery('''
        SELECT DISTINCT d.id, d.ip_address
        FROM devices d
        JOIN nmap_hosts h ON d.id = h.device_id
        JOIN nmap_ports p ON h.id = p.host_id
        WHERE d.project_id = ?
          AND p.port IN (139, 389, 445, 636)
          AND p.state = 'open'
        GROUP BY d.id, d.ip_address
      ''', [projectId]);

      debugPrint('Devices with OPEN SAMBA/LDAP ports: ${results.length}');
      if (results.isEmpty) {
        debugPrint('⚠️  NO DEVICES WITH OPEN SAMBA/LDAP PORTS FOUND');
        debugPrint('This means no devices in this project have open ports 139, 389, 445, or 636');
        if (devicesWithSambaPorts.isNotEmpty) {
          debugPrint('Note: ${devicesWithSambaPorts.length} device(s) have these ports but they are closed/filtered');
        }
        if (allDevices.length > (devicesWithNmap.first['count'] as int)) {
          debugPrint('Note: ${allDevices.length - (devicesWithNmap.first['count'] as int)} device(s) have not been scanned with NMAP yet');
        }
      } else {
        debugPrint('Target devices for batch scan:');
        for (int i = 0; i < results.length; i++) {
          debugPrint('  ${i + 1}. Device ${results[i]['id']} - ${results[i]['ip_address']}');
        }
      }

      debugPrint('=== getSambaLdapTargets (BATCH) END ===');
      return results;
    } catch (e, stackTrace) {
      debugPrint('ERROR in getSambaLdapTargets: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('=== getSambaLdapTargets (BATCH) ERROR END ===');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getSambaLdapTargetsForDevice(int deviceId) async {
    if (kIsWeb) return [];

    debugPrint('=== getSambaLdapTargetsForDevice START ===');
    debugPrint('Device ID: $deviceId');

    try {
      final db = await _dbConnection.database;
      debugPrint('Database connection obtained successfully');

      // First, verify the device exists
      final deviceCheck = await db.rawQuery(
        'SELECT id, ip_address, name FROM devices WHERE id = ?',
        [deviceId]
      );
      debugPrint('Device query result: $deviceCheck');

      if (deviceCheck.isEmpty) {
        debugPrint('ERROR: Device $deviceId not found in database!');
        return [];
      }

      // Check if there are any nmap_hosts for this device
      final hostsCheck = await db.rawQuery(
        'SELECT COUNT(*) as count FROM nmap_hosts WHERE device_id = ?',
        [deviceId]
      );
      debugPrint('NMAP hosts count: ${hostsCheck.first['count']}');

      // Check if there are any nmap_ports for this device
      final portsCheck = await db.rawQuery('''
        SELECT COUNT(*) as count
        FROM nmap_ports p
        JOIN nmap_hosts h ON p.host_id = h.id
        WHERE h.device_id = ?
      ''', [deviceId]);
      debugPrint('NMAP ports count: ${portsCheck.first['count']}');

      // Show ALL ports found for this device (for debugging)
      final allPorts = await db.rawQuery('''
        SELECT p.port, p.protocol, p.state, p.service_name
        FROM nmap_ports p
        JOIN nmap_hosts h ON p.host_id = h.id
        WHERE h.device_id = ?
        ORDER BY p.port
      ''', [deviceId]);
      debugPrint('All ports found for this device:');
      if (allPorts.isEmpty) {
        debugPrint('  (No ports found in database)');
      } else {
        for (final port in allPorts) {
          debugPrint('  Port ${port['port']}/${port['protocol']} - ${port['state']} - Service: ${port['service_name'] ?? 'unknown'}');
        }
      }

      // Check for SAMBA/LDAP ports specifically
      final sambaPortsCheck = await db.rawQuery('''
        SELECT COUNT(*) as count
        FROM nmap_ports p
        JOIN nmap_hosts h ON p.host_id = h.id
        WHERE h.device_id = ?
          AND p.port IN (139, 389, 445, 636)
          AND p.state = 'open'
      ''', [deviceId]);
      debugPrint('SAMBA/LDAP open ports count: ${sambaPortsCheck.first['count']}');

      // Show specific SAMBA/LDAP ports (even if closed/filtered)
      final sambaPortsDetail = await db.rawQuery('''
        SELECT p.port, p.protocol, p.state, p.service_name
        FROM nmap_ports p
        JOIN nmap_hosts h ON p.host_id = h.id
        WHERE h.device_id = ?
          AND p.port IN (139, 389, 445, 636)
        ORDER BY p.port
      ''', [deviceId]);
      debugPrint('SAMBA/LDAP ports (139, 389, 445, 636) status:');
      if (sambaPortsDetail.isEmpty) {
        debugPrint('  (No SAMBA/LDAP ports found - device may not have been scanned with NMAP yet)');
      } else {
        for (final port in sambaPortsDetail) {
          debugPrint('  Port ${port['port']}/${port['protocol']} - STATE: ${port['state']} - Service: ${port['service_name'] ?? 'unknown'}');
        }
        final openCount = sambaPortsDetail.where((p) => p['state'] == 'open').length;
        debugPrint('  → ${openCount} of ${sambaPortsDetail.length} SAMBA/LDAP ports are OPEN');
      }

      // Now run the actual query
      final results = await db.rawQuery('''
        SELECT DISTINCT d.id, d.ip_address
        FROM devices d
        JOIN nmap_hosts h ON d.id = h.device_id
        JOIN nmap_ports p ON h.id = p.host_id
        WHERE d.id = ?
          AND p.port IN (139, 389, 445, 636)
          AND p.state = 'open'
        GROUP BY d.id, d.ip_address
      ''', [deviceId]);

      debugPrint('Final query returned ${results.length} results: $results');
      debugPrint('=== getSambaLdapTargetsForDevice END ===');

      return results;
    } catch (e, stackTrace) {
      debugPrint('ERROR in getSambaLdapTargetsForDevice: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('=== getSambaLdapTargetsForDevice ERROR END ===');
      rethrow;
    }
  }

  Future<List<String>> getDistinctOperatingSystems(int projectId) async {
    if (kIsWeb) {
      return await ApiDatabaseHelper().getDistinctOperatingSystems(projectId);
    }
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
  }

  Future<List<String>> getDistinctMacVendors(int projectId) async {
    if (kIsWeb) {
      return await ApiDatabaseHelper().getDistinctMacVendors(projectId);
    }
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
  }

  Future<List<Map<String, dynamic>>> getDevicesByMacVendor(int projectId, String vendor) async {
    if (kIsWeb) {
      return await ApiDatabaseHelper().searchDevices(projectId, 'VENDOR', vendor);
    }
    final db = await _dbConnection.database;
    return await db.rawQuery('''
      SELECT d.*
      FROM devices d
      JOIN nmap_hosts h ON d.id = h.device_id
      WHERE d.project_id = ?
        AND h.vendor = ?
      ORDER BY d.name ASC
    ''', [projectId, vendor]);
  }

  Future<List<String>> getDistinctBanners(int projectId) async {
    if (kIsWeb) {
      return await ApiDatabaseHelper().getDistinctBanners(projectId);
    }
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
  }

  Future<List<Map<String, dynamic>>> getDevicesByBanner(int projectId, String banner) async {
    if (kIsWeb) {
      return await ApiDatabaseHelper().searchDevices(projectId, 'BANNER', banner);
    }
    final db = await _dbConnection.database;
    return await db.rawQuery('''
      SELECT DISTINCT d.*
      FROM devices d
      JOIN nmap_hosts h ON d.id = h.device_id
      JOIN nmap_ports p ON h.id = p.host_id
      WHERE d.project_id = ?
        AND (p.product || ' ' || COALESCE(p.version, '')) = ?
      ORDER BY d.name ASC
    ''', [projectId, banner]);
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
      SELECT p.port
      FROM nmap_ports p
      JOIN nmap_hosts h ON p.host_id = h.id
      WHERE h.device_id = ?
        AND p.service_name LIKE '%telnet%'
        AND p.state = 'open'
      ORDER BY p.port ASC
    ''', [deviceId]);

    return results.map((r) => r['port'] as int).toList();
  }

  Future<String?> extractMacFromSnmpFindings(int deviceId) async {
    if (kIsWeb) {
      // For web, we would need an API endpoint, but for now return null
      return null;
    }

    try {
      final db = await _dbConnection.database;
      final findings = await db.query('snmp_findings',
        where: 'device_id = ? AND finding_type = ?',
        whereArgs: [deviceId, 'System Information'],
      );

      if (findings.isEmpty) return null;

      // Simplified regex patterns for Dart compatibility
      // Match MAC addresses in various formats
      final macRegexColonDash = RegExp(
        r'[0-9A-Fa-f]{2}[:\-][0-9A-Fa-f]{2}[:\-][0-9A-Fa-f]{2}[:\-][0-9A-Fa-f]{2}[:\-][0-9A-Fa-f]{2}[:\-][0-9A-Fa-f]{2}',
      );
      final macRegexContinuous = RegExp(
        r'[0-9A-Fa-f]{12}',
      );
      final macRegexSpaces = RegExp(
        r'[0-9A-Fa-f]{2}\s+[0-9A-Fa-f]{2}\s+[0-9A-Fa-f]{2}\s+[0-9A-Fa-f]{2}\s+[0-9A-Fa-f]{2}\s+[0-9A-Fa-f]{2}',
      );

      for (final finding in findings) {
        final findingValue = finding['finding_value'] as String?;
        if (findingValue != null) {
          // Try colon/dash separated format first (most common)
          var match = macRegexColonDash.firstMatch(findingValue);
          if (match != null) {
            return match.group(0);
          }

          // Try space-separated format
          match = macRegexSpaces.firstMatch(findingValue);
          if (match != null) {
            return match.group(0);
          }

          // Try continuous 12 hex chars (but validate it's actually a MAC)
          match = macRegexContinuous.firstMatch(findingValue);
          if (match != null) {
            final macAddress = match.group(0);
            // Only accept if it's not all the same character (to avoid false positives)
            if (macAddress != null && !RegExp(r'^(.)\1+$').hasMatch(macAddress)) {
              return macAddress;
            }
          }
        }
      }

      return null;
    } catch (e, stackTrace) {
      debugPrint('Error in extractMacFromSnmpFindings: $e');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  Future<void> updateMacAddressInNmapHosts(int deviceId, String macAddress) async {
    if (kIsWeb) {
      // For web, we would need an API endpoint
      return;
    }

    try {
      final db = await _dbConnection.database;

      // Check if a record exists first
      final existingHosts = await db.query('nmap_hosts',
        where: 'device_id = ?',
        whereArgs: [deviceId],
      );

      if (existingHosts.isNotEmpty) {
        // Update existing record
        await db.rawUpdate('''
          UPDATE nmap_hosts
          SET mac_address = ?
          WHERE device_id = ?
        ''', [macAddress, deviceId]);
      }
    } catch (e, stackTrace) {
      debugPrint('Error updating MAC address in nmap_hosts: $e');
      debugPrint('Stack trace: $stackTrace');
      // Don't rethrow - we want to continue loading even if update fails
    }
  }
}
