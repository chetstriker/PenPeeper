import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:penpeeper/quill_flag_dialog.dart';
import 'package:penpeeper/theme_config.dart';
import 'package:penpeeper/models/cvss/cvss_data.dart';
import 'package:penpeeper/widgets/gradient_border_container.dart';
import 'package:penpeeper/services/project_data_cache.dart';
import 'package:penpeeper/widgets/cve_edit_modal.dart';
import 'package:penpeeper/widgets/finding_type_dialog.dart';
import 'package:penpeeper/widgets/cve_search_modal.dart';
import 'package:penpeeper/repositories/findings_repository.dart';
import 'package:penpeeper/repositories/vulnerability_repository.dart';
import 'package:penpeeper/utils/quill_embed_helper.dart';
import 'package:penpeeper/widgets/custom_image_embed_builder.dart';

class DeviceFindingsModal extends StatefulWidget {
  final String deviceName;
  final String ipAddress;
  final int deviceId;
  final List<Map<String, dynamic>> existingFindings;
  final VoidCallback onFindingAdded;
  final String projectName;
  final int projectId;

  const DeviceFindingsModal({
    super.key,
    required this.deviceName,
    required this.ipAddress,
    required this.deviceId,
    required this.existingFindings,
    required this.onFindingAdded,
    required this.projectName,
    required this.projectId,
  });

  @override
  State<DeviceFindingsModal> createState() => _DeviceFindingsModalState();
}

class _DeviceFindingsModalState extends State<DeviceFindingsModal> {
  final _findingsRepo = FindingsRepository();
  final _vulnerabilityRepo = VulnerabilityRepository();
  List<Map<String, dynamic>> findings = [];

  @override
  void initState() {
    super.initState();
    findings = List.from(widget.existingFindings);
  }

