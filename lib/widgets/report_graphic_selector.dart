import 'package:flutter/material.dart';
import 'package:penpeeper/theme_config.dart';
import 'package:penpeeper/widgets/gradient_border_container.dart';
import 'package:penpeeper/widgets/vulnerability_graphic_generator.dart';
import 'package:penpeeper/repositories/report_section_repository.dart';
import 'package:penpeeper/models/report_section.dart';

class ReportGraphicSelector extends StatefulWidget {
  final int projectId;

  const ReportGraphicSelector({super.key, required this.projectId});

  @override
  State<ReportGraphicSelector> createState() => _ReportGraphicSelectorState();
}

class _ReportGraphicSelectorState extends State<ReportGraphicSelector> {
  final _repository = ReportSectionRepository();
  int _selectedOption = 1;
  bool _isLoading = true;

  final List<Map<String, String>> _graphicOptions = [
    {
      'value': '1',
      'label': 'Radial Chart with Legend',
      'description': 'Donut chart with severity distribution',
    },
    {
      'value': '2',
      'label': 'Stacked Category Bars',
      'description': 'Horizontal bars showing category breakdown',
    },
    {
      'value': '4',
      'label': 'Category × Severity Matrix',
      'description': 'Grid layout showing all intersections',
    },
    {
      'value': '5',
      'label': 'Compact Information Cards',
      'description': 'Dashboard-style two-card layout',
    },
    {
      'value': '6',
      'label': 'Severity-First Horizontal Flow',
      'description': 'Vertical columns per severity level',
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadSelectedOption();
  }

  Future<void> _loadSelectedOption() async {
    print(
      '[GRAPHIC_SELECTOR] Loading graphic option for project ${widget.projectId}',
    );
    final section = await _repository.getReportSection(
      widget.projectId,
      'summary_graphic',
    );
    if (section != null) {
      print('[GRAPHIC_SELECTOR] Found saved option: ${section.content}');
      setState(() {
        _selectedOption = int.tryParse(section.content) ?? 1;
        _isLoading = false;
      });
    } else {
      print('[GRAPHIC_SELECTOR] No saved option found, creating default record with value: 1');
      // Automatically create a record with the default value (1)
      await _saveSelectedOption(1);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSelectedOption(int option) async {
    print(
      '[GRAPHIC_SELECTOR] Saving graphic option: $option for project ${widget.projectId}',
    );
    final now = DateTime.now();
    final section = ReportSection(
      projectId: widget.projectId,
      sectionType: 'summary_graphic',
      content: option.toString(),
      createdAt: now,
      updatedAt: now,
    );
    await _repository.saveReportSection(section);
    print('[GRAPHIC_SELECTOR] Graphic option saved successfully');
  }

  void _showPreviewModal() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          height: MediaQuery.of(context).size.height * 0.9,
          decoration: BoxDecoration(
            color: AppTheme.mediumBackground,
            borderRadius: BorderRadius.circular(AppTheme.borderRadiusLarge),
            border: Border.all(color: AppTheme.borderSecondary),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(AppTheme.borderRadiusLarge),
                    topRight: Radius.circular(AppTheme.borderRadiusLarge),
                  ),
                  border: Border(
                    bottom: BorderSide(color: AppTheme.borderSecondary),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.preview,
                      color: AppTheme.primaryColor,
                      size: AppTheme.iconSizeMedium,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Summary Graphic Preview',
                      style: TextStyle(
                        fontSize: AppTheme.fontSizeTitle,
                        fontWeight: AppTheme.fontWeightSemiBold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: Icon(Icons.close, color: AppTheme.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _graphicOptions.length,
                  itemBuilder: (context, index) {
                    final option = _graphicOptions[index];
                    final optionValue = int.parse(option['value']!);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: AppTheme.inputBackground,
                        borderRadius: BorderRadius.circular(
                          AppTheme.borderRadiusMedium,
                        ),
                        border: Border.all(
                          color: _selectedOption == optionValue
                              ? AppTheme.primaryColor
                              : AppTheme.borderSecondary,
                          width: _selectedOption == optionValue ? 2 : 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(
                                      alpha: 0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      AppTheme.borderRadiusSmall,
                                    ),
                                  ),
                                  child: Text(
                                    'Option ${option['value']}',
                                    style: TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontWeight: AppTheme.fontWeightSemiBold,
                                      fontSize: AppTheme.fontSizeBody,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        option['label']!,
                                        style: TextStyle(
                                          fontSize: AppTheme.fontSizeBodyLarge,
                                          fontWeight:
                                              AppTheme.fontWeightSemiBold,
                                          color: AppTheme.textPrimary,
                                        ),
                                      ),
                                      Text(
                                        option['description']!,
                                        style: TextStyle(
                                          fontSize: AppTheme.fontSizeBody,
                                          color: AppTheme.textMuted,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: 400,
                            padding: const EdgeInsets.all(16),
                            child: VulnerabilityGraphicGenerator(
                              option: optionValue,
                              data: _getSampleData(),
                              width: 800,
                              height: 400,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<VulnerabilityEntry> _getSampleData() {
    return [
      VulnerabilityEntry(
        category: 'Authentication & Authorization',
        subcategory: 'Broken Authentication',
        severity: 'CRITICAL',
        count: 7,
      ),
      VulnerabilityEntry(
        category: 'Authentication & Authorization',
        subcategory: 'Broken Authentication',
        severity: 'HIGH',
        count: 1,
      ),
      VulnerabilityEntry(
        category: 'Authentication & Authorization',
        subcategory: 'Privilege Escalation',
        severity: 'HIGH',
        count: 1,
      ),
      VulnerabilityEntry(
        category: 'Memory Safety',
        subcategory: 'Buffer Overflow',
        severity: 'CRITICAL',
        count: 1,
      ),
      VulnerabilityEntry(
        category: 'Memory Safety',
        subcategory: 'Buffer Overflow',
        severity: 'HIGH',
        count: 2,
      ),
      VulnerabilityEntry(
        category: 'Memory Safety',
        subcategory: 'Stack Overflow',
        severity: 'CRITICAL',
        count: 6,
      ),
      VulnerabilityEntry(
        category: 'Information Disclosure',
        subcategory: 'Exposure of Sensitive Information',
        severity: 'MEDIUM',
        count: 1,
      ),
      VulnerabilityEntry(
        category: 'Software Maintenance',
        subcategory: 'Lack of Security Updates',
        severity: 'CRITICAL',
        count: 1,
      ),
      VulnerabilityEntry(
        category: 'Software Maintenance',
        subcategory: 'Lack of Security Updates',
        severity: 'HIGH',
        count: 2,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Summary Graphic',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: 'View examples of all graphic options',
              child: IconButton(
                icon: Icon(
                  Icons.help_outline,
                  size: 20,
                  color: AppTheme.primaryColor,
                ),
                onPressed: _showPreviewModal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GradientBorderContainer(
          borderConfig:
              AppTheme.borderPrimaryGradient ?? AppTheme.borderPrimary,
          borderRadius: 8,
          borderWidth: 1,
          backgroundColor: AppTheme.inputBackground,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: DropdownButtonFormField<int>(
              initialValue: _selectedOption,
              decoration: InputDecoration(
                labelText: 'Select Graphic Style',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    AppTheme.borderRadiusMedium,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
              items: _graphicOptions.map((option) {
                final value = int.parse(option['value']!);
                return DropdownMenuItem<int>(
                  value: value,
                  child: Text(
                    '${option['label']} - ${option['description']}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedOption = value);
                  _saveSelectedOption(value);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}
