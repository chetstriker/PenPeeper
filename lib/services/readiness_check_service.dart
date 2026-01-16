import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:penpeeper/api_database_helper.dart';

class ReadinessCheckService {
  static const List<String> _requiredTools = [
    'nmap',
    'ffuf', 
    'nikto',
    'searchsploit',
    'whatweb',
    'enum4linux-ng',
    'raft-large-files.txt',
    'getoptlong',
    'impacket'
  ];

  Future<ReadinessStatus> checkSystemReadiness() async {
    if (kIsWeb) return await _checkWebReadiness();
    if (Platform.isLinux) return await _checkLinuxReadiness();
    if (Platform.isMacOS) return await _checkMacOSReadiness();
    if (Platform.isWindows) return await _checkWindowsReadiness();

    return ReadinessStatus(
      isWindows: false,
      isLinux: false,
      isMacOS: false,
      isWeb: false,
      wslInstalled: false,
      wslDistribution: null,
      wslConnection: false,
      toolStatuses: {},
    );
  }

  Future<ReadinessStatus> _checkWindowsReadiness() async {
    final wslInstalled = await _checkWSLInstalled();
    final wslDistribution = wslInstalled ? await _getWSLDistribution() : null;
    final wslConnection = wslInstalled ? await _checkWSLConnection() : false;
    
    final toolStatuses = <String, bool>{};
    for (final tool in _requiredTools) {
      if (tool == 'nmap') {
        toolStatuses[tool] = await _checkWindowsNativeTool('nmap');
      } else if (wslConnection) {
        toolStatuses[tool] = await _checkToolInstalled(tool);
      } else {
        toolStatuses[tool] = false;
      }
    }

    return ReadinessStatus(
      isWindows: true,
      isLinux: false,
      isMacOS: false,
      isWeb: false,
      wslInstalled: wslInstalled,
      wslDistribution: wslDistribution,
      wslConnection: wslConnection,
      toolStatuses: toolStatuses,
    );
  }

