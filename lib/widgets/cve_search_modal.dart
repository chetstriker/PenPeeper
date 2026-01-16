import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:penpeeper/services/nvd_api_service.dart';
import 'package:penpeeper/theme_config.dart';
import 'package:penpeeper/widgets/gradient_border_container.dart';

class CveSearchModal extends StatefulWidget {
  final int deviceId;
  final int projectId;

  const CveSearchModal({
    super.key,
    required this.deviceId,
    required this.projectId,
  });

  @override
  State<CveSearchModal> createState() => _CveSearchModalState();
}

class _CveSearchModalState extends State<CveSearchModal> {
  final _cveController = TextEditingController();
  final _nvdService = NvdApiService();
  String _confidenceLevel = 'Most Likely';
  bool _isLoading = false;
  Map<String, dynamic>? _cveData;
  String? _errorMessage;

  @override
  void dispose() {
    _cveController.dispose();
    super.dispose();
  }

  Future<void> _searchCve() async {
    final cveId = _cveController.text.trim();
    if (cveId.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a CVE ID';
        _cveData = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _cveData = null;
    });

    debugPrint('Searching for CVE: $cveId');
    final data = await _nvdService.fetchCveData(cveId);
    debugPrint('CVE search result: $data');

    setState(() {
      _isLoading = false;
      if (data != null) {
        _cveData = data;
        _cveData!['cveId'] = cveId;
      } else {
        _errorMessage = 'CVE not found or network error.';
      }
    });
  }

  Color _getCvssColor(double score) {
    if (score >= 9.0) return Colors.red;
    if (score >= 7.0) return Colors.orange;
    if (score >= 4.0) return Colors.yellow;
    return Colors.green;
  }

  String _getCvssSeverity(double score) {
    if (score >= 9.0) return 'Critical';
    if (score >= 7.0) return 'High';
    if (score >= 4.0) return 'Medium';
    return 'Low';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surfaceColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.security, color: AppTheme.primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Search CVE',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // CVE ID Input
            TextField(
              controller: _cveController,
              inputFormatters: [UpperCaseTextFormatter()],
              decoration: InputDecoration(
                labelText: 'CVE ID',
                hintText: 'e.g., CVE-2019-1010218',
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.borderSecondary),
                ),
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.borderSecondary),
                ),
              ),
              onSubmitted: (_) => _searchCve(),
            ),
            const SizedBox(height: 16),

            // Confidence Level
            DropdownButtonFormField<String>(
              initialValue: _confidenceLevel,
              decoration: InputDecoration(
                labelText: 'Confidence Level',
                border: OutlineInputBorder(
                  borderSide: BorderSide(color: AppTheme.borderSecondary),
                ),
              ),
              items: const [
                DropdownMenuItem(value: 'Validated', child: Text('Validated')),
                DropdownMenuItem(value: 'Most Likely', child: Text('Most Likely')),
                DropdownMenuItem(value: 'Unsure', child: Text('Unsure')),
              ],
              onChanged: (value) => setState(() => _confidenceLevel = value!),
            ),
            const SizedBox(height: 16),

            // Search Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _searchCve,
                icon: Icon(_isLoading ? Icons.hourglass_empty : Icons.search),
                label: Text(_isLoading ? 'Searching...' : 'Search CVE'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Results
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              )
            else if (_cveData != null)
              Flexible(
                child: GradientBorderContainer(
                  borderConfig: AppTheme.borderSecondaryGradient ?? AppTheme.borderSecondary,
                  borderRadius: 8,
                  borderWidth: 1,
                  backgroundColor: AppTheme.cardBackground,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // CVE ID
                        Text(
                          _cveData!['cveId'],
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // CVSS Score
                        Row(
                          children: [
                            Text(
                              'CVSS Score: ',
                              style: TextStyle(color: AppTheme.textSecondary),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _getCvssColor(_cveData!['cvssScore']).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${_cveData!['cvssScore'].toStringAsFixed(1)} - ${_getCvssSeverity(_cveData!['cvssScore'])}',
                                style: TextStyle(
                                  color: _getCvssColor(_cveData!['cvssScore']),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Vulnerability Type
                        Text(
                          'Type: ${_cveData!['vulnerabilityType']}',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 12),

                        // Description
                        Text(
                          'Description:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _cveData!['description'],
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 12),

                        // URL
                        InkWell(
                          onTap: () {
                            // URL will be handled by url_launcher in production
                          },
                          child: Text(
                            _cveData!['url'],
                            style: const TextStyle(
                              color: Colors.blue,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _cveData == null ? null : () {
                    Navigator.pop(context, {
                      'cveId': _cveData!['cveId'],
                      'confidenceLevel': _confidenceLevel,
                      'description': _cveData!['description'],
                      'vulnerabilityType': _cveData!['vulnerabilityType'],
                      'cvssScore': _cveData!['cvssScore'],
                      'url': _cveData!['url'],
                      'cvssVersion': _cveData!['cvssVersion'],
                      'attackVector': _cveData!['attackVector'],
                      'attackComplexity': _cveData!['attackComplexity'],
                      'privilegesRequired': _cveData!['privilegesRequired'],
                      'userInteraction': _cveData!['userInteraction'],
                      'scope': _cveData!['scope'],
                      'confidentialityImpact': _cveData!['confidentialityImpact'],
                      'integrityImpact': _cveData!['integrityImpact'],
                      'availabilityImpact': _cveData!['availabilityImpact'],
                      'cvssSeverity': _cveData!['cvssSeverity']?.toString().toUpperCase(),
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Accept'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}


class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
