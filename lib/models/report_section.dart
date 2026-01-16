class ReportSection {
  final int? id;
  final int projectId;
  final String sectionType;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReportSection({
    this.id,
    required this.projectId,
    required this.sectionType,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'project_id': projectId,
      'section_type': sectionType,
      'content': content,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  factory ReportSection.fromMap(Map<String, dynamic> map) {
    return ReportSection(
      id: map['id'] as int?,
      projectId: map['project_id'] as int,
      sectionType: map['section_type'] as String,
      content: map['content'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }
}
