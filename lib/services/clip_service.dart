import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/clip_model.dart';

class ClipService {
  final String baseUrl;
  final String Function() getToken;

  ClipService({required this.baseUrl, required this.getToken});

  // Create a new clip
  Future<ClipModel?> createClip(String content, String type) async {
    try {
      final token = getToken();
      final response = await http.post(
        Uri.parse('$baseUrl/clips'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'content': content,
          'type': type,
        }),
      );

      if (response.statusCode == 200) {
        // TODO: Parse and return clip
        return null;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Get all clips
  Future<List<ClipModel>> getClips() async {
    try {
      final token = getToken();
      final response = await http.get(
        Uri.parse('$baseUrl/clips'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // TODO: Parse and return clips list
        return [];
      }
      return [];
    } catch (e) {
      return [];
    }
  }
}
