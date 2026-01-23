import 'dart:convert';
import 'package:shelf/shelf.dart' as shelf;
import 'package:penpeeper/repositories/device_repository.dart';
import 'package:penpeeper/repositories/scan_repository.dart';
import 'package:penpeeper/repositories/tag_repository.dart';
import 'package:penpeeper/repositories/metadata_repository.dart';
import 'package:penpeeper/repositories/findings_repository.dart';
import 'package:penpeeper/repositories/findings_data_repository.dart';
import 'package:penpeeper/repositories/vulnerability_repository.dart';

class DeviceRoutes {
  static Future<shelf.Response?> handle(
    shelf.Request request,
    List<String> parts,
  ) async {
    if (parts.isEmpty) return null;

    final deviceId = int.tryParse(parts[0]);
    if (deviceId == null) return null;

    final deviceRepository = DeviceRepository();
    final scanRepository = ScanRepository();
    final tagRepository = TagRepository();
    final metadataRepository = MetadataRepository();
    final findingsRepository = FindingsRepository();
    final findingsDataRepository = FindingsDataRepository();

    // GET /api/devices/:id
    if (parts.length == 1 && request.method == 'GET') {
      final device = await deviceRepository.getDeviceById(deviceId);
      return _jsonResponse(device?.toMap() ?? {});
    }

    // GET /api/devices/:id/scans
    if (parts.length == 2 && parts[1] == 'scans' && request.method == 'GET') {
      final scans = await scanRepository.getScansRaw(deviceId);
      return _jsonResponse(scans);
    }

    // POST /api/devices/:id/scans
    if (parts.length == 2 && parts[1] == 'scans' && request.method == 'POST') {
      final body = json.decode(await request.readAsString());
      final scanName = body['name'] as String;
      final scanData = body['data'] as String;
      await scanRepository.insertScan(deviceId, scanName, scanData);
      return _jsonResponse({'success': true});
    }

    // GET /api/devices/:id/details
    if (parts.length == 2 && parts[1] == 'details' && request.method == 'GET') {
      final details = await deviceRepository.getDeviceDetails(deviceId);
      return _jsonResponse(details);
    }

    // GET /api/devices/:id/ai-data
    if (parts.length == 2 && parts[1] == 'ai-data' && request.method == 'GET') {
      final projectId = int.tryParse(request.url.queryParameters['projectId'] ?? '');
      if (projectId == null) {
        return shelf.Response(400, body: json.encode({'error': 'projectId required'}));
      }
      final device = await deviceRepository.getDevice(deviceId);
      final ports = await metadataRepository.getNmapPorts(deviceId);
      final scripts = await metadataRepository.getNmapScripts(deviceId);
      final scans = await scanRepository.getScansForDevice(deviceId);
      return _jsonResponse({
        'device': device,
        'ports': ports,
        'scripts': scripts,
        'scans': scans,
      });
    }

    // GET /api/devices/:id/findings
    if (parts.length == 2 && parts[1] == 'findings' && request.method == 'GET') {
      final findings = await findingsRepository.getFlaggedFindingsForDevice(
        deviceId,
      );
      return _jsonResponse(findings.map((f) => f.toMap()).toList());
    }

    // GET /api/devices/:id/samba-ldap-findings
    if (parts.length == 2 && parts[1] == 'samba-ldap-findings' && request.method == 'GET') {
      final findings = await findingsDataRepository.getSambaLdapFindings(deviceId);
      return _jsonResponse(findings);
    }

    // GET /api/devices/:id/tags
    if (parts.length == 2 && parts[1] == 'tags' && request.method == 'GET') {
      final tags = await tagRepository.getDeviceTags(deviceId);
      return _jsonResponse(tags);
    }

    // POST /api/devices/:id/tags
    if (parts.length == 2 && parts[1] == 'tags' && request.method == 'POST') {
      final body = json.decode(await request.readAsString());
      await tagRepository.addDeviceTag(deviceId, body['tag']);
      return _jsonResponse({'success': true});
    }

    // DELETE /api/devices/:id/tags/:tag
    if (parts.length == 3 &&
        parts[1] == 'tags' &&
        request.method == 'DELETE') {
      final tag = Uri.decodeComponent(parts[2]);
      await tagRepository.removeDeviceTag(deviceId, tag);
      return _jsonResponse({'success': true});
    }

    // GET /api/devices/:id/records/:scanType
    if (parts.length == 3 &&
        parts[1] == 'records' &&
        request.method == 'GET') {
      final scanType = parts[2];
      final records = await _getDeviceRecords(
        deviceId,
        scanType,
        findingsDataRepository,
        deviceRepository,
      );
      return _jsonResponse(records);
    }

    // GET /api/devices/:id/telnet-ports
    if (parts.length == 2 &&
        parts[1] == 'telnet-ports' &&
        request.method == 'GET') {
      final ports = await deviceRepository.getTelnetPorts(deviceId);
      return _jsonResponse(ports);
    }

    // GET /api/devices/:id/data/:section
    if (parts.length == 3 &&
        parts[1] == 'data' &&
        request.method == 'GET') {
      final section = parts[2];
      final data = await deviceRepository.getDeviceData(deviceId, section);
      return _jsonResponse({'data': data});
    }

    // POST /api/devices/:id/data/:section
    if (parts.length == 3 &&
        parts[1] == 'data' &&
        request.method == 'POST') {
      final section = parts[2];
      final body = json.decode(await request.readAsString());
      await deviceRepository.saveDeviceData(deviceId, section, body['content']);
      return _jsonResponse({'success': true});
    }

    // PUT /api/devices/:id/icon
    if (parts.length == 2 && parts[1] == 'icon' && request.method == 'PUT') {
      final body = json.decode(await request.readAsString());
      await deviceRepository.updateDeviceIcon(deviceId, body['icon_type']);
      return _jsonResponse({'success': true});
    }

    // PUT /api/devices/:id/move
    if (parts.length == 2 && parts[1] == 'move' && request.method == 'PUT') {
      final body = json.decode(await request.readAsString());
      final newProjectId = body['project_id'] as int;
      await deviceRepository.moveDeviceToProject(deviceId, newProjectId);
      return _jsonResponse({'success': true});
    }

    // DELETE /api/devices/:id
    if (parts.length == 1 && request.method == 'DELETE') {
      await deviceRepository.deleteDevice(deviceId);
      return _jsonResponse({'success': true});
    }

    return null;
  }

  static Future<List<Map<String, dynamic>>> _getDeviceRecords(
    int deviceId,
    String scanType,
    FindingsDataRepository findingsDataRepo,
    DeviceRepository deviceRepo,
  ) async {
    switch (scanType) {
      case 'FFUF':
        return await findingsDataRepo.getFfufFindings(deviceId);
      case 'SAMBA':
        return await findingsDataRepo.getSambaLdapFindings(deviceId);
      case 'WhatWeb':
        return await findingsDataRepo.getWhatwebFindings(deviceId);
      case 'SearchSploit':
        final vulnRepo = VulnerabilityRepository();
        return await vulnRepo.getVulnerabilities(deviceId, 'SearchSploit');
      case 'Vulners':
        final details = await deviceRepo.getDeviceDetails(deviceId);
        return List<Map<String, dynamic>>.from(details['cves'] ?? []);
      default:
        return [];
    }
  }

  static shelf.Response _jsonResponse(dynamic data) {
    return shelf.Response.ok(
      json.encode(data),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
