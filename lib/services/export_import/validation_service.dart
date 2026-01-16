class ValidationService {
  ValidationResult validateArchiveStructure(Map<String, dynamic> metadata, List<Map<String, dynamic>> projects) {
    final errors = <String>[];
    final warnings = <String>[];

    if (!metadata.containsKey('version')) {
      errors.add('Missing version field');
    } else if (metadata['version'] != '1.0') {
      errors.add('Unsupported version: ${metadata['version']}');
    }

    if (!metadata.containsKey('exportedAt')) {
      errors.add('Missing exportedAt field');
    } else {
      try {
        DateTime.parse(metadata['exportedAt']);
      } catch (e) {
        errors.add('Invalid exportedAt date format');
      }
    }

    if (!metadata.containsKey('projects') || metadata['projects'] is! List) {
      errors.add('Missing or invalid projects list');
    } else if ((metadata['projects'] as List).length != projects.length) {
      warnings.add('Project count mismatch: expected ${(metadata['projects'] as List).length}, found ${projects.length}');
    }

    return ValidationResult(errors.isEmpty, errors, warnings);
  }

  ValidationResult validateProjectData(Map<String, dynamic> project) {
    final errors = <String>[];
    final warnings = <String>[];

    if (project['name'] == null || (project['name'] as String).isEmpty) {
      errors.add('Project name is required');
    } else if ((project['name'] as String).length > 255) {
      errors.add('Project name exceeds 255 characters');
    }

    if (project['created_at'] != null) {
      try {
        DateTime.parse(project['created_at']);
      } catch (e) {
        errors.add('Invalid created_at date format');
      }
    }

    if (project['updated_at'] != null) {
      try {
        DateTime.parse(project['updated_at']);
      } catch (e) {
        errors.add('Invalid updated_at date format');
      }
    }

    final devices = project['devices'] as List?;
    if (devices != null) {
      for (var i = 0; i < devices.length; i++) {
        final device = devices[i] as Map<String, dynamic>;
        if (device['name'] == null || (device['name'] as String).isEmpty) {
          errors.add('Device $i: name is required');
        }
        if (device['ip_address'] != null && (device['ip_address'] as String).isNotEmpty) {
          if (!_isValidIP(device['ip_address'])) {
            warnings.add('Device $i: invalid IP address format');
          }
        }
      }
    }

    final findings = project['findings'] as List?;
    if (findings != null) {
      for (var i = 0; i < findings.length; i++) {
        final finding = findings[i] as Map<String, dynamic>;
        if (finding['cvss_base_score'] != null) {
          final score = finding['cvss_base_score'];
          if (score is num && (score < 0.0 || score > 10.0)) {
            errors.add('Finding $i: CVSS score must be between 0.0 and 10.0');
          }
        }
      }
    }

    return ValidationResult(errors.isEmpty, errors, warnings);
  }

  List<String> validateForeignKeys(Map<String, dynamic> project) {
    final errors = <String>[];
    final deviceIds = <int>{};
    final hostIds = <int>{};
    final portIds = <int>{};
    final scanIds = <int>{};
    final findingIds = <int>{};

    final devices = project['devices'] as List?;
    if (devices != null) {
      for (var device in devices) {
        if (device['id'] != null) deviceIds.add(device['id']);
      }
    }

    final hosts = project['nmap_hosts'] as List?;
    if (hosts != null) {
      for (var host in hosts) {
        if (host['id'] != null) hostIds.add(host['id']);
        if (host['device_id'] != null && !deviceIds.contains(host['device_id'])) {
          errors.add('Host ${host['id']}: references non-existent device ${host['device_id']}');
        }
      }
    }

    final ports = project['nmap_ports'] as List?;
    if (ports != null) {
      for (var port in ports) {
        if (port['id'] != null) portIds.add(port['id']);
        if (port['host_id'] != null && !hostIds.contains(port['host_id'])) {
          errors.add('Port ${port['id']}: references non-existent host ${port['host_id']}');
        }
      }
    }

    final scripts = project['nmap_scripts'] as List?;
    if (scripts != null) {
      for (var script in scripts) {
        if (script['port_id'] != null && !portIds.contains(script['port_id'])) {
          errors.add('Script ${script['id']}: references non-existent port ${script['port_id']}');
        }
      }
    }

    final scans = project['scans'] as List?;
    if (scans != null) {
      for (var scan in scans) {
        if (scan['id'] != null) scanIds.add(scan['id']);
        if (scan['device_id'] != null && !deviceIds.contains(scan['device_id'])) {
          errors.add('Scan ${scan['id']}: references non-existent device ${scan['device_id']}');
        }
      }
    }

    final findings = project['findings'] as List?;
    if (findings != null) {
      for (var finding in findings) {
        if (finding['id'] != null) findingIds.add(finding['id']);
        // Skip validation for device_id = 0 (non-device findings)
        if (finding['device_id'] != null && finding['device_id'] != 0 && !deviceIds.contains(finding['device_id'])) {
          errors.add('Finding ${finding['id']}: references non-existent device ${finding['device_id']}');
        }
      }
    }



    return errors;
  }

  bool validateFileReferences(Map<String, dynamic> project) {
    final uploadFiles = project['upload_files'] as List?;
    if (uploadFiles == null) return true;

    for (var file in uploadFiles) {
      final path = file['file_path'] as String?;
      if (path == null) continue;
      
      if (path.contains('..')) return false;
      if (path.startsWith('/') || path.startsWith('\\')) return false;
    }

    return true;
  }

  bool _isValidIP(String ip) {
    final parts = ip.split('.');
    if (parts.length != 4) return false;
    
    for (var part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) return false;
    }
    
    return true;
  }
}

class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  ValidationResult(this.isValid, this.errors, this.warnings);
}
