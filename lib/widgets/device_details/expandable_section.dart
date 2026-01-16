import 'package:flutter/material.dart';
import 'package:penpeeper/widgets/device_details/section_container.dart';
import 'package:penpeeper/theme_config.dart';

class ExpandableSection extends StatefulWidget {
  final String title;
  final Color? headerColor;
  final List<dynamic> items;
  final Widget Function(dynamic item) itemBuilder;
  final int initialDisplayCount;
  final String moreText;

  const ExpandableSection({
    super.key,
    required this.title,
    this.headerColor,
    required this.items,
    required this.itemBuilder,
    this.initialDisplayCount = 4,
    this.moreText = 'vulnerabilities',
  });

  @override
  State<ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<ExpandableSection> {
  bool isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final displayedItems = isExpanded 
        ? widget.items 
        : widget.items.take(widget.initialDisplayCount).toList();
    final hasMore = widget.items.length > widget.initialDisplayCount;

    return SectionContainer(
      title: widget.title,
      headerColor: widget.headerColor,
      trailing: hasMore
          ? InkWell(
              onTap: () => setState(() => isExpanded = !isExpanded),
              child: Icon(
                isExpanded ? AppTheme.keyboardArrowUpIcon : AppTheme.keyboardArrowDownIcon,
                color: widget.headerColor == null ? Colors.black : Colors.white,
                size: 20,
              ),
            )
          : null,
      children: [
        for (final item in displayedItems)
          widget.itemBuilder(item),
        if (hasMore && !isExpanded)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '... and ${widget.items.length - widget.initialDisplayCount} more ${widget.moreText}',
              style: const TextStyle(
                color: Color(0xFF8B949E),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }
}
