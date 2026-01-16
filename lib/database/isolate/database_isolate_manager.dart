// Conditional export based on platform
// This allows us to use different implementations for web vs native platforms
// Web doesn't support isolates, so we provide a stub implementation
// We check for the absence of dart:io (native) to detect web platform

export 'database_isolate_manager_web.dart'
    if (dart.library.io) 'database_isolate_manager_io.dart';
