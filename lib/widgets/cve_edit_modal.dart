import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:penpeeper/repositories/project_repository.dart';
import 'package:penpeeper/repositories/findings_repository.dart';
import 'package:penpeeper/database/connection/database_connection.dart';
import 'package:penpeeper/theme_config.dart';
import 'package:penpeeper/widgets/gradient_border_container.dart';
import 'package:penpeeper/widgets/custom_quill_image_button.dart';
import 'package:penpeeper/services/project_data_cache.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:penpeeper/utils/quill_embed_helper.dart';
import 'package:penpeeper/widgets/custom_image_embed_builder.dart';

class CveEditModal extends StatefulWidget {
  final Map<String, dynamic> finding;
  final int projectId;
  final int deviceId;
  final VoidCallback onSaved;
  final String? projectName;

  const CveEditModal({
    super.key,
    required this.finding,
    required this.projectId,
    required this.deviceId,
    required this.onSaved,
    this.projectName,
  });

  @override
  State<CveEditModal> createState() => _CveEditModalState();
}

class _CveEditModalState extends State<CveEditModal> with TickerProviderStateMixin {
  late QuillController _commentController;
  late QuillController _evidenceController;
  late QuillController _recommendationController;
  late TabController _tabController;
  final FocusNode _commentFocusNode = FocusNode();
  final FocusNode _evidenceFocusNode = FocusNode();
  final FocusNode _recommendationFocusNode = FocusNode();
  final ScrollController _commentScrollController = ScrollController();
  final ScrollController _evidenceScrollController = ScrollController();
  final ScrollController _recommendationScrollController = ScrollController();
  List<Map<String, dynamic>> _taxonomyData = [];
  String? _selectedCategory;
  String? _selectedSubcategory;
  Map<String, dynamic>? _selectedSubcategoryData;
  String? _scope;
  bool _isLoading = true;
  Map<String, dynamic>? _existingClassification;
  String _projectName = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initializeControllers();
    _loadData();
  }

  void _initializeControllers() {
    debugPrint('=' * 80);
    debugPrint('🔧 [CVE Edit Modal] INITIALIZING FROM DETAILS TAB');
    debugPrint('=' * 80);
    
    final commentJson = widget.finding['comment'] as String? ?? '';
    final evidenceJson = widget.finding['evidence'] as String? ?? '';
    final recommendationJson = widget.finding['recommendation'] as String? ?? '';
    
    debugPrint('📝 [CVE Edit] Comment length: ${commentJson.length} chars');
    debugPrint('📝 [CVE Edit] Evidence length: ${evidenceJson.length} chars');
    debugPrint('📝 [CVE Edit] Recommendation length: ${recommendationJson.length} chars');
    
    if (evidenceJson.isNotEmpty) {
      debugPrint('📝 [CVE Edit] Evidence RAW: $evidenceJson');
    }
    
    try {
      debugPrint('📝 [CVE Edit] Converting comment...');
      final convertedComment = QuillEmbedHelper.convertDeltaJsonForWeb(commentJson);
      debugPrint('📝 [CVE Edit] Comment converted: ${convertedComment?.length ?? 0} chars');
      _commentController = convertedComment != null && convertedComment.isNotEmpty
          ? QuillController(
              document: Document.fromJson(jsonDecode(convertedComment)),
              selection: const TextSelection.collapsed(offset: 0),
              readOnly: false,
            )
          : QuillController.basic();
    } catch (e) {
      debugPrint('❌ [CVE Edit] Comment error: $e');
      _commentController = QuillController.basic();
      if (commentJson.isNotEmpty) {
        _commentController.document.insert(0, commentJson);
      }
    }

    try {
      debugPrint('📝 [CVE Edit] Converting evidence...');
      final convertedEvidence = QuillEmbedHelper.convertDeltaJsonForWeb(evidenceJson);
      debugPrint('📝 [CVE Edit] Evidence converted: ${convertedEvidence?.length ?? 0} chars');
      if (convertedEvidence != null && convertedEvidence.isNotEmpty) {
        debugPrint('📝 [CVE Edit] Evidence CONVERTED: $convertedEvidence');
      }
      _evidenceController = convertedEvidence != null && convertedEvidence.isNotEmpty
          ? QuillController(
              document: Document.fromJson(jsonDecode(convertedEvidence)),
              selection: const TextSelection.collapsed(offset: 0),
              readOnly: false,
            )
          : QuillController.basic();
    } catch (e) {
      debugPrint('❌ [CVE Edit] Evidence error: $e');
      _evidenceController = QuillController.basic();
      if (evidenceJson.isNotEmpty) {
        _evidenceController.document.insert(0, evidenceJson);
      }
    }

    try {
      debugPrint('📝 [CVE Edit] Converting recommendation...');
      final convertedRecommendation = QuillEmbedHelper.convertDeltaJsonForWeb(recommendationJson);
      debugPrint('📝 [CVE Edit] Recommendation converted: ${convertedRecommendation?.length ?? 0} chars');
      _recommendationController = convertedRecommendation != null && convertedRecommendation.isNotEmpty
          ? QuillController(
              document: Document.fromJson(jsonDecode(convertedRecommendation)),
              selection: const TextSelection.collapsed(offset: 0),
              readOnly: false,
            )
          : QuillController.basic();
    } catch (e) {
      debugPrint('❌ [CVE Edit] Recommendation error: $e');
      _recommendationController = QuillController.basic();
      if (recommendationJson.isNotEmpty) {
        _recommendationController.document.insert(0, recommendationJson);
      }
    }

    // Add listeners to update tab indicators when content changes
    _commentController.addListener(() => setState(() {}));
    _evidenceController.addListener(() => setState(() {}));
    _recommendationController.addListener(() => setState(() {}));
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadTaxonomyData(),
      _loadExistingClassification(),
      _loadProjectName(),
    ]);
    _autoPopulateScope();
    setState(() => _isLoading = false);
  }

  Future<void> _loadProjectName() async {
    if (widget.projectName != null) {
      _projectName = widget.projectName!;
      return;
    }
    try {
      final projectRepo = ProjectRepository();
      final projects = await projectRepo.getProjects();
      final project = projects.firstWhere((p) => p.id == widget.projectId);
      _projectName = project.name;
    } catch (e) {
      debugPrint('Error loading project name: $e');
      _projectName = 'Unknown';
    }
  }

  Future<void> _loadTaxonomyData() async {
    try {
      final jsonString = await rootBundle.loadString('assets/vulnerability_taxonomy_full.json');
      final List<dynamic> data = json.decode(jsonString);
      _taxonomyData = data.cast<Map<String, dynamic>>();
    } catch (e) {
      debugPrint('Error loading taxonomy data: $e');
    }
  }

  Future<void> _loadExistingClassification() async {
    try {
      debugPrint('[CVE Edit] Loading existing classification for finding ID: ${widget.finding['id']}');
      debugPrint('[CVE Edit] Finding data keys: ${widget.finding.keys.toList()}');
      debugPrint('[CVE Edit] Finding category: ${widget.finding['category']}');
      
      // First check if classification data is already in the finding (from JOIN)
      if (widget.finding['category'] != null && widget.finding['category'] != '') {
        _selectedCategory = widget.finding['category'];
        _selectedSubcategory = widget.finding['subcategory'];
        _scope = widget.finding['classification_scope'] ?? widget.finding['scope'];
        debugPrint('[CVE Edit] ✅ Loaded from finding JOIN: Category=$_selectedCategory, Subcategory=$_selectedSubcategory, Scope=$_scope');
        _updateSubcategoryData();
        return;
      }
      
      // Otherwise query the vulnerability_classifications table
      debugPrint('[CVE Edit] No classification in finding, querying...');
      
      Map<String, dynamic>? classification;
      
      if (kIsWeb) {
        // Direct API call for web to avoid repository issues
        debugPrint('[CVE Edit] Using direct API call for web...');
        try {
          final response = await http.get(Uri.parse('/api/vulnerability-classifications/${widget.finding['id']}'));
          debugPrint('[CVE Edit] API response status: ${response.statusCode}');
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            debugPrint('[CVE Edit] API response data type: ${data.runtimeType}');
            debugPrint('[CVE Edit] API response data: $data');
            if (data != null && data is Map) {
              classification = Map<String, dynamic>.from(data);
              debugPrint('[CVE Edit] Direct API returned: $classification');
            }
          }
        } catch (apiError, stackTrace) {
          debugPrint('[CVE Edit] Direct API error: $apiError');
          debugPrint('[CVE Edit] Stack: $stackTrace');
        }
      } else {
        // Use database directly for desktop
        try {
          final db = await DatabaseConnection().database;
          final results = await db.query(
            'vulnerability_classifications',
            where: 'finding_id = ?',
            whereArgs: [widget.finding['id']],
            orderBy: 'created_at DESC',
            limit: 1,
          );
          classification = results.isNotEmpty ? results.first : null;
          debugPrint('[CVE Edit] Database returned: $classification');
        } catch (dbError) {
          debugPrint('[CVE Edit] Database error: $dbError');
        }
      }
      
      if (classification != null) {
        _existingClassification = classification;
        _selectedCategory = classification['category'] as String?;
        _selectedSubcategory = classification['subcategory'] as String?;
        _scope = classification['scope'] as String?;
        debugPrint('[CVE Edit] ✅ Loaded: Category=$_selectedCategory, Subcategory=$_selectedSubcategory, Scope=$_scope');
        _updateSubcategoryData();
      } else {
        debugPrint('[CVE Edit] ❌ No classification found');
      }
    } catch (e, stackTrace) {
      debugPrint('[CVE Edit] ❌ Error loading classification: $e');
      debugPrint('[CVE Edit] Stack trace: $stackTrace');
    }
  }

  void _autoPopulateScope() {
    if (_scope != null) return;
    final attackVector = widget.finding['attack_vector'] as String?;
    if (attackVector != null) {
      switch (attackVector.toUpperCase()) {
        case 'NETWORK':
          _scope = 'NETWORK';
          break;
        case 'ADJACENT_NETWORK':
          _scope = 'ADJACENT';
          break;
        case 'LOCAL':
          _scope = 'LOCAL';
          break;
        case 'PHYSICAL':
          _scope = 'PHYSICAL';
          break;
        default:
          _scope = 'NETWORK';
      }
    } else {
      _scope = 'NETWORK';
    }
  }

  void _updateSubcategoryData() {
    if (_selectedCategory == null || _selectedSubcategory == null) return;
    final category = _taxonomyData.firstWhere(
      (item) => item['Category'] == _selectedCategory,
      orElse: () => {},
    );
    if (category.isEmpty) return;
    final subcategories = (category['Subcategories'] as List).cast<Map<String, dynamic>>();
    _selectedSubcategoryData = subcategories.firstWhere(
      (item) => item['Subcategory'] == _selectedSubcategory,
      orElse: () => {},
    );
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

  Color _getSeverityColor(String? severity) {
    if (severity == null) return Colors.grey;
    switch (severity.toUpperCase()) {
      case 'CRITICAL':
        return Colors.red;
      case 'HIGH':
        return Colors.orange;
      case 'MEDIUM':
        return Colors.yellow;
      case 'LOW':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Future<void> _save() async {
    try {
      debugPrint('=== CVE SAVE DEBUG START ===');
      debugPrint('Finding ID: ${widget.finding['id']}');
      debugPrint('Finding Type: ${widget.finding['type']}');
      
      // Force unfocus to ensure all controllers commit their changes
      _commentFocusNode.unfocus();
      _evidenceFocusNode.unfocus();
      _recommendationFocusNode.unfocus();
      
      // Wait a frame to ensure all changes are committed
      await Future.delayed(const Duration(milliseconds: 50));
      
      final findingsRepo = FindingsRepository();
      debugPrint('Repository instance created');
      
      final commentJson = jsonEncode(_commentController.document.toDelta().toJson());
      final evidenceJson = jsonEncode(_evidenceController.document.toDelta().toJson());
      final recommendationJson = jsonEncode(_recommendationController.document.toDelta().toJson());
      debugPrint('JSON data prepared - Comment: ${commentJson.length} chars, Evidence: ${evidenceJson.length} chars, Recommendation: ${recommendationJson.length} chars');
      
      debugPrint('Step 1: Updating flagged finding...');
      await findingsRepo.updateFlaggedFinding(widget.finding['id'], widget.finding['type'], commentJson);
      debugPrint('Step 1: SUCCESS - Flagged finding updated');
      
      debugPrint('Step 2: Updating evidence...');
      await findingsRepo.updateFlaggedFindingEvidence(widget.finding['id'], evidenceJson);
      debugPrint('Step 2: SUCCESS - Evidence updated');
      
      debugPrint('Step 3: Updating recommendation...');
      await findingsRepo.updateFlaggedFindingRecommendation(widget.finding['id'], recommendationJson);
      debugPrint('Step 3: SUCCESS - Recommendation updated');

      // Save classification if selected
      if (_selectedCategory != null && _selectedSubcategory != null && _selectedSubcategoryData != null && _scope != null) {
        debugPrint('Step 4: Processing classification...');
        debugPrint('Category: $_selectedCategory, Subcategory: $_selectedSubcategory, Scope: $_scope');
        
        if (kIsWeb) {
          // Web: Use API calls
          if (_existingClassification != null) {
            debugPrint('Step 4a: Deleting existing classification ID: ${_existingClassification!['id']}');
            await http.delete(Uri.parse('/api/vulnerability-classifications/${_existingClassification!['id']}'));
            debugPrint('Step 4a: SUCCESS - Existing classification deleted');
          }
          
          debugPrint('Step 4b: Inserting new classification...');
          await http.post(
            Uri.parse('/api/vulnerability-classifications'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'project_id': widget.projectId,
              'device_id': widget.deviceId,
              'finding_id': widget.finding['id'],
              'category': _selectedCategory!,
              'subcategory': _selectedSubcategory!,
              'description': _selectedSubcategoryData!['Description'] ?? '',
              'mapped_owasp': _selectedSubcategoryData!['Mapped_OWASP'] ?? '',
              'mapped_cwe': _selectedSubcategoryData!['Mapped_CWE'] ?? '',
              'severity_guideline': _selectedSubcategoryData!['Severity_Guideline'] ?? '',
              'scope': _scope!,
            }),
          );
          debugPrint('Step 4b: SUCCESS - New classification inserted');
        } else {
          // Desktop: Use database directly
          final db = await DatabaseConnection().database;
          
          if (_existingClassification != null) {
            debugPrint('Step 4a: Deleting existing classification ID: ${_existingClassification!['id']}');
            await db.delete(
              'vulnerability_classifications',
              where: 'id = ?',
              whereArgs: [_existingClassification!['id']],
            );
            debugPrint('Step 4a: SUCCESS - Existing classification deleted');
          }
          
          debugPrint('Step 4b: Inserting new classification...');
          await db.insert('vulnerability_classifications', {
            'project_id': widget.projectId,
            'device_id': widget.deviceId,
            'finding_id': widget.finding['id'],
            'category': _selectedCategory!,
            'subcategory': _selectedSubcategory!,
            'description': _selectedSubcategoryData!['Description'] ?? '',
            'mapped_owasp': _selectedSubcategoryData!['Mapped_OWASP'] ?? '',
            'mapped_cwe': _selectedSubcategoryData!['Mapped_CWE'] ?? '',
            'severity_guideline': _selectedSubcategoryData!['Severity_Guideline'] ?? '',
            'scope': _scope!,
            'created_at': DateTime.now().toIso8601String(),
          });
          debugPrint('Step 4b: SUCCESS - New classification inserted');
        }
      } else {
        debugPrint('Step 4: SKIPPED - No classification data to save');
      }

      debugPrint('Step 5: Updating cache...');
      final updatedFinding = Map<String, dynamic>.from(widget.finding);
      updatedFinding['comment'] = commentJson;
      updatedFinding['evidence'] = evidenceJson;
      updatedFinding['recommendation'] = recommendationJson;
      ProjectDataCache().updateFindingUpdated(updatedFinding);
      debugPrint('Step 5: SUCCESS - Cache updated');

      debugPrint('=== CVE SAVE DEBUG SUCCESS ===');
      if (mounted) {
        widget.onSaved();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('CVE updated successfully'), backgroundColor: Colors.green),
        );
      }
    } catch (e, stackTrace) {
      debugPrint('=== CVE SAVE DEBUG ERROR ===');
      debugPrint('Error: $e');
      debugPrint('Stack trace: $stackTrace');
      debugPrint('=== CVE SAVE DEBUG ERROR END ===');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _evidenceController.dispose();
    _recommendationController.dispose();
    _tabController.dispose();
    _commentFocusNode.dispose();
    _evidenceFocusNode.dispose();
    _recommendationFocusNode.dispose();
    _commentScrollController.dispose();
    _evidenceScrollController.dispose();
    _recommendationScrollController.dispose();
    super.dispose();
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
    final cvssVersion = widget.finding['cvss_version'] as String? ?? '';
    final cvssScore = widget.finding['cvss_base_score'] as double?;
    final severity = widget.finding['cvss_severity'] as String?;
    final vulnType = widget.finding['vulnerability_type'] as String?;
    final url = widget.finding['url'] as String?;

    return GradientBorderContainer(
      borderConfig: AppTheme.borderPrimaryGradient ?? AppTheme.borderPrimary,
      borderRadius: 8,
      borderWidth: 2,
      backgroundColor: AppTheme.surfaceColor,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (cvssScore != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getSeverityColor(severity).withValues(alpha: 0.2),
                  border: Border.all(color: _getSeverityColor(severity)),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(color: _getSeverityColor(severity)),
                    children: [
                      const TextSpan(text: 'CVSS V'),
                      TextSpan(text: cvssVersion),
                      const TextSpan(text: '  '),
                      TextSpan(
                        text: cvssScore.toStringAsFixed(1),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            if (severity != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getSeverityColor(severity),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  severity.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 12),
            ],
            if (vulnType != null) ...[
              Expanded(
                child: Text(
                  vulnType,
                  style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            if (url != null) ...[
              const SizedBox(width: 12),
              IconButton(
                icon: Icon(Icons.open_in_new, color: AppTheme.primaryColor),
                onPressed: () => launchUrl(Uri.parse(url)),
                tooltip: 'Open URL',
              ),
            ],
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
                  if (_isControllerEmpty(_commentController)) ...[
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
                  Flexible(
                    child: Text('Recommendation', overflow: TextOverflow.ellipsis),
                  ),
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
              _buildQuillEditor(_commentController),
              _buildQuillEditor(_evidenceController),
              _buildQuillEditor(_recommendationController),
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
    
    if (controller == _commentController) {
      focusNode = _commentFocusNode;
      scrollController = _commentScrollController;
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
                projectName: _projectName,
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
          Text('Category', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          GradientBorderContainer(
            borderConfig: AppTheme.borderPrimaryGradient ?? AppTheme.borderPrimary,
            borderRadius: 8,
            borderWidth: 1,
            backgroundColor: AppTheme.surfaceColor,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedCategory,
                hint: Text('Select', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                isExpanded: true,
                dropdownColor: AppTheme.surfaceColor,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
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
          Text('Subcategory', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          GradientBorderContainer(
            borderConfig: AppTheme.borderPrimaryGradient ?? AppTheme.borderPrimary,
            borderRadius: 8,
            borderWidth: 1,
            backgroundColor: AppTheme.surfaceColor,
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedSubcategory,
                hint: Text('Select', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                isExpanded: true,
                dropdownColor: AppTheme.surfaceColor,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 12),
                items: _subcategories.map((sub) => DropdownMenuItem(value: sub['Subcategory'] as String, child: Text(sub['Subcategory'] as String))).toList(),
                onChanged: _selectedCategory == null ? null : (value) {
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
                border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                _selectedSubcategoryData!['Description'] ?? '',
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 11),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Text('Scope', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          ..._buildScopeRadios(),
        ],
      ),
    );
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
        onTap: () => setState(() => _scope = scope.$1),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Radio<String>(
                value: scope.$1,
                groupValue: _scope,
                activeColor: AppTheme.primaryColor,
                onChanged: (value) => setState(() => _scope = value),
              ),
              Expanded(
                child: Tooltip(
                  message: scope.$2,
                  child: Text(scope.$1, style: TextStyle(color: AppTheme.textPrimary, fontSize: 11)),
                ),
              ),
            ],
          ),
        ),
      );
    }).toList();
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
        ),
        const SizedBox(width: 12),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

