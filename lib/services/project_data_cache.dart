import 'package:flutter/foundation.dart';
import '../models.dart';
import '../repositories/device_repository.dart';
import '../repositories/metadata_repository.dart';
import '../repositories/findings_data_repository.dart';
import '../repositories/findings_repository.dart';
import '../repositories/tag_repository.dart';

class ProjectDataCache with ChangeNotifier {
  int? projectId;

  // Device data
  List<Device> devices = [];
  Map<int, Map<String, dynamic>> deviceMetadata = {};
  int deviceCount = 0;
  
  // Search filters
  List<String> operatingSystems = [];
  List<String> macVendors = [];
  List<String> banners = [];
  List<String> tags = [];
  
  // Findings
  List<Map<String, dynamic>> flaggedFindings = [];
  Set<int> flaggedDeviceIds = {};
  
  // CVE Attached
  Map<int, List<Map<String, dynamic>>> cveAttachedByDevice = {};
  
  // Scan type cache
  Map<String, Set<int>> scanTypeDeviceMap = {
    'FFUF': {},
    'Nikto': {},
    'SAMBA': {},
    'SNMP': {},
    'WhatWeb': {},
    'SearchSploit': {},
    'Vulners': {},
  };
  
  // Loading state
  bool isLoaded = false;
  DateTime? lastLoadTime;

  // Singleton pattern
  static final ProjectDataCache _instance = ProjectDataCache._internal();
  factory ProjectDataCache() => _instance;
  ProjectDataCache._internal();

  bool _isDisposed = false;

  // Getters
  bool get hasData => isLoaded && projectId != null;

  /// Schedule notification asynchronously to avoid calling during build/setState
  void _scheduleNotify() {
    if (_isDisposed) return;

    // Use Future.microtask instead of SchedulerBinding.addPostFrameCallback
    // This works better in packaged macOS apps
    Future.microtask(() {
      if (!_isDisposed && hasListeners) {
        try {
          notifyListeners();
        } catch (e) {
          debugPrint('ProjectDataCache: Error notifying listeners: $e');
        }
      }
    });
  }
  
  // Clear cache
  void clear() {
    projectId = null;
    devices = [];
    deviceMetadata = {};
    deviceCount = 0;
    operatingSystems = [];
    macVendors = [];
    banners = [];
    tags = [];
    flaggedFindings = [];
    flaggedDeviceIds = {};
    cveAttachedByDevice = {};
    scanTypeDeviceMap = {
      'FFUF': {},
      'Nikto': {},
      'SAMBA': {},
      'SNMP': {},
      'WhatWeb': {},
      'SearchSploit': {},
      'Vulners': {},
    };
    isLoaded = false;
    lastLoadTime = null;
    _scheduleNotify();
  }
  
  // Reset for new project
  void reset(int newProjectId) {
    clear();
    projectId = newProjectId;
    _scheduleNotify();
  }
  
  // Validate cache
  bool isValidFor(int checkProjectId) {
    return isLoaded && projectId == checkProjectId;
  }
  
  // Mark as loaded
  void markLoaded() {
    isLoaded = true;
    lastLoadTime = DateTime.now();
    _scheduleNotify();
  }
  
  // Incremental update methods
  void updateDeviceAdded(Device device, Map<String, dynamic> metadata) {
    devices = List.from(devices)..add(device);
    deviceCount = devices.length;
    deviceMetadata = Map<int, Map<String, dynamic>>.from(deviceMetadata)
      ..[device.id] = Map<String, dynamic>.from(metadata);

    final osType = metadata['os_type'] as String?;
    if (osType != null && osType.isNotEmpty && !operatingSystems.contains(osType)) {
      operatingSystems = List.from(operatingSystems)..add(osType);
    }

    final vendor = metadata['mac_vendor'] as String?;
    if (vendor != null && vendor.isNotEmpty && !macVendors.contains(vendor)) {
      macVendors = List.from(macVendors)..add(vendor);
    }
    _scheduleNotify();
  }
  
