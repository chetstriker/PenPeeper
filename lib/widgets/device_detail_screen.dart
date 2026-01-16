import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:penpeeper/repositories/project_repository.dart';
import 'package:penpeeper/models.dart';
import 'package:penpeeper/theme_config.dart';
import 'package:penpeeper/widgets/scans_section.dart';
import 'package:penpeeper/widgets/device_details_section.dart';
import 'package:penpeeper/quill_flag_dialog.dart';
import 'package:penpeeper/widgets/finding_type_dialog.dart';
import 'package:penpeeper/widgets/cve_search_modal.dart';
import 'package:penpeeper/widgets/move_device_dialog.dart';
import 'package:penpeeper/models/cvss/cvss_data.dart';
import 'package:penpeeper/repositories/findings_repository.dart';
import 'package:penpeeper/repositories/tag_repository.dart';
import 'package:penpeeper/repositories/device_repository.dart';
import 'package:penpeeper/repositories/vulnerability_repository.dart';
import 'package:penpeeper/services/project_data_cache.dart';

class DeviceDetailScreen extends StatefulWidget {
  final Device device;
  final VoidCallback onDataChanged;
  final Function(int deviceId)? onDeviceMoved;

  const DeviceDetailScreen({
    super.key,
    required this.device,
    required this.onDataChanged,
    this.onDeviceMoved,
  });

  @override
  State<DeviceDetailScreen> createState() => DeviceDetailScreenState();
}

