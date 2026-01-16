import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:penpeeper/theme_config.dart';
import 'package:penpeeper/utils/clipboard_helper.dart';
import 'package:penpeeper/utils/quill_embed_helper.dart';
import 'package:penpeeper/widgets/custom_image_embed_builder.dart';

class RichCommentViewer extends StatelessWidget {
  final String comment;

  const RichCommentViewer({
    super.key,
    required this.comment,
  });

  @override
  Widget build(BuildContext context) {
    try {
      // Convert image paths using helper (handles Web/Desktop differences)
      final convertedComment = QuillEmbedHelper.convertDeltaJsonForWeb(comment);
      final delta = jsonDecode(convertedComment ?? comment);
      final document = Document.fromJson(delta);
      
      final controller = QuillController(
        document: document,
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
      final focusNode = FocusNode();

      controller.addListener(() {
        if (controller.selection.isValid && !controller.selection.isCollapsed) {
          if (!focusNode.hasFocus) {
            focusNode.requestFocus();
          }
        }
      });

      return Shortcuts(
        shortcuts: {
          LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyC): const CopyTextIntent(),
        },
        child: Actions(
          actions: {
            CopyTextIntent: CallbackAction<CopyTextIntent>(
              onInvoke: (intent) async {
                final selection = controller.selection;
                if (selection.isValid && !selection.isCollapsed) {
                  final selectedText = controller.document.getPlainText(
                    selection.start,
                    selection.end - selection.start,
                  );
                  await ClipboardHelper.copy(
                    selectedText,
                    successMessage: 'Text copied to clipboard',
                    context: context,
                  );
                }
                return null;
              },
            ),
          },
          child: QuillEditor(
            controller: controller,
            focusNode: focusNode,
            scrollController: ScrollController(),
            config: QuillEditorConfig(
              padding: EdgeInsets.zero,
              embedBuilders: [
                CustomImageEmbedBuilder(),
                ...FlutterQuillEmbeds.editorBuilders(),
              ],
              enableSelectionToolbar: true,
            ),
          ),
        ),
      );
    } catch (e) {
      // Fallback to plain text if parsing fails
      return SelectableText(
        comment,
        style: TextStyle(
          color: AppTheme.textSecondary,
          fontSize: AppTheme.fontSizeBodyMedium,
          fontFamily: AppTheme.defaultFontFamily.isEmpty ? null : AppTheme.defaultFontFamily,
        ),
      );
    }
  }
}

class CopyTextIntent extends Intent {
  const CopyTextIntent();
}
