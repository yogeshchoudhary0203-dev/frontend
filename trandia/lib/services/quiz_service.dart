import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import '../models/quiz_model.dart';

class QuizService {
  static Future<Map<String, dynamic>> sendWatchEvent({
    required String userId,
    required String videoId,
    required double watchPercentage,
    required double watchDurationSeconds,
    String videoTopic = 'general',
    String videoUrl = '',
  }) async {
    final token = await ApiService.getToken();
    final resp = await http.post(
      Uri.parse('$baseUrl/quiz/video-watch-event'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'user_id': userId,
        'video_id': videoId,
        'watch_percentage': watchPercentage,
        'watch_duration_seconds': watchDurationSeconds,
        'video_topic': videoTopic,
        'video_url': videoUrl,
      }),
    ).timeout(const Duration(seconds: 10));

    if (resp.statusCode == 200) return jsonDecode(resp.body);
    return {'quiz_triggered': false, 'count': 0};
  }

  static Future<QuizStatusModel> getStatus(String userId) async {
    final token = await ApiService.getToken();
    final resp = await http.get(
      Uri.parse('$baseUrl/quiz/status/$userId'),
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 10));

    if (resp.statusCode == 200) {
      return QuizStatusModel.fromJson(jsonDecode(resp.body));
    }
    return const QuizStatusModel(hasPendingQuiz: false);
  }

  static Future<QuizModel?> getQuiz(String quizId) async {
    final token = await ApiService.getToken();
    final resp = await http.get(
      Uri.parse('$baseUrl/quiz/$quizId'),
      headers: {if (token != null) 'Authorization': 'Bearer $token'},
    ).timeout(const Duration(seconds: 10));

    if (resp.statusCode == 200) return QuizModel.fromJson(jsonDecode(resp.body));
    return null;
  }

  static Future<QuizSubmitResult?> submitQuiz({
    required String quizId,
    required List<int> answers,
    required List<double> timePerQuestion,
  }) async {
    final token = await ApiService.getToken();
    final resp = await http.post(
      Uri.parse('$baseUrl/quiz/$quizId/submit'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'answers': answers,
        'time_per_question': timePerQuestion,
      }),
    ).timeout(const Duration(seconds: 10));

    if (resp.statusCode == 200) return QuizSubmitResult.fromJson(jsonDecode(resp.body));
    return null;
  }
}
