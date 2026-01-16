import 'dart:convert';
import 'package:shelf/shelf.dart' as shelf;
import 'package:penpeeper/repositories/project_repository.dart';
import 'package:penpeeper/repositories/device_repository.dart';
import 'package:penpeeper/repositories/metadata_repository.dart';
import 'package:penpeeper/repositories/tag_repository.dart';
import 'package:penpeeper/repositories/findings_data_repository.dart';
import 'package:penpeeper/repositories/findings_repository.dart';

class ProjectRoutes {
  static Future<shelf.Response?> handle(
    shelf.Request request,
    List<String> parts,
  ) async {
    final projectRepository = ProjectRepository();
    final deviceRepository = DeviceRepository();
    final metadataRepository = MetadataRepository();
    final tagRepository = TagRepository();
    final findingsDataRepository = FindingsDataRepository();
    final findingsRepository = FindingsRepository();

    // GET /api/projects
    if (parts.isEmpty && request.method == 'GET') {
      final projects = await projectRepository.getProjectsRaw();
      return _jsonResponse(projects);
    }

    // POST /api/projects
    if (parts.isEmpty && request.method == 'POST') {
      final body = json.decode(await request.readAsString());
      final project = await projectRepository.insertProject(body['name']);
      return _jsonResponse({'id': project.id});
    }

    if (parts.isEmpty) return null;

    final projectId = int.tryParse(parts[0]);
    if (projectId == null) return null;

    // DELETE /api/projects/:id
    if (parts.length == 1 && request.method == 'DELETE') {
      await projectRepository.deleteProject(projectId);
      return _jsonResponse({'success': true});
    }

    // PUT /api/projects/:id (rename)
    if (parts.length == 1 && request.method == 'PUT') {
      final body = json.decode(await request.readAsString());
      final newName = body['name'] as String;
      await projectRepository.renameProject(projectId, newName);
      return _jsonResponse({'success': true});
    }

    if (parts.length < 2) return null;

    // GET /api/projects/:id/devices
    if (parts[1] == 'devices' && parts.length == 2 && request.method == 'GET') {
      final devices = await deviceRepository.getDevicesRaw(projectId);
      final deviceCount = await deviceRepository.getDeviceCount(projectId);
      return _jsonResponse({'devices': devices, 'count': deviceCount});
    }

    // POST /api/projects/:id/devices
    if (parts[1] == 'devices' && parts.length == 2 && request.method == 'POST') {
      final body = json.decode(await request.readAsString());
      final id = await deviceRepository.insertDevice(
        projectId,
        body['name'],
        body['ip_address'],
      );
      return _jsonResponse({'id': id});
    }

    // POST /api/projects/:id/metadata
    if (parts[1] == 'metadata' && request.method == 'POST') {
      final body = json.decode(await request.readAsString());
      final deviceIds = List<int>.from(body['device_ids']);
      final metadata = await metadataRepository.getBatchDeviceMetadata(
        projectId,
        deviceIds,
      );
      final stringKeyMetadata = metadata.map(
        (key, value) => MapEntry(key.toString(), value),
      );
      return _jsonResponse(stringKeyMetadata);
    }

    // GET /api/projects/:id/os-list
    if (parts[1] == 'os-list' && request.method == 'GET') {
      final osList = await metadataRepository.getDistinctOperatingSystems(
        projectId,
      );
      return _jsonResponse(osList);
    }

    // GET /api/projects/:id/vendors-list
    if (parts[1] == 'vendors-list' && request.method == 'GET') {
      final vendorsList = await metadataRepository.getDistinctMacVendors(
        projectId,
      );
      return _jsonResponse(vendorsList);
    }

    // GET /api/projects/:id/banners-list
    if (parts[1] == 'banners-list' && request.method == 'GET') {
      final bannersList = await metadataRepository.getDistinctBanners(projectId);
      return _jsonResponse(bannersList);
    }

    // GET /api/projects/:id/tags
    if (parts[1] == 'tags' && request.method == 'GET') {
      final tags = await tagRepository.getAllProjectTags(projectId);
      return _jsonResponse(tags);
    }

    // GET /api/projects/:id/devices/with-ffuf
    if (parts[1] == 'devices' &&
        parts.length == 3 &&
        parts[2] == 'with-ffuf' &&
        request.method == 'GET') {
      final deviceIds = await findingsDataRepository.getDevicesWithFfufFindings(
        projectId,
      );
      return _jsonResponse(deviceIds.toList());
    }

    // GET /api/projects/:id/devices/with-samba
    if (parts[1] == 'devices' &&
        parts.length == 3 &&
        parts[2] == 'with-samba' &&
        request.method == 'GET') {
      final deviceIds = await findingsDataRepository
          .getDevicesWithSambaLdapFindings(projectId);
      return _jsonResponse(deviceIds.toList());
    }

    // GET /api/projects/:id/devices/with-whatweb
    if (parts[1] == 'devices' &&
        parts.length == 3 &&
        parts[2] == 'with-whatweb' &&
        request.method == 'GET') {
      final deviceIds = await findingsDataRepository
          .getDevicesWithWhatWebFindings(projectId);
      return _jsonResponse(deviceIds.toList());
    }

    // GET /api/projects/:id/devices/with-searchsploit
    if (parts[1] == 'devices' &&
        parts.length == 3 &&
        parts[2] == 'with-searchsploit' &&
        request.method == 'GET') {
      final deviceIds = await findingsDataRepository
          .getDevicesWithSearchSploitFindings(projectId);
      return _jsonResponse(deviceIds.toList());
    }

    // GET /api/projects/:id/devices/with-vulners
    if (parts[1] == 'devices' &&
        parts.length == 3 &&
        parts[2] == 'with-vulners' &&
        request.method == 'GET') {
      final deviceIds = await findingsDataRepository.getDevicesWithVulnersCves(
        projectId,
      );
      return _jsonResponse(deviceIds.toList());
    }

    // GET /api/projects/:id/devices-with-nikto
    if (parts[1] == 'devices-with-nikto' &&
        parts.length == 2 &&
        request.method == 'GET') {
      final deviceIds = await findingsDataRepository.getDevicesWithNiktoFindings(
        projectId,
      );
      return _jsonResponse(deviceIds.toList());
    }

    // GET /api/projects/:id/devices-with-snmp
    if (parts[1] == 'devices-with-snmp' &&
        parts.length == 2 &&
        request.method == 'GET') {
      final deviceIds = await findingsDataRepository.getDevicesWithSnmpFindings(
        projectId,
      );
      return _jsonResponse(deviceIds.toList());
    }

    // GET /api/projects/:id/devices-with-nmap-scripts
    if (parts[1] == 'devices-with-nmap-scripts' &&
        parts.length == 2 &&
        request.method == 'GET') {
      final deviceIds = await findingsDataRepository.getDevicesWithNmapScripts(
        projectId,
      );
      return _jsonResponse(deviceIds.toList());
    }

    // GET /api/projects/:id/findings
    if (parts[1] == 'findings' &&
        parts.length == 2 &&
        request.method == 'GET') {
      final findings = await findingsRepository.getFlaggedFindings(projectId);
      return _jsonResponse(findings.map((f) => f.toMap()).toList());
    }

    return null;
  }

  static shelf.Response _jsonResponse(dynamic data) {
    return shelf.Response.ok(
      json.encode(data),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
