import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:penpeeper/services/app_paths_service.dart';


/// Manages database connection and initialization
class DatabaseConnection {
  static final DatabaseConnection _instance = DatabaseConnection._internal();
  factory DatabaseConnection() => _instance;
  DatabaseConnection._internal();

  static Database? _database;

  /// Gets the database instance, initializing if necessary
  Future<Database> get database async {
    if (kIsWeb) {
      throw Exception('Database not available on web - use API calls');
    }
    _database ??= await _initDatabase();
    return _database!;
  }

  /// Initializes the database with proper configuration
  Future<Database> _initDatabase() async {
    if (kIsWeb) {
      throw Exception('Database not available on web - use API calls');
    }
    
    debugPrint('Initializing desktop database...');
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    final dbPath = AppPathsService().databasePath;
    final db = await openDatabase(
      dbPath,
      version: 20,
      onCreate: _onCreate,
      onOpen: _onOpen,
    );
    
    debugPrint('Desktop database initialized successfully');
    return db;
  }

  /// Configures database on open
  Future<void> _onOpen(Database db) async {
    await db.execute('PRAGMA journal_mode=WAL');
    await db.execute('PRAGMA busy_timeout=30000');
    debugPrint('WAL mode enabled, busy timeout set to 30s');
  }

  /// Creates database schema for new databases
  Future<void> _onCreate(Database db, int version) async {
    debugPrint('Creating database tables...');
    
    await db.execute('''
      CREATE TABLE projects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE devices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        ip_address TEXT NOT NULL,
        icon_type TEXT,
        mac_address TEXT,
        vendor TEXT,
        FOREIGN KEY (project_id) REFERENCES projects (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE device_data (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id INTEGER NOT NULL,
        section TEXT NOT NULL,
        content TEXT NOT NULL,
        FOREIGN KEY (device_id) REFERENCES devices (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE scans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (device_id) REFERENCES devices (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE vulnerabilities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id INTEGER NOT NULL,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        severity TEXT,
        url TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (device_id) REFERENCES devices (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE whatweb_findings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id INTEGER NOT NULL,
        finding TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (device_id) REFERENCES devices (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE ffuf_findings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id INTEGER NOT NULL,
        url TEXT NOT NULL,
        status INTEGER NOT NULL,
        words INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (device_id) REFERENCES devices (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE samba_ldap_findings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id INTEGER NOT NULL,
        finding_type TEXT NOT NULL,
        finding_value TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (device_id) REFERENCES devices (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE snmp_findings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id INTEGER NOT NULL,
        project_id INTEGER NOT NULL,
        finding_type TEXT NOT NULL,
        finding_value TEXT NOT NULL,
        FOREIGN KEY (device_id) REFERENCES devices (id),
        FOREIGN KEY (project_id) REFERENCES projects (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE flagged_findings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id INTEGER NOT NULL,
        device_name TEXT NOT NULL,
        ip_address TEXT NOT NULL,
        type TEXT NOT NULL,
        comment TEXT NOT NULL,
        created_at TEXT NOT NULL,
        attack_vector TEXT,
        attack_complexity TEXT,
        privileges_required TEXT,
        user_interaction TEXT,
        scope TEXT,
        confidentiality_impact TEXT,
        integrity_impact TEXT,
        availability_impact TEXT,
        cvss_base_score REAL,
        cvss_severity TEXT,
        cve_id TEXT,
        confidence_level TEXT,
        vulnerability_type TEXT,
        url TEXT,
        finding_type TEXT NOT NULL DEFAULT 'MANUAL',
        cvss_version TEXT,
        project_id INTEGER,
        recommendation TEXT,
        evidence TEXT,
        FOREIGN KEY (device_id) REFERENCES devices (id),
        FOREIGN KEY (project_id) REFERENCES projects (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    await db.insert('settings', {'key': 'theme', 'value': 'default'});

    await db.execute('''
      CREATE TABLE device_tags (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id INTEGER NOT NULL,
        tag TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (device_id) REFERENCES devices (id),
        UNIQUE(device_id, tag)
      )
    ''');
    
    await db.execute('''
      CREATE TABLE vulnerability_classifications (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        device_id INTEGER NOT NULL,
        finding_id INTEGER NOT NULL,
        category TEXT NOT NULL,
        subcategory TEXT NOT NULL,
        description TEXT NOT NULL,
        mapped_owasp TEXT NOT NULL,
        mapped_cwe TEXT NOT NULL,
        severity_guideline TEXT NOT NULL,
        scope TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (project_id) REFERENCES projects (id),
        FOREIGN KEY (device_id) REFERENCES devices (id),
        FOREIGN KEY (finding_id) REFERENCES flagged_findings (id)
      )
    ''');

    // Create indexes for performance
    await db.execute('CREATE INDEX IF NOT EXISTS idx_devices_project_id ON devices(project_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_nmap_hosts_device_id ON nmap_hosts(device_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_nmap_ports_host_id ON nmap_ports(host_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_device_tags_device_id ON device_tags(device_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_flagged_findings_device_id ON flagged_findings(device_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_vuln_classifications_finding_id ON vulnerability_classifications(finding_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_ffuf_findings_device_id ON ffuf_findings(device_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_whatweb_findings_device_id ON whatweb_findings(device_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_samba_ldap_findings_device_id ON samba_ldap_findings(device_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_vulnerabilities_device_id ON vulnerabilities(device_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_snmp_findings_device_id ON snmp_findings(device_id)');
  }

  /// Legacy migration code - no longer used since app is in beta
  @Deprecated('No longer needed - app is in beta with single version')
  Future<void> _onUpgradeLegacy(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE scans (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          device_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          content TEXT NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (device_id) REFERENCES devices (id)
        )
      ''');
    }
    if (oldVersion < 3) {
      try {
        await db.execute('ALTER TABLE nmap_hosts ADD COLUMN mac_address TEXT');
      } catch (e) {}
      try {
        await db.execute('ALTER TABLE nmap_hosts ADD COLUMN vendor TEXT');
      } catch (e) {}
    }
    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE vulnerabilities (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          device_id INTEGER NOT NULL,
          type TEXT NOT NULL,
          title TEXT NOT NULL,
          description TEXT,
          severity TEXT,
          url TEXT,
          created_at TEXT NOT NULL,
          FOREIGN KEY (device_id) REFERENCES devices (id)
        )
      ''');
    }
    if (oldVersion < 5) {
      await db.execute('''
        CREATE TABLE whatweb_findings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          device_id INTEGER NOT NULL,
          finding TEXT NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (device_id) REFERENCES devices (id)
        )
      ''');
    }
    if (oldVersion < 6) {
      await db.execute('''
        CREATE TABLE ffuf_findings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          device_id INTEGER NOT NULL,
          url TEXT NOT NULL,
          status INTEGER NOT NULL,
          words INTEGER NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (device_id) REFERENCES devices (id)
        )
      ''');
    }
    if (oldVersion < 7) {
      await db.execute('''
        CREATE TABLE samba_ldap_findings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          device_id INTEGER NOT NULL,
          finding_type TEXT NOT NULL,
          finding_value TEXT NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (device_id) REFERENCES devices (id)
        )
      ''');
    }
    if (oldVersion < 8) {
      await db.execute('''
        CREATE TABLE flagged_findings (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          device_id INTEGER NOT NULL,
          device_name TEXT NOT NULL,
          ip_address TEXT NOT NULL,
          type TEXT NOT NULL,
          comment TEXT NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (device_id) REFERENCES devices (id)
        )
      ''');
    }
    if (oldVersion < 9) {
      try {
        await db.execute('ALTER TABLE devices ADD COLUMN icon_type TEXT');
      } catch (e) {
        debugPrint('Column icon_type might already exist: $e');
      }
    }
    if (oldVersion < 10) {
      await db.execute('''
        CREATE TABLE settings (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
      await db.insert('settings', {'key': 'theme', 'value': 'default'});
    }
    if (oldVersion < 11) {
      await db.execute('''
        CREATE TABLE device_tags (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          device_id INTEGER NOT NULL,
          tag TEXT NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (device_id) REFERENCES devices (id),
          UNIQUE(device_id, tag)
        )
      ''');
    }
    if (oldVersion < 12) {
      try {
        await db.execute('CREATE INDEX IF NOT EXISTS idx_devices_project_id ON devices(project_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_nmap_hosts_device_id ON nmap_hosts(device_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_nmap_ports_host_id ON nmap_ports(host_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_device_tags_device_id ON device_tags(device_id)');
        await db.execute('CREATE INDEX IF NOT EXISTS idx_flagged_findings_device_id ON flagged_findings(device_id)');
      } catch (e) {
        debugPrint('Error creating indexes: $e');
      }
    }
    if (oldVersion < 13) {
      await db.execute('''
        CREATE TABLE vulnerability_classifications (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          project_id INTEGER NOT NULL,
          device_id INTEGER NOT NULL,
          finding_id INTEGER NOT NULL,
          category TEXT NOT NULL,
          subcategory TEXT NOT NULL,
          description TEXT NOT NULL,
          mapped_owasp TEXT NOT NULL,
          mapped_cwe TEXT NOT NULL,
          severity_guideline TEXT NOT NULL,
          scope TEXT NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (project_id) REFERENCES projects (id),
          FOREIGN KEY (device_id) REFERENCES devices (id),
          FOREIGN KEY (finding_id) REFERENCES flagged_findings (id)
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_vuln_classifications_finding_id ON vulnerability_classifications(finding_id)');
    }
    if (oldVersion < 15) {
      try {
        await db.execute('ALTER TABLE flagged_findings ADD COLUMN attack_vector TEXT');
        await db.execute('ALTER TABLE flagged_findings ADD COLUMN attack_complexity TEXT');
        await db.execute('ALTER TABLE flagged_findings ADD COLUMN privileges_required TEXT');
        await db.execute('ALTER TABLE flagged_findings ADD COLUMN user_interaction TEXT');
        await db.execute('ALTER TABLE flagged_findings ADD COLUMN scope TEXT');
        await db.execute('ALTER TABLE flagged_findings ADD COLUMN confidentiality_impact TEXT');
        await db.execute('ALTER TABLE flagged_findings ADD COLUMN integrity_impact TEXT');
        await db.execute('ALTER TABLE flagged_findings ADD COLUMN availability_impact TEXT');
        await db.execute('ALTER TABLE flagged_findings ADD COLUMN cvss_base_score REAL');
        await db.execute('ALTER TABLE flagged_findings ADD COLUMN cvss_severity TEXT');
      } catch (e) {
        debugPrint('Error adding CVSS columns: $e');
      }
    }
    if (oldVersion < 16) {
      try {
        await db.execute('ALTER TABLE flagged_findings ADD COLUMN cve_id TEXT');
        await db.execute('ALTER TABLE flagged_findings ADD COLUMN confidence_level TEXT');
        await db.execute('ALTER TABLE flagged_findings ADD COLUMN vulnerability_type TEXT');
        await db.execute('ALTER TABLE flagged_findings ADD COLUMN url TEXT');
        await db.execute('ALTER TABLE flagged_findings ADD COLUMN finding_type TEXT NOT NULL DEFAULT "MANUAL"');
        await db.execute('ALTER TABLE flagged_findings ADD COLUMN cvss_version TEXT');
        await db.execute('ALTER TABLE flagged_findings ADD COLUMN project_id INTEGER');
        debugPrint('Successfully added CVE merge columns to flagged_findings');
        
        final cveRecords = await db.query('cve_attached');
        debugPrint('Migrating ${cveRecords.length} CVE records to flagged_findings');
        
        for (final cve in cveRecords) {
          final deviceId = cve['device_id'] as int;
          final device = await db.query('devices', where: 'id = ?', whereArgs: [deviceId], limit: 1);
          
          if (device.isNotEmpty) {
            await db.insert('flagged_findings', {
              'device_id': deviceId,
              'device_name': device.first['name'],
              'ip_address': device.first['ip_address'],
              'type': 'CVE',
              'comment': cve['description'] ?? '',
              'created_at': cve['created_at'],
              'cve_id': cve['cve_id'],
              'confidence_level': cve['confidence_level'],
              'vulnerability_type': cve['vulnerability_type'],
              'cvss_base_score': cve['cvss_score'],
              'url': cve['url'],
              'finding_type': 'CVE',
              'project_id': cve['project_id'],
            });
          }
        }
        debugPrint('CVE migration completed: ${cveRecords.length} records migrated');
      } catch (e) {
        debugPrint('Error in version 16 migration: $e');
      }
    }
    if (oldVersion < 17) {
      try {
        await db.execute('ALTER TABLE flagged_findings ADD COLUMN recommendation TEXT');
        debugPrint('Successfully added recommendation column to flagged_findings');
      } catch (e) {
        debugPrint('Error adding recommendation column: $e');
      }
    }
    if (oldVersion < 18) {
      try {
        await db.execute('ALTER TABLE flagged_findings ADD COLUMN evidence TEXT');
        debugPrint('Successfully added evidence column to flagged_findings');
      } catch (e) {
        debugPrint('Error adding evidence column: $e');
      }
    }
    if (oldVersion < 19) {
      try {
        await db.execute('ALTER TABLE devices ADD COLUMN mac_address TEXT');
        await db.execute('ALTER TABLE devices ADD COLUMN vendor TEXT');
        debugPrint('Successfully added mac_address and vendor columns to devices');
      } catch (e) {
        debugPrint('Error adding mac_address/vendor columns: $e');
      }
      try {
        await db.execute('''
          CREATE TABLE snmp_findings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_id INTEGER NOT NULL,
            project_id INTEGER NOT NULL,
            finding_type TEXT NOT NULL,
            finding_value TEXT NOT NULL,
            FOREIGN KEY (device_id) REFERENCES devices (id),
            FOREIGN KEY (project_id) REFERENCES projects (id)
          )
        ''');
        debugPrint('Successfully created snmp_findings table');
      } catch (e) {
        debugPrint('Error creating snmp_findings table: $e');
      }
    }
  }
}
