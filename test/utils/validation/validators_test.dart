import 'package:flutter_test/flutter_test.dart';
import 'package:penpeeper/utils/validation/validators.dart';

void main() {
  group('Validators.validateIP', () {
    test('accepts valid IPv4 addresses', () {
      expect(Validators.validateIP('192.168.1.1').isValid, true);
      expect(Validators.validateIP('0.0.0.0').isValid, true);
      expect(Validators.validateIP('255.255.255.255').isValid, true);
      expect(Validators.validateIP('10.0.0.1').isValid, true);
    });

    test('rejects invalid IPv4 addresses', () {
      expect(Validators.validateIP('256.1.1.1').isValid, false);
      expect(Validators.validateIP('1.1.1').isValid, false);
      expect(Validators.validateIP('1.1.1.1.1').isValid, false);
      expect(Validators.validateIP('abc.def.ghi.jkl').isValid, false);
      expect(Validators.validateIP('').isValid, false);
    });

    test('provides error messages for invalid IPs', () {
      expect(Validators.validateIP('').errorMessage, 'IP address cannot be empty');
      expect(Validators.validateIP('1.1.1').errorMessage, 'IP address must have 4 octets');
      expect(Validators.validateIP('256.1.1.1').errorMessage, 'Each octet must be 0-255');
    });
  });

  group('Validators.validateCIDR', () {
    test('accepts valid CIDR notation', () {
      expect(Validators.validateCIDR('192.168.1.0/24').isValid, true);
      expect(Validators.validateCIDR('10.0.0.0/8').isValid, true);
      expect(Validators.validateCIDR('172.16.0.0/16').isValid, true);
      expect(Validators.validateCIDR('0.0.0.0/0').isValid, true);
      expect(Validators.validateCIDR('255.255.255.255/32').isValid, true);
    });

    test('rejects invalid CIDR notation', () {
      expect(Validators.validateCIDR('192.168.1.0').isValid, false);
      expect(Validators.validateCIDR('192.168.1.0/33').isValid, false);
      expect(Validators.validateCIDR('192.168.1.0/-1').isValid, false);
      expect(Validators.validateCIDR('256.1.1.1/24').isValid, false);
      expect(Validators.validateCIDR('').isValid, false);
    });

    test('provides error messages for invalid CIDR', () {
      expect(Validators.validateCIDR('').errorMessage, 'CIDR cannot be empty');
      expect(Validators.validateCIDR('192.168.1.0').errorMessage, 'CIDR must be in format: IP/prefix');
      expect(Validators.validateCIDR('192.168.1.0/33').errorMessage, 'Prefix must be 0-32');
    });
  });

  group('Validators.validatePort', () {
    test('accepts valid port numbers', () {
      expect(Validators.validatePort('1').isValid, true);
      expect(Validators.validatePort('80').isValid, true);
      expect(Validators.validatePort('443').isValid, true);
      expect(Validators.validatePort('8080').isValid, true);
      expect(Validators.validatePort('65535').isValid, true);
    });

    test('rejects invalid port numbers', () {
      expect(Validators.validatePort('0').isValid, false);
      expect(Validators.validatePort('65536').isValid, false);
      expect(Validators.validatePort('-1').isValid, false);
      expect(Validators.validatePort('abc').isValid, false);
      expect(Validators.validatePort('').isValid, false);
    });
  });

  group('Validators.validateCVE', () {
    test('accepts valid CVE IDs', () {
      expect(Validators.validateCVE('CVE-2019-1010218').isValid, true);
      expect(Validators.validateCVE('CVE-2021-44228').isValid, true);
      expect(Validators.validateCVE('cve-2020-0001').isValid, true);
    });

    test('rejects invalid CVE IDs', () {
      expect(Validators.validateCVE('CVE-19-1234').isValid, false);
      expect(Validators.validateCVE('CVE-2019-123').isValid, false);
      expect(Validators.validateCVE('2019-1234').isValid, false);
      expect(Validators.validateCVE('').isValid, false);
    });
  });

  group('Validators.validateProjectName', () {
    test('accepts valid project names', () {
      expect(Validators.validateProjectName('My Project').isValid, true);
      expect(Validators.validateProjectName('Test123').isValid, true);
      expect(Validators.validateProjectName('a').isValid, true);
    });

    test('rejects invalid project names', () {
      expect(Validators.validateProjectName('').isValid, false);
      expect(Validators.validateProjectName('a' * 101).isValid, false);
    });
  });

  group('Validators.validateTag', () {
    test('accepts valid tags', () {
      expect(Validators.validateTag('web-server').isValid, true);
      expect(Validators.validateTag('database_01').isValid, true);
      expect(Validators.validateTag('TEST123').isValid, true);
    });

    test('rejects invalid tags', () {
      expect(Validators.validateTag('').isValid, false);
      expect(Validators.validateTag('a' * 51).isValid, false);
      expect(Validators.validateTag('tag with spaces').isValid, false);
      expect(Validators.validateTag('tag@special').isValid, false);
    });
  });

  group('Validators.validateURL', () {
    test('accepts valid URLs', () {
      expect(Validators.validateURL('http://example.com').isValid, true);
      expect(Validators.validateURL('https://example.com').isValid, true);
      expect(Validators.validateURL('https://example.com/path').isValid, true);
    });

    test('rejects invalid URLs', () {
      expect(Validators.validateURL('').isValid, false);
      expect(Validators.validateURL('example.com').isValid, false);
      expect(Validators.validateURL('ftp://example.com').isValid, false);
    });
  });

  group('Validators.validateHostname', () {
    test('accepts valid hostnames', () {
      expect(Validators.validateHostname('example.com').isValid, true);
      expect(Validators.validateHostname('sub.example.com').isValid, true);
      expect(Validators.validateHostname('localhost').isValid, true);
    });

    test('rejects invalid hostnames', () {
      expect(Validators.validateHostname('').isValid, false);
      expect(Validators.validateHostname('a' * 254).isValid, false);
      expect(Validators.validateHostname('-invalid.com').isValid, false);
    });
  });
}
