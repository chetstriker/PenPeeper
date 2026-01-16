import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import 'package:penpeeper/theme_config.dart';
import 'package:penpeeper/repositories/metadata_repository.dart';
import 'package:penpeeper/repositories/device_repository.dart';
import 'package:penpeeper/widgets/device_details_section.dart';
import 'package:penpeeper/models.dart';

class FindingsModalHelper {
  static Future<void> showRecordModal({
    required BuildContext context,
    required Map<String, dynamic> device,
    required String activeFilter,
    required MetadataRepository metadataRepo,
  }) async {
    final records = await _loadRecords(device, activeFilter, metadataRepo);

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$activeFilter Records - ${device['name']}'),
        content: SizedBox(
          width: 600,
          height: 400,
          child: ListView.builder(
            itemCount: records.length,
            itemBuilder: (context, index) => _buildRecordItem(records[index], activeFilter),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  static Future<List<Map<String, dynamic>>> _loadRecords(
    Map<String, dynamic> device,
    String activeFilter,
    MetadataRepository metadataRepo,
  ) async {
    if (kIsWeb) {
      try {
        final response = await http.get(
          Uri.parse('/api/devices/${device['id']}/records/$activeFilter'),
        );
        if (response.statusCode == 200) {
          return List<Map<String, dynamic>>.from(json.decode(response.body));
        }
      } catch (e) {
        return [];
      }
      return [];
    }

    final database = await metadataRepo.database;
    switch (activeFilter) {
      case 'FFUF':
        return await database.query(
          'ffuf_findings',
          where: 'device_id = ?',
          whereArgs: [device['id']],
          orderBy: 'words DESC',
        );
      case 'SAMBA':
        return await database.query(
          'samba_ldap_findings',
          where: 'device_id = ?',
          whereArgs: [device['id']],
          orderBy: 'created_at DESC',
        );
      case 'WhatWeb':
        return await database.query(
          'whatweb_findings',
          where: 'device_id = ?',
          whereArgs: [device['id']],
          orderBy: 'created_at DESC',
        );
      case 'SearchSploit':
        return await database.query(
          'vulnerabilities',
          where: 'device_id = ? AND type = ?',
          whereArgs: [device['id'], 'SearchSploit'],
          orderBy: 'created_at DESC',
        );
      case 'Nikto':
        return await database.query(
          'nikto_findings',
          where: 'device_id = ?',
          whereArgs: [device['id']],
          orderBy: 'created_at DESC',
        );
      case 'SNMP':
        return await database.query(
          'snmp_findings',
          where: 'device_id = ?',
          whereArgs: [device['id']],
          orderBy: 'id DESC',
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
          [device['id']],
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
          [device['id']],
        );
      default:
        return [];
    }
  }

  static Widget _buildRecordItem(Map<String, dynamic> record, String activeFilter) {
    switch (activeFilter) {
      case 'FFUF':
        return ListTile(
          title: InkWell(
            onTap: () async {
              final uri = Uri.parse(record['url']);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
              }
            },
            child: Text(
              record['url'],
              style: TextStyle(
                color: AppTheme.linkColor,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          subtitle: Text('Status: ${record['status']}, Words: ${record['words']}'),
        );
      case 'SAMBA':
        return ListTile(
          title: Text(record['finding_type']),
          subtitle: Text(record['finding_value']),
        );
      case 'WhatWeb':
        return ListTile(title: Text(record['finding']));
      case 'SearchSploit':
        return ListTile(
          title: Text(record['title']),
          subtitle: Text('Severity: ${record['severity']}'),
        );
      case 'Nikto':
        final description = record['description']?.toString() ?? '';
        final uri = record['uri']?.toString() ?? '';
        final namelink = record['namelink']?.toString() ?? '';
        final iplink = record['iplink']?.toString() ?? '';
        
        return ListTile(
          title: Text(description),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (uri.isNotEmpty)
                InkWell(
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
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              if (namelink.isNotEmpty && namelink != iplink)
                InkWell(
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
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
            ],
          ),
          isThreeLine: true,
        );
      case 'SNMP':
        return ListTile(
          title: Text(record['finding_type']?.toString() ?? 'SNMP Finding'),
          subtitle: Text(record['finding_value']?.toString() ?? ''),
        );
      case 'Nmap Scripts':
        final scriptId = record['script_id']?.toString() ?? 'unknown';
        final output = record['output']?.toString() ?? '';
        final port = record['port'];
        final protocol = record['protocol'] ?? 'tcp';
        final serviceName = record['service_name'] ?? '';
        return ListTile(
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  scriptId,
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (port != null)
                Text(
                  '$port/$protocol',
                  style: const TextStyle(fontSize: 12),
                ),
              if (serviceName.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  '($serviceName)',
                  style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
                ),
              ],
            ],
          ),
          subtitle: Text(
            output,
            style: const TextStyle(fontSize: 13),
          ),
          isThreeLine: true,
        );
      case 'Vulners':
        return ListTile(
          title: Text(record['cve_id']),
          subtitle: Text('CVSS: ${record['cvss']}'),
        );
      default:
        return const SizedBox();
    }
  }

  static Future<void> showDeviceInfo({
    required BuildContext context,
    required Map<String, dynamic> device,
    required int projectId,
    required DeviceRepository deviceRepo,
  }) async {
    String? iconType = device['icon_type'];

    if (kIsWeb) {
      try {
        final response = await http.get(Uri.parse('/api/devices/${device['id']}'));
        if (response.statusCode == 200) {
          final deviceData = json.decode(response.body);
          iconType = deviceData['icon_type'];
        }
      } catch (e) {
        // Use fallback icon_type
      }
    } else {
      final db = await deviceRepo.database;
      final result = await db.query(
        'devices',
        where: 'id = ?',
        whereArgs: [device['id']],
        limit: 1,
      );
      iconType = result.isNotEmpty ? result.first['icon_type'] as String? : device['icon_type'];
    }

    final deviceObj = Device(
      id: device['id'],
      projectId: projectId,
      name: device['name'],
      ipAddress: device['ip_address'],
      iconType: iconType,
    );

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Device Information - ${device['name']}'),
        content: SizedBox(
          width: 800,
          height: 600,
          child: DeviceDetailsSection(device: deviceObj),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
