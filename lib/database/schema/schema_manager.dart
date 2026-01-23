import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class SchemaManager {
  static const int currentVersion = 26;

  static Future<void> onCreate(Database db, int version) async {
    await _createTables(db);
    await _createIndexes(db);
    await _insertDefaultData(db);
  }

  static Future<void> _createTables(Database db) async {
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
        netbios_name TEXT,
        netbios_user TEXT,
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
      CREATE TABLE nmap_hosts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id INTEGER NOT NULL,
        project_id INTEGER,
        address TEXT,
        mac_address TEXT,
        vendor TEXT,
        status TEXT,
        uptime_seconds INTEGER,
        last_boot TEXT,
        FOREIGN KEY (device_id) REFERENCES devices (id),
        FOREIGN KEY (project_id) REFERENCES projects (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE nmap_os_matches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        host_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        accuracy INTEGER NOT NULL,
        vendor TEXT,
        os_family TEXT,
        os_generation TEXT,
        cpe TEXT,
        FOREIGN KEY (host_id) REFERENCES nmap_hosts (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE nmap_ports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        host_id INTEGER NOT NULL,
        port INTEGER NOT NULL,
        protocol TEXT NOT NULL,
        state TEXT NOT NULL,
        reason TEXT,
        service_name TEXT,
        product TEXT,
        version TEXT,
        cpe TEXT,
        FOREIGN KEY (host_id) REFERENCES nmap_hosts (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE nmap_scripts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        port_id INTEGER NOT NULL,
        script_id TEXT NOT NULL,
        output TEXT NOT NULL,
        FOREIGN KEY (port_id) REFERENCES nmap_ports (id)
      )
    ''');

    await db.execute('''
      CREATE TABLE nmap_cves (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        script_id INTEGER NOT NULL,
        cve_id TEXT NOT NULL,
        cvss REAL,
        is_exploit BOOLEAN,
        url TEXT,
        FOREIGN KEY (script_id) REFERENCES nmap_scripts (id)
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
      CREATE TABLE nikto_findings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        device_id INTEGER NOT NULL,
        item_id TEXT,
        description TEXT,
        uri TEXT,
        namelink TEXT,
        iplink TEXT,
        references_data TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (device_id) REFERENCES devices (id)
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

    await db.execute('''
      CREATE TABLE report_sections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        section_type TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (project_id) REFERENCES projects (id),
        UNIQUE(project_id, section_type)
      )
    ''');

    await db.execute('''
      CREATE TABLE scan_range (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        project_id INTEGER NOT NULL,
        ip_range TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (project_id) REFERENCES projects (id)
      )
    ''');
  }

  static Future<void> _createIndexes(Database db) async {
    await db.execute('CREATE INDEX idx_devices_project_id ON devices(project_id)');
    await db.execute('CREATE INDEX idx_nmap_hosts_device_id ON nmap_hosts(device_id)');
    await db.execute('CREATE INDEX idx_nmap_ports_host_id ON nmap_ports(host_id)');
    await db.execute('CREATE INDEX idx_device_tags_device_id ON device_tags(device_id)');
    await db.execute('CREATE INDEX idx_flagged_findings_device_id ON flagged_findings(device_id)');
    await db.execute('CREATE INDEX idx_vuln_classifications_finding_id ON vulnerability_classifications(finding_id)');
    await db.execute('CREATE INDEX idx_ffuf_findings_device_id ON ffuf_findings(device_id)');
    await db.execute('CREATE INDEX idx_whatweb_findings_device_id ON whatweb_findings(device_id)');
    await db.execute('CREATE INDEX idx_samba_ldap_findings_device_id ON samba_ldap_findings(device_id)');
    await db.execute('CREATE INDEX idx_vulnerabilities_device_id ON vulnerabilities(device_id)');
    await db.execute('CREATE INDEX idx_snmp_findings_device_id ON snmp_findings(device_id)');
    await db.execute('CREATE INDEX idx_nikto_findings_device_id ON nikto_findings(device_id)');
    await db.execute('CREATE INDEX idx_nmap_scripts_port_id ON nmap_scripts(port_id)');
    await db.execute('CREATE INDEX idx_nmap_cves_script_id ON nmap_cves(script_id)');
    await db.execute('CREATE INDEX idx_scan_range_project_id ON scan_range(project_id)');
  }

  static Future<void> _insertDefaultData(Database db) async {
    await db.insert('settings', {'key': 'theme', 'value': 'DeepOcean'});
    await db.insert('settings', {'key': 'concurrent_scan_count', 'value': '3'});
  }

  static Future<void> onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 21) {
      // Add missing columns to nmap_hosts
      try {
        await db.execute('ALTER TABLE nmap_hosts ADD COLUMN project_id INTEGER');
      } catch (e) {
        // Column might already exist
      }
      try {
        await db.execute('ALTER TABLE nmap_hosts ADD COLUMN address TEXT');
      } catch (e) {
        // Column might already exist
      }
      try {
        await db.execute('ALTER TABLE nmap_hosts ADD COLUMN last_boot TEXT');
      } catch (e) {
        // Column might already exist
      }

      // Add missing column to nmap_ports
      try {
        await db.execute('ALTER TABLE nmap_ports ADD COLUMN reason TEXT');
      } catch (e) {
        // Column might already exist
      }

      // Add missing columns to nmap_os_matches
      try {
        await db.execute('ALTER TABLE nmap_os_matches ADD COLUMN vendor TEXT');
      } catch (e) {
        // Column might already exist
      }
      try {
        await db.execute('ALTER TABLE nmap_os_matches ADD COLUMN os_family TEXT');
      } catch (e) {
        // Column might already exist
      }
      try {
        await db.execute('ALTER TABLE nmap_os_matches ADD COLUMN os_generation TEXT');
      } catch (e) {
        // Column might already exist
      }

      // Add missing columns to nmap_cves
      try {
        await db.execute('ALTER TABLE nmap_cves ADD COLUMN is_exploit BOOLEAN');
      } catch (e) {
        // Column might already exist
      }
      try {
        await db.execute('ALTER TABLE nmap_cves ADD COLUMN url TEXT');
      } catch (e) {
        // Column might already exist
      }
    }

    if (oldVersion < 22) {
      // Add NetBIOS columns to devices table
      try {
        await db.execute('ALTER TABLE devices ADD COLUMN netbios_name TEXT');
      } catch (e) {
        // Column might already exist
      }
      try {
        await db.execute('ALTER TABLE devices ADD COLUMN netbios_user TEXT');
      } catch (e) {
        // Column might already exist
      }
    }

    if (oldVersion < 23) {
      // Create nikto_findings table
      try {
        await db.execute('''
          CREATE TABLE nikto_findings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_id INTEGER NOT NULL,
            item_id TEXT,
            description TEXT,
            uri TEXT,
            namelink TEXT,
            iplink TEXT,
            references_data TEXT,
            created_at TEXT NOT NULL,
            FOREIGN KEY (device_id) REFERENCES devices (id)
          )
        ''');
        await db.execute('CREATE INDEX idx_nikto_findings_device_id ON nikto_findings(device_id)');
      } catch (e) {
        // Table might already exist
      }
    }

    if (oldVersion < 24) {
      // Retry creating nikto_findings table if missed in version 23 update
      try {
        await db.execute('''
          CREATE TABLE nikto_findings (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            device_id INTEGER NOT NULL,
            item_id TEXT,
            description TEXT,
            uri TEXT,
            namelink TEXT,
            iplink TEXT,
            references_data TEXT,
            created_at TEXT NOT NULL,
            FOREIGN KEY (device_id) REFERENCES devices (id)
          )
        ''');
        await db.execute('CREATE INDEX idx_nikto_findings_device_id ON nikto_findings(device_id)');
      } catch (e) {
        // Table might already exist
      }
    }

    if (oldVersion < 25) {
      // Add missing indexes for nmap tables
      try {
        await db.execute('CREATE INDEX idx_nmap_scripts_port_id ON nmap_scripts(port_id)');
      } catch (e) {
        // Index might already exist
      }
      try {
        await db.execute('CREATE INDEX idx_nmap_cves_script_id ON nmap_cves(script_id)');
      } catch (e) {
        // Index might already exist
      }
    }

    if (oldVersion < 26) {
      // Create scan_range table
      try {
        await db.execute('''
          CREATE TABLE scan_range (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            project_id INTEGER NOT NULL,
            ip_range TEXT NOT NULL,
            created_at TEXT NOT NULL,
            FOREIGN KEY (project_id) REFERENCES projects (id)
          )
        ''');
        await db.execute('CREATE INDEX idx_scan_range_project_id ON scan_range(project_id)');
      } catch (e) {
        // Table might already exist
      }
    }
  }
}
