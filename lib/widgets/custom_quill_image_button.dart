import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:file_picker/file_picker.dart';
import 'package:penpeeper/services/image_manager.dart';
import 'package:penpeeper/utils/image_path_helper.dart';

class CustomQuillImageButton extends StatelessWidget {
  final QuillController controller;
  final String projectName;

  const CustomQuillImageButton({
    super.key,
    required this.controller,
    required this.projectName,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.image),
      tooltip: 'Insert Image',
      onPressed: () => _insertImage(context),
    );
  }

  Future<void> _insertImage(BuildContext context) async {
    try {
      debugPrint('🖼️  Opening file picker for image selection...');

      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
      );

      if (result == null) {
        debugPrint('❌ File picker canceled by user');
        return;
      }

      final file = result.files.single;
      debugPrint('✓ File selected: ${file.name}');
      debugPrint('  - Path: ${file.path}');
      debugPrint('  - Bytes: ${file.bytes?.length ?? 'null'}');
      debugPrint('  - Size: ${file.size}');

      String? copiedPath;

      // On web, always use bytes. On desktop, use path
      if (kIsWeb) {
        debugPrint('Using file bytes (web mode)');
        copiedPath = await ImageManager.copyImageToProjectFolder(
          sourcePath: file.name,
          projectName: projectName,
          bytes: file.bytes,
        );
      } else if (file.path != null) {
        debugPrint('Using file path (desktop mode)');
        copiedPath = await ImageManager.copyImageToProjectFolder(
          sourcePath: file.path!,
          projectName: projectName,
          bytes: null,
        );
      } else {
        debugPrint('❌ No path or bytes available from file picker');
        throw Exception('Could not access file data');
      }

      debugPrint('✓ Image copied to: $copiedPath');

      // Convert to absolute URL for web platform
      final imagePath = kIsWeb 
          ? ImagePathHelper.resolveImagePath(copiedPath)
          : copiedPath;
      debugPrint('✓ Final image path for editor: $imagePath');

      final index = controller.selection.baseOffset;
      final length = controller.selection.extentOffset - index;

      controller.replaceText(
        index,
        length,
        BlockEmbed.image(imagePath),
        null,
      );

      debugPrint('✅ Image inserted successfully into editor');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image inserted successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e, stack) {
      debugPrint('❌ Failed to insert image: $e');
      debugPrint('Stack trace: $stack');

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to insert image: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }
}