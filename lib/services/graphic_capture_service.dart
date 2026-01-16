import 'dart:typed_data';
import '../models/report_models.dart';

class GraphicCaptureService {
  static final Map<String, Uint8List> _cache = {};

  static Future<Uint8List?> captureGraphicAsImage({
    required int option,
    required List<ReportFinding> findings,
    double width = 800,
    double height = 400,
  }) async {
    final cacheKey = 'graphic_${option}_${findings.length}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey];
    }

    // For now, return null to use fallback
    // Image capture requires the widget to be in the widget tree
    return null;
  }

  static void cacheGraphicImage(String key, Uint8List imageBytes) {
    _cache[key] = imageBytes;
  }

  static void clearCache() {
    _cache.clear();
  }
}
