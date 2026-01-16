import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:penpeeper/services/image_manager.dart';
import 'package:penpeeper/utils/image_resizer.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class QuillParser {
  static final Map<String, int> _colorTable = {};
  static int _colorIndex = 3;
  
  static String deltaToPlainText(String? deltaJson) {
    if (deltaJson == null || deltaJson.isEmpty) return '';
    
    try {
      final delta = jsonDecode(deltaJson);
      final document = Document.fromJson(delta);
      final plainText = document.toPlainText();
      // Fix special characters for PDF rendering
      return plainText
          .replaceAll('\u2022', '* ')      // Bullet to asterisk
          .replaceAll('\u2013', '-')       // En dash
          .replaceAll('\u2014', '-')       // Em dash
          .replaceAll(''', "'")       // Left single quote
          .replaceAll(''', "'")       // Right single quote
          .replaceAll('\u201C', '"')       // Left double quote
          .replaceAll('\u201D', '"')       // Right double quote
          .replaceAll('"', '"')       // Left double quote
          .replaceAll('"', '"')       // Right double quote
          .replaceAll('┌', '+')        // Box drawing
          .replaceAll('└', '+')        // Box drawing
          .replaceAll('─', '-')        // Box drawing
          .replaceAll('│', '|')        // Box drawing
          .replaceAll('㉿', '@');       // Special symbol
    } catch (e) {
      return deltaJson;
    }
  }
  
  static Future<List<pw.Widget>> deltaToPdfWidgets(String? deltaJson, String projectName) async {
    if (deltaJson == null || deltaJson.isEmpty) return [];
    
    try {
      // Decode HTML entities before parsing JSON
      final decodedJson = _decodeHtmlEntities(deltaJson);
      final delta = jsonDecode(decodedJson);
      final document = Document.fromJson(delta);
      final widgets = <pw.Widget>[];
      final operations = document.toDelta().toList();
      String currentText = '';
      
      for (int i = 0; i < operations.length; i++) {
        final operation = operations[i];
        
        if (operation.data is String) {
          String text = operation.data as String;
          currentText += text
              .replaceAll('\u2022', '* ')
              .replaceAll('\u2013', '-')
              .replaceAll('\u2014', '-')
              .replaceAll('\u2018', "'")  // Left single quote
              .replaceAll('\u2019', "'")  // Right single quote
              .replaceAll(''', "'")
              .replaceAll(''', "'")
              .replaceAll('\u201C', '"')
              .replaceAll('\u201D', '"')
              .replaceAll('"', '"')
              .replaceAll('"', '"')
              .replaceAll('┌', '+')
              .replaceAll('└', '+')
              .replaceAll('─', '-')
              .replaceAll('│', '|')
              .replaceAll('㉿', '@');
        } else if (operation.data is Map) {
          // Flush current text before image
          if (currentText.trim().isNotEmpty) {
            widgets.add(pw.Text(currentText.trim(), style: const pw.TextStyle(fontSize: 9)));
            currentText = '';
          }
          
          final embed = operation.data as Map<String, dynamic>;
          if (embed.containsKey('image')) {
            final imageWidget = await _createPdfImage(embed['image'], projectName);
            if (imageWidget != null) {
              widgets.add(imageWidget);
            }
          }
        }
      }
      
      // Flush remaining text
      if (currentText.trim().isNotEmpty) {
        widgets.add(pw.Text(currentText.trim(), style: const pw.TextStyle(fontSize: 9)));
      }
      
      return widgets.isEmpty ? [pw.Text(deltaToPlainText(deltaJson), style: const pw.TextStyle(fontSize: 9))] : widgets;
    } catch (e) {
      return [pw.Text(deltaJson.replaceAll('\u201C', '"').replaceAll('\u201D', '"').replaceAll('"', '"').replaceAll('"', '"'), style: const pw.TextStyle(fontSize: 9))];
    }
  }
  
  static Future<pw.Widget?> _createPdfImage(dynamic imageSource, String projectName) async {
    try {
      debugPrint('📄 [QuillParser] Processing image for PDF: $imageSource');
      Uint8List? imageBytes;

      if (imageSource is String) {
        if (imageSource.startsWith('data:image/')) {
          final base64Data = imageSource.split(',')[1];
          imageBytes = base64Decode(base64Data);
        } else {
          // Use ImageManager to handle both absolute and relative paths
          imageBytes = await ImageManager.readImageBytes(imageSource);
        }
      }

      if (imageBytes != null) {
        debugPrint('📊 [QuillParser] Image bytes loaded: ${imageBytes.length} bytes');

        // Get image dimensions to check if resizing is needed
        final dimensions = await ImageResizer.getImageDimensions(imageBytes);
        if (dimensions != null) {
          debugPrint('📐 [QuillParser] Image dimensions: $dimensions');

          // Check if image needs resizing (using same 2000px limit)
          if (dimensions.width > 2000 || dimensions.height > 2000) {
            debugPrint('⚠️  [QuillParser] Image too large for PDF, resizing...');
            debugPrint('   Original: ${dimensions.width}x${dimensions.height}');

            // Get source name for better logging
            String imageName = 'unknown.png';
            if (imageSource is String) {
              if (imageSource.contains('/')) {
                imageName = imageSource.split('/').last;
              } else if (imageSource.contains('\\')) {
                imageName = imageSource.split('\\').last;
              }
            }

            // Resize the image
            final resizeResult = await ImageResizer.resizeImageIfNeeded(
              imageBytes: imageBytes,
              imageName: imageName,
            );

            if (resizeResult.wasResized) {
              debugPrint('✅ [QuillParser] Image resized successfully for PDF');
              debugPrint('   New dimensions: ${resizeResult.newWidth}x${resizeResult.newHeight}');
              imageBytes = resizeResult.imageBytes;
            } else {
              debugPrint('⚠️  [QuillParser] Resize failed, will try to use original');
              if (resizeResult.error != null) {
                debugPrint('   Error: ${resizeResult.error}');
              }
            }
          } else {
            debugPrint('✓ [QuillParser] Image is within size limits for PDF');
          }
        }

        final image = pw.MemoryImage(imageBytes);
        debugPrint('✅ [QuillParser] Creating PDF image widget');
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 8),
          child: pw.Container(
            constraints: const pw.BoxConstraints(maxWidth: 400, maxHeight: 300),
            child: pw.Image(image, fit: pw.BoxFit.contain),
          ),
        );
      } else {
        debugPrint('❌ [QuillParser] Failed to load image bytes');
      }
    } catch (e, stack) {
      debugPrint('❌ [QuillParser] Error creating PDF image: $e');
      debugPrint('Stack trace: $stack');
    }
    return null;
  }
  
  static Future<String> deltaToRTF(String? deltaJson) async {
    if (deltaJson == null || deltaJson.isEmpty) return '';
    
    try {
      return await _convertQuillDeltaToRTF(deltaJson);
    } catch (e) {
      return _escapeRTFText(deltaJson);
    }
  }
  
  static String deltaToHTML(String? deltaJson) {
    if (deltaJson == null || deltaJson.isEmpty) return '';
    
    try {
      return _convertQuillDeltaToHTML(deltaJson);
    } catch (e) {
      return _escapeHTML(deltaJson);
    }
  }
  
  static Future<String> deltaToHTMLWithImages(String? deltaJson, String projectName) async {
    if (deltaJson == null || deltaJson.isEmpty) return '';
    
    try {
      return await _convertQuillDeltaToHTMLWithImages(deltaJson, projectName);
    } catch (e) {
      return _escapeHTML(deltaJson).replaceAll('\n', '<br>');
    }
  }
  
  static Future<String> _convertQuillDeltaToRTF(String comment) async {
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
            // Process the accumulated line text
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
                // Regular paragraph
                if (currentLineText.trim().isNotEmpty) {
                  rtfBuffer.write('$currentLineText\\par ');
                } else {
                  rtfBuffer.write('\\par ');
                }
                orderedListCounter = 1;
                wasOrderedList = false;
              }
            } else {
              // Plain newline
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
            // Split text on internal newlines
            final lines = text.split('\n');
            
            for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
              final lineText = lines[lineIndex];
              
              if (lineIndex > 0) {
                // Process previous line before starting new one
                if (currentLineText.trim().isNotEmpty) {
                  rtfBuffer.write('$currentLineText\\par ');
                } else {
                  // Empty line - add paragraph break
                  rtfBuffer.write('\\par ');
                }
                currentLineText = '';
              }
              
              // Add current line text
              if (attrs != null) {
                final isCodeBlock = attrs['code-block'] == true;
                
                if (isCodeBlock) {
                  final escapedText = _escapeRTFText(lineText);
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
                  
                  if (formatBuffer.isNotEmpty) {
                    currentLineText += '{$formatBuffer${_escapeRTFText(lineText)}}';
                  } else {
                    currentLineText += _escapeRTFText(lineText);
                  }
                }
              } else {
                currentLineText += _escapeRTFText(lineText);
              }
            }
          }
        } else if (operation.data is Map) {
          // Handle embeds (images, etc.) - add line break before
          if (currentLineText.trim().isNotEmpty) {
            rtfBuffer.write('$currentLineText\\par ');
            currentLineText = '';
          }
          
          final embed = operation.data as Map<String, dynamic>;
          if (embed.containsKey('image')) {
            final imageData = await _getImageDataForRTF(embed['image']);
            if (imageData != null) {
              rtfBuffer.write(imageData);
            } else {
              rtfBuffer.write('{\\cf2\\b [IMAGE: ${_escapeRTFText(embed['image'].toString())}]}\\par ');
            }
          } else {
            rtfBuffer.write('{\\cf2\\b [EMBED: ${_escapeRTFText(embed.toString())}]}\\par ');
          }
        }
      }
      
      // Handle any remaining text
      if (currentLineText.trim().isNotEmpty) {
        rtfBuffer.write('$currentLineText\\par ');
      }
      
      return rtfBuffer.toString().trim();
    } catch (e) {
      return _escapeRTFText(comment).replaceAll('\n', '\\par ').trim();
    }
  }
  
  static String _convertQuillDeltaToHTML(String comment) {
    try {
      final delta = jsonDecode(comment);
      final document = Document.fromJson(delta);
      final htmlBuffer = StringBuffer();
      
      final operations = document.toDelta().toList();
      String currentLineText = '';
      bool inList = false;
      String? currentListType;
      
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
                final tag = 'h$headerLevel';
                htmlBuffer.write('<$tag>$currentLineText</$tag>');
              } else if (isCodeBlock) {
                htmlBuffer.write('<pre><code>$currentLineText</code></pre>');
              } else if (listType != null) {
                if (!inList || currentListType != listType) {
                  if (inList) {
                    final closeTag = currentListType == 'ordered' ? '</ol>' : '</ul>';
                    htmlBuffer.write(closeTag);
                  }
                  final openTag = listType == 'ordered' ? '<ol>' : '<ul>';
                  htmlBuffer.write(openTag);
                  inList = true;
                  currentListType = listType;
                }
                
                if (listType == 'checked') {
                  htmlBuffer.write('<li>✓ $currentLineText</li>');
                } else if (listType == 'unchecked') {
                  htmlBuffer.write('<li>☐ $currentLineText</li>');
                } else {
                  htmlBuffer.write('<li>$currentLineText</li>');
                }
              } else {
                if (inList) {
                  final closeTag = currentListType == 'ordered' ? '</ol>' : '</ul>';
                  htmlBuffer.write(closeTag);
                  inList = false;
                  currentListType = null;
                }
                if (currentLineText.trim().isNotEmpty) {
                  htmlBuffer.write('<p>$currentLineText</p>');
                } else {
                  htmlBuffer.write('<br>');
                }
              }
            } else {
              if (inList) {
                final closeTag = currentListType == 'ordered' ? '</ol>' : '</ul>';
                htmlBuffer.write(closeTag);
                inList = false;
                currentListType = null;
              }
              if (currentLineText.trim().isNotEmpty) {
                htmlBuffer.write('<p>$currentLineText</p>');
              } else {
                htmlBuffer.write('<br>');
              }
            }
            currentLineText = '';
          } else {
            // Handle text with internal newlines
            final lines = text.split('\n');
            
            for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
              final lineText = lines[lineIndex];
              
              // Add line break for internal newlines (not the first line)
              if (lineIndex > 0) {
                // Close current line if it has content
                if (currentLineText.trim().isNotEmpty) {
                  if (inList) {
                    final closeTag = currentListType == 'ordered' ? '</ol>' : '</ul>';
                    htmlBuffer.write(closeTag);
                    inList = false;
                    currentListType = null;
                  }
                  htmlBuffer.write('<p>$currentLineText</p>');
                  currentLineText = '';
                } else {
                  htmlBuffer.write('<br>');
                }
              }
              
              String htmlText = _escapeHTML(lineText);
              
              if (attrs != null) {
                if (attrs['bold'] == true) {
                  htmlText = '<strong>$htmlText</strong>';
                }
                if (attrs['italic'] == true) {
                  htmlText = '<em>$htmlText</em>';
                }
                if (attrs['underline'] == true) {
                  htmlText = '<u>$htmlText</u>';
                }
                if (attrs['color'] != null) {
                  htmlText = '<span style="color: ${attrs['color']}">$htmlText</span>';
                }
                if (attrs['background'] != null) {
                  htmlText = '<span style="background-color: ${attrs['background']}">$htmlText</span>';
                }
              }
              
              currentLineText += htmlText;
            }
          }
        } else if (operation.data is Map) {
          // Handle embeds (images, etc.)
          final embed = operation.data as Map<String, dynamic>;
          if (embed.containsKey('image')) {
            // Close current line before adding image
            if (currentLineText.trim().isNotEmpty) {
              if (inList) {
                final closeTag = currentListType == 'ordered' ? '</ol>' : '</ul>';
                htmlBuffer.write(closeTag);
                inList = false;
                currentListType = null;
              }
              htmlBuffer.write('<p>$currentLineText</p>');
              currentLineText = '';
            }
            
            final imageData = embed['image'];
            if (imageData is String && (imageData.startsWith('http') || imageData.startsWith('data:'))) {
              htmlBuffer.write('<img src="$imageData" class="evidence-image" alt="Evidence Screenshot" />');
            } else {
              htmlBuffer.write('<div class="image-placeholder">📷 Evidence Screenshot<br><small>Image: $imageData</small></div>');
            }
          } else {
            currentLineText += '<span style="color: #7f8c8d; font-style: italic;">[${embed.keys.first.toUpperCase()}]</span>';
          }
        }
      }
      
      if (inList) {
        final closeTag = currentListType == 'ordered' ? '</ol>' : '</ul>';
        htmlBuffer.write(closeTag);
      }
      
      if (currentLineText.trim().isNotEmpty) {
        htmlBuffer.write('<p>$currentLineText</p>');
      }
      
      return htmlBuffer.toString();
    } catch (e) {
      // Fallback: convert plain text newlines to <br> tags
      return '<p>${_escapeHTML(comment).replaceAll('\n', '<br>')}</p>';
    }
  }
  
  static String _escapeRTFText(String text) {
    text = text.replaceAll(String.fromCharCodes([226, 128, 147]), '-');
    text = text.replaceAll(String.fromCharCodes([226, 128, 148]), '-');
    text = text.replaceAll(String.fromCharCodes([226, 128, 156]), '"');
    text = text.replaceAll(String.fromCharCodes([226, 128, 157]), '"');
    text = text.replaceAll(String.fromCharCodes([194, 160]), ' ');
    
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      final code = char.codeUnitAt(0);
      
      if (char == '\\') {
        buffer.write('\\\\');
      } else if (char == '{') {
        buffer.write('\\{');
      } else if (char == '}') {
        buffer.write('\\}');
      } else if (code == 0x2013 || code == 0x2014) {
        buffer.write('-');
      } else if (code == 0x201C || code == 0x201D) {
        buffer.write('"');
      } else if (code == 0x00A0) {
        buffer.write(' ');
      } else if (code > 127) {
        if (code > 32767) {
          buffer.write('\\u${(code - 65536)}?');
        } else {
          buffer.write('\\u$code?');
        }
      } else {
        buffer.write(char);
      }
    }
    
    return buffer.toString();
  }
  
  static int _getColorIndex(dynamic color) {
    if (color is String) {
      String colorStr = color.replaceAll('#', '').replaceAll('0x', '');
      if (colorStr.length >= 6) {
        final r = int.parse(colorStr.substring(colorStr.length - 6, colorStr.length - 4), radix: 16);
        final g = int.parse(colorStr.substring(colorStr.length - 4, colorStr.length - 2), radix: 16);
        final b = int.parse(colorStr.substring(colorStr.length - 2), radix: 16);
        return _addColorToTable(r, g, b);
      }
    } else if (color is int) {
      final r = (color >> 16) & 0xFF;
      final g = (color >> 8) & 0xFF;
      final b = color & 0xFF;
      return _addColorToTable(r, g, b);
    }
    return 0;
  }
  
  static int _addColorToTable(int r, int g, int b) {
    final key = '$r,$g,$b';
    if (_colorTable.containsKey(key)) {
      return _colorTable[key]!;
    }
    _colorTable[key] = _colorIndex;
    return _colorIndex++;
  }
  
  static Future<String?> _getImageDataForRTF(dynamic imageSource) async {
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
        return _createRTFImageEmbed(imageBytes);
      }
    } catch (e) {
      // Silent failure
    }
    return null;
  }

  static String _createRTFImageEmbed(Uint8List imageBytes) {
    // Convert image bytes to hexadecimal
    final hexData = imageBytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join('');
    
    // Try to get actual image dimensions (simplified approach)
    int actualWidth = 800; // Default fallback
    int actualHeight = 600; // Default fallback
    
    // Basic PNG dimension detection
    if (imageBytes.length > 24 && 
        imageBytes[0] == 0x89 && imageBytes[1] == 0x50 && 
        imageBytes[2] == 0x4E && imageBytes[3] == 0x47) {
      // PNG signature found, read dimensions from IHDR chunk
      actualWidth = (imageBytes[16] << 24) | (imageBytes[17] << 16) | (imageBytes[18] << 8) | imageBytes[19];
      actualHeight = (imageBytes[20] << 24) | (imageBytes[21] << 16) | (imageBytes[22] << 8) | imageBytes[23];
    }
    
    // Max width for RTF document (accounting for margins) - approximately 6.5 inches = 468 pixels
    const maxWidth = 468;
    double scale = 1.0;
    
    if (actualWidth > maxWidth) {
      scale = maxWidth / actualWidth;
    }
    
    final displayWidth = (actualWidth * scale).round();
    final displayHeight = (actualHeight * scale).round();
    
    // RTF twips (1/1440 inch) - multiply by 20 for proper scaling
    final widthTwips = displayWidth * 20;
    final heightTwips = displayHeight * 20;
    
    // RTF image embed format with center alignment and calculated dimensions
    return '''
\\pard\\qc{\\pict\\pngblip\\picw$actualWidth\\pich$actualHeight\\picwgoal$widthTwips\\pichgoal$heightTwips
$hexData}\\par
''';
  }

  static String buildColorTable() {
    final buffer = StringBuffer('{\\colortbl;\\red21\\green96\\blue130;\\red255\\green0\\blue0;\\red0\\green0\\blue139;\\red211\\green211\\blue211;\\red240\\green240\\blue240;');
    for (final entry in _colorTable.entries) {
      final parts = entry.key.split(',');
      buffer.write('\\red${parts[0]}\\green${parts[1]}\\blue${parts[2]};');
    }
    buffer.write('}');
    return buffer.toString();
  }

  static void resetColorTable() {
    _colorTable.clear();
    _colorIndex = 3;
  }

  static Future<String> _convertQuillDeltaToHTMLWithImages(String comment, String projectName) async {
    try {
      final delta = jsonDecode(comment);
      final document = Document.fromJson(delta);
      final htmlBuffer = StringBuffer();
      
      final operations = document.toDelta().toList();
      String currentLineText = '';
      bool inList = false;
      String? currentListType;
      const stripColors = true;
      
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
                final tag = 'h$headerLevel';
                htmlBuffer.write('<$tag>$currentLineText</$tag>');
              } else if (isCodeBlock) {
                htmlBuffer.write('<pre><code>$currentLineText</code></pre>');
              } else if (listType != null) {
                if (!inList || currentListType != listType) {
                  if (inList) {
                    final closeTag = currentListType == 'ordered' ? '</ol>' : '</ul>';
                    htmlBuffer.write(closeTag);
                  }
                  final openTag = listType == 'ordered' ? '<ol>' : '<ul>';
                  htmlBuffer.write(openTag);
                  inList = true;
                  currentListType = listType;
                }
                
                if (listType == 'checked') {
                  htmlBuffer.write('<li>✓ $currentLineText</li>');
                } else if (listType == 'unchecked') {
                  htmlBuffer.write('<li>☐ $currentLineText</li>');
                } else {
                  htmlBuffer.write('<li>$currentLineText</li>');
                }
              } else {
                if (inList) {
                  final closeTag = currentListType == 'ordered' ? '</ol>' : '</ul>';
                  htmlBuffer.write(closeTag);
                  inList = false;
                  currentListType = null;
                }
                if (currentLineText.trim().isNotEmpty) {
                  htmlBuffer.write('<p>$currentLineText</p>');
                } else {
                  htmlBuffer.write('<br>');
                }
              }
            } else {
              if (inList) {
                final closeTag = currentListType == 'ordered' ? '</ol>' : '</ul>';
                htmlBuffer.write(closeTag);
                inList = false;
                currentListType = null;
              }
              if (currentLineText.trim().isNotEmpty) {
                htmlBuffer.write('<p>$currentLineText</p>');
              } else {
                htmlBuffer.write('<br>');
              }
            }
            currentLineText = '';
          } else {
            // Handle text with internal newlines
            final lines = text.split('\n');
            
            for (int lineIndex = 0; lineIndex < lines.length; lineIndex++) {
              final lineText = lines[lineIndex];
              
              // Add line break for internal newlines (not the first line)
              if (lineIndex > 0) {
                // Close current line if it has content
                if (currentLineText.trim().isNotEmpty) {
                  if (inList) {
                    final closeTag = currentListType == 'ordered' ? '</ol>' : '</ul>';
                    htmlBuffer.write(closeTag);
                    inList = false;
                    currentListType = null;
                  }
                  htmlBuffer.write('<p>$currentLineText</p>');
                  currentLineText = '';
                } else {
                  htmlBuffer.write('<br>');
                }
              }
              
              String htmlText = _escapeHTML(lineText);
              
              if (attrs != null) {
                if (attrs['bold'] == true) {
                  htmlText = '<strong>$htmlText</strong>';
                }
                if (attrs['italic'] == true) {
                  htmlText = '<em>$htmlText</em>';
                }
                if (attrs['underline'] == true) {
                  htmlText = '<u>$htmlText</u>';
                }
                if (!stripColors) {
                  if (attrs['color'] != null) {
                    htmlText = '<span style="color: ${attrs['color']}">$htmlText</span>';
                  }
                  if (attrs['background'] != null) {
                    htmlText = '<span style="background-color: ${attrs['background']}">$htmlText</span>';
                  }
                }
              }
              
              currentLineText += htmlText;
            }
          }
        } else if (operation.data is Map) {
          // Handle embeds (images, etc.)
          final embed = operation.data as Map<String, dynamic>;
          if (embed.containsKey('image')) {
            // Close current line before adding image
            if (currentLineText.trim().isNotEmpty) {
              if (inList) {
                final closeTag = currentListType == 'ordered' ? '</ol>' : '</ul>';
                htmlBuffer.write(closeTag);
                inList = false;
                currentListType = null;
              }
              htmlBuffer.write('<p>$currentLineText</p>');
              currentLineText = '';
            }
            
            final imageData = embed['image'];
            final base64Image = await _convertImageToBase64(imageData, projectName);
            if (base64Image != null) {
              htmlBuffer.write('<img src="$base64Image" class="evidence-image" alt="Evidence Screenshot" />');
            } else {
              htmlBuffer.write('<div class="image-placeholder">📷 Evidence Screenshot<br><small>Image: $imageData</small></div>');
            }
          } else {
            currentLineText += '<span style="color: #7f8c8d; font-style: italic;">[${embed.keys.first.toUpperCase()}]</span>';
          }
        }
      }
      
      if (inList) {
        final closeTag = currentListType == 'ordered' ? '</ol>' : '</ul>';
        htmlBuffer.write(closeTag);
      }
      
      if (currentLineText.trim().isNotEmpty) {
        htmlBuffer.write('<p>$currentLineText</p>');
      }
      
      return htmlBuffer.toString();
    } catch (e) {
      // Fallback: convert plain text newlines to <br> tags
      return '<p>${_escapeHTML(comment).replaceAll('\n', '<br>')}</p>';
    }
  }
  
  static Future<String?> _convertImageToBase64(dynamic imageSource, String projectName) async {
    try {
      if (imageSource is String) {
        if (imageSource.startsWith('data:image/')) {
          return imageSource; // Already base64
        }

        // Use ImageManager to handle both absolute and relative paths
        final bytes = await ImageManager.readImageBytes(imageSource);
        if (bytes != null) {
          final extension = imageSource.split('.').last.toLowerCase();
          final mimeType = extension == 'png' ? 'image/png' : 'image/jpeg';
          final base64String = base64Encode(bytes);
          return 'data:$mimeType;base64,$base64String';
        }
      }
    } catch (e) {
      // Silent failure
    }
    return null;
  }
  
  static String _escapeHTML(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#x27;');
  }
  
  static String _decodeHtmlEntities(String text) {
    return text
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&amp;', '&');
  }
}