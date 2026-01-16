import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:penpeeper/services/app_paths_service.dart';

class ConfigService {
  static bool get isLinux => !kIsWeb && Platform.isLinux;
  static bool get isWindows => !kIsWeb && Platform.isWindows;
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;

  static Future<Map<String, String>> loadConfig() async {
    if (kIsWeb) return {};

    try {
      final configFile = File(AppPathsService().configPath);
      if (await configFile.exists()) {
        final configContent = await configFile.readAsString();
        final config = json.decode(configContent);
        final result = Map<String, String>.from(config['tools']);
        if (config['paths'] != null) {
          result.addAll(Map<String, String>.from(config['paths']));
        }
        return result;
      }
    } catch (e) {
      debugPrint('Failed to load config: $e');
    }
    return _getDefaultConfig();
  }

  static Map<String, String> _getDefaultConfig() {
    if (kIsWeb) return {};

    if (isLinux || isMacOS) {
      return {
        'perl': 'perl',
        'nikto': 'nikto',
        'nmap_scanner': 'nmap',

        'nmap_processor': './nmap_processor',
        'searchsploit_scanner': './searchsploit_scanner',
      };
    }
    return {
      'perl': r'C:\Strawberry\perl\bin\perl.exe',
      'nikto': r'C:\nikto\program\nikto.pl',
      'nmap_scanner': 'nmap_scanner.exe',

      'nmap_processor': 'nmap_processor.exe',
      'searchsploit_scanner': 'searchsploit_scanner.exe',
      'perl5lib': r'C:\Strawberry\perl\site\lib',
      'openssl_dll': r'C:\Strawberry\c\bin',
    };
  }
}
