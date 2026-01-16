import 'package:flutter/material.dart';
import 'package:flutter_to_pdf/flutter_to_pdf.dart';
import 'vulnerability_graphic_generator.dart';
import '../models/report_models.dart';

class ReportGraphicCapturer extends StatelessWidget {
  final int option;
  final List<ReportFinding> findings;
  final ExportDelegate exportDelegate;

  const ReportGraphicCapturer({
    super.key,
    required this.option,
    required this.findings,
    required this.exportDelegate,
  });

  @override
  Widget build(BuildContext context) {
    final data = <VulnerabilityEntry>[];
    for (var finding in findings) {
      data.add(
        VulnerabilityEntry(
          category: finding.category ?? 'Uncategorized',
          subcategory: finding.subcategory ?? 'General',
          severity: finding.cvssSeverity ?? 'UNKNOWN',
          count: 1,
        ),
      );
    }

    return Offstage(
      child: SizedBox(
        width: 600,
        height: 300,
        child: ExportFrame(
          frameId: 'summary_graphic_$option',
          exportDelegate: exportDelegate,
          child: Container(
            width: 600,
            height: 300,
            color: Colors.white,
            padding: const EdgeInsets.all(20),
            child: VulnerabilityGraphicGenerator(
              option: option,
              data: data,
              width: 560,
              height: 260,
            ),
          ),
        ),
      ),
    );
  }
}
