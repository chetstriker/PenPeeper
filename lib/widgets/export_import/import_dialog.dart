import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:penpeeper/services/export_import/import_service.dart';
import 'package:penpeeper/services/export_import/archive_service.dart';
import 'package:penpeeper/services/export_import/conflict_resolver.dart';
import 'package:penpeeper/widgets/export_import/password_input_dialog.dart';
import 'package:penpeeper/widgets/export_import/conflict_resolution_dialog.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:typed_data';

class ImportDialog extends StatefulWidget {
  final Function() onImportComplete;

  const ImportDialog({super.key, required this.onImportComplete});

  @override
  State<ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<ImportDialog> {
  String? _selectedFilePath;
  Uint8List? _selectedFileBytes;
  String? _selectedFileName;
  bool _isImporting = false;

  Future<void> _selectFile() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: 'Select Import Archive',
      type: FileType.custom,
      allowedExtensions: ['pp'],
    );

    if (result != null) {
      if (kIsWeb) {
        // Web: Store file bytes
        setState(() {
          _selectedFileBytes = result.files.single.bytes;
          _selectedFileName = result.files.single.name;
          _selectedFilePath = null;
        });
      } else {
        // Desktop: Store file path
        if (result.files.single.path != null) {
          setState(() {
            _selectedFilePath = result.files.single.path;
            _selectedFileBytes = null;
            _selectedFileName = null;
          });
        }
      }
    }
  }

  Future<void> _showPasswordDialog() async {
    final password = await showDialog<String>(
      context: context,
      builder: (context) => const PasswordInputDialog(
        title: 'Enter Import Password',
        requireConfirmation: false,
      ),
    );

    if (password != null && mounted) {
      await _performImport(password);
    }
  }

  Future<void> _performImport(String password) async {
    setState(() => _isImporting = true);

    try {
      if (kIsWeb) {
        // Web: Use API endpoint
        if (_selectedFileBytes == null) {
          throw Exception('No file selected');
        }

        // First, upload file and check for conflicts
        final uri = Uri.parse('/api/import?password=${Uri.encodeComponent(password)}');
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/octet-stream'},
          body: _selectedFileBytes,
        );

        if (response.statusCode == 200) {
          final result = json.decode(response.body);
          final conflicts = result['conflicts'] as List;
          final sessionId = result['sessionId'] as String;

          if (conflicts.isNotEmpty && mounted) {
            // Show conflict resolution dialog
            final conflictObjects = conflicts.map((c) => ProjectConflict(
              projectName: c['projectName'],
              existingProjectId: c['existingProjectId'],
              existingUpdatedAt: DateTime.parse(c['existingUpdatedAt']),
              importUpdatedAt: DateTime.parse(c['importUpdatedAt']),
            )).toList();

            final resolutions = await showDialog<Map<String, ConflictResolution>>(
              context: context,
              builder: (context) => ConflictResolutionDialog(conflicts: conflictObjects),
            );

            if (resolutions == null) {
              setState(() => _isImporting = false);
              return;
            }

            // Send resolutions to server
            final confirmResponse = await http.post(
              Uri.parse('/api/import/confirm'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'sessionId': sessionId,
                'resolutions': resolutions.map((k, v) => MapEntry(k, v.toString().split('.').last)),
              }),
            );

            if (confirmResponse.statusCode == 200) {
              final confirmResult = json.decode(confirmResponse.body);
              final importResult = ImportResult(
                success: confirmResult['success'],
                importedProjects: List<String>.from(confirmResult['importedProjects']),
                errors: List<String>.from(confirmResult['errors']),
                totalProjects: confirmResult['totalProjects'],
              );
              if (mounted) {
                _showResult(importResult);
              }
            } else {
              throw Exception('Import confirmation failed: ${confirmResponse.statusCode}');
            }
          } else {
            // No conflicts, import directly
            final confirmResponse = await http.post(
              Uri.parse('/api/import/confirm'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'sessionId': sessionId,
                'resolutions': <String, String>{},
              }),
            );

            if (confirmResponse.statusCode == 200) {
              final confirmResult = json.decode(confirmResponse.body);
              final importResult = ImportResult(
                success: confirmResult['success'],
                importedProjects: List<String>.from(confirmResult['importedProjects']),
                errors: List<String>.from(confirmResult['errors']),
                totalProjects: confirmResult['totalProjects'],
              );
              if (mounted) {
                _showResult(importResult);
              }
            } else {
              throw Exception('Import failed: ${confirmResponse.statusCode}');
            }
          }
        } else {
          throw Exception('Import failed: ${response.statusCode}');
        }
      } else {
        // Desktop: Use local services
        final importService = ImportService();
        final file = File(_selectedFilePath!);
        final archiveData = await file.readAsBytes();

        final archiveService = ArchiveService();
        final exportData = await archiveService.extractArchive(archiveData, password);
        final conflicts = await importService.detectConflicts(exportData);

        if (conflicts.isNotEmpty && mounted) {
          final resolutions = await showDialog<Map<String, ConflictResolution>>(
            context: context,
            builder: (context) => ConflictResolutionDialog(conflicts: conflicts),
          );

          if (resolutions == null) {
            setState(() => _isImporting = false);
            return;
          }

          // Import with resolutions
          final result = await importService.importProjects(exportData, resolutions, archiveData, password);
          if (mounted) {
            _showResult(result);
          }
        } else {
          final result = await importService.importArchiveWithPath(_selectedFilePath!, password);
          if (mounted) {
            _showResult(result);
          }
        }
      }
    } catch (e, stack) {
      debugPrint('=== IMPORT ERROR ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace:');
      debugPrint(stack.toString());
      debugPrint('===================');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Import failed: ${e.toString().contains('Invalid') ? 'Wrong password or corrupted file' : e}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isImporting = false);
      }
    }
  }

  void _showResult(ImportResult result) {
    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Successfully imported ${result.importedProjects.length} projects')),
      );
      widget.onImportComplete();
      Navigator.of(context).pop();
    } else {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Completed with Errors'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (result.importedProjects.isNotEmpty) ...[
                const Text('Imported:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...result.importedProjects.map((p) => Text('• $p')),
                const SizedBox(height: 8),
              ],
              if (result.errors.isNotEmpty) ...[
                const Text('Errors:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                ...result.errors.map((e) => Text('• $e', style: const TextStyle(color: Colors.red))),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                if (result.importedProjects.isNotEmpty) {
                  widget.onImportComplete();
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import Projects'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Select a .pp archive file to import:'),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isImporting ? null : _selectFile,
            icon: const Icon(Icons.folder_open),
            label: const Text('Select File'),
          ),
          if (_selectedFilePath != null || _selectedFileName != null) ...[
            const SizedBox(height: 16),
            Text(
              kIsWeb ? _selectedFileName! : _selectedFilePath!.split(Platform.pathSeparator).last,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isImporting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isImporting || (_selectedFilePath == null && _selectedFileBytes == null) ? null : _showPasswordDialog,
          child: _isImporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Import'),
        ),
      ],
    );
  }
}