  void updateDeviceDeleted(int deviceId) {
    devices = devices.where((d) => d.id != deviceId).toList();
    deviceCount = devices.length;
    deviceMetadata.remove(deviceId);
    flaggedFindings = flaggedFindings.where((f) => f['device_id'] != deviceId).toList();
    flaggedDeviceIds.remove(deviceId);
    _scheduleNotify();
  }
  
  void updateDeviceMetadata(int deviceId, Map<String, dynamic> metadata) {
    deviceMetadata = Map<int, Map<String, dynamic>>.from(deviceMetadata)
      ..[deviceId] = Map<String, dynamic>.from(metadata);
    _scheduleNotify();
  }
  
  void updateDeviceIcon(int deviceId, String iconType) {
    final deviceIndex = devices.indexWhere((d) => d.id == deviceId);
    if (deviceIndex != -1) {
      final newDevices = List<Device>.from(devices);
      newDevices[deviceIndex] = Device(
        id: devices[deviceIndex].id,
        projectId: devices[deviceIndex].projectId,
        name: devices[deviceIndex].name,
        ipAddress: devices[deviceIndex].ipAddress,
        iconType: iconType,
      );
      devices = newDevices;
    }
    if (deviceMetadata.containsKey(deviceId)) {
      final newMetadata = Map<int, Map<String, dynamic>>.from(deviceMetadata);
      newMetadata[deviceId] = Map<String, dynamic>.from(deviceMetadata[deviceId]!);
      newMetadata[deviceId]!['icon_type'] = iconType;
      deviceMetadata = newMetadata;
    }
    // Update flagged findings icon_type if present
    final newFindings = <Map<String, dynamic>>[];
    for (int i = 0; i < flaggedFindings.length; i++) {
      if (flaggedFindings[i]['device_id'] == deviceId) {
        final updatedFinding = Map<String, dynamic>.from(flaggedFindings[i]);
        updatedFinding['icon_type'] = iconType;
        newFindings.add(updatedFinding);
      } else {
        newFindings.add(flaggedFindings[i]);
      }
    }
    flaggedFindings = newFindings;
    _scheduleNotify();
  }
  
  void updateTagAdded(String tag) {
    if (!tags.contains(tag)) {
      tags = List.from(tags)..add(tag);
      _scheduleNotify();
    }
  }
  
  void updateTagRemoved(String tag, bool isLastUsage) {
    if (isLastUsage) {
      tags = tags.where((t) => t != tag).toList();
      _scheduleNotify();
    }
  }
  
  // Findings cache update methods
  void updateFindingAdded(Map<String, dynamic> finding) {
    flaggedFindings = List.from(flaggedFindings)..add(finding);
    final deviceId = finding['device_id'] as int;
    flaggedDeviceIds.add(deviceId);
    _scheduleNotify();
  }
  
  void updateFindingUpdated(Map<String, dynamic> updatedFinding) {
    final findingId = updatedFinding['id'];
    final index = flaggedFindings.indexWhere((f) => f['id'] == findingId);
    if (index != -1) {
      // Create a new list and replace the item to avoid modifying read-only data
      final newFindings = List<Map<String, dynamic>>.from(flaggedFindings);
      newFindings[index] = Map<String, dynamic>.from(updatedFinding);
      flaggedFindings = newFindings;
      _scheduleNotify();
    }
  }
  
  void updateFindingDeleted(int findingId, int deviceId) {
    flaggedFindings = flaggedFindings.where((f) => f['id'] != findingId).toList();
    // Check if device still has other findings
    final hasOtherFindings = flaggedFindings.any((f) => f['device_id'] == deviceId);
    if (!hasOtherFindings) {
      flaggedDeviceIds.remove(deviceId);
    }
    _scheduleNotify();
  }
  
  // CVE cache methods
  void updateCveAdded(int deviceId, Map<String, dynamic> cve) {
    final newCveMap = Map<int, List<Map<String, dynamic>>>.from(cveAttachedByDevice);
    if (!newCveMap.containsKey(deviceId)) {
      newCveMap[deviceId] = [];
    }
    newCveMap[deviceId] = List<Map<String, dynamic>>.from(newCveMap[deviceId]!)
      ..add(Map<String, dynamic>.from(cve));
    cveAttachedByDevice = newCveMap;
    _scheduleNotify();
  }
  
