import 'dart:math' as math;
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

class PdfTextHelper {
  static String abbreviateCategory(String category, int maxLength) {
    if (category.length <= maxLength) return category;
    final words = category.split(' ');
    if (words.length > 2) {
      return '${words.take(2).join(' ')}...';
    }
    return '${category.substring(0, math.min(maxLength - 3, category.length))}...';
  }
}

class PdfTextWithShadow {
  static pw.Widget build(String text, pw.TextStyle style) {
    return pw.Stack(
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 1, top: 1),
          child: pw.Text(
            text,
            style: style.copyWith(color: PdfColor.fromInt(0x80000000)),
          ),
        ),
        pw.Text(text, style: style),
      ],
    );
  }
}
