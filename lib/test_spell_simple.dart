import 'package:flutter/material.dart';
import 'package:penpeeper/services/spell_checker_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final checker = SpellChecker(language: 'en');
  await checker.load();
  
  final text = 'credendials';
  
  print('Testing word: $text');
  final isCorrect = checker.check(text);
  print('Is correct: $isCorrect');
  
  if (!isCorrect) {
    print('Word is misspelled!');
  } else {
    print('Word is correct');
  }
}
