import 'dart:io';
import 'package:xml/xml.dart';
import 'package:penpeeper/database/isolate/database_isolate_manager.dart';
import 'package:penpeeper/database/isolate/database_commands.dart';

class NmapProcessor {
  // Process existing XML file
  static Future<void> processNmapXml(int deviceId, int projectId, String xmlFilePath) async {
    try {
      final xmlContent = await File(xmlFilePath).readAsString();
      await processXmlContent(deviceId, projectId, xmlContent);
    } catch (e) {
      print('ERROR: $e');
      rethrow;
    }
  }

  static Future<void> processXmlContent(int deviceId, int projectId, String xmlContent) async {
    final document = XmlDocument.parse(xmlContent);
    final writeManager = DatabaseIsolateManager();

    // Clear existing device data in a transaction
    await _clearDeviceData(writeManager, deviceId);

    // Process hosts - each host in its own transaction to reduce lock time
    // but still batch all operations for that host
    final hosts = document.findAllElements('host');
    for (final host in hosts) {
      await _processHostInTransaction(writeManager, host, deviceId, projectId);
    }

    print('SUCCESS');
  }

  /// Process a single host and all its related data in one transaction
  static Future<void> _processHostInTransaction(
    DatabaseIsolateManager writeManager,
    XmlElement host,
    int deviceId,
    int projectId,
  ) async {
    // Collect all insert commands for this host
    final commands = <DatabaseCommand>[];

    // Extract host data
    String addr = '';
    String macAddr = '';
    String vendor = '';
    for (final address in host.findElements('address')) {
      final addrType = address.getAttribute('addrtype') ?? '';
      final addrValue = address.getAttribute('addr') ?? '';
      final vendorValue = address.getAttribute('vendor') ?? '';
      if (addrType == 'ipv4') {
        addr = addrValue;
      } else if (addrType == 'mac') {
        macAddr = addrValue;
        vendor = vendorValue;
      }
    }

    final status = host.findElements('status').first.getAttribute('state') ?? '';
    int uptime = 0;
    String lastBoot = '';
    final uptimeElement = host.findElements('uptime').firstOrNull;
    if (uptimeElement != null) {
      uptime = int.tryParse(uptimeElement.getAttribute('seconds') ?? '0') ?? 0;
      lastBoot = uptimeElement.getAttribute('lastboot') ?? '';
    }

    // Insert host and get ID
    commands.add(writeManager.createInsertCommand('nmap_hosts', {
      'device_id': deviceId,
      'project_id': projectId,
      'address': addr,
      'mac_address': macAddr,
      'vendor': vendor,
      'status': status,
      'uptime_seconds': uptime,
      'last_boot': lastBoot,
    }));

    // Execute host insert to get hostId
    final results = await writeManager.transaction(commands);
    final hostId = results[0] as int;

    // Now process ports, scripts, etc. with the hostId
    // We can't batch these in the same transaction because we need the hostId
    // But we can batch all ports together
    await _processPortsInBatch(writeManager, host, hostId);

    // Process host scripts
    final hostScriptElement = host.findElements('hostscript').firstOrNull;
    if (hostScriptElement != null) {
      for (final script in hostScriptElement.findElements('script')) {
        await _processHostScript(writeManager, script, deviceId);
      }
    }

    // Process OS matches in batch
    await _processOSMatchesInBatch(writeManager, host, hostId);
  }

