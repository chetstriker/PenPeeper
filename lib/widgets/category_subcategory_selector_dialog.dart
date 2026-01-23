import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:penpeeper/theme_config.dart';

class CategorySubcategorySelectorDialog extends StatefulWidget {
  const CategorySubcategorySelectorDialog({super.key});

  @override
  State<CategorySubcategorySelectorDialog> createState() => _CategorySubcategorySelectorDialogState();
}

class _CategorySubcategorySelectorDialogState extends State<CategorySubcategorySelectorDialog> {
  List<Map<String, dynamic>> _taxonomyData = [];
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  final Map<String, bool> _expandedCategories = {};

  @override
  void initState() {
    super.initState();
    _loadTaxonomyData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadTaxonomyData() async {
    try {
      final jsonString = await rootBundle.loadString('assets/vulnerability_taxonomy_full.json');
      final List<dynamic> data = json.decode(jsonString);
      setState(() {
        _taxonomyData = data.cast<Map<String, dynamic>>();
      });
    } catch (e) {
      debugPrint('Error loading taxonomy data: $e');
    }
  }

  List<Map<String, dynamic>> _getFilteredCategories() {
    if (_searchQuery.isEmpty) return _taxonomyData;

    final query = _searchQuery.toLowerCase();
    return _taxonomyData.where((category) {
      final categoryName = (category['Category'] as String).toLowerCase();
      if (categoryName.contains(query)) return true;

      final subcategories = (category['Subcategories'] as List).cast<Map<String, dynamic>>();
      return subcategories.any((sub) {
        final subcategoryName = (sub['Subcategory'] as String).toLowerCase();
        final description = (sub['Description'] as String? ?? '').toLowerCase();
        return subcategoryName.contains(query) || description.contains(query);
      });
    }).toList();
  }

  List<Map<String, dynamic>> _getFilteredSubcategories(Map<String, dynamic> category) {
    final subcategories = (category['Subcategories'] as List).cast<Map<String, dynamic>>();
    if (_searchQuery.isEmpty) return subcategories;

    final query = _searchQuery.toLowerCase();
    return subcategories.where((sub) {
      final subcategoryName = (sub['Subcategory'] as String).toLowerCase();
      final description = (sub['Description'] as String? ?? '').toLowerCase();
      return subcategoryName.contains(query) || description.contains(query);
    }).toList();
  }

  void _selectSubcategory(String category, String subcategory) {
    Navigator.of(context).pop({'category': category, 'subcategory': subcategory});
  }

  @override
  Widget build(BuildContext context) {
    final filteredCategories = _getFilteredCategories();

    return Dialog(
      backgroundColor: AppTheme.surfaceColor,
      child: Container(
        width: 700,
        height: 600,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Category / Subcategory Selector',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Search for categories or subcategories and select the appropriate subcategory.',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              style: TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search categories or subcategories...',
                hintStyle: TextStyle(color: AppTheme.textTertiary),
                prefixIcon: Icon(Icons.search, color: AppTheme.textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: AppTheme.textSecondary),
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.borderPrimary),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.borderPrimary),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: AppTheme.primaryColor),
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                  if (value.isNotEmpty) {
                    for (var category in filteredCategories) {
                      _expandedCategories[category['Category']] = true;
                    }
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.borderPrimary),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: filteredCategories.isEmpty
                    ? Center(
                        child: Text(
                          'No matches found',
                          style: TextStyle(color: AppTheme.textSecondary),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filteredCategories.length,
                        itemBuilder: (context, index) {
                          final category = filteredCategories[index];
                          final categoryName = category['Category'] as String;
                          final isExpanded = _expandedCategories[categoryName] ?? false;
                          final filteredSubs = _getFilteredSubcategories(category);

                          return Column(
                            children: [
                              InkWell(
                                onTap: () {
                                  setState(() {
                                    _expandedCategories[categoryName] = !isExpanded;
                                  });
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                                    border: Border(
                                      bottom: BorderSide(color: AppTheme.borderPrimary),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isExpanded ? Icons.arrow_drop_down : Icons.arrow_right,
                                        color: AppTheme.textPrimary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          categoryName,
                                          style: TextStyle(
                                            color: AppTheme.textPrimary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Text(
                                          '${filteredSubs.length}',
                                          style: TextStyle(
                                            color: AppTheme.primaryColor,
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              if (isExpanded)
                                ...filteredSubs.map((sub) {
                                  final subcategoryName = sub['Subcategory'] as String;
                                  return InkWell(
                                    onTap: () => _selectSubcategory(categoryName, subcategoryName),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(color: AppTheme.borderPrimary.withValues(alpha: 0.3)),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          const SizedBox(width: 32),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  subcategoryName,
                                                  style: TextStyle(
                                                    color: AppTheme.textPrimary,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                if (sub['Description'] != null) ...[ 
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    sub['Description'] as String,
                                                    style: TextStyle(
                                                      color: AppTheme.textSecondary,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          Icon(Icons.chevron_right, color: AppTheme.textTertiary, size: 20),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                            ],
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
