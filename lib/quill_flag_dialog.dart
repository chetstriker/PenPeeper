import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:penpeeper/theme_config.dart';
import 'package:penpeeper/widgets/gradient_border_container.dart';
import 'package:penpeeper/widgets/custom_quill_image_button.dart';
import 'package:penpeeper/models/cvss/cvss_data.dart';
import 'package:penpeeper/models/cvss/cvss_enums.dart';

import 'package:penpeeper/widgets/cve_search_modal.dart';
import 'package:penpeeper/repositories/findings_repository.dart';
import 'package:penpeeper/database/connection/database_connection.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:penpeeper/utils/quill_embed_helper.dart';
import 'package:penpeeper/widgets/simple_quill_spell_checker.dart';
import 'package:penpeeper/widgets/custom_image_embed_builder.dart';

class QuillFlagDialog extends StatefulWidget {
  final String deviceName;
  final Function(String type, String content) onSubmit;
  final String? initialComment;
  final String? initialType;
  final bool isEditing;
  final String projectName;
  final CvssData? initialCvssData;
  final String? initialEvidence;
  final String? initialRecommendation;
  final int? findingId;
  final int? projectId;
  final int? deviceId;

  const QuillFlagDialog({
    super.key,
    required this.deviceName,
    required this.onSubmit,
    this.initialComment,
    this.initialType,
    this.isEditing = false,
    required this.projectName,
    this.initialCvssData,
    this.initialEvidence,
    this.initialRecommendation,
    this.findingId,
    this.projectId,
    this.deviceId,
  });

  @override
  State<QuillFlagDialog> createState() => _QuillFlagDialogState();
}

