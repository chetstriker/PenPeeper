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
      id: map['id'] as int,
      projectId: map['project_id'] as int,
      name: map['name'] as String,
      ipAddress: map['ip_address'] as String,
      iconType: map['icon_type'] as String?,
      macAddress: map['mac_address'] as String?,
      vendor: map['vendor'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'project_id': projectId,
      'name': name,
      'ip_address': ipAddress,
      if (iconType != null) 'icon_type': iconType,
      if (macAddress != null) 'mac_address': macAddress,
      if (vendor != null) 'vendor': vendor,
    };
  }

  Map<String, dynamic> toJson() => toMap();
}
