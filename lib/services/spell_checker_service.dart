import 'package:flutter/material.dart';
import 'package:simple_spell_checker/simple_spell_checker.dart';

class SpellChecker {
  final SimpleSpellChecker _checker;
  
  SpellChecker({required String language}) 
      : _checker = SimpleSpellChecker(language: language, caseSensitive: false);

  Future<void> load() async {
    // SimpleSpellChecker initializes in constructor
  }

  List<String> checkText(String text) {
    debugPrint('🔍 Checking text (${text.length} chars): "${text.substring(0, text.length > 50 ? 50 : text.length)}${text.length > 50 ? '...' : ''}"');
    
    final result = _checker.check(
      text,
      wrongStyle: const TextStyle(backgroundColor: Colors.red),
      commonStyle: const TextStyle(backgroundColor: Colors.transparent),
    );
    
    debugPrint('📊 Check returned: ${result?.length ?? 0} TextSpans');
    
    final errors = <String>{};
    
    if (result != null && result.isNotEmpty) {
      for (final span in result) {
        final hasError = span.style?.backgroundColor == Colors.red;
        if (hasError && span.text != null) {
          // Extract words from the error span
          final words = span.text!.split(RegExp(r'\s+'));
          for (final word in words) {
            final cleanWord = word.trim();
            if (cleanWord.isNotEmpty && cleanWord.length > 1) {
              errors.add(cleanWord);
              debugPrint('❌ Found misspelled: "$cleanWord"');
            }
          }
        }
      }
    }
    
    debugPrint('✨ Total unique errors found: ${errors.length}');
    return errors.toList();
  }

  bool check(String word) {
    // Legacy method for backward compatibility
    final errors = checkText(word);
    return !errors.contains(word);
  }

  List<String> suggestions(String word) {
    debugPrint('🔍 Getting suggestions for: "$word"');
    final suggestions = <String>[];
    final lowerWord = word.toLowerCase();
    
    // Common misspellings map
    final commonSubs = {
      'teh': ['the'],
      'recieve': ['receive'],
      'seperate': ['separate'],
      'definately': ['definitely'],
      'occured': ['occurred'],
      'neccessary': ['necessary'],
      'quik': ['quick'],
      'wich': ['which', 'witch'],
      'thier': ['their', 'there'],
      'youre': ['you\'re', 'your'],
      'its': ['it\'s'],
      'alot': ['a lot'],
      'cant': ['can\'t'],
      'wont': ['won\'t'],
      'dont': ['don\'t'],
    };
    
    // Check exact match first
    if (commonSubs.containsKey(lowerWord)) {
      suggestions.addAll(commonSubs[lowerWord]!);
    } else {
      // Generate basic suggestions for any word
      suggestions.addAll(_generateBasicSuggestions(word));
    }
    
    debugPrint('💡 Generated ${suggestions.length} suggestions: $suggestions');
    return suggestions.take(5).toList();
  }
  
  List<String> _generateBasicSuggestions(String word) {
    final suggestions = <String>[];
    final commonWords = ['the', 'and', 'that', 'have', 'for', 'not', 'with', 'you', 'this', 'but', 'his', 'from', 'they', 'she', 'her', 'been', 'than', 'its', 'now', 'more', 'very', 'what', 'know', 'just', 'first', 'get', 'over', 'think', 'also', 'your', 'work', 'life', 'only', 'can', 'still', 'should', 'after', 'being', 'now', 'made', 'before', 'here', 'through', 'when', 'where', 'much', 'go', 'me', 'world', 'too', 'any', 'may', 'say', 'these', 'so', 'try', 'her', 'way', 'many', 'then', 'them', 'write', 'would', 'like', 'so', 'these', 'her', 'long', 'make', 'thing', 'see', 'him', 'two', 'more', 'go', 'no', 'way', 'could', 'my', 'than', 'first', 'been', 'call', 'who', 'oil', 'sit', 'now', 'find', 'down', 'day', 'did', 'get', 'come', 'made', 'may', 'part'];
    
    // Find words with similar length and starting letter
    for (final commonWord in commonWords) {
      if (commonWord.length == word.length && 
          commonWord[0].toLowerCase() == word[0].toLowerCase()) {
        suggestions.add(commonWord);
      }
    }
    
    // If no similar words found, add some basic alternatives
    if (suggestions.isEmpty) {
      if (word.length > 3) {
        suggestions.add(word.substring(0, word.length - 1)); // Remove last letter
        suggestions.add('${word}e'); // Add 'e' at end
        suggestions.add('${word}s'); // Add 's' at end
      }
    }
    
    return suggestions;
  }

  void addWord(String word) {
    try {
      SimpleSpellChecker.learnWord(_checker.getCurrentLanguage(), word);
      debugPrint('✅ Added "$word" to dictionary');
    } catch (e) {
      debugPrint('❌ Failed to add "$word" to dictionary: $e');
    }
  }

  void removeWord(String word) {
    SimpleSpellChecker.unlearnWord(_checker.getCurrentLanguage(), word);
  }
}
