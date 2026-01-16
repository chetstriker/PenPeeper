import 'package:flutter/material.dart';
import 'package:penpeeper/theme_config.dart';

class SearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onNext;
  final VoidCallback? onPrevious;
  final VoidCallback onClose;
  final int currentMatch;
  final int totalMatches;

  const SearchBarWidget({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onNext,
    this.onPrevious,
    required this.onClose,
    this.currentMatch = 0,
    this.totalMatches = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: const Color(0xFF3C3C3C),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: InputDecoration(
                hintText: 'Search scan content...',
                prefixIcon: Icon(AppTheme.searchIcon),
                border: InputBorder.none,
              ),
              onChanged: onChanged,
              onSubmitted: (_) => onNext(),
            ),
          ),
          if (totalMatches > 0)
            Text(
              '${currentMatch + 1}/$totalMatches',
              style: const TextStyle(color: Color(0xFFB0B0B0)),
            ),
          IconButton(
            icon: Icon(AppTheme.keyboardArrowUpIcon),
            onPressed: totalMatches > 0 ? onPrevious : null,
          ),
          IconButton(
            icon: Icon(AppTheme.keyboardArrowDownIcon),
            onPressed: totalMatches > 0 ? onNext : null,
          ),
          IconButton(
            icon: Icon(AppTheme.closeIcon),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