class DeviceDetailScreenState extends State<DeviceDetailScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final Map<String, TextEditingController> _controllers = {};
  final List<String> sections = ['DETAILS', 'SCANS'];
  final _deviceRepo = DeviceRepository();
  final _findingsRepo = FindingsRepository();
  final _tagRepo = TagRepository();
  final _projectRepo = ProjectRepository();
  static int _persistentTabIndex = 0;
  List<String> _tags = [];
  List<String> _allProjectTags = [];
  final _tagController = TextEditingController();
  int _refreshKey = 0;
  String _projectName = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: sections.length, vsync: this, initialIndex: _persistentTabIndex);
    _tabController.addListener(() {
      _persistentTabIndex = _tabController.index;
    });
    _initializeControllers();
  }

  Future<void> _initializeControllers() async {
    for (String section in sections) {
      final content = await _deviceRepo.getDeviceData(widget.device.id, section);
      _controllers[section] = TextEditingController(text: content);
      _controllers[section]!.addListener(() {
        widget.onDataChanged();
        _saveData(section);
      });
    }
    _tags = await _tagRepo.getDeviceTags(widget.device.id);
    _allProjectTags = await _tagRepo.getAllProjectTags(widget.device.projectId);

    // Load project name
    final projects = await _projectRepo.getProjects();
    final project = projects.firstWhere((p) => p.id == widget.device.projectId);
    _projectName = project.name;

    if (mounted) setState(() {});
  }

  Future<void> _saveData(String section) async {
    final content = _controllers[section]?.text ?? '';
    await _deviceRepo.saveDeviceData(widget.device.id, section, content);
  }

  Future<void> saveAllData() async {
    for (String section in sections) {
      if (_controllers[section] != null) {
        await _saveData(section);
      }
    }
  }

  @override
  void dispose() {
    for (var controller in _controllers.values) {
      controller.dispose();
    }
    _tagController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            border: Border(
              bottom: BorderSide(
                color: AppTheme.textTertiary,
                width: 2.0,
              ),
            ),
          ),
          child: Row(
            children: [
              TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: AppTheme.primaryColor,
                dividerColor: Colors.transparent,
                tabs: sections.map((section) => Tab(text: section)).toList(),
              ),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _tags.map((tag) => Container(
                      margin: const EdgeInsets.only(left: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tag,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Remove Tag'),
                                  content: Text('Are you sure you want to remove the tag "$tag"?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Remove'),
                                    ),
                                  ],
                                ),
                              );
                                if (confirm == true) {
                                  debugPrint('DeviceDetailScreen: Removing tag $tag from device ${widget.device.id}');
                                  await _tagRepo.removeDeviceTag(widget.device.id, tag);
                                  
                                  debugPrint('DeviceDetailScreen: Reloading cache tags for project ${widget.device.projectId}');
                                  final cache = ProjectDataCache();
                                  await cache.reloadTags(widget.device.projectId);
                                  
                                  setState(() {
                                    _tags.remove(tag);
                                  });
                                }
                            },
                            child: const Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ],
                      ),
                    )).toList(),
                  ),
                ),
              ),
              SizedBox(
                width: 120,
                height: 32,
                child: Autocomplete<String>(
                  optionsBuilder: (textEditingValue) {
                    if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
                    final query = textEditingValue.text.toUpperCase();
                    return _allProjectTags.where((tag) => tag.contains(query) && !_tags.contains(tag));
                  },
                  onSelected: (value) async {
                    if (!_tags.contains(value)) {
                      debugPrint('DeviceDetailScreen: Adding tag $value to device ${widget.device.id}');
                      await _tagRepo.addDeviceTag(widget.device.id, value);
                      
                      debugPrint('DeviceDetailScreen: Reloading cache tags for project ${widget.device.projectId}');
                      final cache = ProjectDataCache();
                      await cache.reloadTags(widget.device.projectId);
                      
                      setState(() {
                        _tags.add(value);
                        if (!_allProjectTags.contains(value)) _allProjectTags.add(value);
                      });
                    }
                  },
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    _tagController.text = controller.text;
                    controller.addListener(() => _tagController.text = controller.text);
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      style: TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Add tag...',
                        hintStyle: const TextStyle(color: Colors.grey, fontSize: 12),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(color: AppTheme.primaryColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(4),
                          borderSide: BorderSide(color: AppTheme.primaryColor),
                        ),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.add, size: 16),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onPressed: () async {
                            final value = controller.text.trim().toUpperCase();
                            if (value.isNotEmpty && !_tags.contains(value)) {
                              debugPrint('DeviceDetailScreen: Adding tag $value to device ${widget.device.id}');
                              await _tagRepo.addDeviceTag(widget.device.id, value);
                              
                              debugPrint('DeviceDetailScreen: Reloading cache tags for project ${widget.device.projectId}');
                              final cache = ProjectDataCache();
                              await cache.reloadTags(widget.device.projectId);
                              
                              setState(() {
                                _tags.add(value);
                                if (!_allProjectTags.contains(value)) _allProjectTags.add(value);
                                controller.clear();
                              });
                            }
                          },
                        ),
                      ),
                      onSubmitted: (value) async {
                        final trimmed = value.trim().toUpperCase();
                        if (trimmed.isNotEmpty && !_tags.contains(trimmed)) {
                          debugPrint('DeviceDetailScreen: Adding tag $trimmed to device ${widget.device.id}');
                          await _tagRepo.addDeviceTag(widget.device.id, trimmed);
                          
                          debugPrint('DeviceDetailScreen: Reloading cache tags for project ${widget.device.projectId}');
                          final cache = ProjectDataCache();
                          await cache.reloadTags(widget.device.projectId);
                          
                          setState(() {
                            _tags.add(trimmed);
                            if (!_allProjectTags.contains(trimmed)) _allProjectTags.add(trimmed);
                            controller.clear();
                          });
                        }
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Tooltip(
                  message: 'Move Device to Other Project',
                  child: ElevatedButton(
                    onPressed: () => _moveDevice(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Icon(Icons.drive_file_move, color: Colors.white, size: 18),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 16),
                child: Tooltip(
                  message: 'Add Flag',
                  child: ElevatedButton(
                    onPressed: () => _flagDevice(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(AppTheme.addIcon, color: Colors.white, size: 18),
                        const SizedBox(width: 4),
                        Icon(AppTheme.flagIcon, color: Colors.white, size: 18),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            physics: const NeverScrollableScrollPhysics(),
            children: sections.map((section) {
              if (section == 'DETAILS') {
                return DeviceDetailsSection(
                  key: ValueKey(_refreshKey),
                  device: widget.device,
                  onIconChanged: () => setState(() {}),
                );
              }
              if (section == 'SCANS') {
                return ScansSection(
                  device: widget.device,
                  onDataChanged: widget.onDataChanged,
                  projectName: _projectName,
                );
              }
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.borderPrimary),
                  ),
                  child: Focus(
                    onKeyEvent: (node, event) {
                      if ((HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed) && event is KeyDownEvent) {
                        if (event.logicalKey == LogicalKeyboardKey.keyA) {
                          _controllers[section]?.selection = TextSelection(baseOffset: 0, extentOffset: _controllers[section]?.text.length ?? 0);
                          return KeyEventResult.handled;
                        } else if (event.logicalKey == LogicalKeyboardKey.keyC) {
                          final selectedText = _controllers[section]?.selection.textInside(_controllers[section]?.text ?? '') ?? '';
                          if (selectedText.isNotEmpty) {
                            Clipboard.setData(ClipboardData(text: selectedText));
                          }
                          return KeyEventResult.handled;
                        }
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller: _controllers[section],
                      maxLines: null,
                      expands: true,
                      style: const TextStyle(color: Color(0xFFE0E0E0)),
                      decoration: InputDecoration(
                        hintText: 'Enter $section information...',
                        hintStyle: const TextStyle(color: Color(0xFF888888)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(12),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Future<void> _flagDevice() async {
    final findingType = await showDialog<String>(
      context: context,
      builder: (context) => const FindingTypeDialog(),
    );

    if (findingType == null) return;

    if (findingType == 'CVE') {
      await _addCve();
    } else {
      await _addManualFinding();
    }
  }

  Future<void> _addManualFinding() async {
    final projects = await _projectRepo.getProjects();
    final project = projects.firstWhere((p) => p.id == widget.device.projectId);
    final projectName = project.name;

    final flagResult = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => QuillFlagDialog(
        deviceName: widget.device.name,
        projectName: projectName,
        onSubmit: (type, content) {},
      ),
    );

    if (flagResult != null) {
      final id = await _findingsRepo.insertFlaggedFinding(
        widget.device.id,
        widget.device.name,
        widget.device.ipAddress,
        flagResult['type'],
        flagResult['comment'],
        findingType: 'MANUAL',
        projectId: widget.device.projectId,
      );

      if (flagResult['evidence'] != null) {
        await _findingsRepo.updateFlaggedFindingEvidence(
          id,
          flagResult['evidence'],
        );
      }
      
      if (flagResult['recommendation'] != null) {
        await _findingsRepo.updateFlaggedFindingRecommendation(
          id,
          flagResult['recommendation'],
        );
      }

      if (flagResult['cvssData'] != null) {
        final cvss = flagResult['cvssData'] as CvssData;
        await _findingsRepo.updateFlaggedFindingCvss(
          id,
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
      
      if (flagResult['classification'] != null) {
        final classification = flagResult['classification'] as Map<String, dynamic>;
        final vulnRepo = VulnerabilityRepository();
        if (classification['category'] != null && classification['subcategory'] != null && classification['scope'] != null) {
          await vulnRepo.insertVulnerabilityClassification(
            projectId: widget.device.projectId,
            deviceId: widget.device.id,
            findingId: id,
            category: classification['category'],
            subcategory: classification['subcategory'],
            description: '',
            mappedOwasp: '',
            mappedCwe: '',
            severityGuideline: '',
            scope: classification['scope'],
          );
        }
      }

      setState(() => _refreshKey++);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Finding added successfully')),
      );
    }
  }

  Future<void> _addCve() async{
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => CveSearchModal(
        deviceId: widget.device.id,
        projectId: widget.device.projectId,
      ),
    );

    if (result != null) {
      await _findingsRepo.insertFlaggedFinding(
        widget.device.id,
        widget.device.name,
        widget.device.ipAddress,
        'CVE',
        result['description'] ?? '',
        findingType: 'CVE',
        projectId: widget.device.projectId,
        cveId: result['cveId'],
        confidenceLevel: result['confidenceLevel'],
        vulnerabilityType: result['vulnerabilityType'],
        url: result['url'],
        cvssVersion: result['cvssVersion'],
        attackVector: result['attackVector'],
        attackComplexity: result['attackComplexity'],
        privilegesRequired: result['privilegesRequired'],
        userInteraction: result['userInteraction'],
        scope: result['scope'],
        confidentialityImpact: result['confidentialityImpact'],
        integrityImpact: result['integrityImpact'],
        availabilityImpact: result['availabilityImpact'],
        cvssBaseScore: result['cvssScore'],
        cvssSeverity: result['cvssSeverity'],
      );

      setState(() => _refreshKey++);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CVE added successfully')),
      );
    }
  }

  Future<void> _moveDevice() async {
    try {
      // Get all projects
      final projects = await _projectRepo.getProjects();

      // Show the move device dialog
      final selectedProjectId = await showDialog<int>(
        context: context,
        builder: (context) => MoveDeviceDialog(
          projects: projects,
          currentProjectId: widget.device.projectId,
        ),
      );

      // If user cancelled or didn't select a project, return
      if (selectedProjectId == null) return;

      // Show loading indicator
      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      // Move the device to the new project
      await _deviceRepo.moveDeviceToProject(widget.device.id, selectedProjectId);

      // Close loading indicator
      if (!mounted) return;
      Navigator.of(context).pop();

      // Show success message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Device moved successfully')),
      );

      // Notify parent that device was moved
      if (widget.onDeviceMoved != null) {
        widget.onDeviceMoved!(widget.device.id);
      } else {
        // Fallback to old behavior if callback not provided
        widget.onDataChanged();
      }

    } catch (e) {
      // Close loading indicator if it's showing
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      // Show error message
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to move device: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }
}
