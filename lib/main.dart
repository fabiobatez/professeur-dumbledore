import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:audioplayers/audioplayers.dart';
import 'recorder.dart';
import 'patronus_loader.dart';
import 'magic_background.dart';
import 'animated_gradient_text.dart';
import 'patronus_demo_page.dart';

void main() => runApp(const DumbledoreApp());

class DumbledoreApp extends StatelessWidget {
  const DumbledoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Professeur Dumbledore',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6A1B9A), // Deep Purple
          brightness: Brightness.dark,
          primary: const Color(0xFFAB47BC),
          secondary: const Color(0xFF26C6DA),
          surface: const Color(0xFF1E1E2C),
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF0A0B10),
        cardTheme: CardTheme(
          color: const Color(0xFF1E1E2C).withOpacity(0.8),
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
          bodyLarge: TextStyle(fontSize: 16),
        ),
      ),
      home: const VoiceCoachPage(),
    );
  }
}

class Spell {
  final String name;
  final List<String> aliases;

  Spell({required this.name, required this.aliases});

  factory Spell.fromJson(Map<String, dynamic> j) {
    return Spell(
      name: j['name'] as String,
      aliases: (j['aliases'] as List<dynamic>).map((e) => e as String).toList(),
    );
  }
}

class SpellMatch {
  final Spell spell;
  final double score; // 0..1
  const SpellMatch(this.spell, this.score);
}

enum PronunciationStatus { accepted, almost, rejected, technical }

class PronunciationResult {
  final PronunciationStatus status;
  final double confidence;
  final String predicted;
  final String? reason; // explication courte
  final List<String> suggestions; // aides
  final List<String> flaggedSyllables; // pour l'affichage
  const PronunciationResult({
    required this.status,
    required this.confidence,
    required this.predicted,
    this.reason,
    this.suggestions = const [],
    this.flaggedSyllables = const [],
  });
}

class SpellMatcher {
  final List<Spell> spells;
  SpellMatcher(this.spells);

  static String _normalize(String s) {
    final lower = s.toLowerCase();
    final replaced = lower
        .replaceAll(RegExp(r"[^a-zàâãäåæçéèêëîïñôöœùûüÿ' ]"), ' ')
        .replaceAll("'", ' ')
        .replaceAll(RegExp(r"\s+"), ' ') // collapse spaces
        .trim();
    return replaced;
  }

  static int _levenshtein(String a, String b) {
    // Simple Levenshtein distance (iterative DP)
    final m = a.length;
    final n = b.length;
    if (m == 0) return n;
    if (n == 0) return m;
    final dp = List.generate(m + 1, (_) => List<int>.filled(n + 1, 0));
    for (var i = 0; i <= m; i++) dp[i][0] = i;
    for (var j = 0; j <= n; j++) dp[0][j] = j;
    for (var i = 1; i <= m; i++) {
      for (var j = 1; j <= n; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        dp[i][j] = [
          dp[i - 1][j] + 1,
          dp[i][j - 1] + 1,
          dp[i - 1][j - 1] + cost,
        ].reduce((v, e) => v < e ? v : e);
      }
    }
    return dp[m][n];
  }

  static double _similarity(String a, String b) {
    final na = _normalize(a);
    final nb = _normalize(b);
    final maxLen = (na.length > nb.length ? na.length : nb.length);
    if (maxLen == 0) return 0.0;
    final dist = _levenshtein(na, nb);
    return 1.0 - (dist / maxLen);
  }

  SpellMatch bestMatch(String input) {
    final norm = _normalize(input);
    Spell? best;
    double bestScore = 0.0;
    for (final s in spells) {
      final candidates = [s.name, ...s.aliases];
      for (final c in candidates) {
        final sc = _similarity(norm, c);
        if (sc > bestScore) {
          bestScore = sc;
          best = s;
        }
      }
    }
    return SpellMatch(best ?? spells.first, bestScore);
  }

