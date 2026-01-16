import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:penpeeper/services/export_import/export_import_service.dart';
import 'package:penpeeper/services/export_import/archive_service.dart';

class ExportHandler {
  Future<Response> handleExport(Request request) async {
    try {
      final body = await request.readAsString();
      final json = jsonDecode(body);
      
      final projectIds = (json['projectIds'] as List).cast<int>();
      final password = json['password'] as String;
      
      final exportService = ExportImportService();
      final exportData = await exportService.exportProjects(projectIds);
      
      final archiveService = ArchiveService();
      final archiveBytes = await archiveService.createArchive(exportData, password);
      
      final filename = 'export_${DateTime.now().toIso8601String().split('T')[0]}.pp';
      
      return Response.ok(
        archiveBytes,
        headers: {
          'Content-Type': 'application/octet-stream',
          'Content-Disposition': 'attachment; filename="$filename"',
          'Access-Control-Allow-Origin': '*',
        },
      );
    } catch (e) {
      return Response.internalServerError(
        body: jsonEncode({'error': 'Export failed: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
