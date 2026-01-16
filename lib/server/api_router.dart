import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart';
import 'package:http/http.dart' as http;
import 'package:penpeeper/database_helper.dart';
import 'package:penpeeper/server/routes/project_routes.dart';
import 'package:penpeeper/server/routes/device_routes.dart';
import 'package:penpeeper/server/routes/findings_routes.dart';
import 'package:penpeeper/server/routes/scan_routes.dart';
import 'package:penpeeper/server/routes/report_routes.dart';
import 'package:penpeeper/server/routes/system_routes.dart';
import 'package:penpeeper/server/handlers/export_handler.dart';
import 'package:penpeeper/server/handlers/import_handler.dart';
import 'package:penpeeper/repositories/scan_repository.dart';
import 'package:penpeeper/repositories/findings_repository.dart';
import 'package:penpeeper/repositories/vulnerability_repository.dart';
import 'package:penpeeper/services/app_paths_service.dart';

/// Global scan progress tracking for terminal mode
final Map<int, Map<String, dynamic>> scanProgress = {};

class ApiRouter {
  static Future<shelf.Response> handleRequest(shelf.Request request) async {
    if (request.method == 'OPTIONS') {
      return shelf.Response.ok('');
    }

    final path = request.url.path;

    if (path.startsWith('api/')) {
      return await _handleApi(request);
    }

    return shelf.Response.notFound('Not found');
  }

