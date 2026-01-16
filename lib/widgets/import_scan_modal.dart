import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;
import 'package:penpeeper/services/image_manager.dart';
import 'package:penpeeper/widgets/decorated_dialog_title.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class ImportScanModal extends StatefulWidget {
  final String projectName;

  const ImportScanModal({
    super.key,
    required this.projectName,
  });

  @override
  State<ImportScanModal> createState() => _ImportScanModalState();
}

class _ImportScanModalState extends State<ImportScanModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _selectedFileName;
  PlatformFile? _selectedFile;
  bool _isProcessing = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['txt', 'json', 'xml', 'png', 'jpg', 'jpeg'],
      allowMultiple: false,
    );

    if (result != null) {
      setState(() {
        _selectedFile = result.files.single;
        _selectedFileName = _selectedFile!.name;
      });
    }
  }

  Future<void> _processAndImport() async {
    if (!_formKey.currentState!.validate() || _selectedFile == null) {
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final name = _nameController.text;
      String content = '';
      final extension = _selectedFile!.extension?.toLowerCase();

      if (['txt', 'json', 'xml'].contains(extension)) {
        if (kIsWeb) {
           if (_selectedFile!.bytes != null) {
             content = utf8.decode(_selectedFile!.bytes!);
           } else {
             throw Exception('File content is empty');
           }
        } else {
          if (_selectedFile!.path != null) {
            content = await File(_selectedFile!.path!).readAsString();
          } else {
             throw Exception('File path is missing');
          }
        }
      } else if (['png', 'jpg', 'jpeg'].contains(extension)) {
        String? imagePath;
        
        if (extension == 'png') {
          if (kIsWeb) {
             // Web PNG upload
             imagePath = await ImageManager.copyImageToProjectFolder(
               sourcePath: _selectedFile!.name, // Use name as sourcePath for web fallback
               projectName: widget.projectName,
               bytes: _selectedFile!.bytes,
             );
          } else {
             // Desktop PNG copy
             if (_selectedFile!.path != null) {
               imagePath = await ImageManager.copyImageToProjectFolder(
                 sourcePath: _selectedFile!.path!,
                 projectName: widget.projectName,
               );
             }
          }
        } else {
          // JPG/JPEG conversion
          Uint8List? imageBytes;
          if (kIsWeb) {
            imageBytes = _selectedFile!.bytes;
          } else if (_selectedFile!.path != null) {
            imageBytes = await File(_selectedFile!.path!).readAsBytes();
          }

          if (imageBytes != null) {
            final image = img.decodeImage(imageBytes);
            if (image != null) {
              final pngBytes = img.encodePng(image);
              
              if (kIsWeb) {
                 imagePath = await ImageManager.copyImageToProjectFolder(
                   sourcePath: '${path.basenameWithoutExtension(_selectedFile!.name)}.png',
                   projectName: widget.projectName,
                   bytes: pngBytes,
                 );
              } else {
                 // Save to temp file for desktop ImageManager
                 final tempDir = Directory.systemTemp;
                 final tempFile = File(path.join(tempDir.path, 'temp_convert_${DateTime.now().millisecondsSinceEpoch}.png'));
                 await tempFile.writeAsBytes(pngBytes);
                 
                 imagePath = await ImageManager.copyImageToProjectFolder(
                   sourcePath: tempFile.path,
                   projectName: widget.projectName,
                 );
                 
                 try {
                   await tempFile.delete();
                 } catch (e) {
                   debugPrint('Failed to delete temp file: $e');
                 }
              }
            }
          }
        }

        if (imagePath != null) {
          content = '[{"insert":{"image":"$imagePath"}},{"insert":"\\n"}]';
        } else {
          throw Exception('Failed to process image');
        }
      }

      if (mounted) {
        Navigator.of(context).pop({'name': name, 'content': content});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 9, 24, 0),
      title: const DecoratedDialogTitle('Import Scan'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Scan Name',
                hintText: 'Enter scan name',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a scan name';
                }
                if (value.length < 4) {
                  return 'Name must be at least 4 characters';
                }
                final validCharacters = RegExp(r'^[a-zA-Z0-9 ._-]+$');
                if (!validCharacters.hasMatch(value)) {
                  return 'Only letters, numbers, spaces, dots, underscores, and hyphens allowed';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _pickFile,
                  child: const Text('Select File'),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedFileName ?? 'No file selected',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontStyle: _selectedFileName == null
                          ? FontStyle.italic
                          : FontStyle.normal,
                      color: _selectedFileName == null
                          ? Theme.of(context).disabledColor
                          : null,
                    ),
                  ),
                ),
              ],
            ),
            if (_selectedFile != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  'Type: ${_selectedFile!.extension?.toUpperCase()}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isProcessing ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: (_isProcessing || _selectedFile == null)
              ? null
              : _processAndImport,
          child: _isProcessing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Import'),
        ),
      ],
    );
  }
}
