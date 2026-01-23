import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:penpeeper/repositories/device_repository.dart';
import 'package:penpeeper/repositories/scan_repository.dart';
import 'package:penpeeper/repositories/project_repository.dart';
import 'package:penpeeper/models.dart';
import 'package:penpeeper/api_database_helper.dart';

import 'package:penpeeper/services/scan_orchestrator.dart';
import 'package:penpeeper/services/scan_status_service.dart';
import 'package:penpeeper/services/project_data_cache.dart';
import 'package:penpeeper/services/project_data_loader.dart';
import 'package:penpeeper/services/readiness_check_service.dart';
import 'package:penpeeper/services/app_paths_service.dart';
import 'package:penpeeper/controllers/project_scan_controller.dart';
import 'package:penpeeper/services/scan_executor.dart';
import 'package:penpeeper/theme_config.dart';
import 'package:penpeeper/widgets/device_detail_screen.dart';
import 'package:penpeeper/widgets/empty_device_prompt.dart';
import 'package:penpeeper/widgets/macos_password_prompt.dart';
import 'package:penpeeper/utils/privileged_runner.dart';
import 'package:penpeeper/services/config_service.dart';
import 'package:penpeeper/widgets/decorated_dialog_title.dart' as widgets;
import 'package:penpeeper/screens/settings_screen.dart';
import 'package:penpeeper/screens/findings_screen.dart';
import 'package:penpeeper/screens/report_screen.dart';
import 'package:penpeeper/widgets/project_screen/device_list_sidebar.dart';
import 'package:penpeeper/widgets/project_screen/scan_toolbar.dart';
import 'package:penpeeper/widgets/project_screen/enhanced_status_bar.dart';
import 'package:penpeeper/services/status_notification_service.dart';
import 'package:penpeeper/widgets/gradient_button.dart';
import 'package:penpeeper/widgets/magic_button.dart';
import 'package:penpeeper/widgets/project_loading_modal.dart';
import 'package:penpeeper/utils/debug_logger.dart';
import 'package:penpeeper/utils/validation/validators.dart';
import 'package:penpeeper/widgets/non_device_title_dialog.dart';
import 'package:penpeeper/quill_flag_dialog.dart';
import 'package:penpeeper/repositories/findings_repository.dart';
import 'package:penpeeper/repositories/vulnerability_repository.dart';
import 'package:penpeeper/models/cvss/cvss_data.dart';

class ProjectScreen extends StatefulWidget {
  final Project project;

  const ProjectScreen({super.key, required this.project});

  @override
  State<ProjectScreen> createState() => ProjectScreenState();
}

