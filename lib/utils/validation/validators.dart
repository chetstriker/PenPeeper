import 'validation_result.dart';

/// Centralized validation utilities
class Validators {
  /// Validate IPv4 address
  /// 
  /// Example:
  /// ```dart
  /// final result = Validators.validateIP('192.168.1.1');
  /// if (!result.isValid) print(result.errorMessage);
  /// ```
  static ValidationResult validateIP(String ip) {
    if (ip.isEmpty) {
      return const ValidationResult.invalid('IP address cannot be empty');
    }

    final parts = ip.split('.');
    if (parts.length != 4) {
      return const ValidationResult.invalid('IP address must have 4 octets');
    }

    for (final part in parts) {
      final num = int.tryParse(part);
      if (num == null || num < 0 || num > 255) {
        return const ValidationResult.invalid('Each octet must be 0-255');
      }
    }

    return const ValidationResult.valid();
  }

  /// Validate CIDR notation (e.g., 192.168.1.0/24)
  /// 
  /// Example:
  /// ```dart
  /// final result = Validators.validateCIDR('192.168.1.0/24');
  /// ```
  static ValidationResult validateCIDR(String cidr) {
    if (cidr.isEmpty) {
      return const ValidationResult.invalid('CIDR cannot be empty');
    }

    final parts = cidr.split('/');
    if (parts.length != 2) {
      return const ValidationResult.invalid('CIDR must be in format: IP/prefix');
    }

    // Validate IP part
    final ipResult = validateIP(parts[0]);
    if (!ipResult.isValid) {
      return ipResult;
    }

    // Validate prefix
    final prefix = int.tryParse(parts[1]);
    if (prefix == null || prefix < 0 || prefix > 32) {
      return const ValidationResult.invalid('Prefix must be 0-32');
    }

    return const ValidationResult.valid();
  }

  /// Validate port number
  /// 
  /// Example:
  /// ```dart
  /// final result = Validators.validatePort('8080');
  /// ```
  static ValidationResult validatePort(String port) {
    if (port.isEmpty) {
      return const ValidationResult.invalid('Port cannot be empty');
    }

    final num = int.tryParse(port);
    if (num == null || num < 1 || num > 65535) {
      return const ValidationResult.invalid('Port must be 1-65535');
    }

    return const ValidationResult.valid();
  }

  /// Validate CVE ID format (e.g., CVE-2019-1010218)
  /// 
  /// Example:
  /// ```dart
  /// final result = Validators.validateCVE('CVE-2019-1010218');
  /// ```
  static ValidationResult validateCVE(String cveId) {
    if (cveId.isEmpty) {
      return const ValidationResult.invalid('CVE ID cannot be empty');
    }

    final pattern = RegExp(r'^CVE-\d{4}-\d{4,}$', caseSensitive: false);
    if (!pattern.hasMatch(cveId)) {
      return const ValidationResult.invalid('CVE ID must be in format: CVE-YYYY-NNNN');
    }

    return const ValidationResult.valid();
  }

  /// Validate project name
  /// 
  /// Example:
  /// ```dart
  /// final result = Validators.validateProjectName('My Project');
  /// ```
  static ValidationResult validateProjectName(String name) {
    if (name.isEmpty) {
      return const ValidationResult.invalid('Project name cannot be empty');
    }

    if (name.length > 100) {
      return const ValidationResult.invalid('Project name too long (max 100 characters)');
    }

    return const ValidationResult.valid();
  }

  /// Validate tag name
  /// 
  /// Example:
  /// ```dart
  /// final result = Validators.validateTag('web-server');
  /// ```
  static ValidationResult validateTag(String tag) {
    if (tag.isEmpty) {
      return const ValidationResult.invalid('Tag cannot be empty');
    }

    if (tag.length > 50) {
      return const ValidationResult.invalid('Tag too long (max 50 characters)');
    }

    // Check for invalid characters
    final pattern = RegExp(r'^[a-zA-Z0-9_\-]+$');
    if (!pattern.hasMatch(tag)) {
      return const ValidationResult.invalid('Tag can only contain letters, numbers, hyphens, and underscores');
    }

    return const ValidationResult.valid();
  }

  /// Validate URL
  /// 
  /// Example:
  /// ```dart
  /// final result = Validators.validateURL('https://example.com');
  /// ```
  static ValidationResult validateURL(String url) {
    if (url.isEmpty) {
      return const ValidationResult.invalid('URL cannot be empty');
    }

    try {
      final uri = Uri.parse(url);
      if (!uri.hasScheme || (uri.scheme != 'http' && uri.scheme != 'https')) {
        return const ValidationResult.invalid('URL must start with http:// or https://');
      }
      return const ValidationResult.valid();
    } catch (e) {
      return const ValidationResult.invalid('Invalid URL format');
    }
  }

  /// Validate hostname
  /// 
  /// Example:
  /// ```dart
  /// final result = Validators.validateHostname('example.com');
  /// ```
  static ValidationResult validateHostname(String hostname) {
    if (hostname.isEmpty) {
      return const ValidationResult.invalid('Hostname cannot be empty');
    }

    if (hostname.length > 253) {
      return const ValidationResult.invalid('Hostname too long (max 253 characters)');
    }

    final pattern = RegExp(r'^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$');
    if (!pattern.hasMatch(hostname)) {
      return const ValidationResult.invalid('Invalid hostname format');
    }

    return const ValidationResult.valid();
  }
}
