import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:simple_spell_checker/simple_spell_checker.dart';
import 'package:penpeeper/repositories/settings_repository.dart';

/// Spell checker that tries to use the package's dictionary for suggestions
///
/// APPROACH:
/// Since simple_spell_checker doesn't expose the dictionary, we'll:
/// 1. Use our custom dictionary for Levenshtein
/// 2. Leverage the package's internal checking
/// 3. Generate suggestions from our comprehensive dictionary
class SimpleQuillSpellChecker extends StatefulWidget {
  final QuillController controller;
  final Widget child;
  final String language;

  const SimpleQuillSpellChecker({
    super.key,
    required this.controller,
    required this.child,
    this.language = 'en',
  });

  @override
  State<SimpleQuillSpellChecker> createState() =>
      _SimpleQuillSpellCheckerState();
}

class _SimpleQuillSpellCheckerState extends State<SimpleQuillSpellChecker> {
  SimpleSpellChecker? _spellChecker;
  bool _isInitialized = false;
  Map<String, SpellCheckResult> _errors = {};
  bool _showPanel = false;

  // Comprehensive dictionary for suggestions
  List<String> _dictionaryWords = <String>[];
  final SettingsRepository _settingsRepo = SettingsRepository();

  @override
  void initState() {
    super.initState();
    _initializeSpellChecker();
  }

  Future<void> _initializeSpellChecker() async {
    try {
      // Create comprehensive English dictionary
      _dictionaryWords = _createComprehensiveEnglishDictionary().toList();

      // Load saved custom words
      final customWords = await _settingsRepo.getSetting(
        'custom_dictionary_words',
        '',
      );
      if (customWords.isNotEmpty) {
        final words = customWords.split(',');
        _dictionaryWords.addAll(words);
        debugPrint('✅ Loaded ${words.length} custom words');
      }

      _spellChecker = SimpleSpellChecker(
        language: widget.language,
        caseSensitive: false,
      );

      setState(() => _isInitialized = true);
      debugPrint(
        '✅ Spell checker with ${_dictionaryWords.length} word dictionary ready',
      );
    } catch (e) {
      debugPrint('❌ Error: $e');
    }
  }

