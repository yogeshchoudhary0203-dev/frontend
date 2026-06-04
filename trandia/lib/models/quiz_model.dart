class QuizQuestion {
  final String questionText;
  final List<String> options;
  final int correctAnswerIndex;
  final String explanation;
  final String difficulty;

  const QuizQuestion({
    required this.questionText,
    required this.options,
    required this.correctAnswerIndex,
    required this.explanation,
    required this.difficulty,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> j) => QuizQuestion(
        questionText: j['question_text'] ?? '',
        options: List<String>.from(j['options'] ?? []),
        correctAnswerIndex: j['correct_answer_index'] ?? 0,
        explanation: j['explanation'] ?? '',
        difficulty: j['difficulty'] ?? 'saral',
      );
}

class QuizModel {
  final String quizId;
  final String userId;
  final List<String> sourceVideoIds;
  final List<QuizQuestion> questions;
  final String status;
  final String pattern;
  final String? aiProviderUsed;
  final bool attempted;

  const QuizModel({
    required this.quizId,
    required this.userId,
    required this.sourceVideoIds,
    required this.questions,
    required this.status,
    required this.pattern,
    this.aiProviderUsed,
    required this.attempted,
  });

  factory QuizModel.fromJson(Map<String, dynamic> j) => QuizModel(
        quizId: j['quiz_id'] ?? '',
        userId: j['user_id'] ?? '',
        sourceVideoIds: List<String>.from(j['source_video_ids'] ?? []),
        questions: (j['questions'] as List? ?? [])
            .map((q) => QuizQuestion.fromJson(q))
            .toList(),
        status: j['status'] ?? 'generating',
        pattern: j['pattern'] ?? 'A',
        aiProviderUsed: j['ai_provider_used'],
        attempted: j['attempted'] ?? false,
      );
}

class QuizStatusModel {
  final bool hasPendingQuiz;
  final String? quizId;
  final String? status;

  const QuizStatusModel({
    required this.hasPendingQuiz,
    this.quizId,
    this.status,
  });

  factory QuizStatusModel.fromJson(Map<String, dynamic> j) => QuizStatusModel(
        hasPendingQuiz: j['has_pending_quiz'] ?? false,
        quizId: j['quiz_id'],
        status: j['status'],
      );
}

class QuizSubmitResult {
  final int score;
  final int total;
  final List<int> correctAnswers;
  final List<String> explanations;
  final int skillScoreDelta;

  const QuizSubmitResult({
    required this.score,
    required this.total,
    required this.correctAnswers,
    required this.explanations,
    required this.skillScoreDelta,
  });

  factory QuizSubmitResult.fromJson(Map<String, dynamic> j) => QuizSubmitResult(
        score: j['score'] ?? 0,
        total: j['total'] ?? 5,
        correctAnswers: List<int>.from(j['correct_answers'] ?? []),
        explanations: List<String>.from(j['explanations'] ?? []),
        skillScoreDelta: j['skill_score_delta'] ?? 0,
      );
}

/// Per-question reveal returned by POST /quiz/{id}/answer.
/// Answers are no longer shipped up-front (anti-cheat) — the screen asks for
/// the correct option only after the user commits to an answer.
class QuizReveal {
  final int correctIndex;
  final String explanation;
  final bool isCorrect;

  const QuizReveal({
    required this.correctIndex,
    required this.explanation,
    required this.isCorrect,
  });

  factory QuizReveal.fromJson(Map<String, dynamic> j) => QuizReveal(
        correctIndex: j['correct_index'] ?? 0,
        explanation: j['explanation'] ?? '',
        isCorrect: j['is_correct'] ?? false,
      );
}