  /// Process all ports for a host in batched transactions
  static Future<void> _processPortsInBatch(
    DatabaseIsolateManager writeManager,
    XmlElement host,
    int hostId,
  ) async {
    final portsElement = host.findElements('ports').firstOrNull;
    if (portsElement == null) return;

    // Collect all port insert commands
    final portCommands = <DatabaseCommand>[];
    final portElements = <XmlElement>[];

    for (final port in portsElement.findElements('port')) {
      final portId = int.tryParse(port.getAttribute('portid') ?? '0') ?? 0;
      final protocol = port.getAttribute('protocol') ?? '';
      final stateElement = port.findElements('state').first;
      final state = stateElement.getAttribute('state') ?? '';
      final reason = stateElement.getAttribute('reason') ?? '';

      String serviceName = '';
      String product = '';
      String version = '';
      String cpe = '';
      final serviceElement = port.findElements('service').firstOrNull;
      if (serviceElement != null) {
        serviceName = serviceElement.getAttribute('name') ?? '';
        product = serviceElement.getAttribute('product') ?? '';
        version = serviceElement.getAttribute('version') ?? '';
        final cpeElement = serviceElement.findElements('cpe').firstOrNull;
        if (cpeElement != null) cpe = cpeElement.innerText;
      }

      portCommands.add(writeManager.createInsertCommand('nmap_ports', {
        'host_id': hostId,
        'port': portId,
        'protocol': protocol,
        'state': state,
        'reason': reason,
        'service_name': serviceName,
        'product': product,
        'version': version,
        'cpe': cpe,
      }));
      portElements.add(port);
    }

    // Handle extraports
    final extraPorts = portsElement.findElements('extraports').firstOrNull;
    if (extraPorts != null) {
      final count = int.tryParse(extraPorts.getAttribute('count') ?? '0') ?? 0;
      final state = extraPorts.getAttribute('state') ?? '';
      if (count > 0) {
        portCommands.add(writeManager.createInsertCommand('nmap_ports', {
          'host_id': hostId,
          'port': 0,
          'protocol': 'tcp',
          'state': state,
          'reason': 'summary',
          'service_name': '$count ports $state',
          'product': '',
          'version': '',
          'cpe': '',
        }));
      }
    }

    // Execute all port inserts in one transaction
    if (portCommands.isNotEmpty) {
      final portResults = await writeManager.transaction(portCommands);

      // Process scripts for each port
      for (int i = 0; i < portElements.length; i++) {
        final portDbId = portResults[i] as int;
        await _processScriptsForPort(writeManager, portElements[i], portDbId);
      }
    }
  }

  /// Process all scripts for a single port in a batch
  static Future<void> _processScriptsForPort(
    DatabaseIsolateManager writeManager,
    XmlElement port,
    int portDbId,
  ) async {
    final scripts = port.findElements('script').toList();
    if (scripts.isEmpty) return;

    final scriptCommands = <DatabaseCommand>[];
    for (final script in scripts) {
      final scriptId = script.getAttribute('id') ?? '';
      final output = script.getAttribute('output') ?? '';
      scriptCommands.add(writeManager.createInsertCommand('nmap_scripts', {
        'port_id': portDbId,
        'script_id': scriptId,
        'output': output,
      }));
    }

    // Execute all script inserts in one transaction
    final scriptResults = await writeManager.transaction(scriptCommands);

    // Process CVEs for each script
    for (int i = 0; i < scripts.length; i++) {
      final scriptDbId = scriptResults[i] as int;
      await _processCVEsForScript(writeManager, scripts[i], scriptDbId);
    }
  }

  /// Process all CVEs for a script in a batch
  static Future<void> _processCVEsForScript(
    DatabaseIsolateManager writeManager,
    XmlElement script,
    int scriptDbId,
  ) async {
    final cveCommands = <DatabaseCommand>[];

    for (final table in script.findElements('table')) {
      for (final subTable in table.findElements('table')) {
        String? cveId;
        double cvss = 0.0;
        bool isExploit = false;

        for (final elem in subTable.findElements('elem')) {
          final key = elem.getAttribute('key') ?? '';
          final value = elem.innerText;
          switch (key) {
            case 'id':
              cveId = value;
              break;
            case 'cvss':
              cvss = double.tryParse(value) ?? 0.0;
              break;
            case 'is_exploit':
              isExploit = value == 'true';
              break;
          }
        }

        if (cveId != null) {
          cveCommands.add(writeManager.createInsertCommand('nmap_cves', {
            'script_id': scriptDbId,
            'cve_id': cveId,
            'cvss': cvss,
            'is_exploit': isExploit ? 1 : 0,
            'url': 'https://vulners.com/cve/$cveId',
          }));
        }
      }
    }

    // Execute all CVE inserts in one transaction
    if (cveCommands.isNotEmpty) {
      await writeManager.transaction(cveCommands);
    }
  }

