import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:penpeeper/services/app_paths_service.dart';

class FileExtractor {
  Future<void> extractUploadFiles(Archive archive, String projectName) async {
    if (kIsWeb) return;

    // Ensure project uploads directory exists
    await AppPathsService().ensureProjectUploadsDir(projectName);
    final uploadsDir = AppPathsService().getProjectUploadsDir(projectName);

    for (final file in archive.files) {
      if (file.isFile && file.name.contains('/uploads/')) {
        final fileName = file.name.split('/').last;
        final destFile = File('$uploadsDir/$fileName');
        await destFile.writeAsBytes(file.content as List<int>);
      }
    }
  }
}
