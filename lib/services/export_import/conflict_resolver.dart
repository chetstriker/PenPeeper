import 'package:penpeeper/database_helper.dart';
import 'package:penpeeper/models/export_data.dart';

class ProjectConflict {
  final String projectName;
  final int existingProjectId;
  final DateTime existingUpdatedAt;
  final DateTime importUpdatedAt;

  ProjectConflict({
    required this.projectName,
    required this.existingProjectId,
    required this.existingUpdatedAt,
    required this.importUpdatedAt,
  });
}

enum ConflictResolution { cancel, replace, rename }

class ConflictResolver {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Future<List<ProjectConflict>> findConflicts(List<ProjectExport> projects) async {
    final conflicts = <ProjectConflict>[];

    for (final project in projects) {
      final projectName = project.project['name'] as String;
      final existing = await getExistingProject(projectName);

      if (existing != null) {
        conflicts.add(ProjectConflict(
          projectName: projectName,
          existingProjectId: existing['id'] as int,
          existingUpdatedAt: DateTime.parse(existing['updated_at'] as String),
          importUpdatedAt: DateTime.parse(project.project['updated_at'] as String),
        ));
      }
    }

    return conflicts;
  }

  Future<Map<String, dynamic>?> getExistingProject(String projectName) async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'projects',
      where: 'name = ?',
      whereArgs: [projectName],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  String generateUniqueName(String baseName) {
    var counter = 1;
    var newName = '$baseName ($counter)';
    return newName;
  }

  Future<String> generateUniqueNameAsync(String baseName) async {
    var counter = 1;
    var newName = '$baseName ($counter)';

    while (await getExistingProject(newName) != null) {
      counter++;
      newName = '$baseName ($counter)';
    }

    return newName;
  }
}
