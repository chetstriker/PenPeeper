import 'package:penpeeper/repositories/device_repository.dart';
import 'package:penpeeper/repositories/scan_repository.dart';
import 'package:penpeeper/repositories/findings_repository.dart';
import 'package:penpeeper/repositories/vulnerability_repository.dart';
import 'package:penpeeper/repositories/project_repository.dart';
import 'package:penpeeper/repositories/tag_repository.dart';
import 'package:penpeeper/repositories/settings_repository.dart';
import 'package:penpeeper/services/scan_orchestrator.dart';
import 'package:penpeeper/services/nmap_scan_service.dart';
import 'package:penpeeper/services/nikto_scan_service.dart';
import 'package:penpeeper/services/project_data_cache.dart';

/// Simple dependency injection container
class DI {
  static final DI _instance = DI._internal();
  factory DI() => _instance;
  DI._internal();

  final Map<Type, dynamic> _singletons = {};

  T get<T>() {
    if (_singletons.containsKey(T)) {
      return _singletons[T] as T;
    }

    // Register singletons on first access
    final instance = _createInstance<T>();
    _singletons[T] = instance;
    return instance;
  }

  dynamic _createInstance<T>() {
    switch (T) {
      // Repositories
      case DeviceRepository:
        return DeviceRepository();
      case ScanRepository:
        return ScanRepository();
      case FindingsRepository:
        return FindingsRepository();
      case VulnerabilityRepository:
        return VulnerabilityRepository();
      case ProjectRepository:
        return ProjectRepository();
      case TagRepository:
        return TagRepository();
      case SettingsRepository:
        return SettingsRepository();
      
      // Services
      case ScanOrchestrator:
        return ScanOrchestrator();
      case NmapScanService:
        return NmapScanService();
      case NiktoScanService:
        return NiktoScanService();
      case ProjectDataCache:
        return ProjectDataCache();
      
      default:
        throw Exception('Type $T not registered in DI container');
    }
  }

  void reset() {
    _singletons.clear();
  }
}
