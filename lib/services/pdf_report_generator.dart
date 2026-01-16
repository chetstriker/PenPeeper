import 'dart:async';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../models/report_models.dart';
import '../models/pdf_generation_status.dart';
import 'pdf_report_builder.dart';

class PdfReportGenerator {
  final StreamController<PdfGenerationStatus> _statusController =
      StreamController<PdfGenerationStatus>.broadcast();
  late ReportData reportData;

  Stream<PdfGenerationStatus> get statusStream => _statusController.stream;

  void _updateStatus(PdfGenerationStatus status) {
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  /// Add a report section and check if it's problematic
  void _addReportSection(
    pw.Document doc,
    String sectionName,
    String? sectionContent,
    List<pw.Widget> widgets,
    pw.Widget Function(pw.Context) footerBuilder,
  ) {
    try {
      doc.addPage(
        pw.MultiPage(build: (context) => widgets, footer: footerBuilder),
      );
    } catch (e) {
      // Silent failure
    }
  }

  /// Add findings with tracking - only log problems
  void _addFindingsWithSmartTracking(
    pw.Document doc,
    List<pw.Widget> allWidgets,
    Map<int, Map<String, dynamic>> widgetToFindingMap,
    pw.Widget Function(pw.Context) footerBuilder,
  ) {
    if (allWidgets.isEmpty) return;

    Map<int, List<int>> findingToWidgetIndices = {};
    for (int i = 0; i < allWidgets.length; i++) {
      if (widgetToFindingMap.containsKey(i)) {
        int findingId = widgetToFindingMap[i]!['id'];
        if (!findingToWidgetIndices.containsKey(findingId)) {
          findingToWidgetIndices[findingId] = [];
        }
        findingToWidgetIndices[findingId]!.add(i);
      }
    }

    for (var entry in findingToWidgetIndices.entries) {
      int findingId = entry.key;
      List<int> widgetIndices = entry.value;
      var findingInfo = widgetToFindingMap[widgetIndices.first]!;
      String deviceName = findingInfo['device'] ?? 'Unknown';
      List<pw.Widget> findingWidgets = widgetIndices
          .map((i) => allWidgets[i])
          .toList();

      try {
        doc.addPage(
          pw.MultiPage(
            build: (context) => findingWidgets,
            footer: footerBuilder,
          ),
        );
      } on pw.TooManyPagesException {
        _addFindingInChunks(
          doc,
          findingWidgets,
          findingId,
          deviceName,
          footerBuilder,
        );
      } catch (e) {
        // Silent failure
      }
    }
  }

  /// Split problematic finding into chunks
  void _addFindingInChunks(
    pw.Document doc,
    List<pw.Widget> widgets,
    int findingId,
    String deviceName,
    pw.Widget Function(pw.Context) footerBuilder,
  ) {
    int chunkSize = widgets.length ~/ 2;
    int startIndex = 0;

    while (startIndex < widgets.length && chunkSize >= 1) {
      int endIndex = (startIndex + chunkSize).clamp(0, widgets.length);
      var chunk = widgets.sublist(startIndex, endIndex);

      try {
        doc.addPage(
          pw.MultiPage(build: (context) => chunk, footer: footerBuilder),
        );
        startIndex = endIndex;
      } catch (e) {
        if (chunk.length > 1) {
          chunkSize = chunk.length ~/ 2;
        } else {
          startIndex = endIndex;
        }
      }
    }
  }

  Future<pw.Document> generatePdfDocument(
    ReportData data, {
    dynamic exportDelegate,
  }) async {
    try {
      reportData = data;
      _updateStatus(PdfGenerationStatus.preparing());

      print('[PDF_GENERATOR] Starting PDF generation');
      print(
        '[PDF_GENERATOR] Summary graphic option: ${data.summaryGraphicOption}',
      );
      print(
        '[PDF_GENERATOR] Export delegate provided: ${exportDelegate != null}',
      );

      _updateStatus(PdfGenerationStatus.generating('Building content', 0.3));
      final builder = PdfReportBuilder(
        data,
        data.projectName ?? 'project',
        exportDelegate: exportDelegate,
      );
      print(
        '[PDF_GENERATOR] Builder created with exportDelegate: ${exportDelegate != null}',
      );

      final pageCapture = <String, int>{};
      final doc = pw.Document(pageMode: PdfPageMode.outlines, compress: true);

      // Cover page
      print('[PDF_GENERATOR] Building cover page (first pass)');
      final coverPage = await builder.buildCoverPage();
      print('[PDF_GENERATOR] Cover page built successfully');
      doc.addPage(
        pw.Page(
          build: (context) => pw.Column(
            children: [
              pw.Expanded(child: coverPage),
              builder.buildFooter(context),
            ],
          ),
        ),
      );

      // TOC placeholder
      doc.addPage(
        pw.Page(
          build: (context) => pw.Column(
            children: [
              pw.Expanded(child: builder.buildTocPlaceholder()),
              builder.buildFooter(context),
            ],
          ),
        ),
      );

      _updateStatus(PdfGenerationStatus.generating('Generating sections', 0.6));

      // Executive Summary
      final execSummary = await builder.buildExecutiveSummary();
      if (execSummary.isNotEmpty) {
        final content = [
          pw.Builder(
            builder: (context) {
              pageCapture['Executive Summary'] = context.pageNumber;
              return pw.SizedBox.shrink();
            },
          ),
          ...execSummary,
        ];
        _addReportSection(
          doc,
          'Executive Summary',
          reportData.executiveSummary,
          content,
          (context) => builder.buildFooter(context),
        );
      }

      // Methodology & Scope
      final methodology = await builder.buildMethodologyScope();
      if (methodology.isNotEmpty) {
        final content = [
          pw.Builder(
            builder: (context) {
              pageCapture['Methodology & Scope'] = context.pageNumber;
              return pw.SizedBox.shrink();
            },
          ),
          ...methodology,
        ];
        _addReportSection(
          doc,
          'Methodology & Scope',
          reportData.methodologyScope,
          content,
          (context) => builder.buildFooter(context),
        );
      }

      // Findings - Detailed tracking
      final findingsDataAndMap = await builder.buildFindingsWithCaptureAndMap(
        pageCapture,
      );
      final findingsData = findingsDataAndMap['widgets'] as List<pw.Widget>;
      final widgetToFindingMap =
          findingsDataAndMap['widgetToFindingMap']
              as Map<int, Map<String, dynamic>>;

      if (findingsData.isNotEmpty) {
        final markerWidget = pw.Builder(
          builder: (context) {
            pageCapture['Findings'] = context.pageNumber;
            return pw.SizedBox.shrink();
          },
        );

        final allFindingsWidgets = [markerWidget, ...findingsData];

        try {
          doc.addPage(
            pw.MultiPage(
              build: (context) => allFindingsWidgets,
              footer: (context) => builder.buildFooter(context),
            ),
          );
        } on pw.TooManyPagesException {
          _addFindingsWithSmartTracking(
            doc,
            allFindingsWidgets,
            widgetToFindingMap,
            (context) => builder.buildFooter(context),
          );
        }
      }

      // Risk Rating Model
      final riskRating = await builder.buildRiskRatingModel();
      if (riskRating.isNotEmpty) {
        final content = [
          pw.Builder(
            builder: (context) {
              pageCapture['Risk Rating Model'] = context.pageNumber;
              return pw.SizedBox.shrink();
            },
          ),
          ...riskRating,
        ];
        _addReportSection(
          doc,
          'Risk Rating Model',
          reportData.riskRatingModel,
          content,
          (context) => builder.buildFooter(context),
        );
      }

      // Conclusion
      final conclusion = await builder.buildConclusion();
      if (conclusion.isNotEmpty) {
        final content = [
          pw.Builder(
            builder: (context) {
              pageCapture['Conclusion'] = context.pageNumber;
              return pw.SizedBox.shrink();
            },
          ),
          ...conclusion,
        ];
        _addReportSection(
          doc,
          'Conclusion',
          reportData.conclusion,
          content,
          (context) => builder.buildFooter(context),
        );
      }

      await doc.save();

      // FINAL PASS
      _updateStatus(PdfGenerationStatus.generating('Finalizing', 0.9));

      final finalBuilder = PdfReportBuilder(
        data,
        data.projectName ?? 'project',
        tocPages: pageCapture,
        exportDelegate: exportDelegate,
      );
      print(
        '[PDF_GENERATOR] Final builder created with exportDelegate: ${exportDelegate != null}',
      );
      final finalDoc = pw.Document(
        pageMode: PdfPageMode.outlines,
        compress: true,
      );

      // Cover
      print('[PDF_GENERATOR] Building cover page (final pass)');
      final finalCoverPage = await finalBuilder.buildCoverPage();
      print('[PDF_GENERATOR] Final cover page built successfully');
      finalDoc.addPage(
        pw.Page(
          build: (context) => pw.Column(
            children: [
              pw.Expanded(child: finalCoverPage),
              finalBuilder.buildFooter(context),
            ],
          ),
        ),
      );

      // TOC
      finalDoc.addPage(
        pw.Page(
          build: (context) => pw.Column(
            children: [
              pw.Expanded(child: finalBuilder.buildTableOfContents()),
              finalBuilder.buildFooter(context),
            ],
          ),
        ),
      );

      // Executive Summary
      final execSummary2 = await finalBuilder.buildExecutiveSummary();
      if (execSummary2.isNotEmpty) {
        finalDoc.addPage(
          pw.MultiPage(
            build: (context) => execSummary2,
            footer: (context) => finalBuilder.buildFooter(context),
          ),
        );
      }

      // Methodology
      final methodology2 = await finalBuilder.buildMethodologyScope();
      if (methodology2.isNotEmpty) {
        finalDoc.addPage(
          pw.MultiPage(
            build: (context) => methodology2,
            footer: (context) => finalBuilder.buildFooter(context),
          ),
        );
      }

      // Findings
      final findings2 = await finalBuilder.buildFindings();
      if (findings2.isNotEmpty) {
        try {
          finalDoc.addPage(
            pw.MultiPage(
              build: (context) => findings2,
              footer: (context) => finalBuilder.buildFooter(context),
            ),
          );
        } on pw.TooManyPagesException {
          // Split into chunks if too large
          int chunkSize = findings2.length ~/ 2;
          for (int i = 0; i < findings2.length; i += chunkSize) {
            final chunk = findings2.sublist(
              i,
              (i + chunkSize).clamp(0, findings2.length),
            );
            try {
              finalDoc.addPage(
                pw.MultiPage(
                  build: (context) => chunk,
                  footer: (context) => finalBuilder.buildFooter(context),
                ),
              );
            } catch (e) {
              // Skip problematic chunk
            }
          }
        }
      }

      // Risk Rating
      final riskRating2 = await finalBuilder.buildRiskRatingModel();
      if (riskRating2.isNotEmpty) {
        finalDoc.addPage(
          pw.MultiPage(
            build: (context) => riskRating2,
            footer: (context) => finalBuilder.buildFooter(context),
          ),
        );
      }

      // Conclusion
      final conclusion2 = await finalBuilder.buildConclusion();
      if (conclusion2.isNotEmpty) {
        finalDoc.addPage(
          pw.MultiPage(
            build: (context) => conclusion2,
            footer: (context) => finalBuilder.buildFooter(context),
          ),
        );
      }

      return finalDoc;
    } catch (e) {
      _updateStatus(PdfGenerationStatus.error(e.toString()));
      rethrow;
    }
  }

  Future<String> generateAndSavePdf(
    ReportData reportData,
    String filePath, {
    dynamic exportDelegate,
  }) async {
    try {
      final pdf = await generatePdfDocument(
        reportData,
        exportDelegate: exportDelegate,
      );

      _updateStatus(PdfGenerationStatus.saving());

      await Printing.sharePdf(bytes: await pdf.save(), filename: filePath);

      _updateStatus(PdfGenerationStatus.completed(filePath));
      return filePath;
    } catch (e) {
      _updateStatus(PdfGenerationStatus.error(e.toString()));
      rethrow;
    }
  }

  void dispose() {
    _statusController.close();
  }
}
