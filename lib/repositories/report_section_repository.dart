import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:penpeeper/database_helper.dart';
import 'package:penpeeper/models/report_section.dart';
import 'package:penpeeper/api_database_helper.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ReportSectionRepository {
  final DatabaseHelper _db = DatabaseHelper();

  Future<ReportSection?> getReportSection(int projectId, String sectionType) async {
    if (kIsWeb) {
      return await ApiDatabaseHelper().getReportSection(projectId, sectionType);
    }
    final db = await _db.database;
    final results = await db.query(
      'report_sections',
      where: 'project_id = ? AND section_type = ?',
      whereArgs: [projectId, sectionType],
      limit: 1,
    );
    return results.isNotEmpty ? ReportSection.fromMap(results.first) : null;
  }

  Future<void> saveReportSection(ReportSection section) async {
    if (kIsWeb) {
      await ApiDatabaseHelper().saveReportSection(section);
      return;
    }
    final db = await _db.database;
    final map = section.toMap();
    map.remove('id');
    
    await db.insert(
      'report_sections',
      map,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ReportSection>> getAllReportSections(int projectId) async {
    if (kIsWeb) {
      return await ApiDatabaseHelper().getAllReportSections(projectId);
    }
    final db = await _db.database;
    final results = await db.query(
      'report_sections',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'section_type ASC',
    );
    return results.map((map) => ReportSection.fromMap(map)).toList();
  }

  Future<Map<String, dynamic>?> getReportSectionRaw(int projectId, String sectionType) async {
    final db = await _db.database;
    final results = await db.query(
      'report_sections',
      where: 'project_id = ? AND section_type = ?',
      whereArgs: [projectId, sectionType],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> saveReportSectionRaw(int projectId, String sectionType, String content) async {
    final db = await _db.database;
    await db.insert(
      'report_sections',
      {
        'project_id': projectId,
        'section_type': sectionType,
        'content': content,
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getAllReportSectionsRaw(int projectId) async {
    final db = await _db.database;
    return await db.query(
      'report_sections',
      where: 'project_id = ?',
      whereArgs: [projectId],
      orderBy: 'section_type ASC',
    );
  }
}