class ProjectScreenState extends State<ProjectScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTab = 0;
  bool _showSettings = false;
  List<Device> devices = [];
  Device? selectedDevice;
  final _deviceRepo = DeviceRepository();
  final _scanRepo = ScanRepository();
  final _projectRepo = ProjectRepository();
  final _cache = ProjectDataCache();
  final _findingsRepo = FindingsRepository();
  final _vulnRepo = VulnerabilityRepository();
  late final ProjectScanController _scanController;

  GlobalKey<DeviceDetailScreenState>? _deviceDetailKey;
  bool isScanning = false;
  bool _cancelScan = false;
  String scanStatus = '';
  Set<int> failedDeviceIds = {};
  Map<int, Map<String, dynamic>> deviceMetadata = {};
  final Set<Process> _activeProcesses = {};
  final Set<String> tempFiles = {};
  final _scanOrchestrator = ScanOrchestrator();
  bool isLoadingDevices = false;
  String deviceLoadingStatus = '';
  int devicesLoaded = 0;
  int totalDevices = 0;
  final ScrollController _deviceListScrollController = ScrollController();
  int deviceCount = 0;
  bool hasDevices = false;
  bool hasNmapResults = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _selectedTab = _tabController.index;
          _showSettings = false;
        });
      }
    });
    _scanController = ProjectScanController(
      _scanOrchestrator,
      _scanRepo,
      _deviceRepo,
      _cache,
    );
    _initializeLogger();
    _cleanupOnStartup();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProjectData());
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkToolReadiness());
    _cache.addListener(_onCacheChanged);
  }

  void _onCacheChanged() {
    if (mounted) {
      setState(() {
        devices = _cache.devices;
        deviceMetadata = _cache.deviceMetadata;
        deviceCount = _cache.deviceCount;
      });
    }
  }

  Future<void> _initializeLogger() async {
    try {
      await DebugLogger().initialize();
      await DebugLogger().log(
        'PROJECT_SCREEN',
        'Project screen initialized for project: ${widget.project.name}',
      );
    } catch (e) {
      debugPrint('Failed to initialize logger: $e');
    }
  }

  Future<void> _checkToolReadiness() async {
    try {
      final readinessService = ReadinessCheckService();
      final status = await readinessService.checkSystemReadiness();

      if (!status.isReady && mounted) {
        // Get list of missing tools
        final missingTools = status.toolStatuses.entries
            .where((entry) => !entry.value)
            .map((entry) => entry.key)
            .toList();

        if (missingTools.isNotEmpty) {
          // Show warning message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Warning: Some scanning tools are not installed (${missingTools.join(', ')}). '
                'You might encounter errors when using the Magic Button or running scans. '
                'Please install any missing tools from the home page.',
              ),
              duration: const Duration(seconds: 8),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              action: SnackBarAction(
                label: 'Dismiss',
                textColor: Colors.white,
                onPressed: () {
                  if (mounted) {
                    ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  }
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Failed to check tool readiness: $e');
    }
  }

  void jumpToDevice(int deviceId) {
    setState(() {
      _selectedTab = 0;
      _tabController.index = 0;
      final targetDevice = devices.firstWhere(
        (d) => d.id == deviceId,
        orElse: () => Device(id: -1, projectId: -1, name: '', ipAddress: ''),
      );
      if (targetDevice.id != -1) {
        selectedDevice = targetDevice;
        _deviceDetailKey = GlobalKey<DeviceDetailScreenState>();
      }
    });
  }

  Future<void> _loadProjectData() async {
    final cache = ProjectDataCache();
    final loader = ProjectDataLoader();

    double progress = 0;
    String message = 'Initializing...';
    StateSetter? setModalState;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          setModalState = setState;
          return ProjectLoadingModal(progress: progress, message: message);
        },
      ),
    );

    try {
      await loader.loadProjectData(widget.project.id, (p, m) {
        progress = p;
        message = m;
        setModalState?.call(() {});
      });

      if (!mounted) return;
      Navigator.of(context).pop();

      // Check for NMap results
      final hasNmap = await _projectRepo.hasNmapResults(widget.project.id);

      setState(() {
        devices = cache.devices;
        deviceMetadata = cache.deviceMetadata;
        deviceCount = cache.deviceCount;
        hasDevices = devices.isNotEmpty;
        hasNmapResults = hasNmap;
      });
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to load project: $e')));
    }
  }

  @override
  void dispose() {
    _cleanup();
    _scanController.dispose();
    _deviceListScrollController.dispose();
    _tabController.dispose();
    _cache.removeListener(_onCacheChanged);
    ProjectDataCache().clear();
    DebugLogger().log('PROJECT_SCREEN', 'Project screen disposed');
    super.dispose();
  }

  void _cleanupOnStartup() async {
    if (kIsWeb) return;
    try {
      final tempDir = Directory(AppPathsService().tempScanDir);
      if (!await tempDir.exists()) {
        return; // Nothing to clean up
      }
      final files = tempDir.listSync().where((f) => f.path.contains('temp_'));
      for (final file in files) {
        try {
          file.deleteSync();
        } catch (e) {
          // Ignore errors when deleting temp files on startup
        }
      }
    } catch (e) {
      // Ignore errors when accessing directory
    }
  }

  void _cleanup() async {
    if (kIsWeb) return;
    await DebugLogger().log(
      'PROJECT_CLEANUP',
      'Starting project cleanup - ${_activeProcesses.length} processes, ${tempFiles.length} temp files',
    );

    for (final process in _activeProcesses) {
      try {
        await DebugLogger().log(
          'PROJECT_CLEANUP',
          'Killing process PID: ${process.pid}',
        );
        process.kill(ProcessSignal.sigterm);
        await Future.delayed(Duration(milliseconds: 500));
        process.kill(ProcessSignal.sigkill);
      } catch (e) {
        await DebugLogger().logError(
          'PROJECT_CLEANUP',
          'Error killing process: $e',
        );
      }
    }
    _activeProcesses.clear();

    for (final tempFile in tempFiles) {
      try {
        File(tempFile).deleteSync();
        await DebugLogger().log(
          'PROJECT_CLEANUP',
          'Deleted temp file: $tempFile',
        );
      } catch (e) {
        await DebugLogger().logError(
          'PROJECT_CLEANUP',
          'Error deleting temp file $tempFile: $e',
        );
      }
    }
    tempFiles.clear();

    await DebugLogger().log('PROJECT_CLEANUP', 'Project cleanup completed');
  }

  Future<void> loadDevices() async {
    try {
      await DebugLogger().log('LOAD_DEVICES', 'Loading devices from cache...');
      final cache = ProjectDataCache();
      await DebugLogger().log('LOAD_DEVICES', 'Cache retrieved, checking nmap results...');

      final hasNmap = await _projectRepo.hasNmapResults(widget.project.id);
      await DebugLogger().log('LOAD_DEVICES', 'Has nmap results: $hasNmap, device count: ${cache.deviceCount}');

      if (!mounted) {
        await DebugLogger().log('LOAD_DEVICES', 'Widget not mounted, skipping setState');
        return;
      }

      await DebugLogger().log('LOAD_DEVICES', 'Updating UI state with loaded devices...');
      setState(() {
        devices = cache.devices;
        deviceMetadata = cache.deviceMetadata;
        deviceCount = cache.deviceCount;
        hasDevices = devices.isNotEmpty;
        hasNmapResults = hasNmap;
      });
      await DebugLogger().log('LOAD_DEVICES', 'UI state updated successfully');
    } catch (e, stackTrace) {
      await DebugLogger().logError('LOAD_DEVICES', 'Failed to load devices: $e', stackTrace);
      rethrow;
    }
  }

  Future<void> _showAutomateScanDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          final input = controller.text.trim();
          final ipValid = Validators.validateIP(input).isValid;
          final cidrValid = Validators.validateCIDR(input).isValid;
          final isValid = input.isNotEmpty && (ipValid || cidrValid);
          final showError = input.isNotEmpty && !isValid;

          return AlertDialog(
            titlePadding: const EdgeInsets.fromLTRB(24, 9, 24, 0),
            title: const widgets.DecoratedDialogTitle('Automate Scan'),
            content: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: controller,
                    autofocus: true,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (value) {
                      if (isValid) Navigator.pop(context, value);
                    },
                    decoration: const InputDecoration(
                      hintText: '127.0.0.1, 127.0.0.0/24',
                      labelText: 'IP Address or CIDR Network Range',
                    ),
                  ),
                  if (showError)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'Invalid IP address or CIDR range',
                        style: TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, null),
                child: const Text('CANCEL'),
              ),
              GradientButton(
                label: 'BEGIN',
                backgroundConfig:
                    AppTheme.primaryButtonGradient ?? AppTheme.primaryColor,
                onPressed: isValid
                    ? () => Navigator.pop(context, controller.text)
                    : null,
                textColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
            ],
          );
        },
      ),
    );

    if (result != null && result.isNotEmpty) {
      _startAutomatedScan(result);
    }
  }

  Future<void> _startAutomatedScan(String target) async {
    // Save scan range
    await _projectRepo.insertScanRange(widget.project.id, target);
    // Prompt for password if needed (works for both desktop and web)
    if (!PrivilegedRunner.hasPassword) {
      final hasPassword = await MacOSPasswordPrompt.promptIfNeeded(context);
      if (!hasPassword) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Administrator access required for scanning')),
          );
        }
        return;
      }
    }
    
    // For web mode, send password to server
    if (kIsWeb && PrivilegedRunner.hasPassword) {
      await _sendPasswordToServer(PrivilegedRunner.sessionPassword!);
    }
    
    final scanId = ScanStatusService().startScan(
      scanType: 'ADD DEVICE',
      totalDevices: 1,
    );
    ScanStatusService().updateScanMessage('ADD DEVICE', 'Scanning $target...');

    setState(() {
      isScanning = true;
      scanStatus = 'Scanning $target...';
    });

    try {
      if (kIsWeb) {
        final response = await http.post(
          Uri.parse('${ApiDatabaseHelper.baseUrl}/projects/${widget.project.id}/scan-hosts'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'target': target}),
        );
        if (response.statusCode == 200) {
          final cache = ProjectDataCache();
          await cache.reloadDevices(widget.project.id);
          await loadDevices();
          ScanStatusService().completeScan(scanId);
          if (mounted) {
            setState(() {
              isScanning = false;
              scanStatus = 'Scan completed successfully';
            });
          }
        } else {
          throw Exception('Scan failed');
        }
      } else {
        try {
          final logger = DebugLogger();
          await logger.log('AUTOMATED_SCAN', 'Running host discovery scan for: $target');
          await logger.flush(); // Force write to disk

          final result = await _runNmapScan(target);

          await logger.log('AUTOMATED_SCAN', 'Host discovery completed, processing results...');
          await logger.log('AUTOMATED_SCAN', 'Result length: ${result.length} characters');
          await logger.flush(); // Force write to disk

          await logger.log('AUTOMATED_SCAN', 'About to call _processHostDiscoveryResults...');
          await logger.flush(); // Force write to disk

          await _processHostDiscoveryResults(result);

          await logger.log('AUTOMATED_SCAN', 'Host discovery processing completed');
          await logger.flush(); // Force write to disk

          ScanStatusService().completeScan(scanId);
          if (mounted) {
            setState(() {
              isScanning = false;
              scanStatus = 'Scan completed successfully';
            });
          }

          // await logger.log('AUTOMATED_SCAN', 'Starting automated device scans...');
          // await logger.flush(); // Force write to disk

          // // Start device scans after host discovery completes
          // await _startAutomatedDeviceScans(forcedOption: 'All');
          // await logger.log('AUTOMATED_SCAN', 'Automated device scans initiated');
        } catch (e, stackTrace) {
          final logger = DebugLogger();
          await logger.logError('AUTOMATED_SCAN', 'CRASH CAUGHT: $e', stackTrace);
          await logger.flush(); // Force write to disk
          rethrow;
        }
      }
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            scanStatus = '';
          });
        }
      });
    } catch (e, stackTrace) {
      await DebugLogger().logError('AUTOMATED_SCAN', 'Scan failed: $e', stackTrace);
      ScanStatusService().completeScan(scanId);
      if (mounted) {
        setState(() {
          isScanning = false;
          scanStatus = 'Scan failed: $e';
        });
      }
    }
  }

  Future<String> _runNmapScan(String target) async {
    return await _scanOrchestrator.runHostDiscoveryScan(target);
  }

  Future<void> _processHostDiscoveryResults(String jsonResults) async {
    try {
      await DebugLogger().log('HOST_DISCOVERY', 'Processing host discovery results...');

      final newHosts = await _scanOrchestrator.processHostDiscoveryResults(
        jsonResults,
        devices,
      );
      await DebugLogger().log('HOST_DISCOVERY', 'Found ${newHosts.length} new hosts');

      await DebugLogger().log('HOST_DISCOVERY', 'Adding discovered hosts to database...');
      await _scanOrchestrator.addDiscoveredHosts(widget.project.id, newHosts);
      await DebugLogger().log('HOST_DISCOVERY', 'Hosts added successfully');

      await DebugLogger().log('HOST_DISCOVERY', 'Reloading device cache...');
      final cache = ProjectDataCache();
      await cache.reloadDevices(widget.project.id);
      await DebugLogger().log('HOST_DISCOVERY', 'Cache reloaded');

      await DebugLogger().log('HOST_DISCOVERY', 'Loading devices into UI...');
      await loadDevices();
      await DebugLogger().log('HOST_DISCOVERY', 'Devices loaded successfully');
    } catch (e, stackTrace) {
      await DebugLogger().logError('HOST_DISCOVERY', 'Failed to process scan results: $e', stackTrace);
      throw Exception('Failed to process scan results: $e');
    }
  }

  Future<void> _startAutomatedDeviceScans({String? forcedOption}) async {
    await DebugLogger().log(
      'AUTOMATED_SCAN',
      'Starting automated device scans',
    );

    // Prompt for password if needed (works for both desktop and web)
    if (!PrivilegedRunner.hasPassword) {
      final hasPassword = await MacOSPasswordPrompt.promptIfNeeded(context);
      if (!hasPassword) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Administrator access required for scanning')),
          );
        }
        return;
      }
    }

    // For web mode, send password to server
    if (kIsWeb && PrivilegedRunner.hasPassword) {
      await _sendPasswordToServer(PrivilegedRunner.sessionPassword!);
    }

    if (devices.isEmpty) {
      await DebugLogger().log('AUTOMATED_SCAN', 'No devices to scan');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No devices to scan')));
      }
      return;
    }

    String? scanOption;
    if (forcedOption != null) {
      await DebugLogger().log('AUTOMATED_SCAN', 'Using forced scan option: $forcedOption');
      scanOption = forcedOption;
    } else {
      await DebugLogger().log('AUTOMATED_SCAN', 'Prompting user for scan option...');
      scanOption = await _getScanOption('AUTO NMAP');
      if (scanOption == null) {
        await DebugLogger().log('AUTOMATED_SCAN', 'Scan cancelled by user');
        return;
      }
      await DebugLogger().log('AUTOMATED_SCAN', 'User selected scan option: $scanOption');
    }

    await DebugLogger().log('AUTOMATED_SCAN', 'Filtering devices by scan option...');
    await DebugLogger().log('AUTOMATED_SCAN', 'Total devices available: ${devices.length}');

    List<Device> devicesToScan = await _filterDevicesByScanOption(
      devices,
      'AUTO NMAP',
      scanOption,
    );
    await DebugLogger().log('AUTOMATED_SCAN', 'Devices to scan after filtering: ${devicesToScan.length}');

    if (devicesToScan.isEmpty) {
      await DebugLogger().log('AUTOMATED_SCAN', 'All devices already scanned');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All devices have already been scanned'),
          ),
        );
      }
      return;
    }

    await DebugLogger().log(
      'AUTOMATED_SCAN',
      'Starting scan of ${devicesToScan.length} devices with option: $scanOption',
    );

    await DebugLogger().log('AUTOMATED_SCAN', 'Adding status notification...');
    await DebugLogger().flush();

    final notificationId = StatusNotificationService().addNotification(
      'Running automated scans on ${devicesToScan.length} devices...',
    );
    await DebugLogger().log('AUTOMATED_SCAN', 'Notification added successfully: $notificationId');

    await DebugLogger().log('AUTOMATED_SCAN', 'Updating UI state...');
    await DebugLogger().flush();

    setState(() {
      isScanning = true;
      _cancelScan = false;
      scanStatus =
          'Running automated scans on ${devicesToScan.length} devices...';
      failedDeviceIds.clear();
    });
    await DebugLogger().log('AUTOMATED_SCAN', 'UI state updated successfully');

    try {
      await DebugLogger().log('AUTOMATED_SCAN', 'Resetting scan orchestrator cancels...');
      _scanOrchestrator.resetAllCancels();
      await DebugLogger().log('AUTOMATED_SCAN', 'Calling runAutomatedDeviceScans...');

      final result = await _scanOrchestrator.runAutomatedDeviceScans(
        widget.project.id,
        devicesToScan,
        scanOption == 'replace',
        (status) {
          StatusNotificationService().updateNotification(
            notificationId,
            status,
          );
          if (mounted) {
            // Defer setState to avoid calling during build/setState phase
            // Use Future.microtask instead of SchedulerBinding (works better in packaged macOS apps)
            Future.microtask(() {
              if (mounted) {
                setState(() {
                  scanStatus = status;
                });
              }
            });
          }
        },
      );

      await DebugLogger().log('AUTOMATED_SCAN', 'runAutomatedDeviceScans completed');
      await DebugLogger().flush();

      await DebugLogger().log('AUTOMATED_SCAN', 'Starting _processNmapResults...');
      await DebugLogger().flush();
      await _processNmapResults();
      await DebugLogger().log('AUTOMATED_SCAN', '_processNmapResults completed');
      await DebugLogger().flush();

      await DebugLogger().log('AUTOMATED_SCAN', 'Reloading devices from cache...');
      await DebugLogger().flush();
      final cache = ProjectDataCache();
      await cache.reloadDevices(widget.project.id);
      await loadDevices();
      await DebugLogger().log('AUTOMATED_SCAN', 'Devices reloaded successfully');
      await DebugLogger().flush();

      StatusNotificationService().removeNotification(notificationId);

      await DebugLogger().log(
        'AUTOMATED_SCAN',
        'Scan batch completed - ${result['completed']} successful, ${result['failed']} failed',
      );
      await DebugLogger().flush();

      if (mounted) {
        setState(() {
          isScanning = false;
          if (_cancelScan) {
            scanStatus =
                'Scan cancelled - ${result['completed']} completed, ${result['failed']} failed';
          } else if (result['failed'] == 0) {
            scanStatus =
                'All ${result['completed']} scans completed successfully';
          } else {
            scanStatus =
                '${result['completed']} scans completed, ${result['failed']} failed';
          }
        });
      }
    } catch (e, stackTrace) {
      await DebugLogger().logError(
        'AUTOMATED_SCAN',
        'Automated scan error: $e',
        stackTrace,
      );
      StatusNotificationService().removeNotification(notificationId);
      if (mounted) {
        setState(() {
          isScanning = false;
          scanStatus = 'Scan failed: $e';
        });
      }
    }

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) setState(() => scanStatus = '');
    });
  }

  Future<void> _processNmapResults() async {
    setState(() {
      scanStatus = 'Processing nmap results...';
    });

    try {
      final result = await _scanOrchestrator.processNmapResults(
        widget.project.id,
        (status) {
          if (mounted) {
            // Defer setState to avoid calling during build/setState phase
            // Use Future.microtask instead of SchedulerBinding (works better in packaged macOS apps)
            Future.microtask(() {
              if (mounted) {
                setState(() {
                  scanStatus = status;
                });
              }
            });
          }
        },
      );

      setState(() {
        if (result['failed'] == 0) {
          scanStatus =
              'Processed ${result['processed']} nmap results successfully';
        } else {
          scanStatus =
              'Processed ${result['processed']} nmap results, ${result['failed']} failed';
        }
      });
    } catch (e) {
      setState(() {
        scanStatus = 'Failed to process nmap results: $e';
      });
    }
  }

  Future<String?> _getScanOption(String scanType) async {
    bool hasExistingScans = false;
    for (final device in devices) {
      final scans = await _scanRepo.getScans(device.id);
      if (scans.any((scan) => scan.scanType == scanType)) {
        hasExistingScans = true;
        break;
      }
    }

    if (!hasExistingScans) return 'replace';

    return await showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(24, 9, 24, 0),
        title: widgets.DecoratedDialogTitle('$scanType Scans'),
        content: Text(
          'Choose how to handle existing $scanType scans:',
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'replace'),
            child: const Text('Replace existing Scans'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'skip'),
            child: const Text('Skip devices that have already been scanned'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<List<Device>> _filterDevicesByScanOption(
    List<Device> devices,
    String scanType,
    String scanOption,
  ) async {
    if (scanOption == 'replace') return devices;

    final scannedDeviceIds = <int>{};
    for (final device in devices) {
      final scans = await _scanRepo.getScans(device.id);
      if (scans.any((scan) => scan.scanType == scanType)) {
        scannedDeviceIds.add(device.id);
      }
    }
    return devices
        .where((device) => !scannedDeviceIds.contains(device.id))
        .toList();
  }

  Future<void> _executeScan(
    ScanStrategy strategy, {
    String? forcedOption,
  }) async {
    await DebugLogger().log(
      'SCAN_EXECUTE',
      '>>> Starting ${strategy.scanType} scan <<<',
    );
    await DebugLogger().flush();

    if (devices.isEmpty) {
      await DebugLogger().log('SCAN_EXECUTE', 'No devices to scan - aborting');
      await DebugLogger().flush();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No devices to scan')));
      }
      return;
    }

    await DebugLogger().log('SCAN_EXECUTE', '${strategy.scanType}: ${devices.length} devices available');
    await DebugLogger().flush();

    // Prompt for password on macOS/Linux/Web if needed for all scans
    if (ConfigService.isMacOS || ConfigService.isLinux || kIsWeb) {
      await DebugLogger().log('SCAN_EXECUTE', '${strategy.scanType}: Running on ${ConfigService.isMacOS ? 'macOS' : 'Linux'}');
      await DebugLogger().flush();

      if (!PrivilegedRunner.hasPassword) {
        await DebugLogger().log('SCAN_EXECUTE', '${strategy.scanType}: No password cached');
        await DebugLogger().flush();

        await DebugLogger().log('SCAN_EXECUTE', '${strategy.scanType}: Requesting admin password...');
        await DebugLogger().flush();

        final hasPassword = await MacOSPasswordPrompt.promptIfNeeded(context);

        if (!hasPassword) {
          await DebugLogger().log('SCAN_EXECUTE', '${strategy.scanType}: Password prompt cancelled');
          await DebugLogger().flush();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Administrator access required for scanning')),
            );
          }
          return;
        }

        await DebugLogger().log('SCAN_EXECUTE', '${strategy.scanType}: Password obtained');
        await DebugLogger().flush();
      } else {
        await DebugLogger().log('SCAN_EXECUTE', '${strategy.scanType}: Password already cached');
        await DebugLogger().flush();
      }
      
      // For web mode, send password to server
      if (kIsWeb && PrivilegedRunner.hasPassword) {
        await _sendPasswordToServer(PrivilegedRunner.sessionPassword!);
      }
    }

    await DebugLogger().log('SCAN_EXECUTE', '${strategy.scanType}: Calling scanController.executeScan...');
    await DebugLogger().flush();

    await _scanController.executeScan(
      strategy: strategy,
      projectId: widget.project.id,
      onStatusChange: (isScanning, status) {
        if (mounted) {
          // Defer setState to avoid calling during build/setState phase
          // Use Future.microtask instead of SchedulerBinding (works better in packaged macOS apps)
          Future.microtask(() {
            if (mounted) {
              setState(() {
                this.isScanning = isScanning;
                scanStatus = status;
              });
            }
          });
        }
      },
      getScanOption: (scanType) async {
        if (forcedOption != null) return forcedOption;
        return _getScanOption(scanType);
      },
    );

    await DebugLogger().log('SCAN_EXECUTE', '${strategy.scanType}: scanController.executeScan completed');
    await DebugLogger().flush();

    await DebugLogger().log('SCAN_EXECUTE', '${strategy.scanType}: Reloading devices cache...');
    await DebugLogger().flush();
    await _cache.reloadDevices(widget.project.id);

    if (mounted) {
      await loadDevices();
      await DebugLogger().log('SCAN_EXECUTE', '${strategy.scanType}: Devices reloaded');
      await DebugLogger().flush();
    }

    await DebugLogger().log('SCAN_EXECUTE', '>>> ${strategy.scanType} scan COMPLETED <<<');
    await DebugLogger().flush();
  }

  Future<void> _deleteDevice(Device device) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(24, 9, 24, 0),
        title: const widgets.DecoratedDialogTitle('Delete Device'),
        content: Text(
          'Are you sure you want to delete "${device.name}"?\n\nThis will also delete all associated scans and data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (result == true) {
      await _deviceRepo.deleteDevice(device.id);
      final cache = ProjectDataCache();
      cache.updateDeviceDeleted(device.id);
      if (selectedDevice?.id == device.id) {
        setState(() {
          selectedDevice = null;
        });
      }
      loadDevices();
    }
  }

  Future<void> _handleDeviceMoved(int deviceId) async {
    // Find the current index of the moved device
    final currentIndex = devices.indexWhere((d) => d.id == deviceId);

    if (currentIndex == -1) {
      // Device not found in current list, just reload and clear selection
      final cache = ProjectDataCache();
      await cache.reloadDevices(widget.project.id);
      await loadDevices();
      setState(() {
        selectedDevice = null;
      });
      return;
    }

    // Find the next device to select
    Device? nextDevice;
    if (currentIndex < devices.length - 1) {
      // Select the next device in the list
      nextDevice = devices[currentIndex + 1];
    } else if (currentIndex > 0) {
      // If this was the last device, select the previous one
      nextDevice = devices[currentIndex - 1];
    }
    // else: this was the only device, nextDevice stays null

    // Reload devices from cache (which will exclude the moved device)
    final cache = ProjectDataCache();
    await cache.reloadDevices(widget.project.id);
    await loadDevices();

    // Update the selected device
    setState(() {
      if (nextDevice != null) {
        // Find the device in the newly loaded list (in case it moved positions)
        final foundDevice = devices.firstWhere(
          (d) => d.id == nextDevice!.id,
          orElse: () => Device(id: -1, projectId: -1, name: '', ipAddress: ''),
        );
        if (foundDevice.id != -1) {
          selectedDevice = foundDevice;
          _deviceDetailKey = GlobalKey<DeviceDetailScreenState>();
        } else {
          selectedDevice = null;
        }
      } else {
        selectedDevice = null;
      }
    });
  }

  Future<void> _searchDevice() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(24, 9, 24, 0),
        title: const widgets.DecoratedDialogTitle('Device Search'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter Host Name or IP Address',
            labelText: 'Search Term',
          ),
          onSubmitted: (value) => Navigator.pop(context, value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Search'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final searchTerm = result.toLowerCase();
      Device? bestMatch;
      int bestScore = 0;

      for (final device in devices) {
        final nameScore = _calculateMatchScore(
          device.name.toLowerCase(),
          searchTerm,
        );
        final ipScore = _calculateMatchScore(
          device.ipAddress.toLowerCase(),
          searchTerm,
        );
        final maxScore = nameScore > ipScore ? nameScore : ipScore;

        if (maxScore > bestScore) {
          bestScore = maxScore;
          bestMatch = device;
        }
      }

      if (bestMatch != null && bestScore > 0) {
        setState(() {
          selectedDevice = bestMatch;
          _deviceDetailKey = GlobalKey<DeviceDetailScreenState>();
        });

        final deviceIndex = devices.indexWhere((d) => d.id == bestMatch!.id);
        if (deviceIndex != -1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_deviceListScrollController.hasClients) {
              const itemHeight = 80.0;
              final targetPosition = deviceIndex * itemHeight;
              final viewportHeight =
                  _deviceListScrollController.position.viewportDimension;

              final centeredPosition =
                  targetPosition - (viewportHeight / 2) + (itemHeight / 2);
              final maxScroll =
                  _deviceListScrollController.position.maxScrollExtent;
              final scrollPosition = centeredPosition.clamp(0.0, maxScroll);

              _deviceListScrollController.animateTo(
                scrollPosition,
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeInOut,
              );
            }
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No matching device found')),
          );
        }
      }
    }
  }

  int _calculateMatchScore(String text, String searchTerm) {
    if (text == searchTerm) return 100;
    if (text.startsWith(searchTerm)) return 90;
    if (text.contains(searchTerm)) return 70;

    int matches = 0;
    for (int i = 0; i < searchTerm.length; i++) {
      if (text.contains(searchTerm[i])) matches++;
    }
    return (matches * 30) ~/ searchTerm.length;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            flexibleSpace: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: AppTheme.backgroundGradient,
                ),
              ),
            ),
            titleSpacing: 0,
            title: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Text(
                    widget.project.name,
                    style: TextStyle(
                      fontSize: 24,
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ScanToolbar(
                    onAddHost: _showAutomateScanDialog,
                    onNmapScan: _startAutomatedDeviceScans,
                    onNiktoScan: () => _executeScan(NiktoScanStrategy()),
                    onSearchsploitScan: () =>
                        _executeScan(SearchsploitScanStrategy()),
                    onWhatwebScan: () => _executeScan(WhatwebScanStrategy()),
                    onEnum4linuxScan: () =>
                        _executeScan(SambaLdapScanStrategy()),
                    onFfufScan: () => _executeScan(FfufScanStrategy()),
                    onSnmpScan: () => _executeScan(SnmpScanStrategy()),
                    hasDevices: hasDevices,
                    hasNmapResults: hasNmapResults,
                  ),
                ),
                const SizedBox(width: 80), // Space for MagicButton
              ],
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppTheme.textTertiary,
                      width: 2.0,
                    ),
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  padding: const EdgeInsets.only(right: 180),
                  indicatorColor: AppTheme.primaryColor,
                  labelColor: AppTheme.primaryColor,
                  unselectedLabelColor: AppTheme.textTertiary,
                  onTap: (index) {
                    // Close settings when any tab is clicked
                    if (_showSettings) {
                      setState(() {
                        _showSettings = false;
                      });
                    }
                  },
                  tabs: const [
                    Tab(text: 'GATHER'),
                    Tab(text: 'SEARCH'),
                    Tab(text: 'FINDINGS'),
                    Tab(text: 'REPORT'),
                  ],
                ),
              ),
            ),
          ),
          body: _showSettings
              ? const SettingsScreen()
              : _selectedTab == 0
              ? Row(
                  children: [
                    DeviceListSidebar(
                      devices: devices,
                      selectedDevice: selectedDevice,
                      failedDeviceIds: failedDeviceIds,
                      deviceMetadata: deviceMetadata,
                      isLoadingDevices: isLoadingDevices,
                      deviceLoadingStatus: deviceLoadingStatus,
                      devicesLoaded: devicesLoaded,
                      totalDevices: totalDevices,
                      scrollController: _deviceListScrollController,
                      onAddDevice: _showAutomateScanDialog,
                      onSearchDevice: _searchDevice,
                      onDeviceSelected: (device) {
                        setState(() {
                          selectedDevice = device;
                          _deviceDetailKey =
                              GlobalKey<DeviceDetailScreenState>();
                        });
                      },
                      onDeleteDevice: _deleteDevice,
                      onIconChanged: (device, iconType) async {
                        await _deviceRepo.updateDeviceIcon(device.id, iconType);
                        _cache.updateDeviceIcon(device.id, iconType);
                        loadDevices();
                      },
                    ),
                    Expanded(
                      child: selectedDevice != null
                          ? Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: AppTheme.backgroundGradient,
                                ),
                              ),
                              child: DeviceDetailScreen(
                                key: _deviceDetailKey,
                                device: selectedDevice!,
                                onDataChanged: () {
                                  // Reload device details by creating new key
                                  setState(() {
                                    _deviceDetailKey = GlobalKey<DeviceDetailScreenState>();
                                  });
                                },
                                onDeviceMoved: (deviceId) =>
                                    _handleDeviceMoved(deviceId),
                              ),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: AppTheme.backgroundGradient,
                                ),
                              ),
                              child: Center(
                                child: deviceCount == 0
                                    ? const EmptyDevicePrompt()
                                    : const SelectDevicePrompt(),
                              ),
                            ),
                    ),
                  ],
                )
              : _selectedTab == 1
              ? FindingsTab(
                  projectId: widget.project.id,
                  deviceCount: deviceCount,
                  projectName: widget.project.name,
                )
              : _selectedTab == 2
              ? FindingsTab(
                  projectId: widget.project.id,
                  deviceCount: deviceCount,
                  showFindingsOnly: true,
                  projectName: widget.project.name,
                )
              : _selectedTab == 3
              ? ReportScreen(
                  projectId: widget.project.id,
                  projectName: widget.project.name,
                )
              : const Center(child: Text('Unknown Tab')),
          bottomNavigationBar: EnhancedStatusBar(
            onCancel: isScanning
                ? (String scanType) {
                    // Immediately update the status bar to show cancelling
                    ScanStatusService().updateScanMessage(
                      scanType,
                      'Cancelling... Please wait',
                    );

                    setState(() {
                      _cancelScan = true;
                      scanStatus = 'Cancelling $scanType scans...';
                    });
                    _scanOrchestrator.requestCancel(scanType);
                  }
                : null,
          ),
        ),
        if (_selectedTab == 0)
          Positioned(
            top: -10,
            right: 0,
            child: MagicButton(onPressed: _handleMagicButton),
          ),
        if (_selectedTab == 0)
          Positioned(
            top: 15,
            right: 8,
            child: Tooltip(
              message: 'Flag a non-device',
              child: IconButton(
                icon: Icon(
                  AppTheme.flagIcon,
                  color: AppTheme.textSecondary,
                ),
                onPressed: _flagNonDevice,
              ),
            ),
          ),
        Positioned(
          top: 55,
          right: 8,
          child: Tooltip(
            message: 'Settings',
            child: IconButton(
              icon: Icon(
                AppTheme.settingsIcon,
                color: _showSettings
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary,
              ),
              onPressed: () {
                setState(() {
                  _showSettings = !_showSettings;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _handleMagicButton() async {
    // Prompt for password on macOS/Linux/Web before showing any dialogs
    if ((ConfigService.isMacOS || ConfigService.isLinux || kIsWeb) && !PrivilegedRunner.hasPassword) {
      final hasPassword = await MacOSPasswordPrompt.promptIfNeeded(context);
      if (!hasPassword) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Administrator access required for scanning')),
          );
        }
        return;
      }
    }
    
    // Determine if any devices exist
    final hasDevices = devices.isNotEmpty;

    if (!hasDevices) {
      // Show "No Devices" modal
      final controller = TextEditingController();
      final result = await showDialog<String?>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) {
            final input = controller.text.trim();
            final ipValid = Validators.validateIP(input).isValid;
            final cidrValid = Validators.validateCIDR(input).isValid;
            final isValid = input.isNotEmpty && (ipValid || cidrValid);
            final showError = input.isNotEmpty && !isValid;

            return AlertDialog(
              titlePadding: const EdgeInsets.fromLTRB(24, 9, 24, 0),
              title: const widgets.DecoratedDialogTitle(
                'The Magic Button will Automate all Scans',
              ),
              content: SizedBox(
                width: 500,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'First you\'ll need to add an IP Address or CIDR Network Range to Scan.',
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: controller,
                      autofocus: true,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (value) {
                        if (isValid) Navigator.pop(context, value);
                      },
                      decoration: const InputDecoration(
                        hintText: '127.0.0.1, 127.0.0.0/24',
                        labelText: 'IP Address or CIDR Network Range',
                      ),
                    ),
                    if (showError)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Invalid IP address or CIDR range',
                          style: TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, null),
                  child: const Text('CANCEL'),
                ),
                GradientButton(
                  label: 'BEGIN',
                  backgroundConfig:
                      AppTheme.primaryButtonGradient ?? AppTheme.primaryColor,
                  onPressed: isValid
                      ? () => Navigator.pop(context, controller.text)
                      : null,
                  textColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
              ],
            );
          },
        ),
      );

      if (result != null && result.isNotEmpty) {
        await _runMagicButtonSequence(target: result);
      }
    } else {
      // Show "Existing Devices" modal
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(24, 9, 24, 0),
          title: const widgets.DecoratedDialogTitle(
            'The Magic Button will Automate all Scans',
          ),
          content: const Text(
            'Any existing scan information in this project will be overwritten.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('CANCEL'),
            ),
            GradientButton(
              label: 'BEGIN',
              backgroundConfig:
                  AppTheme.primaryButtonGradient ?? AppTheme.primaryColor,
              onPressed: () => Navigator.pop(context, true),
              textColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ],
        ),
      );

      if (result == true) {
        await _runMagicButtonSequence();
      }
    }
  }

  Future<void> _runMagicButtonSequence({String? target}) async {
    await DebugLogger().log('MAGIC_BUTTON', '========== MAGIC BUTTON SEQUENCE STARTED ==========');
    await DebugLogger().flush();

    try {
      // Step 1: Add Devices (if target provided)
      if (target != null) {
        await DebugLogger().log('MAGIC_BUTTON', 'Step 1: Adding devices for target: $target');
        await DebugLogger().flush();
        await _startAutomatedScan(target);
        await DebugLogger().log('MAGIC_BUTTON', 'Step 1: Device discovery completed');
        await DebugLogger().flush();
      }

      // Step 2: NMap Scans
      await DebugLogger().log('MAGIC_BUTTON', 'Step 2: Starting NMAP scans...');
      await DebugLogger().flush();
      await _startAutomatedDeviceScans(forcedOption: 'replace');
      await DebugLogger().log('MAGIC_BUTTON', 'Step 2: NMAP scans COMPLETED');
      await DebugLogger().flush();

      // CRITICAL: Log before cleanup delay
      await DebugLogger().log('MAGIC_BUTTON', 'CRITICAL: NMAP finished, preparing for next scans');
      await DebugLogger().flush();

      // On macOS, add a small delay to let processes clean up properly
      if (ConfigService.isMacOS) {
        await DebugLogger().log('MAGIC_BUTTON', 'macOS detected - waiting 2 seconds for process cleanup...');
        await DebugLogger().flush();
        await Future.delayed(Duration(seconds: 2));
        await DebugLogger().log('MAGIC_BUTTON', 'macOS cleanup delay complete');
        await DebugLogger().flush();
      }

      await DebugLogger().log('MAGIC_BUTTON', 'CRITICAL: About to start combined scan batch (SNMP, Nikto, SearchSploit, WhatWeb, Enum4Linux, FFUF)');
      await DebugLogger().flush();

      try {
        final tasks = [
          () => _executeScan(SnmpScanStrategy(), forcedOption: 'replace'),
          () => _executeScan(NiktoScanStrategy(), forcedOption: 'replace'),
          () => _executeScan(SearchsploitScanStrategy(), forcedOption: 'replace'),
          () => _executeScan(WhatwebScanStrategy(), forcedOption: 'replace'),
          () => _executeScan(SambaLdapScanStrategy(), forcedOption: 'replace'),
          () => _executeScan(FfufScanStrategy(), forcedOption: 'replace'),
        ];

        // Run scans with a concurrency of 3 strategies at a time
        // This ensures that as soon as one strategy finishes (e.g. SNMP), the next one (e.g. WhatWeb) starts
        await _runStrategiesInPool(tasks, 3);

        await DebugLogger().log('MAGIC_BUTTON', 'Combined batch completed successfully');
        await DebugLogger().flush();
      } catch (e, stack) {
        await DebugLogger().logError('MAGIC_BUTTON', 'Combined batch ERROR: $e', stack);
        await DebugLogger().flush();
      }

      // Step 5: Completion Modal
      await DebugLogger().log('MAGIC_BUTTON', 'Step 5: All scans completed, showing completion dialog');
      await DebugLogger().flush();

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            titlePadding: const EdgeInsets.fromLTRB(24, 9, 24, 0),
            title: const widgets.DecoratedDialogTitle(
              'Magic Button Scanning complete!',
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

      await DebugLogger().log('MAGIC_BUTTON', '========== MAGIC BUTTON SEQUENCE COMPLETED SUCCESSFULLY ==========');
      await DebugLogger().flush();
    } catch (e, stackTrace) {
      await DebugLogger().logError('MAGIC_BUTTON', '!!!!!! MAGIC BUTTON SEQUENCE CRASHED !!!!!!', stackTrace);
      await DebugLogger().logError('MAGIC_BUTTON', 'Exception details: $e');
      await DebugLogger().flush();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Magic Button sequence failed: $e')),
        );
      }
    }
  }

  /// Runs a list of async tasks with a maximum concurrency.
  Future<void> _runStrategiesInPool(List<Future<void> Function()> tasks, int poolSize) async {
    final activeFutures = <int, Future<int>>{};
    int nextTaskIndex = 0;

    while (nextTaskIndex < tasks.length || activeFutures.isNotEmpty) {
      // Fill pool
      while (activeFutures.length < poolSize && nextTaskIndex < tasks.length) {
        final index = nextTaskIndex;
        final task = tasks[index];
        
        // Start task and have it return its index when done
        final future = task().then((_) => index);
        activeFutures[index] = future;
        
        nextTaskIndex++;
      }

      if (activeFutures.isNotEmpty) {
        // Wait for ANY of the active tasks to complete
        final completedIndex = await Future.any(activeFutures.values);
        
        // Remove the completed task from the active list
        activeFutures.remove(completedIndex);
      }
    }
  }

  Future<void> _flagNonDevice() async {
    final title = await showDialog<String>(
      context: context,
      builder: (context) => const NonDeviceTitleDialog(),
    );

    if (title == null) return;

    final flagResult = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => QuillFlagDialog(
        deviceName: title,
        projectName: widget.project.name,
        onSubmit: (type, content) {},
      ),
    );

    if (flagResult != null) {
      final id = await _findingsRepo.insertFlaggedFinding(
        0,
        title,
        title,
        flagResult['type'],
        flagResult['comment'],
        findingType: 'MANUAL',
        projectId: widget.project.id,
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
        if (classification['category'] != null && classification['subcategory'] != null && classification['scope'] != null) {
          await _vulnRepo.insertVulnerabilityClassification(
            projectId: widget.project.id,
            deviceId: 0,
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

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Non-device finding added successfully')),
      );
    }
  }
  
  Future<void> _sendPasswordToServer(String password) async {
    try {
      await http.post(
        Uri.parse('${ApiDatabaseHelper.baseUrl}/set-session-password'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'password': password}),
      );
    } catch (e) {
      debugPrint('Failed to send password to server: $e');
    }
  }
}
