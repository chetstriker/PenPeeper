import 'package:penpeeper/services/export/rtf_export_service.dart';
import 'package:penpeeper/services/export/csv_export_service.dart';

/// Unified service for exporting findings in various formats
class FindingsExportService {
  final RtfExportService _rtfService = RtfExportService();
  final CsvExportService _csvService = CsvExportService();

  /// Gets the RTF export service
  RtfExportService get rtf => _rtfService;

  /// Gets the CSV export service
  CsvExportService get csv => _csvService;
}
