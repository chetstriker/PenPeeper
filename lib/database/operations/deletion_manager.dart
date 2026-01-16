import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DeletionManager {
  static Future<void> deleteReportSectionsByProject(Database db, int projectId) async {
    await db.delete('report_sections', where: 'project_id = ?', whereArgs: [projectId]);
  }

  static Future<void> deleteNmapCvesByDevice(Database db, int deviceId) async {
    await db.rawDelete('''
      DELETE FROM nmap_cves WHERE script_id IN (
        SELECT s.id FROM nmap_scripts s 
        JOIN nmap_ports p ON s.port_id = p.id 
        JOIN nmap_hosts h ON p.host_id = h.id 
        WHERE h.device_id = ?
      )
    ''', [deviceId]);
  }

  static Future<void> deleteNmapScriptsByDevice(Database db, int deviceId) async {
    await db.rawDelete('''
      DELETE FROM nmap_scripts WHERE port_id IN (
        SELECT p.id FROM nmap_ports p 
        JOIN nmap_hosts h ON p.host_id = h.id 
        WHERE h.device_id = ?
      )
    ''', [deviceId]);
  }

  static Future<void> deleteNmapPortsByDevice(Database db, int deviceId) async {
    await db.rawDelete('''
      DELETE FROM nmap_ports WHERE host_id IN (
        SELECT id FROM nmap_hosts WHERE device_id = ?
      )
    ''', [deviceId]);
  }

  static Future<void> deleteNmapOsMatchesByDevice(Database db, int deviceId) async {
    await db.rawDelete('''
      DELETE FROM nmap_os_matches WHERE host_id IN (
        SELECT id FROM nmap_hosts WHERE device_id = ?
      )
    ''', [deviceId]);
  }

  static Future<void> deleteNmapHostsByDevice(Database db, int deviceId) async {
    await db.delete('nmap_hosts', where: 'device_id = ?', whereArgs: [deviceId]);
  }

  static Future<void> deleteDeviceData(Database db, int deviceId) async {
    await db.delete('device_data', where: 'device_id = ?', whereArgs: [deviceId]);
  }

  static Future<void> deleteDeviceTags(Database db, int deviceId) async {
    await db.delete('device_tags', where: 'device_id = ?', whereArgs: [deviceId]);
  }

  static Future<void> deleteFlaggedFindingsByDevice(Database db, int deviceId) async {
    await db.delete('flagged_findings', where: 'device_id = ?', whereArgs: [deviceId]);
  }

  static Future<void> deleteFfufFindingsByDevice(Database db, int deviceId) async {
    await db.delete('ffuf_findings', where: 'device_id = ?', whereArgs: [deviceId]);
  }

  static Future<void> deleteSambaLdapFindingsByDevice(Database db, int deviceId) async {
    await db.delete('samba_ldap_findings', where: 'device_id = ?', whereArgs: [deviceId]);
  }

  static Future<void> deleteScansByDevice(Database db, int deviceId) async {
    await db.delete('scans', where: 'device_id = ?', whereArgs: [deviceId]);
  }

  static Future<void> deleteSnmpFindingsByDevice(Database db, int deviceId) async {
    await db.delete('snmp_findings', where: 'device_id = ?', whereArgs: [deviceId]);
  }

  static Future<void> deleteVulnerabilitiesByDevice(Database db, int deviceId) async {
    await db.delete('vulnerabilities', where: 'device_id = ?', whereArgs: [deviceId]);
  }

  static Future<void> deleteVulnerabilityClassificationsByDevice(Database db, int deviceId) async {
    await db.delete('vulnerability_classifications', where: 'device_id = ?', whereArgs: [deviceId]);
  }

  static Future<void> deleteWhatwebFindingsByDevice(Database db, int deviceId) async {
    await db.delete('whatweb_findings', where: 'device_id = ?', whereArgs: [deviceId]);
  }

  static Future<void> deleteDevicesByProject(Database db, int projectId) async {
    await db.delete('devices', where: 'project_id = ?', whereArgs: [projectId]);
  }

  static Future<void> deleteAllDeviceData(Database db, int deviceId) async {
    await deleteNmapCvesByDevice(db, deviceId);
    await deleteNmapScriptsByDevice(db, deviceId);
    await deleteNmapPortsByDevice(db, deviceId);
    await deleteNmapOsMatchesByDevice(db, deviceId);
    await deleteNmapHostsByDevice(db, deviceId);
    await deleteDeviceData(db, deviceId);
    await deleteDeviceTags(db, deviceId);
    await deleteFlaggedFindingsByDevice(db, deviceId);
    await deleteFfufFindingsByDevice(db, deviceId);
    await deleteSambaLdapFindingsByDevice(db, deviceId);
    await deleteScansByDevice(db, deviceId);
    await deleteSnmpFindingsByDevice(db, deviceId);
    await deleteVulnerabilitiesByDevice(db, deviceId);
    await deleteVulnerabilityClassificationsByDevice(db, deviceId);
    await deleteWhatwebFindingsByDevice(db, deviceId);
  }
}
