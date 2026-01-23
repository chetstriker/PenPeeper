import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_to_pdf/flutter_to_pdf.dart';
import 'package:http/http.dart' as http;
import 'package:penpeeper/api_database_helper.dart';
import 'package:penpeeper/theme_config.dart';
import 'package:penpeeper/utils/pdf_download.dart';
import 'package:penpeeper/widgets/gradient_button.dart';
import 'package:penpeeper/services/report_service.dart';
import 'package:penpeeper/services/report_generator.dart';
import 'package:penpeeper/services/pdf_report_generator.dart';
import 'package:penpeeper/models/report_models.dart';
import 'package:penpeeper/models/pdf_generation_status.dart';
import 'package:penpeeper/widgets/report_section_editor.dart';
import 'package:penpeeper/widgets/report_graphic_selector.dart';
import 'package:penpeeper/widgets/report_graphic_capturer.dart';
import 'package:penpeeper/constants/report_section_examples.dart';
import 'package:penpeeper/widgets/ai_executive_summary_dialog.dart';
import 'package:penpeeper/widgets/ai_conclusion_dialog.dart';
import 'package:penpeeper/repositories/settings_repository.dart';
import 'package:penpeeper/repositories/report_section_repository.dart';
import 'package:penpeeper/database_helper.dart';
import 'package:penpeeper/models/llm_settings.dart';
import 'package:penpeeper/models/llm_provider.dart';
import 'package:intl/intl.dart';
import 'package:sqflite_common/sqlite_api.dart';

class ReportScreen extends StatefulWidget {
  final int projectId;
  final String projectName;

