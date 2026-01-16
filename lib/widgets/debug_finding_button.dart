import 'package:flutter/material.dart';
import 'package:penpeeper/utils/run_finding_debug.dart';

/// Debug button widget to analyze finding ID 92
/// Add this to any screen to trigger debug analysis
class DebugFindingButton extends StatefulWidget {
  final int findingId;

  const DebugFindingButton({super.key, this.findingId = 92});

  @override
  State<DebugFindingButton> createState() => _DebugFindingButtonState();
}

class _DebugFindingButtonState extends State<DebugFindingButton> {
  bool _isRunning = false;

  Future<void> _runDebug() async {
    if (_isRunning) return;

    setState(() => _isRunning = true);

    try {
      await runFindingDebug();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Debug analysis complete! Check console output.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Debug error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isRunning = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: _isRunning ? null : _runDebug,
      icon: _isRunning
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.bug_report),
      label: Text(
        _isRunning ? 'Running...' : 'Debug Finding ${widget.findingId}',
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
    );
  }
}

/// Floating action button version for easy placement
class DebugFindingFab extends StatelessWidget {
  final int findingId;

  const DebugFindingFab({super.key, this.findingId = 92});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      onPressed: () async {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Running debug analysis... Check console.'),
            duration: Duration(seconds: 2),
          ),
        );

        await runFindingDebug();

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Debug complete! Check console output.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
      backgroundColor: Colors.orange,
      tooltip: 'Debug Finding $findingId',
      child: const Icon(Icons.bug_report),
    );
  }
}
