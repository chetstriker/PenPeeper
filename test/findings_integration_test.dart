import 'package:flutter_test/flutter_test.dart';
import 'package:penpeeper/repositories/findings_repository.dart';

void main() {
  group('Findings Integration Tests', () {
    late FindingsRepository findingsRepo;

    setUp(() async {
      findingsRepo = FindingsRepository();
    });

    test('completion status methods should not throw errors', () async {
      // Test that all completion methods can be called without errors
      expect(() async {
        await findingsRepo.getCompleteFlaggedFindings(1);
        await findingsRepo.getIncompleteFlaggedFindings(1);
        await findingsRepo.getFindingCompletionStatus(999); // Non-existent ID
      }, returnsNormally);
    });

    test('completion status should handle non-existent finding gracefully', () async {
      final status = await findingsRepo.getFindingCompletionStatus(999999);
      
      expect(status['is_complete'], false);
      expect(status['missing_criteria'], isA<List>());
    });

    test('performance check for completion queries', () async {
      final stopwatch = Stopwatch()..start();
      
      // Run multiple completion queries
      for (int i = 0; i < 10; i++) {
        await findingsRepo.getCompleteFlaggedFindings(1);
        await findingsRepo.getIncompleteFlaggedFindings(1);
      }
      
      stopwatch.stop();
      
      // Should complete within reasonable time (2 seconds for 20 queries)
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));
      print('Completion queries performance: ${stopwatch.elapsedMilliseconds}ms for 20 queries');
    });
  });
}