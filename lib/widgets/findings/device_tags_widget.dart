import 'package:flutter/material.dart';
import 'package:penpeeper/repositories/tag_repository.dart';
import 'package:penpeeper/services/project_data_cache.dart';
import 'package:penpeeper/theme_config.dart';

class DeviceTagsWidget extends StatefulWidget {
  final int deviceId;
  final int projectId;
  final VoidCallback onTagsChanged;

  const DeviceTagsWidget({
    super.key,
    required this.deviceId,
    required this.projectId,
    required this.onTagsChanged,
  });

  @override
  State<DeviceTagsWidget> createState() => _DeviceTagsWidgetState();
}

class _DeviceTagsWidgetState extends State<DeviceTagsWidget> {
  final _tagRepo = TagRepository();
  List<String> _tags = [];
  List<String> _allProjectTags = [];
  final TextEditingController _tagController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadTags();
    _loadAllProjectTags();
  }

  @override
  void didUpdateWidget(DeviceTagsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.deviceId != widget.deviceId || oldWidget.projectId != widget.projectId) {
      _loadTags();
      _loadAllProjectTags();
    }
  }

  @override
  void dispose() {
    _tagController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadTags() async {
    final tags = await _tagRepo.getDeviceTags(widget.deviceId);
    if (mounted) {
      setState(() => _tags = tags);
    }
  }

  Future<void> _loadAllProjectTags() async {
    final tags = await _tagRepo.getAllProjectTags(widget.projectId);
    if (mounted) {
      setState(() => _allProjectTags = tags);
    }
  }

  Future<void> _addTag(String tag) async {
    final upperTag = tag.trim().toUpperCase();
    if (upperTag.isEmpty || _tags.contains(upperTag)) return;
    
    debugPrint('DeviceTagsWidget: Adding tag $upperTag to device ${widget.deviceId}');
    await _tagRepo.addDeviceTag(widget.deviceId, upperTag);
    await _loadTags();
    await _loadAllProjectTags();
    
    debugPrint('DeviceTagsWidget: Reloading cache tags for project ${widget.projectId}');
    final cache = ProjectDataCache();
    await cache.reloadTags(widget.projectId);
    
    widget.onTagsChanged();
    _tagController.clear();
  }

  Future<void> _removeTag(String tag) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Tag'),
        content: Text('Remove tag "$tag"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _tagRepo.removeDeviceTag(widget.deviceId, tag);
      await _loadTags();
      
      final allTags = await _tagRepo.getAllProjectTags(widget.projectId);
      final isLastUsage = !allTags.contains(tag);
      
      final cache = ProjectDataCache();
      await cache.reloadTags(widget.projectId);
      
      await _loadAllProjectTags();
      widget.onTagsChanged();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ShaderMask(
                shaderCallback: (bounds) {
                  return const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Colors.transparent, Colors.white, Colors.white, Colors.transparent],
                    stops: [0.0, 0.05, 0.95, 1.0],
                  ).createShader(bounds);
                },
                blendMode: BlendMode.dstIn,
                child: Row(
                  children: _tags.map((tag) => Container(
                    margin: const EdgeInsets.only(right: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(tag, style: const TextStyle(color: Colors.white, fontSize: 12)),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: () => _removeTag(tag),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ],
                    ),
                  )).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 150,
            height: 40,
            child: Autocomplete<String>(
              optionsBuilder: (textEditingValue) {
                if (textEditingValue.text.isEmpty) return const Iterable<String>.empty();
                return _allProjectTags.where((tag) =>
                  tag.toUpperCase().contains(textEditingValue.text.toUpperCase())
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 8,
                    color: const Color(0xFF2A2A2A),
                    borderRadius: BorderRadius.circular(4),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 200, maxWidth: 150),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(4),
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (context, index) {
                          final option = options.elementAt(index);
                          return InkWell(
                            onTap: () => onSelected(option),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                              child: Text(option, style: const TextStyle(fontSize: 12, color: Colors.white)),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
              onSelected: _addTag,
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Add tag...',
                    hintStyle: TextStyle(fontSize: 12),
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    isDense: true,
                    suffixIcon: Icon(Icons.add, size: 20),
                  ),
                  onSubmitted: (value) {
                    _addTag(value);
                    controller.clear();
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
