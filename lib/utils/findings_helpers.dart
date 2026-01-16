import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:penpeeper/repositories/metadata_repository.dart';
import 'package:penpeeper/repositories/tag_repository.dart';

class FindingsHelpers {
  /// Converts Quill Delta JSON to plain text
  static String getPlainTextFromComment(String comment) {
    try {
      final delta = jsonDecode(comment);
      return QuillController(
        document: Document.fromJson(delta),
        selection: const TextSelection.collapsed(offset: 0),
      ).document.toPlainText();
    } catch (e) {
      return comment;
    }
  }

  /// Gets MAC address for a device
  static Future<String> getMacAddress(int deviceId) async {
    final metadataRepo = MetadataRepository();
    final metadata = await metadataRepo.getDeviceMetadata(deviceId);
    return metadata['mac_address'] ?? 'N/A';
  }

  /// Gets all tags for a device
  static Future<List<String>> getDeviceTags(int deviceId) async {
    final tagRepo = TagRepository();
    return await tagRepo.getDeviceTags(deviceId);
  }
}
