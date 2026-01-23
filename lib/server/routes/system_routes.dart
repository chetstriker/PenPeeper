import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart' as shelf;
import 'package:mime/mime.dart';
import 'package:penpeeper/repositories/settings_repository.dart';
import 'package:penpeeper/repositories/search_repository.dart';
import 'package:penpeeper/database_helper.dart';
import 'package:penpeeper/services/app_paths_service.dart';

class SystemRoutes {
  static Future<shelf.Response?> handle(
    shelf.Request request,
    List<String> parts,
    [DatabaseHelper? dbHelper,]
  ) async {
    // GET /api/status
    if (parts.isEmpty && request.method == 'GET') {
      return null; // Let main router handle
    }

    // GET /api/system/tools
    if (parts.length == 2 &&
        parts[0] == 'system' &&
        parts[1] == 'tools' &&
        request.method == 'GET') {
      final tools = await _checkInstalledTools();
      return _jsonResponse(tools);
    }

    // POST /api/check-tool
    if (parts.length == 1 &&
        parts[0] == 'check-tool' &&
        request.method == 'POST') {
      final body = json.decode(await request.readAsString());
      final tool = body['tool'] as String;
      final isInstalled = await _checkToolInstalled(tool);
      return _jsonResponse({'installed': isInstalled});
    }

    // POST /api/install-tool
    if (parts.length == 1 &&
        parts[0] == 'install-tool' &&
        request.method == 'POST') {
      final body = json.decode(await request.readAsString());
      final tool = body['tool'] as String;
      final success = await _installToolOnServer(tool);
      return _jsonResponse({'success': success});
    }

    // POST /api/install-tool-with-output
    if (parts.length == 1 &&
        parts[0] == 'install-tool-with-output' &&
        request.method == 'POST') {
      final body = json.decode(await request.readAsString());
      final tool = body['tool'] as String;
      final password = body['password'] as String?;
      final result = await _installToolOnServerWithOutput(tool, password);
      return _jsonResponse(result);
    }

    // POST /api/validate-password
    if (parts.length == 1 &&
        parts[0] == 'validate-password' &&
        request.method == 'POST') {
      final body = json.decode(await request.readAsString());
      final password = body['password'] as String?;
      if (password == null || password.isEmpty) {
        return _jsonResponse({'valid': false, 'error': 'Password required'});
      }
      final isValid = await _validatePassword(password);
      return _jsonResponse({'valid': isValid});
    }

    // POST /api/ping
    if (parts.length == 1 && parts[0] == 'ping' && request.method == 'POST') {
      final body = json.decode(await request.readAsString());
      final address = body['address'] as String;
      return await _handlePing(address);
    }

    // GET /api/themes
    if (parts.length == 1 && parts[0] == 'themes' && request.method == 'GET') {
      return await _handleGetThemes();
    }

    // GET /api/themes/:name
    if (parts.length == 2 && parts[0] == 'themes' && request.method == 'GET') {
      final themeName = parts[1];
      return await _handleGetTheme(themeName);
    }

    // POST /api/images/upload
    if (parts.length == 2 &&
        parts[0] == 'images' &&
        parts[1] == 'upload' &&
        request.method == 'POST') {
      return await _handleImageUpload(request);
    }

    // GET /api/settings/:key
    if (parts.length == 2 &&
        parts[0] == 'settings' &&
        request.method == 'GET') {
      final key = parts[1];
      final defaultValue = request.url.queryParameters['default'] ?? '';
      
      final db = dbHelper != null ? await dbHelper.database : await DatabaseHelper().database;
      final result = await db.query(
        'settings',
        where: 'key = ?',
        whereArgs: [key],
      );
      
      final value = result.isEmpty ? defaultValue : (result.first['value'] as String? ?? defaultValue);
      return _jsonResponse({'value': value});
    }

    // POST /api/settings/:key
    if (parts.length == 2 &&
        parts[0] == 'settings' &&
        request.method == 'POST') {
      final key = parts[1];
      final body = json.decode(await request.readAsString());
      final value = body['value'] as String;
      
      final db = dbHelper != null ? await dbHelper.database : await DatabaseHelper().database;
      await db.execute(
        'INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)',
        [key, value],
      );
      return _jsonResponse({'success': true});
    }

    // POST /api/settings/init
    if (parts.length == 2 &&
        parts[0] == 'settings' &&
        parts[1] == 'init' &&
        request.method == 'POST') {
      final db = dbHelper != null ? await dbHelper.database : await DatabaseHelper().database;
      await db.execute(
        'INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)',
        ['theme', 'DeepOcean'],
      );
      await db.execute(
        'INSERT OR REPLACE INTO settings (key, value) VALUES (?, ?)',
        ['concurrent_scan_count', '3'],
      );
      return _jsonResponse({'success': true});
    }

    // POST /api/projects/:id/search
    if (parts.length == 3 &&
        parts[0] == 'projects' &&
        parts[2] == 'search' &&
        request.method == 'POST') {
      final projectId = int.parse(parts[1]);
      final body = json.decode(await request.readAsString());
      final type = body['type'] as String;
      final query = body['query'] as String;

      final db = dbHelper != null ? await dbHelper.database : await DatabaseHelper().database;
      List<Map<String, dynamic>> results = [];

      switch (type) {
        case 'HOST':
          results = await db.rawQuery('''
            SELECT DISTINCT d.id, d.name, d.ip_address, d.icon_type
            FROM devices d
            WHERE d.project_id = ? AND d.name LIKE ?
          ''', [projectId, '%$query%']);
          break;
        case 'IP':
          results = await db.rawQuery('''
            SELECT DISTINCT d.id, d.name, d.ip_address, d.icon_type
            FROM devices d
            WHERE d.project_id = ? AND d.ip_address LIKE ?
          ''', [projectId, '%$query%']);
          break;
        case 'PORT':
          results = await db.rawQuery('''
            SELECT DISTINCT d.id, d.name, d.ip_address, d.icon_type
            FROM devices d
            JOIN nmap_hosts h ON d.id = h.device_id
            JOIN nmap_ports p ON h.id = p.host_id
            WHERE d.project_id = ? AND p.port = ?
          ''', [projectId, query]);
          break;
        case 'SERVICE':
          results = await db.rawQuery('''
            SELECT DISTINCT d.id, d.name, d.ip_address, d.icon_type
            FROM devices d
            JOIN nmap_hosts h ON d.id = h.device_id
            JOIN nmap_ports p ON h.id = p.host_id
            WHERE d.project_id = ? AND (p.service_name LIKE ? OR p.product LIKE ?)
          ''', [projectId, '%$query%', '%$query%']);
          break;
        case 'OS':
          results = await db.rawQuery('''
            SELECT DISTINCT d.id, d.name, d.ip_address, d.icon_type
            FROM devices d
            JOIN nmap_hosts h ON d.id = h.device_id
            JOIN nmap_os_matches o ON h.id = o.host_id
            WHERE d.project_id = ?
              AND o.name = ?
              AND o.id IN (
                SELECT id FROM nmap_os_matches o2
                WHERE o2.host_id = o.host_id
                ORDER BY o2.accuracy DESC
                LIMIT 1
              )
          ''', [projectId, query]);
          break;
        case 'VENDOR':
          results = await db.rawQuery('''
            SELECT d.*
            FROM devices d
            JOIN nmap_hosts h ON d.id = h.device_id
            WHERE d.project_id = ? AND h.vendor = ?
            ORDER BY d.name ASC
          ''', [projectId, query]);
          break;
        case 'BANNER':
          results = await db.rawQuery('''
            SELECT DISTINCT d.*
            FROM devices d
            JOIN nmap_hosts h ON d.id = h.device_id
            JOIN nmap_ports p ON h.id = p.host_id
            WHERE d.project_id = ? AND (p.product || ' ' || COALESCE(p.version, '')) = ?
            ORDER BY d.name ASC
          ''', [projectId, query]);
          break;
        case 'TAG':
          results = await db.rawQuery('''
            SELECT DISTINCT d.id, d.name, d.ip_address, d.icon_type
            FROM devices d
            JOIN device_tags t ON d.id = t.device_id
            WHERE d.project_id = ? AND t.tag = ?
            ORDER BY d.name ASC
          ''', [projectId, query]);
          break;
      }
      return _jsonResponse(results);
    }

    // POST /api/projects/:id/scan-filter
    if (parts.length == 3 &&
        parts[0] == 'projects' &&
        parts[2] == 'scan-filter' &&
        request.method == 'POST') {
      final projectId = int.parse(parts[1]);
      final body = json.decode(await request.readAsString());
      final filter = body['filter'] as String;
      
      // Use database directly instead of SearchRepository to avoid read-only issues
      final db = dbHelper != null ? await dbHelper.database : await DatabaseHelper().database;
      List<Map<String, dynamic>> results = [];
      
      switch (filter) {
        case 'FFUF':
          results = await db.rawQuery('''
            SELECT d.id, d.name, d.ip_address, d.icon_type, COUNT(f.id) as count
            FROM devices d
            JOIN ffuf_findings f ON d.id = f.device_id
            WHERE d.project_id = ?
            GROUP BY d.id, d.name, d.ip_address, d.icon_type
            ORDER BY count DESC
          ''', [projectId]);
          break;
        case 'SAMBA':
          results = await db.rawQuery('''
            SELECT d.id, d.name, d.ip_address, d.icon_type, COUNT(s.id) as count
            FROM devices d
            JOIN samba_ldap_findings s ON d.id = s.device_id
            WHERE d.project_id = ?
            GROUP BY d.id, d.name, d.ip_address, d.icon_type
            ORDER BY count DESC
          ''', [projectId]);
          break;
        case 'Nikto':
          results = await db.rawQuery('''
            SELECT d.id, d.name, d.ip_address, d.icon_type, COUNT(n.id) as count
            FROM devices d
            JOIN nikto_findings n ON d.id = n.device_id
            WHERE d.project_id = ?
            GROUP BY d.id, d.name, d.ip_address, d.icon_type
            ORDER BY count DESC
          ''', [projectId]);
          break;
        case 'WhatWeb':
          results = await db.rawQuery('''
            SELECT d.id, d.name, d.ip_address, d.icon_type, COUNT(w.id) as count
            FROM devices d
            JOIN whatweb_findings w ON d.id = w.device_id
            WHERE d.project_id = ?
            GROUP BY d.id, d.name, d.ip_address, d.icon_type
            ORDER BY count DESC
          ''', [projectId]);
          break;
        case 'SearchSploit':
          results = await db.rawQuery('''
            SELECT d.id, d.name, d.ip_address, d.icon_type, COUNT(v.id) as count
            FROM devices d
            JOIN vulnerabilities v ON d.id = v.device_id
            WHERE d.project_id = ? AND v.type = 'SearchSploit'
            GROUP BY d.id, d.name, d.ip_address, d.icon_type
            ORDER BY count DESC
          ''', [projectId]);
          break;
        case 'SNMP':
          results = await db.rawQuery('''
            SELECT d.id, d.name, d.ip_address, d.icon_type, COUNT(s.id) as count
            FROM devices d
            JOIN snmp_findings s ON d.id = s.device_id
            WHERE d.project_id = ?
            GROUP BY d.id, d.name, d.ip_address, d.icon_type
            ORDER BY count DESC
          ''', [projectId]);
          break;
        case 'Vulners':
          final allResults = await db.rawQuery('''
            SELECT d.id, d.name, d.ip_address, d.icon_type, c.id as cve_id, s.output
            FROM devices d
            JOIN nmap_hosts h ON d.id = h.device_id
            JOIN nmap_ports p ON h.id = p.host_id
            JOIN nmap_scripts s ON p.id = s.port_id
            JOIN nmap_cves c ON s.id = c.script_id
            WHERE d.project_id = ?
          ''', [projectId]);
          
          final excludedPrefixes = [
            'cpe:/a:apache:http_server:',
            'cpe:/a:microsoft:iis:',
            'cpe:/a:nginx:nginx:',
            'cpe:/a:php:php:',
            'cpe:/a:genivia:gsoap:',
            'cpe:/a:goahead:goahead:',
            'cpe:/a:boa:boa:',
            'cpe:/a:microsoft:sql_server:',
            'cpe:/a:mysql:mysql:',
            'cpe:/a:mariadb:mariadb:',
            'cpe:/a:postgresql:postgresql',
            'cpe:/a:openssl:openssl:',
            'cpe:/a:net-snmp:net-snmp:',
          ];
          
          final deviceCounts = <int, Map<String, dynamic>>{};
          for (final row in allResults) {
            final output = ((row['output'] as String?) ?? '').trim();
            final shouldExclude = excludedPrefixes.any((prefix) => output.startsWith(prefix));
            if (!shouldExclude) {
              final deviceId = row['id'] as int;
              if (!deviceCounts.containsKey(deviceId)) {
                deviceCounts[deviceId] = {
                  'id': row['id'],
                  'name': row['name'],
                  'ip_address': row['ip_address'],
                  'icon_type': row['icon_type'],
                  'count': 0,
                };
              }
              deviceCounts[deviceId]!['count'] = (deviceCounts[deviceId]!['count'] as int) + 1;
            }
          }
          results = deviceCounts.values.where((device) => (device['count'] as int) > 0).toList();
          results.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
          break;
        case 'Nmap Scripts':
          results = await db.rawQuery('''
            SELECT d.id, d.name, d.ip_address, d.icon_type, COUNT(DISTINCT s.id) as count
            FROM devices d
            JOIN nmap_hosts h ON d.id = h.device_id
            JOIN nmap_ports p ON h.id = p.host_id
            JOIN nmap_scripts s ON p.id = s.port_id
            WHERE d.project_id = ?
            GROUP BY d.id, d.name, d.ip_address, d.icon_type
            ORDER BY count DESC
          ''', [projectId]);
          break;
      }
      
      return _jsonResponse(results);
    }

    return null;
  }