  double scoreAgainst(String input, Spell target) {
    final candidates = [target.name, ...target.aliases];
    final norm = _normalize(input);
    double best = 0.0;
    for (final c in candidates) {
      final sc = _similarity(norm, c);
      if (sc > best) best = sc;
    }
    return best;
  }
}

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Container(
            padding: padding ?? const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface.withOpacity(0.4),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

class VoiceCoachPage extends StatefulWidget {
  const VoiceCoachPage({super.key});
  @override
  State<VoiceCoachPage> createState() => _VoiceCoachPageState();
}

class _VoiceCoachPageState extends State<VoiceCoachPage> {
  final FlutterTts _tts = FlutterTts();
  final stt.SpeechToText _stt = stt.SpeechToText();
  final AudioPlayer _player = AudioPlayer();
  Recorder? _recorder;
  bool _showLoader = true;
  bool _sttReady = false;
  bool _listening = false;
  bool _recording = false;
  bool _playing = false;
  String _recognized = '';
  List<Spell> _spells = [];
  SpellMatcher? _matcher;
  SpellMatch? _last;
  // Exercice guidé
  Spell? _target;
  bool _training = false;
  int _attempts = 0;
  double _threshold = 0.85; // exigence de correspondance
  DateTime? _busyUntil; // debounce après résultat
  DateTime? _listenStarted; // mesure de durée
  final int _maxAttempts = 5;
  final List<PronunciationResult> _history = [];
  bool _countdown = false;

  @override
  void initState() {
    super.initState();
    _loadSpells();
    _initTts();
    _initStt();
    _recorder = Recorder();
  }

  Future<void> _loadSpells() async {
    final raw = await rootBundle.loadString('assets/spells.json');
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final list = (j['spells'] as List).map((e) => Spell.fromJson(e)).toList();
    setState(() {
      _spells = list;
      _matcher = SpellMatcher(_spells);
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _showLoader = false);
    });
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('fr-FR');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(0.9);
  }

  Future<void> _initStt() async {
    try {
      final available = await _stt.initialize(
        onStatus: (s) => setState(() => _listening = s == 'listening'),
        onError: (e) => debugPrint('STT error: $e'),
      );
      setState(() => _sttReady = available);
    } catch (e) {
      debugPrint('Speech init failed: $e');
      setState(() => _sttReady = false);
    }
  }

  Future<void> _startListen() async {
    if (!_sttReady) return;
    if (_busyUntil != null && DateTime.now().isBefore(_busyUntil!)) return;
    setState(() {
      _recognized = '';
      _listening = true;
      _countdown = true;
    });
    // petit compte à rebours (2s)
    await Future.delayed(const Duration(seconds: 2));
    setState(() => _countdown = false);
    _listenStarted = DateTime.now();
    // démarre l'enregistrement audio en parallèle
    await _startRecording();
    await _stt.listen(
      localeId: 'fr_FR',
      partialResults: true,
      onResult: (res) {
        setState(() {
          _recognized = res.recognizedWords;
          if (_target != null && _matcher != null) {
            final sc = _matcher!.scoreAgainst(_recognized, _target!);
            _last = SpellMatch(_target!, sc);
          } else if (_matcher != null) {
            _last = _matcher!.bestMatch(_recognized);
          }
        });
      },
    );
  }

  Future<void> _stopListen() async {
    await _stt.stop();
    await _stopRecording();
    setState(() => _listening = false);
    _giveFeedback();
    _busyUntil = DateTime.now().add(const Duration(seconds: 1));
  }

  Future<void> _giveFeedback() async {
    if (_last == null) return;
    final s = _last!;
    final scorePct = (s.score * 100).round();
    if (s.score > 0.80) {
      await _tts.speak('Parfait ! ${s.spell.name} à ${scorePct} pour cent.');
    } else if (s.score > 0.60) {
      await _tts.speak(
          'Bien joué, mais on peut améliorer. Tu as dit ${s.spell.name} à ${scorePct} pour cent.');
    } else {
      await _tts.speak(
          "Hmm, je n'ai pas bien reconnu. Essaie de prononcer ${s.spell.name} avec clarté.");
    }
  }

  // --- Mode exercice: on relance jusqu'à correspondance ---
  Future<void> _startTraining(Spell target) async {
    setState(() {
      _target = target;
      _training = true;
      _attempts = 0;
      _recognized = '';
      _last = null;
      _history.clear();
      _lastRecordingPath = null;
      _playing = false;
    });
    await _tts.speak('Prononce: ${target.name}');
    await _newAttempt();
  }

  Future<void> _listenAttempt() async {
    if (!_sttReady) {
      await _tts.speak('Le micro n’est pas disponible. Vérifie les permissions et réessaie.');
      return;
    }
    _listenStarted = DateTime.now();
    await _startRecording();
    await _stt.listen(
      localeId: 'fr_FR',
      partialResults: true,
      onResult: (res) async {
        // Mise à jour en temps réel
        final wordsLive = res.recognizedWords;
        setState(() {
          _recognized = wordsLive;
          if (_target != null && _matcher != null) {
            final scLive = _matcher!.scoreAgainst(wordsLive, _target!);
            _last = SpellMatch(_target!, scLive);
          }
        });
        if (!res.finalResult) return;
        final words = res.recognizedWords;
        final target = _target;
        if (target == null) return;
        final score = _matcher?.scoreAgainst(words, target) ?? 0.0;
        final duration = _listenStarted == null
            ? 0.0
            : DateTime.now().difference(_listenStarted!).inMilliseconds / 1000.0;
        final result = _buildResult(words, target, score, duration,
            sttConfidence: res.hasConfidenceRating ? res.confidence : null);
        setState(() {
          _recognized = words;
          _last = SpellMatch(target, score);
          _attempts += 1;
          _history.insert(0, result);
          if (_history.length > 5) _history.removeLast();
        });
        await _stt.stop();
        await _stopRecording();
        if (result.status == PronunciationStatus.accepted) {
          setState(() => _training = false);
          await _tts.speak('Bravo ! ${target.name} bien prononcé.');
        } else {
          final msg = result.status == PronunciationStatus.almost
              ? 'Presque ! ${result.reason ?? ''} Recommence: ${target.name}.'
              : 'Pas encore, on reprend. Essaie de dire: ${target.name}.';
          await _tts.speak(msg);
          if (_attempts >= _maxAttempts) {
            await _tts.speak('Proposons un exercice ciblé.');
            // Placeholder: jouer la référence lentement
            await _tts.setSpeechRate(0.35);
            await _tts.speak('Référence: ${target.name}');
            await _tts.setSpeechRate(0.45);
            setState(() {});
          } else {
            await Future.delayed(const Duration(milliseconds: 700));
            await _listenAttempt();
          }
        }
      },
    );
  }

  Future<void> _newAttempt() async {
    // Stop any ongoing listen/play/record and clear current attempt state
    try {
      await _stt.stop();
    } catch (_) {}
    try {
      await _player.stop();
    } catch (_) {}
    await _stopRecording();
    setState(() {
      _recognized = '';
      _last = null;
      _lastRecordingPath = null;
      _playing = false;
      _listening = false;
      _countdown = true;
    });
    await Future.delayed(const Duration(seconds: 2));
    setState(() => _countdown = false);
    await _listenAttempt();
  }

  Future<void> _startRecording() async {
    try {
      final hasPerm = await _recorder?.hasPermission() ?? false;
      if (!hasPerm) {
        debugPrint('Record: permission manquante');
        return;
      }
      await _recorder!.start();
      setState(() => _recording = true);
    } catch (e) {
      debugPrint('Record start error: $e');
    }
  }

  String? _lastRecordingPath;
  Future<void> _stopRecording() async {
    try {
      final path = await _recorder?.stop();
      setState(() {
        _recording = false;
        _lastRecordingPath = path;
      });
    } catch (e) {
      debugPrint('Record stop error: $e');
    }
  }

  Future<void> _playLastRecording() async {
    final p = _lastRecordingPath;
    if (p == null || p.isEmpty) return;
    try {
      await _player.stop();
      if (kIsWeb) {
        await _player.play(UrlSource(p));
      } else {
        await _player.play(DeviceFileSource(p));
      }
      setState(() => _playing = true);
      _player.onPlayerComplete.listen((_) {
        setState(() => _playing = false);
      });
    } catch (e) {
      debugPrint('Play error: $e');
    }
  }

  PronunciationResult _buildResult(String input, Spell target, double score, double duration,
      {double? sttConfidence}) {
    // Heuristiques basiques pour les états et raisons
    final trimmed = input.trim();
    final wordsCount = trimmed.isEmpty ? 0 : trimmed.split(RegExp(r"\s+")).length;
    final bool tooShort = duration < 0.8 || wordsCount < 1 || trimmed.length < 3;
    final bool multiWords = wordsCount > target.name.split(RegExp(r"\s+")).length + 1;
    final bool lowSnr = (sttConfidence != null && sttConfidence < 0.35);

    if (!_sttReady) {
      return PronunciationResult(
        status: PronunciationStatus.technical,
        confidence: score,
        predicted: trimmed,
        reason: 'Micro non disponible',
        suggestions: const ['Vérifie les permissions du micro.'],
      );
    }

    if (lowSnr) {
      return PronunciationResult(
        status: PronunciationStatus.rejected,
        confidence: score,
        predicted: trimmed,
        reason: 'Trop de bruit / confiance faible',
        suggestions: const ['Rapproche-toi du micro', 'Parle dans un endroit calme'],
      );
    }

    if (tooShort) {
      return PronunciationResult(
        status: PronunciationStatus.rejected,
        confidence: score,
        predicted: trimmed,
        reason: 'Trop court — dis la formule en entier',
        suggestions: ['Prononce clairement ${target.name}'],
      );
    }

    if (multiWords) {
      return PronunciationResult(
        status: PronunciationStatus.rejected,
        confidence: score,
        predicted: trimmed,
        reason: 'Plusieurs mots détectés — ne dis que la formule',
        suggestions: ['Ne rajoute pas de phrase autour'],
      );
    }

    if (score >= _threshold) {
      return PronunciationResult(
        status: PronunciationStatus.accepted,
        confidence: score,
        predicted: trimmed,
        reason: 'Prononciation correcte',
        suggestions: const ['Excellent !'],
      );
    }
    if (score >= 0.60) {
      final flagged = _flagSyllables(target.name, trimmed);
      return PronunciationResult(
        status: PronunciationStatus.almost,
        confidence: score,
        predicted: trimmed,
        reason: flagged.isNotEmpty
            ? "Syllabe(s) faible(s): ${flagged.join(', ')}"
            : 'Améliore l’articulation',
        suggestions: const ['Accentue les consonnes', 'Sépare bien les syllabes'],
        flaggedSyllables: flagged,
      );
    }
    final flagged = _flagSyllables(target.name, trimmed);
    return PronunciationResult(
      status: PronunciationStatus.rejected,
      confidence: score,
      predicted: trimmed,
      reason: flagged.isNotEmpty
          ? "Syllabe(s) manquante(s) / erronée(s): ${flagged.join(', ')}"
          : 'Mot différent',
      suggestions: const ['Réessaie en prononçant calmement', 'Regarde la prononciation de référence'],
      flaggedSyllables: flagged,
    );
  }

  List<String> _syllabify(String s) {
    // Découpage simple par groupes voyelles/consonnes
    final norm = s.toLowerCase().replaceAll(RegExp(r"[^a-zàâãäåæçéèêëîïñôöœùûüÿ ]"), '');
    final tokens = <String>[];
    var buf = '';
    bool lastWasVowel = false;
    bool isVowel(String ch) => RegExp(r"[aeiouyàâäéèêëîïôöùûü]").hasMatch(ch);
    for (final ch in norm.characters) {
      if (ch == ' ') {
        if (buf.isNotEmpty) tokens.add(buf);
        buf = '';
        continue;
      }
      final v = isVowel(ch);
      if (buf.isEmpty) {
        buf = ch;
        lastWasVowel = v;
      } else if (v != lastWasVowel) {
        tokens.add(buf);
        buf = ch;
        lastWasVowel = v;
      } else {
        buf += ch;
      }
    }
    if (buf.isNotEmpty) tokens.add(buf);
    // Regroupe syllabes très courtes avec la suivante
    final merged = <String>[];
    for (var i = 0; i < tokens.length; i++) {
      if (tokens[i].length == 1 && i + 1 < tokens.length) {
        merged.add(tokens[i] + tokens[i + 1]);
        i++;
      } else {
        merged.add(tokens[i]);
      }
    }
    return merged;
  }

  List<String> _flagSyllables(String expected, String said) {
    final e = _syllabify(expected);
    final s = _syllabify(said);
    final flagged = <String>[];
    final len = e.length < s.length ? e.length : s.length;
    for (var i = 0; i < len; i++) {
      final sim = SpellMatcher._similarity(e[i], s[i]);
      if (sim < 0.70) flagged.add(e[i]);
    }
    // syllabes manquantes
    if (s.length < e.length) {
      flagged.addAll(e.sublist(s.length));
    }
    return flagged;
  }

  Widget _controls() {
    // Affiche les boutons micro sur toutes les plateformes quand STT est prêt
    if (_sttReady) {
      final btnStyle = ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.8),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        elevation: 8,
        shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.5),
      );

      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_training && !_listening)
            ElevatedButton.icon(
              onPressed: _newAttempt,
              icon: const Icon(Icons.mic, size: 28),
              label: const Text('PARLER', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              style: btnStyle.copyWith(
                backgroundColor: MaterialStateProperty.all(const Color(0xFFD81B60)),
              ),
            ),
          if (_listening)
            ElevatedButton.icon(
              onPressed: _stopListen,
              icon: const Icon(Icons.stop_circle_outlined, size: 28),
              label: const Text('ARRÊTER', style: TextStyle(fontWeight: FontWeight.bold)),
              style: btnStyle.copyWith(
                backgroundColor: MaterialStateProperty.all(Colors.redAccent),
              ),
            ),
          if (!_listening && _lastRecordingPath != null) ...[
            const SizedBox(width: 16),
            ElevatedButton.icon(
              onPressed: _playLastRecording,
              icon: Icon(_playing ? Icons.volume_up : Icons.play_arrow),
              label: Text(_playing ? 'LECTURE...' : 'RÉÉCOUTER'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white10,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                  side: BorderSide(color: Colors.white.withOpacity(0.2)),
                ),
              ),
            ),
          ],
        ],
      );
    }
    // STT indisponible: message de diagnostic et réinitialisation
    return Column(
      children: [
        const Text(
          'Micro non disponible — Autorise l’accès au micro dans le navigateur et réessaie.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _initStt,
          icon: const Icon(Icons.mic_off),
          label: const Text("Activer le micro"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white10,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final match = _last;
    final score = match?.score ?? 0.0;
    final pct = (score * 100).toStringAsFixed(0);
    return Stack(
      children: [
        const Positioned.fill(child: MagicBackground(intensity: 0.9)),
        Scaffold(
          appBar: AppBar(
            title: const AnimatedGradientText('Professeur Dumbledore'),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                tooltip: 'Patronus',
                icon: const Icon(Icons.auto_awesome),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PatronusDemoPage()),
                  );
                },
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_target == null)
                  Text(
                    'Choisis un sort pour t’entraîner',
                    style: Theme.of(context).textTheme.titleMedium,
                  )
                else
                  Text(
                    'Exercice: ${_target!.name}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                const SizedBox(height: 12),
                _controls(),
                if (_countdown)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('Prêt… Parlez', textAlign: TextAlign.center),
                  ),
                const SizedBox(height: 24),
                GlassCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.mic, color: Theme.of(context).colorScheme.secondary, size: 20),
                          const SizedBox(width: 8),
                          Text('Reconnu', style: Theme.of(context).textTheme.bodySmall),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _recognized.isEmpty ? '...' : _recognized,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: score == 0 ? null : score,
                          minHeight: 8,
                          backgroundColor: Colors.white10,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            score > 0.8 ? Colors.greenAccent : (score > 0.5 ? Colors.orangeAccent : Colors.redAccent),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (match != null)
                        Row(
                          children: [
                            const Text('Meilleure correspondance : ', style: TextStyle(color: Colors.white70)),
                            Expanded(
                              child: Text(
                                '${match.spell.name} (\u2248 $pct%)',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (_training && _target != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black26,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Exercice : ${_target!.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                              Text('Tentatives : $_attempts'),
                            ],
                          ),
                        ),
                      ],
                      if (_history.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _history.map((h) {
                            Color c;
                            Color textC = Colors.black87;
                            switch (h.status) {
                              case PronunciationStatus.accepted:
                                c = Colors.greenAccent.withOpacity(0.2);
                                textC = Colors.greenAccent;
                                break;
                              case PronunciationStatus.almost:
                                c = Colors.orangeAccent.withOpacity(0.2);
                                textC = Colors.orangeAccent;
                                break;
                              case PronunciationStatus.rejected:
                                c = Colors.redAccent.withOpacity(0.2);
                                textC = Colors.redAccent;
                                break;
                              case PronunciationStatus.technical:
                                c = Colors.grey.withOpacity(0.2);
                                textC = Colors.grey;
                                break;
                            }
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: c,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: textC.withOpacity(0.3)),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${(h.confidence * 100).round()}% • ${h.predicted}',
                                    style: TextStyle(color: textC, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                  if (h.reason != null)
                                    Text(
                                      h.reason!,
                                      style: TextStyle(color: textC.withOpacity(0.8), fontSize: 10),
                                    ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(child: _spellsGrid()),
              ],
            ),
          ),
        ),
        if (_showLoader)
          Positioned.fill(
            child: PatronusLoader(
              duration: const Duration(milliseconds: 1800),
              onCompleted: () {
                if (mounted) setState(() => _showLoader = false);
              },
            ),
          ),
      ],
    );
  }

  Widget _spellsGrid() {
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.1,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _spells.length,
      itemBuilder: (ctx, i) {
        final s = _spells[i];
        final isLong = s.name.length >= 10;
        return GlassCard(
          onTap: () => _startTraining(s),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_fix_high,
                      size: 20,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                  if (isLong)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text('Expert', style: TextStyle(fontSize: 10, color: Colors.amber)),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                s.name,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.2,
                    ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Prononciation',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white60,
                    ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _tts.stop();
    _stt.cancel();
    _player.dispose();
    super.dispose();
  }
}