  const ReportScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final List<String> _selectedTags = [];
  List<String> _availableTags = [];
  bool _isGenerating = false;
  bool _isLoading = true;
  ReportData? _reportData;
  final _reportService = ReportService();
  final _reportGenerator = ReportGenerator();
  final _pdfGenerator = PdfReportGenerator();
  final _scrollController = ScrollController();
  PdfGenerationStatus _pdfStatus = PdfGenerationStatus.idle();
  final _exportDelegate = ExportDelegate();
  final _settingsRepo = SettingsRepository();
  final _reportSectionRepo = ReportSectionRepository();
  bool _hasLlmConfigured = false;
  final _companyNameController = TextEditingController();
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadReportData();
    _checkLlmSettings();
    _loadProjectMetadata();
    _pdfGenerator.statusStream.listen((status) {
      if (mounted) {
        setState(() => _pdfStatus = status);
      }
    });
  }

  @override
  void dispose() {
    _pdfGenerator.dispose();
    _scrollController.dispose();
    _companyNameController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  Future<void> _loadProjectMetadata() async {
    try {
      final companyName = await _reportSectionRepo.getReportSection(widget.projectId, 'company_name');
      final startDate = await _reportSectionRepo.getReportSection(widget.projectId, 'start_date');
      final endDate = await _reportSectionRepo.getReportSection(widget.projectId, 'end_date');
      
      if (mounted) {
        setState(() {
          _companyNameController.text = companyName?.content ?? '';
          _startDateController.text = startDate?.content ?? '';
          _endDateController.text = endDate?.content ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error loading project metadata: $e');
    }
  }

  Future<void> _saveProjectMetadata(String sectionType, String value) async {
    try {
      await _reportSectionRepo.saveReportSectionRaw(widget.projectId, sectionType, value);
    } catch (e) {
      debugPrint('Error saving $sectionType: $e');
    }
  }

  Future<void> _selectDate(TextEditingController controller, String sectionType) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      final formatted = DateFormat('yyyy-MM-dd').format(picked);
      controller.text = formatted;
      await _saveProjectMetadata(sectionType, formatted);
    }
  }

  Future<void> _checkLlmSettings() async {
    try {
      final settingsJson = await _settingsRepo.getSetting('llm_settings', '');
      if (settingsJson.isNotEmpty) {
        final settings = LLMSettings.fromJson(json.decode(settingsJson));
        setState(() {
          _hasLlmConfigured = settings.provider != LLMProvider.none;
        });
      }
    } catch (e) {
      setState(() => _hasLlmConfigured = false);
    }
  }

  void _showAiSummaryDialog() {
    showDialog(
      context: context,
      builder: (context) => AiExecutiveSummaryDialog(projectId: widget.projectId),
    );
  }

  void _showAiConclusionDialog() {
    showDialog(
      context: context,
      builder: (context) => AiConclusionDialog(projectId: widget.projectId),
    );
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);
    try {
      final reportData = await _reportService.getReportData(
        widget.projectId,
        selectedTags: _selectedTags,
      );
      setState(() {
        _reportData = reportData;
        _availableTags = reportData.availableTags;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading report data: $e')),
        );
      }
    }
  }

  Future<void> _generateRTFReport() async {
    if (_reportData == null) return;

    setState(() => _isGenerating = true);
    try {
      // Reload report data to get latest section content
      await _loadReportData();
      if (_reportData == null) return;
      
      await _reportGenerator.generateRTFReport(
        _reportData!,
        widget.projectName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('RTF report generated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating RTF report: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _generateWebReport() async {
    if (_reportData == null) return;

    setState(() => _isGenerating = true);
    try {
      // Reload report data to get latest section content
      await _loadReportData();
      if (_reportData == null) return;
      
      await _reportGenerator.generateHTMLReport(
        _reportData!,
        widget.projectName,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('HTML report generated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating HTML report: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _generatePDFReport() async {
    if (_reportData == null) return;

    setState(() => _isGenerating = true);
    try {
      print('[REPORT_SCREEN] Starting PDF generation');
      await _loadReportData();
      if (_reportData == null) return;
      
      print('[REPORT_SCREEN] Report data loaded');
      print('[REPORT_SCREEN] Summary graphic option: ${_reportData!.summaryGraphicOption}');
      print('[REPORT_SCREEN] kIsWeb: $kIsWeb');
      
      if (kIsWeb) {
        // Web: Call API to generate PDF on server
        print('[REPORT_SCREEN] Generating PDF via API');
        final response = await http.post(
          Uri.parse('${ApiDatabaseHelper.baseUrl}/projects/${widget.projectId}/generate-pdf'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'projectName': widget.projectName,
            'tagFilter': _selectedTags.isNotEmpty ? _selectedTags.first : null,
          }),
        );
        
        print('[REPORT_SCREEN] API response status: ${response.statusCode}');
        print('[REPORT_SCREEN] PDF size: ${response.bodyBytes.length} bytes');
        
        if (response.statusCode == 200) {
          print('[REPORT_SCREEN] Calling downloadPdf...');
          downloadPdf(response.bodyBytes, '${widget.projectName}_Report.pdf');
          print('[REPORT_SCREEN] downloadPdf completed');
        } else {
          throw Exception('Failed to generate PDF: ${response.body}');
        }
      } else {
        // Desktop: Generate locally
        print('[REPORT_SCREEN] Export delegate: $_exportDelegate');
        final fileName = '${widget.projectName}_Report.pdf';
        await _pdfGenerator.generateAndSavePdf(_reportData!, fileName, exportDelegate: _exportDelegate);
      }
      
      if (mounted && _pdfStatus.state == PdfGenerationState.completed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF report generated successfully')),
        );
      }
    } catch (e, stackTrace) {
      print('[REPORT_SCREEN] Error generating PDF: $e');
      print('[REPORT_SCREEN] Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF report: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppTheme.backgroundGradient,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Row(
              children: [
                Container(
                  width: 3,
                  height: 24,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: AppTheme.primaryGradient),
                    borderRadius: const BorderRadius.all(Radius.circular(2)),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Report Generation',
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeLargeTitle,
                    fontWeight: AppTheme.fontWeightSemiBold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      AppTheme.borderRadiusMedium,
                    ),
                    border: Border.all(
                      color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    widget.projectName,
                    style: TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: AppTheme.fontWeightMedium,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Expanded(
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scrollController,
                  child: Column(
                    children: [
                      // Filters and Export side by side
                      IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              flex: 4,
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppTheme.mediumBackground,
                                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                                  border: Border.all(color: AppTheme.borderSecondary),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.filter_list, color: AppTheme.primaryColor, size: AppTheme.iconSizeMedium),
                                        const SizedBox(width: 8),
                                        Text('Report Filters', style: TextStyle(fontSize: AppTheme.fontSizeTitle, fontWeight: AppTheme.fontWeightSemiBold, color: AppTheme.textPrimary)),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: AppTheme.inputBackground,
                                        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                                        border: Border.all(color: AppTheme.borderSecondary),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.label, color: AppTheme.primaryColor, size: AppTheme.iconSizeLarge),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Text('Filter by Tags', style: TextStyle(fontSize: AppTheme.fontSizeBodyLarge, fontWeight: AppTheme.fontWeightSemiBold, color: AppTheme.textPrimary)),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 8),
                                          if (_reportData != null)
                                            Text('${_reportData!.findings.length} findings available', style: TextStyle(fontSize: AppTheme.fontSizeBody, color: AppTheme.textMuted)),
                                          const SizedBox(height: 16),
                                          _isLoading ? const CircularProgressIndicator() : _buildTagMultiSelect(),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 6,
                              child: Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppTheme.mediumBackground,
                                  borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                                  border: Border.all(color: AppTheme.borderSecondary),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.file_download, color: AppTheme.primaryColor, size: AppTheme.iconSizeMedium),
                                        const SizedBox(width: 8),
                                        Text('Export Options', style: TextStyle(fontSize: AppTheme.fontSizeTitle, fontWeight: AppTheme.fontWeightSemiBold, color: AppTheme.textPrimary)),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    _buildExportButton('PDF Report', 'Professional PDF with table of contents', Icons.picture_as_pdf, _generatePDFReport),
                                    // RTF Report button hidden - code kept for future development
                                    // Expanded(child: _buildExportButton('RTF Report', 'Professional RTF document with images', Icons.description, _generateRTFReport)),
                                    if (_pdfStatus.state == PdfGenerationState.generating) ...[
                                      const SizedBox(height: 16),
                                      LinearProgressIndicator(value: _pdfStatus.progress),
                                      const SizedBox(height: 8),
                                      Text(_pdfStatus.message, style: TextStyle(fontSize: AppTheme.fontSizeBody, color: AppTheme.textSecondary)),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.mediumBackground,
                          borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
                          border: Border.all(color: AppTheme.borderSecondary),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.article, color: AppTheme.primaryColor, size: AppTheme.iconSizeMedium),
                                const SizedBox(width: 8),
                                Text('Report Content', style: TextStyle(fontSize: AppTheme.fontSizeTitle, fontWeight: AppTheme.fontWeightSemiBold, color: AppTheme.textPrimary)),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.inputBackground,
                                borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
                                border: Border.all(color: AppTheme.borderSecondary),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Company Name', style: TextStyle(fontSize: AppTheme.fontSizeBodyLarge, fontWeight: AppTheme.fontWeightMedium, color: AppTheme.textPrimary)),
                                  const SizedBox(height: 8),
                                  TextField(
                                    controller: _companyNameController,
                                    style: TextStyle(color: AppTheme.textPrimary),
                                    decoration: InputDecoration(
                                      hintText: 'Enter company name...',
                                      hintStyle: TextStyle(color: AppTheme.textTertiary),
                                      border: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.borderPrimary)),
                                      enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.borderPrimary)),
                                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor)),
                                    ),
                                    onChanged: (value) => _saveProjectMetadata('company_name', value),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('Start Date', style: TextStyle(fontSize: AppTheme.fontSizeBodyLarge, fontWeight: AppTheme.fontWeightMedium, color: AppTheme.textPrimary)),
                                            const SizedBox(height: 8),
                                            TextField(
                                              controller: _startDateController,
                                              readOnly: true,
                                              style: TextStyle(color: AppTheme.textPrimary),
                                              decoration: InputDecoration(
                                                hintText: 'YYYY-MM-DD',
                                                hintStyle: TextStyle(color: AppTheme.textTertiary),
                                                border: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.borderPrimary)),
                                                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.borderPrimary)),
                                                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor)),
                                                suffixIcon: IconButton(
                                                  icon: Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                                                  onPressed: () => _selectDate(_startDateController, 'start_date'),
                                                ),
                                              ),
                                              onTap: () => _selectDate(_startDateController, 'start_date'),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text('End Date', style: TextStyle(fontSize: AppTheme.fontSizeBodyLarge, fontWeight: AppTheme.fontWeightMedium, color: AppTheme.textPrimary)),
                                            const SizedBox(height: 8),
                                            TextField(
                                              controller: _endDateController,
                                              readOnly: true,
                                              style: TextStyle(color: AppTheme.textPrimary),
                                              decoration: InputDecoration(
                                                hintText: 'YYYY-MM-DD',
                                                hintStyle: TextStyle(color: AppTheme.textTertiary),
                                                border: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.borderPrimary)),
                                                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.borderPrimary)),
                                                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryColor)),
                                                suffixIcon: IconButton(
                                                  icon: Icon(Icons.calendar_today, color: AppTheme.primaryColor),
                                                  onPressed: () => _selectDate(_endDateController, 'end_date'),
                                                ),
                                              ),
                                              onTap: () => _selectDate(_endDateController, 'end_date'),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            ReportSectionEditor(projectId: widget.projectId, sectionType: 'report_header', title: 'Report Header', placeholder: 'Report title...', projectName: widget.projectName, exampleContent: 'Security Assessment Findings Report', description: 'The main title/header for your report.'),
                            const SizedBox(height: 16),
                            ReportGraphicSelector(projectId: widget.projectId),
                            if (_reportData != null && _reportData!.summaryGraphicOption != null)
                              ReportGraphicCapturer(
                                option: _reportData!.summaryGraphicOption!,
                                findings: _reportData!.findings,
                                exportDelegate: _exportDelegate,
                              ),
                            const SizedBox(height: 16),
                            ReportSectionEditor(
                              projectId: widget.projectId,
                              sectionType: 'executive_summary',
                              title: 'Executive Summary',
                              placeholder: 'Non-technical summary...',
                              projectName: widget.projectName,
                              exampleContent: ReportSectionExamples.executiveSummary,
                              description: ReportSectionExamples.executiveSummaryDescription,
                              showAiButton: _hasLlmConfigured,
                              onAiButtonPressed: _showAiSummaryDialog,
                            ),
                            const SizedBox(height: 16),
                            ReportSectionEditor(projectId: widget.projectId, sectionType: 'methodology_scope', title: 'Methodology and Scope', placeholder: 'Testing approach...', projectName: widget.projectName, exampleContent: ReportSectionExamples.methodologyScope, description: ReportSectionExamples.methodologyScopeDescription),
                            const SizedBox(height: 16),
                            ReportSectionEditor(projectId: widget.projectId, sectionType: 'risk_rating_model', title: 'Risk Rating Model', placeholder: 'Severity ratings...', projectName: widget.projectName, exampleContent: ReportSectionExamples.riskRatingModel, description: ReportSectionExamples.riskRatingModelDescription),
                            const SizedBox(height: 16),
                            ReportSectionEditor(
                              projectId: widget.projectId,
                              sectionType: 'conclusion',
                              title: 'Conclusion',
                              placeholder: 'Final summary...',
                              projectName: widget.projectName,
                              exampleContent: ReportSectionExamples.conclusion,
                              description: ReportSectionExamples.conclusionDescription,
                              showAiButton: _hasLlmConfigured,
                              onAiButtonPressed: _showAiConclusionDialog,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagMultiSelect() {
    return SizedBox(
      width: double.infinity,
      child: GradientButton(
        label: _selectedTags.isEmpty ? 'Select Tags (Optional)' : '${_selectedTags.length} Tag(s) Selected',
        backgroundConfig: AppTheme.primaryButtonGradient ?? AppTheme.primaryColor,
        onPressed: _showTagSelector,
        textColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 12),
        borderRadius: AppTheme.borderRadiusMedium,
      ),
    );
  }

  void _showTagSelector() {
    String searchQuery = '';
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          final filteredTags = _availableTags
              .where(
                (tag) => tag.toLowerCase().contains(searchQuery.toLowerCase()),
              )
              .toList();

          return AlertDialog(
            title: Text('Select Tags'),
            content: SizedBox(
              width: 300,
              height: 400,
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      hintText: 'Search tags...',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setDialogState(() {
                        searchQuery = value;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_selectedTags.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: _selectedTags.map((tag) => Chip(
                          label: Text(tag, style: TextStyle(fontSize: 12)),
                          deleteIcon: Icon(Icons.close, size: 16),
                          onDeleted: () {
                            setState(() => _selectedTags.remove(tag));
                            setDialogState(() {});
                          },
                          backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                          side: BorderSide(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
                        )).toList(),
                      ),
                    ),
                  Expanded(
                    child: ListView(
                      children: filteredTags.map((tag) {
                        final isSelected = _selectedTags.contains(tag);
                        return CheckboxListTile(
                          title: Text(tag),
                          value: isSelected,
                          onChanged: (selected) {
                            setState(() {
                              if (selected == true) {
                                _selectedTags.add(tag);
                              } else {
                                _selectedTags.remove(tag);
                              }
                            });
                            setDialogState(() {});
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedTags.clear();
                  });
                  Navigator.of(context).pop();
                  _loadReportData();
                },
                child: Text('Clear All'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _loadReportData();
                },
                child: Text('Apply'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildExportButton(
    String title,
    String description,
    IconData icon,
    VoidCallback? onPressed,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.inputBackground,
        borderRadius: BorderRadius.circular(AppTheme.borderRadiusMedium),
        border: Border.all(color: AppTheme.borderSecondary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: AppTheme.primaryColor,
                size: AppTheme.iconSizeLarge,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: AppTheme.fontSizeBodyLarge,
                    fontWeight: AppTheme.fontWeightSemiBold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: AppTheme.fontSizeBody,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: GradientButton(
              label: _isGenerating
                  ? 'Generating...'
                  : (_reportData?.findings.isEmpty != false
                        ? 'No Data'
                        : 'Generate'),
              backgroundConfig:
                  AppTheme.primaryButtonGradient ?? AppTheme.primaryColor,
              onPressed: _isGenerating || _reportData?.findings.isEmpty != false
                  ? null
                  : onPressed,
              textColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              borderRadius: AppTheme.borderRadiusMedium,
            ),
          ),
        ],
      ),
    );
  }
}
