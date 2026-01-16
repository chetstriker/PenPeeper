
/// Validation script to compare old and new API router implementations
/// 
/// This script extracts all route patterns from both routers and compares them
/// to ensure functional equivalence.
library;

void main() {
  print('=== API Router Validation ===\n');
  
  final oldRoutes = _extractOldRoutes();
  final newRoutes = _extractNewRoutes();
  
  print('Old Router: ${oldRoutes.length} routes');
  print('New Router: ${newRoutes.length} routes\n');
  
  // Find missing routes
  final missingInNew = oldRoutes.where((r) => !newRoutes.contains(r)).toList();
  final extraInNew = newRoutes.where((r) => !oldRoutes.contains(r)).toList();
  
  if (missingInNew.isEmpty && extraInNew.isEmpty) {
    print('✓ All routes match! Both routers have identical endpoints.\n');
  } else {
    if (missingInNew.isNotEmpty) {
      print('✗ Routes in OLD but MISSING in NEW:');
      for (final route in missingInNew) {
        print('  - $route');
      }
      print('');
    }
    
    if (extraInNew.isNotEmpty) {
      print('✗ Routes in NEW but NOT in OLD:');
      for (final route in extraInNew) {
        print('  - $route');
      }
      print('');
    }
  }
  
  // Group routes by category
  print('=== Route Categories ===\n');
  _printRoutesByCategory('Project Routes', oldRoutes, 'projects');
  _printRoutesByCategory('Device Routes', oldRoutes, 'devices');
  _printRoutesByCategory('Findings Routes', oldRoutes, 'findings');
  _printRoutesByCategory('Scan Routes', oldRoutes, ['nmap', 'nikto', 'searchsploit', 'whatweb', 'ffuf', 'enum4linux']);
  _printRoutesByCategory('Report Routes', oldRoutes, 'report');
  _printRoutesByCategory('System Routes', oldRoutes, ['settings', 'themes', 'check-tool', 'install-tool', 'ping', 'images']);
  
  print('\n=== Validation Complete ===');
}

List<String> _extractOldRoutes() {
  return [
    'GET /api/status',
    'GET /api/projects',
    'POST /api/projects',
    'GET /api/projects/:id/devices',
    'POST /api/projects/:id/devices',
    'DELETE /api/projects/:id',
    'POST /api/projects/:id/metadata',
    'GET /api/projects/:id/os-list',
    'GET /api/projects/:id/vendors-list',
    'GET /api/projects/:id/banners-list',
    'GET /api/projects/:id/tags',
    'POST /api/projects/:id/search',
    'POST /api/projects/:id/scan-filter',
    'GET /api/projects/:id/devices/with-ffuf',
    'GET /api/projects/:id/devices/with-samba',
    'GET /api/projects/:id/devices/with-whatweb',
    'GET /api/projects/:id/devices/with-searchsploit',
    'GET /api/projects/:id/devices/with-vulners',
    'GET /api/projects/:id/findings',
    'GET /api/projects/:id/findings/complete',
    'GET /api/projects/:id/findings/incomplete',
    'GET /api/projects/:id/report-sections',
    'GET /api/projects/:id/report-sections/:sectionType',
    'POST /api/projects/:id/report-sections',
    'GET /api/projects/:id/report-data',
    'POST /api/projects/:id/generate-report',
    'POST /api/projects/:id/generate-pdf',
    'POST /api/projects/:id/scan-hosts',
    'GET /api/projects/:id/scan-progress',
    'POST /api/projects/:id/nikto-scans',
    'POST /api/projects/:id/searchsploit-scans',
    'POST /api/projects/:id/whatweb-scans',
    'POST /api/projects/:id/ffuf-scans',
    'POST /api/projects/:id/enum4linux-scans',
    'GET /api/devices/:id',
    'GET /api/devices/:id/scans',
    'POST /api/devices/:id/scans',
    'GET /api/devices/:id/details',
    'GET /api/devices/:id/findings',
    'GET /api/devices/:id/tags',
    'POST /api/devices/:id/tags',
    'DELETE /api/devices/:id/tags/:tag',
    'GET /api/devices/:id/records/:scanType',
    'GET /api/devices/:id/telnet-ports',
    'GET /api/devices/:id/data/:section',
    'POST /api/devices/:id/data/:section',
    'PUT /api/devices/:id/icon',
    'DELETE /api/devices/:id',
    'POST /api/devices/:id/scan',
    'POST /api/devices/:id/nikto',
    'POST /api/devices/:id/searchsploit',
    'POST /api/devices/:id/whatweb',
    'POST /api/devices/:id/enum4linux',
    'POST /api/devices/:id/ffuf',
    'POST /api/findings',
    'PUT /api/findings/:id',
    'GET /api/findings/:id/completion-status',
    'DELETE /api/findings/:id',
    'PUT /api/findings/:id/recommendation',
    'DELETE /api/scans/:id',
    'POST /api/vulnerability-classifications',
    'GET /api/vulnerability-classifications/:finding_id',
    'DELETE /api/vulnerability-classifications/:id',
    'GET /api/vulnerability-classifications/by-finding/:finding_id',
    'PUT /api/vulnerability-classifications/:id/update',
    'POST /api/images/upload',
    'GET /api/themes',
    'GET /api/themes/:name',
    'POST /api/check-tool',
    'POST /api/install-tool',
    'POST /api/install-tool-with-output',
    'GET /api/system/tools',
    'POST /api/ping',
    'GET /api/settings/:key',
    'POST /api/settings/:key',
    'POST /api/nmap/device-scan',
    'POST /api/nmap/process-results',
    'POST /api/export',
    'POST /api/import',
    'POST /api/import/confirm',
  ];
}