  Future<bool> _checkWindowsNativeTool(String tool) async {
    try {
      final result = await Process.run('where', [tool]);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  Future<bool> _checkWSLInstalled() async {
    try {
      final result = await Process.run('wsl', ['--list', '--quiet'], runInShell: true);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  Future<String?> _getWSLDistribution() async {
    try {
      final result = await Process.run('wsl', ['--list', '--verbose'], runInShell: true);
      if (result.exitCode == 0) {
        final lines = result.stdout.toString().split('\n');
        for (final line in lines) {
          if (line.contains('*') || (lines.indexOf(line) == 1 && line.trim().isNotEmpty)) {
            final parts = line.replaceAll('*', '').trim().split(RegExp(r'\s+'));
            if (parts.isNotEmpty) {
              return parts[0];
            }
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<bool> _checkWSLConnection() async {
    try {
      final result = await Process.run('wsl', ['echo', 'test'], runInShell: true);
      return result.exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  Future<ReadinessStatus> _checkLinuxReadiness() async {
    final toolStatuses = <String, bool>{};
    for (final tool in _requiredTools) {
      toolStatuses[tool] = await _checkLinuxToolInstalled(tool);
    }
    
    return ReadinessStatus(
      isWindows: false,
      isLinux: true,
      isMacOS: false,
      isWeb: false,
      wslInstalled: false,
      wslDistribution: null,
      wslConnection: false,
      toolStatuses: toolStatuses,
    );
  }
  
  Future<ReadinessStatus> _checkMacOSReadiness() async {
    final toolStatuses = <String, bool>{};
    
    // Check Homebrew first
    final brewInstalled = await _checkMacOSToolInstalled('brew');
    toolStatuses['brew'] = brewInstalled;
    
    // Check other tools
    for (final tool in _requiredTools) {
      toolStatuses[tool] = await _checkMacOSToolInstalled(tool);
    }
    
    return ReadinessStatus(
      isWindows: false,
      isLinux: false,
      isMacOS: true,
      isWeb: false,
      wslInstalled: false,
      wslDistribution: null,
      wslConnection: false,
      toolStatuses: toolStatuses,
    );
  }
  
  Future<ReadinessStatus> _checkWebReadiness() async {
    final toolStatuses = <String, bool>{};
    for (final tool in _requiredTools) {
      toolStatuses[tool] = await _checkWebToolInstalled(tool);
    }
    
    return ReadinessStatus(
      isWindows: false,
      isLinux: false,
      isMacOS: false,
      isWeb: true,
      wslInstalled: false,
      wslDistribution: null,
      wslConnection: false,
      toolStatuses: toolStatuses,
    );
  }

  Future<bool> _checkToolInstalled(String tool) async {
    try {
      if (tool == 'raft-large-files.txt') {
        final result = await Process.run('wsl', ['test', '-f', '/usr/share/seclists/Discovery/Web-Content/raft-large-files.txt'], runInShell: true);
        return result.exitCode == 0;
      }
      if (tool == 'getoptlong') {
        final result = await Process.run('wsl', ['ruby', '-e', "require 'getoptlong'"], runInShell: true);
        return result.exitCode == 0;
      }
      if (tool == 'impacket') {
        final result = await Process.run('wsl', ['python3', '-c', "import impacket"], runInShell: true);
        return result.exitCode == 0;
      }
      if (tool == 'enum4linux-ng') {
        final result = await Process.run('wsl', ['enum4linux-ng', '-h'], runInShell: true);
        if (result.exitCode == 0) return true;
        // Check for specific error indicating tool is installed but needs arguments
        final stderr = result.stderr.toString();
        if (stderr.contains('enum4linux-ng: error: the following arguments are required')) {
          return true;
        }
        if (stderr.contains('usage: enum4linux-ng')) {
          return true;
        }
        return false;
      }

      final result = await Process.run('wsl', ['command', '-v', tool], runInShell: true);
      return result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  Future<bool> _checkLinuxToolInstalled(String tool) async {
    try {
      if (tool == 'raft-large-files.txt') {
        final file = File('/usr/share/seclists/Discovery/Web-Content/raft-large-files.txt');
        return await file.exists();
      }
      if (tool == 'getoptlong') {
        // Check if getoptlong is available system-wide (accessible to sudo)
        final userResult = await Process.run('ruby', ['-e', "require 'getoptlong'"]);
        if (userResult.exitCode != 0) return false;

        // Check if it's in system gem list (accessible to sudo)
        final systemGemResult = await Process.run('gem', ['list', 'getoptlong']);
        if (systemGemResult.exitCode == 0 && systemGemResult.stdout.toString().contains('getoptlong')) {
          // Verify installation directory is system-wide
          final gemEnvResult = await Process.run('gem', ['environment', 'gemdir']);
          if (gemEnvResult.exitCode == 0) {
            final gemDir = gemEnvResult.stdout.toString().trim();
            // System gems are in /usr or /var, user gems are in /home
            return gemDir.startsWith('/usr') || gemDir.startsWith('/var') || gemDir.contains('/lib/ruby');
          }
        }
        return false;
      }
      if (tool == 'impacket') {
        // Check if impacket is available and installed system-wide
        final result = await Process.run('python3', ['-c', "import impacket, os; print(os.path.dirname(impacket.__file__))"]);
        if (result.exitCode != 0) return false;

        // Verify it's in system site-packages (not user site-packages)
        final path = result.stdout.toString().trim();
        // System packages are in /usr/lib, user packages are in ~/.local
        return path.startsWith('/usr') || path.startsWith('/var');
      }
      if (tool == 'enum4linux-ng') {
        final result = await Process.run('bash', ['-c', 'enum4linux-ng -h']);
        if (result.exitCode == 0) return true;
        final stderr = result.stderr.toString();
        if (stderr.contains('enum4linux-ng: error: the following arguments are required')) return true;
        if (stderr.contains('usage: enum4linux-ng')) return true;
        return false;
      }
      final result = await Process.run('bash', ['-c', 'command -v $tool']);
      return result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  Future<bool> _checkMacOSToolInstalled(String tool) async {
    try {
      final homeDir = Platform.environment['HOME'] ?? '/tmp';
      final pathEnv = 'export PATH="$homeDir/.local/bin:/opt/homebrew/bin:/usr/local/bin:\$PATH"';
      
      if (tool == 'raft-large-files.txt') {
        final file = File('$homeDir/.local/share/seclists/Discovery/Web-Content/raft-large-files.txt');
        if (await file.exists()) return true;
        final file2 = File('/usr/local/share/seclists/Discovery/Web-Content/raft-large-files.txt');
        if (await file2.exists()) return true;
        final file3 = File('/opt/homebrew/share/seclists/Discovery/Web-Content/raft-large-files.txt');
        return await file3.exists();
      }
      if (tool == 'getoptlong') {
        // Check if getoptlong is available
        final userResult = await Process.run('/bin/zsh', ['-c', '$pathEnv && ruby -e "require \'getoptlong\'"']);
        return userResult.exitCode == 0;
      }
      if (tool == 'impacket') {
        // Check if impacket is available and installed system-wide
        final result = await Process.run('/bin/zsh', ['-c', '$pathEnv && python3 -c "import impacket, os; print(os.path.dirname(impacket.__file__))"']);
        if (result.exitCode != 0) return false;

        // Verify it's in system site-packages (not user site-packages)
        final path = result.stdout.toString().trim();
        // System packages are in /usr/lib or /Library, user packages are in ~/Library
        return path.startsWith('/usr') || path.startsWith('/Library') || path.contains('/opt/homebrew');
      }
      if (tool == 'enum4linux-ng') {
        final result = await Process.run('/bin/zsh', ['-c', '$pathEnv && enum4linux-ng -h']);
        if (result.exitCode == 0) return true;
        final stderr = result.stderr.toString();
        if (stderr.contains('enum4linux-ng: error: the following arguments are required')) return true;
        if (stderr.contains('usage: enum4linux-ng')) return true;
        return false;
      }
      
      final result = await Process.run('/bin/zsh', ['-c', '$pathEnv && command -v $tool']);
      return result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty;
    } catch (e) {
      return false;
    }
  }
  
  Future<bool> _checkWebToolInstalled(String tool) async {
    try {
      debugPrint('Checking web tool: $tool via API');
      final response = await http.get(
        Uri.parse('${ApiDatabaseHelper.baseUrl}/system/tools'),
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final result = data[tool] == true;
        return result;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  Future<bool> installTool(String tool) async {
    if (kIsWeb) return await _installWebToolWithOutput(tool, (_) {}, null);
    if (Platform.isLinux) return await _installLinuxTool(tool);
    if (Platform.isWindows) return await _installWindowsTool(tool);
    return false;
  }
  
  Future<bool> installToolWithOutput(String tool, Function(String) onOutput, [String? password, Future<String?> Function()? requestPassword]) async {
    if (kIsWeb) return await _installWebToolWithOutput(tool, onOutput, password);
    if (Platform.isLinux) return await _installLinuxToolWithOutput(tool, onOutput, password);
    if (Platform.isMacOS) {
      if (tool == 'brew') return await _installHomebrewMacOS(onOutput);
      return await _installMacOSToolWithOutput(tool, onOutput, password);
    }
    if (Platform.isWindows) {
      if (tool == 'nmap') {
        return await _installWindowsNativeTool(tool, onOutput);
      }
      return await _installWSLToolWithOutput(tool, onOutput, requestPassword);
    }
    return false;
  }
  
  Future<bool> _installWindowsTool(String tool) async {
    if (tool == 'nmap') {
      try {
        final result = await Process.run('winget', ['install', '-e', '--id', 'Insecure.Nmap']);
        return result.exitCode == 0;
      } catch (e) {
        return false;
      }
    }
    return await _installWSLTool(tool);
  }

  Future<bool> _installWindowsNativeTool(String tool, Function(String) onOutput) async {
    if (tool == 'nmap') {
      onOutput('Attempting to install Nmap using winget...');
      try {
        onOutput('Running: winget install -e --id Insecure.Nmap');
        final process = await Process.start('winget', ['install', '-e', '--id', 'Insecure.Nmap']);
        
        process.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
        process.stderr.transform(utf8.decoder).listen((data) => onOutput('ERROR: ${data.trim()}'));
        
        final exitCode = await process.exitCode;
        if (exitCode == 0) {
          onOutput('Winget installation successful. Please restart the app for changes to take effect.');
          return true;
        } else {
           onOutput('Winget installation failed with exit code $exitCode');
        }
      } catch (e) {
        onOutput('Winget installation failed: $e');
      }
      onOutput('Please install Nmap manually from https://nmap.org/download.html');
      return false;
    }
    return false;
  }
  
  Future<bool> _installLinuxTool(String tool) async {
    // Basic silent install logic (stub)
    return false;
  }
  
  Future<bool> _installMacOSToolWithOutput(String tool, Function(String) onOutput, [String? password]) async {
    final specialInstaller = _getSpecialInstaller(tool, isWSL: false, isMacOS: true);
    if (specialInstaller != null) {
      return await specialInstaller(onOutput, password);
    }

    try {
      onOutput('Checking for Homebrew...');
      final brewCheck = await Process.run('/bin/zsh', ['-c', 'export PATH="/opt/homebrew/bin:/usr/local/bin:\$PATH" && command -v brew']);
      
      if (brewCheck.exitCode != 0) {
        onOutput('Homebrew not found.');
        onOutput('Please install Homebrew first: https://brew.sh');
        return false;
      }
      
      final packageName = _getMacOSPackageName(tool);
      onOutput('Installing $packageName with Homebrew...');
      
      final process = await Process.start('/bin/zsh', ['-c', 'export PATH="/opt/homebrew/bin:/usr/local/bin:\$PATH" && brew install $packageName']);
      
      process.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
      process.stderr.transform(utf8.decoder).listen((data) => onOutput('BREW: ${data.trim()}'));
      
      final exitCode = await process.exitCode;
      
      if (exitCode == 0 || exitCode == 1) {
        await Future.delayed(Duration(seconds: 2));
        final installed = await _checkMacOSToolInstalled(tool);
        if (installed) {
          onOutput('Installation successful!');
          return true;
        }
      }
      onOutput('Installation failed with exit code: $exitCode');
      return false;
    } catch (e) {
      onOutput('Error: $e');
      return false;
    }
  }
  
  Future<bool> _installLinuxToolWithOutput(String tool, Function(String) onOutput, [String? password]) async {
    final specialInstaller = _getSpecialInstaller(tool, isWSL: false, isMacOS: false);
    if (specialInstaller != null) {
      return await specialInstaller(onOutput, password);
    }

    final managers = ['apt', 'yum', 'dnf', 'pacman', 'rpm', 'dpkg', 'zypper'];
    
    for (final manager in managers) {
      try {
        onOutput('Checking for $manager...');
        final checkResult = await Process.run('bash', ['-c', 'command -v $manager']);
        if (checkResult.exitCode == 0) {
          final packageName = _getPackageName(tool, manager);
          onOutput('Found $manager, installing $packageName...');
          final installCmd = _getInstallCommand(manager, packageName);
          onOutput('Running: sudo ${installCmd.join(' ')}');
          
          final process = await Process.start('sudo', ['-S', ...installCmd]);
          
          if (password != null) {
            process.stdin.writeln(password);
          }
          
          process.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
          process.stderr.transform(utf8.decoder).listen((data) => onOutput('ERROR: ${data.trim()}'));
          
          final exitCode = await process.exitCode;
          onOutput('Command finished with exit code: $exitCode');
          
          if (exitCode == 0) {
            final installed = await _checkLinuxToolInstalled(tool);
            onOutput(installed ? 'Installation successful!' : 'Installation verification failed');
            return installed;
          }
        }
      } catch (e) {
        onOutput('Error with $manager: $e');
        continue;
      }
    }
    onOutput('No suitable package manager found');
    return false;
  }
  
  Future<bool> _installWSLTool(String tool) async {
    return false;
  }
  
  Future<bool> _installWSLToolWithOutput(String tool, Function(String) onOutput, [Future<String?> Function()? requestPassword]) async {
    final specialInstaller = _getSpecialInstaller(tool, isWSL: true, isMacOS: false);
    if (specialInstaller != null) {
      return await specialInstaller(onOutput, null);
    }

    final managers = ['apt', 'yum', 'dnf', 'pacman', 'rpm', 'dpkg', 'zypper'];
    
    for (final manager in managers) {
      try {
        onOutput('Checking for $manager in WSL...');
        final checkResult = await Process.run('wsl', ['command', '-v', manager], runInShell: true);
        if (checkResult.exitCode == 0) {
          final packageName = _getPackageName(tool, manager);
          onOutput('Found $manager, installing $packageName...');
          final installCmd = _getInstallCommand(manager, packageName);
          
          final process = await Process.start('wsl', ['-u', 'root', '--', 'bash', '-lc', installCmd.join(' ')], runInShell: true);
          
          process.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
          process.stderr.transform(utf8.decoder).listen((data) => onOutput('ERROR: ${data.trim()}'));
          
          final exitCode = await process.exitCode;
          onOutput('Command finished with exit code: $exitCode');
          
          if (exitCode == 0) {
            final installed = await _checkToolInstalled(tool);
            onOutput(installed ? 'Installation successful!' : 'Installation verification failed');
            return installed;
          }
        }
      } catch (e) {
        onOutput('Error with $manager: $e');
        continue;
      }
    }
    return false;
  }
  
  Future<bool> _installWebToolWithOutput(String tool, Function(String) onOutput, [String? password]) async {
    try {
      onOutput('Installing $tool via API...');
      final response = await http.post(
        Uri.parse('${ApiDatabaseHelper.baseUrl}/install-tool-with-output'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'tool': tool, 'password': password}),
      ).timeout(const Duration(minutes: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        final output = data['output'] as String? ?? '';
        final success = data['success'] as bool? ?? false;
        
        if (output.isNotEmpty) {
          onOutput(output);
        }
        
        return success;
      }
      onOutput('Installation failed: HTTP ${response.statusCode}');
      return false;
    } catch (e) {
      onOutput('Installation error: $e');
      return false;
    }
  }
  
  
  Future<bool> Function(Function(String), String?)? _getSpecialInstaller(String tool, {required bool isWSL, required bool isMacOS}) {
    if (tool == 'searchsploit') {
      if (isWSL) return (onOutput, _) => _installSearchsploitWSL(onOutput);
      if (isMacOS) return (onOutput, password) => _installSearchsploitMacOS(onOutput, password);
      return (onOutput, password) => _installSearchsploitLinux(onOutput, password);
    }
    if (tool == 'enum4linux-ng') {
      if (isWSL) return (onOutput, _) => _installEnum4linuxWSL(onOutput);
      if (isMacOS) return (onOutput, password) => _installEnum4linuxMacOS(onOutput, password);
      return (onOutput, password) => _installEnum4linuxLinux(onOutput, password);
    }
    if (tool == 'ffuf') {
      if (!isWSL && !isMacOS) return (onOutput, password) => _installFfufLinux(onOutput, password);
    }
    if (tool == 'whatweb') {
      if (isMacOS) return (onOutput, password) => _installWhatWebMacOS(onOutput, password);
      if (!isWSL) return (onOutput, password) => _installWhatWebLinux(onOutput, password);
    }
    if (tool == 'raft-large-files.txt') {
      if (isWSL) return (onOutput, _) => _installRaftFileWSL(onOutput);
      if (isMacOS) return (onOutput, password) => _installRaftFileMacOS(onOutput, password);
      return (onOutput, password) => _installRaftFileLinux(onOutput, password);
    }
    if (tool == 'getoptlong') {
      if (isWSL) return (onOutput, _) => _installGetoptLongWSL(onOutput);
      if (isMacOS) return (onOutput, password) => _installGetoptLongMacOS(onOutput, password);
      return (onOutput, password) => _installGetoptLongLinux(onOutput, password);
    }
    if (tool == 'impacket') {
      if (isWSL) return (onOutput, _) => _installImpacketWSL(onOutput);
      if (isMacOS) return (onOutput, password) => _installImpacketMacOS(onOutput, password);
      return (onOutput, password) => _installImpacketLinux(onOutput, password);
    }
    return null;
  }

  String _getPackageName(String tool, [String? manager]) {
    switch (tool) {
      case 'searchsploit': return 'exploitdb';
      case 'enum4linux-ng': return 'enum4linux-ng';
      case 'go': return 'golang-go';
      case 'whatweb': return 'whatweb';
      case 'nikto': return 'nikto';
      case 'ffuf': return 'ffuf';
      default: return tool;
    }
  }
  
  String _getMacOSPackageName(String tool) {
    switch (tool) {
      case 'searchsploit': return 'exploitdb';
      case 'enum4linux-ng': return 'enum4linux-ng';
      case 'go': return 'go';
      case 'whatweb': return 'whatweb';
      case 'nikto': return 'nikto';
      case 'ffuf': return 'ffuf';
      default: return tool;
    }
  }
  
  List<String> _getInstallCommand(String manager, String packageName) {
    switch (manager) {
      case 'apt': return [manager, 'install', '-y', packageName];
      case 'yum': case 'dnf': return [manager, 'install', '-y', packageName];
      case 'pacman': return [manager, '-S', '--noconfirm', packageName];
      default: return [manager, 'install', '-y', packageName];
    }
  }

  // --- EXISTING HELPERS ---

  Future<bool> _ensureParuInstalled(Function(String) onOutput, String? password) async {
    // Check if paru is already installed
    if ((await Process.run('bash', ['-c', 'command -v paru'])).exitCode == 0) {
      return true;
    }

    // Check if this is Arch Linux (has pacman)
    if ((await Process.run('bash', ['-c', 'command -v pacman'])).exitCode != 0) {
      return false; // Not Arch, can't install paru
    }

    onOutput('Installing paru AUR helper for Arch Linux...');

    try {
      // Ensure base-devel and git are installed
      onOutput('Installing base-devel and git...');
      final baseDevelProc = await Process.start('sudo', ['-S', 'pacman', '-S', '--needed', '--noconfirm', 'base-devel', 'git']);
      if (password != null) baseDevelProc.stdin.writeln(password);
      baseDevelProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
      await baseDevelProc.exitCode;

      // Clone paru repository
      onOutput('Cloning paru repository...');
      final tempDir = Directory.systemTemp.createTempSync('paru_install_');
      final cloneProc = await Process.start('git', ['clone', 'https://aur.archlinux.org/paru.git', tempDir.path]);
      cloneProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
      await cloneProc.exitCode;

      // Build and install paru
      onOutput('Building and installing paru...');
      final buildProc = await Process.start('bash', ['-c', 'cd ${tempDir.path} && makepkg -si --noconfirm']);
      buildProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
      buildProc.stderr.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
      await buildProc.exitCode;

      // Clean up
      try { tempDir.deleteSync(recursive: true); } catch (_) {}

      // Verify installation
      final installed = (await Process.run('bash', ['-c', 'command -v paru'])).exitCode == 0;
      onOutput(installed ? 'paru installed successfully!' : 'paru installation failed');
      return installed;
    } catch (e) {
      onOutput('Failed to install paru: $e');
      return false;
    }
  }

  Future<bool> _installFfufLinux(Function(String) onOutput, String? password) async {
    try {
      onOutput('Installing FFUF...');

      final managers = ['apt', 'yum', 'dnf', 'pacman', 'zypper'];

      for (final manager in managers) {
        try {
          onOutput('Checking for $manager...');
          final checkResult = await Process.run('bash', ['-c', 'command -v $manager']);
          if (checkResult.exitCode == 0) {
            final packageName = _getPackageName('ffuf', manager);
            onOutput('Found $manager, installing $packageName...');
            final installCmd = _getInstallCommand(manager, packageName);
            onOutput('Running: sudo ${installCmd.join(' ')}');

            final process = await Process.start('sudo', ['-S', ...installCmd]);

            if (password != null) {
              process.stdin.writeln(password);
            }

            process.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
            process.stderr.transform(utf8.decoder).listen((data) => onOutput('ERROR: ${data.trim()}'));

            final exitCode = await process.exitCode;
            onOutput('Command finished with exit code: $exitCode');

            if (exitCode == 0) {
              final installed = await _checkLinuxToolInstalled('ffuf');
              onOutput(installed ? 'Installation successful!' : 'Installation verification failed');
              return installed;
            }
          }
        } catch (e) {
          onOutput('Error with $manager: $e');
          continue;
        }
      }

      // Fallback: Try installing from GitHub releases (Go binary)
      onOutput('Package manager installation failed, trying GitHub release...');
      onOutput('Installing FFUF from GitHub releases...');

      try {
        final tempDir = Directory.systemTemp.createTempSync('ffuf_install_');
        final downloadUrl = 'https://github.com/ffuf/ffuf/releases/latest/download/ffuf_2.1.0_linux_amd64.tar.gz';

        onOutput('Downloading FFUF...');
        final curlProc = await Process.start('bash', ['-c', 'curl -L $downloadUrl -o ${tempDir.path}/ffuf.tar.gz']);
        curlProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
        await curlProc.exitCode;

        onOutput('Extracting...');
        await Process.run('tar', ['-xzf', '${tempDir.path}/ffuf.tar.gz', '-C', tempDir.path]);

        onOutput('Installing to /usr/local/bin...');
        final installProc = await Process.start('sudo', ['-S', 'mv', '${tempDir.path}/ffuf', '/usr/local/bin/ffuf']);
        if (password != null) installProc.stdin.writeln(password);
        await installProc.exitCode;

        await Process.run('sudo', ['-S', 'chmod', '+x', '/usr/local/bin/ffuf']);

        try { tempDir.deleteSync(recursive: true); } catch (_) {}

        final installed = await _checkLinuxToolInstalled('ffuf');
        onOutput(installed ? 'Installation successful via GitHub!' : 'Installation verification failed');
        return installed;
      } catch (e) {
        onOutput('GitHub installation failed: $e');
      }

      onOutput('All installation methods failed');
      return false;
    } catch (e) {
      onOutput('FFUF installation error: $e');
      return false;
    }
  }
  Future<bool> _installWhatWebLinux(Function(String) onOutput, String? password) async {
    try {
      onOutput('Installing WhatWeb...');

      // First ensure Ruby gem dependencies are installed system-wide (WhatWeb needs these)
      onOutput('Checking for Ruby gem dependencies...');

      // Check and install getoptlong
      final getoptInstalled = await _checkLinuxToolInstalled('getoptlong');
      if (!getoptInstalled) {
        onOutput('Installing getoptlong gem...');
        await _installGetoptLongLinux(onOutput, password);
      }

      // Check and install resolv-replace (also removed from Ruby 3.4.0)
      onOutput('Checking for resolv-replace gem...');
      final resolvCheck = await Process.run('ruby', ['-e', "require 'resolv-replace'"]);
      if (resolvCheck.exitCode != 0) {
        onOutput('Installing resolv-replace gem system-wide...');
        final resolvProc = await Process.start('sudo', ['-S', 'gem', 'install', 'resolv-replace', '--no-user-install']);
        if (password != null) resolvProc.stdin.writeln(password);
        resolvProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
        resolvProc.stderr.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
        await resolvProc.exitCode;
      }

      // Check and install addressable (required by WhatWeb)
      onOutput('Checking for addressable gem...');
      final addressCheck = await Process.run('ruby', ['-e', "require 'addressable'"]);
      if (addressCheck.exitCode != 0) {
        onOutput('Installing addressable gem system-wide...');
        final addressProc = await Process.start('sudo', ['-S', 'gem', 'install', 'addressable', '--no-user-install']);
        if (password != null) addressProc.stdin.writeln(password);
        addressProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
        addressProc.stderr.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
        await addressProc.exitCode;
      }

      final managers = ['apt', 'yum', 'dnf', 'pacman', 'zypper'];

      for (final manager in managers) {
        try {
          onOutput('Checking for $manager...');
          final checkResult = await Process.run('bash', ['-c', 'command -v $manager']);
          if (checkResult.exitCode == 0) {
            final packageName = _getPackageName('whatweb', manager);
            onOutput('Found $manager, installing $packageName...');
            final installCmd = _getInstallCommand(manager, packageName);
            onOutput('Running: sudo ${installCmd.join(' ')}');

            final process = await Process.start('sudo', ['-S', ...installCmd]);

            if (password != null) {
              process.stdin.writeln(password);
            }

            process.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
            process.stderr.transform(utf8.decoder).listen((data) => onOutput('ERROR: ${data.trim()}'));

            final exitCode = await process.exitCode;
            onOutput('Command finished with exit code: $exitCode');

            if (exitCode == 0) {
              final installed = await _checkLinuxToolInstalled('whatweb');
              onOutput(installed ? 'Installation successful!' : 'Installation verification failed');
              return installed;
            }
          }
        } catch (e) {
          onOutput('Error with $manager: $e');
          continue;
        }
      }

      // Try AUR helpers for Arch Linux (install paru if needed)
      onOutput('Checking for AUR helper...');
      final hasAurHelper = (await Process.run('bash', ['-c', 'command -v paru'])).exitCode == 0 ||
                           (await Process.run('bash', ['-c', 'command -v yay'])).exitCode == 0;

      if (!hasAurHelper && (await Process.run('bash', ['-c', 'command -v pacman'])).exitCode == 0) {
        // This is Arch Linux but no AUR helper - install paru
        onOutput('No AUR helper found. Installing paru...');
        await _ensureParuInstalled(onOutput, password);
      }

      // Now try with paru or yay
      if ((await Process.run('bash', ['-c', 'command -v paru'])).exitCode == 0) {
        onOutput('Installing whatweb and ruby-addressable from AUR via paru...');
        final paruProc = await Process.start('paru', ['-S', '--noconfirm', 'whatweb', 'ruby-addressable']);
        paruProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
        paruProc.stderr.transform(utf8.decoder).listen((data) => onOutput('ERROR: ${data.trim()}'));

        if (await paruProc.exitCode == 0) {
          final installed = await _checkLinuxToolInstalled('whatweb');
          onOutput(installed ? 'Installation successful via paru!' : 'Installation verification failed');
          return installed;
        }
      } else if ((await Process.run('bash', ['-c', 'command -v yay'])).exitCode == 0) {
        onOutput('Installing whatweb and ruby-addressable from AUR via yay...');
        final yayProc = await Process.start('yay', ['-S', '--noconfirm', 'whatweb', 'ruby-addressable']);
        yayProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
        yayProc.stderr.transform(utf8.decoder).listen((data) => onOutput('ERROR: ${data.trim()}'));

        if (await yayProc.exitCode == 0) {
          final installed = await _checkLinuxToolInstalled('whatweb');
          onOutput(installed ? 'Installation successful via yay!' : 'Installation verification failed');
          return installed;
        }
      }

      // Fallback: Install from GitHub
      onOutput('All package managers failed, installing from GitHub...');
      try {
        onOutput('Ensuring git is installed...');
        final gitCheck = await Process.run('bash', ['-c', 'command -v git']);
        if (gitCheck.exitCode != 0) {
          onOutput('Git not found. Installing git first...');
          if ((await Process.run('bash', ['-c', 'command -v pacman'])).exitCode == 0) {
            final gitProc = await Process.start('sudo', ['-S', 'pacman', '-S', '--noconfirm', 'git']);
            if (password != null) gitProc.stdin.writeln(password);
            await gitProc.exitCode;
          }
        }

        onOutput('Cloning WhatWeb repository...');
        final tempDir = Directory.systemTemp.createTempSync('whatweb_install_');
        final cloneProc = await Process.start('git', ['clone', 'https://github.com/urbanadventurer/WhatWeb.git', tempDir.path]);
        cloneProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
        await cloneProc.exitCode;

        onOutput('Installing to /opt/whatweb...');
        final mvProc = await Process.start('sudo', ['-S', 'mv', tempDir.path, '/opt/whatweb']);
        if (password != null) mvProc.stdin.writeln(password);
        await mvProc.exitCode;

        onOutput('Creating symlink...');
        final lnProc = await Process.start('sudo', ['-S', 'ln', '-sf', '/opt/whatweb/whatweb', '/usr/local/bin/whatweb']);
        if (password != null) lnProc.stdin.writeln(password);
        await lnProc.exitCode;

        // Make executable
        await Process.run('sudo', ['-S', 'chmod', '+x', '/opt/whatweb/whatweb']);

        // Ensure Ruby and dependencies are installed
        onOutput('Checking Ruby dependencies...');
        if ((await Process.run('bash', ['-c', 'command -v pacman'])).exitCode == 0) {
          final rubyProc = await Process.start('sudo', ['-S', 'pacman', '-S', '--noconfirm', 'ruby', 'ruby-bundler']);
          if (password != null) rubyProc.stdin.writeln(password);
          await rubyProc.exitCode;
        }

        // Try to use bundle install if Gemfile exists
        onOutput('Installing gem dependencies with bundler...');
        final gemfileCheck = await File('/opt/whatweb/Gemfile').exists();
        if (gemfileCheck) {
          onOutput('Found Gemfile, running bundle install...');
          final bundleProc = await Process.start('bash', ['-c', 'cd /opt/whatweb && bundle install']);
          bundleProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
          bundleProc.stderr.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
          await bundleProc.exitCode;
        }

        final installed = await _checkLinuxToolInstalled('whatweb');
        onOutput(installed ? 'Installation successful via GitHub!' : 'Installation verification failed');
        return installed;
      } catch (e) {
        onOutput('GitHub installation failed: $e');
      }

      onOutput('All installation methods failed');
      return false;
    } catch (e) {
      onOutput('WhatWeb installation error: $e');
      return false;
    }
  }
  Future<bool> _installSearchsploitLinux(Function(String) onOutput, String? password) async {
    try {
      onOutput('Installing SearchSploit (exploitdb)...');

      final managers = ['apt', 'yum', 'dnf', 'pacman', 'zypper'];

      for (final manager in managers) {
        try {
          onOutput('Checking for $manager...');
          final checkResult = await Process.run('bash', ['-c', 'command -v $manager']);
          if (checkResult.exitCode == 0) {
            final packageName = _getPackageName('searchsploit', manager);
            onOutput('Found $manager, installing $packageName...');
            final installCmd = _getInstallCommand(manager, packageName);
            onOutput('Running: sudo ${installCmd.join(' ')}');

            final process = await Process.start('sudo', ['-S', ...installCmd]);

            if (password != null) {
              process.stdin.writeln(password);
            }

            process.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
            process.stderr.transform(utf8.decoder).listen((data) => onOutput('ERROR: ${data.trim()}'));

            final exitCode = await process.exitCode;
            onOutput('Command finished with exit code: $exitCode');

            if (exitCode == 0) {
              // Update searchsploit database after installation
              onOutput('Updating searchsploit database...');
              final updateProc = await Process.start('searchsploit', ['-u']);
              updateProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
              await updateProc.exitCode;

              final installed = await _checkLinuxToolInstalled('searchsploit');
              onOutput(installed ? 'Installation successful!' : 'Installation verification failed');
              return installed;
            }
          }
        } catch (e) {
          onOutput('Error with $manager: $e');
          continue;
        }
      }

      // Fallback: Install from GitHub
      onOutput('Package manager installation failed, trying GitHub...');
      try {
        final tempDir = Directory.systemTemp.createTempSync('exploitdb_install_');

        onOutput('Cloning exploitdb repository...');
        final cloneProc = await Process.start('git', ['clone', 'https://github.com/offensive-security/exploitdb.git', tempDir.path]);
        cloneProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
        await cloneProc.exitCode;

        onOutput('Installing to /opt/exploitdb...');
        final mvProc = await Process.start('sudo', ['-S', 'mv', tempDir.path, '/opt/exploitdb']);
        if (password != null) mvProc.stdin.writeln(password);
        await mvProc.exitCode;

        onOutput('Creating symlink...');
        final lnProc = await Process.start('sudo', ['-S', 'ln', '-sf', '/opt/exploitdb/searchsploit', '/usr/local/bin/searchsploit']);
        if (password != null) lnProc.stdin.writeln(password);
        await lnProc.exitCode;

        final installed = await _checkLinuxToolInstalled('searchsploit');
        onOutput(installed ? 'Installation successful via GitHub!' : 'Installation verification failed');
        return installed;
      } catch (e) {
        onOutput('GitHub installation failed: $e');
      }

      onOutput('All installation methods failed');
      return false;
    } catch (e) {
      onOutput('SearchSploit installation error: $e');
      return false;
    }
  }
  Future<bool> _installSearchsploitWSL(Function(String) onOutput) async {
    try {
      onOutput('Installing SearchSploit (exploitdb) in WSL...');

      // Try apt first (most common in WSL)
      onOutput('Trying apt install exploitdb...');
      final aptProc = await Process.start('wsl', ['-u', 'root', '--', 'bash', '-lc', 'apt update && apt install -y exploitdb'], runInShell: true);

      aptProc.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) => onOutput(line));
      aptProc.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) => onOutput('Error: $line'));

      if (await aptProc.exitCode == 0) {
        // Update searchsploit database with timeout
        onOutput('Updating searchsploit database (this may take several minutes)...');
        try {
          final updateProc = await Process.start('wsl', ['searchsploit', '-u'], runInShell: true);
          updateProc.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) => onOutput(line));
          
          // Add 10 minute timeout for database update
          final exitCode = await updateProc.exitCode.timeout(
            Duration(minutes: 10),
            onTimeout: () {
              onOutput('Database update timed out after 10 minutes - killing process');
              updateProc.kill();
              return -1;
            },
          );
          
          if (exitCode == 0) {
            onOutput('Database update completed successfully');
          } else if (exitCode == -1) {
            onOutput('Database update timed out but SearchSploit is installed and functional');
          } else {
            onOutput('Database update failed with exit code $exitCode, but SearchSploit is installed');
          }
        } catch (e) {
          onOutput('Database update failed: $e, but SearchSploit is installed');
        }

        final installed = await _checkToolInstalled('searchsploit');
        onOutput(installed ? 'Installation successful!' : 'Installation verification failed');
        return installed;
      }

      // Fallback: Install from GitHub
      onOutput('Apt installation failed, trying GitHub...');
      final cloneProc = await Process.start('wsl', ['-u', 'root', '--', 'bash', '-lc', 'git clone https://github.com/offensive-security/exploitdb.git /opt/exploitdb && ln -sf /opt/exploitdb/searchsploit /usr/local/bin/searchsploit'], runInShell: true);

      cloneProc.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) => onOutput(line));
      cloneProc.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) => onOutput(line));

      if (await cloneProc.exitCode == 0) {
        final installed = await _checkToolInstalled('searchsploit');
        onOutput(installed ? 'Installation successful via GitHub!' : 'Installation verification failed');
        return installed;
      }

      onOutput('All installation methods failed');
      return false;
    } catch (e) {
      onOutput('SearchSploit WSL installation error: $e');
      return false;
    }
  }
  
  Future<bool> _installEnum4linuxLinux(Function(String) onOutput, String? password) async {
    try {
      onOutput('Installing Enum4linux-ng and dependencies...');

      // Ensure Python dependencies are installed
      await _installImpacketLinux(onOutput, password);

      // Install required Python modules: PyYAML and ldap3
      onOutput('Installing required Python modules (PyYAML, ldap3)...');
      final pythonDeps = ['pyyaml', 'ldap3', 'impacket'];
      for (final dep in pythonDeps) {
        try {
          final depProc = await Process.start('sudo', ['-S', 'python3', '-m', 'pip', 'install', dep, '--break-system-packages']);
          if (password != null) depProc.stdin.writeln(password);
          depProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
          await depProc.exitCode;
        } catch (e) {
          onOutput('Warning: Could not install $dep via pip: $e');
        }
      }

      // Try apt first (Debian/Ubuntu/Kali) - most reliable
      if ((await Process.run('bash', ['-c', 'command -v apt'])).exitCode == 0) {
         onOutput('Trying apt install enum4linux-ng...');
         final aptProc = await Process.start('sudo', ['-S', 'apt', 'update']);
         if (password != null) aptProc.stdin.writeln(password);
         aptProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
         await aptProc.exitCode;

         final aptInstall = await Process.start('sudo', ['-S', 'apt', 'install', '-y', 'enum4linux-ng']);
         if (password != null) aptInstall.stdin.writeln(password);
         aptInstall.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
         aptInstall.stderr.transform(utf8.decoder).listen((data) => onOutput(data.trim()));

         if (await aptInstall.exitCode == 0) {
            if (await _checkLinuxToolInstalled('enum4linux-ng')) {
              onOutput('Installation successful via apt!');
              return true;
            }
         }
      }

      // Try AUR helpers for Arch Linux (install paru if needed)
      onOutput('Checking for AUR helper...');
      final hasAurHelper = (await Process.run('bash', ['-c', 'command -v paru'])).exitCode == 0 ||
                           (await Process.run('bash', ['-c', 'command -v yay'])).exitCode == 0;

      if (!hasAurHelper && (await Process.run('bash', ['-c', 'command -v pacman'])).exitCode == 0) {
        // This is Arch Linux but no AUR helper - install paru
        onOutput('No AUR helper found. Installing paru...');
        await _ensureParuInstalled(onOutput, password);
      }

      // Now try with paru or yay
      if ((await Process.run('bash', ['-c', 'command -v paru'])).exitCode == 0) {
         onOutput('Installing enum4linux-ng from AUR via paru...');
         final paruProc = await Process.start('paru', ['-S', '--noconfirm', 'enum4linux-ng']);
         paruProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
         paruProc.stderr.transform(utf8.decoder).listen((data) => onOutput(data.trim()));

         if (await paruProc.exitCode == 0) {
            if (await _checkLinuxToolInstalled('enum4linux-ng')) {
              onOutput('Installation successful via paru!');
              return true;
            }
         }
      } else if ((await Process.run('bash', ['-c', 'command -v yay'])).exitCode == 0) {
         onOutput('Installing enum4linux-ng from AUR via yay...');
         final yayProc = await Process.start('yay', ['-S', '--noconfirm', 'enum4linux-ng']);
         yayProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
         yayProc.stderr.transform(utf8.decoder).listen((data) => onOutput(data.trim()));

         if (await yayProc.exitCode == 0) {
            if (await _checkLinuxToolInstalled('enum4linux-ng')) {
              onOutput('Installation successful via yay!');
              return true;
            }
         }
      }

      // Fallback: Install from GitHub repository
      onOutput('Trying to install from GitHub repository...');
      onOutput('Installing git if needed...');

      // Ensure git is installed
      final gitCheck = await Process.run('bash', ['-c', 'command -v git']);
      if (gitCheck.exitCode != 0) {
        if ((await Process.run('bash', ['-c', 'command -v apt'])).exitCode == 0) {
          final gitInstall = await Process.start('sudo', ['-S', 'apt', 'install', '-y', 'git']);
          if (password != null) gitInstall.stdin.writeln(password);
          await gitInstall.exitCode;
        } else if ((await Process.run('bash', ['-c', 'command -v pacman'])).exitCode == 0) {
          final gitInstall = await Process.start('sudo', ['-S', 'pacman', '-S', '--noconfirm', 'git']);
          if (password != null) gitInstall.stdin.writeln(password);
          await gitInstall.exitCode;
        }
      }

      onOutput('Cloning enum4linux-ng repository...');
      final tempDir = Directory.systemTemp.createTempSync('enum4linux_install_');
      final cloneProc = await Process.start('git', ['clone', 'https://github.com/cddmp/enum4linux-ng.git', tempDir.path]);
      cloneProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
      cloneProc.stderr.transform(utf8.decoder).listen((data) => onOutput(data.trim()));

      if (await cloneProc.exitCode == 0) {
        onOutput('Installing via pip from repository...');
        final installProc = await Process.start('sudo', ['-S', 'python3', '-m', 'pip', 'install', tempDir.path, '--break-system-packages']);
        if (password != null) installProc.stdin.writeln(password);
        installProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
        installProc.stderr.transform(utf8.decoder).listen((data) => onOutput(data.trim()));

        if (await installProc.exitCode == 0) {
          // Clean up temp directory
          try { tempDir.deleteSync(recursive: true); } catch (_) {}

          if (await _checkLinuxToolInstalled('enum4linux-ng')) {
            onOutput('Installation successful via GitHub!');
            return true;
          }
        }
      }

      // Clean up temp directory if it still exists
      try { tempDir.deleteSync(recursive: true); } catch (_) {}

      final finalCheck = await _checkLinuxToolInstalled('enum4linux-ng');
      if (finalCheck) {
        onOutput('Installation verification successful!');
      } else {
        onOutput('Installation failed. Please install manually:');
        onOutput('  Arch: paru -S enum4linux-ng');
        onOutput('  Debian/Ubuntu: sudo apt install enum4linux-ng');
        onOutput('  Or: git clone https://github.com/cddmp/enum4linux-ng.git && cd enum4linux-ng && sudo pip3 install .');
      }
      return finalCheck;
    } catch (e) {
      onOutput('Enum4linux-ng installation error: $e');
      return false;
    }
  }

  Future<bool> _installEnum4linuxWSL(Function(String) onOutput) async {
    try {
      onOutput('Installing Enum4linux-ng and dependencies in WSL...');

      // Ensure Python dependencies are installed
      await _installImpacketWSL(onOutput);

      // Install required Python modules: PyYAML and ldap3
      onOutput('Installing required Python modules (PyYAML, ldap3)...');
      final pythonDeps = ['pyyaml', 'ldap3', 'impacket'];
      for (final dep in pythonDeps) {
        try {
          final depProc = await Process.start('wsl', ['-u', 'root', '--', 'bash', '-lc', 'python3 -m pip install $dep --break-system-packages'], runInShell: true);
          depProc.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) => onOutput(line));
          await depProc.exitCode;
        } catch (e) {
          onOutput('Warning: Could not install $dep via pip: $e');
        }
      }
      
      // Try pip install
      onOutput('Trying pip install enum4linux-ng...');
      final pipProc = await Process.start('wsl', ['-u', 'root', '--', 'bash', '-lc', 'python3 -m pip install enum4linux-ng --break-system-packages'], runInShell: true);
      
      pipProc.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) => onOutput(line));
      pipProc.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) => onOutput('Error: $line'));
      
      if (await pipProc.exitCode == 0) {
         // Verify installation
         onOutput('Verifying pip installation...');
         // enum4linux-ng requires a host argument, so running with -h to verify it executes
         final checkResult = await Process.run('wsl', ['enum4linux-ng', '-h'], runInShell: true);
         if (checkResult.exitCode == 0) {
            onOutput('Verification successful: ${checkResult.stdout}');
            return true;
         } else {
            // Check if failure is due to missing arguments (which means it's installed)
            final stderr = checkResult.stderr.toString();
            if (stderr.contains('enum4linux-ng: error: the following arguments are required')) {
               onOutput('Verification successful (argument check pass).');
               return true;
            }
            if (stderr.contains('usage: enum4linux-ng')) {
               onOutput('Verification successful (usage check pass).');
               return true;
            }

            onOutput('Verification failed: ${checkResult.stderr}');
            // Try to force reinstall if verification fails but pip said success
            onOutput('Attempting force reinstall via pip...');
            final forcePip = await Process.start('wsl', ['-u', 'root', '--', 'bash', '-lc', 'python3 -m pip install --force-reinstall enum4linux-ng --break-system-packages'], runInShell: true);
            forcePip.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) => onOutput(line));
            await forcePip.exitCode;
         }
      }
      
      // Try apt (Kali/Debian/Ubuntu WSL)
      onOutput('Trying apt install enum4linux-ng...');
      final aptProc = await Process.start('wsl', ['-u', 'root', '--', 'bash', '-lc', 'apt update && apt install -y enum4linux-ng'], runInShell: true);
      
      aptProc.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) => onOutput(line));
      aptProc.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) => onOutput('Error: $line'));
      
      if (await aptProc.exitCode == 0) {
         // Verify again
         onOutput('Verifying apt installation...');
         final checkResult = await Process.run('wsl', ['enum4linux-ng', '-h'], runInShell: true);
         if (checkResult.exitCode == 0) {
            onOutput('Verification successful.');
            return true;
         } else {
            // Check if failure is due to missing arguments
            final stderr = checkResult.stderr.toString();
            if (stderr.contains('enum4linux-ng: error: the following arguments are required')) {
               onOutput('Verification successful (argument check pass).');
               return true;
            }
            if (stderr.contains('usage: enum4linux-ng')) {
               onOutput('Verification successful (usage check pass).');
               return true;
            }

            onOutput('Verification failed: ${checkResult.stderr}');
            // Try reinstall via apt
            onOutput('Attempting reinstall via apt...');
            final reinstallApt = await Process.start('wsl', ['-u', 'root', '--', 'bash', '-lc', 'apt install --reinstall -y enum4linux-ng python3-impacket'], runInShell: true);
            reinstallApt.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) => onOutput(line));
            await reinstallApt.exitCode;
         }
      }

      final finalCheck = await _checkToolInstalled('enum4linux-ng');
      if (!finalCheck) {
        // One last diagnostic check - check if binary exists but fails to run
        final whichProc = await Process.run('wsl', ['which', 'enum4linux-ng'], runInShell: true);
        if (whichProc.exitCode == 0) {
           final binaryPath = whichProc.stdout.toString().trim();
           onOutput('Binary found at: $binaryPath');
           // Try running it directly
           final runDirect = await Process.run('wsl', [binaryPath, '-h'], runInShell: true);
           onOutput('Direct run output: ${runDirect.stdout}');
           onOutput('Direct run stderr: ${runDirect.stderr}');
           if (runDirect.exitCode == 0) {
             onOutput('Direct run successful - tool is actually installed!');
             return true; // Force return true if direct run works
           }
           // Check stderr for success indicators even if exit code is non-zero
           if (runDirect.stderr.toString().contains('usage: enum4linux-ng') || 
               runDirect.stderr.toString().contains('enum4linux-ng: error:')) {
             onOutput('Direct run successful (based on stderr) - tool is installed!');
             return true;
           }
        } else {
           onOutput('Binary not found in PATH');
        }
      }
      return finalCheck;
    } catch (e) {
      onOutput('Enum4linux-ng installation error: $e');
      return false;
    }
  }

  Future<bool> _installRaftFileLinux(Function(String) onOutput, String? password) async {
    try {
      onOutput('Installing Raft Large Files wordlist (SecLists)...');

      final managers = ['apt', 'yum', 'dnf', 'pacman', 'zypper'];

      // Try installing seclists package first
      for (final manager in managers) {
        try {
          onOutput('Checking for $manager...');
          final checkResult = await Process.run('bash', ['-c', 'command -v $manager']);
          if (checkResult.exitCode == 0) {
            onOutput('Found $manager, installing seclists...');
            final installCmd = _getInstallCommand(manager, 'seclists');
            onOutput('Running: sudo ${installCmd.join(' ')}');

            final process = await Process.start('sudo', ['-S', ...installCmd]);

            if (password != null) {
              process.stdin.writeln(password);
            }

            process.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
            process.stderr.transform(utf8.decoder).listen((data) => onOutput('ERROR: ${data.trim()}'));

            final exitCode = await process.exitCode;
            onOutput('Command finished with exit code: $exitCode');

            if (exitCode == 0) {
              final installed = await _checkLinuxToolInstalled('raft-large-files.txt');
              onOutput(installed ? 'Installation successful!' : 'Installation verification failed');
              return installed;
            }
          }
        } catch (e) {
          onOutput('Error with $manager: $e');
          continue;
        }
      }

      // Fallback: Download the specific file
      onOutput('Package manager installation failed, downloading file directly...');
      try {
        onOutput('Creating directory /usr/share/seclists/Discovery/Web-Content/...');
        final mkdirProc = await Process.start('sudo', ['-S', 'mkdir', '-p', '/usr/share/seclists/Discovery/Web-Content']);
        if (password != null) mkdirProc.stdin.writeln(password);
        await mkdirProc.exitCode;

        onOutput('Downloading raft-large-files.txt...');
        final downloadUrl = 'https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/raft-large-files.txt';
        final curlProc = await Process.start('sudo', ['-S', 'curl', '-L', downloadUrl, '-o', '/usr/share/seclists/Discovery/Web-Content/raft-large-files.txt']);
        if (password != null) curlProc.stdin.writeln(password);
        curlProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
        await curlProc.exitCode;

        final installed = await _checkLinuxToolInstalled('raft-large-files.txt');
        onOutput(installed ? 'Download successful!' : 'Download verification failed');
        return installed;
      } catch (e) {
        onOutput('Direct download failed: $e');
      }

      onOutput('All installation methods failed');
      return false;
    } catch (e) {
      onOutput('Raft file installation error: $e');
      return false;
    }
  }
  Future<bool> _installRaftFileWSL(Function(String) onOutput) async {
    try {
      onOutput('Installing Raft Large Files wordlist (SecLists) in WSL...');

      // Try installing seclists package
      onOutput('Trying apt install seclists...');
      final aptProc = await Process.start('wsl', ['-u', 'root', '--', 'bash', '-lc', 'apt update && apt install -y seclists'], runInShell: true);

      aptProc.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) => onOutput(line));
      aptProc.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) => onOutput('Error: $line'));

      if (await aptProc.exitCode == 0) {
        final installed = await _checkToolInstalled('raft-large-files.txt');
        onOutput(installed ? 'Installation successful!' : 'Installation verification failed');
        return installed;
      }

      // Fallback: Download the specific file
      onOutput('Apt installation failed, downloading file directly...');
      final downloadProc = await Process.start('wsl', ['-u', 'root', '--', 'bash', '-lc', 'mkdir -p /usr/share/seclists/Discovery/Web-Content && curl -L https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/raft-large-files.txt -o /usr/share/seclists/Discovery/Web-Content/raft-large-files.txt'], runInShell: true);

      downloadProc.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) => onOutput(line));
      downloadProc.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) => onOutput(line));

      if (await downloadProc.exitCode == 0) {
        final installed = await _checkToolInstalled('raft-large-files.txt');
        onOutput(installed ? 'Download successful!' : 'Download verification failed');
        return installed;
      }

      onOutput('All installation methods failed');
      return false;
    } catch (e) {
      onOutput('Raft file WSL installation error: $e');
      return false;
    }
  }
  Future<bool> _installSearchsploitMacOS(Function(String) onOutput, String? password) async {
    try {
      onOutput('Installing SearchSploit (exploitdb) on macOS...');

      final homeDir = Platform.environment['HOME'] ?? '/tmp';
      final pathEnv = 'export PATH="$homeDir/.local/bin:/opt/homebrew/bin:/usr/local/bin:\$PATH"';

      // Check if Homebrew is installed
      final brewCheck = await Process.run('/bin/zsh', ['-c', '$pathEnv && command -v brew']);

      if (brewCheck.exitCode != 0) {
        onOutput('Homebrew not found. Please install Homebrew first.');
        return false;
      }

      // Try installing exploitdb via Homebrew
      onOutput('Installing exploitdb with Homebrew...');
      final brewProc = await Process.start('/bin/zsh', ['-c', '$pathEnv && brew install exploitdb']);
      brewProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
      brewProc.stderr.transform(utf8.decoder).listen((data) => onOutput(data.trim()));

      if (await brewProc.exitCode == 0) {
        // Update searchsploit database
        onOutput('Updating searchsploit database...');
        final updateProc = await Process.start('/bin/zsh', ['-c', '$pathEnv && searchsploit -u']);
        updateProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
        await updateProc.exitCode;

        final installed = await _checkMacOSToolInstalled('searchsploit');
        onOutput(installed ? 'Installation successful!' : 'Installation verification failed');
        return installed;
      }

      // Fallback: Install from GitHub
      onOutput('Homebrew installation failed, trying GitHub...');
      final cloneProc = await Process.start('/bin/zsh', ['-c', 'git clone https://github.com/offensive-security/exploitdb.git /opt/exploitdb']);
      cloneProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
      await cloneProc.exitCode;

      onOutput('Creating symlink...');
      await Process.run('/bin/zsh', ['-c', 'sudo ln -sf /opt/exploitdb/searchsploit /usr/local/bin/searchsploit']);

      final installed = await _checkMacOSToolInstalled('searchsploit');
      onOutput(installed ? 'Installation successful via GitHub!' : 'Installation verification failed');
      return installed;
    } catch (e) {
      onOutput('SearchSploit macOS installation error: $e');
      return false;
    }
  }
  Future<bool> _installEnum4linuxMacOS(Function(String) onOutput, String? password) async {
    try {
      onOutput('Installing Enum4linux-ng and dependencies on macOS...');
      final homeDir = Platform.environment['HOME'] ?? '/tmp';
      final pathEnv = 'export PATH="$homeDir/.local/bin:/opt/homebrew/bin:/usr/local/bin:\$PATH"';

      // Ensure Python dependencies are installed
      await _installImpacketMacOS(onOutput, password);

      // Install required Python modules: PyYAML and ldap3
      onOutput('Installing required Python modules (PyYAML, ldap3)...');
      final pythonDeps = ['pyyaml', 'ldap3', 'impacket'];
      for (final dep in pythonDeps) {
        try {
          final depProc = await Process.start('/bin/zsh', ['-c', '$pathEnv && python3 -m pip install $dep --break-system-packages']);
          depProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
          await depProc.exitCode;
        } catch (e) {
          onOutput('Warning: Could not install $dep via pip: $e');
        }
      }

      // Try Homebrew first
      onOutput('Checking for Homebrew...');
      final brewCheck = await Process.run('/bin/zsh', ['-c', '$pathEnv && command -v brew']);

      if (brewCheck.exitCode == 0) {
        onOutput('Trying to install enum4linux-ng with Homebrew...');
        final brewProc = await Process.start('/bin/zsh', ['-c', '$pathEnv && brew install enum4linux-ng']);
        brewProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
        brewProc.stderr.transform(utf8.decoder).listen((data) => onOutput(data.trim()));

        if (await brewProc.exitCode == 0) {
          if (await _checkMacOSToolInstalled('enum4linux-ng')) {
            onOutput('Installation successful via Homebrew!');
            return true;
          }
        }
      }

      // Fallback: Install from GitHub repository
      onOutput('Trying to install from GitHub repository...');

      // Ensure git is installed
      final gitCheck = await Process.run('/bin/zsh', ['-c', '$pathEnv && command -v git']);
      if (gitCheck.exitCode != 0 && brewCheck.exitCode == 0) {
        onOutput('Installing git via Homebrew...');
        final gitInstall = await Process.start('/bin/zsh', ['-c', '$pathEnv && brew install git']);
        await gitInstall.exitCode;
      }

      onOutput('Cloning enum4linux-ng repository...');
      final tempDir = Directory.systemTemp.createTempSync('enum4linux_install_');
      final cloneProc = await Process.start('/bin/zsh', ['-c', '$pathEnv && git clone https://github.com/cddmp/enum4linux-ng.git ${tempDir.path}']);
      cloneProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
      cloneProc.stderr.transform(utf8.decoder).listen((data) => onOutput(data.trim()));

      if (await cloneProc.exitCode == 0) {
        onOutput('Installing via pip from repository...');
        final installProc = await Process.start('/bin/zsh', ['-c', '$pathEnv && python3 -m pip install ${tempDir.path} --break-system-packages']);
        installProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
        installProc.stderr.transform(utf8.decoder).listen((data) => onOutput(data.trim()));

        if (await installProc.exitCode == 0) {
          try { tempDir.deleteSync(recursive: true); } catch (_) {}

          if (await _checkMacOSToolInstalled('enum4linux-ng')) {
            onOutput('Installation successful via GitHub!');
            return true;
          }
        }
      }

      try { tempDir.deleteSync(recursive: true); } catch (_) {}

      final finalCheck = await _checkMacOSToolInstalled('enum4linux-ng');
      if (finalCheck) {
        onOutput('Installation verification successful!');
      } else {
        onOutput('Installation failed. Please install manually:');
        onOutput('  Homebrew: brew install enum4linux-ng');
        onOutput('  Or: git clone https://github.com/cddmp/enum4linux-ng.git && cd enum4linux-ng && pip3 install .');
      }
      return finalCheck;
    } catch (e) {
      onOutput('Enum4linux-ng installation error: $e');
      return false;
    }
  }
  Future<bool> _installHomebrewMacOS(Function(String) onOutput) async {
    try {
      onOutput('Installing Homebrew package manager for macOS...');

      onOutput('Downloading Homebrew installation script...');
      onOutput('Note: This may take several minutes and require your password...');

      // Download and run the official Homebrew install script
      final installScript = '/bin/bash -c "\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"';

      final process = await Process.start('/bin/zsh', ['-c', installScript]);

      process.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
      process.stderr.transform(utf8.decoder).listen((data) => onOutput(data.trim()));

      final exitCode = await process.exitCode;

      if (exitCode == 0) {
        onOutput('Homebrew installation completed!');
        onOutput('Verifying installation...');

        // Give it a moment to finish
        await Future.delayed(Duration(seconds: 2));

        final installed = await _checkMacOSToolInstalled('brew');
        onOutput(installed ? 'Installation successful!' : 'Installation verification failed - you may need to add Homebrew to your PATH');
        return installed;
      } else {
        onOutput('Homebrew installation failed with exit code: $exitCode');
        onOutput('Please install Homebrew manually from: https://brew.sh');
        return false;
      }
    } catch (e) {
      onOutput('Homebrew installation error: $e');
      onOutput('Please install Homebrew manually from: https://brew.sh');
      return false;
    }
  }
  Future<bool> _installWhatWebMacOS(Function(String) onOutput, String? password) async {
    try {
      onOutput('Installing WhatWeb on macOS...');

      final homeDir = Platform.environment['HOME'] ?? '/tmp';
      final installPath = '$homeDir/.local/opt/whatweb';
      final binPath = '$homeDir/.local/bin';
      
      onOutput('Creating directories...');
      await Process.run('/bin/zsh', ['-c', 'mkdir -p $binPath']);
      
      onOutput('Removing old installation if exists...');
      await Process.run('/bin/zsh', ['-c', 'rm -rf $installPath']);
      
      onOutput('Cloning WhatWeb repository...');
      final cloneProcess = await Process.start('/bin/zsh', ['-c', 'git clone https://github.com/urbanadventurer/WhatWeb.git $installPath']);
      
      cloneProcess.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
      cloneProcess.stderr.transform(utf8.decoder).listen((data) => onOutput('Git: ${data.trim()}'));
      final cloneExit = await cloneProcess.exitCode;
      
      if (cloneExit != 0) {
        onOutput('Git clone failed with exit code: $cloneExit');
        return false;
      }
      
      onOutput('Creating symlink...');
      await Process.run('/bin/zsh', ['-c', 'ln -sf $installPath/whatweb $binPath/whatweb']);
      await Process.run('/bin/zsh', ['-c', 'chmod +x $binPath/whatweb']);
      
      onOutput('Verifying installation...');
      final installed = await _checkMacOSToolInstalled('whatweb');
      onOutput(installed ? 'WhatWeb installed successfully!' : 'Installation verification failed. Add $binPath to PATH.');
      return installed;
    } catch (e) {
      onOutput('WhatWeb installation error: $e');
      return false;
    }
  }
  Future<bool> _installRaftFileMacOS(Function(String) onOutput, String? password) async {
    try {
      onOutput('Installing Raft Large Files wordlist (SecLists) on macOS...');

      final homeDir = Platform.environment['HOME'] ?? '/tmp';
      final pathEnv = 'export PATH="$homeDir/.local/bin:/opt/homebrew/bin:/usr/local/bin:\$PATH"';

      // Check if Homebrew is installed
      final brewCheck = await Process.run('/bin/zsh', ['-c', '$pathEnv && command -v brew']);

      if (brewCheck.exitCode != 0) {
        onOutput('Homebrew not found. Please install Homebrew first.');
        return false;
      }

      // Try installing seclists via Homebrew
      onOutput('Installing seclists with Homebrew...');
      final brewProc = await Process.start('/bin/zsh', ['-c', '$pathEnv && brew install seclists']);
      brewProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
      brewProc.stderr.transform(utf8.decoder).listen((data) => onOutput(data.trim()));

      if (await brewProc.exitCode == 0) {
        final installed = await _checkMacOSToolInstalled('raft-large-files.txt');
        onOutput(installed ? 'Installation successful!' : 'Installation verification failed');
        return installed;
      }

      // Fallback: Download the specific file
      onOutput('Homebrew installation failed, downloading file directly...');
      try {
        onOutput('Creating directory...');
        await Process.run('/bin/zsh', ['-c', 'mkdir -p /opt/homebrew/share/seclists/Discovery/Web-Content']);

        onOutput('Downloading raft-large-files.txt...');
        final downloadUrl = 'https://raw.githubusercontent.com/danielmiessler/SecLists/master/Discovery/Web-Content/raft-large-files.txt';
        final curlProc = await Process.start('/bin/zsh', ['-c', 'curl -L $downloadUrl -o /opt/homebrew/share/seclists/Discovery/Web-Content/raft-large-files.txt']);
        curlProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
        await curlProc.exitCode;

        final installed = await _checkMacOSToolInstalled('raft-large-files.txt');
        onOutput(installed ? 'Download successful!' : 'Download verification failed');
        return installed;
      } catch (e) {
        onOutput('Direct download failed: $e');
      }

      onOutput('All installation methods failed');
      return false;
    } catch (e) {
      onOutput('Raft file macOS installation error: $e');
      return false;
    }
  }
  Future<bool> _installGetoptLongLinux(Function(String) onOutput, String? password) async {
    try {
      onOutput('Installing getoptlong Ruby gem...');

      // Check if Ruby is installed first
      final rubyCheck = await Process.run('bash', ['-c', 'command -v ruby']);
      if (rubyCheck.exitCode != 0) {
        onOutput('Ruby is not installed. Installing Ruby first...');

        // Try to install Ruby based on available package manager
        if ((await Process.run('bash', ['-c', 'command -v apt'])).exitCode == 0) {
          final aptProc = await Process.start('sudo', ['-S', 'apt', 'install', '-y', 'ruby', 'ruby-dev']);
          if (password != null) aptProc.stdin.writeln(password);
          aptProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
          await aptProc.exitCode;
        } else if ((await Process.run('bash', ['-c', 'command -v pacman'])).exitCode == 0) {
          final pacmanProc = await Process.start('sudo', ['-S', 'pacman', '-S', '--noconfirm', 'ruby']);
          if (password != null) pacmanProc.stdin.writeln(password);
          pacmanProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
          await pacmanProc.exitCode;
        } else if ((await Process.run('bash', ['-c', 'command -v yum'])).exitCode == 0) {
          final yumProc = await Process.start('sudo', ['-S', 'yum', 'install', '-y', 'ruby', 'ruby-devel']);
          if (password != null) yumProc.stdin.writeln(password);
          yumProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
          await yumProc.exitCode;
        } else if ((await Process.run('bash', ['-c', 'command -v dnf'])).exitCode == 0) {
          final dnfProc = await Process.start('sudo', ['-S', 'dnf', 'install', '-y', 'ruby', 'ruby-devel']);
          if (password != null) dnfProc.stdin.writeln(password);
          dnfProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
          await dnfProc.exitCode;
        }
      }

      // IMPORTANT: Install system-wide first so sudo commands (whatweb, enum4linux-ng) can access it
      // Use --no-user-install to override Arch's default --user-install config
      onOutput('Installing getoptlong gem system-wide...');
      final gemProc = await Process.start('sudo', ['-S', 'gem', 'install', 'getoptlong', '--no-user-install']);
      if (password != null) gemProc.stdin.writeln(password);
      gemProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
      gemProc.stderr.transform(utf8.decoder).listen((data) => onOutput(data.trim()));

      if (await gemProc.exitCode == 0) {
        // Verify both system and user installations
        final installed = await _checkLinuxToolInstalled('getoptlong');
        if (installed) {
          onOutput('System-wide installation successful!');
          return true;
        }
      }

      // Fallback: Try user install if system install fails
      onOutput('System install failed, trying user install as fallback...');
      final userGemProc = await Process.start('gem', ['install', 'getoptlong', '--user-install']);
      userGemProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
      userGemProc.stderr.transform(utf8.decoder).listen((data) => onOutput(data.trim()));

      if (await userGemProc.exitCode == 0) {
        final installed = await _checkLinuxToolInstalled('getoptlong');
        if (installed) {
          onOutput('User installation successful (note: may not work with sudo commands)!');
          return true;
        }
      }

      onOutput('Gem installation failed');
      return false;
    } catch (e) {
      onOutput('getoptlong installation error: $e');
      return false;
    }
  }

  Future<bool> _installGetoptLongMacOS(Function(String) onOutput, String? password) async {
    try {
      onOutput('Installing getoptlong Ruby gem...');
      final homeDir = Platform.environment['HOME'] ?? '/tmp';
      final pathEnv = 'export PATH="$homeDir/.local/bin:/opt/homebrew/bin:/usr/local/bin:\$PATH"';

      // Check if Ruby is installed
      final rubyCheck = await Process.run('/bin/zsh', ['-c', '$pathEnv && command -v ruby']);
      if (rubyCheck.exitCode != 0) {
        onOutput('Ruby is not installed. Installing Ruby with Homebrew...');
        final brewProc = await Process.start('/bin/zsh', ['-c', '$pathEnv && brew install ruby']);
        brewProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
        brewProc.stderr.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
        await brewProc.exitCode;
      }

      // IMPORTANT: Install system-wide first so sudo commands (whatweb, enum4linux-ng) can access it
      // Use --no-user-install to ensure system-wide installation
      onOutput('Installing getoptlong gem system-wide...');
      final sudoGemProc = await Process.start('/bin/zsh', ['-c', '$pathEnv && sudo gem install getoptlong --no-user-install']);
      sudoGemProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
      sudoGemProc.stderr.transform(utf8.decoder).listen((data) => onOutput(data.trim()));

      if (await sudoGemProc.exitCode == 0) {
        final installed = await _checkMacOSToolInstalled('getoptlong');
        if (installed) {
          onOutput('System-wide installation successful!');
          return true;
        }
      }

      // Fallback: Try user install if system install fails
      onOutput('System install failed, trying user install as fallback...');
      final gemProc = await Process.start('/bin/zsh', ['-c', '$pathEnv && gem install getoptlong --user-install']);
      gemProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
      gemProc.stderr.transform(utf8.decoder).listen((data) => onOutput(data.trim()));

      if (await gemProc.exitCode == 0) {
        onOutput('User installation successful!');
        return true;
      }

      onOutput('Gem installation failed');
      return false;
    } catch (e) {
      onOutput('getoptlong installation error: $e');
      return false;
    }
  }

  Future<bool> _installGetoptLongWSL(Function(String) onOutput) async {
    try {
      onOutput('Installing getoptlong Ruby gem in WSL...');

      // Check if Ruby is installed in WSL
      final rubyCheck = await Process.run('wsl', ['command', '-v', 'ruby'], runInShell: true);
      if (rubyCheck.exitCode != 0) {
        onOutput('Ruby is not installed in WSL. Installing Ruby...');
        final aptProc = await Process.start('wsl', ['-u', 'root', '--', 'bash', '-lc', 'apt update && apt install -y ruby ruby-dev'], runInShell: true);
        aptProc.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) => onOutput(line));
        aptProc.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) => onOutput('Error: $line'));
        await aptProc.exitCode;
      }

      // Install getoptlong gem system-wide (no-user-install)
      onOutput('Installing getoptlong gem system-wide...');
      final gemProc = await Process.start('wsl', ['-u', 'root', '--', 'bash', '-lc', 'gem install getoptlong --no-user-install'], runInShell: true);

      gemProc.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) => onOutput(line));
      gemProc.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) => onOutput(line));

      if (await gemProc.exitCode == 0) {
        final installed = await _checkToolInstalled('getoptlong');
        onOutput(installed ? 'Installation successful!' : 'Installation verification failed');
        return installed;
      }

      onOutput('Gem installation failed');
      return false;
    } catch (e) {
      onOutput('getoptlong installation error: $e');
      return false;
    }
  }

  // --- NEW IMPACKET HELPERS ---

  Future<bool> _installImpacketLinux(Function(String) onOutput, String? password) async {
    try {
      onOutput('Installing impacket library...');
      
      // Try apt first
      if ((await Process.run('bash', ['-c', 'command -v apt'])).exitCode == 0) {
         onOutput('Trying apt install python3-impacket...');
         final aptProc = await Process.start('sudo', ['-S', 'apt', 'install', '-y', 'python3-impacket']);
         if (password != null) aptProc.stdin.writeln(password);
         aptProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
         if (await aptProc.exitCode == 0) {
            if (await _checkLinuxToolInstalled('impacket')) return true;
         }
      }

      onOutput('Trying pip install impacket...');
      final pipProc = await Process.start('sudo', ['-S', 'python3', '-m', 'pip', 'install', 'impacket']);
      if (password != null) pipProc.stdin.writeln(password);
      pipProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
      if (await pipProc.exitCode == 0) {
         if (await _checkLinuxToolInstalled('impacket')) return true;
      }
      
      onOutput('Trying pip install --break-system-packages impacket...');
      final pipBreakProc = await Process.start('sudo', ['-S', 'python3', '-m', 'pip', 'install', 'impacket', '--break-system-packages']);
      if (password != null) pipBreakProc.stdin.writeln(password);
      pipBreakProc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
      
      return await pipBreakProc.exitCode == 0 && await _checkLinuxToolInstalled('impacket');
    } catch (e) {
      onOutput('Impacket installation error: $e');
      return false;
    }
  }

  Future<bool> _installImpacketWSL(Function(String) onOutput) async {
    try {
      onOutput('Installing impacket library in WSL...');
      
      onOutput('Trying apt install python3-impacket...');
      final aptProc = await Process.start('wsl', ['-u', 'root', '--', 'bash', '-lc', 'apt update && apt install -y python3-impacket'], runInShell: true);
      
      aptProc.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) => onOutput(line));
      aptProc.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) => onOutput('Error: $line'));
      
      if (await aptProc.exitCode == 0) {
         if (await _checkToolInstalled('impacket')) return true;
      }
      
      onOutput('Trying pip install impacket...');
      final pipProc = await Process.start('wsl', ['-u', 'root', '--', 'bash', '-lc', 'python3 -m pip install impacket'], runInShell: true);
      
      pipProc.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) => onOutput(line));
      pipProc.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) => onOutput('Error: $line'));
      
      if (await pipProc.exitCode == 0) {
         if (await _checkToolInstalled('impacket')) return true;
      }

      onOutput('Trying pip install --break-system-packages impacket...');
      final pipBreakProc = await Process.start('wsl', ['-u', 'root', '--', 'bash', '-lc', 'python3 -m pip install impacket --break-system-packages'], runInShell: true);
      
      pipBreakProc.stdout.transform(utf8.decoder).transform(const LineSplitter()).listen((line) => onOutput(line));
      pipBreakProc.stderr.transform(utf8.decoder).transform(const LineSplitter()).listen((line) => onOutput('Error: $line'));

      return await pipBreakProc.exitCode == 0 && await _checkToolInstalled('impacket');
    } catch (e) {
      onOutput('Impacket installation error: $e');
      return false;
    }
  }

  Future<bool> _installImpacketMacOS(Function(String) onOutput, String? password) async {
    try {
      onOutput('Installing impacket library on macOS...');
      onOutput('Using Homebrew python pip...');
      
      final proc = await Process.start('/bin/zsh', ['-c', 'export PATH="/opt/homebrew/bin:/usr/local/bin:\$PATH" && python3 -m pip install --break-system-packages impacket']);
      proc.stdout.transform(utf8.decoder).listen((data) => onOutput(data.trim()));
      proc.stderr.transform(utf8.decoder).listen((data) => onOutput('PIP: ${data.trim()}'));
      
      if (await proc.exitCode == 0) {
        return await _checkMacOSToolInstalled('impacket');
      }
      return false;
    } catch (e) {
      onOutput('Impacket installation error: $e');
      return false;
    }
  }
}

class ReadinessStatus {
  final bool isWindows;
  final bool isLinux;
  final bool isMacOS;
  final bool isWeb;
  final bool wslInstalled;
  final String? wslDistribution;
  final bool wslConnection;
  final Map<String, bool> toolStatuses;

  ReadinessStatus({
    required this.isWindows,
    required this.isLinux,
    required this.isMacOS,
    required this.isWeb,
    required this.wslInstalled,
    this.wslDistribution,
    required this.wslConnection,
    required this.toolStatuses,
  });

  bool get isReady {
    if (isWeb) return toolStatuses.values.every((status) => status);
    if (isLinux || isMacOS) return toolStatuses.values.every((status) => status);
    if (isWindows) {
      return toolStatuses.values.every((status) => status);
    }
    return false;
  }

  bool get canInstall {
    if (isWeb) return false;
    return true;
  }
}
