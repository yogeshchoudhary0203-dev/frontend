import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_model.dart';
import 'api_service.dart';

class UserService {
  static Future<List<UserProfile>> searchUsers(String query) async {
    final token = await ApiService.getToken();
    final res = await http.get(
      Uri.parse('$baseUrl/users/search?q=$query'),
      headers: {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      return data.map((e) => UserProfile.fromJson(e)).toList();
    } else {
      throw const ApiException('Failed to search users');
    }
  }
}
