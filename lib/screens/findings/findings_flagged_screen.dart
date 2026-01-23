import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:penpeeper/repositories/findings_repository.dart';
import 'package:penpeeper/repositories/vulnerability_repository.dart';
import 'package:penpeeper/repositories/settings_repository.dart';
import 'package:penpeeper/services/project_data_cache.dart';
import 'package:penpeeper/services/findings/findings_controller.dart';
import 'package:penpeeper/services/findings/findings_export_coordinator.dart';
import 'package:penpeeper/theme_config.dart';
import 'package:penpeeper/widgets/gradient_border_container.dart';
import 'package:penpeeper/widgets/findings/index.dart';
import 'package:penpeeper/widgets/cve_edit_modal.dart';
import 'package:penpeeper/quill_flag_dialog.dart';
import 'package:penpeeper/models/cvss/cvss_data.dart';
import 'package:penpeeper/widgets/common/decorated_dialog_title.dart';
import 'package:penpeeper/widgets/device_details_section.dart';
import 'package:penpeeper/models.dart';
import 'package:penpeeper/screens/project_screen.dart';
import 'package:penpeeper/models/llm_settings.dart';
import 'package:penpeeper/widgets/ai_device_search_modal.dart';

class FindingsFlaggedScreen extends StatefulWidget {
  final int projectId;
  final String projectName;
  final List<String> availableTags;

  const FindingsFlaggedScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.availableTags,
  });

  @override
  State<FindingsFlaggedScreen> createState() => _FindingsFlaggedScreenState();
}

class _FindingsFlaggedScreenState extends State<FindingsFlaggedScreen> {
  final TextEditingController _searchController = TextEditingController();
  final _findingsRepo = FindingsRepository();
  final _vulnRepo = VulnerabilityRepository();
  final _cache = ProjectDataCache();
  final _exportCoordinator = FindingsExportCoordinator();
  final _settingsRepo = SettingsRepository();
  late final FindingsController _findingsController;

  String searchType = 'HOST';
  String searchQuery = '';
  String selectedTag = '';
  String completionFilter = 'incomplete';
  List<Map<String, dynamic>> flaggedFindings = [];
  bool _showAIButton = false;

  @override
  void initState() {
    super.initState();
    _findingsController = FindingsController(widget.projectId);
    _refreshFlaggedFindings();
    _cache.addListener(_onCacheChanged);
    _checkLLMSettings();
  }

  Future<void> _checkLLMSettings() async {
    try {
      final settingsJson = await _settingsRepo.getSetting('llm_settings', '');
      if (settingsJson.isNotEmpty) {
        final settings = LLMSettings.fromJson(json.decode(settingsJson));
        setState(() {
          _showAIButton = settings.provider.name != 'none';
        });
      }
    } catch (e) {
      debugPrint('Error checking LLM settings: $e');
    }
  }

