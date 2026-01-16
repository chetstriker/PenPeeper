import 'dart:async';
import 'package:flutter/foundation.dart';

import '../repositories/device_repository.dart';
import '../repositories/metadata_repository.dart';
import '../repositories/findings_repository.dart';
import '../repositories/findings_data_repository.dart';
import '../repositories/tag_repository.dart';
import 'project_data_cache.dart';

class ProjectDataLoader {
  final DeviceRepository _deviceRepo = DeviceRepository();
  final MetadataRepository _metadataRepo = MetadataRepository();
  final FindingsRepository _findingsRepo = FindingsRepository();
  final FindingsDataRepository _findingsDataRepo = FindingsDataRepository();
  final TagRepository _tagRepo = TagRepository();
  final ProjectDataCache _cache = ProjectDataCache();
  
  Future<void> loadProjectData(int projectId, void Function(double, String) onProgress) async {
    try {
      final startTime = DateTime.now();
      _cache.reset(projectId);
      
      // Step 1: Load devices
      onProgress(0.0, 'Loading devices...');
      var stepStart = DateTime.now();
      _cache.devices = await _deviceRepo.getDevices(projectId);
      _cache.deviceCount = _cache.devices.length;
      debugPrint('Load devices: ${DateTime.now().difference(stepStart).inMilliseconds}ms');
      
      if (_cache.deviceCount == 0) {
        _cache.markLoaded();
        onProgress(1.0, 'Complete');
        return;
      }
      
      final deviceIds = _cache.devices.map((d) => d.id).toList();
      
      // Step 2: Load metadata
      onProgress(0.02, 'Loading metadata...');
      stepStart = DateTime.now();
      await _loadAllDeviceMetadata(projectId, deviceIds, onProgress);
      debugPrint('Load metadata: ${DateTime.now().difference(stepStart).inMilliseconds}ms');
      
      // Step 3: Load scan type mappings sequentially with progress
      stepStart = DateTime.now();
      await _loadScanTypeMappings(projectId, onProgress);
      debugPrint('Load scan mappings: ${DateTime.now().difference(stepStart).inMilliseconds}ms');
      
      // Step 4: Load other data in parallel
      onProgress(0.95, 'Finalizing...');
      stepStart = DateTime.now();
      await Future.wait([
        _loadOperatingSystems(projectId),
        _loadMacVendors(projectId),
        _loadBanners(projectId),
        _loadTags(projectId),
        _loadFlaggedFindings(projectId),
      ]);
      debugPrint('Load other data: ${DateTime.now().difference(stepStart).inMilliseconds}ms');
      
      _cache.markLoaded();
      onProgress(1.0, 'Complete');
      debugPrint('Total load time: ${DateTime.now().difference(startTime).inMilliseconds}ms');
      
    } catch (e) {
      debugPrint('Error loading project data: $e');
      rethrow;
    }
  }
  
  Future<void> _loadOperatingSystems(int projectId) async {
    _cache.operatingSystems = await _metadataRepo.getDistinctOperatingSystems(projectId);
  }
  
  Future<void> _loadMacVendors(int projectId) async {
    _cache.macVendors = await _metadataRepo.getDistinctMacVendors(projectId);
  }
  
  Future<void> _loadBanners(int projectId) async {
    _cache.banners = await _metadataRepo.getDistinctBanners(projectId);
  }
  
  Future<void> _loadTags(int projectId) async {
    _cache.tags = await _tagRepo.getAllProjectTags(projectId);
  }
  
  Future<void> _loadFlaggedFindings(int projectId) async {
    final findings = await _findingsRepo.getFlaggedFindings(projectId);
    _cache.flaggedFindings = findings.map((f) => f.toMap()).toList();
    _cache.flaggedDeviceIds = _cache.flaggedFindings
        .map((f) => f['device_id'] as int)
        .toSet();
  }
  

  
  Future<void> _loadAllDeviceMetadata(int projectId, List<int> deviceIds, void Function(double, String) onProgress) async {
    if (deviceIds.isEmpty) return;
    
    const batchSize = 150;
    const parallelBatches = 1; // Serialized to prevent DB locking
    final batches = <List<int>>[];
    
    for (int i = 0; i < deviceIds.length; i += batchSize) {
      batches.add(deviceIds.skip(i).take(batchSize).toList());
    }

    int completedBatches = 0;
    
    // Process batches in chunks to control concurrency
    for (int i = 0; i < batches.length; i += parallelBatches) {
      final chunk = batches.skip(i).take(parallelBatches);
      await Future.wait(chunk.map((batch) async {
        final metadata = await _metadataRepo.getBatchDeviceMetadata(projectId, batch);
        _cache.deviceMetadata.addAll(metadata);
        completedBatches++;
        
        final progress = 0.02 + (0.03 * completedBatches / batches.length);
        onProgress(progress, 'Loading metadata (${completedBatches * batchSize}/${deviceIds.length})...');
      }));
    }
  }
  
  Future<void> _loadScanTypeMappings(int projectId, void Function(double, String) onProgress) async {
    onProgress(0.05, 'Loading findings...');
    
    int completed = 0;
    final total = 8; // Number of scan types

    void updateProgress(String name) {
      completed++;
      final progress = 0.05 + (0.90 * completed / total);
      onProgress(progress, 'Loading $name findings...');
    }

    _cache.scanTypeDeviceMap['FFUF'] = await _findingsDataRepo.getDevicesWithFfufFindings(projectId);
    updateProgress('FFUF');

    _cache.scanTypeDeviceMap['Nikto'] = await _findingsDataRepo.getDevicesWithNiktoFindings(projectId);
    updateProgress('Nikto');

    _cache.scanTypeDeviceMap['SAMBA'] = await _findingsDataRepo.getDevicesWithSambaLdapFindings(projectId);
    updateProgress('Samba/LDAP');

    _cache.scanTypeDeviceMap['SNMP'] = await _findingsDataRepo.getDevicesWithSnmpFindings(projectId);
    updateProgress('SNMP');

    _cache.scanTypeDeviceMap['WhatWeb'] = await _findingsDataRepo.getDevicesWithWhatWebFindings(projectId);
    updateProgress('WhatWeb');

    _cache.scanTypeDeviceMap['SearchSploit'] = await _findingsDataRepo.getDevicesWithSearchSploitFindings(projectId);
    updateProgress('SearchSploit');

    _cache.scanTypeDeviceMap['Vulners'] = await _findingsDataRepo.getDevicesWithVulnersCves(projectId);
    updateProgress('Vulners');

    _cache.scanTypeDeviceMap['Nmap Scripts'] = await _findingsDataRepo.getDevicesWithNmapScripts(projectId);
    updateProgress('Nmap Scripts');

    debugPrint('Scan type cache loaded: FFUF=${_cache.scanTypeDeviceMap['FFUF']!.length}, Nikto=${_cache.scanTypeDeviceMap['Nikto']!.length}, SAMBA=${_cache.scanTypeDeviceMap['SAMBA']!.length}, SNMP=${_cache.scanTypeDeviceMap['SNMP']!.length}, WhatWeb=${_cache.scanTypeDeviceMap['WhatWeb']!.length}, SearchSploit=${_cache.scanTypeDeviceMap['SearchSploit']!.length}, Vulners=${_cache.scanTypeDeviceMap['Vulners']!.length}, Nmap Scripts=${_cache.scanTypeDeviceMap['Nmap Scripts']!.length}');
  }
}

