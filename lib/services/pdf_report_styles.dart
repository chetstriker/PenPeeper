import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class PdfReportStyles {
  // Colors
  static const PdfColor primaryColor = PdfColor.fromInt(0xFF2196F3);
  static const PdfColor headerColor = PdfColor.fromInt(0xFF1976D2);
  static const PdfColor textColor = PdfColor.fromInt(0xFF212121);
  static const PdfColor lightGray = PdfColor.fromInt(0xFFE0E0E0);
  static const PdfColor darkGray = PdfColor.fromInt(0xFF757575);
  
  // Severity colors
  static const PdfColor criticalColor = PdfColor.fromInt(0xFFD32F2F);
  static const PdfColor highColor = PdfColor.fromInt(0xFFFF6F00);
  static const PdfColor mediumColor = PdfColor.fromInt(0xFFFBC02D);
  static const PdfColor lowColor = PdfColor.fromInt(0xFF388E3C);
  static const PdfColor infoColor = PdfColor.fromInt(0xFF1976D2);

  // Font sizes
  static const double titleSize = 24.0;
  static const double heading1Size = 18.0;
  static const double heading2Size = 14.0;
  static const double heading3Size = 12.0;
  static const double bodySize = 10.0;
  static const double smallSize = 8.0;

  // Spacing
  static const double sectionSpacing = 20.0;
  static const double paragraphSpacing = 10.0;
  static const double lineSpacing = 5.0;

  // Text styles
  static pw.TextStyle get titleStyle => pw.TextStyle(
        fontSize: titleSize,
        fontWeight: pw.FontWeight.bold,
        color: headerColor,
      );

  static pw.TextStyle get heading1Style => pw.TextStyle(
        fontSize: heading1Size,
        fontWeight: pw.FontWeight.bold,
        color: textColor,
      );

  static pw.TextStyle get heading2Style => pw.TextStyle(
        fontSize: heading2Size,
        fontWeight: pw.FontWeight.bold,
        color: textColor,
      );

  static pw.TextStyle get heading3Style => pw.TextStyle(
        fontSize: heading3Size,
        fontWeight: pw.FontWeight.bold,
        color: textColor,
      );

  static pw.TextStyle get bodyStyle => const pw.TextStyle(
        fontSize: bodySize,
        color: textColor,
      );

  static pw.TextStyle get smallStyle => const pw.TextStyle(
        fontSize: smallSize,
        color: darkGray,
      );

  static pw.TextStyle get boldStyle => pw.TextStyle(
        fontSize: bodySize,
        fontWeight: pw.FontWeight.bold,
        color: textColor,
      );

  static PdfColor getSeverityColor(String? severity) {
    if (severity == null) return infoColor;
    switch (severity.toUpperCase()) {
      case 'CRITICAL':
        return criticalColor;
      case 'HIGH':
        return highColor;
      case 'MEDIUM':
        return mediumColor;
      case 'LOW':
        return lowColor;
      default:
        return infoColor;
    }
  }
}
