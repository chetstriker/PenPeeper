import 'package:penpeeper/repositories/base_repository.dart';
import 'package:penpeeper/database/connection/database_connection.dart';
import 'package:penpeeper/api_database_helper.dart';
import 'package:penpeeper/services/project_data_cache.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class FindingsDataRepository extends BaseRepository {
  final _dbConnection = DatabaseConnection();

  Future<void> insertWhatwebFinding(int deviceId, String finding) async {
    final db = await _dbConnection.database;
    await db.insert('whatweb_findings', {
      'device_id': deviceId,
      'finding': finding,
      'created_at': DateTime.now().toIso8601String(),
    });

    final cache = ProjectDataCache();
    cache.addDeviceToScanType('WhatWeb', deviceId);
  }

  /// Batch insert WhatWeb findings in a single transaction to prevent database locking
  Future<void> batchInsertWhatwebFindings(int deviceId, List<String> findings) async {
    if (findings.isEmpty) return;

    final db = await _dbConnection.database;
    final batch = db.batch();

    for (final finding in findings) {
      batch.insert('whatweb_findings', {
        'device_id': deviceId,
        'finding': finding,
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    await batch.commit(noResult: true);

    final cache = ProjectDataCache();
    cache.addDeviceToScanType('WhatWeb', deviceId);
  }

  Future<void> deleteWhatwebFindings(int deviceId) async {
    final db = await _dbConnection.database;
    await db.delete('whatweb_findings',
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );
    
    final cache = ProjectDataCache();
    cache.removeDeviceFromScanType('WhatWeb', deviceId);
  }

  Future<List<Map<String, dynamic>>> getWhatwebFindings(int deviceId) async {
    final db = await _dbConnection.database;
    return await db.query('whatweb_findings',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'created_at DESC',
    );
  }

  Future<void> insertFfufFinding(int deviceId, String url, int status, int words) async {
    final db = await _dbConnection.database;
    await db.insert('ffuf_findings', {
      'device_id': deviceId,
      'url': url,
      'status': status,
      'words': words,
      'created_at': DateTime.now().toIso8601String(),
    });

    final cache = ProjectDataCache();
    cache.addDeviceToScanType('FFUF', deviceId);
  }

  /// Batch insert FFUF findings in a single transaction to prevent database locking
  Future<void> batchInsertFfufFindings(int deviceId, List<Map<String, dynamic>> findings) async {
    if (findings.isEmpty) return;

    final db = await _dbConnection.database;
    final batch = db.batch();

    for (final finding in findings) {
      batch.insert('ffuf_findings', {
        'device_id': deviceId,
        'url': finding['url'],
        'status': finding['status'],
        'words': finding['words'],
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    await batch.commit(noResult: true);

    final cache = ProjectDataCache();
    cache.addDeviceToScanType('FFUF', deviceId);
  }

  Future<void> deleteFfufFindings(int deviceId) async {
    final db = await _dbConnection.database;
    await db.delete('ffuf_findings',
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );
    
    final cache = ProjectDataCache();
    cache.removeDeviceFromScanType('FFUF', deviceId);
  }

  Future<List<Map<String, dynamic>>> getFfufFindings(int deviceId) async {
    final db = await _dbConnection.database;
    return await db.query('ffuf_findings',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'status ASC, url ASC',
    );
  }

  Future<void> insertSambaLdapFinding(int deviceId, String findingType, String findingValue) async {
    final db = await _dbConnection.database;
    await db.insert('samba_ldap_findings', {
      'device_id': deviceId,
      'finding_type': findingType,
      'finding_value': findingValue,
      'created_at': DateTime.now().toIso8601String(),
    });

    final cache = ProjectDataCache();
    cache.addDeviceToScanType('SAMBA', deviceId);
  }

  /// Batch insert Samba/LDAP findings in a single transaction to prevent database locking
  Future<void> batchInsertSambaLdapFindings(int deviceId, List<Map<String, String>> findings) async {
    if (findings.isEmpty) return;

    final db = await _dbConnection.database;
    final batch = db.batch();

    for (final finding in findings) {
      batch.insert('samba_ldap_findings', {
        'device_id': deviceId,
        'finding_type': finding['type'],
        'finding_value': finding['value'],
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    await batch.commit(noResult: true);

    final cache = ProjectDataCache();
    cache.addDeviceToScanType('SAMBA', deviceId);
  }

  Future<void> deleteSambaLdapFindings(int deviceId) async {
    final db = await _dbConnection.database;
    await db.delete('samba_ldap_findings',
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );
    
    final cache = ProjectDataCache();
    cache.removeDeviceFromScanType('SAMBA', deviceId);
  }

  Future<List<Map<String, dynamic>>> getSambaLdapFindings(int deviceId) async {
    final db = await _dbConnection.database;
    return await db.query('samba_ldap_findings',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'created_at DESC',
    );
  }

  Future<String?> getFqdnForDevice(int deviceId) async {
    if (kIsWeb) {
      final findings = await ApiDatabaseHelper().getSambaLdapFindings(deviceId);
      final fqdnFinding = findings.where((f) => f['finding_type'] == 'FQDN').firstOrNull;
      final fqdn = fqdnFinding?['finding_value'] as String?;
      return (fqdn != null && fqdn.isNotEmpty) ? fqdn : null;
    }
    final db = await _dbConnection.database;
    final results = await db.query('samba_ldap_findings',
      where: 'device_id = ? AND finding_type = ?',
      whereArgs: [deviceId, 'FQDN'],
      limit: 1,
    );
    if (results.isEmpty) return null;
    final fqdn = results.first['finding_value'] as String?;
    return (fqdn != null && fqdn.isNotEmpty) ? fqdn : null;
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

  Future<Set<int>> getDevicesWithNiktoFindings(int projectId) async {
    if (kIsWeb) {
      return await ApiDatabaseHelper().getDevicesWithNiktoFindings(projectId);
    }
    final db = await _dbConnection.database;
    final results = await db.rawQuery('''
      SELECT DISTINCT d.id
      FROM devices d
      JOIN nikto_findings n ON d.id = n.device_id
      WHERE d.project_id = ?
    ''', [projectId]);
    return results.map((r) => r['id'] as int).toSet();
  }

  Future<Set<int>> getDevicesWithSnmpFindings(int projectId) async {
    if (kIsWeb) {
      return await ApiDatabaseHelper().getDevicesWithSnmpFindings(projectId);
    }
    final db = await _dbConnection.database;
    final results = await db.rawQuery('''
      SELECT DISTINCT d.id
      FROM devices d
      JOIN snmp_findings s ON d.id = s.device_id
      WHERE d.project_id = ?
    ''', [projectId]);
    return results.map((r) => r['id'] as int).toSet();
  }

  Future<Set<int>> getDevicesWithNmapScripts(int projectId) async {
    if (kIsWeb) {
      return await ApiDatabaseHelper().getDevicesWithNmapScripts(projectId);
    }
    final db = await _dbConnection.database;
    final results = await db.rawQuery('''
      SELECT DISTINCT d.id
      FROM devices d
      JOIN nmap_hosts h ON d.id = h.device_id
      JOIN nmap_ports p ON h.id = p.host_id
      JOIN nmap_scripts s ON p.id = s.port_id
      WHERE d.project_id = ?
        AND s.script_id != 'vulners'
        AND s.output IS NOT NULL
        AND s.output != ''
        AND s.output != 'Not Found'
        AND s.output NOT LIKE 'ERROR:%'
        AND s.output NOT LIKE 'Couldn''t determine%'
    ''', [projectId]);
    return results.map((r) => r['id'] as int).toSet();
  }

  Future<void> insertNiktoFinding(int deviceId, Map<String, String> finding) async {
    final db = await _dbConnection.database;
    await db.insert('nikto_findings', {
      'device_id': deviceId,
      'item_id': finding['item_id'],
      'description': finding['description'],
      'uri': finding['uri'],
      'namelink': finding['namelink'],
      'iplink': finding['iplink'],
      'references_data': finding['references'],
      'created_at': DateTime.now().toIso8601String(),
    });

    final cache = ProjectDataCache();
    cache.addDeviceToScanType('Nikto', deviceId);
  }

  /// Batch insert Nikto findings in a single transaction to prevent database locking
  Future<void> batchInsertNiktoFindings(int deviceId, List<Map<String, String>> findings) async {
    if (findings.isEmpty) return;

    final db = await _dbConnection.database;
    final batch = db.batch();

    for (final finding in findings) {
      batch.insert('nikto_findings', {
        'device_id': deviceId,
        'item_id': finding['item_id'],
        'description': finding['description'],
        'uri': finding['uri'],
        'namelink': finding['namelink'],
        'iplink': finding['iplink'],
        'references_data': finding['references'],
        'created_at': DateTime.now().toIso8601String(),
      });
    }

    await batch.commit(noResult: true);

    final cache = ProjectDataCache();
    cache.addDeviceToScanType('Nikto', deviceId);
  }

  Future<void> deleteNiktoFindings(int deviceId) async {
    final db = await _dbConnection.database;
    await db.delete('nikto_findings',
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );

    final cache = ProjectDataCache();
    cache.removeDeviceFromScanType('Nikto', deviceId);
  }

  Future<List<Map<String, dynamic>>> getNiktoFindings(int deviceId) async {
    final db = await _dbConnection.database;
    return await db.query('nikto_findings',
      where: 'device_id = ?',
      whereArgs: [deviceId],
      orderBy: 'created_at DESC',
    );
  }
}
