import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:penpeeper/theme_config.dart';
import 'package:penpeeper/widgets/device_details/section_container.dart';
import 'package:penpeeper/telnet_client_modal.dart';

class PortsDisplay extends StatelessWidget {
  final List<dynamic> ports;
  final String? deviceIpAddress;

  const PortsDisplay({super.key, required this.ports, this.deviceIpAddress});

  bool _isTelnetService(Map<String, dynamic> port) {
    final serviceName = port['service_name']?.toString().toLowerCase() ?? '';
    final portNumber = port['port'] as int? ?? 0;
    
    // Check for telnet service name or common telnet ports
    return serviceName == 'telnet' || 
           portNumber == 23 || 
           serviceName.contains('telnet');
  }

  List<int> _getTelnetPorts() {
    return ports
        .where((port) => port['state'] == 'open' && _isTelnetService(port))
        .map<int>((port) => port['port'] as int)
        .toList();
  }

  void _openTelnetClient(BuildContext context) {
    if (deviceIpAddress == null) return;
    
    final telnetPorts = _getTelnetPorts();
    if (telnetPorts.isEmpty) return;

    showDialog(
      context: context,
      builder: (context) => TelnetClientModal(
        ipAddress: deviceIpAddress!,
        telnetPorts: telnetPorts,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final telnetPorts = _getTelnetPorts();
    final hasTelnetService = telnetPorts.isNotEmpty;
    
    return SectionContainer(
      title: 'Open Ports & Services',
      trailing: hasTelnetService
          ? Tooltip(
              message: kIsWeb 
                  ? 'Telnet Client (Web mode - requires server support)'
                  : 'Open Telnet Client',
              child: ElevatedButton.icon(
                onPressed: deviceIpAddress != null ? () => _openTelnetClient(context) : null,
                icon: Icon(AppTheme.terminalIcon, size: 16),
                label: const Text('Telnet', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kIsWeb 
                      ? AppTheme.primaryColor.withValues(alpha: 0.7)
                      : AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: const Size(0, 28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            )
          : null,
      children: [
        _buildPortsList(),
      ],
    );
  }

  Widget _buildPortsList() {
    final textSpans = <TextSpan>[];
    
    for (int i = 0; i < ports.length; i++) {
      final port = ports[i];
      textSpans.addAll([
        const TextSpan(
          text: 'Port ',
          style: TextStyle(color: Color(0xFFB0B0B0)),
        ),
        TextSpan(
          text: '${port['port']}',
          style: const TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
        TextSpan(
          text: '/${port['protocol']} - ',
          style: const TextStyle(color: Color(0xFFB0B0B0)),
        ),
        TextSpan(
          text: '${port['state']}',
          style: TextStyle(
            color: port['state'] == 'open' ? Colors.green : Colors.orange,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (port['service_name'] != null && port['service_name'].isNotEmpty)
          TextSpan(
            text: ' (${port['service_name']})',
            style: const TextStyle(color: Color(0xFF4FC3F7)),
          ),
        if (port['product'] != null && port['product'].isNotEmpty)
          TextSpan(
            text: ' - ${port['product']}',
            style: TextStyle(color: AppTheme.textPrimary),
          ),
        if (port['version'] != null && port['version'].isNotEmpty)
          TextSpan(
            text: ' v${port['version']}',
            style: const TextStyle(color: Color(0xFFFFD700)),
          ),
        if (i < ports.length - 1)
          const TextSpan(text: '\n'),
      ]);
    }
    
    return SelectableText.rich(
      TextSpan(children: textSpans),
    );
  }
}
