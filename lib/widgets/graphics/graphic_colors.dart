import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';

class SeverityColors {
  static const Color critical = Color(0xFFDC2626);
  static const Color high = Color(0xFFEA580C);
  static const Color medium = Color(0xFFF59E0B);
  static const Color low = Color(0xFF10B981);
  static const Color info = Color(0xFF3B82F6);

  static Color getColor(String severity) {
    switch (severity.toUpperCase()) {
      case 'CRITICAL': return critical;
      case 'HIGH': return high;
      case 'MEDIUM': return medium;
      case 'LOW': return low;
      case 'INFO': return info;
      default: return Colors.grey;
    }
  }

  static List<String> get severityOrder => ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW', 'INFO'];
}

class PdfSeverityColors {
  static const PdfColor critical = PdfColor.fromInt(0xFFDC2626);
  static const PdfColor high = PdfColor.fromInt(0xFFEA580C);
  static const PdfColor medium = PdfColor.fromInt(0xFFF59E0B);
  static const PdfColor low = PdfColor.fromInt(0xFF10B981);
  static const PdfColor info = PdfColor.fromInt(0xFF3B82F6);

  static PdfColor getColor(String severity) {
    switch (severity.toUpperCase()) {
      case 'CRITICAL': return critical;
      case 'HIGH': return high;
      case 'MEDIUM': return medium;
      case 'LOW': return low;
      case 'INFO': return info;
      default: return PdfColors.grey;
    }
  }

  static List<String> get severityOrder => ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW', 'INFO'];
}
