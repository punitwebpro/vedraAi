import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

const kApiUrl = 'https://vedraai.onrender.com';

Future<String> askVedra(List<Map<String, String>> history) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) throw Exception('Login required');

  final merged = <Map<String, String>>[];
  for (final m in history) {
    if (merged.isNotEmpty && merged.last['role'] == m['role']) {
      merged.last['text'] = '${merged.last['text']}\n${m['text']}';
    } else {
      merged.add({'role': m['role']!, 'text': m['text']!});
    }
  }

  final token = await user.getIdToken();
  final res = await http
      .post(
        Uri.parse('$kApiUrl/chat'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'messages': merged}),
      )
      .timeout(const Duration(seconds: 90));
  if (res.statusCode != 200) {
    throw Exception('Server error ${res.statusCode}');
  }
  return jsonDecode(utf8.decode(res.bodyBytes))['reply'] as String;
}
