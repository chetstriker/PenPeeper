import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:penpeeper/theme_config.dart';
import 'package:penpeeper/widgets/gradient_border_container.dart';
import 'package:penpeeper/widgets/custom_quill_image_button.dart';
import 'package:penpeeper/repositories/report_section_repository.dart';
import 'package:penpeeper/models/report_section.dart';
import 'package:penpeeper/widgets/report_section_help_dialog.dart';
import 'package:penpeeper/utils/quill_embed_helper.dart';
import 'package:penpeeper/utils/image_path_helper.dart';
import 'package:penpeeper/services/app_paths_service.dart';

class ReportSectionEditor extends StatefulWidget {
  final int projectId;
  final String sectionType;
  final String title;
  final String placeholder;
  final String projectName;
  final String? exampleContent;
  final String? description;
  final bool showAiButton;
  final VoidCallback? onAiButtonPressed;

  const ReportSectionEditor({
    super.key,
    required this.projectId,
    required this.sectionType,
    required this.title,
    required this.placeholder,
    required this.projectName,
    this.exampleContent,
    this.description,
    this.showAiButton = false,
    this.onAiButtonPressed,
  });

  @override
  State<ReportSectionEditor> createState() => _ReportSectionEditorState();
}

class _ReportSectionEditorState extends State<ReportSectionEditor> {
  late QuillController _controller;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final _repository = ReportSectionRepository();
  Timer? _debounceTimer;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _showSaved = false;

  @override
  void initState() {
    super.initState();
    _loadContent();
    _focusNode.addListener(_onFocusChange);
  }

  Future<void> _loadContent() async {
    final section = await _repository.getReportSection(widget.projectId, widget.sectionType);
    if (section != null) {
      try {
        final convertedContent = QuillEmbedHelper.convertDeltaJsonForWeb(section.content);
        final delta = jsonDecode(convertedContent!);
        _controller = QuillController(
          document: Document.fromJson(delta),
          selection: const TextSelection.collapsed(offset: 0),
        );
      } catch (e) {
        _controller = QuillController.basic();
      }
    } else {
      _controller = QuillController.basic();
      // Pre-populate Risk Rating Model with default formatted content
      if (widget.sectionType == 'risk_rating_model') {
        final riskImagePath = AppPathsService().riskPath;
        _controller.document.insert(0, BlockEmbed.image(riskImagePath));
        _controller.document.insert(1, '\n');
        await _saveContent();
      }
      // Pre-populate Report Header with default content
      else if (widget.sectionType == 'report_header' && widget.exampleContent != null) {
        _controller.document.insert(0, widget.exampleContent!);
        // Save the default content immediately
        await _saveContent();
      }
    }
    _controller.addListener(_onContentChange);
    setState(() => _isLoading = false);
  }

  void _onContentChange() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 30), _saveContent);
  }

  void _onFocusChange() {
    if (!_focusNode.hasFocus) {
      _saveContent();
    }
  }

  Future<void> _saveContent() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    // Get the delta and convert image paths to relative paths
    final delta = _controller.document.toDelta().toJson();
    final convertedDelta = _convertImagePathsToRelative(delta);
    final content = jsonEncode(convertedDelta);

    final now = DateTime.now();
    final section = ReportSection(
      projectId: widget.projectId,
      sectionType: widget.sectionType,
      content: content,
      createdAt: now,
      updatedAt: now,
    );

    await _repository.saveReportSection(section);

    setState(() {
      _isSaving = false;
      _showSaved = true;
    });

    Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _showSaved = false);
    });
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
            if (imagePath is String && !imagePath.startsWith('data:')) {
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
            if (imagePath is String && !imagePath.startsWith('data:')) {
              insert['image'] = ImagePathHelper.toStoragePath(imagePath);
            }
          }
        }
      }
      return delta;
    }
    return delta;
  }

  void _showExample() {
    if (widget.exampleContent == null) return;
    showDialog(
      context: context,
      builder: (context) => ReportSectionHelpDialog(
        title: widget.title,
        description: widget.description ?? '',
        example: widget.exampleContent!,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.title,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
            ),
            const SizedBox(width: 8),
            if (widget.exampleContent != null)
              Tooltip(
                message: 'View example and best practices',
                child: IconButton(
                  icon: Icon(Icons.help_outline, size: 20, color: AppTheme.primaryColor),
                  onPressed: _showExample,
                ),
              ),
            if (widget.showAiButton && widget.onAiButtonPressed != null)
              Tooltip(
                message: 'Generate with AI',
                child: IconButton(
                  icon: Icon(Icons.psychology, size: 20, color: AppTheme.primaryColor),
                  onPressed: widget.onAiButtonPressed,
                ),
              ),
            const Spacer(),
            if (_isSaving)
              Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
                  ),
                  const SizedBox(width: 8),
                  Text('Saving...', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                ],
              )
            else if (_showSaved)
              Row(
                children: [
                  Icon(Icons.check_circle, size: 16, color: Colors.green),
                  const SizedBox(width: 8),
                  Text('Saved', style: TextStyle(color: Colors.green, fontSize: 12)),
                ],
              ),
          ],
        ),
        const SizedBox(height: 8),
        GradientBorderContainer(
          borderConfig: AppTheme.borderPrimaryGradient ?? AppTheme.borderPrimary,
          borderRadius: 8,
          borderWidth: 1,
          backgroundColor: AppTheme.inputBackground,
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor.withValues(alpha: 0.5),
                  border: Border(
                    bottom: BorderSide(color: AppTheme.borderSecondary, width: 1),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: QuillSimpleToolbar(
                        controller: _controller,
                        config: const QuillSimpleToolbarConfig(
                          showBackgroundColorButton: false,
                          showInlineCode: false,
                          showSubscript: false,
                          showSuperscript: false,
                          showIndent: false,
                          showSearchButton: false,
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
              ),
              SizedBox(
                height: 200,
                child: QuillEditor(
                  controller: _controller,
                  focusNode: _focusNode,
                  scrollController: _scrollController,
                  config: QuillEditorConfig(
                    padding: const EdgeInsets.all(12),
                    placeholder: widget.placeholder,
                    embedBuilders: [
                      ...FlutterQuillEmbeds.editorBuilders(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
