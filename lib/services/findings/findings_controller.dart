import 'package:flutter/foundation.dart';
import 'package:penpeeper/repositories/findings_repository.dart';
import 'package:penpeeper/repositories/metadata_repository.dart';
import 'package:penpeeper/services/project_data_cache.dart';

class FindingsController {
  final int projectId;
  final _findingsRepo = FindingsRepository();
  final _metadataRepo = MetadataRepository();
  final _cache = ProjectDataCache();

  FindingsController(this.projectId);

  Future<List<Map<String, dynamic>>> getFlaggedFindings(
    String completionFilter,
  ) async {
    List<Map<String, dynamic>> results;
    switch (completionFilter) {
      case 'complete':
        results = (await _findingsRepo.getCompleteFlaggedFindings(projectId))
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        break;
      case 'incomplete':
        results = (await _findingsRepo.getIncompleteFlaggedFindings(projectId))
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
        break;
      default:
        results = (await _findingsRepo.getFlaggedFindings(projectId))
            .map((f) => f.toMap())
            .toList();
        break;
    }

    // Enrich with OS type if icon_type is missing
    final deviceIdsToEnrich = results
        .where((f) => f['icon_type'] == null || f['icon_type'] == '' || f['icon_type'] == 'unknown')
        .map((f) => f['device_id'] as int)
        .toSet()
        .toList();

    if (deviceIdsToEnrich.isNotEmpty) {
      final metadataMap = await _metadataRepo.getBatchDeviceMetadata(projectId, deviceIdsToEnrich);
      for (final finding in results) {
        if (finding['icon_type'] == null || finding['icon_type'] == '' || finding['icon_type'] == 'unknown') {
           final metadata = metadataMap[finding['device_id']];
           if (metadata != null && metadata['os_type'] != null && metadata['os_type'] != 'unknown') {
             finding['icon_type'] = metadata['os_type'];
           }
        }
      }
    }

    return results;
  }

  Future<List<Map<String, dynamic>>> filterFindingsByTag(
    String tag,
    String completionFilter,
  ) async {
    final allFindings = await getFlaggedFindings(completionFilter);
    final filteredFindings = <Map<String, dynamic>>[];

    for (final finding in allFindings) {
      final deviceTags = await _getDeviceTags(finding['device_id']);
      if (deviceTags.contains(tag)) {
        filteredFindings.add(finding);
      }
    }

    return filteredFindings;
  }

  Future<List<Map<String, dynamic>>> searchFindings(
    String query,
    String searchType,
    String completionFilter,
  ) async {
    if (query.isEmpty) {
      return await getFlaggedFindings(completionFilter);
    }

    final allFindings = await getFlaggedFindings(completionFilter);
    final filteredFindings = <Map<String, dynamic>>[];
    final queryLower = query.toLowerCase();

    for (final finding in allFindings) {
      final matches = searchType == 'IP'
          ? (finding['ip_address'] ?? '').toString().toLowerCase().contains(
                queryLower,
              )
          : (finding['device_name'] ?? '').toString().toLowerCase().contains(
                queryLower,
              );

      if (matches) {
        filteredFindings.add(finding);
      }
    }

    return filteredFindings;
  }

  Set<int> extractFlaggedDeviceIds(List<Map<String, dynamic>> findings) {
    return findings.map((f) => f['device_id'] as int).toSet();
  }

  void updateCache(
    List<Map<String, dynamic>> findings,
    Set<int> deviceIds,
  ) {
    _cache.flaggedFindings = findings;
    _cache.flaggedDeviceIds = deviceIds;
  }

  /// Refreshes the global cache with ALL flagged findings from the database.
  /// This ensures the cache is not affected by local UI filters.
  Future<void> refreshCache() async {
    await _cache.reloadFlaggedFindings(projectId);
  }

  Future<List<String>> _getDeviceTags(int deviceId) async {
    try {
      final db = await _findingsRepo.database;
      final results = await db.query(
        'device_tags',
        where: 'device_id = ?',
        whereArgs: [deviceId],
      );
      return results.map((r) => r['tag'] as String).toList();
    } catch (e) {
      debugPrint('Error getting device tags: $e');
      return [];
    }
  }
}
