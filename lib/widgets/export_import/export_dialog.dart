import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:penpeeper/services/export_import/export_import_service.dart';
import 'package:penpeeper/services/export_import/archive_service.dart';
import 'package:penpeeper/widgets/export_import/project_selection_list.dart';
import 'package:penpeeper/widgets/export_import/password_input_dialog.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'dart:convert';

class ExportDialog extends StatefulWidget {
  final List<Map<String, dynamic>> projects;

  const ExportDialog({super.key, required this.projects});

  @override
  State<ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<ExportDialog> {
  final Set<int> _selectedProjectIds = {};
  bool _isExporting = false;

  void _toggleSelection(int id, bool selected) {
    setState(() {
      if (selected) {
        _selectedProjectIds.add(id);
      } else {
        _selectedProjectIds.remove(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      _selectedProjectIds.addAll(widget.projects.map((p) => p['id'] as int));
    });
  }

  void _deselectAll() {
    setState(() => _selectedProjectIds.clear());
  }

  Future<void> _showPasswordDialog() async {
    final password = await showDialog<String>(
      context: context,
      builder: (context) => const PasswordInputDialog(
        title: 'Set Export Password',
        requireConfirmation: true,
      ),
    );

    if (password != null && mounted) {
      await _performExport(password);
    }
  }

  Future<void> _performExport(String password) async {
    setState(() => _isExporting = true);

    try {
      if (kIsWeb) {
        // Web: Use API endpoint
        final response = await http.post(
          Uri.parse('/api/export'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'projectIds': _selectedProjectIds.toList(),
            'password': password,
          }),
        );

        if (response.statusCode == 200) {
          final bytes = response.bodyBytes;
          final defaultName = 'export_${DateTime.now().toIso8601String().split('T')[0]}.pp';
          
          final result = await FilePicker.platform.saveFile(
            dialogTitle: 'Save Export Archive',
            fileName: defaultName,
            bytes: bytes,
          );

          if (result != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Export completed successfully')),
            );
            Navigator.of(context).pop();
          }
        } else {
          throw Exception('Export failed: ${response.statusCode}');
        }
      } else {
        // Desktop: Use local services
        final exportService = ExportImportService();
        final archiveService = ArchiveService();

        final exportData = await exportService.exportProjects(_selectedProjectIds.toList());
        final archiveBytes = await archiveService.createArchive(exportData, password);

        final defaultName = 'export_${DateTime.now().toIso8601String().split('T')[0]}.pp';
        final outputPath = await FilePicker.platform.saveFile(
          dialogTitle: 'Save Export Archive',
          fileName: defaultName,
          type: FileType.custom,
          allowedExtensions: ['pp'],
        );

        if (outputPath != null && mounted) {
          final file = File(outputPath);
          await file.writeAsBytes(archiveBytes);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Exported to: $outputPath')),
            );
            Navigator.of(context).pop();
          }
        }
      }
    } catch (e, stack) {
      debugPrint('=== EXPORT ERROR ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace:');
      debugPrint(stack.toString());
      debugPrint('===================');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 10),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isExporting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export Projects'),
      content: SizedBox(
        width: 500,
        height: 400,
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: _selectAll,
                  child: const Text('Select All'),
                ),
                TextButton(
                  onPressed: _deselectAll,
                  child: const Text('Deselect All'),
                ),
              ],
            ),
            Expanded(
              child: ProjectSelectionList(
                projects: widget.projects,
                selectedIds: _selectedProjectIds,
                onSelectionChanged: _toggleSelection,
              ),
            ),
            const SizedBox(height: 8),
            Text('${_selectedProjectIds.length} projects selected'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isExporting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isExporting || _selectedProjectIds.isEmpty ? null : _showPasswordDialog,
          child: _isExporting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Export'),
        ),
      ],
    );
  }
}
