class Project {
  final int id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;

  Project({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Project.fromMap(Map<String, dynamic> map) {
    return Project(
      id: map['id'],
      name: map['name'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
    );
  }
}

class Device {
  final int id;
  final int projectId;
  final String name;
  final String ipAddress;
  final String? iconType;
  final String? macAddress;
  final String? vendor;

  Device({
    required this.id,
    required this.projectId,
    required this.name,
    required this.ipAddress,
    this.iconType,
    this.macAddress,
    this.vendor,
  });

  factory Device.fromMap(Map<String, dynamic> map) {
    return Device(
      id: map['id'],
      projectId: map['project_id'],
      name: map['name'],
      ipAddress: map['ip_address'],
      iconType: map['icon_type'],
      macAddress: map['mac_address'],
      vendor: map['vendor'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'project_id': projectId,
      'name': name,
      'ip_address': ipAddress,
      'icon_type': iconType,
      'mac_address': macAddress,
      'vendor': vendor,
    };
  }
}

class Scan {
  final int id;
  final int deviceId;
  final String scanType;
  final String result;
  final DateTime timestamp;

  Scan({
    required this.id,
    required this.deviceId,
    required this.scanType,
    required this.result,
    required this.timestamp,
  });

  factory Scan.fromMap(Map<String, dynamic> map) {
    return Scan(
      id: map['id'],
      deviceId: map['device_id'],
      scanType: map['name'],
      result: map['content'],
      timestamp: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'device_id': deviceId,
      'name': scanType,
      'content': result,
      'created_at': timestamp.toIso8601String(),
    };
  }
}

class FlaggedFinding {
  final int id;
  final int deviceId;
  final String deviceName;
  final String ipAddress;
  final String type;
  final String comment;
  final DateTime createdAt;

  FlaggedFinding({
    required this.id,
    required this.deviceId,
    required this.deviceName,
    required this.ipAddress,
    required this.type,
    required this.comment,
    required this.createdAt,
  });

  factory FlaggedFinding.fromMap(Map<String, dynamic> map) {
    return FlaggedFinding(
      id: map['id'],
      deviceId: map['device_id'],
      deviceName: map['device_name'],
      ipAddress: map['ip_address'],
      type: map['type'],
      comment: map['comment'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }
}

class CveAttached {
  final int id;
  final int deviceId;
  final int projectId;
  final String cveId;
  final String confidenceLevel;
  final String? description;
  final String? vulnerabilityType;
  final double? cvssScore;
  final String? url;
  final DateTime createdAt;

  CveAttached({
    required this.id,
    required this.deviceId,
    required this.projectId,
    required this.cveId,
    required this.confidenceLevel,
    this.description,
    this.vulnerabilityType,
    this.cvssScore,
    this.url,
    required this.createdAt,
  });

  factory CveAttached.fromMap(Map<String, dynamic> map) {
    return CveAttached(
      id: map['id'],
      deviceId: map['device_id'],
      projectId: map['project_id'],
      cveId: map['cve_id'],
      confidenceLevel: map['confidence_level'],
      description: map['description'],
      vulnerabilityType: map['vulnerability_type'],
      cvssScore: map['cvss_score'] != null ? (map['cvss_score'] as num).toDouble() : null,
      url: map['url'],
      createdAt: DateTime.parse(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'device_id': deviceId,
      'project_id': projectId,
      'cve_id': cveId,
      'confidence_level': confidenceLevel,
      'description': description,
      'vulnerability_type': vulnerabilityType,
      'cvss_score': cvssScore,
      'url': url,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
