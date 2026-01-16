import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:penpeeper/repositories/vulnerability_repository.dart';
import 'package:penpeeper/theme_config.dart';
import 'package:penpeeper/widgets/gradient_border_container.dart';

class VulnTaxonomyModal extends StatefulWidget {
  final int projectId;
  final int deviceId;
  final int findingId;
  final Map<String, dynamic>? existingClassification;
  final VoidCallback onSubmitted;

  const VulnTaxonomyModal({
    super.key,
    required this.projectId,
    required this.deviceId,
    required this.findingId,
    this.existingClassification,
    required this.onSubmitted,
  });

  @override
  State<VulnTaxonomyModal> createState() => _VulnTaxonomyModalState();
}

class _VulnTaxonomyModalState extends State<VulnTaxonomyModal> {
  final _vulnerabilityRepo = VulnerabilityRepository();
  List<Map<String, dynamic>> _taxonomyData = [];
  String? _selectedCategory;
  String? _selectedSubcategory;
  Map<String, dynamic>? _selectedSubcategoryData;
  String _selectedScope = 'NETWORK';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTaxonomyData();
    if (widget.existingClassification != null) {
      _selectedCategory = widget.existingClassification!['category'];
      _selectedSubcategory = widget.existingClassification!['subcategory'];
      _selectedScope = widget.existingClassification!['scope'] ?? 'NETWORK';
    }
  }

  Future<void> _loadTaxonomyData() async {
    try {
      final jsonString = await rootBundle.loadString('assets/vulnerability_taxonomy_full.json');
      final List<dynamic> data = json.decode(jsonString);
      setState(() {
        _taxonomyData = data.cast<Map<String, dynamic>>();
        _isLoading = false;
        if (_selectedSubcategory != null) {
          _selectedSubcategoryData = _subcategories.firstWhere(
            (item) => item['Subcategory'] == _selectedSubcategory,
            orElse: () => {},
          );
        }
      });
    } catch (e) {
      debugPrint('Error loading taxonomy data: $e');
      setState(() => _isLoading = false);
    }
  }

  List<String> get _categories {
    return _taxonomyData.map((item) => item['Category'] as String).toList();
  }

  List<Map<String, dynamic>> get _subcategories {
    if (_selectedCategory == null) return [];
    final category = _taxonomyData.firstWhere(
      (item) => item['Category'] == _selectedCategory,
      orElse: () => {},
    );
    if (category.isEmpty) return [];
    return (category['Subcategories'] as List).cast<Map<String, dynamic>>();
  }

  void _onCategoryChanged(String? value) {
    setState(() {
      _selectedCategory = value;
      _selectedSubcategory = null;
      _selectedSubcategoryData = null;
    });
  }

  void _onSubcategoryChanged(String? value) {
    setState(() {
      _selectedSubcategory = value;
      if (value != null) {
        _selectedSubcategoryData = _subcategories.firstWhere(
          (item) => item['Subcategory'] == value,
          orElse: () => {},
        );
      } else {
        _selectedSubcategoryData = null;
      }
    });
  }

  Future<void> _submitClassification() async {
    if (_selectedCategory == null || _selectedSubcategory == null || _selectedSubcategoryData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select both category and subcategory')),
      );
      return;
    }

    try {
      if (widget.existingClassification != null) {
        await _vulnerabilityRepo.deleteVulnerabilityClassification(widget.existingClassification!['id']);
      }
      
      await _vulnerabilityRepo.insertVulnerabilityClassification(
        projectId: widget.projectId,
        deviceId: widget.deviceId,
        findingId: widget.findingId,
        category: _selectedCategory!,
        subcategory: _selectedSubcategory!,
        description: _selectedSubcategoryData!['Description'] ?? '',
        mappedOwasp: _selectedSubcategoryData!['Mapped_OWASP'] ?? '',
        mappedCwe: _selectedSubcategoryData!['Mapped_CWE'] ?? '',
        severityGuideline: _selectedSubcategoryData!['Severity_Guideline'] ?? '',
        scope: _selectedScope,
      );

      if (mounted) {
        widget.onSubmitted();
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingClassification != null 
              ? 'Vulnerability classification updated' 
              : 'Vulnerability classification added to report'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  // Title
                  Center(
                    child: Column(
                      children: [
                        FractionallySizedBox(
                          widthFactor: 0.8,
                          child: Container(
                            height: 7,
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        Text(
                          'Classify Vulnerability',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Category Dropdown
                  Text(
                    'Category',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GradientBorderContainer(
                    borderConfig: AppTheme.borderPrimaryGradient ?? AppTheme.borderPrimary,
                    borderRadius: 8,
                    borderWidth: 1,
                    backgroundColor: AppTheme.surfaceColor,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCategory,
                        hint: Text('Select Category', style: TextStyle(color: AppTheme.textSecondary)),
                        isExpanded: true,
                        dropdownColor: AppTheme.surfaceColor,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        items: _categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Text(category, style: TextStyle(color: AppTheme.textPrimary)),
                          );
                        }).toList(),
                        onChanged: _onCategoryChanged,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Subcategory Dropdown
                  Text(
                    'Subcategory',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GradientBorderContainer(
                    borderConfig: AppTheme.borderPrimaryGradient ?? AppTheme.borderPrimary,
                    borderRadius: 8,
                    borderWidth: 1,
                    backgroundColor: AppTheme.surfaceColor,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedSubcategory,
                        hint: Text(
                          _selectedCategory == null
                              ? 'Select a category first'
                              : 'Select Subcategory',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                        isExpanded: true,
                        dropdownColor: AppTheme.surfaceColor,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        items: _subcategories.map((subcategory) {
                          return DropdownMenuItem(
                            value: subcategory['Subcategory'] as String,
                            child: Text(
                              subcategory['Subcategory'] as String,
                              style: TextStyle(color: AppTheme.textPrimary),
                            ),
                          );
                        }).toList(),
                        onChanged: _selectedCategory == null ? null : _onSubcategoryChanged,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description (visible when subcategory selected)
                  if (_selectedSubcategoryData != null) ...[
                    GradientBorderContainer(
                      borderConfig: AppTheme.borderPrimaryGradient ?? AppTheme.borderPrimary,
                      borderRadius: 8,
                      borderWidth: 1,
                      backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.1),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: AppTheme.primaryColor, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Description',
                                  style: TextStyle(
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _selectedSubcategoryData!['Description'] ?? '',
                              style: TextStyle(color: AppTheme.textPrimary, fontSize: 13),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                _buildInfoChip('OWASP', _selectedSubcategoryData!['Mapped_OWASP'] ?? ''),
                                _buildInfoChip('CWE', _selectedSubcategoryData!['Mapped_CWE'] ?? ''),
                                _buildInfoChip('Severity', _selectedSubcategoryData!['Severity_Guideline'] ?? ''),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Scope Radio Buttons
                  Text(
                    'Scope',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Tooltip(
                              message: '(Remote) - An attacker can exploit the weakness over the network (often the Internet) without prior access to the target machine; this is the easiest-to-reach vector.',
                              child: RadioListTile<String>(
                                title: Text('NETWORK', style: TextStyle(color: AppTheme.textPrimary)),
                                value: 'NETWORK',
                                groupValue: _selectedScope,
                                activeColor: AppTheme.primaryColor,
                                onChanged: (value) => setState(() => _selectedScope = value!),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Tooltip(
                              message: '(Same LAN, Wi-Fi, or ISP block) - The attacker must be on the same local or shared network — closer than “Network” but not physically at the device.',
                              child: RadioListTile<String>(
                                title: Text('ADJACENT', style: TextStyle(color: AppTheme.textPrimary)),
                                value: 'ADJACENT',
                                groupValue: _selectedScope,
                                activeColor: AppTheme.primaryColor,
                                onChanged: (value) => setState(() => _selectedScope = value!),
                              ),
                            ),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: Tooltip(
                              message: '(Authenticated / Local Access) — The attacker needs local logon access to an account on the machine (or must run code on it) to exploit the weakness.',
                              child: RadioListTile<String>(
                                title: Text('LOCAL', style: TextStyle(color: AppTheme.textPrimary)),
                                value: 'LOCAL',
                                groupValue: _selectedScope,
                                activeColor: AppTheme.primaryColor,
                                onChanged: (value) => setState(() => _selectedScope = value!),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Tooltip(
                              message: '(Physically There) No log in account, but have physical access to the hardware itself (touching it, stealing it, plugging in media) to take advantage of the weakness.',
                              child: RadioListTile<String>(
                                title: Text('PHYSICAL', style: TextStyle(color: AppTheme.textPrimary)),
                                value: 'PHYSICAL',
                                groupValue: _selectedScope,
                                activeColor: AppTheme.primaryColor,
                                onChanged: (value) => setState(() => _selectedScope = value!),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Action Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _submitClassification,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: const Text('Submit to Report'),
                      ),
                    ],
                  ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
