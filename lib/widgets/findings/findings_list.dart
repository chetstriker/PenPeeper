import 'package:flutter/material.dart';

class FindingsList extends StatelessWidget {
  final int itemCount;
  final Widget Function(BuildContext, int) itemBuilder;
  final Widget? emptyState;

  const FindingsList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.emptyState,
  });

  @override
  Widget build(BuildContext context) {
    if (itemCount == 0 && emptyState != null) {
      return emptyState!;
    }

    return ListView.builder(
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }
}
