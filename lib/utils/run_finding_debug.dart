import 'package:flutter/foundation.dart';
import 'package:penpeeper/utils/finding_debug_query.dart';

/// Quick utility to run debug analysis on finding ID 92
/// Call this from anywhere in your app to trigger the debug analysis
Future<void> runFindingDebug() async {
  debugPrint('\n\n');
  debugPrint('╔════════════════════════════════════════╗');
  debugPrint('║   STARTING FINDING ID 92 DEBUG         ║');
  debugPrint('╚════════════════════════════════════════╝');
  debugPrint('\n');
  
  await FindingDebugQuery.debugFinding(92);
  
  debugPrint('\n');
  debugPrint('╔════════════════════════════════════════╗');
  debugPrint('║   DEBUG COMPLETE - CHECK OUTPUT ABOVE  ║');
  debugPrint('╚════════════════════════════════════════╝');
  debugPrint('\n\n');
}