  Future<void> _addNewFinding() async {
    // First show the finding type dialog
    final findingType = await showDialog<String>(
      context: context,
      builder: (context) => const FindingTypeDialog(),
    );
    
    if (findingType == null) return;
    
    if (findingType == 'CVE') {
      final cveResult = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => CveSearchModal(
          deviceId: widget.deviceId,
          projectId: widget.projectId,
        ),
      );
      
      if (cveResult != null) {
        final findingId = await _findingsRepo.insertFlaggedFinding(
          widget.deviceId,
          widget.deviceName,
          widget.ipAddress,
          'CVE',
          cveResult['description'],
          findingType: 'CVE',
          projectId: widget.projectId,
          cveId: cveResult['cveId'],
          confidenceLevel: cveResult['confidenceLevel'],
          vulnerabilityType: cveResult['vulnerabilityType'],
          url: cveResult['url'],
          cvssVersion: cveResult['cvssVersion'],
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
        
        final updatedFindings = (await _findingsRepo.getFlaggedFindingsForDevice(widget.deviceId)).map((f) => f.toMap()).toList();
        setState(() => findings = updatedFindings);
        
        final completeFinding = updatedFindings.firstWhere((f) => f['id'] == findingId);
        ProjectDataCache().updateFindingAdded(completeFinding);
        
        widget.onFindingAdded();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('CVE ${cveResult['cveId']} added successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
      return;
    }
    
    final flagResult = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => QuillFlagDialog(
        deviceName: widget.deviceName,
        onSubmit: (type, content) {},
        projectName: widget.projectName,
      ),
    );

    if (flagResult != null) {
      final findingId = await _findingsRepo.insertFlaggedFinding(
        widget.deviceId,
        widget.deviceName,
        widget.ipAddress,
        flagResult['type'],
        flagResult['comment'],
        findingType: 'MANUAL',
        projectId: widget.projectId,
      );
      
      // Save evidence and recommendation if provided
      if (flagResult['evidence'] != null && flagResult['evidence'].toString().isNotEmpty) {
        await _findingsRepo.updateFlaggedFindingEvidence(findingId, flagResult['evidence']);
      }
      if (flagResult['recommendation'] != null && flagResult['recommendation'].toString().isNotEmpty) {
        await _findingsRepo.updateFlaggedFindingRecommendation(findingId, flagResult['recommendation']);
      }
      
      // Save classification if provided
      if (flagResult['classification'] != null) {
        final classification = flagResult['classification'] as Map<String, dynamic>;
        if (classification['category'] != null && classification['subcategory'] != null) {
          try {
            // Check for existing classification first
            final existing = await _vulnerabilityRepo.getVulnerabilityClassifications(findingId);
            if (existing.isNotEmpty) {
              await _vulnerabilityRepo.deleteVulnerabilityClassification(existing.first.toMap()['id']);
            }
            
            final jsonString = await rootBundle.loadString('assets/vulnerability_taxonomy_full.json');
            final List<dynamic> taxonomyData = json.decode(jsonString);
            final category = taxonomyData.firstWhere((item) => item['Category'] == classification['category'], orElse: () => {});
            if (category.isNotEmpty) {
              final subcategories = (category['Subcategories'] as List).cast<Map<String, dynamic>>();
              final subcategoryData = subcategories.firstWhere((item) => item['Subcategory'] == classification['subcategory'], orElse: () => {});
              if (subcategoryData.isNotEmpty) {
                await _vulnerabilityRepo.insertVulnerabilityClassification(
                  projectId: widget.projectId,
                  deviceId: widget.deviceId,
                  findingId: findingId,
                  category: classification['category'],
                  subcategory: classification['subcategory'],
                  description: subcategoryData['Description'] ?? '',
                  mappedOwasp: subcategoryData['Mapped_OWASP'] ?? '',
                  mappedCwe: subcategoryData['Mapped_CWE'] ?? '',
                  severityGuideline: subcategoryData['Severity_Guideline'] ?? '',
                  scope: classification['scope'] ?? 'NETWORK',
                );
              }
            }
          } catch (e) {
            debugPrint('Error saving new finding classification: $e');
          }
        }
      }
      
      if (flagResult['cvssData'] != null) {
        final cvss = flagResult['cvssData'] as CvssData;
        await _findingsRepo.updateFlaggedFindingCvss(
          findingId,
          attackVector: cvss.attackVector?.name,
          attackComplexity: cvss.attackComplexity?.name,
          privilegesRequired: cvss.privilegesRequired?.name,
          userInteraction: cvss.userInteraction?.name,
          scope: cvss.scope?.name,
          confidentialityImpact: cvss.confidentialityImpact?.name,
          integrityImpact: cvss.integrityImpact?.name,
          availabilityImpact: cvss.availabilityImpact?.name,
          cvssBaseScore: cvss.baseScore,
          cvssSeverity: cvss.severity?.name,
        );
      }

      // Refresh findings list from database to get complete data including CVSS
      final updatedFindings = (await _findingsRepo.getFlaggedFindingsForDevice(widget.deviceId)).map((f) => f.toMap()).toList();
      setState(() {
        findings = updatedFindings;
      });

      // Update cache with complete finding data
      final completeFinding = updatedFindings.firstWhere((f) => f['id'] == findingId);
      ProjectDataCache().updateFindingAdded(completeFinding);

      widget.onFindingAdded();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Finding added successfully')),
        );
      }
    }
  }

  Future<void> _deleteFinding(Map<String, dynamic> finding) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        title: Text('Delete Finding', style: TextStyle(color: AppTheme.textPrimary)),
        content: Text('Are you sure you want to delete this finding?', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.deleteButtonColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _findingsRepo.deleteFlaggedFinding(finding['id']);

      // Update cache immediately
      ProjectDataCache().updateFindingDeleted(finding['id'], widget.deviceId);

      // Refresh findings list
      final updatedFindings = (await _findingsRepo.getFlaggedFindingsForDevice(widget.deviceId)).map((f) => f.toMap()).toList();
      setState(() {
        findings = updatedFindings;
      });

      widget.onFindingAdded();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Finding deleted successfully')),
        );
      }
    }
  }

  Future<void> _editFinding(Map<String, dynamic> finding) async {
    final findingType = finding['finding_type'] as String? ?? finding['type'] as String?;
    
    if (findingType == 'CVE' || finding['cve_id'] != null) {
      await showDialog(
        context: context,
        builder: (context) => CveEditModal(
          finding: finding,
          projectId: widget.projectId,
          deviceId: widget.deviceId,
          onSaved: () async {
            final updatedFindings = (await _findingsRepo.getFlaggedFindingsForDevice(widget.deviceId)).map((f) => f.toMap()).toList();
            setState(() => findings = updatedFindings);
            final completeFinding = updatedFindings.firstWhere((f) => f['id'] == finding['id']);
            ProjectDataCache().updateFindingUpdated(completeFinding);
            widget.onFindingAdded();
          },
        ),
      );
      return;
    }

    final cvssData = CvssData.fromDatabase(finding);
    final flagResult = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => QuillFlagDialog(
        deviceName: widget.deviceName,
        onSubmit: (type, content) {},
        initialComment: finding['comment'],
        initialType: finding['type'],
        isEditing: true,
        projectName: widget.projectName,
        initialCvssData: cvssData,
        initialEvidence: finding['evidence'],
        initialRecommendation: finding['recommendation'],
        findingId: finding['id'],
        projectId: widget.projectId,
        deviceId: widget.deviceId,
      ),
    );

    if (flagResult != null) {
      await _findingsRepo.updateFlaggedFinding(
        finding['id'],
        flagResult['type'],
        flagResult['comment'],
      );
      
      // Update evidence and recommendation if provided
      if (flagResult['evidence'] != null) {
        await _findingsRepo.updateFlaggedFindingEvidence(finding['id'], flagResult['evidence']);
      }
      if (flagResult['recommendation'] != null) {
        await _findingsRepo.updateFlaggedFindingRecommendation(finding['id'], flagResult['recommendation']);
      }
      
      // Save classification if provided
      if (flagResult['classification'] != null) {
        final classification = flagResult['classification'] as Map<String, dynamic>;
        if (classification['category'] != null && classification['subcategory'] != null) {
          try {
            // Check for existing classification first
            final existing = await _vulnerabilityRepo.getVulnerabilityClassifications(finding['id']);
            if (existing.isNotEmpty) {
              await _vulnerabilityRepo.deleteVulnerabilityClassification(existing.first.toMap()['id']);
            }
            
            final jsonString = await rootBundle.loadString('assets/vulnerability_taxonomy_full.json');
            final List<dynamic> taxonomyData = json.decode(jsonString);
            final category = taxonomyData.firstWhere((item) => item['Category'] == classification['category'], orElse: () => {});
            if (category.isNotEmpty) {
              final subcategories = (category['Subcategories'] as List).cast<Map<String, dynamic>>();
              final subcategoryData = subcategories.firstWhere((item) => item['Subcategory'] == classification['subcategory'], orElse: () => {});
              if (subcategoryData.isNotEmpty) {
                await _vulnerabilityRepo.insertVulnerabilityClassification(
                  projectId: widget.projectId,
                  deviceId: widget.deviceId,
                  findingId: finding['id'],
                  category: classification['category'],
                  subcategory: classification['subcategory'],
                  description: subcategoryData['Description'] ?? '',
                  mappedOwasp: subcategoryData['Mapped_OWASP'] ?? '',
                  mappedCwe: subcategoryData['Mapped_CWE'] ?? '',
                  severityGuideline: subcategoryData['Severity_Guideline'] ?? '',
                  scope: classification['scope'] ?? 'NETWORK',
                );
              }
            }
          } catch (e) {
            debugPrint('Error saving updated finding classification: $e');
          }
        }
      }
      
      if (flagResult['cvssData'] != null) {
        final cvss = flagResult['cvssData'] as CvssData;
        await _findingsRepo.updateFlaggedFindingCvss(
          finding['id'],
          attackVector: cvss.attackVector?.name,
          attackComplexity: cvss.attackComplexity?.name,
          privilegesRequired: cvss.privilegesRequired?.name,
          userInteraction: cvss.userInteraction?.name,
          scope: cvss.scope?.name,
          confidentialityImpact: cvss.confidentialityImpact?.name,
          integrityImpact: cvss.integrityImpact?.name,
          availabilityImpact: cvss.availabilityImpact?.name,
          cvssBaseScore: cvss.baseScore,
          cvssSeverity: cvss.severity?.name,
        );
      }

      final updatedFindings = (await _findingsRepo.getFlaggedFindingsForDevice(widget.deviceId)).map((f) => f.toMap()).toList();
      setState(() => findings = updatedFindings);
      final completeFinding = updatedFindings.firstWhere((f) => f['id'] == finding['id']);
      ProjectDataCache().updateFindingUpdated(completeFinding);
      widget.onFindingAdded();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Finding updated successfully')),
        );
      }
    }
  }

  String _formatDateTime(String isoString) {
    try {
      final dateTime = DateTime.parse(isoString);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return isoString;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'Issue':
        return Colors.red;
      case 'Needs Investigating':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'Issue':
        return AppTheme.errorIcon;
      case 'Needs Investigating':
        return AppTheme.searchIcon;
      default:
        return AppTheme.flagIcon;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: SizedBox(
        width: 800,
        height: 600,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(AppTheme.flagIcon, color: Colors.black, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.deviceName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                        Text(
                          '${findings.length} finding${findings.length != 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _addNewFinding,
                    icon: Icon(AppTheme.addIcon, size: 18),
                    label: const Text('Add New Finding'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),

            // Findings List
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(20),
                child: findings.isEmpty
                    ? Center(
                        child: Text(
                          'No findings yet',
                          style: TextStyle(
                            color: AppTheme.textTertiary,
                            fontSize: 16,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: findings.length,
                        itemBuilder: (context, index) {
                          final finding = findings[index];
                          final type = finding['type'] as String;
                          final comment = finding['comment'] as String;
                          final createdAt = finding['created_at'] as String;

                          return GradientBorderContainer(
                            borderConfig: _getTypeColor(type).withValues(alpha: 0.3),
                            borderRadius: 8,
                            borderWidth: 1,
                            backgroundColor: AppTheme.cardBackground,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Header with type and date
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _getTypeColor(type).withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              _getTypeIcon(type),
                                              size: 14,
                                              color: _getTypeColor(type),
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              type,
                                              style: TextStyle(
                                                color: _getTypeColor(type),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        _formatDateTime(createdAt),
                                        style: TextStyle(
                                          color: AppTheme.iconSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        onPressed: () => _editFinding(finding),
                                        icon: Icon(AppTheme.editIcon, size: 18),
                                        color: AppTheme.primaryColor,
                                        tooltip: 'Edit',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        onPressed: () => _deleteFinding(finding),
                                        icon: Icon(AppTheme.deleteIcon, size: 18),
                                        color: AppTheme.deleteButtonColor,
                                        tooltip: 'Delete',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  
                                  // Comment content
                                  GradientBorderContainer(
                                    borderConfig: AppTheme.borderSecondaryGradient ?? AppTheme.borderSecondary,
                                    borderRadius: 6,
                                    borderWidth: 1,
                                    backgroundColor: AppTheme.surfaceColor,
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      child: _buildCommentContent(comment),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Color(0xFF4A4A4A), width: 1),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentContent(String comment) {
    try {
      final convertedComment = QuillEmbedHelper.convertDeltaJsonForWeb(comment);
      final delta = jsonDecode(convertedComment ?? comment);
      final document = Document.fromJson(delta);
      
      // Always show the full QuillEditor with proper embed builders
      final controller = QuillController(
        document: document,
        selection: const TextSelection.collapsed(offset: 0),
      );
      
      return QuillEditor(
        controller: controller,
        focusNode: FocusNode(),
        scrollController: ScrollController(),
        config: QuillEditorConfig(
          padding: EdgeInsets.zero,
          embedBuilders: [
            CustomImageEmbedBuilder(),
            ...FlutterQuillEmbeds.editorBuilders(),
          ],
        ),
      );
    } catch (e) {
      // Fallback to plain text if JSON parsing fails
      return SelectableText(
        comment,
        style: const TextStyle(
          color: Color(0xFFE0E0E0),
          fontSize: 14,
          height: 1.4,
        ),
      );
    }
  }
}


