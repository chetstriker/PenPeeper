import 'package:penpeeper/services/nmap_scan_service.dart';

class ScanService {
  static final _nmapService = NmapScanService();
  
  static Future<String> runNmapScan(String target) async {
    return await _nmapService.runHostDiscoveryScan(target);
  }

  static Future<String> runDeviceScan(String target, [String? uniqueId]) async {
    return await _nmapService.runDeviceScan(target, uniqueId);
  }
}
