class ExportData {
  final List<ProjectExport> projects;
  final String version;
  final DateTime exportedAt;

  ExportData({
    required this.projects,
    required this.version,
    required this.exportedAt,
  });

  Map<String, dynamic> get metadata => {
        'version': version,
        'exportedAt': exportedAt.toIso8601String(),
        'projects': projects.map((p) => {'name': p.project['name']}).toList(),
      };

  Map<String, dynamic> toJson() => {
        'projects': projects.map((p) => p.toJson()).toList(),
        'version': version,
        'exportedAt': exportedAt.toIso8601String(),
      };

  factory ExportData.fromJson(Map<String, dynamic> json) => ExportData(
        projects: (json['projects'] as List)
            .map((p) => ProjectExport.fromJson(p))
            .toList(),
        version: json['version'],
        exportedAt: DateTime.parse(json['exportedAt']),
      );
}

class ProjectExport {
  final Map<String, dynamic> project;
  final List<Map<String, dynamic>> devices;
  final List<Map<String, dynamic>> nmapScans;
  final List<Map<String, dynamic>> niktoScans;
  final List<Map<String, dynamic>> searchsploitScans;
  final List<Map<String, dynamic>> findings;
  final List<Map<String, dynamic>> classifications;
  final List<Map<String, dynamic>> reportSections;
  final List<Map<String, dynamic>> tags;
  final List<Map<String, dynamic>> nmapHosts;
  final List<Map<String, dynamic>> nmapOsMatches;
  final List<Map<String, dynamic>> nmapPorts;
  final List<Map<String, dynamic>> nmapScripts;
  final List<Map<String, dynamic>> niktoFindings;
  final List<Map<String, dynamic>> searchsploitResults;
  final List<Map<String, dynamic>> ffufFindings;
  final List<Map<String, dynamic>> whatwebFindings;
  final List<Map<String, dynamic>> sambaLdapFindings;
  final List<Map<String, dynamic>> snmpFindings;
  final List<String> uploadFiles;

  ProjectExport({
    required this.project,
    required this.devices,
    required this.nmapScans,
    required this.niktoScans,
    required this.searchsploitScans,
    required this.findings,
    required this.classifications,
    required this.reportSections,
    required this.tags,
    required this.nmapHosts,
    required this.nmapOsMatches,
    required this.nmapPorts,
    required this.nmapScripts,
    required this.niktoFindings,
    required this.searchsploitResults,
    required this.ffufFindings,
    required this.whatwebFindings,
    required this.sambaLdapFindings,
    required this.snmpFindings,
    required this.uploadFiles,
  });

  Map<String, dynamic> toJson() => {
        'project': project,
        'devices': devices,
        'nmapScans': nmapScans,
        'niktoScans': niktoScans,
        'searchsploitScans': searchsploitScans,
        'findings': findings,
        'classifications': classifications,
        'reportSections': reportSections,
        'tags': tags,
        'nmapHosts': nmapHosts,
        'nmapOsMatches': nmapOsMatches,
        'nmapPorts': nmapPorts,
        'nmapScripts': nmapScripts,
        'niktoFindings': niktoFindings,
        'searchsploitResults': searchsploitResults,
        'ffufFindings': ffufFindings,
        'whatwebFindings': whatwebFindings,
        'sambaLdapFindings': sambaLdapFindings,
        'snmpFindings': snmpFindings,
        'uploadFiles': uploadFiles,
      };

  factory ProjectExport.fromJson(Map<String, dynamic> json) => ProjectExport(
        project: json['project'],
        devices: List<Map<String, dynamic>>.from(json['devices']),
        nmapScans: List<Map<String, dynamic>>.from(json['nmapScans']),
        niktoScans: List<Map<String, dynamic>>.from(json['niktoScans']),
        searchsploitScans:
            List<Map<String, dynamic>>.from(json['searchsploitScans']),
        findings: List<Map<String, dynamic>>.from(json['findings']),
        classifications:
            List<Map<String, dynamic>>.from(json['classifications']),
        reportSections: List<Map<String, dynamic>>.from(json['reportSections']),
        tags: List<Map<String, dynamic>>.from(json['tags']),
        nmapHosts: List<Map<String, dynamic>>.from(json['nmapHosts']),
        nmapOsMatches: List<Map<String, dynamic>>.from(json['nmapOsMatches'] ?? []),
        nmapPorts: List<Map<String, dynamic>>.from(json['nmapPorts']),
        nmapScripts: List<Map<String, dynamic>>.from(json['nmapScripts']),
        niktoFindings: List<Map<String, dynamic>>.from(json['niktoFindings']),
        searchsploitResults:
            List<Map<String, dynamic>>.from(json['searchsploitResults']),
        ffufFindings: List<Map<String, dynamic>>.from(json['ffufFindings'] ?? []),
        whatwebFindings: List<Map<String, dynamic>>.from(json['whatwebFindings'] ?? []),
        sambaLdapFindings: List<Map<String, dynamic>>.from(json['sambaLdapFindings'] ?? []),
        snmpFindings: List<Map<String, dynamic>>.from(json['snmpFindings'] ?? []),
        uploadFiles: List<String>.from(json['uploadFiles']),
      );
}
