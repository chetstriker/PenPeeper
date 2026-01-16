import 'package:penpeeper/repositories/search_repository.dart';
import 'package:penpeeper/repositories/metadata_repository.dart';
import 'package:penpeeper/repositories/tag_repository.dart';

class DeviceSearchService {
  final _searchRepo = SearchRepository();
  final _metadataRepo = MetadataRepository();
  final _tagRepo = TagRepository();

  Future<List<Map<String, dynamic>>> searchByOS(
    int projectId,
    String osName,
  ) async {
    final results = await _searchRepo.getDevicesByOperatingSystem(
      projectId,
      osName,
    );
    return await _enrichResults(results);
  }

  Future<List<Map<String, dynamic>>> searchByVendor(
    int projectId,
    String vendor,
  ) async {
    final results = await _metadataRepo.getDevicesByMacVendor(
      projectId,
      vendor,
    );
    return await _enrichResults(results);
  }

  Future<List<Map<String, dynamic>>> searchByBanner(
    int projectId,
    String banner,
  ) async {
    final results = await _metadataRepo.getDevicesByBanner(
      projectId,
      banner,
    );
    return await _enrichResults(results);
  }

  Future<List<Map<String, dynamic>>> searchByTag(
    int projectId,
    String tag,
  ) async {
    final results = await _tagRepo.searchDevicesByTag(projectId, tag);
    return await _enrichResults(results);
  }

  Future<List<Map<String, dynamic>>> searchByName(
    int projectId,
    String query,
  ) async {
    final results = await _searchRepo.searchDevicesByName(projectId, query);
    return await _enrichResults(results);
  }

  Future<List<Map<String, dynamic>>> searchByIP(
    int projectId,
    String query,
  ) async {
    final results = await _searchRepo.searchDevicesByIP(projectId, query);
    return await _enrichResults(results);
  }

  Future<List<Map<String, dynamic>>> searchByPort(
    int projectId,
    String query,
  ) async {
    final results = await _searchRepo.searchDevicesByPort(projectId, query);
    return await _enrichResults(results);
  }

  Future<List<Map<String, dynamic>>> searchByService(
    int projectId,
    String query,
  ) async {
    final results = await _searchRepo.searchDevicesByService(projectId, query);
    return await _enrichResults(results);
  }

  Future<List<Map<String, dynamic>>> _enrichResults(
    List<Map<String, dynamic>> results,
  ) async {
    final enrichedResults = <Map<String, dynamic>>[];
    for (final result in results) {
      final enriched = Map<String, dynamic>.from(result);
      if (enriched['icon_type'] == null || 
          enriched['icon_type'] == '' || 
          enriched['icon_type'] == 'unknown') {
        final metadata = await _metadataRepo.getDeviceMetadata(enriched['id']);
        if (metadata['os_type'] != null && metadata['os_type'] != 'unknown') {
          enriched['icon_type'] = metadata['os_type'];
        }
      }
      enrichedResults.add(enriched);
    }
    return enrichedResults;
  }
}