  static Future<shelf.Response> _handleApi(shelf.Request request) async {
    final path = request.url.path.substring(4); // Remove 'api/'
    final parts = path.split('/');

    try {
      // GET /api/status
      if (path == 'status' && request.method == 'GET') {
        return _jsonResponse({'status': 'running', 'version': '1.0.0'});
      }

      // Handle CVE lookup
      if (path == 'cve/lookup' && request.method == 'POST') {
        return await _handleCveLookup(request);
      }

      // Serve uploaded images
      if (path.startsWith('uploads/') && request.method == 'GET') {
        return await _serveUploadedImage(request, path);
      }

      // Serve theme assets (SVG files)
      if (path.startsWith('Themes/') && request.method == 'GET') {
        return await _serveThemeAsset(request, path);
      }

      // Handle image upload early (doesn't need database)
      if (path == 'images/upload' && request.method == 'POST') {
        return await _handleImageUpload(request);
      }

      // Handle export/import early (they manage their own database access)
      if (path == 'export' && request.method == 'POST') {
        final exportHandler = ExportHandler();
        return await exportHandler.handleExport(request);
      }

      if (path == 'import' && request.method == 'POST') {
        final importHandler = ImportHandler();
        return await importHandler.handleImport(request);
      }

      if (path == 'import/confirm' && request.method == 'POST') {
        final importHandler = ImportHandler();
        return await importHandler.handleImportConfirm(request);
      }

      // Handle project findings routes early
      if (parts.length == 4 && parts[0] == 'projects' && parts[2] == 'findings') {
        final projectId = int.tryParse(parts[1]);
        if (projectId != null && request.method == 'GET') {
          final findingsRepository = FindingsRepository();
          if (parts[3] == 'complete') {
            final findings = await findingsRepository.getCompleteFlaggedFindings(projectId);
            return _jsonResponse(findings);
          } else if (parts[3] == 'incomplete') {
            final findings = await findingsRepository.getIncompleteFlaggedFindings(projectId);
            return _jsonResponse(findings);
          }
        }
      }

      // Handle findings completion-status early
      if (parts.length == 3 && parts[0] == 'findings' && parts[2] == 'completion-status' && request.method == 'GET') {
        final findingId = int.tryParse(parts[1]);
        if (findingId != null) {
          final findingsRepository = FindingsRepository();
          final status = await findingsRepository.getFindingCompletionStatus(findingId);
          return _jsonResponse(status);
        }
      }

      // Handle vulnerability classification lookup early (both patterns)
      if (parts[0] == 'vulnerability-classifications' && request.method == 'GET') {
        int? findingId;
        // Pattern 1: /vulnerability-classifications/by-finding/:id
        if (parts.length == 3 && parts[1] == 'by-finding') {
          findingId = int.tryParse(parts[2]);
        }
        // Pattern 2: /vulnerability-classifications/:id (direct finding ID)
        else if (parts.length == 2) {
          findingId = int.tryParse(parts[1]);
        }
        
        if (findingId != null) {
          final vulnRepository = VulnerabilityRepository();
          final classification = await vulnRepository.getVulnerabilityClassificationByFindingIdRaw(findingId);
          if (classification != null) {
            return _jsonResponse(classification);
          }
          return shelf.Response.ok(json.encode(null), headers: {'Content-Type': 'application/json'});
        }
      }

      final db = DatabaseHelper();

      // Try route modules in order
      shelf.Response? response;

      switch (parts[0]) {
        case 'set-session-password':
          response = await ScanRoutes.handle(request, parts, db);
          break;
        case 'projects':
          response = await ProjectRoutes.handle(request, parts.sublist(1));
          response ??= await ScanRoutes.handle(request, parts, db);
          response ??= await ReportRoutes.handle(request, parts, db);
          response ??= await SystemRoutes.handle(request, parts, db);
          break;
        case 'devices':
          response = await DeviceRoutes.handle(request, parts.sublist(1));
          response ??= await ScanRoutes.handle(request, parts, db);
          break;
        case 'findings':
        case 'vulnerability-classifications':
          response = await FindingsRoutes.handle(request, parts);
          break;
        case 'nmap':
          response = await ScanRoutes.handle(request, parts, db);
          break;
        case 'scans':
          if (parts.length == 2 && request.method == 'DELETE') {
            final scanId = int.parse(parts[1]);
            final scanRepository = ScanRepository();
            await scanRepository.deleteScan(scanId);
            return _jsonResponse({'success': true});
          }
          break;
        case 'debug':
          return await _handleDebug(request, parts.sublist(1));
        default:
          response = await SystemRoutes.handle(request, parts, db);
          break;
      }

      if (response != null) {
        return response;
      }

      return shelf.Response.notFound(
        json.encode({'error': 'Endpoint not found: $path'}),
      );
    } catch (e) {
      debugPrint('API Error: $e');
      return shelf.Response.internalServerError(
        body: json.encode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  static Future<shelf.Response> _handleDebug(shelf.Request request, List<String> parts) async {
    if (parts.isEmpty) return shelf.Response.notFound('Not found');

    // Get debug log path from AppPathsService
    final logPath = AppPathsService().debugLogPath;
    final logFile = File(logPath);

    if (parts[0] == 'init' && request.method == 'POST') {
      try {
        await logFile.writeAsString(''); // Create or truncate
        debugPrint('[API] Debug logging initialized at $logPath');
        return _jsonResponse({'status': 'initialized', 'path': logPath});
      } catch (e) {
        return shelf.Response.internalServerError(body: json.encode({'error': 'Failed to init log: $e'}));
      }
    }

    if (parts[0] == 'log' && request.method == 'POST') {
      try {
        final content = await request.readAsString();
        final Map<String, dynamic> body = json.decode(content);
        final message = body['message'];
        
        if (message != null) {
           // Append to file
           await logFile.writeAsString('$message\n', mode: FileMode.append);
           return _jsonResponse({'status': 'logged'});
        } else {
           return shelf.Response.badRequest(body: json.encode({'error': 'Message required'}));
        }
      } catch (e) {
         // Silently fail or return error?
         return shelf.Response.internalServerError(body: json.encode({'error': 'Failed to write log: $e'}));
      }
    }

    return shelf.Response.notFound('Debug endpoint not found');
  }

  static shelf.Response _jsonResponse(dynamic data) {
    return shelf.Response.ok(
      json.encode(data),
      headers: {'Content-Type': 'application/json'},
    );
  }

  static Future<shelf.Response> _serveUploadedImage(shelf.Request request, String requestPath) async {
    try {
      // Convert the relative path to absolute using app data directory
      final filePath = path.join(AppPathsService().appDataDir, requestPath.replaceAll('/', Platform.pathSeparator));
      final file = File(filePath);
      
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final mimeType = lookupMimeType(filePath) ?? 'application/octet-stream';
        
        return shelf.Response.ok(
          bytes,
          headers: {
            'Content-Type': mimeType,
            'Cache-Control': 'public, max-age=3600',
          },
        );
      } else {
        return shelf.Response.notFound('Image not found');
      }
    } catch (e) {
      return shelf.Response.internalServerError(
        body: 'Error serving image: $e',
      );
    }
  }

  static Future<shelf.Response> _serveThemeAsset(shelf.Request request, String path) async {
    try {
      final filePath = Directory.current.path + Platform.pathSeparator + path.replaceAll('/', Platform.pathSeparator);
      final file = File(filePath);
      
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final mimeType = lookupMimeType(filePath) ?? 'image/svg+xml';
        
        return shelf.Response.ok(
          bytes,
          headers: {
            'Content-Type': mimeType,
            'Cache-Control': 'public, max-age=3600',
          },
        );
      } else {
        return shelf.Response.notFound('Theme asset not found');
      }
    } catch (e) {
      return shelf.Response.internalServerError(
        body: 'Error serving theme asset: $e',
      );
    }
  }

  static Future<shelf.Response> _handleCveLookup(shelf.Request request) async {
    try {
      final body = await request.readAsString();
      final data = json.decode(body);
      final cveId = data['cveId'] as String?;
      
      if (cveId == null || cveId.isEmpty) {
        return shelf.Response.badRequest(
          body: json.encode({'error': 'CVE ID required'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
      
      const apiKey = '581aaf06-657f-4940-ae07-5542c1fe53ee';
      const baseUrl = 'https://services.nvd.nist.gov/rest/json/cves/2.0';
      
      final uri = Uri.parse('$baseUrl?cveId=$cveId');
      final response = await http.get(uri, headers: {'apiKey': apiKey});
      
      if (response.statusCode == 200) {
        return shelf.Response.ok(
          response.body,
          headers: {'Content-Type': 'application/json'},
        );
      } else {
        return shelf.Response(response.statusCode,
          body: json.encode({'error': 'NVD API error: ${response.statusCode}'}),
          headers: {'Content-Type': 'application/json'},
        );
      }
    } catch (e) {
      return shelf.Response.internalServerError(
        body: json.encode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  static Future<shelf.Response> _handleImageUpload(shelf.Request request) async {
    debugPrint('[Image Upload] Starting upload...');
    try {
      final contentType = request.headers['content-type'];
      debugPrint('[Image Upload] Content-Type: $contentType');
      
      if (contentType == null || !contentType.contains('multipart/form-data')) {
        debugPrint('[Image Upload] Invalid content type');
        return shelf.Response.badRequest(
          body: json.encode({'error': 'Content-Type must be multipart/form-data'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final boundary = contentType.split('boundary=').last;
      debugPrint('[Image Upload] Boundary: $boundary');
      
      final transformer = MimeMultipartTransformer(boundary);
      final parts = await transformer.bind(request.read()).toList();
      debugPrint('[Image Upload] Parts count: ${parts.length}');

      String? projectName;
      String? fileName;
      List<int>? fileBytes;

      for (final part in parts) {
        final contentDisposition = part.headers['content-disposition'];
        debugPrint('[Image Upload] Part disposition: $contentDisposition');
        if (contentDisposition == null) continue;

        if (contentDisposition.contains('name="projectName"')) {
          final bytes = await part.expand((x) => x).toList();
          projectName = utf8.decode(bytes);
          debugPrint('[Image Upload] Project name: $projectName');
        } else if (contentDisposition.contains('name="fileName"')) {
          final bytes = await part.expand((x) => x).toList();
          fileName = utf8.decode(bytes);
          debugPrint('[Image Upload] File name: $fileName');
        } else if (contentDisposition.contains('name="file"')) {
          fileBytes = await part.expand((x) => x).toList();
          debugPrint('[Image Upload] File bytes: ${fileBytes.length}');
        }
      }

      if (projectName == null || fileName == null || fileBytes == null) {
        debugPrint('[Image Upload] Missing fields - project: $projectName, file: $fileName, bytes: ${fileBytes?.length}');
        return shelf.Response.badRequest(
          body: json.encode({'error': 'Missing required fields'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final projectImagesDir = Directory(path.join(AppPathsService().uploadsDir, projectName));
      debugPrint('[Image Upload] Target dir: ${projectImagesDir.path}');
      
      if (!await projectImagesDir.exists()) {
        await projectImagesDir.create(recursive: true);
        debugPrint('[Image Upload] Created directory');
      }

      final destinationPath = path.join(projectImagesDir.path, fileName);
      await File(destinationPath).writeAsBytes(fileBytes);
      debugPrint('[Image Upload] File written to: $destinationPath');

      final relativePath = 'uploads/$projectName/$fileName';
      debugPrint('[Image Upload] Success: $relativePath');
      return shelf.Response.ok(relativePath, headers: {'Content-Type': 'text/plain'});
    } catch (e, stackTrace) {
      debugPrint('[Image Upload] ERROR: $e');
      debugPrint('[Image Upload] Stack trace: $stackTrace');
      return shelf.Response.internalServerError(
        body: json.encode({'error': e.toString()}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }
}
