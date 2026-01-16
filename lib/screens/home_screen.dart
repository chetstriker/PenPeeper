import 'package:flutter/material.dart';
import 'package:penpeeper/models.dart';
import 'package:penpeeper/screens/project_screen.dart';
import 'package:penpeeper/widgets/decorated_dialog_title.dart';
import 'package:penpeeper/theme_config.dart';
import 'package:penpeeper/theme_loader.dart';
import 'package:penpeeper/repositories/project_repository.dart';
import 'package:penpeeper/repositories/settings_repository.dart';
import 'package:penpeeper/main.dart';
import 'package:penpeeper/widgets/gradient_button.dart';
import 'package:penpeeper/widgets/readiness_check_widget.dart';
import 'package:penpeeper/utils/error/error_handler.dart';
import 'package:penpeeper/widgets/export_import/export_dialog.dart';
import 'package:penpeeper/widgets/export_import/import_dialog.dart';
import 'package:penpeeper/widgets/project_screen/enhanced_status_bar.dart';
import 'package:package_info_plus/package_info_plus.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Project> projects = [];
  final _projectRepo = ProjectRepository();
  final _settingsRepo = SettingsRepository();
  List<String> availableThemes = [];
  String selectedTheme = 'default';
  final _scrollController = ScrollController();
  bool _showTopFade = false;
  bool _showBottomFade = false;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadProjects();
    _loadThemes();
    _loadSavedTheme();
    _loadVersion();
    _scrollController.addListener(_updateFadeState);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _updateFadeState() {
    if (!_scrollController.hasClients) return;
    setState(() {
      _showTopFade = _scrollController.offset > 0;
      _showBottomFade =
          _scrollController.offset < _scrollController.position.maxScrollExtent;
    });
  }

  Future<void> _loadVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = packageInfo.version;
        });
      }
    } catch (e) {
      debugPrint('Error loading version: $e');
    }
  }

  Future<void> _loadSavedTheme() async {
    final savedTheme = await _settingsRepo.getSetting('theme', 'default');
    setState(() {
      selectedTheme = savedTheme;
    });
  }

  Future<void> _loadThemes() async {
    final themes = await ThemeLoader.getAvailableThemes();
    setState(() {
      availableThemes = themes;
      if (!themes.contains(selectedTheme) && themes.isNotEmpty) {
        selectedTheme = themes.first;
      }
    });
  }

  Future<void> _loadProjects() async {
    try {
      final projectList = await _projectRepo.getProjects();
      setState(() {
        projects = projectList;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateFadeState());
    } catch (e, stack) {
      ErrorHandler.handle(e, stackTrace: stack, context: 'Load projects');
    }
  }

  Future<void> _createNewProject() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(24, 9, 24, 0),
        title: const DecoratedDialogTitle('New Project'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Project Name'),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      try {
        final project = await _projectRepo.insertProject(result);
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProjectScreen(project: project),
            ),
          ).then((_) => _loadProjects());
        }
      } catch (e, stack) {
        ErrorHandler.handle(
          e,
          stackTrace: stack,
          onUserMessage: mounted
              ? (msg) => ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(msg)))
              : null,
          context: 'Create project',
        );
      }
    }
  }

  Future<void> _renameProject(Project project) async {
    final controller = TextEditingController(text: project.name);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(24, 9, 24, 0),
        title: const DecoratedDialogTitle('Rename Project'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Project Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != project.name) {
      await _projectRepo.renameProject(project.id, result);
      _loadProjects();
    }
  }

  Future<void> _showExportDialog() async {
    if (projects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No projects to export')),
      );
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => ExportDialog(
        projects: projects.map((p) => {
          'id': p.id,
          'name': p.name,
          'updated_at': p.updatedAt.toString().split('.')[0],
        }).toList(),
      ),
    );
  }

  Future<void> _showImportDialog() async {
    await showDialog(
      context: context,
      builder: (context) => ImportDialog(
        onImportComplete: _loadProjects,
      ),
    );
  }

  Future<void> _deleteProject(Project project) async {
    debugPrint('=== DELETE PROJECT STARTED ===');
    debugPrint('Project ID: ${project.id}');
    debugPrint('Project Name: ${project.name}');
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(24, 9, 24, 0),
        title: const DecoratedDialogTitle('Delete Project'),
        content: Text(
          'Are you sure you want to delete "${project.name}"?\n\nThis will permanently delete the project and all associated devices, scans, and data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.errorColor),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    debugPrint('Dialog result: $result');
    
    if (result == true) {
      try {
        debugPrint('Calling deleteProject for ID: ${project.id}');
        await _projectRepo.deleteProject(project.id);
        debugPrint('deleteProject completed successfully');
        
        // Only remove from UI after successful database deletion
        if (mounted) {
          setState(() {
            projects.removeWhere((p) => p.id == project.id);
          });
        }
      } catch (e, stack) {
        debugPrint('ERROR deleting project: $e');
        debugPrint('Stack trace: $stack');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete project: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    } else {
      debugPrint('Delete cancelled by user');
    }
    debugPrint('=== DELETE PROJECT ENDED ===');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppTheme.backgroundGradient,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                height: constraints.maxHeight - 48,
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
                            border: Border.all(
                              color: AppTheme.primaryColor.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                          child: Icon(
                            AppTheme.appIcon,
                            color: AppTheme.primaryColor,
                            size: AppTheme.iconSizeXLarge,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'PenPeeper',
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeHeading,
                            fontWeight: AppTheme.fontWeightBold,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const Spacer(),
                        IntrinsicHeight(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.inputBackground,
                              borderRadius: BorderRadius.circular(
                                AppTheme.borderRadiusLarge,
                              ),
                              border: Border.all(color: AppTheme.borderPrimary),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.palette,
                                  color: AppTheme.primaryColor,
                                  size: AppTheme.iconSizeMedium,
                                ),
                                const SizedBox(width: 8),
                                DropdownButton<String>(
                                  value: selectedTheme,
                                  underline: const SizedBox(),
                                  dropdownColor: AppTheme.surfaceColor,
                                  isDense: true,
                                  icon: Icon(
                                    Icons.arrow_drop_down,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                                  style: TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 14,
                                  ),
                                  items: availableThemes.map((theme) {
                                    return DropdownMenuItem(
                                      value: theme,
                                      child: Text(theme),
                                    );
                                  }).toList(),
                                  onChanged: (value) async {
                                    if (value != null) {
                                      try {
                                        setState(() {
                                          selectedTheme = value;
                                        });
                                        await _settingsRepo.setSetting('theme', value);
                                        AppTheme.resetInitialized();
                                        await AppTheme.loadTheme(value);
                                        debugPrint('✓ Theme loaded successfully: $value');

                                        if (!context.mounted) return;

                                        // Force rebuild of entire app with new theme
                                        PenPeeperApp.of(context)?.rebuildApp();

                                        // Show success feedback
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Theme changed to: $value'),
                                            duration: const Duration(seconds: 2),
                                            backgroundColor: AppTheme.successColor,
                                          ),
                                        );
                                      } catch (e) {
                                        debugPrint('❌ Failed to load theme: $e');
                                        if (!context.mounted) return;

                                        // Show error to user
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Failed to load theme: $e'),
                                            duration: const Duration(seconds: 3),
                                            backgroundColor: AppTheme.errorColor,
                                          ),
                                        );

                                        // Revert selection
                                        setState(() {
                                          selectedTheme = AppTheme.currentThemeName;
                                        });
                                      }
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: const Icon(Icons.file_upload),
                          tooltip: 'Import Projects',
                          onPressed: _showImportDialog,
                        ),
                        IconButton(
                          icon: const Icon(Icons.file_download),
                          tooltip: 'Export Projects',
                          onPressed: _showExportDialog,
                        ),
                        const SizedBox(width: 8),
                        GradientButton(
                          label: 'New Project',
                          icon: AppTheme.addIcon,
                          backgroundConfig:
                              AppTheme.primaryButtonGradient ??
                              AppTheme.primaryColor,
                          onPressed: _createNewProject,
                          textColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 7,
                          ),
                          borderRadius: AppTheme.borderRadiusLarge,
                          iconSize: AppTheme.iconSizeMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 800),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 3,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: AppTheme.primaryGradient,
                                          ),
                                          borderRadius: BorderRadius.all(
                                            Radius.circular(2),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Projects',
                                        style: TextStyle(
                                          fontSize: AppTheme.fontSizeLargeTitle,
                                          fontWeight:
                                              AppTheme.fontWeightSemiBold,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  Expanded(
                                    child: projects.isEmpty
                                        ? Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(48),
                                            decoration: BoxDecoration(
                                              color: AppTheme.mediumBackground,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                    AppTheme.borderRadiusXLarge,
                                                  ),
                                              border: Border.all(
                                                color: AppTheme.borderSecondary,
                                                width: 1,
                                              ),
                                            ),
                                            child: Column(
                                              children: [
                                                Container(
                                                  padding: const EdgeInsets.all(
                                                    16,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme.primaryColor
                                                        .withValues(alpha: 0.1),
                                                    shape: BoxShape.circle,
                                                  ),
                                                  child: Icon(
                                                    AppTheme
                                                        .projectIconOutlined,
                                                    size: AppTheme
                                                        .iconSizeXXXLarge,
                                                    color:
                                                        AppTheme.primaryColor,
                                                  ),
                                                ),
                                                const SizedBox(height: 16),
                                                Text(
                                                  'No Projects Yet',
                                                  style: TextStyle(
                                                    fontSize:
                                                        AppTheme.fontSizeTitle,
                                                    fontWeight: AppTheme
                                                        .fontWeightSemiBold,
                                                    color: AppTheme.textPrimary,
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'Create your first penetration testing project to get started',
                                                  style: TextStyle(
                                                    fontSize: AppTheme
                                                        .fontSizeBodyLarge,
                                                    color: AppTheme.textMuted,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ],
                                            ),
                                          )
                                        : ShaderMask(
                                            shaderCallback: (bounds) {
                                              return LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  _showTopFade
                                                      ? Colors.transparent
                                                      : Colors.white,
                                                  Colors.white,
                                                  Colors.white,
                                                  _showBottomFade
                                                      ? Colors.transparent
                                                      : Colors.white,
                                                ],
                                                stops: const [
                                                  0.0,
                                                  0.05,
                                                  0.95,
                                                  1.0,
                                                ],
                                              ).createShader(bounds);
                                            },
                                            blendMode: BlendMode.dstIn,
                                            child: ListView.builder(
                                              controller: _scrollController,
                                              itemCount: projects.length,
                                              itemBuilder: (context, index) {
                                                final project = projects[index];
                                                return Container(
                                                  margin: const EdgeInsets.only(
                                                    bottom: 8,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppTheme
                                                        .mediumBackground,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          AppTheme
                                                              .borderRadiusLarge,
                                                        ),
                                                    border: Border.all(
                                                      color: AppTheme
                                                          .borderSecondary,
                                                      width: 1,
                                                    ),
                                                  ),
                                                  child: ListTile(
                                                    contentPadding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 16,
                                                          vertical: 8,
                                                        ),
                                                    leading: Container(
                                                      padding:
                                                          const EdgeInsets.all(
                                                            8,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: AppTheme
                                                            .primaryColor
                                                            .withValues(
                                                              alpha: 0.1,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              AppTheme
                                                                  .borderRadiusMedium,
                                                            ),
                                                      ),
                                                      child: Icon(
                                                        AppTheme.projectIcon,
                                                        color: AppTheme
                                                            .primaryColor,
                                                        size: AppTheme
                                                            .iconSizeLarge,
                                                      ),
                                                    ),
                                                    title: Text(
                                                      project.name,
                                                      style: TextStyle(
                                                        fontWeight: AppTheme
                                                            .fontWeightMedium,
                                                        color: AppTheme
                                                            .textPrimary,
                                                      ),
                                                    ),
                                                    subtitle: Text(
                                                      'Last updated: ${project.updatedAt.toString().split('.')[0]}',
                                                      style: TextStyle(
                                                        color:
                                                            AppTheme.textMuted,
                                                        fontSize: AppTheme
                                                            .fontSizeBody,
                                                      ),
                                                    ),
                                                    trailing: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        IconButton(
                                                          icon: Icon(
                                                            AppTheme.editIcon,
                                                            size: AppTheme
                                                                .iconSizeMedium,
                                                            color: AppTheme
                                                                .textTertiary,
                                                          ),
                                                          onPressed: () =>
                                                              _renameProject(
                                                                project,
                                                              ),
                                                        ),
                                                        IconButton(
                                                          icon: Icon(
                                                            AppTheme.deleteIcon,
                                                            size: AppTheme
                                                                .iconSizeMedium,
                                                            color: AppTheme
                                                                .textTertiary,
                                                          ),
                                                          onPressed: () =>
                                                              _deleteProject(
                                                                project,
                                                              ),
                                                        ),
                                                        Icon(
                                                          AppTheme
                                                              .arrowForwardIcon,
                                                          color: AppTheme
                                                              .primaryColor,
                                                          size: AppTheme
                                                              .iconSizeSmall,
                                                        ),
                                                      ],
                                                    ),
                                                    onTap: () {
                                                      if (context.mounted) {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (context) =>
                                                                ProjectScreen(
                                                                  project:
                                                                      project,
                                                                ),
                                                          ),
                                                        ).then(
                                                          (_) =>
                                                              _loadProjects(),
                                                        );
                                                      }
                                                    },
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 24),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0, right: 4.0),
                                child: Text(
                                  _version.isNotEmpty ? 'v$_version' : '',
                                  style: TextStyle(
                                    color: AppTheme.textMuted,
                                    fontSize: AppTheme.fontSizeSmall, // Changed from fontSizeBodySmall to fontSizeSmall
                                    fontWeight: AppTheme.fontWeightMedium,
                                  ),
                                ),
                              ),
                              const ReadinessCheckWidget(),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: const EnhancedStatusBar(),
    );
  }
}
