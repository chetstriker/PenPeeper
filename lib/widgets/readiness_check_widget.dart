import 'package:flutter/material.dart';
import 'package:penpeeper/services/readiness_check_service.dart';
import 'package:penpeeper/theme_config.dart';
import 'package:penpeeper/widgets/macos_password_prompt.dart';
import 'package:penpeeper/utils/privileged_runner.dart';
import 'package:penpeeper/services/config_service.dart';

class ReadinessCheckWidget extends StatefulWidget {
  const ReadinessCheckWidget({super.key});

  @override
  State<ReadinessCheckWidget> createState() => _ReadinessCheckWidgetState();
}

class _ReadinessCheckWidgetState extends State<ReadinessCheckWidget> {
  ReadinessStatus? _status;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkReadiness();
  }

  Future<void> _checkReadiness() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final service = ReadinessCheckService();
    final status = await service.checkSystemReadiness();
    if (!mounted) return;
    setState(() {
      _status = status;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.mediumBackground,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
        border: Border.all(color: AppTheme.borderSecondary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.health_and_safety, color: AppTheme.primaryColor, size: AppTheme.iconSizeMedium),
              const SizedBox(width: 8),
              Text(
                _status != null ? _getTitle() : 'System Readiness',
                style: TextStyle(
                  fontSize: AppTheme.fontSizeTitle,
                  fontWeight: AppTheme.fontWeightSemiBold,
                  color: AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              if (_isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                  ),
                )
              else if (_status != null)
                IconButton(
                  icon: Icon(Icons.refresh, size: AppTheme.iconSizeSmall),
                  onPressed: _checkReadiness,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_status == null || _isLoading)
            _buildShimmerPlaceholder()
          else if (_status != null && (_status!.isWindows || _status!.isLinux || _status!.isMacOS || _status!.isWeb))
            Column(
              children: [
                if (_status!.isWindows) ..._buildWindowsChecks(),
                if (_status!.isLinux) ..._buildLinuxChecks(),
                if (_status!.isMacOS) ..._buildMacOSChecks(),
                if (_status!.isWeb) ..._buildWebChecks(),
                if (_status!.toolStatuses.isNotEmpty) const Divider(height: 16),
                ..._status!.toolStatuses.entries.map((entry) =>
                  _buildStatusItem('${_formatToolName(entry.key)} Installed', entry.value, tool: entry.key)
                ),
              ],
            )
          else
            const SizedBox.shrink(),
        ],
      ),
    );
  }

  Widget _buildStatusItem(String label, bool status, {String? subtitle, String? tool}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            status ? Icons.check_circle : Icons.cancel,
            color: status ? Colors.green : Colors.red,
            size: AppTheme.iconSizeSmall,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeBody,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: AppTheme.fontSizeBody * 0.8,
                      color: AppTheme.textMuted,
                    ),
                  ),
              ],
            ),
          ),
          if (!status && tool != null && _status?.canInstall == true)
            IconButton(
              icon: Icon(Icons.download, size: AppTheme.iconSizeSmall),
              onPressed: () => _showInstallDialog(tool),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
        ],
      ),
    );
  }

  String _getTitle() {
    if (_status?.isWeb == true) return 'Tool Readiness (Web)';
    if (_status?.isLinux == true) return 'Tool Readiness (Linux)';
    if (_status?.isMacOS == true) return 'Tool Readiness (macOS)';
    return 'System Readiness';
  }
  
  List<Widget> _buildWindowsChecks() {
    return [
      _buildStatusItem('WSL Installed', _status!.wslInstalled),
      _buildStatusItem(
        'WSL Linux Installed', 
        _status!.wslDistribution != null,
        subtitle: _status!.wslDistribution,
      ),
      _buildStatusItem('Connection to WSL', _status!.wslConnection),
    ];
  }
  
  List<Widget> _buildLinuxChecks() {
    return [
      _buildStatusItem('Linux System', true, subtitle: 'Native Linux'),
    ];
  }
  
  List<Widget> _buildMacOSChecks() {
    return [
      _buildStatusItem('macOS System', true, subtitle: 'Native macOS'),
    ];
  }
  
  List<Widget> _buildWebChecks() {
    return [
      _buildStatusItem('Web Mode', true, subtitle: 'API-based checks'),
    ];
  }

  Future<void> _showInstallDialog(String tool) async {
    String? password;

    // For Linux/macOS, prompt for password if not already cached
    if (_status?.isLinux == true || _status?.isMacOS == true) {
      // Use the shared password prompt that caches the password for the session
      final hasPassword = await MacOSPasswordPrompt.promptIfNeeded(context);
      if (!hasPassword) {
        return; // User cancelled password prompt
      }
      // Get the cached password from PrivilegedRunner
      password = PrivilegedRunner.sessionPassword;
    } else if (_status?.isWeb == true) {
      // Web mode needs password for remote operations
      password = await _promptForPassword();
      if (password == null) {
        return; // User cancelled
      }
    } else {
      // Windows (WSL doesn't need password prompt since it runs as root)
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Install ${_formatToolName(tool)}'),
          content: Text('Would you like to install ${_formatToolName(tool)} automatically?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Install'),
            ),
          ],
        ),
      );

      if (result != true) return;
    }

    await _installTool(tool, password);
  }
  
  Future<String?> _promptForPassword() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Administrator Password Required'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter your password to install tools on the server:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (value) => Navigator.pop(context, value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }
  
  Future<void> _installTool(String tool, [String? password]) async {
    if (!mounted) return;
    
    final outputController = ValueNotifier<String>('');
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Installing ${_formatToolName(tool)}'),
        content: SizedBox(
          width: 400,
          height: 300,
          child: Column(
            children: [
              CircularProgressIndicator(),
              const SizedBox(height: 16),
              Expanded(
                child: ValueListenableBuilder<String>(
                  valueListenable: outputController,
                  builder: (context, output, child) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: SingleChildScrollView(
                        child: Text(
                          output.isEmpty ? 'Starting installation...' : output,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    
    final service = ReadinessCheckService();
    final success = await service.installToolWithOutput(tool, (output) {
      outputController.value += '$output\n';
      // ALSO PRINT TO DEBUG CONSOLE
      debugPrint('INSTALL_LOG: $output');
    }, password);
    
    if (!mounted) return;
    Navigator.pop(context);
    
    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${_formatToolName(tool)} installed successfully!')),
        );
        _checkReadiness();
      }
    } else {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Installation Failed'),
            content: Text('Failed to install ${_formatToolName(tool)}. Please install it manually.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  Widget _buildShimmerPlaceholder() {
    return Column(
      children: List.generate(8, (index) => 
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: AppTheme.textMuted.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  height: 16,
                  decoration: BoxDecoration(
                    color: AppTheme.textMuted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatToolName(String tool) {
    switch (tool) {
      case 'brew':
        return 'Homebrew';
      case 'nmap':
        return 'NMAP';
      case 'ffuf':
        return 'FFUF';
      case 'nikto':
        return 'Nikto';
      case 'searchsploit':
        return 'SearchSploit';
      case 'whatweb':
        return 'WhatWeb';
      case 'enum4linux-ng':
        return 'Enum4linux-ng';
      case 'raft-large-files.txt':
        return 'Raft Large Files';
      case 'nmap_processor':
        return 'NMAP Processor';
      case 'go':
        return 'Go';
      default:
        return tool.toUpperCase();
    }
  }
}