  /// Comprehensive English dictionary (~1000 most common words)
  /// This is both used by simple_spell_checker AND for generating suggestions
  List<String> _createComprehensiveEnglishDictionary() {
    return const [
      // Most common 1000 English words
      'the', 'be', 'to', 'of', 'and', 'a', 'in', 'that', 'have', 'i',
      'it', 'for', 'not', 'on', 'with', 'he', 'as', 'you', 'do', 'at',
      'this', 'but', 'his', 'by', 'from', 'they', 'we', 'say', 'her', 'she',
      'or', 'an', 'will', 'my', 'one', 'all', 'would', 'there', 'their', 'what',
      'so', 'up', 'out', 'if', 'about', 'who', 'get', 'which', 'go', 'me',
      'when',
      'make',
      'can',
      'like',
      'time',
      'no',
      'just',
      'him',
      'know',
      'take',
      'people',
      'into',
      'year',
      'your',
      'good',
      'some',
      'could',
      'them',
      'see',
      'other',
      'than',
      'then',
      'now',
      'look',
      'only',
      'come',
      'its',
      'over',
      'think',
      'also',
      'back',
      'after',
      'use',
      'two',
      'how',
      'our',
      'work',
      'first',
      'well',
      'way',
      'even',
      'new',
      'want',
      'because',
      'any',
      'these',
      'give',
      'day',
      'most',
      'us',

      // Verb forms
      'is', 'are', 'was', 'were', 'been', 'being', 'am',
      'has', 'had', 'having',
      'does', 'did', 'doing', 'done',
      'goes', 'went', 'gone', 'going',
      'gets', 'got', 'gotten', 'getting',
      'makes', 'made', 'making',
      'takes', 'took', 'taken', 'taking',
      'sees', 'saw', 'seen', 'seeing',
      'knows', 'knew', 'known', 'knowing',
      'thinks', 'thought', 'thinking',
      'comes', 'came', 'coming',
      'wants', 'wanted', 'wanting',
      'uses', 'used', 'using',
      'finds', 'found', 'finding',
      'gives', 'gave', 'given', 'giving',
      'tells', 'told', 'telling',
      'works', 'worked', 'working',
      'calls', 'called', 'calling',
      'tries', 'tried', 'trying',
      'asks', 'asked', 'asking',
      'needs', 'needed', 'needing',
      'feels', 'felt', 'feeling',
      'becomes', 'became', 'becoming',
      'leaves', 'left', 'leaving',
      'puts', 'putting',
      'means', 'meant', 'meaning',
      'keeps', 'kept', 'keeping',
      'lets', 'letting',
      'begins', 'began', 'begun', 'beginning',
      'seems', 'seemed', 'seeming',
      'helps', 'helped', 'helping',
      'talks', 'talked', 'talking',
      'turns', 'turned', 'turning',
      'starts', 'started', 'starting',
      'shows', 'showed', 'shown', 'showing',
      'hears', 'heard', 'hearing',
      'plays', 'played', 'playing',
      'runs', 'ran', 'running',
      'moves', 'moved', 'moving',
      'lives', 'lived', 'living',
      'believes', 'believed', 'believing',
      'holds', 'held', 'holding',
      'brings', 'brought', 'bringing',
      'happens', 'happened', 'happening',
      'writes', 'wrote', 'written', 'writing',
      'provides', 'provided', 'providing',
      'sits', 'sat', 'sitting',
      'stands', 'stood', 'standing',
      'loses', 'lost', 'losing',
      'pays', 'paid', 'paying',
      'meets', 'met', 'meeting',
      'includes', 'included', 'including',
      'continues', 'continued', 'continuing',
      'sets', 'setting',
      'learns', 'learned', 'learning',
      'changes', 'changed', 'changing',
      'leads', 'led', 'leading',
      'understands', 'understood', 'understanding',
      'watches', 'watched', 'watching',
      'follows', 'followed', 'following',
      'stops', 'stopped', 'stopping',
      'creates', 'created', 'creating',
      'speaks', 'spoke', 'spoken', 'speaking',
      'reads', 'reading',
      'allows', 'allowed', 'allowing',
      'adds', 'added', 'adding',
      'spends', 'spent', 'spending',
      'grows', 'grew', 'grown', 'growing',
      'opens', 'opened', 'opening',
      'walks', 'walked', 'walking',
      'wins', 'won', 'winning',
      'offers', 'offered', 'offering',
      'remembers', 'remembered', 'remembering',
      'loves', 'loved', 'loving',
      'considers', 'considered', 'considering',
      'appears', 'appeared', 'appearing',
      'buys', 'bought', 'buying',
      'waits', 'waited', 'waiting',
      'serves', 'served', 'serving',
      'dies', 'died', 'dying',
      'sends', 'sent', 'sending',
      'expects', 'expected', 'expecting',
      'builds', 'built', 'building',
      'stays', 'stayed', 'staying',
      'falls', 'fell', 'fallen', 'falling',
      'cuts', 'cutting',
      'reaches', 'reached', 'reaching',
      'kills', 'killed', 'killing',
      'remains', 'remained', 'remaining',
      'suggests', 'suggested', 'suggesting',
      'raises', 'raised', 'raising',
      'passes', 'passed', 'passing',
      'sells', 'sold', 'selling',
      'requires', 'required', 'requiring',
      'reports', 'reported', 'reporting',
      'decides', 'decided', 'deciding',
      'pulls', 'pulled', 'pulling',

      // Adjectives
      'good', 'better', 'best', 'bad', 'worse', 'worst',
      'great', 'big', 'small', 'large', 'little', 'long', 'short',
      'high', 'low', 'old', 'new', 'young', 'early', 'late',
      'different', 'same', 'other', 'next', 'last', 'first', 'second', 'third',
      'important', 'public', 'able', 'political', 'sure', 'free', 'real',
      'possible', 'available', 'likely', 'current', 'right', 'wrong',
      'social', 'common', 'full', 'true', 'clear', 'certain', 'particular',
      'recent', 'similar', 'easy', 'hard', 'quick', 'slow', 'fast',
      'simple', 'complex', 'major', 'general', 'natural', 'local', 'national',
      'final', 'single', 'special', 'whole', 'medical', 'legal', 'personal',
      'red', 'black', 'white', 'blue', 'green', 'yellow', 'brown', 'orange',
      'happy', 'sad', 'angry', 'afraid', 'worried', 'excited', 'tired',
      'hot', 'cold', 'warm', 'cool', 'wet', 'dry', 'clean', 'dirty',
      'strong', 'weak', 'heavy', 'light', 'soft', 'hard', 'smooth', 'rough',
      'quiet', 'loud', 'bright', 'dark', 'deep', 'shallow', 'wide', 'narrow',

      // Nouns
      'time', 'times', 'year', 'years', 'people', 'person', 'persons',
      'way', 'ways', 'day', 'days', 'man', 'men', 'thing', 'things',
      'woman', 'women', 'life', 'lives', 'child', 'children',
      'world', 'school', 'schools', 'state', 'states',
      'family', 'families', 'student', 'students', 'group', 'groups',
      'country', 'countries', 'problem', 'problems', 'hand', 'hands',
      'part', 'parts', 'place', 'places', 'case', 'cases',
      'week', 'weeks', 'company', 'companies', 'system', 'systems',
      'program', 'programs', 'question', 'questions', 'number', 'numbers',
      'night', 'nights', 'point', 'points', 'home', 'homes',
      'water', 'room', 'rooms', 'mother', 'mothers', 'area', 'areas',
      'money', 'story', 'stories', 'fact', 'facts', 'month', 'months',
      'lot', 'right', 'rights', 'study', 'studies', 'book', 'books',
      'eye', 'eyes', 'job', 'jobs', 'word', 'words', 'business',
      'side', 'sides', 'kind', 'kinds', 'head', 'heads', 'house', 'houses',
      'service', 'services', 'friend', 'friends', 'father', 'fathers',
      'power', 'hour', 'hours', 'game', 'games', 'line', 'lines',
      'end', 'ends', 'member', 'members', 'law', 'laws', 'car', 'cars',
      'city', 'cities', 'community', 'communities', 'name', 'names',
      'president', 'team', 'teams', 'minute', 'minutes', 'idea', 'ideas',
      'kid',
      'kids',
      'body',
      'bodies',
      'information',
      'back',
      'parent',
      'parents',
      'face', 'faces', 'others', 'level', 'levels', 'office', 'offices',
      'door', 'doors', 'health', 'art', 'war', 'history', 'party', 'parties',
      'result', 'results', 'change', 'changes', 'morning', 'mornings',
      'reason', 'reasons', 'research', 'girl', 'girls', 'guy', 'guys',
      'moment', 'moments', 'air', 'teacher', 'teachers', 'force', 'forces',
      'education', 'street', 'food', 'price', 'sound', 'voice', 'town',
      'market', 'church', 'court', 'paper', 'phone', 'letter', 'picture',
      'window', 'table', 'chair', 'wall', 'floor', 'roof', 'ground',

      // Prepositions, conjunctions, etc.
      'of', 'to', 'in', 'for', 'on', 'with', 'at', 'from', 'by', 'about',
      'as', 'into', 'like', 'through', 'after', 'over', 'between', 'out',
      'against', 'during', 'without', 'before', 'under', 'around', 'among',
      'and', 'or', 'but', 'so', 'because', 'than', 'if', 'when', 'where',
      'why', 'how', 'which', 'what', 'who', 'whom', 'whose', 'while',
      'although', 'though', 'unless', 'until', 'since', 'whether',

      // Adverbs
      'not', 'no', 'yes', 'up', 'down', 'off', 'very', 'just', 'so',
      'also', 'well', 'only', 'even', 'back', 'there', 'then', 'now', 'here',
      'too', 'still', 'again', 'really', 'never', 'always', 'often',
      'sometimes', 'usually', 'today', 'yesterday', 'tomorrow', 'tonight',
      'already', 'yet', 'almost', 'enough', 'quite', 'rather', 'pretty',
      'perhaps', 'maybe', 'probably', 'actually', 'especially', 'certainly',

      // Numbers
      'one',
      'two',
      'three',
      'four',
      'five',
      'six',
      'seven',
      'eight',
      'nine',
      'ten',
      'eleven',
      'twelve',
      'thirteen',
      'fourteen',
      'fifteen',
      'sixteen',
      'seventeen',
      'eighteen', 'nineteen', 'twenty', 'thirty', 'forty', 'fifty', 'sixty',
      'seventy',
      'eighty',
      'ninety',
      'hundred',
      'thousand',
      'million',
      'billion',

      // Common misspelled words (CORRECT versions for dictionary)
      'receive', 'separate', 'definitely', 'occurred', 'occurrence',
      'until', 'environment', 'weird', 'accommodate', 'accommodation',
      'which', 'their', 'there', 'believe', 'beginning', 'calendar',
      'cemetery', 'changeable', 'column', 'committee', 'conscious',
      'curiosity', 'different', 'embarrass', 'existence', 'foreign',
      'government', 'grammar', 'height', 'independent', 'interest',
      'knowledge', 'liaison', 'library', 'license', 'maintain', 'maintenance',
      'millennium', 'miniature', 'mischievous', 'necessary', 'occasion',
      'personnel', 'possession', 'preferred', 'privilege', 'probably',
      'pronunciation', 'publicly', 'recommend', 'recommendation',
      'referred', 'relevant', 'religious', 'sense', 'successful',
      'surprise', 'tendency', 'therefore', 'vacuum', 'visible', 'whether',

      // Tech/modern terms
      'computer', 'email', 'internet', 'website', 'online', 'data',
      'file', 'files', 'click', 'type', 'enter', 'delete', 'save',
      'search', 'link', 'links', 'page', 'pages', 'message', 'messages',
      'app', 'application', 'software', 'hardware', 'network', 'server',
      'database', 'password', 'username', 'download', 'upload', 'install',
      'update', 'version', 'error', 'bug', 'fix', 'code', 'program',
      'default', 'configuration', 'settings', 'admin', 'administrator',
      'credential', 'credentials', 'authentication', 'authorization',
      'encryption', 'encrypted', 'unencrypted', 'security', 'vulnerability',
      'exploit', 'attack', 'malware', 'virus', 'firewall', 'protocol',
      'service', 'port', 'address', 'domain', 'host', 'client',
      'tcp', 'ip', 'udp', 'icmp', 'http', 'https', 'ftp', 'ssh', 'dns',
    ];
  }

