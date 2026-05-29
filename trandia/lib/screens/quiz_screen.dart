import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/quiz_model.dart';
import '../services/quiz_service.dart';
import 'glass_common.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry point — shows loading state while quiz fetches, then starts quiz
// ─────────────────────────────────────────────────────────────────────────────

class QuizLoadingScreen extends StatefulWidget {
  final String quizId;
  const QuizLoadingScreen({super.key, required this.quizId});

  @override
  State<QuizLoadingScreen> createState() => _QuizLoadingScreenState();
}

class _QuizLoadingScreenState extends State<QuizLoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;
  Timer? _pollTimer;
  int _attempts = 0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _startPolling();
  }

  @override
  void dispose() {
    _pulse.dispose();
    _pollTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _poll();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) => _poll());
  }

  Future<void> _poll() async {
    if (!mounted) return;
    _attempts++;
    if (_attempts > 20) {
      _pollTimer?.cancel();
      if (mounted) _showError('Quiz generation failed. Try again later.');
      return;
    }
    final quiz = await QuizService.getQuiz(widget.quizId);
    if (!mounted) return;
    if (quiz == null) return;
    if (quiz.status == 'ready') {
      _pollTimer?.cancel();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => QuizScreen(quiz: quiz)),
      );
    } else if (quiz.status == 'failed') {
      _pollTimer?.cancel();
      _showError('Quiz generation failed. Try again later.');
    }
  }

  void _showError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF111111),
        title: const Text('Oops!', style: TextStyle(color: Colors.white)),
        content: Text(msg, style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context); },
            child: const Text('OK', style: TextStyle(color: Color(0xFF00E676))),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulse,
              builder: (_, __) => Opacity(
                opacity: 0.6 + _pulse.value * 0.4,
                child: Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00E676), Color(0xFF00BCD4)],
                    ),
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF00E676).withOpacity(0.4), blurRadius: 30),
                    ],
                  ),
                  child: const Icon(Icons.psychology_rounded, color: Colors.black, size: 40),
                ),
              ),
            ),
            const SizedBox(height: 28),
            Text('Quiz Ban Raha Hai...', style: manrope(size: 18, weight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text('AI questions generate kar raha hai', style: manrope(size: 13, color: Colors.white54)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Main Quiz Screen
// ─────────────────────────────────────────────────────────────────────────────

class QuizScreen extends StatefulWidget {
  final QuizModel quiz;
  const QuizScreen({super.key, required this.quiz});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;
  final List<int?> _selectedAnswers = List.filled(5, null);
  final List<double> _timePerQuestion = List.filled(5, 0);
  late DateTime _questionStartTime;
  bool _answered = false;
  bool _submitting = false;
  QuizSubmitResult? _result;

  late AnimationController _slideCtrl;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _questionStartTime = DateTime.now();
    _slideCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _slideAnim = Tween<Offset>(begin: const Offset(0.08, 0), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOut));
    _slideCtrl.forward();
  }

  @override
  void dispose() {
    _slideCtrl.dispose();
    super.dispose();
  }

  QuizQuestion get _current => widget.quiz.questions[_currentIndex];

  void _selectAnswer(int idx) {
    if (_answered) return;
    HapticFeedback.selectionClick();
    final elapsed = DateTime.now().difference(_questionStartTime).inMilliseconds / 1000;
    setState(() {
      _selectedAnswers[_currentIndex] = idx;
      _timePerQuestion[_currentIndex] = elapsed;
      _answered = true;
    });
  }

  void _nextQuestion() {
    if (_currentIndex < 4) {
      _slideCtrl.reset();
      setState(() {
        _currentIndex++;
        _answered = _selectedAnswers[_currentIndex] != null;
        _questionStartTime = DateTime.now();
      });
      _slideCtrl.forward();
    } else {
      _submitQuiz();
    }
  }

  Future<void> _submitQuiz() async {
    setState(() => _submitting = true);
    final answers = _selectedAnswers.map((a) => a ?? 0).toList();
    final times = _timePerQuestion.map((t) => t < 8 ? 8.0 : t).toList();
    final result = await QuizService.submitQuiz(
      quizId: widget.quiz.quizId,
      answers: answers,
      timePerQuestion: times,
    );
    if (!mounted) return;
    setState(() { _result = result; _submitting = false; });
  }

  Color _diffColor(String d) {
    switch (d) {
      case 'saral': return const Color(0xFF00E676);
      case 'samanya': return const Color(0xFF40C4FF);
      case 'kathin': return const Color(0xFFFF6B6B);
      default: return Colors.white54;
    }
  }

  String _diffLabel(String d) {
    switch (d) {
      case 'saral': return 'Saral';
      case 'samanya': return 'Samanya';
      case 'kathin': return 'Kathin';
      default: return d;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_result != null) return _ResultScreen(result: _result!, quiz: widget.quiz);
    if (_submitting) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const CircularProgressIndicator(color: Color(0xFF00E676)),
            const SizedBox(height: 16),
            Text('Submit ho raha hai...', style: manrope(size: 15)),
          ]),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildProgressBar(),
            Expanded(
              child: SlideTransition(
                position: _slideAnim,
                child: _buildQuestionCard(),
              ),
            ),
            _buildNextButton(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.close_rounded, color: Colors.white70, size: 20),
            ),
          ),
          const Spacer(),
          Text(
            'Q${_currentIndex + 1} / 5',
            style: manrope(size: 14, weight: FontWeight.w700, color: Colors.white70),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _diffColor(_current.difficulty).withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _diffColor(_current.difficulty).withOpacity(0.4)),
            ),
            child: Text(
              _diffLabel(_current.difficulty),
              style: manrope(size: 11, weight: FontWeight.w700, color: _diffColor(_current.difficulty)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: List.generate(5, (i) {
          Color color;
          if (i < _currentIndex) color = const Color(0xFF00E676);
          else if (i == _currentIndex) color = const Color(0xFF00E676).withOpacity(0.5);
          else color = Colors.white12;
          return Expanded(
            child: Container(
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildQuestionCard() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                ),
                child: Text(
                  _current.questionText,
                  style: manrope(size: 16, weight: FontWeight.w600, height: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(_current.options.length, (i) => _buildOption(i)),
          if (_answered && _selectedAnswers[_currentIndex] != _current.correctAnswerIndex)
            _buildExplanation(),
        ],
      ),
    );
  }

  Widget _buildOption(int i) {
    final selected = _selectedAnswers[_currentIndex] == i;
    final correct = _current.correctAnswerIndex == i;
    Color borderColor;
    Color bgColor;
    Widget? trailing;

    if (!_answered) {
      borderColor = Colors.white.withOpacity(0.12);
      bgColor = Colors.white.withOpacity(0.05);
    } else if (correct) {
      borderColor = const Color(0xFF00E676);
      bgColor = const Color(0xFF00E676).withOpacity(0.12);
      trailing = const Icon(Icons.check_circle_rounded, color: Color(0xFF00E676), size: 20);
    } else if (selected) {
      borderColor = const Color(0xFFFF6B6B);
      bgColor = const Color(0xFFFF6B6B).withOpacity(0.12);
      trailing = const Icon(Icons.cancel_rounded, color: Color(0xFFFF6B6B), size: 20);
    } else {
      borderColor = Colors.white.withOpacity(0.06);
      bgColor = Colors.transparent;
    }

    return GestureDetector(
      onTap: () => _selectAnswer(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected || (_answered && correct)
                    ? borderColor.withOpacity(0.2)
                    : Colors.white.withOpacity(0.06),
                border: Border.all(color: borderColor),
              ),
              child: Center(
                child: Text(
                  String.fromCharCode(65 + i),
                  style: manrope(size: 12, weight: FontWeight.w700, color: borderColor),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(_current.options[i], style: manrope(size: 14, height: 1.4))),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildExplanation() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF40C4FF).withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF40C4FF).withOpacity(0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF40C4FF), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _current.explanation,
              style: manrope(size: 13, color: Colors.white70, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNextButton() {
    final isLast = _currentIndex == 4;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: GestureDetector(
        onTap: _answered ? _nextQuestion : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: _answered
                ? const LinearGradient(colors: [Color(0xFF00E676), Color(0xFF00BCD4)])
                : null,
            color: _answered ? null : Colors.white12,
          ),
          child: Center(
            child: Text(
              isLast ? 'Submit Quiz' : 'Agla Sawaal',
              style: manrope(
                size: 15,
                weight: FontWeight.w700,
                color: _answered ? Colors.black : Colors.white38,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Result Screen
// ─────────────────────────────────────────────────────────────────────────────

class _ResultScreen extends StatelessWidget {
  final QuizSubmitResult result;
  final QuizModel quiz;
  const _ResultScreen({required this.result, required this.quiz});

  @override
  Widget build(BuildContext context) {
    final pct = (result.score / result.total * 100).round();
    final emoji = pct >= 80 ? '🏆' : pct >= 60 ? '👍' : '📚';
    final msg = pct >= 80 ? 'Shandaar!' : pct >= 60 ? 'Achha kiya!' : 'Aur practice karo!';

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const SizedBox(height: 20),
              Text(emoji, style: const TextStyle(fontSize: 60)),
              const SizedBox(height: 16),
              Text(msg, style: manrope(size: 22, weight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                '${result.score} / ${result.total} sahi jawab',
                style: manrope(size: 15, color: Colors.white60),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E676).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF00E676).withOpacity(0.4)),
                ),
                child: Text(
                  '+${result.skillScoreDelta} Skill Points',
                  style: manrope(size: 13, weight: FontWeight.w700, color: const Color(0xFF00E676)),
                ),
              ),
              const SizedBox(height: 28),
              // Score circle
              SizedBox(
                width: 130, height: 130,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: result.score / result.total,
                      strokeWidth: 8,
                      backgroundColor: Colors.white12,
                      valueColor: const AlwaysStoppedAnimation(Color(0xFF00E676)),
                    ),
                    Text(
                      '$pct%',
                      style: manrope(size: 28, weight: FontWeight.w800),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Per-question review
              Expanded(
                child: ListView.builder(
                  itemCount: quiz.questions.length,
                  itemBuilder: (_, i) {
                    final q = quiz.questions[i];
                    final correct = result.correctAnswers[i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Q${i + 1}. ${q.questionText}',
                              style: manrope(size: 13, weight: FontWeight.w600)),
                          const SizedBox(height: 6),
                          Text('✓ ${q.options[correct]}',
                              style: manrope(size: 12, color: const Color(0xFF00E676))),
                          if (result.explanations[i].isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(result.explanations[i],
                                  style: manrope(size: 12, color: Colors.white54, height: 1.4)),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: const LinearGradient(colors: [Color(0xFF00E676), Color(0xFF00BCD4)]),
                  ),
                  child: Center(
                    child: Text('Wapas Jao', style: manrope(size: 15, weight: FontWeight.w700, color: Colors.black)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
