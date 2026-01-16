import 'package:penpeeper/database_helper.dart';

extension DatabaseHelperExtensions on DatabaseHelper {
  /// Consolidated method to delete auto scans by type
  Future<void> deleteAutoScans(int deviceId, String scanType) async {
    final db = await database;
    await db.delete('scans',
      where: 'device_id = ? AND name = ?',
      whereArgs: [deviceId, scanType],
    );
    
    // Delete associated findings based on scan type
    switch (scanType) {
      case 'AUTO SEARCHSPLOIT':
        await db.delete('vulnerabilities',
          where: 'device_id = ? AND type = ?',
          whereArgs: [deviceId, 'SearchSploit'],
        );
        break;
      case 'AUTO WHATWEB':
        await db.delete('whatweb_findings',
          where: 'device_id = ?',
          whereArgs: [deviceId],
        );
        break;
      case 'AUTO SAMBA/LDAP':
        await db.delete('samba_ldap_findings',
          where: 'device_id = ?',
          whereArgs: [deviceId],
        );
        break;
    }
  }
}