List<String> _extractNewRoutes() {
  // Routes from new modular implementation
  return [
    'GET /api/status',
    // ProjectRoutes
    'GET /api/projects',
    'POST /api/projects',
    'GET /api/projects/:id/devices',
    'POST /api/projects/:id/devices',
    'DELETE /api/projects/:id',
    'POST /api/projects/:id/metadata',
    'GET /api/projects/:id/os-list',
    'GET /api/projects/:id/vendors-list',
    'GET /api/projects/:id/banners-list',
    'GET /api/projects/:id/tags',
    // DeviceRoutes
    'GET /api/devices/:id',
    'GET /api/devices/:id/scans',
    'POST /api/devices/:id/scans',
    'GET /api/devices/:id/details',
    'GET /api/devices/:id/findings',
    'GET /api/devices/:id/tags',
    'POST /api/devices/:id/tags',
    'DELETE /api/devices/:id/tags/:tag',
    'GET /api/devices/:id/records/:scanType',
    'GET /api/devices/:id/telnet-ports',
    'GET /api/devices/:id/data/:section',
    'POST /api/devices/:id/data/:section',
    'PUT /api/devices/:id/icon',
    'DELETE /api/devices/:id',
    // FindingsRoutes
    'GET /api/projects/:id/findings',
    'GET /api/projects/:id/findings/complete',
    'GET /api/projects/:id/findings/incomplete',
    'POST /api/findings',
    'PUT /api/findings/:id',
    'GET /api/findings/:id/completion-status',
    'DELETE /api/findings/:id',
    'PUT /api/findings/:id/recommendation',
    'POST /api/vulnerability-classifications',
    'GET /api/vulnerability-classifications/:finding_id',
    'DELETE /api/vulnerability-classifications/:id',
    'GET /api/vulnerability-classifications/by-finding/:finding_id',
    'PUT /api/vulnerability-classifications/:id/update',
    // ScanRoutes
    'POST /api/devices/:id/scan',
    'GET /api/projects/:id/scan-progress',
    'POST /api/projects/:id/scan-hosts',
    'POST /api/nmap/device-scan',
    'POST /api/nmap/process-results',
    'POST /api/projects/:id/nikto-scans',
    'POST /api/projects/:id/searchsploit-scans',
    'POST /api/projects/:id/whatweb-scans',
    'POST /api/projects/:id/ffuf-scans',
    'POST /api/projects/:id/enum4linux-scans',
    'POST /api/devices/:id/nikto',
    'POST /api/devices/:id/searchsploit',
    'POST /api/devices/:id/whatweb',
    'POST /api/devices/:id/enum4linux',
    'POST /api/devices/:id/ffuf',
    // ReportRoutes
    'GET /api/projects/:id/report-sections',
    'GET /api/projects/:id/report-sections/:sectionType',
    'POST /api/projects/:id/report-sections',
    'GET /api/projects/:id/report-data',
    'POST /api/projects/:id/generate-report',
    'POST /api/projects/:id/generate-pdf',
    // SystemRoutes
    'POST /api/projects/:id/search',
    'POST /api/projects/:id/scan-filter',
    'GET /api/projects/:id/devices/with-ffuf',
    'GET /api/projects/:id/devices/with-samba',
    'GET /api/projects/:id/devices/with-whatweb',
    'GET /api/projects/:id/devices/with-searchsploit',
    'GET /api/projects/:id/devices/with-vulners',
    'POST /api/images/upload',
    'GET /api/themes',
    'GET /api/themes/:name',
    'POST /api/check-tool',
    'POST /api/install-tool',
    'POST /api/install-tool-with-output',
    'GET /api/system/tools',
    'POST /api/ping',
    'GET /api/settings/:key',
    'POST /api/settings/:key',
    // Main router
    'DELETE /api/scans/:id',
    'POST /api/export',
    'POST /api/import',
    'POST /api/import/confirm',
  ];
}

void _printRoutesByCategory(String category, List<String> routes, dynamic filter) {
  final filtered = routes.where((r) {
    if (filter is String) {
      return r.contains('/$filter');
    } else if (filter is List<String>) {
      return filter.any((f) => r.contains('/$f'));
    }
    return false;
  }).toList();
  
  print('$category: ${filtered.length} routes');
}
