class Tag {
  final int id;
  final String name;

  Tag({
    required this.id,
    required this.name,
  });

  factory Tag.fromMap(Map<String, dynamic> map) {
    return Tag(
      id: map['id'] as int,
      name: map['name'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }
}

class DeviceTag {
  final int id;
  final int deviceId;
  final int tagId;

  DeviceTag({
    required this.id,
    required this.deviceId,
    required this.tagId,
  });

  factory DeviceTag.fromMap(Map<String, dynamic> map) {
    return DeviceTag(
      id: map['id'] as int,
      deviceId: map['device_id'] as int,
      tagId: map['tag_id'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'device_id': deviceId,
      'tag_id': tagId,
    };
  }
}
