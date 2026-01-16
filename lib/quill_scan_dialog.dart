import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:penpeeper/theme_config.dart';
import 'package:penpeeper/widgets/gradient_border_container.dart';
import 'package:penpeeper/widgets/simple_quill_spell_checker.dart';
import 'package:penpeeper/widgets/custom_quill_image_button.dart';
import 'package:penpeeper/utils/image_path_helper.dart';
import 'package:penpeeper/utils/quill_embed_helper.dart';
import 'package:penpeeper/widgets/custom_image_embed_builder.dart';

class QuillScanDialog extends StatefulWidget {
  final String deviceName;
  final String? initialContent;
  final String? initialName;
  final bool isEditing;
  final String projectName;

  const QuillScanDialog({
    super.key,
    required this.deviceName,
    this.initialContent,
    this.initialName,
    this.isEditing = false,
    required this.projectName,
  });

  @override
  State<QuillScanDialog> createState() => _QuillScanDialogState();
}

class _QuillScanDialogState extends State<QuillScanDialog> {
  late QuillController _controller;
  final TextEditingController _nameController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.initialContent != null) {
      try {
        final convertedContent = QuillEmbedHelper.convertDeltaJsonForWeb(widget.initialContent!);
        final delta = jsonDecode(convertedContent ?? widget.initialContent!);
        _controller = QuillController(
          document: Document.fromJson(delta),
          selection: const TextSelection.collapsed(offset: 0),
          readOnly: false,
        );
      } catch (e) {
        _controller = QuillController.basic();
        _controller.document.insert(0, widget.initialContent!);
      }
    } else {
      _controller = QuillController.basic();
    }
    if (widget.initialName != null) {
      _nameController.text = widget.initialName!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    return Dialog(
      backgroundColor: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: screenSize.width * 0.9,
        height: screenSize.height * 0.9,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    AppTheme.scanAddIcon,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${widget.isEditing ? 'Edit' : 'Add'} Scan - ${widget.deviceName}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Scan Name Field
            if (!widget.isEditing)
              Column(
                children: [
                  GradientBorderContainer(
                    borderConfig:
                        AppTheme.borderSecondaryGradient ??
                        AppTheme.borderSecondary,
                    borderRadius: 8,
                    borderWidth: 1,
                    backgroundColor: AppTheme.cardBackground,
                    child: TextField(
                      controller: _nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Scan Name',
                        labelStyle: TextStyle(color: AppTheme.primaryColor),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(16),
                        hintText: 'Enter scan name...',
                        hintStyle: const TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),

            // Rich Text Editor
            Expanded(
              child: GradientBorderContainer(
                borderConfig:
                    AppTheme.borderSecondaryGradient ??
                    AppTheme.borderSecondary,
                borderRadius: 8,
                borderWidth: 1,
                backgroundColor: AppTheme.surfaceColor,
                child: SimpleQuillSpellChecker(
                  controller: _controller,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: QuillSimpleToolbar(
                              controller: _controller,
                              config: const QuillSimpleToolbarConfig(
                                showBackgroundColorButton: false,
                                showSearchButton: true,
                                showSubscript: false,
                                showSuperscript: false,
                                showIndent: false,
                                multiRowsDisplay: false,
                              ),
                            ),
                          ),
                          CustomQuillImageButton(
                            controller: _controller,
                            projectName: widget.projectName,
                          ),
                        ],
                      ),
                      Expanded(
                        child: QuillEditor(
                          controller: _controller,
                          focusNode: _focusNode,
                          scrollController: _scrollController,
                          config: QuillEditorConfig(
                            padding: const EdgeInsets.all(8),
                            embedBuilders: [
                              CustomImageEmbedBuilder(),
                              ...FlutterQuillEmbeds.editorBuilders(),
                            ],
                            placeholder:
                                'Enter scan data, paste text or images...',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    final plainText = _controller.document.toPlainText().trim();
                    if (plainText.isNotEmpty) {
                      // Get the delta and convert image paths to relative paths
                      final delta = _controller.document.toDelta().toJson();
                      final convertedDelta = _convertImagePathsToRelative(delta);
                      final richContent = jsonEncode(convertedDelta);

                      final scanName = widget.isEditing
                          ? widget.initialName!
                          : _nameController.text.trim();

                      if (!widget.isEditing && scanName.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a scan name'),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      Navigator.pop(context, {
                        'content': richContent,
                        'name': scanName,
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter scan content'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        widget.isEditing ? AppTheme.saveIcon : AppTheme.addIcon,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(widget.isEditing ? 'Update Scan' : 'Add Scan'),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Converts absolute image paths to relative paths for storage
  dynamic _convertImagePathsToRelative(dynamic delta) {
    if (delta is List) {
      // Delta is the ops array directly
      for (final op in delta) {
        if (op is Map && op.containsKey('insert') && op['insert'] is Map) {
          final insert = op['insert'] as Map;
          if (insert.containsKey('image')) {
            final imagePath = insert['image'];
            if (imagePath is String && !imagePath.startsWith('data:') && !imagePath.startsWith('http')) {
              insert['image'] = ImagePathHelper.toStoragePath(imagePath);
            }
          }
        }
      }
      return delta;
    } else if (delta is Map && delta.containsKey('ops')) {
      // Delta is wrapped: {ops: [...]}
      final ops = delta['ops'] as List;
      for (final op in ops) {
        if (op is Map && op.containsKey('insert') && op['insert'] is Map) {
          final insert = op['insert'] as Map;
          if (insert.containsKey('image')) {
            final imagePath = insert['image'];
            if (imagePath is String && !imagePath.startsWith('data:') && !imagePath.startsWith('http')) {
              insert['image'] = ImagePathHelper.toStoragePath(imagePath);
            }
          }
        }
      }
      return delta;
    }
    return delta;
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