  /// Process all OS matches for a host in a batch
  static Future<void> _processOSMatchesInBatch(
    DatabaseIsolateManager writeManager,
    XmlElement host,
    int hostId,
  ) async {
    final osElement = host.findElements('os').firstOrNull;
    if (osElement == null) return;

    final osCommands = <DatabaseCommand>[];
    for (final osMatch in osElement.findElements('osmatch')) {
      final name = osMatch.getAttribute('name') ?? '';
      final accuracy = int.tryParse(osMatch.getAttribute('accuracy') ?? '0') ?? 0;

      for (final osClass in osMatch.findElements('osclass')) {
        final vendor = osClass.getAttribute('vendor') ?? '';
        final family = osClass.getAttribute('osfamily') ?? '';
        final gen = osClass.getAttribute('osgen') ?? '';
        String cpe = '';
        final cpeElement = osClass.findElements('cpe').firstOrNull;
        if (cpeElement != null) cpe = cpeElement.innerText;

        osCommands.add(writeManager.createInsertCommand('nmap_os_matches', {
          'host_id': hostId,
          'name': name,
          'accuracy': accuracy,
          'vendor': vendor,
          'os_family': family,
          'os_generation': gen,
          'cpe': cpe,
        }));
      }
    }

    // Execute all OS match inserts in one transaction
    if (osCommands.isNotEmpty) {
      await writeManager.transaction(osCommands);
    }
  }

  static Future<void> _clearDeviceData(DatabaseIsolateManager writeManager, int deviceId) async {
    // Use transaction to delete all related data atomically
    await writeManager.transaction([
      writeManager.createExecuteCommand('''
        DELETE FROM nmap_cves WHERE script_id IN (
          SELECT s.id FROM nmap_scripts s
          JOIN nmap_ports p ON s.port_id = p.id
          JOIN nmap_hosts h ON p.host_id = h.id
          WHERE h.device_id = ?)
      ''', [deviceId]),

      writeManager.createExecuteCommand('''
        DELETE FROM nmap_scripts WHERE port_id IN (
          SELECT p.id FROM nmap_ports p
          JOIN nmap_hosts h ON p.host_id = h.id
          WHERE h.device_id = ?)
      ''', [deviceId]),

      writeManager.createExecuteCommand('''
        DELETE FROM nmap_ports WHERE host_id IN (
          SELECT id FROM nmap_hosts WHERE device_id = ?)
      ''', [deviceId]),

      writeManager.createExecuteCommand('''
        DELETE FROM nmap_os_matches WHERE host_id IN (
          SELECT id FROM nmap_hosts WHERE device_id = ?)
      ''', [deviceId]),

      writeManager.createExecuteCommand('DELETE FROM nmap_hosts WHERE device_id = ?', [deviceId]),
    ]);
  }

  static Future<void> _processHostScript(DatabaseIsolateManager writeManager, XmlElement script, int deviceId) async {
    final scriptId = script.getAttribute('id') ?? '';
    final output = script.getAttribute('output') ?? '';

    // Handle nbstat script to extract NetBIOS information
    if (scriptId == 'nbstat' && output.isNotEmpty) {
      await _parseNbstatOutput(writeManager, output, deviceId);
    }
  }

  /// Parses nbstat output to extract NetBIOS name, user, and MAC address
  static Future<void> _parseNbstatOutput(DatabaseIsolateManager writeManager, String output, int deviceId) async {
    try {
      // Decode HTML entities
      String decoded = output
          .replaceAll('&lt;', '<')
          .replaceAll('&gt;', '>')
          .replaceAll('&amp;', '&')
          .replaceAll('&#xa;', '\n');

      // Extract NetBIOS name
      final netbiosNameMatch = RegExp(r'NetBIOS name:\s*([^,\n]+)').firstMatch(decoded);
      final netbiosName = netbiosNameMatch?.group(1)?.trim();

      // Extract NetBIOS user
      final netbiosUserMatch = RegExp(r'NetBIOS user:\s*([^,\n]+)').firstMatch(decoded);
      final netbiosUser = netbiosUserMatch?.group(1)?.trim();

      // Build update map for non-empty, non-unknown values
      final Map<String, dynamic> updates = {};

      if (netbiosName != null && netbiosName.isNotEmpty && netbiosName != '<unknown>') {
        updates['netbios_name'] = netbiosName;
      }

      if (netbiosUser != null && netbiosUser.isNotEmpty && netbiosUser != '<unknown>') {
        updates['netbios_user'] = netbiosUser;
      }

      // Update device with NetBIOS information if we have any
      if (updates.isNotEmpty) {
        // Build the SET clause dynamically
        final setClause = updates.keys.map((key) => '$key = ?').join(', ');
        final values = [...updates.values, deviceId];

        await writeManager.execute(
          'UPDATE devices SET $setClause WHERE id = ?',
          values,
        );
      }
    } catch (e) {
      print('ERROR parsing nbstat output: $e');
    }
  }
}
