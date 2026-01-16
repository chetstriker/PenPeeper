import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:penpeeper/server/api_router.dart';

void main() {
  group('API Router Tests', () {
    test('GET /api/status returns success', () async {
      final request = shelf.Request('GET', Uri.parse('http://localhost/api/status'));
      final response = await ApiRouter.handleRequest(request);
      
      expect(response.statusCode, equals(200));
    });

    test('OPTIONS request returns success', () async {
      final request = shelf.Request('OPTIONS', Uri.parse('http://localhost/api/projects'));
      final response = await ApiRouter.handleRequest(request);
      
      expect(response.statusCode, equals(200));
    });

    test('404 for unknown endpoint', () async {
      final request = shelf.Request('GET', Uri.parse('http://localhost/api/unknown'));
      final response = await ApiRouter.handleRequest(request);
      
      expect(response.statusCode, equals(404));
    });
  });
}