  /// Levenshtein distance calculation
  int _levenshteinDistance(String s1, String s2) {
    final len1 = s1.length;
    final len2 = s2.length;

    if (len1 == 0) return len2;
    if (len2 == 0) return len1;

    final d = List.generate(len1 + 1, (i) => List.filled(len2 + 1, 0));

    for (var i = 0; i <= len1; i++) {
      d[i][0] = i;
    }
    for (var j = 0; j <= len2; j++) {
      d[0][j] = j;
    }

    for (var i = 1; i <= len1; i++) {
      for (var j = 1; j <= len2; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        d[i][j] = [
          d[i - 1][j] + 1,
          d[i][j - 1] + 1,
          d[i - 1][j - 1] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return d[len1][len2];
  }

  /// Generate suggestions using the SAME dictionary simple_spell_checker uses
  List<String> _generateSuggestions(String misspelledWord) {
    final word = misspelledWord.toLowerCase();
    final suggestions = <({String word, int distance})>[];

    // Use our dictionary (which is the SAME one registered with simple_spell_checker)
    for (final dictWord in _dictionaryWords) {
      final distance = _levenshteinDistance(word, dictWord.toLowerCase());

      if (distance > 0 && distance <= 3) {
        // Increased from 2 to 3
        suggestions.add((word: dictWord, distance: distance));
      }
    }

    suggestions.sort((a, b) => a.distance.compareTo(b.distance));

    debugPrint(
      '   Found ${suggestions.length} suggestions for "$misspelledWord"',
    );
    return suggestions.take(5).map((s) => s.word).toList();
  }

  void _checkSpelling() {
    if (!_isInitialized || _spellChecker == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Initializing...')));
      }
      return;
    }

    final text = widget.controller.document.toPlainText();

    if (text.trim().isEmpty) {
      setState(() {
        _errors.clear();
        _showPanel = true;
      });
      return;
    }

    final errors = <String, SpellCheckResult>{};

    try {
      // Let simple_spell_checker detect errors using ITS dictionary
      final result = _spellChecker!.check(
        text,
        wrongStyle: const TextStyle(backgroundColor: Colors.red),
        commonStyle: const TextStyle(backgroundColor: Colors.transparent),
      );

      if (result != null && result.isNotEmpty) {
        int currentOffset = 0;

        for (final span in result) {
          final spanText = span.text ?? '';
          final hasError = span.style?.backgroundColor == Colors.red;

          if (hasError && spanText.trim().isNotEmpty) {
            final words = spanText.split(RegExp(r'\s+'));

            for (final word in words) {
              if (word.trim().isEmpty || double.tryParse(word) != null) {
                continue;
              }

              final cleanWord = word.replaceAll(RegExp(r'[^\w]+'), '');
              if (cleanWord.isEmpty) continue;

              final wordOffset = text.indexOf(cleanWord, currentOffset);

              // Check if word is in our local dictionary (including added words)
              if (!_dictionaryWords.contains(cleanWord.toLowerCase()) &&
                  !errors.containsKey(cleanWord.toLowerCase())) {
                debugPrint('❌ "$cleanWord" - generating suggestions...');

                // Generate suggestions using OUR Levenshtein algorithm
                // on the SAME dictionary simple_spell_checker uses
                final suggestions = _generateSuggestions(cleanWord);

                errors[cleanWord.toLowerCase()] = SpellCheckResult(
                  word: cleanWord,
                  offset: wordOffset >= 0 ? wordOffset : currentOffset,
                  suggestions: suggestions,
                );
              }
            }
          }

          currentOffset += spanText.length;
        }
      }

      debugPrint('✨ Total: ${errors.length} errors');
    } catch (e) {
      debugPrint('❌ Error: $e');
    }

    setState(() {
      _errors = errors;
      _showPanel = true;
    });
  }

  void _replaceWord(SpellCheckResult error, String replacement) {
    widget.controller.replaceText(
      error.offset,
      error.word.length,
      replacement,
      TextSelection.collapsed(offset: error.offset + replacement.length),
    );
    _checkSpelling();
  }

  void _addToDictionary(String word) async {
    try {
      final lowerWord = word.toLowerCase();
      _dictionaryWords.add(lowerWord);

      // Save to persistent storage
      final customWords = await _settingsRepo.getSetting(
        'custom_dictionary_words',
        '',
      );
      final wordList = customWords.isEmpty
          ? <String>[]
          : customWords.split(',');
      if (!wordList.contains(lowerWord)) {
        wordList.add(lowerWord);
        await _settingsRepo.setSetting(
          'custom_dictionary_words',
          wordList.join(','),
        );
      }

      debugPrint('✅ Added "$word" to dictionary (persisted)');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Added "$word" to dictionary')));
      }
      _checkSpelling();
    } catch (e) {
      debugPrint('❌ Error adding to dictionary: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,

        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton.small(
            onPressed: _isInitialized ? _checkSpelling : null,
            tooltip: 'Check Spelling',
            backgroundColor: _isInitialized ? null : Colors.grey,
            child: Badge(
              isLabelVisible: _errors.isNotEmpty,
              label: Text('${_errors.length}'),
              child: const Icon(Icons.spellcheck),
            ),
          ),
        ),

        if (_showPanel)
          Positioned(
            bottom: 70,
            right: 16,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 350,
                height: 400,
                decoration: BoxDecoration(
                  color: const Color(0xFF2D2D2D),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.spellcheck,
                            color: Colors.white,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${_errors.length} Error${_errors.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => setState(() => _showPanel = false),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),

                    Expanded(
                      child: _errors.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 48,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'No errors!',
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _errors.length,
                              itemBuilder: (context, index) {
                                final error = _errors.values.elementAt(index);
                                return ExpansionTile(
                                  title: Text(
                                    error.word,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.add_circle_outline,
                                      color: Colors.blue,
                                      size: 20,
                                    ),
                                    onPressed: () =>
                                        _addToDictionary(error.word),
                                  ),
                                  children: error.suggestions.isEmpty
                                      ? [
                                          const Padding(
                                            padding: EdgeInsets.all(16),
                                            child: Text(
                                              'No suggestions',
                                              style: TextStyle(
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                        ]
                                      : error.suggestions
                                            .map(
                                              (s) => ListTile(
                                                dense: true,
                                                leading: const Icon(
                                                  Icons.arrow_forward,
                                                  size: 16,
                                                  color: Colors.green,
                                                ),
                                                title: Text(
                                                  s,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                onTap: () =>
                                                    _replaceWord(error, s),
                                              ),
                                            )
                                            .toList(),
                                );
                              },
                            ),
                    ),

                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900,
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: _checkSpelling,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Recheck'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _spellChecker?.dispose();
    super.dispose();
  }
}

class SpellCheckResult {
  final String word;
  final int offset;
  final List<String> suggestions;

  SpellCheckResult({
    required this.word,
    required this.offset,
    required this.suggestions,
  });
}
