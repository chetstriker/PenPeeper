import 'package:penpeeper/services/export/csv_export_service.dart';
import 'package:penpeeper/services/export/rtf_export_service.dart';
import 'package:penpeeper/utils/findings_helpers.dart';

class FindingsExportCoordinator {
  final _csvService = CsvExportService();
  final _rtfService = RtfExportService();

  Future<String?> exportVendorList(List<String> vendors) async {
    return await _csvService.exportVendorList(vendors);
  }

  Future<String?> exportBannerList(List<String> banners) async {
    return await _csvService.exportBannerList(banners);
  }

  Future<String?> exportOSList(List<String> osList) async {
    return await _csvService.exportOSList(osList);
  }

  Future<String?> exportSearchResults(
    List<Map<String, dynamic>> results,
    String activeFilter,
  ) async {
    return await _csvService.exportSearchResults(results, activeFilter);
  }

  Future<String?> exportFilterResults({
    required List<Map<String, dynamic>> devices,
    required String filter,
    required Future<List<Map<String, dynamic>>> Function(int, String)
        getRecords,
  }) async {
    return await _csvService.exportFilterResults(
      devices: devices,
      filter: filter,
      getRecords: getRecords,
    );
  }

  Future<String?> exportFlaggedFindingsToCSV(
    List<Map<String, dynamic>> findings,
  ) async {
    return await _csvService.exportFlaggedFindings(
      findings: findings,
      getMacAddress: FindingsHelpers.getMacAddress,
      getDeviceTags: FindingsHelpers.getDeviceTags,
    );
  }

  Future<String?> exportFlaggedFindingsToRTF(
    List<Map<String, dynamic>> findings,
  ) async {
    return await _rtfService.exportFlaggedFindings(
      findings: findings,
      getMacAddress: FindingsHelpers.getMacAddress,
      getDeviceTags: FindingsHelpers.getDeviceTags,
    );
  }
}