  void updateCveDeleted(int deviceId, int cveId) {
    if (cveAttachedByDevice.containsKey(deviceId)) {
      cveAttachedByDevice[deviceId]!.removeWhere((c) => c['id'] == cveId);
      if (cveAttachedByDevice[deviceId]!.isEmpty) {
        cveAttachedByDevice.remove(deviceId);
      }
      _scheduleNotify();
    }
  }
  
  // Scan type cache methods
  void addDeviceToScanType(String scanType, int deviceId) {
    if (scanTypeDeviceMap.containsKey(scanType)) {
      scanTypeDeviceMap[scanType]!.add(deviceId);
      _scheduleNotify();
    }
  }
  
  void removeDeviceFromScanType(String scanType, int deviceId) {
    if (scanTypeDeviceMap.containsKey(scanType)) {
      scanTypeDeviceMap[scanType]!.remove(deviceId);
      _scheduleNotify();
    }
  }
  
  Set<int> getDevicesForScanType(String scanType) {
    return scanTypeDeviceMap[scanType] ?? {};
  }
  
  bool deviceHasScanType(String scanType, int deviceId) {
    return scanTypeDeviceMap[scanType]?.contains(deviceId) ?? false;
  }
  
  bool validateScanTypeCache() {
    final validDeviceIds = devices.map((d) => d.id).toSet();
    for (final entry in scanTypeDeviceMap.entries) {
      for (final deviceId in entry.value) {
        if (!validDeviceIds.contains(deviceId)) {
          return false;
        }
      }
    }
    return true;
  }
  
  // Reload devices from database (used after adding new devices)
  Future<void> reloadDevices(int projectId) async {
    final deviceRepo = DeviceRepository();
    final metadataRepo = MetadataRepository();

    devices = await deviceRepo.getDevices(projectId);
    deviceCount = devices.length;

    // Reload metadata for new devices
    final deviceIds = devices.map((d) => d.id).toList();
    deviceMetadata = await metadataRepo.getBatchDeviceMetadata(projectId, deviceIds);

    // Reload filters that might have changed
    operatingSystems = await metadataRepo.getDistinctOperatingSystems(projectId);
    macVendors = await metadataRepo.getDistinctMacVendors(projectId);
    banners = await metadataRepo.getDistinctBanners(projectId);
    _scheduleNotify();
  }
  
  // Reload scan type mappings from database (used after scans complete)
  Future<void> reloadScanTypeMappings(int projectId) async {
    final findingsRepo = FindingsDataRepository();

    scanTypeDeviceMap['FFUF'] = await findingsRepo.getDevicesWithFfufFindings(projectId);
    scanTypeDeviceMap['Nikto'] = await findingsRepo.getDevicesWithNiktoFindings(projectId);
    scanTypeDeviceMap['SAMBA'] = await findingsRepo.getDevicesWithSambaLdapFindings(projectId);
    scanTypeDeviceMap['SNMP'] = await findingsRepo.getDevicesWithSnmpFindings(projectId);
    scanTypeDeviceMap['WhatWeb'] = await findingsRepo.getDevicesWithWhatWebFindings(projectId);
    scanTypeDeviceMap['SearchSploit'] = await findingsRepo.getDevicesWithSearchSploitFindings(projectId);
    scanTypeDeviceMap['Vulners'] = await findingsRepo.getDevicesWithVulnersCves(projectId);
    scanTypeDeviceMap['Nmap Scripts'] = await findingsRepo.getDevicesWithNmapScripts(projectId);
    _scheduleNotify();
  }

  // Reload flagged findings from database
  Future<void> reloadFlaggedFindings(int projectId) async {
    final findingsRepo = FindingsRepository();
    final findings = await findingsRepo.getFlaggedFindings(projectId);
    flaggedFindings = findings.map((f) => f.toMap()).toList();
    flaggedDeviceIds = flaggedFindings
        .map((f) => f['device_id'] as int)
        .toSet();
    _scheduleNotify();
  }

  Future<void> reloadTags(int projectId) async {
    final tagRepo = TagRepository();
    tags = await tagRepo.getAllProjectTags(projectId);
    _scheduleNotify();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
