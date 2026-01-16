import 'package:penpeeper/repositories/search_repository.dart';
import 'package:penpeeper/repositories/tag_repository.dart';
import 'package:penpeeper/repositories/device_repository.dart';

/// Service for searching devices and findings
class FindingsSearchService {
  final _searchRepo = SearchRepository();
  final _tagRepo = TagRepository();
  final _deviceRepo = DeviceRepository();

  /// Searches devices by operating system
  Future<List<Map<String, dynamic>>> searchByOS(int projectId, String osName) async {
    final results = await _searchRepo.getDevicesByOperatingSystem(projectId, osName);
    return _enrichResults(results);
  }

  /// Searches devices by MAC vendor
  Future<List<Map<String, dynamic>>> searchByVendor(int projectId, String vendor) async {
    final results = await _searchRepo.getDevicesByMacVendor(projectId, vendor);
    return _enrichResults(results);
  }

  /// Searches devices by banner
  Future<List<Map<String, dynamic>>> searchByBanner(int projectId, String banner) async {
    final results = await _searchRepo.getDevicesByBanner(projectId, banner);
    return _enrichResults(results);
  }

  /// Searches devices by tag
  Future<List<Map<String, dynamic>>> searchByTag(int projectId, String tag) async {
    final results = await _tagRepo.searchDevicesByTag(projectId, tag);
    return _enrichResults(results);
  }

  /// Performs a general search based on type
  Future<List<Map<String, dynamic>>> search(int projectId, String searchType, String query) async {
    List<Map<String, dynamic>> results;
    
    switch (searchType) {
      case 'HOST':
        results = await _searchRepo.searchDevicesByName(projectId, query);
        break;
      case 'IP':
        results = await _searchRepo.searchDevicesByIP(projectId, query);
        break;
      case 'PORT':
        results = await _searchRepo.searchDevicesByPort(projectId, query);
        break;
      case 'SERVICE':
        results = await _searchRepo.searchDevicesByService(projectId, query);
        break;
      default:
        results = [];
    }
    
    return _enrichResults(results);
  }

  /// Enriches results with icon type metadata
  Future<List<Map<String, dynamic>>> _enrichResults(List<Map<String, dynamic>> results) async {
    final enrichedResults = <Map<String, dynamic>>[];
    for (final result in results) {
      final enriched = Map<String, dynamic>.from(result);
      if (enriched['icon_type'] == null) {
        final metadata = await _deviceRepo.getDeviceMetadata(enriched['id']);
        enriched['icon_type'] = metadata['os_type'];
      }
      enrichedResults.add(enriched);
    }
    return enrichedResults;
  }
}
