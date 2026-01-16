import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:penpeeper/services/app_paths_service.dart';
import 'api_router.dart';
import 'websocket_handler.dart';

class TerminalServer {
  static Future<void> run() async {
    debugPrint('Starting PenPeeper in terminal mode...');

    final appPathsService = AppPathsService();

    // Determine the web assets path
    // Platform-specific bundled paths:
    // - Linux: /opt/penpeeper/build/web
    // - Windows: <install-dir>/build/web
    // - macOS: PenPeeper.app/Contents/Resources/build/web
    // - Development: <project>/build/web
    final executableDir = path.dirname(Platform.resolvedExecutable);

    // For macOS app bundles, web assets are in Contents/Resources/
    // Executable is at: .../PenPeeper.app/Contents/MacOS/PenPeeper
    // Resources are at: .../PenPeeper.app/Contents/Resources/
    final macOSResourcesPath = path.join(
      path.dirname(executableDir), // Go up from MacOS to Contents
      'Resources',
      'build',
      'web',
    );

    final bundledWebPath = path.join(executableDir, 'build', 'web');
    final developmentWebPath = path.join(Directory.current.path, 'build', 'web');

    String webPath;
    if (await Directory(macOSResourcesPath).exists()) {
      webPath = macOSResourcesPath;
      debugPrint('Using macOS bundled web assets: $webPath');
    } else if (await Directory(bundledWebPath).exists()) {
      webPath = bundledWebPath;
      debugPrint('Using bundled web assets: $webPath');
    } else if (await Directory(developmentWebPath).exists()) {
      webPath = developmentWebPath;
      debugPrint('Using development web assets: $webPath');
    } else {
      debugPrint('ERROR: Web assets not found!');
      debugPrint('  Checked macOS Resources path: $macOSResourcesPath');
      debugPrint('  Checked bundled path: $bundledWebPath');
      debugPrint('  Checked development path: $developmentWebPath');
      debugPrint('  Please ensure the application was built with web assets included.');
      exit(1);
    }

    debugPrint('Starting server on http://0.0.0.0:8808...');

    final webDirExists = await Directory(webPath).exists();

    shelf.Handler? staticHandler;
    if (webDirExists) {
      staticHandler = createStaticHandler(
        webPath,
        defaultDocument: 'index.html',
        listDirectories: false,
      );
    }

    // Use the proper uploads directory from AppPathsService
    final uploadsPath = appPathsService.uploadsDir;
    final uploadsHandler = createStaticHandler(
      uploadsPath,
      listDirectories: false,
    );
    
    final handler = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addMiddleware(_corsHeaders())
        .addHandler((request) async {
          final requestPath = request.url.path;

          if (requestPath == 'ws/telnet') {
            return webSocketHandler((WebSocketChannel webSocket, String? protocol) {
              WebSocketHandler.handleTelnet(webSocket);
            })(request);
          }

          if (requestPath.startsWith('api/')) {
            return await ApiRouter.handleRequest(request);
          }

          if (requestPath.startsWith('uploads/')) {
            // Strip 'uploads/' prefix and create new request
            final relativePath = requestPath.substring('uploads/'.length);
            final newRequest = shelf.Request(
              request.method,
              request.requestedUri.replace(path: relativePath),
              headers: request.headers,
            );
            return await uploadsHandler(newRequest);
          }

          // Serve risk.png from bundled assets or development directory
          if (requestPath == 'risk.png') {
            // Check macOS Resources location, bundled location, then development location
            final macOSRiskPng = File(path.join(path.dirname(executableDir), 'Resources', 'risk.png'));
            final bundledRiskPng = File(path.join(executableDir, 'risk.png'));
            final devRiskPng = File('${Directory.current.path}/risk.png');

            File? riskFile;
            if (await macOSRiskPng.exists()) {
              riskFile = macOSRiskPng;
            } else if (await bundledRiskPng.exists()) {
              riskFile = bundledRiskPng;
            } else if (await devRiskPng.exists()) {
              riskFile = devRiskPng;
            }

            if (riskFile != null) {
              return shelf.Response.ok(
                riskFile.openRead(),
                headers: {'Content-Type': 'image/png'}
              );
            }
          }

          if (staticHandler != null) {
            return await staticHandler(request);
          }

          return shelf.Response.notFound('Not found');
        });
    
    final server = await shelf_io.serve(handler, InternetAddress.anyIPv4, 8808);
    
    debugPrint('\nPenPeeper web interface available at:');
    debugPrint('  http://localhost:8808');
    debugPrint('  http://<your-ip>:8808');
    debugPrint('\nUploads directory: $uploadsPath');
    debugPrint('Press Ctrl+C to stop\n');
    
    await ProcessSignal.sigint.watch().first;
    await server.close();
    debugPrint('\nServer stopped');
  }

  static shelf.Middleware _corsHeaders() {
    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    };

    return shelf.createMiddleware(
      responseHandler: (shelf.Response response) {
        // Avoid using response.change() as it might have issues.
        return shelf.Response(
          response.statusCode,
          body: response.read(),
          headers: {...response.headers, ...corsHeaders},
          context: response.context,
        );
      },
    );
  }
}
