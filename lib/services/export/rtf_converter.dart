import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:penpeeper/services/image_manager.dart';

/// Service for converting Quill Delta documents to RTF format
class RtfConverter {
  final Map<String, int> _colorTable = {};
  int _colorIndex = 3; // Start after predefined colors

  /// Converts a Quill Delta JSON string to RTF format
  Future<String> convertQuillDeltaToRTF(String comment) async {
    try {
      final delta = jsonDecode(comment);
      final document = Document.fromJson(delta);
      final rtfBuffer = StringBuffer();
      int orderedListCounter = 1;
      bool wasOrderedList = false;
      
      final operations = document.toDelta().toList();
      String currentLineText = '';
      
      for (int i = 0; i < operations.length; i++) {
        final operation = operations[i];
        
        if (operation.data is String) {
          String text = operation.data as String;
          final attrs = operation.attributes;
          
          if (text == '\n') {
            if (attrs != null) {
              final listType = attrs['list'];
              final isCodeBlock = attrs['code-block'] == true;
              final headerLevel = attrs['header'];
              
              if (headerLevel != null) {
                final fontSize = headerLevel == 1 ? 32 : (headerLevel == 2 ? 28 : 24);
                rtfBuffer.write('{\\b\\fs$fontSize $currentLineText}\\par ');
                orderedListCounter = 1;
                wasOrderedList = false;
              } else if (isCodeBlock) {
                rtfBuffer.write('{\\f1\\fs16\\cf3\\highlight4 $currentLineText}\\par ');
              } else if (listType != null) {
                if (listType == 'bullet') {
                  rtfBuffer.write('\\bullet $currentLineText\\par ');
                  wasOrderedList = false;
                } else if (listType == 'ordered') {
                  if (!wasOrderedList) orderedListCounter = 1;
                  rtfBuffer.write('$orderedListCounter) $currentLineText\\par ');
                  orderedListCounter++;
                  wasOrderedList = true;
                } else if (listType == 'checked') {
                  rtfBuffer.write('[X] $currentLineText\\par ');
                  wasOrderedList = false;
                } else if (listType == 'unchecked') {
                  rtfBuffer.write('[ ] $currentLineText\\par ');
                  wasOrderedList = false;
                }
              } else {
                if (currentLineText.trim().isNotEmpty) {
                  rtfBuffer.write('$currentLineText\\par ');
                } else {
                  rtfBuffer.write('\\par ');
                }
                orderedListCounter = 1;
                wasOrderedList = false;
              }
            } else {
              if (currentLineText.trim().isNotEmpty) {
                rtfBuffer.write('$currentLineText\\par ');
              } else {
                rtfBuffer.write('\\par ');
              }
              orderedListCounter = 1;
              wasOrderedList = false;
            }
            currentLineText = '';
          } else {
            final lines = text.split('\n');
            
            for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
              final lineText = lines[lineIndex];
              
              if (lineIndex > 0) {
                if (currentLineText.trim().isNotEmpty) {
                  rtfBuffer.write('$currentLineText\\par ');
                } else {
                  rtfBuffer.write('\\par ');
                }
                currentLineText = '';
              }
              
              if (attrs != null) {
                final isCodeBlock = attrs['code-block'] == true;
                
                if (isCodeBlock) {
                  final escapedText = escapeRTFText(lineText);
                  currentLineText += '{\\f1\\fs16\\cf3\\highlight4 $escapedText}';
                } else {
                  final formatBuffer = StringBuffer();
                  
                  if (attrs['bold'] == true) {
                    formatBuffer.write('\\b ');
                  }
                  if (attrs['italic'] == true) {
                    formatBuffer.write('\\i ');
                  }
                  if (attrs['underline'] == true) {
                    formatBuffer.write('\\ul ');
                  }
                  if (attrs['color'] != null) {
                    final colorIndex = getColorIndex(attrs['color']);
                    formatBuffer.write('\\cf$colorIndex ');
                  }
                  
                  if (formatBuffer.isNotEmpty) {
                    currentLineText += '{$formatBuffer${escapeRTFText(lineText)}}';
                  } else {
                    currentLineText += escapeRTFText(lineText);
                  }
                }
              } else {
                currentLineText += lineText;
              }
            }
          }
        } else if (operation.data is Map) {
          if (currentLineText.trim().isNotEmpty) {
            rtfBuffer.write('$currentLineText\\par ');
            currentLineText = '';
          }
          
          final embed = operation.data as Map<String, dynamic>;
          if (embed.containsKey('image')) {
            final imageData = await getImageDataForRTF(embed['image']);
            if (imageData != null) {
              rtfBuffer.write(imageData);
            } else {
              rtfBuffer.write('{\\cf2\\b [IMAGE: ${escapeRTFText(embed['image'].toString())}]}\\par ');
            }
          } else {
            rtfBuffer.write('{\\cf2\\b [EMBED: ${escapeRTFText(embed.toString())}]}\\par ');
          }
        }
      }
      
      if (currentLineText.trim().isNotEmpty) {
        rtfBuffer.write('$currentLineText\\par ');
      }
      
      return rtfBuffer.toString().trim();
    } catch (e) {
      return escapeRTFText(comment).replaceAll('\n', '\\par ').trim();
    }
  }

  /// Escapes special RTF characters in text
  String escapeRTFText(String text) {
    text = text.replaceAll('\\', '\\\\');
    text = text.replaceAll('{', '\\{');
    text = text.replaceAll('}', '\\}');
    
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      final code = char.codeUnitAt(0);
      
      if (code > 127) {
        buffer.write('\\u$code?');
      } else {
        buffer.write(char);
      }
    }
    
    return buffer.toString();
  }

  /// Gets or creates a color index for the RTF color table
  int getColorIndex(dynamic color) {
    if (color is String) {
      String colorStr = color.replaceAll('#', '').replaceAll('0x', '');
      if (colorStr.length >= 6) {
        final r = int.parse(colorStr.substring(colorStr.length - 6, colorStr.length - 4), radix: 16);
        final g = int.parse(colorStr.substring(colorStr.length - 4, colorStr.length - 2), radix: 16);
        final b = int.parse(colorStr.substring(colorStr.length - 2), radix: 16);
        return addColorToTable(r, g, b);
      }
    } else if (color is int) {
      final r = (color >> 16) & 0xFF;
      final g = (color >> 8) & 0xFF;
      final b = color & 0xFF;
      return addColorToTable(r, g, b);
    }
    return 0;
  }

  /// Adds a color to the color table and returns its index
  int addColorToTable(int r, int g, int b) {
    final key = '$r,$g,$b';
    if (_colorTable.containsKey(key)) {
      return _colorTable[key]!;
    }
    _colorTable[key] = _colorIndex;
    return _colorIndex++;
  }

  /// Builds the RTF color table string
  String buildColorTable() {
    final buffer = StringBuffer('{\\colortbl;\\red21\\green96\\blue130;\\red255\\green0\\blue0;\\red0\\green0\\blue139;\\red211\\green211\\blue211;\\red240\\green240\\blue240;');
    for (final entry in _colorTable.entries) {
      final parts = entry.key.split(',');
      buffer.write('\\red${parts[0]}\\green${parts[1]}\\blue${parts[2]};');
    }
    buffer.write('}');
    return buffer.toString();
  }

  /// Resets the color table for a new export
  void resetColorTable() {
    _colorTable.clear();
    _colorIndex = 3;
  }

  /// Gets image data formatted for RTF embedding
  Future<String?> getImageDataForRTF(dynamic imageSource) async {
    try {
      Uint8List? imageBytes;
      
      if (imageSource is String) {
        if (imageSource.startsWith('data:image/')) {
          final base64Data = imageSource.split(',')[1];
          imageBytes = base64Decode(base64Data);
        } else {
          imageBytes = await ImageManager.readImageBytes(imageSource);
        }
      }
      
      if (imageBytes != null) {
        return createRTFImageEmbed(imageBytes);
      }
    } catch (e) {
      debugPrint('Failed to load image for RTF: $e');
    }
    return null;
  }

  /// Creates an RTF image embed from image bytes
  String createRTFImageEmbed(Uint8List imageBytes) {
    final hexData = imageBytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('');
    
    int actualWidth = 800;
    int actualHeight = 600;
    
    if (imageBytes.length > 24 && 
        imageBytes[0] == 0x89 && imageBytes[1] == 0x50 && 
        imageBytes[2] == 0x4E && imageBytes[3] == 0x47) {
      actualWidth = (imageBytes[16] << 24) | (imageBytes[17] << 16) | (imageBytes[18] << 8) | imageBytes[19];
      actualHeight = (imageBytes[20] << 24) | (imageBytes[21] << 16) | (imageBytes[22] << 8) | imageBytes[23];
    }
    
    double scaleWidth = 600.0 / actualWidth;
    double scaleHeight = 600.0 / actualHeight;
    double scale = scaleWidth < scaleHeight ? scaleWidth : scaleHeight;
    
    if (scale > 1.0) scale = 1.0;
    
    final displayWidth = (actualWidth * scale).round();
    final displayHeight = (actualHeight * scale).round();
    
    final widthTwips = displayWidth * 20;
    final heightTwips = displayHeight * 20;
    
    return '''
{\\pict\\pngblip\\picw$actualWidth\\pich$actualHeight\\picwgoal$widthTwips\\pichgoal$heightTwips
$hexData}\\par
''';
  }
}