  Future<void> _openAISearchModal() async {
    try {
      final settingsJson = await _settingsRepo.getSetting('llm_settings', '');
      if (settingsJson.isEmpty) return;
      
      final settings = LLMSettings.fromJson(json.decode(settingsJson));
      if (!mounted) return;
      
      await showDialog(
        context: context,
        builder: (context) => AIDeviceSearchModal(
          projectId: widget.projectId,
          llmSettings: settings,
          onFindingAdded: _refreshFlaggedFindings,
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _onCacheChanged() {
    if (mounted) {
      _refreshFlaggedFindings();
    }
  }

  @override
  void dispose() {
    _cache.removeListener(_onCacheChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refreshFlaggedFindings() async {
    final findings = await _findingsController.getFlaggedFindings(completionFilter);
    if (!mounted) return;
    setState(() => flaggedFindings = findings);
  }

  Future<void> _filterFindingsByTag(String tag) async {
    final filteredFindings = await _findingsController.filterFindingsByTag(
      tag,
      completionFilter,
    );
    setState(() => flaggedFindings = filteredFindings);
  }

  Future<void> _performFindingsSearch() async {
    final filteredFindings = await _findingsController.searchFindings(
      searchQuery,
      searchType,
      completionFilter,
    );
    setState(() => flaggedFindings = filteredFindings);
  }

  Future<void> _editFlaggedFinding(Map<String, dynamic> finding) async {
    final findingType = finding['finding_type'] ?? 'MANUAL';

    if (findingType == 'CVE' || finding['cve_id'] != null) {
      await showDialog(
        context: context,
        builder: (context) => CveEditModal(
          finding: finding,
          projectId: widget.projectId,
          deviceId: finding['device_id'],
          onSaved: () async {
            await _findingsController.refreshCache();
            await _refreshFlaggedFindings();
          },
        ),
      );
      return;
    }

    final cvssData = CvssData.fromDatabase(finding);
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => QuillFlagDialog(
        deviceName: finding['device_name'],
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
        deviceId: finding['device_id'],
      ),
    );

    if (result != null) {
      await _findingsRepo.updateFlaggedFinding(
        finding['id'],
        result['type'],
        result['comment'],
      );

      if (result['evidence'] != null) {
        await _findingsRepo.updateFlaggedFindingEvidence(
          finding['id'],
          result['evidence'],
        );
      }
      if (result['recommendation'] != null) {
        await _findingsRepo.updateFlaggedFindingRecommendation(
          finding['id'],
          result['recommendation'],
        );
      }

      if (result['classification'] != null) {
        final classification = result['classification'] as Map<String, dynamic>;
        if (classification['category'] != null &&
            classification['subcategory'] != null) {
          try {
            final existing = await _vulnRepo.getVulnerabilityClassifications(
              finding['id'],
            );
            if (existing.isNotEmpty) {
              await _vulnRepo.deleteVulnerabilityClassification(
                existing.first.id,
              );
            }

            final jsonString = await rootBundle.loadString(
              'assets/vulnerability_taxonomy_full.json',
            );
            final List<dynamic> taxonomyData = json.decode(jsonString);
            final category = taxonomyData.firstWhere(
              (item) => item['Category'] == classification['category'],
              orElse: () => {},
            );
            if (category.isNotEmpty) {
              final subcategories = (category['Subcategories'] as List)
                  .cast<Map<String, dynamic>>();
              final subcategoryData = subcategories.firstWhere(
                (item) => item['Subcategory'] == classification['subcategory'],
                orElse: () => {},
              );
              if (subcategoryData.isNotEmpty) {
                await _vulnRepo.insertVulnerabilityClassification(
                  projectId: widget.projectId,
                  deviceId: finding['device_id'],
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

      if (result['cvssData'] != null) {
        final cvss = result['cvssData'] as CvssData;
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

      await _findingsController.refreshCache();
      await _refreshFlaggedFindings();
    }
  }

  Future<void> _deleteFlaggedFinding(Map<String, dynamic> finding) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(24, 9, 24, 0),
        title: const DecoratedDialogTitle('Delete Flagged Finding'),
        content: Text(
          'Are you sure you want to delete this flagged finding for "${finding['device_name']}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _findingsRepo.deleteFlaggedFinding(finding['id']);
      _cache.updateFindingDeleted(finding['id'], finding['device_id']);
      await _refreshFlaggedFindings();
    }
  }

  void _showDeviceInfo(Map<String, dynamic> device) async {
    final cachedDevice = _cache.devices.firstWhere(
      (d) => d.id == device['id'],
      orElse: () => Device(
        id: device['id'],
        projectId: widget.projectId,
        name: device['name'],
        ipAddress: device['ip_address'],
      ),
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Device Information - ${device['name']}'),
        content: SizedBox(
          width: 800,
          height: 600,
          child: DeviceDetailsSection(device: cachedDevice),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _jumpToDevice(Map<String, dynamic> device) {
    final projectState = context.findAncestorStateOfType<ProjectScreenState>();
    projectState?.jumpToDevice(device['id']);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppTheme.backgroundGradient,
        ),
      ),
      child: Column(
        children: [
          _buildSearchBar(),
          Expanded(child: _buildFindingsList()),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderPrimary),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          if (_showAIButton) ...[
            ElevatedButton.icon(
              onPressed: _openAISearchModal,
              icon: const Icon(Icons.psychology, size: 18),
              label: const Text('Search Devices With AI'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Stack(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildTagDropdown(),
                      const SizedBox(width: 16),
                      _buildSearchField(),
                      IconButton(
                        onPressed: _performFindingsSearch,
                        icon: Icon(Icons.search, color: AppTheme.primaryColor),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      width: 40,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            AppTheme.surfaceColor.withValues(alpha: 0.0),
                            AppTheme.surfaceColor,
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          WorkflowStatusDropdown(
            completionFilter: completionFilter,
            onChanged: (value) {
              setState(() {
                completionFilter = value;
                selectedTag = '';
              });
              _refreshFlaggedFindings();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTagDropdown() {
    return PopupMenuButton<String>(
      tooltip: 'Search by Tag',
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: AppTheme.searchTagBorderColor, width: 1),
            right: BorderSide(color: AppTheme.searchTagBorderColor, width: 1),
            bottom: BorderSide(color: AppTheme.searchTagBorderColor, width: 3),
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: ElevatedButton(
          onPressed: null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(AppTheme.searchTagIcon, color: AppTheme.searchTagIconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                'Search by Tag',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_drop_down,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                size: 20,
              ),
            ],
          ),
        ),
      ),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: '',
          child: Text('All Tags', style: TextStyle(fontWeight: FontWeight.w500)),
        ),
        const PopupMenuDivider(height: 1),
        ...widget.availableTags.expand(
          (tag) => [
            PopupMenuItem(value: tag, child: Text(tag)),
            if (tag != widget.availableTags.last) const PopupMenuDivider(height: 1),
          ],
        ),
      ],
      onSelected: (value) {
        setState(() => selectedTag = value);
        if (value.isNotEmpty) {
          _filterFindingsByTag(value);
        } else {
          _refreshFlaggedFindings();
        }
      },
    );
  }

  Widget _buildSearchField() {
    return Container(
      width: 300,
      constraints: const BoxConstraints(maxHeight: 36),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: Colors.white, width: 1),
          right: BorderSide(color: Colors.white, width: 1),
          top: BorderSide(color: Colors.white, width: 1),
          bottom: BorderSide(color: Colors.white, width: 3),
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Enter search term...',
          hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          isDense: true,
          suffixIcon: DropdownButton<String>(
            value: searchType == 'PORT' || searchType == 'SERVICE' ? 'HOST' : searchType,
            underline: const SizedBox(),
            icon: Icon(Icons.arrow_drop_down, color: AppTheme.textPrimary),
            items: [
              DropdownMenuItem(
                value: 'HOST',
                child: Text('HOST', style: TextStyle(color: AppTheme.textPrimary)),
              ),
              DropdownMenuItem(
                value: 'IP',
                child: Text('IP', style: TextStyle(color: AppTheme.textPrimary)),
              ),
            ],
            onChanged: (value) => setState(() => searchType = value!),
          ),
        ),
        onChanged: (value) => searchQuery = value,
        onSubmitted: (_) => _performFindingsSearch(),
      ),
    );
  }

  Widget _buildFindingsList() {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GradientBorderContainer(
            borderConfig: AppTheme.borderPrimaryGradient ?? AppTheme.borderPrimary,
            borderRadius: 8,
            borderWidth: 1,
            backgroundColor: AppTheme.surfaceColor,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.flag, color: AppTheme.textPrimary, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    '${flaggedFindings.length} Item${flaggedFindings.length != 1 ? 's' : ''} Found',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: AppTheme.fontWeightSemiBold,
                      fontSize: AppTheme.fontSizeBodyLarge,
                      fontFamily: AppTheme.defaultFontFamily.isEmpty
                          ? null
                          : AppTheme.defaultFontFamily,
                    ),
                  ),
                  const Spacer(),
                  Tooltip(
                    message: 'Export to RTF',
                    child: IconButton(
                      onPressed: () async {
                        if (flaggedFindings.isEmpty) return;
                        try {
                          final filePath = await _exportCoordinator.exportFlaggedFindingsToRTF(
                            flaggedFindings,
                          );
                          if (filePath != null && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Exported to $filePath')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Export failed: $e')),
                            );
                          }
                        }
                      },
                      icon: Icon(Icons.description, color: AppTheme.textPrimary, size: 16),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'Export to CSV',
                    child: IconButton(
                      onPressed: () async {
                        if (flaggedFindings.isEmpty) return;
                        try {
                          final filePath = await _exportCoordinator.exportFlaggedFindingsToCSV(
                            flaggedFindings,
                          );
                          if (filePath != null && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Exported to $filePath')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Export failed: $e')),
                            );
                          }
                        }
                      },
                      icon: Icon(Icons.file_download, color: AppTheme.textPrimary, size: 16),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (flaggedFindings.isEmpty)
            EmptyFindingsState(
              completionFilter: completionFilter,
              onShowAll: () {
                setState(() => completionFilter = 'all');
                _refreshFlaggedFindings();
              },
            )
          else
            Expanded(
              child: ListView.builder(
                itemCount: flaggedFindings.length,
                itemBuilder: (context, index) {
                  final finding = flaggedFindings[index];
                  return FlaggedFindingItem(
                    finding: finding,
                    projectId: widget.projectId,
                    onDeviceInfo: () => _showDeviceInfo({
                      'id': finding['device_id'],
                      'name': finding['device_name'],
                      'ip_address': finding['ip_address'],
                    }),
                    onJumpToDevice: () => _jumpToDevice({
                      'id': finding['device_id'],
                      'name': finding['device_name'],
                      'ip_address': finding['ip_address'],
                    }),
                    onFlagFinding: () {},
                    onEdit: () => _editFlaggedFinding(finding),
                    onDelete: () => _deleteFlaggedFinding(finding),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
