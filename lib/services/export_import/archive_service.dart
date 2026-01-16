import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:penpeeper/models/export_data.dart';
import 'package:penpeeper/services/export_import/encryption_service.dart';
import 'package:penpeeper/services/app_paths_service.dart';

class ArchiveService {
  final EncryptionService _encryptionService = EncryptionService();

  Future<Uint8List> createArchive(
    ExportData exportData,
    String password,
  ) async {
    final archive = Archive();

    // Add metadata
    final metadataJson = jsonEncode({
      'version': exportData.version,
      'exportedAt': exportData.exportedAt.toIso8601String(),
      'projectCount': exportData.projects.length,
      'projects': exportData.projects.map((p) => p.project['name']).toList(),
    });
    final metadataBytes = utf8.encode(metadataJson);
    archive.addFile(
      ArchiveFile('metadata.json', metadataBytes.length, metadataBytes),
    );

    // Add each project
    for (final project in exportData.projects) {
      final projectName = project.project['name'] as String;
      final sanitizedName = projectName.replaceAll(RegExp(r'[^\w\s-]'), '_');

      // Add project data
      final dataJson = jsonEncode(project.toJson());
      final dataBytes = utf8.encode(dataJson);
      archive.addFile(
        ArchiveFile(
          'projects/$sanitizedName/data.json',
          dataBytes.length,
          dataBytes,
        ),
      );

      // Add upload files
      if (!kIsWeb) {
        await _addUploadFiles(archive, project, sanitizedName);
      }
    }

    // Compress
    final zipEncoder = ZipEncoder();
    final compressed = zipEncoder.encode(archive);

    // Encrypt
    final encrypted = await _encryptionService.encrypt(
      Uint8List.fromList(compressed),
      password,
    );

    return encrypted;
  }

  Future<ExportData> extractArchive(
    Uint8List archiveData,
    String password,
  ) async {
    // Decrypt
    final decrypted = await _encryptionService.decrypt(archiveData, password);

    // Decompress
    final archive = ZipDecoder().decodeBytes(decrypted);

    // Read metadata
    final metadataFile = archive.findFile('metadata.json');
    if (metadataFile == null) {
      throw Exception('Invalid archive: missing metadata');
    }
    final metadataContent = metadataFile.content as List<int>;
    final metadataJson = utf8.decode(metadataContent);
    final metadata = jsonDecode(metadataJson);

    // Read projects
    final projects = <ProjectExport>[];
    for (final projectName in metadata['projects']) {
      final sanitizedName = (projectName as String).replaceAll(
        RegExp(r'[^\w\s-]'),
        '_',
      );
      final dataFile = archive.findFile('projects/$sanitizedName/data.json');
      if (dataFile == null) continue;

      final dataContent = dataFile.content as List<int>;
      final dataJson = utf8.decode(dataContent);
      final projectData = jsonDecode(dataJson);
      projects.add(ProjectExport.fromJson(projectData));
    }

    return ExportData(
      projects: projects,
      version: metadata['version'],
      exportedAt: DateTime.parse(metadata['exportedAt']),
    );
  }

  Future<void> _addUploadFiles(
    Archive archive,
    ProjectExport project,
    String sanitizedName,
  ) async {
    debugPrint('Adding ${project.uploadFiles.length} files to archive');
    for (final filePath in project.uploadFiles) {
      // filePath is stored as relative path like "uploads/ProjectName/image.png"
      // We need to resolve it from app data directory
      // Convert forward slashes to platform-specific path separator
      final normalizedPath = filePath.replaceAll('/', path.separator);
      final absolutePath = path.join(AppPathsService().appDataDir, normalizedPath);
      final file = File(absolutePath);

      debugPrint('  Checking: $filePath');
      debugPrint('    Absolute: $absolutePath');

      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final fileName = filePath.replaceAll('\\', '/').split('/').last;
        final archivePath = 'projects/$sanitizedName/uploads/$fileName';

        archive.addFile(
          ArchiveFile(
            archivePath,
            bytes.length,
            bytes,
          ),
        );
        debugPrint('    ✅ Added to archive as: $archivePath');
      } else {
        debugPrint('    ❌ File not found on disk');
      }
    }
  }

  Future<Archive> extractUploadFiles(
    Uint8List archiveData,
    String password,
  ) async {
    final decrypted = await _encryptionService.decrypt(archiveData, password);
    return ZipDecoder().decodeBytes(decrypted);
  }
}
