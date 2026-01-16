import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:penpeeper/theme_config.dart';
import 'package:penpeeper/theme_loader.dart';
import 'package:penpeeper/repositories/settings_repository.dart';
import 'package:penpeeper/widgets/gradient_button.dart';
import 'package:http/http.dart' as http;
import 'package:penpeeper/utils/error/error_handler.dart';
import 'package:penpeeper/utils/debug_logger.dart';
import 'package:penpeeper/api_database_helper.dart';
import 'package:penpeeper/services/app_paths_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settingsRepo = SettingsRepository();
  List<String> availableThemes = [];
  String selectedTheme = 'crimson';
  final _pingAddressController = TextEditingController();
  final _pingResultController = TextEditingController();
  bool _isPinging = false;
  int _concurrentScanCount = 3;

  @override
  void initState() {
    super.initState();
    _loadThemes();
    _loadSavedTheme();
    _loadConcurrentScanCount();
  }

  @override
  void dispose() {
    _pingAddressController.dispose();
    _pingResultController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedTheme() async {
    final savedTheme = await _settingsRepo.getSetting('theme', 'default');
    setState(() {
      selectedTheme = savedTheme;
    });
  }

  Future<void> _loadConcurrentScanCount() async {
    final count = await _settingsRepo.getIntSetting('concurrent_scan_count', 3);
    setState(() {
      _concurrentScanCount = count;
    });
  }

  Future<void> _saveConcurrentScanCount(int value) async {
    await _settingsRepo.setIntSetting('concurrent_scan_count', value);
    setState(() {
      _concurrentScanCount = value;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Concurrent scan count set to $value'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
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


  Future<void> _runPing() async {
    final address = _pingAddressController.text.trim();
    if (address.isEmpty) {
      setState(() {
        _pingResultController.text = 'Please enter an address to ping';
      });
      return;
    }

    setState(() {
      _isPinging = true;
      _pingResultController.text = 'Pinging $address...';
    });

    try {
      if (kIsWeb) {
        final response = await http.post(
          Uri.parse('${ApiDatabaseHelper.baseUrl}/ping'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'address': address}),
        );
        final result = json.decode(response.body);
        setState(() {
          _pingResultController.text = result['output'] ?? 'No output';
          _isPinging = false;
        });
      } else if (Platform.isWindows) {
        final result = await Process.run('wsl', ['ping', '-c', '4', address]);
        setState(() {
          _pingResultController.text = result.stdout.toString();
          _isPinging = false;
        });
      } else {
        final result = await Process.run('ping', ['-c', '4', address]);
        setState(() {
          _pingResultController.text = result.stdout.toString();
          _isPinging = false;
        });
      }
    } catch (e, stack) {
      ErrorHandler.handle(
        e,
        stackTrace: stack,
        onUserMessage: (msg) => setState(() {
          _pingResultController.text = 'Ping failed: $msg';
          _isPinging = false;
        }),
        context: 'Ping address',
      );
    }
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
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildConcurrentScanSection(),
            const SizedBox(height: 24),
            _buildPingTestSection(),
            const SizedBox(height: 24),
            _buildDebugLoggingSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildConcurrentScanSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: Border.all(color: AppTheme.borderPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.speed,
                color: AppTheme.primaryColor,
                size: AppTheme.iconSizeXLarge,
              ),
              const SizedBox(width: 12),
              Text(
                'Scan Performance',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeLargeTitle,
                  fontWeight: AppTheme.fontWeightSemiBold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Concurrent Scans',
            style: TextStyle(
              fontSize: AppTheme.fontSizeBodyLarge,
              fontWeight: AppTheme.fontWeightMedium,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Number of devices to scan simultaneously (1-10). Higher values improve speed but use more resources.',
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Slider(
                  value: _concurrentScanCount.toDouble(),
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: _concurrentScanCount.toString(),
                  activeColor: AppTheme.primaryColor,
                  inactiveColor: AppTheme.borderPrimary,
                  onChanged: (value) {
                    setState(() {
                      _concurrentScanCount = value.toInt();
                    });
                  },
                  onChangeEnd: (value) {
                    _saveConcurrentScanCount(value.toInt());
                  },
                ),
              ),
              const SizedBox(width: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.inputBackground,
                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                  border: Border.all(color: AppTheme.borderPrimary),
                ),
                child: Text(
                  '$_concurrentScanCount',
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeBodyLarge,
                    fontWeight: AppTheme.fontWeightSemiBold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.inputBackground,
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
              border: Border.all(color: AppTheme.borderPrimary),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  color: AppTheme.textSecondary,
                  size: AppTheme.iconSizeMedium,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _concurrentScanCount == 1
                        ? 'Sequential scanning (safest, slowest)'
                        : _concurrentScanCount <= 3
                            ? 'Balanced performance (recommended)'
                            : _concurrentScanCount <= 6
                                ? 'High performance (requires good hardware)'
                                : 'Maximum performance (CPU/memory intensive)',
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeBody,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPingTestSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: Border.all(color: AppTheme.borderPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.network_ping,
                color: AppTheme.primaryColor,
                size: AppTheme.iconSizeXLarge,
              ),
              const SizedBox(width: 12),
              Text(
                'Ping Test',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeLargeTitle,
                  fontWeight: AppTheme.fontWeightSemiBold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pingAddressController,
                  style: TextStyle(color: AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Address (IP or hostname)',
                    labelStyle: TextStyle(color: AppTheme.textSecondary),
                    hintText: '192.168.1.1 or google.com',
                    hintStyle: TextStyle(color: AppTheme.textTertiary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GradientButton(
                label: _isPinging ? 'Pinging...' : 'Ping',
                icon: Icons.send,
                backgroundConfig: AppTheme.primaryButtonGradient ?? AppTheme.primaryColor,
                onPressed: _isPinging ? null : _runPing,
                textColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                iconSize: AppTheme.iconSizeMedium,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            height: 200,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.inputBackground,
              borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
              border: Border.all(color: AppTheme.borderPrimary),
            ),
            child: SingleChildScrollView(
              child: Text(
                _pingResultController.text.isEmpty
                    ? 'Ping results will appear here'
                    : _pingResultController.text,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontFamily: AppTheme.monospaceFontFamily,
                  fontSize: AppTheme.fontSizeBody,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDebugLoggingSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: Border.all(color: AppTheme.borderPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bug_report,
                color: AppTheme.primaryColor,
                size: AppTheme.iconSizeXLarge,
              ),
              const SizedBox(width: 12),
              Text(
                'Debug Logging',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeLargeTitle,
                  fontWeight: AppTheme.fontWeightSemiBold,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Enable Session Logging',
                      style: TextStyle(
                        fontSize: AppTheme.fontSizeBodyLarge,
                        fontWeight: AppTheme.fontWeightMedium,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Log errors and debug messages to file for this session. (Resets on restart)',
                      style: TextStyle(
                        fontSize: AppTheme.fontSizeBody,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: DebugLogger().isEnabled,
                activeThumbColor: AppTheme.primaryColor,
                onChanged: (value) async {
                  if (value) {
                    await DebugLogger().enable();
                  } else {
                    await DebugLogger().disable();
                  }
                  setState(() {});
                },
              ),
            ],
          ),
          if (DebugLogger().isEnabled) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.inputBackground,
                borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                border: Border.all(color: AppTheme.borderPrimary),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                        size: AppTheme.iconSizeMedium,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          kIsWeb
                              ? 'Logging is active. Sending logs to host...'
                              : 'Logging is active',
                          style: TextStyle(
                            fontSize: AppTheme.fontSizeBody,
                            fontWeight: AppTheme.fontWeightMedium,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (!kIsWeb) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.folder_outlined,
                          color: AppTheme.textTertiary,
                          size: AppTheme.iconSizeSmall,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SelectableText(
                            AppPathsService().debugLogPath,
                            style: TextStyle(
                              fontSize: AppTheme.fontSizeBody,
                              color: AppTheme.textSecondary,
                              fontFamily: AppTheme.monospaceFontFamily,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ]
        ],
      ),
    );
  }
}