  static Future<bool> _checkToolInstalled(String tool) async {
    try {
      final result = await Process.run('/bin/bash', ['-c', 'command -v $tool']);
      return result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> _installToolOnServer(String tool) async {
    final packageName = _getServerPackageName(tool);
    final managers = ['apt', 'yum', 'dnf', 'pacman', 'rpm', 'dpkg', 'zypper'];

    for (final manager in managers) {
      try {
        final checkResult = await Process.run('/bin/bash', ['-c', 'command -v $manager']);
        if (checkResult.exitCode == 0) {
          final installCmd = _getServerInstallCommand(manager, packageName);
          final result = await Process.run('sudo', installCmd);
          if (result.exitCode == 0) {
            return await _checkToolInstalled(tool);
          }
        }
      } catch (e) {
        continue;
      }
    }
    return false;
  }

  static Future<Map<String, dynamic>> _installToolOnServerWithOutput(
    String tool, [
    String? password,
  ]) async {
    final packageName = _getServerPackageName(tool);
    final managers = ['apt', 'yum', 'dnf', 'pacman', 'rpm', 'dpkg', 'zypper'];
    final output = StringBuffer();

    for (final manager in managers) {
      try {
        output.writeln('Checking for $manager...');
        final checkResult = await Process.run(
          '/bin/bash', 
          ['-c', 'command -v $manager'],
        );
        if (checkResult.exitCode == 0) {
          output.writeln('Found $manager, installing $packageName...');
          final installCmd = _getServerInstallCommand(manager, packageName);
          output.writeln('Running: sudo ${installCmd.join(' ')}');

          final process = await Process.start('sudo', ['-S', ...installCmd]);

          if (password != null) {
            process.stdin.writeln(password);
          }

          process.stdout.transform(utf8.decoder).listen((data) {
            output.write(data);
          });

          process.stderr.transform(utf8.decoder).listen((data) {
            output.write('ERROR: $data');
          });

          final exitCode = await process.exitCode;
          output.writeln('Command finished with exit code: $exitCode');

          if (exitCode == 0) {
            output.writeln('Verifying installation...');
            final installed = await _checkToolInstalled(tool);
            output.writeln(
              installed
                  ? 'Installation successful!'
                  : 'Installation verification failed',
            );
            return {'success': installed, 'output': output.toString()};
          } else {
            output.writeln('Installation failed with exit code: $exitCode');
          }
        }
      } catch (e) {
        output.writeln('Error with $manager: $e');
        continue;
      }
    }
    output.writeln('No suitable package manager found');
    return {'success': false, 'output': output.toString()};
  }

  static String _getServerPackageName(String tool) {
    switch (tool) {
      case 'searchsploit':
        return 'exploitdb';
      case 'enum4linux-ng':
        return 'enum4linux-ng';
      default:
        return tool;
    }
  }

  static List<String> _getServerInstallCommand(
    String manager,
    String packageName,
  ) {
    switch (manager) {
      case 'apt':
        return [manager, 'install', '-y', packageName];
      case 'yum':
      case 'dnf':
        return [manager, 'install', '-y', packageName];
      case 'pacman':
        return [manager, '-S', '--noconfirm', packageName];
      case 'zypper':
        return [manager, 'install', '-y', packageName];
      default:
        return [manager, 'install', '-y', packageName];
    }
  }

  static Future<Map<String, bool>> _checkInstalledTools() async {
    final tools = {
      'nmap': false,
      'nikto': false,
      'searchsploit': false,
      'enum4linux-ng': false,
      'ffuf': false,
      'whatweb': false,
      'raft-large-files.txt': false,
      'getoptlong': false,
      'impacket': false,
    };

    for (final tool in tools.keys) {
      try {
        if (tool == 'raft-large-files.txt') {
          final file = File(
            '/usr/share/seclists/Discovery/Web-Content/raft-large-files.txt',
          );
          tools[tool] = await file.exists();
        } else if (tool == 'getoptlong') {
          final result = await Process.run('ruby', ['-e', "require 'getoptlong'"]);
          tools[tool] = result.exitCode == 0;
        } else if (tool == 'impacket') {
          final result = await Process.run('python3', ['-c', "import impacket"]);
          tools[tool] = result.exitCode == 0;
        } else if (tool == 'enum4linux-ng') {
          final result = await Process.run('bash', ['-c', 'enum4linux-ng -h']);
          if (result.exitCode == 0) {
            tools[tool] = true;
          } else {
            final stderr = result.stderr.toString();
            if (stderr.contains('enum4linux-ng: error: the following arguments are required') ||
                stderr.contains('usage: enum4linux-ng')) {
              tools[tool] = true;
            }
          }
        } else {
          final result = await Process.run('which', [tool]);
          tools[tool] = result.exitCode == 0;
        }
      } catch (e) {
        tools[tool] = false;
      }
    }

    return tools;
  }

  static Future<shelf.Response> _handlePing(String address) async {
    try {
      final result = await Process.run('ping', ['-c', '4', address]);
      return _jsonResponse({
        'success': result.exitCode == 0,
        'output': result.stdout.toString(),
        'error': result.exitCode != 0 ? result.stderr.toString() : null,
      });
    } catch (e) {
      return _jsonResponse({
        'success': false,
        'output': '',
        'error': 'Ping failed: $e',
      });
    }
  }

  static Future<shelf.Response> _handleGetThemes() async {
    try {
      final Set<String> allThemes = {};

      // Check user themes directory
      final userThemesDir = Directory(AppPathsService().themesDir);
      if (await userThemesDir.exists()) {
        final files = await userThemesDir.list().toList();
        final themes = files
            .where((f) => f.path.endsWith('.penTheme'))
            .map((f) => f.path.split(Platform.pathSeparator).last.replaceAll('.penTheme', ''));
        allThemes.addAll(themes);
      }

      // Check bundled themes directories
      for (final bundledPath in AppPathsService().getBundledThemesPaths()) {
        final themesDir = Directory(bundledPath);
        if (await themesDir.exists()) {
          final files = await themesDir.list().toList();
          final themes = files
              .where((f) => f.path.endsWith('.penTheme'))
              .map((f) => f.path.split(Platform.pathSeparator).last.replaceAll('.penTheme', ''));
          allThemes.addAll(themes);
        }
      }

      return _jsonResponse(allThemes.toList());
    } catch (e) {
      return _jsonResponse([]);
    }
  }

  static Future<shelf.Response> _handleGetTheme(String themeName) async {
    try {
      // Try user themes directory first
      for (final name in [themeName, themeName.toLowerCase()]) {
        final themeFile = File('${AppPathsService().themesDir}/$name.penTheme');
        if (await themeFile.exists()) {
          final content = await themeFile.readAsString();
          return shelf.Response.ok(
            content,
            headers: {'Content-Type': 'application/json'},
          );
        }
      }

      // Try bundled themes directories
      for (final bundledPath in AppPathsService().getBundledThemesPaths()) {
        for (final name in [themeName, themeName.toLowerCase()]) {
          final themeFile = File('$bundledPath/$name.penTheme');
          if (await themeFile.exists()) {
            final content = await themeFile.readAsString();
            return shelf.Response.ok(
              content,
              headers: {'Content-Type': 'application/json'},
            );
          }
        }

        // Try case-insensitive search in this directory
        final themesDir = Directory(bundledPath);
        if (await themesDir.exists()) {
          final files = await themesDir.list().toList();
          for (final file in files) {
            final fileName = file.path.split(Platform.pathSeparator).last;
            if (fileName.toLowerCase() == '$themeName.pentheme'.toLowerCase()) {
              final content = await File(file.path).readAsString();
              return shelf.Response.ok(
                content,
                headers: {'Content-Type': 'application/json'},
              );
            }
          }
        }
      }

      return shelf.Response.notFound(
        json.encode({'error': 'Theme not found'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return shelf.Response.internalServerError(
        body: json.encode({'error': 'Failed to load theme: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  static Future<shelf.Response> _handleImageUpload(
    shelf.Request request,
  ) async {
    try {
      // Parse multipart form data
      final contentType = request.headers['content-type'];
      if (contentType == null || !contentType.contains('multipart/form-data')) {
        return shelf.Response.badRequest(
          body: json.encode({'error': 'Expected multipart/form-data'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final boundary = contentType.split('boundary=').last;

      String? projectName;
      String? fileName;
      List<int>? fileBytes;

      // Parse multipart data
      final transformer = MimeMultipartTransformer(boundary);
      await for (final part in request.read().transform(transformer)) {
        final contentDisposition = part.headers['content-disposition'] ?? '';

        if (contentDisposition.contains('name="projectName"')) {
          projectName = await part.transform(utf8.decoder).join();
        } else if (contentDisposition.contains('name="fileName"')) {
          fileName = await part.transform(utf8.decoder).join();
        } else if (contentDisposition.contains('name="sourcePath"')) {
          // Skip sourcePath field - we need actual file bytes
          await part.drain();
        } else if (contentDisposition.contains('name="file"')) {
          fileBytes = await part.toList().then((chunks) => chunks.expand((x) => x).toList());
        }
      }

      if (projectName == null || fileName == null) {
        return shelf.Response.badRequest(
          body: json.encode({'error': 'Missing projectName or fileName'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Create uploads directory structure
      await AppPathsService().ensureProjectUploadsDir(projectName);
      final projectImagesDir = AppPathsService().getProjectUploadsDir(projectName);

      // Save the file
      final filePath = '$projectImagesDir/$fileName';
      if (fileBytes != null && fileBytes.isNotEmpty) {
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);
      }

      // Return relative path
      final relativePath = 'uploads/$projectName/$fileName';
      return shelf.Response.ok(
        relativePath,
        headers: {'Content-Type': 'text/plain'},
      );
    } catch (e) {
      return shelf.Response.internalServerError(
        body: json.encode({'error': 'Image upload failed: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  static Future<bool> _validatePassword(String password) async {
    try {
      final process = await Process.start('sudo', ['-S', 'true']);
      process.stdin.writeln(password);
      await process.stdin.flush();
      await process.stdin.close();
      final exitCode = await process.exitCode;
      return exitCode == 0;
    } catch (e) {
      return false;
    }
  }

  static shelf.Response _jsonResponse(dynamic data) {
    return shelf.Response.ok(
      json.encode(data),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
