import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:penpeeper/models/report_models.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'web_download_stub.dart' if (dart.library.html) 'web_download_web.dart';
import 'quill_parser.dart';

class ReportGenerator {
  Future<void> generateRTFReport(
    ReportData reportData,
    String projectName,
  ) async {
    if (kIsWeb) {
      await _generateWebReport(reportData, projectName, 'rtf');
    } else {
      final rtfContent = await _buildRTFContent(reportData, projectName);
      // Desktop file save
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save RTF Report',
        fileName: '${projectName}_Report.rtf',
        type: FileType.custom,
        allowedExtensions: ['rtf'],
      );

      if (result != null) {
        final file = File(result);
        await file.writeAsString(rtfContent);
      }
    }
  }

  Future<String> _buildRTFContent(
    ReportData reportData,
    String projectName,
  ) async {
    QuillParser.resetColorTable();
    final buffer = StringBuffer();

    // Process findings - convert delta to RTF for each grouped finding
    final processedGroupedFindings = <String, List<ReportFinding>>{};
    for (final entry in reportData.groupedFindings.entries) {
      final processedFindings = <ReportFinding>[];
      for (final finding in entry.value) {
        final comment = await QuillParser.deltaToRTF(finding.comment);
        final evidence = finding.evidence != null
            ? await QuillParser.deltaToRTF(finding.evidence!)
            : null;
        final recommendation = finding.recommendation != null
            ? await QuillParser.deltaToRTF(finding.recommendation!)
            : null;

        processedFindings.add(
          ReportFinding(
            id: finding.id,
            deviceId: finding.deviceId,
            deviceName: finding.deviceName,
            ipAddress: finding.ipAddress,
            type: finding.type,
            comment: comment,
            evidence: evidence,
            recommendation: recommendation,
            category: finding.category,
            subcategory: finding.subcategory,
            cvssScore: finding.cvssScore,
            cvssSeverity: finding.cvssSeverity,
            cvssVersion: finding.cvssVersion,
            cveId: finding.cveId,
            macAddress: finding.macAddress,
            vendor: finding.vendor,
            createdAt: finding.createdAt,
          ),
        );
      }
      processedGroupedFindings[entry.key] = processedFindings;
    }

    // Professional RTF Header
    buffer.writeln(r'{\rtf1\ansi\deff0');
    buffer.writeln(
      r'{\fonttbl {\f0\fswiss\fcharset0 Segoe UI;}{\f1\fmodern\fcharset0 Consolas;}{\f2\froman\fcharset0 Times New Roman;}}',
    );
    buffer.writeln(
      r'{\colortbl;\red0\green0\blue0;\red220\green53\blue69;\red255\green193\blue7;\red255\green235\blue59;\red40\green167\blue69;\red52\green73\blue94;\red248\green249\blue250;\red33\green37\blue41;}',
    );
    buffer.writeln(QuillParser.buildColorTable());
    buffer.writeln(r'\f2\fs24'); // Times New Roman, 12pt

    // Report Header
    if (reportData.reportHeader != null &&
        reportData.reportHeader!.isNotEmpty) {
      final reportHeaderRTF = await QuillParser.deltaToRTF(
        reportData.reportHeader!,
      );
      buffer.writeln('\\pard\\sa120\\sb60\\qc $reportHeaderRTF\\par');
    } else {
      buffer.writeln(
        '\\pard\\sa120\\sb60\\qc\\f0\\fs32\\b\\cf8 PENETRATION TESTING REPORT\\b0\\fs20\\par',
      );
    }
    buffer.writeln(
      '\\pard\\sa60\\qc\\cf8\\fs4 ________________________________________________________________________________________________\\par\\par',
    );

    // Table of Contents
    buffer.writeln(
      '\\pard\\sa90\\sb60\\ql\\f0\\fs24\\b\\cf8 TABLE OF CONTENTS\\b0\\fs20\\par',
    );
    buffer.writeln(
      '\\pard\\sa30\\ql\\cf8\\fs4 ________________________________________________________________________________\\par',
    );
    buffer.writeln(
      '{\\pard\\sa15\\ql\\f2\\fs20\\b Executive Summary\\tab\\tab\\tab\\tab\\tab\\tab\\tab {\\field{\\*\\fldinst PAGEREF exec_summary}{\\fldrslt 1}}\\b0\\par}',
    );
    buffer.writeln(
      '{\\pard\\sa15\\ql\\f2\\fs20\\b Methodology and Scope\\tab\\tab\\tab\\tab\\tab\\tab {\\field{\\*\\fldinst PAGEREF method_scope}{\\fldrslt 2}}\\b0\\par}',
    );
    buffer.writeln(
      '{\\pard\\sa15\\ql\\f2\\fs20\\b Findings\\tab\\tab\\tab\\tab\\tab\\tab\\tab\\tab {\\field{\\*\\fldinst PAGEREF findings_section}{\\fldrslt 3}}\\b0\\par}',
    );
    buffer.writeln(
      '{\\pard\\sa15\\ql\\f2\\fs20\\b Risk Rating Model\\tab\\tab\\tab\\tab\\tab\\tab\\tab {\\field{\\*\\fldinst PAGEREF risk_rating}{\\fldrslt 4}}\\b0\\par}',
    );
    buffer.writeln(
      '{\\pard\\sa15\\ql\\f2\\fs20\\b Conclusion\\tab\\tab\\tab\\tab\\tab\\tab\\tab\\tab {\\field{\\*\\fldinst PAGEREF conclusion_section}{\\fldrslt 5}}\\b0\\par}',
    );
    buffer.writeln(
      '\\pard\\sa30\\ql\\cf8\\fs4 ________________________________________________________________________________\\par\\par',
    );
    buffer.writeln('\\page');

    // Executive Summary
    buffer.writeln('{\\*\\bkmkstart exec_summary}');
    buffer.writeln(
      '\\pard\\sa90\\sb60\\ql\\f0\\fs24\\b\\cf8 EXECUTIVE SUMMARY\\b0\\fs20\\par',
    );
    buffer.writeln('{\\*\\bkmkend exec_summary}');
    buffer.writeln(
      '\\pard\\sa30\\ql\\cf8\\fs4 ________________________________________________________________________________\\par',
    );
    if (reportData.executiveSummary != null &&
        reportData.executiveSummary!.isNotEmpty) {
      final executiveSummaryRTF = await QuillParser.deltaToRTF(
        reportData.executiveSummary!,
      );
      buffer.writeln('\\pard\\sa15\\ql\\f2\\fs20 $executiveSummaryRTF\\par');
    }
    final totalFindings = reportData.findings.length;
    final totalCategories = reportData.groupedFindings.keys
        .map((k) => k.split('|')[0])
        .toSet()
        .length;
    buffer.writeln(
      '\\pard\\sa15\\ql\\f2\\fs20\\b Total Findings: \\b0\\cf2 $totalFindings\\cf1\\par',
    );
    buffer.writeln(
      '\\pard\\sa15\\ql\\f2\\fs20\\b Categories: \\b0\\cf5 $totalCategories\\cf1\\par',
    );
    buffer.writeln(
      '\\pard\\sa30\\ql\\cf8\\fs4 ________________________________________________________________________________\\par\\par',
    );
    buffer.writeln('\\page');

    // Methodology and Scope
    if (reportData.methodologyScope != null &&
        reportData.methodologyScope!.isNotEmpty) {
      buffer.writeln('{\\*\\bkmkstart method_scope}');
      buffer.writeln(
        '\\pard\\sa90\\sb60\\ql\\f0\\fs24\\b\\cf8 METHODOLOGY AND SCOPE\\b0\\fs20\\par',
      );
      buffer.writeln('{\\*\\bkmkend method_scope}');
      buffer.writeln(
        '\\pard\\sa30\\ql\\cf8\\fs4 ________________________________________________________________________________\\par',
      );
      final methodologyScopeRTF = await QuillParser.deltaToRTF(
        reportData.methodologyScope!,
      );
      buffer.writeln('\\pard\\sa15\\ql\\f2\\fs20 $methodologyScopeRTF\\par');
      buffer.writeln(
        '\\pard\\sa30\\ql\\cf8\\fs4 ________________________________________________________________________________\\par\\par',
      );
      buffer.writeln('\\page');
    }

    // Detailed Findings Header
    buffer.writeln('{\\*\\bkmkstart findings_section}');
    buffer.writeln(
      '\\pard\\sa90\\sb60\\ql\\f0\\fs24\\b\\cf8 DETAILED FINDINGS\\b0\\fs20\\par',
    );
    buffer.writeln('{\\*\\bkmkend findings_section}');
    buffer.writeln(
      '\\pard\\sa30\\ql\\cf8\\fs4 ________________________________________________________________________________\\par\\par',
    );

    String? currentCategory;
    String? currentSubcategory;

    for (final entry in processedGroupedFindings.entries) {
      final parts = entry.key.split('|');
      final category = parts[0];
      final subcategory = parts[1];
      final findings = entry.value;

      // Category Header
      if (currentCategory != category) {
        currentCategory = category;
        buffer.writeln(
          '\\pard\\sa60\\sb30\\ql\\f0\\fs22\\b\\cf8 ${_escapeRTF(category.toUpperCase())}\\b0\\fs20\\par',
        );
        buffer.writeln(
          '\\pard\\sa15\\ql\\cf8\\fs4 ________________________________________________________\\par',
        );
      }

      // Subcategory Header
      if (currentSubcategory != subcategory) {
        currentSubcategory = subcategory;
        buffer.writeln(
          '\\pard\\sa45\\sb15\\li360\\f0\\fs20\\b\\cf6 ${_escapeRTF(subcategory)}\\b0\\par',
        );
      }

      // Individual Findings
      for (final finding in findings) {
        final severity = finding.cvssSeverity ?? 'UNKNOWN';

        buffer.writeln(
          '\\pard\\sa30\\sb15\\li720\\f2\\fs20\\b Finding: \\cf2${_escapeRTF(severity.toUpperCase())}\\cf1\\b0\\par',
        );

        // Device section
        buffer.writeln('\\pard\\sa15\\li1080\\f2\\fs18\\b Device:\\b0\\par');
        buffer.writeln(
          '\\pard\\sa5\\li1440\\f2\\fs18\\b Host Name: \\b0 ${_escapeRTF(finding.deviceName)}\\par',
        );
        buffer.writeln(
          '\\pard\\sa5\\li1440\\f2\\fs18\\b IP Address: \\b0 ${_escapeRTF(finding.ipAddress)}\\par',
        );
        if (finding.macAddress != null && finding.macAddress!.isNotEmpty) {
          buffer.writeln(
            '\\pard\\sa5\\li1440\\f2\\fs18\\b MAC Address: \\b0 ${_escapeRTF(finding.macAddress!)}\\par',
          );
        }
        if (finding.vendor != null && finding.vendor!.isNotEmpty) {
          buffer.writeln(
            '\\pard\\sa5\\li1440\\f2\\fs18\\b MAC Vendor: \\b0 ${_escapeRTF(finding.vendor!)}\\par',
          );
        }

        // CVSS information
        if (finding.cvssScore != null) {
          final rawVersion = finding.cvssVersion ?? '3.1';
          final cvssVersion = rawVersion.startsWith('v')
              ? rawVersion
              : 'v$rawVersion';
          final cvssScore = finding.cvssScore!.toStringAsFixed(1);
          buffer.writeln(
            '\\pard\\sa5\\li1440\\f2\\fs18\\b CVSS: \\b0\\cf2$cvssVersion - $cvssScore\\cf1\\par',
          );
        }

        // CVE information
        if (finding.cveId != null) {
          buffer.writeln(
            '\\pard\\sa5\\li1440\\f1\\fs18\\b CVE: \\b0\\cf2${_escapeRTF(finding.cveId!)}\\cf1\\par',
          );
        }

        // Description Section
        if (finding.comment.isNotEmpty) {
          buffer.writeln(
            '\\pard\\sa15\\li1080\\f2\\fs18\\b Description:\\b0\\par',
          );
          buffer.writeln(
            '\\pard\\sa10\\li1080\\f2\\fs18 ${finding.comment}\\par',
          );
        }

        // Evidence Section
        if (finding.evidence != null && finding.evidence!.isNotEmpty) {
          buffer.writeln(
            '\\pard\\sa15\\li1080\\f2\\fs18\\b Evidence:\\b0\\par',
          );
          buffer.writeln(
            '\\pard\\sa10\\li1080\\ri720\\f2\\fs18 ${finding.evidence}\\par',
          );
        }

        // Recommendation Section
        if (finding.recommendation != null &&
            finding.recommendation!.isNotEmpty) {
          buffer.writeln(
            '\\pard\\sa15\\li1080\\f2\\fs18\\b Recommendation:\\b0\\par',
          );
          buffer.writeln(
            '\\pard\\sa10\\li1080\\f2\\fs18 ${finding.recommendation}\\par',
          );
        }

        buffer.writeln('\\par');
      }
      buffer.writeln('\\par');
    }
    buffer.writeln('\\page');

    // Risk Rating Model
    if (reportData.riskRatingModel != null &&
        reportData.riskRatingModel!.isNotEmpty) {
      buffer.writeln('{\\*\\bkmkstart risk_rating}');
      buffer.writeln(
        '\\pard\\sa90\\sb60\\ql\\f0\\fs24\\b\\cf8 RISK RATING MODEL\\b0\\fs20\\par',
      );
      buffer.writeln('{\\*\\bkmkend risk_rating}');
      buffer.writeln(
        '\\pard\\sa30\\ql\\cf8\\fs4 ________________________________________________________________________________\\par',
      );
      final riskRatingModelRTF = await QuillParser.deltaToRTF(
        reportData.riskRatingModel!,
      );
      buffer.writeln('\\pard\\sa15\\ql\\f2\\fs20 $riskRatingModelRTF\\par');
      buffer.writeln(
        '\\pard\\sa30\\ql\\cf8\\fs4 ________________________________________________________________________________\\par\\par',
      );
      buffer.writeln('\\page');
    }

    // Conclusion
    if (reportData.conclusion != null && reportData.conclusion!.isNotEmpty) {
      buffer.writeln('{\\*\\bkmkstart conclusion_section}');
      buffer.writeln(
        '\\pard\\sa90\\sb60\\ql\\f0\\fs24\\b\\cf8 CONCLUSION\\b0\\fs20\\par',
      );
      buffer.writeln('{\\*\\bkmkend conclusion_section}');
      buffer.writeln(
        '\\pard\\sa30\\ql\\cf8\\fs4 ________________________________________________________________________________\\par',
      );
      final conclusionRTF = await QuillParser.deltaToRTF(
        reportData.conclusion!,
      );
      buffer.writeln('\\pard\\sa15\\ql\\f2\\fs20 $conclusionRTF\\par');
      buffer.writeln(
        '\\pard\\sa30\\ql\\cf8\\fs4 ________________________________________________________________________________\\par\\par',
      );
    }

    buffer.writeln('}');
    return buffer.toString();
  }

  int _getCvssRTFColor(double score) {
    if (score >= 9.0) return 2; // Critical - Red
    if (score >= 7.0) return 3; // High - Orange
    if (score >= 4.0) return 4; // Medium - Yellow
    if (score >= 0.1) return 5; // Low - Green
    return 6; // Info - Blue
  }

  String _escapeRTF(String text) {
    text = text.replaceAll(String.fromCharCodes([226, 128, 147]), '-');
    text = text.replaceAll(String.fromCharCodes([226, 128, 148]), '-');
    text = text.replaceAll(String.fromCharCodes([226, 128, 156]), '"');
    text = text.replaceAll(String.fromCharCodes([226, 128, 157]), '"');
    text = text.replaceAll(String.fromCharCodes([194, 160]), ' ');

    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      final code = char.codeUnitAt(0);

      if (char == '\\') {
        buffer.write('\\\\');
      } else if (char == '{') {
        buffer.write('\\{');
      } else if (char == '}') {
        buffer.write('\\}');
      } else if (char == '\n') {
        buffer.write('\\par ');
      } else if (code == 0x2013 || code == 0x2014) {
        buffer.write('-');
      } else if (code == 0x201C || code == 0x201D) {
        buffer.write('"');
      } else if (code == 0x00A0) {
        buffer.write(' ');
      } else if (code > 127) {
        if (code > 32767) {
          buffer.write('\\u${(code - 65536)}?');
        } else {
          buffer.write('\\u$code?');
        }
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  Future<void> generateHTMLReport(
    ReportData reportData,
    String projectName,
  ) async {
    if (kIsWeb) {
      await _generateWebReport(reportData, projectName, 'html');
    } else {
      final htmlContent = await _buildHTMLContent(reportData, projectName);
      // Desktop file save
      final result = await FilePicker.platform.saveFile(
        dialogTitle: 'Save HTML Report',
        fileName: '${projectName}_Report.html',
        type: FileType.custom,
        allowedExtensions: ['html'],
      );

      if (result != null) {
        final file = File(result);
        await file.writeAsString(htmlContent);
      }
    }
  }

  Future<String> _buildHTMLContent(
    ReportData reportData,
    String projectName,
  ) async {
    final buffer = StringBuffer();

    // HTML Header
    buffer.writeln('<!DOCTYPE html>');
    buffer.writeln('<html lang="en">');
    buffer.writeln('<head>');
    buffer.writeln('<meta charset="UTF-8">');
    buffer.writeln(
      '<meta name="viewport" content="width=device-width, initial-scale=1.0">',
    );
    buffer.writeln('<title>Penetration Testing Report - $projectName</title>');
    buffer.writeln('<style>');
    buffer.writeln(_getHTMLStyles());
    buffer.writeln('</style>');
    buffer.writeln('</head>');
    buffer.writeln('<body>');
    buffer.writeln('<div class="container">');

    // Professional Header
    buffer.writeln('<div class="header">');
    if (reportData.reportHeader != null &&
        reportData.reportHeader!.isNotEmpty) {
      final reportHeaderHTML = await _processHTMLWithImages(
        reportData.reportHeader!,
        projectName,
      );
      buffer.writeln(reportHeaderHTML);
    } else {
      buffer.writeln('<h1>Penetration Testing Report</h1>');
    }
    buffer.writeln('</div>');

    // Table of Contents
    buffer.writeln('<div class="toc">');
    buffer.writeln('<h2>Table of Contents</h2>');
    buffer.writeln('<ul class="toc-list">');
    buffer.writeln(
      '<li><a href="#executive-summary">Executive Summary</a></li>',
    );
    buffer.writeln(
      '<li><a href="#methodology-scope">Methodology and Scope</a></li>',
    );
    buffer.writeln('<li><a href="#findings">Findings</a></li>');
    buffer.writeln('<li><a href="#risk-rating">Risk Rating Model</a></li>');
    buffer.writeln('<li><a href="#conclusion">Conclusion</a></li>');
    buffer.writeln('</ul>');
    buffer.writeln('</div>');
    buffer.writeln('<div class="page-break"></div>');

    // Executive Summary
    final criticalHigh = reportData.findings
        .where((f) => (f.cvssScore ?? 0.0) >= 7.0)
        .length;
    buffer.writeln('<div class="summary" id="executive-summary">');
    buffer.writeln('<h2>Executive Summary</h2>');
    if (reportData.executiveSummary != null &&
        reportData.executiveSummary!.isNotEmpty) {
      final executiveSummaryHTML = await _processHTMLWithImages(
        reportData.executiveSummary!,
        projectName,
      );
      buffer.writeln('<div class="content">$executiveSummaryHTML</div>');
    }
    buffer.writeln('<div class="summary-stats">');
    buffer.writeln('<div class="stat">');
    buffer.writeln(
      '<span class="stat-number">${reportData.findings.length}</span>',
    );
    buffer.writeln('<span class="stat-label">Total Findings</span>');
    buffer.writeln('</div>');
    buffer.writeln('<div class="stat">');
    buffer.writeln(
      '<span class="stat-number">${reportData.groupedFindings.keys.map((k) => k.split('|')[0]).toSet().length}</span>',
    );
    buffer.writeln('<span class="stat-label">Categories</span>');
    buffer.writeln('</div>');
    buffer.writeln('<div class="stat">');
    buffer.writeln('<span class="stat-number">$criticalHigh</span>');
    buffer.writeln('<span class="stat-label">Critical/High Risk</span>');
    buffer.writeln('</div>');
    buffer.writeln('</div>');
    buffer.writeln('</div>');
    buffer.writeln('<div class="page-break"></div>');

    // Methodology and Scope
    if (reportData.methodologyScope != null &&
        reportData.methodologyScope!.isNotEmpty) {
      buffer.writeln('<div class="summary" id="methodology-scope">');
      buffer.writeln('<h2>Methodology and Scope</h2>');
      final methodologyScopeHTML = await _processHTMLWithImages(
        reportData.methodologyScope!,
        projectName,
      );
      buffer.writeln('<div class="content">$methodologyScopeHTML</div>');
      buffer.writeln('</div>');
      buffer.writeln('<div class="page-break"></div>');
    }

    // Findings
    buffer.writeln('<div class="findings" id="findings">');
    buffer.writeln('<h2>Detailed Findings</h2>');

    String? currentCategory;
    String? currentSubcategory;

    for (final entry in reportData.groupedFindings.entries) {
      final parts = entry.key.split('|');
      final category = parts[0];
      final subcategory = parts[1];
      final findings = entry.value;

      // Category header
      if (currentCategory != category) {
        if (currentCategory != null) {
          buffer.writeln('</div>'); // Close previous category
        }
        currentCategory = category;
        buffer.writeln('<div class="category">');
        buffer.writeln('<h3>$category</h3>');
      }

      // Subcategory header
      if (currentSubcategory != subcategory) {
        if (currentSubcategory != null) {
          buffer.writeln('</div>'); // Close previous subcategory
        }
        currentSubcategory = subcategory;
        buffer.writeln('<div class="subcategory">');
        buffer.writeln('<h4>$subcategory</h4>');
      }

      // Individual findings
      for (final finding in findings) {
        final severity = finding.cvssSeverity ?? 'UNKNOWN';

        buffer.writeln('<div class="finding">');
        buffer.writeln(
          '<h6>Finding: ${_escapeHTML(severity.toUpperCase())}</h6>',
        );

        buffer.writeln('<div class="section">');
        buffer.writeln('<div class="section-title">Device:</div>');
        buffer.writeln('<div class="content">');
        buffer.writeln(
          '<p><strong>Host Name:</strong> ${_escapeHTML(finding.deviceName)}</p>',
        );
        buffer.writeln(
          '<p><strong>IP Address:</strong> ${_escapeHTML(finding.ipAddress)}</p>',
        );
        if (finding.macAddress != null && finding.macAddress!.isNotEmpty) {
          buffer.writeln(
            '<p><strong>MAC Address:</strong> ${_escapeHTML(finding.macAddress!)}</p>',
          );
        }
        if (finding.vendor != null && finding.vendor!.isNotEmpty) {
          buffer.writeln(
            '<p><strong>MAC Vendor:</strong> ${_escapeHTML(finding.vendor!)}</p>',
          );
        }
        if (finding.cvssScore != null) {
          final rawVersion = finding.cvssVersion ?? '3.1';
          final cvssVersion = rawVersion.startsWith('v')
              ? rawVersion
              : 'v$rawVersion';
          final cvssScore = finding.cvssScore!.toStringAsFixed(1);
          buffer.writeln(
            '<p><strong>CVSS:</strong> <span style="color: #dc3545;">$cvssVersion - $cvssScore</span></p>',
          );
        }
        if (finding.cveId != null) {
          buffer.writeln(
            '<p><strong>CVE:</strong> <span style="color: #dc3545;">${_escapeHTML(finding.cveId!)}</span></p>',
          );
        }
        buffer.writeln('</div>');
        buffer.writeln('</div>');
        buffer.writeln('');

        // Description
        final comment = await _processHTMLWithImages(
          finding.comment,
          projectName,
        );
        if (comment.trim().isNotEmpty) {
          buffer.writeln('<div class="section">');
          buffer.writeln('<div class="section-title">Description:</div>');
          buffer.writeln('<div class="content description">$comment</div>');
          buffer.writeln('</div>');
        }

        // Evidence
        if (finding.evidence != null && finding.evidence!.isNotEmpty) {
          final evidence = await _processHTMLWithImages(
            finding.evidence!,
            projectName,
          );
          if (evidence.trim().isNotEmpty) {
            buffer.writeln('<div class="section">');
            buffer.writeln('<div class="section-title">Evidence:</div>');
            buffer.writeln('<div class="content evidence">$evidence</div>');
            buffer.writeln('</div>');
          }
        }

        // Recommendation
        if (finding.recommendation != null &&
            finding.recommendation!.isNotEmpty) {
          final recommendation = await _processHTMLWithImages(
            finding.recommendation!,
            projectName,
          );
          if (recommendation.trim().isNotEmpty) {
            buffer.writeln('<div class="section">');
            buffer.writeln('<div class="section-title">Recommendation:</div>');
            buffer.writeln(
              '<div class="content recommendation">$recommendation</div>',
            );
            buffer.writeln('</div>');
          }
        }

        buffer.writeln('</div>');
      }
    }

    if (currentSubcategory != null) {
      buffer.writeln('</div>'); // Close last subcategory
    }
    if (currentCategory != null) {
      buffer.writeln('</div>'); // Close last category
    }

    buffer.writeln('</div>');
    buffer.writeln('<div class="page-break"></div>');

    // Risk Rating Model
    if (reportData.riskRatingModel != null &&
        reportData.riskRatingModel!.isNotEmpty) {
      buffer.writeln('<div class="summary" id="risk-rating">');
      buffer.writeln('<h2>Risk Rating Model</h2>');
      final riskRatingModelHTML = await _processHTMLWithImages(
        reportData.riskRatingModel!,
        projectName,
      );
      buffer.writeln('<div class="content">$riskRatingModelHTML</div>');
      buffer.writeln('</div>');
      buffer.writeln('<div class="page-break"></div>');
    }

    // Conclusion
    if (reportData.conclusion != null && reportData.conclusion!.isNotEmpty) {
      buffer.writeln('<div class="summary" id="conclusion">');
      buffer.writeln('<h2>Conclusion</h2>');
      final conclusionHTML = await _processHTMLWithImages(
        reportData.conclusion!,
        projectName,
      );
      buffer.writeln('<div class="content">$conclusionHTML</div>');
      buffer.writeln('</div>');
    }

    // Footer
    buffer.writeln('<div class="footer">');
    buffer.writeln(
      '<p>${reportData.findings.length} security issues identified across ${reportData.groupedFindings.keys.map((k) => k.split('|')[0]).toSet().length} categories</p>',
    );
    buffer.writeln('</div>');

    buffer.writeln('</div>');
    buffer.writeln('</body>');
    buffer.writeln('</html>');

    return buffer.toString();
  }

  String _getHTMLStyles() {
    return '''
* { margin: 0; padding: 0; box-sizing: border-box; }
body { font-family: 'Times New Roman', serif; line-height: 1.6; color: #2c3e50; background-color: #ffffff; }
.container { max-width: 1000px; margin: 0 auto; padding: 40px; background-color: white; }
.header { background: #34495e; color: white; padding: 30px; margin: -40px -40px 40px -40px; text-align: center; border-bottom: 3px solid #2c3e50; }
.header h1 { font-size: 2.2em; margin-bottom: 15px; font-weight: 400; letter-spacing: 1px; }
.header-info { display: flex; justify-content: space-between; margin-top: 20px; font-size: 1em; opacity: 0.9; }
.summary { background: #ecf0f1; color: #2c3e50; padding: 25px; border-radius: 5px; margin-bottom: 30px; border: 1px solid #bdc3c7; }
.summary h2 { font-size: 1.5em; margin-bottom: 20px; font-weight: 500; color: #34495e; }
.summary-stats { display: flex; justify-content: space-around; margin-top: 15px; }
.stat { text-align: center; }
.stat-number { font-size: 1.8em; font-weight: 600; display: block; color: #e74c3c; }
.stat-label { font-size: 0.9em; color: #7f8c8d; }
h2 { color: #2c3e50; border-bottom: 2px solid #34495e; padding-bottom: 8px; margin: 30px 0 20px 0; font-size: 1.6em; font-weight: 500; }
h3 { color: #34495e; margin: 25px 0 15px 0; font-size: 1.3em; padding-left: 15px; border-left: 3px solid #95a5a6; font-weight: 500; }
h4 { color: #555; margin: 20px 0 10px 20px; font-size: 1.1em; padding-left: 10px; border-left: 2px solid #bdc3c7; font-weight: 500; }
h5 { margin: 15px 0 8px 40px; font-size: 1em; color: #666; font-weight: 500; }
.finding { margin: 15px 0 15px 40px; padding: 20px; border-radius: 3px; background: #fdfdfd; border: 1px solid #d5dbdb; border-top: 3px solid #34495e; }
.finding h6 { margin: 0 0 12px 0; color: #2c3e50; font-size: 1em; font-weight: 600; }
.cve-info { background: #f8f9fa; padding: 8px 12px; border-radius: 3px; margin-bottom: 12px; font-style: italic; color: #6c757d; border-left: 3px solid #95a5a6; }
.section { margin: 12px 0; }
.section-title { font-weight: 600; color: #34495e; margin-bottom: 6px; font-size: 0.95em; }
.content { background: #fafbfc; padding: 12px; border-radius: 3px; border-left: 3px solid #95a5a6; line-height: 1.6; }
.content p { margin-bottom: 8px; }
.content p:last-child { margin-bottom: 0; }
.cvss { padding: 3px 8px; border-radius: 3px; color: white; font-weight: 600; font-size: 0.8em; display: inline-block; margin-right: 8px; }
.cvss.critical { background: #c0392b; }
.cvss.high { background: #d35400; }
.cvss.medium { background: #f39c12; color: #2c3e50; }
.cvss.low { background: #27ae60; }
.cvss.none { background: #7f8c8d; }
.evidence-image { max-width: 90%; height: auto; border: 1px solid #bdc3c7; border-radius: 3px; margin: 8px auto; display: block; }
.image-placeholder { background: #f8f9fa; border: 1px dashed #bdc3c7; padding: 15px; text-align: center; color: #7f8c8d; border-radius: 3px; margin: 8px 0; font-size: 0.9em; }
.recommendation { background: #eafaf1; border-left: 3px solid #27ae60; }
.description { border-left: 3px solid #3498db; }
.evidence { border-left: 3px solid #f39c12; }
.ip-address { font-family: 'Courier New', monospace; background: #ecf0f1; padding: 2px 5px; border-radius: 2px; font-weight: 500; font-size: 0.9em; }
.footer { margin-top: 40px; padding: 20px; background: #f8f9fa; border-radius: 3px; text-align: center; color: #7f8c8d; border-top: 1px solid #ecf0f1; }
.toc { background: #f8f9fa; padding: 25px; border-radius: 5px; margin-bottom: 30px; border: 1px solid #bdc3c7; }
.toc h2 { font-size: 1.5em; margin-bottom: 20px; font-weight: 500; color: #34495e; border-bottom: 2px solid #34495e; padding-bottom: 8px; }
.toc-list { list-style: none; margin: 0; padding: 0; }
.toc-list li { margin: 12px 0; padding: 8px 0; border-bottom: 1px dotted #bdc3c7; }
.toc-list li:last-child { border-bottom: none; }
.toc-list a { text-decoration: none; color: #2c3e50; font-weight: 500; display: flex; justify-content: space-between; align-items: center; }
.toc-list a:hover { color: #3498db; }
@page { size: letter; margin: 1in; }
.page-break { page-break-after: always; }
ul { margin: 8px 0 8px 20px; }
li { margin-bottom: 4px; line-height: 1.5; }
.content br { line-height: 1.2; }
@media print { body { margin: 0; background: white; } .container { padding: 20px; } .header { page-break-after: avoid; } .finding { page-break-inside: avoid; } }
@media (max-width: 768px) { .container { padding: 20px; } .header { padding: 20px; margin: -20px -20px 30px -20px; } .header h1 { font-size: 1.8em; } .header-info { flex-direction: column; gap: 8px; } .summary-stats { flex-direction: column; gap: 10px; } }
''';
  }

  String _getCvssHTMLClass(double score) {
    if (score >= 9.0) return 'critical';
    if (score >= 7.0) return 'high';
    if (score >= 4.0) return 'medium';
    if (score >= 0.1) return 'low';
    return 'none';
  }

  String _escapeHTML(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;');
  }

  Future<String> _processHTMLWithImages(
    String deltaJson,
    String projectName,
  ) async {
    if (deltaJson.isEmpty) return '';

    try {
      // Use the QuillParser with image support for HTML conversion
      return await QuillParser.deltaToHTMLWithImages(deltaJson, projectName);
    } catch (e) {
      // Fallback: treat as plain text and convert newlines to <br>
      return _escapeHTML(deltaJson).replaceAll('\n', '<br>');
    }
  }

  Future<String?> _convertImageToBase64(
    dynamic imageSource,
    String projectName,
  ) async {
    try {
      if (imageSource is String) {
        if (imageSource.startsWith('data:image/')) {
          return imageSource; // Already base64
        }

        // Try to read from uploads directory
        final imagePath = imageSource.contains('uploads')
            ? imageSource
            : 'uploads/$projectName/$imageSource';

        final file = File(imagePath);
        if (await file.exists()) {
          final bytes = await file.readAsBytes();
          final extension = imagePath.split('.').last.toLowerCase();
          final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';
          final base64String = base64Encode(bytes);
          return 'data:$mimeType;base64,$base64String';
        }
      }
    } catch (e) {
      debugPrint('Failed to convert image to base64: $e');
    }
    return null;
  }

  Future<void> _generateWebReport(
    ReportData reportData,
    String projectName,
    String format,
  ) async {
    try {
      // Get current project ID from URL or context
      final projectId = 1; // Simplified for now - could be passed as parameter

      final response = await http.post(
        Uri.parse('/api/projects/$projectId/generate-report'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'format': format,
          'projectName': projectName,
          'tagFilter': 'all', // Could be made configurable
        }),
      );

      if (response.statusCode == 200) {
        final filename = format == 'rtf'
            ? '${projectName}_Report.rtf'
            : '${projectName}_Report.html';
        final mimeType = format == 'rtf' ? 'application/rtf' : 'text/html';

        // Trigger download
        downloadFile(response.body, filename, mimeType);
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to generate report: $e');
    }
  }
}