class _QuillFlagDialogState extends State<QuillFlagDialog>
    with TickerProviderStateMixin {
  late QuillController _controller;
  late QuillController _evidenceController;
  late QuillController _recommendationController;
  late TabController _tabController;
  String selectedType = 'Issue';
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _evidenceFocusNode = FocusNode();
  final ScrollController _evidenceScrollController = ScrollController();
  final FocusNode _recommendationFocusNode = FocusNode();
  final ScrollController _recommendationScrollController = ScrollController();

  CvssData? _cvssData;
  List<Map<String, dynamic>> _taxonomyData = [];
  String? _selectedCategory;
  String? _selectedSubcategory;
  Map<String, dynamic>? _selectedSubcategoryData;
  String? _scope;
  bool _isLoading = true;

  final _findingsRepo = FindingsRepository();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    debugPrint('=' * 80);
    debugPrint('🔧 [Quill Flag Dialog] INITIALIZING');
    debugPrint('=' * 80);
    debugPrint('📝 Comment: ${widget.initialComment?.length ?? 0} chars');
    debugPrint('📝 Evidence: ${widget.initialEvidence?.length ?? 0} chars');
    debugPrint(
      '📝 Recommendation: ${widget.initialRecommendation?.length ?? 0} chars',
    );

    if (widget.initialComment != null) {
      try {
        debugPrint('📝 [Flag Dialog] Converting comment...');
        final convertedComment = QuillEmbedHelper.convertDeltaJsonForWeb(
          widget.initialComment,
        );
        final delta = jsonDecode(convertedComment!);
        _controller = QuillController(
          document: Document.fromJson(delta),
          selection: const TextSelection.collapsed(offset: 0),
          readOnly: false,
        );
      } catch (e) {
        _controller = QuillController.basic();
      }
    } else {
      _controller = QuillController.basic();
    }

    // Initialize evidence controller
    if (widget.initialEvidence != null && widget.initialEvidence!.isNotEmpty) {
      try {
        debugPrint('📝 [Flag Dialog] Converting evidence...');
        debugPrint('📝 [Flag Dialog] Evidence RAW: ${widget.initialEvidence}');
        final convertedEvidence = QuillEmbedHelper.convertDeltaJsonForWeb(
          widget.initialEvidence,
        );
        debugPrint('📝 [Flag Dialog] Evidence CONVERTED: $convertedEvidence');
        final delta = jsonDecode(convertedEvidence ?? widget.initialEvidence!);
        _evidenceController = QuillController(
          document: Document.fromJson(delta),
          selection: const TextSelection.collapsed(offset: 0),
          readOnly: false,
        );
      } catch (e) {
        debugPrint('❌ [Flag Dialog] Evidence error: $e');
        _evidenceController = QuillController.basic();
        if (widget.initialEvidence!.isNotEmpty) {
          _evidenceController.document.insert(0, widget.initialEvidence!);
        }
      }
    } else {
      _evidenceController = QuillController.basic();
    }

    // Initialize recommendation controller
    if (widget.initialRecommendation != null &&
        widget.initialRecommendation!.isNotEmpty) {
      try {
        debugPrint('📝 [Flag Dialog] Converting recommendation...');
        final convertedRecommendation = QuillEmbedHelper.convertDeltaJsonForWeb(
          widget.initialRecommendation,
        );
        final delta = jsonDecode(convertedRecommendation!);
        _recommendationController = QuillController(
          document: Document.fromJson(delta),
          selection: const TextSelection.collapsed(offset: 0),
          readOnly: false,
        );
      } catch (e) {
        _recommendationController = QuillController.basic();
        if (widget.initialRecommendation!.isNotEmpty) {
          _recommendationController.document.insert(
            0,
            widget.initialRecommendation!,
          );
        }
      }
    } else {
      _recommendationController = QuillController.basic();
    }

    if (widget.initialType != null) {
      selectedType = widget.initialType!;
    }
    _cvssData = widget.initialCvssData;
    _loadTaxonomyData();

    // Add listeners to update tab indicators when content changes
    _controller.addListener(() => setState(() {}));
    _evidenceController.addListener(() => setState(() {}));
    _recommendationController.addListener(() => setState(() {}));

    // Add listener to update the header when controller changes
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  Future<void> _loadTaxonomyData() async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/vulnerability_taxonomy_full.json',
      );
      final List<dynamic> data = json.decode(jsonString);
      _taxonomyData = data.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error loading taxonomy data: $e');
    }

    // Load existing classification after taxonomy data is loaded
    if (widget.isEditing && widget.findingId != null) {
      await _loadExistingClassification();
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadExistingClassification() async {
    try {
      Map<String, dynamic>? classification;
      
      if (kIsWeb) {
        final response = await http.get(Uri.parse('/api/vulnerability-classifications/${widget.findingId}'));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data != null && data is Map) {
            classification = Map<String, dynamic>.from(data);
          }
        }
      } else {
        final db = await DatabaseConnection().database;
        final results = await db.query(
          'vulnerability_classifications',
          where: 'finding_id = ?',
          whereArgs: [widget.findingId],
          orderBy: 'created_at DESC',
          limit: 1,
        );
        classification = results.isNotEmpty ? results.first : null;
      }
      
      if (classification != null) {
        setState(() {
          _selectedCategory = classification!['category'] as String?;
          _selectedSubcategory = classification['subcategory'] as String?;
          _scope = classification['scope'] as String?;
          _updateSubcategoryData();
        });
      }
    } catch (e) {
      debugPrint('Error loading classification: $e');
    }
  }

  List<String> get _categories {
    return _taxonomyData.map((item) => item['Category'] as String).toList();
  }

  List<Map<String, dynamic>> get _subcategories {
    if (_selectedCategory == null) return [];
    final category = _taxonomyData.firstWhere(
      (item) => item['Category'] == _selectedCategory,
      orElse: () => {},
    );
    if (category.isEmpty) return [];
    return (category['Subcategories'] as List).cast<Map<String, dynamic>>();
  }

  void _updateSubcategoryData() {
    if (_selectedCategory == null || _selectedSubcategory == null) return;
    final category = _taxonomyData.firstWhere(
      (item) => item['Category'] == _selectedCategory,
      orElse: () => {},
    );
    if (category.isEmpty) return;
    final subcategories = (category['Subcategories'] as List)
        .cast<Map<String, dynamic>>();
    _selectedSubcategoryData = subcategories.firstWhere(
      (item) => item['Subcategory'] == _selectedSubcategory,
      orElse: () => {},
    );
  }

  void _updateMetric(CvssData newData) {
    setState(() {
      _cvssData = newData.calculate();
    });
  }

  Color _getSeverityColor() {
    if (_cvssData?.severity == null) return Colors.grey;
    switch (_cvssData!.severity!) {
      case CvssSeverity.none:
        return Colors.grey;
      case CvssSeverity.low:
        return Colors.green;
      case CvssSeverity.medium:
        return Colors.yellow;
      case CvssSeverity.high:
        return Colors.orange;
      case CvssSeverity.critical:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Dialog(
        backgroundColor: AppTheme.surfaceColor,
        child: Container(
          width: 1000,
          height: 600,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(),
        ),
      );
    }

    return Dialog(
      backgroundColor: AppTheme.surfaceColor,
      child: Container(
        width: 1000,
        height: 700,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 7, child: _buildMainContent()),
                  const SizedBox(width: 16),
                  SizedBox(width: 300, child: _buildSidebar()),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildActions(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return GradientBorderContainer(
      borderConfig: AppTheme.borderPrimaryGradient ?? AppTheme.borderPrimary,
      borderRadius: 8,
      borderWidth: 2,
      backgroundColor: AppTheme.surfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(AppTheme.flagIcon, color: Colors.red, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Flag Finding - ${widget.deviceName}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Convert to CVE button - only show for manual findings during editing
            if (widget.isEditing &&
                selectedType != 'CVE' &&
                widget.findingId != null &&
                widget.projectId != null &&
                widget.deviceId != null)
              ElevatedButton.icon(
                onPressed: _convertToCve,
                icon: const Icon(Icons.security, size: 16),
                label: const Text('Convert to CVE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primaryColor,
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Description'),
                  if (_isControllerEmpty(_controller)) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Evidence'),
                  if (_isControllerEmpty(_evidenceController)) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Recommendation'),
                  if (_isControllerEmpty(_recommendationController)) ...[
                    const SizedBox(width: 4),
                    Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              SimpleQuillSpellChecker(
                controller: _controller,
                child: _buildQuillEditor(_controller),
              ),
              SimpleQuillSpellChecker(
                controller: _evidenceController,
                child: _buildQuillEditor(_evidenceController),
              ),
              SimpleQuillSpellChecker(
                controller: _recommendationController,
                child: _buildQuillEditor(_recommendationController),
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _isControllerEmpty(QuillController controller) {
    return controller.document.isEmpty() ||
        controller.document.toPlainText().trim().isEmpty;
  }

  Widget _buildQuillEditor(QuillController controller) {
    FocusNode focusNode;
    ScrollController scrollController;

    if (controller == _controller) {
      focusNode = _focusNode;
      scrollController = _scrollController;
    } else if (controller == _evidenceController) {
      focusNode = _evidenceFocusNode;
      scrollController = _evidenceScrollController;
    } else {
      focusNode = _recommendationFocusNode;
      scrollController = _recommendationScrollController;
    }

    return GradientBorderContainer(
      borderConfig: AppTheme.borderPrimaryGradient ?? AppTheme.borderPrimary,
      borderRadius: 8,
      borderWidth: 1,
      backgroundColor: AppTheme.inputBackground,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: QuillSimpleToolbar(
                  controller: controller,
                  config: const QuillSimpleToolbarConfig(
                    showBackgroundColorButton: false,
                    showInlineCode: false,
                    showSubscript: false,
                    showSuperscript: false,
                    showIndent: false,
                    multiRowsDisplay: false,
                  ),
                ),
              ),
              CustomQuillImageButton(
                controller: controller,
                projectName: widget.projectName,
              ),
            ],
          ),
          Expanded(
            child: QuillEditor(
              controller: controller,
              focusNode: focusNode,
              scrollController: scrollController,
              config: QuillEditorConfig(
                padding: const EdgeInsets.all(12),
                embedBuilders: [
                  CustomImageEmbedBuilder(),
                  ...FlutterQuillEmbeds.editorBuilders(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Finding Type at the top - only show for manual findings
          if (selectedType != 'CVE') ...[
            Text(
              'Finding Type',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            GradientBorderContainer(
              borderConfig:
                  AppTheme.borderPrimaryGradient ?? AppTheme.borderPrimary,
              borderRadius: 8,
              borderWidth: 1,
              backgroundColor: AppTheme.surfaceColor,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedType,
                  isExpanded: true,
                  dropdownColor: AppTheme.surfaceColor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                  items: [
                    DropdownMenuItem(
                      value: 'Issue',
                      child: Row(
                        children: [
                          Icon(AppTheme.errorIcon, color: Colors.red, size: 16),
                          const SizedBox(width: 8),
                          const Text('Issue'),
                        ],
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'Needs Investigating',
                      child: Row(
                        children: [
                          Icon(
                            AppTheme.searchIcon,
                            color: Colors.orange,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          const Text('Needs Investigating'),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => selectedType = value!),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Category
          Text(
            'Category',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          GradientBorderContainer(
            borderConfig:
                AppTheme.borderPrimaryGradient ?? AppTheme.borderPrimary,
            borderRadius: 8,
            borderWidth: 1,
            backgroundColor: AppTheme.surfaceColor,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCategory,
                hint: Text(
                  'Select',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                isExpanded: true,
                dropdownColor: AppTheme.surfaceColor,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                items: _categories
                    .map(
                      (cat) => DropdownMenuItem(value: cat, child: Text(cat)),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                    _selectedSubcategory = null;
                    _selectedSubcategoryData = null;
                  });
                },
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Subcategory
          Text(
            'Subcategory',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          GradientBorderContainer(
            borderConfig:
                AppTheme.borderPrimaryGradient ?? AppTheme.borderPrimary,
            borderRadius: 8,
            borderWidth: 1,
            backgroundColor: AppTheme.surfaceColor,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedSubcategory,
                hint: Text(
                  'Select',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                isExpanded: true,
                dropdownColor: AppTheme.surfaceColor,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                items: _subcategories
                    .map(
                      (sub) => DropdownMenuItem(
                        value: sub['Subcategory'] as String,
                        child: Text(sub['Subcategory'] as String),
                      ),
                    )
                    .toList(),
                onChanged: _selectedCategory == null
                    ? null
                    : (value) {
                        setState(() {
                          _selectedSubcategory = value;
                          _updateSubcategoryData();
                        });
                      },
              ),
            ),
          ),
          if (_selectedSubcategoryData != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _selectedSubcategoryData!['Description'] ?? '',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 11),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Scope
          Text(
            'Scope',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 8),
          ..._buildScopeRadios(),
          const SizedBox(height: 12),

          // CVSS Calculator fields
          if (_cvssData?.baseScore != null) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _getSeverityColor().withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _getSeverityColor(), width: 2),
              ),
              child: Column(
                children: [
                  Text(
                    _cvssData!.baseScore!.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _getSeverityColor(),
                    ),
                  ),
                  Text(
                    _cvssData!.severity!.label.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _getSeverityColor(),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // CVSS Metrics - only show for manual findings
          if (selectedType != 'CVE') ...[
            _buildDropdown<AttackComplexity>(
              'Attack Complexity',
              AttackComplexity.values,
              _cvssData?.attackComplexity,
              (v) => _updateMetric(
                (_cvssData ?? CvssData()).copyWith(attackComplexity: v),
              ),
            ),
            _buildDropdown<PrivilegesRequired>(
              'Privileges Required',
              PrivilegesRequired.values,
              _cvssData?.privilegesRequired,
              (v) => _updateMetric(
                (_cvssData ?? CvssData()).copyWith(privilegesRequired: v),
              ),
            ),
            _buildDropdown<UserInteraction>(
              'User Interaction',
              UserInteraction.values,
              _cvssData?.userInteraction,
              (v) => _updateMetric(
                (_cvssData ?? CvssData()).copyWith(userInteraction: v),
              ),
            ),
            _buildDropdown<Scope>(
              'Scope',
              Scope.values,
              _cvssData?.scope,
              (v) =>
                  _updateMetric((_cvssData ?? CvssData()).copyWith(scope: v)),
            ),
            _buildDropdown<Impact>(
              'Confidentiality',
              Impact.values,
              _cvssData?.confidentialityImpact,
              (v) => _updateMetric(
                (_cvssData ?? CvssData()).copyWith(confidentialityImpact: v),
              ),
            ),
            _buildDropdown<Impact>(
              'Integrity',
              Impact.values,
              _cvssData?.integrityImpact,
              (v) => _updateMetric(
                (_cvssData ?? CvssData()).copyWith(integrityImpact: v),
              ),
            ),
            _buildDropdown<Impact>(
              'Availability',
              Impact.values,
              _cvssData?.availabilityImpact,
              (v) => _updateMetric(
                (_cvssData ?? CvssData()).copyWith(availabilityImpact: v),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _updateScopeAndAttackVector(String scope) {
    AttackVector? vector;
    switch (scope) {
      case 'NETWORK':
        vector = AttackVector.network;
        break;
      case 'ADJACENT':
        vector = AttackVector.adjacent;
        break;
      case 'LOCAL':
        vector = AttackVector.local;
        break;
      case 'PHYSICAL':
        vector = AttackVector.physical;
        break;
    }

    setState(() {
      _scope = scope;
      if (vector != null) {
        _cvssData = (_cvssData ?? CvssData())
            .copyWith(attackVector: vector)
            .calculate();
      }
    });
  }

  List<Widget> _buildScopeRadios() {
    final scopes = [
      ('NETWORK', '(Remote) - Exploitable over the network'),
      ('ADJACENT', '(Same LAN) - Same local network'),
      ('LOCAL', '(Authenticated) - Local access required'),
      ('PHYSICAL', '(Physical) - Physical access required'),
    ];

    return scopes.map((scope) {
      return InkWell(
        onTap: () => _updateScopeAndAttackVector(scope.$1),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Radio<String>(
                value: scope.$1,
                groupValue: _scope,
                activeColor: AppTheme.primaryColor,
                onChanged: (value) {
                  if (value != null) _updateScopeAndAttackVector(value);
                },
              ),
              Expanded(
                child: Tooltip(
                  message: scope.$2,
                  child: Text(
                    scope.$1,
                    style: TextStyle(color: AppTheme.textPrimary, fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildDropdown<T>(
    String label,
    List<T> values,
    T? currentValue,
    Function(T) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          GradientBorderContainer(
            borderConfig:
                AppTheme.borderSecondaryGradient ?? AppTheme.borderSecondary,
            borderRadius: 8,
            borderWidth: 1,
            backgroundColor: AppTheme.cardBackground,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: currentValue,
                hint: Text(
                  'Select',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
                isExpanded: true,
                dropdownColor: AppTheme.cardBackground,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                items: values.map((value) {
                  String itemLabel = '';
                  String? description;

                  if (value is AttackVector) {
                    itemLabel = value.label.toUpperCase();
                    description = value.description;
                  } else if (value is AttackComplexity) {
                    itemLabel = value.label.toUpperCase();
                    description = value.description;
                  } else if (value is PrivilegesRequired) {
                    itemLabel = value.label.toUpperCase();
                    description = value.description;
                  } else if (value is UserInteraction) {
                    itemLabel = value.label.toUpperCase();
                    description = value.description;
                  } else if (value is Scope) {
                    itemLabel = value.label.toUpperCase();
                    description = value.description;
                  } else if (value is Impact) {
                    itemLabel = value.label.toUpperCase();
                    description = value.description;
                  }

                  return DropdownMenuItem<T>(
                    value: value,
                    child: Tooltip(
                      message: description ?? '',
                      child: Text(
                        itemLabel,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) onChanged(value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(color: AppTheme.textSecondary),
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: () async {
            // Unfocus all editors to ensure changes are committed
            _focusNode.unfocus();
            _evidenceFocusNode.unfocus();
            _recommendationFocusNode.unfocus();

            // Small delay to ensure unfocus completes
            await Future.delayed(const Duration(milliseconds: 50));

            final plainText = _controller.document.toPlainText().trim();
            if (plainText.isNotEmpty) {
              final richContent = jsonEncode(
                _controller.document.toDelta().toJson(),
              );
              final evidenceContent = jsonEncode(
                _evidenceController.document.toDelta().toJson(),
              );
              final recommendationContent = jsonEncode(
                _recommendationController.document.toDelta().toJson(),
              );

              // Save classification if provided and we have the necessary IDs
              if (widget.findingId != null &&
                  widget.projectId != null &&
                  widget.deviceId != null &&
                  _selectedCategory != null &&
                  _selectedSubcategory != null &&
                  _selectedSubcategoryData != null &&
                  _scope != null) {
                try {
                  if (kIsWeb) {
                    // Web: Use API
                    final response = await http.get(Uri.parse('/api/vulnerability-classifications/${widget.findingId}'));
                    if (response.statusCode == 200) {
                      final data = json.decode(response.body);
                      if (data != null && data is Map && data['id'] != null) {
                        await http.delete(Uri.parse('/api/vulnerability-classifications/${data['id']}'));
                      }
                    }
                    await http.post(
                      Uri.parse('/api/vulnerability-classifications'),
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode({
                        'project_id': widget.projectId!,
                        'device_id': widget.deviceId!,
                        'finding_id': widget.findingId!,
                        'category': _selectedCategory!,
                        'subcategory': _selectedSubcategory!,
                        'description': _selectedSubcategoryData!['Description'] ?? '',
                        'mapped_owasp': _selectedSubcategoryData!['Mapped_OWASP'] ?? '',
                        'mapped_cwe': _selectedSubcategoryData!['Mapped_CWE'] ?? '',
                        'severity_guideline': _selectedSubcategoryData!['Severity_Guideline'] ?? '',
                        'scope': _scope!,
                      }),
                    );
                  } else {
                    // Desktop: Use database
                    final db = await DatabaseConnection().database;
                    final existing = await db.query(
                      'vulnerability_classifications',
                      where: 'finding_id = ?',
                      whereArgs: [widget.findingId],
                    );
                    if (existing.isNotEmpty) {
                      await db.delete(
                        'vulnerability_classifications',
                        where: 'id = ?',
                        whereArgs: [existing.first['id']],
                      );
                    }
                    await db.insert('vulnerability_classifications', {
                      'project_id': widget.projectId!,
                      'device_id': widget.deviceId!,
                      'finding_id': widget.findingId!,
                      'category': _selectedCategory!,
                      'subcategory': _selectedSubcategory!,
                      'description': _selectedSubcategoryData!['Description'] ?? '',
                      'mapped_owasp': _selectedSubcategoryData!['Mapped_OWASP'] ?? '',
                      'mapped_cwe': _selectedSubcategoryData!['Mapped_CWE'] ?? '',
                      'severity_guideline': _selectedSubcategoryData!['Severity_Guideline'] ?? '',
                      'scope': _scope!,
                      'created_at': DateTime.now().toIso8601String(),
                    });
                  }
                } catch (e) {
                  debugPrint('Error saving classification: $e');
                }
              }

              Navigator.pop(context, {
                'comment': richContent,
                'evidence': evidenceContent,
                'recommendation': recommendationContent,
                'type': selectedType,
                'cvssData': _cvssData,
                'classification':
                    _selectedCategory != null && _selectedSubcategory != null
                    ? {
                        'category': _selectedCategory,
                        'subcategory': _selectedSubcategory,
                        'scope': _scope,
                        'description': _selectedSubcategoryData?['Description'],
                        'mapped_owasp':
                            _selectedSubcategoryData?['Mapped_OWASP'],
                        'mapped_cwe': _selectedSubcategoryData?['Mapped_CWE'],
                        'severity_guideline':
                            _selectedSubcategoryData?['Severity_Guideline'],
                      }
                    : null,
              });
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please enter a comment'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.isEditing ? AppTheme.saveIcon : AppTheme.flagIcon,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(widget.isEditing ? 'Update Finding' : 'Add Finding'),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _convertToCve() async {
    if (widget.projectId == null || widget.deviceId == null) return;

    final cveResult = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => CveSearchModal(
        deviceId: widget.deviceId!,
        projectId: widget.projectId!,
      ),
    );

    if (cveResult != null) {
      // Get current comment content
      final currentComment = _controller.document.toPlainText();

      // Create new document with CVE description prepended
      final newDocument = Document();
      newDocument.insert(0, '${cveResult['description']}\n\n$currentComment');

      // Update the controller with new content
      setState(() {
        _controller = QuillController(
          document: newDocument,
          selection: const TextSelection.collapsed(offset: 0),
          readOnly: false,
        );
        selectedType = 'CVE';

        // Update CVSS data from CVE
        _cvssData = CvssData(
          attackVector: _parseAttackVector(cveResult['attackVector']),
          attackComplexity: _parseAttackComplexity(
            cveResult['attackComplexity'],
          ),
          privilegesRequired: _parsePrivilegesRequired(
            cveResult['privilegesRequired'],
          ),
          userInteraction: _parseUserInteraction(cveResult['userInteraction']),
          scope: _parseScope(cveResult['scope']),
          confidentialityImpact: _parseImpact(
            cveResult['confidentialityImpact'],
          ),
          integrityImpact: _parseImpact(cveResult['integrityImpact']),
          availabilityImpact: _parseImpact(cveResult['availabilityImpact']),
        ).calculate();
      });

      // Update the finding in database immediately
      if (widget.findingId != null) {
        final richContent = jsonEncode(_controller.document.toDelta().toJson());

        // Update the finding with CVE data
        await _findingsRepo.updateFlaggedFinding(
          widget.findingId!,
          'CVE',
          richContent,
        );

        // Update CVE-specific fields
        await _findingsRepo.updateFlaggedFindingCvss(
          widget.findingId!,
          attackVector: cveResult['attackVector'],
          attackComplexity: cveResult['attackComplexity'],
          privilegesRequired: cveResult['privilegesRequired'],
          userInteraction: cveResult['userInteraction'],
          scope: cveResult['scope'],
          confidentialityImpact: cveResult['confidentialityImpact'],
          integrityImpact: cveResult['integrityImpact'],
          availabilityImpact: cveResult['availabilityImpact'],
          cvssBaseScore: cveResult['cvssScore'],
          cvssSeverity: cveResult['cvssSeverity'],
        );

        // Update CVE-specific fields
        await _findingsRepo.updateFlaggedFindingCveData(
          widget.findingId!,
          cveId: cveResult['cveId'],
          confidenceLevel: cveResult['confidenceLevel'],
          vulnerabilityType: cveResult['vulnerabilityType'],
          url: cveResult['url'],
          cvssVersion: cveResult['cvssVersion'],
          findingType: 'CVE',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully converted to CVE ${cveResult['cveId']}',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Close the modal and trigger refresh
        Navigator.pop(context, {
          'comment': jsonEncode(_controller.document.toDelta().toJson()),
          'evidence': jsonEncode(
            _evidenceController.document.toDelta().toJson(),
          ),
          'recommendation': jsonEncode(
            _recommendationController.document.toDelta().toJson(),
          ),
          'type': 'CVE',
          'cvssData': _cvssData,
          'converted': true,
        });
      }
    }
  }

  AttackVector? _parseAttackVector(String? value) {
    if (value == null) return null;
    switch (value.toUpperCase()) {
      case 'NETWORK':
        return AttackVector.network;
      case 'ADJACENT_NETWORK':
        return AttackVector.adjacent;
      case 'LOCAL':
        return AttackVector.local;
      case 'PHYSICAL':
        return AttackVector.physical;
      default:
        return null;
    }
  }

  AttackComplexity? _parseAttackComplexity(String? value) {
    if (value == null) return null;
    switch (value.toUpperCase()) {
      case 'LOW':
        return AttackComplexity.low;
      case 'HIGH':
        return AttackComplexity.high;
      default:
        return null;
    }
  }

  PrivilegesRequired? _parsePrivilegesRequired(String? value) {
    if (value == null) return null;
    switch (value.toUpperCase()) {
      case 'NONE':
        return PrivilegesRequired.none;
      case 'LOW':
        return PrivilegesRequired.low;
      case 'HIGH':
        return PrivilegesRequired.high;
      default:
        return null;
    }
  }

  UserInteraction? _parseUserInteraction(String? value) {
    if (value == null) return null;
    switch (value.toUpperCase()) {
      case 'NONE':
        return UserInteraction.none;
      case 'REQUIRED':
        return UserInteraction.required;
      default:
        return null;
    }
  }

  Scope? _parseScope(String? value) {
    if (value == null) return null;
    switch (value.toUpperCase()) {
      case 'UNCHANGED':
        return Scope.unchanged;
      case 'CHANGED':
        return Scope.changed;
      default:
        return null;
    }
  }

  Impact? _parseImpact(String? value) {
    if (value == null) return null;
    switch (value.toUpperCase()) {
      case 'NONE':
        return Impact.none;
      case 'LOW':
        return Impact.low;
      case 'HIGH':
        return Impact.high;
      default:
        return null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _evidenceController.dispose();
    _recommendationController.dispose();
    _tabController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    _evidenceFocusNode.dispose();
    _evidenceScrollController.dispose();
    _recommendationFocusNode.dispose();
    _recommendationScrollController.dispose();
    super.dispose();
  }
}
