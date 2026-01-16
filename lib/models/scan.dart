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
      id: map['id'] as int,
      deviceId: map['device_id'] as int,
      scanType: map['name'] as String,
      result: map['content'] as String,
      timestamp: DateTime.parse(map['created_at'] as String),
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

  Map<String, dynamic> toJson() => toMap();
}
