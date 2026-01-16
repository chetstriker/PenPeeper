import 'package:flutter/material.dart';
import 'package:penpeeper/theme_config.dart';

class FindingsSearchBar extends StatelessWidget {
  final TextEditingController searchController;
  final String searchType;
  final ValueChanged<String> onSearchTypeChanged;
  final VoidCallback onSearch;
  final ValueChanged<String> onSearchQueryChanged;
  final bool showPortAndService;

  const FindingsSearchBar({
    super.key,
    required this.searchController,
    required this.searchType,
    required this.onSearchTypeChanged,
    required this.onSearch,
    required this.onSearchQueryChanged,
    this.showPortAndService = true,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 300,
          constraints: const BoxConstraints(maxHeight: 36),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: Colors.white, width: 1),
              right: BorderSide(color: Colors.white, width: 1),
              top: BorderSide(color: Colors.white, width: 1),
              bottom: BorderSide(color: Colors.white, width: 3),
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: TextField(
            controller: searchController,
            style: TextStyle(color: AppTheme.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Enter search term...',
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              isDense: true,
              suffixIcon: DropdownButton<String>(
                value: searchType,
                underline: const SizedBox(),
                icon: Icon(Icons.arrow_drop_down, color: AppTheme.textPrimary),
                items: [
                  DropdownMenuItem(
                    value: 'HOST',
                    child: Text('HOST', style: TextStyle(color: AppTheme.textPrimary)),
                  ),
                  DropdownMenuItem(
                    value: 'IP',
                    child: Text('IP', style: TextStyle(color: AppTheme.textPrimary)),
                  ),
                  if (showPortAndService) ...[
                    DropdownMenuItem(
                      value: 'PORT',
                      child: Text('PORT', style: TextStyle(color: AppTheme.textPrimary)),
                    ),
                    DropdownMenuItem(
                      value: 'SERVICE',
                      child: Text('SERVICE', style: TextStyle(color: AppTheme.textPrimary)),
                    ),
                  ],
                ],
                onChanged: (value) {
                  if (value != null) onSearchTypeChanged(value);
                },
              ),
            ),
            onChanged: onSearchQueryChanged,
            onSubmitted: (_) => onSearch(),
          ),
        ),
        IconButton(
          onPressed: onSearch,
          icon: Icon(Icons.search, color: AppTheme.primaryColor),
        ),
      ],
    );
  }
}
