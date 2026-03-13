import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final String baseUrl;

  const ApiService({required this.baseUrl});

  Future<Map<String, dynamic>> generatePayload({
    required String vendor,
    required double amount,
  }) async {
    final uri = Uri.parse('$baseUrl/api/generate-payload')
        .replace(queryParameters: {
      'vendor': vendor,
      'amount': amount.toStringAsFixed(2),
    });

    final response = await http.post(uri).timeout(const Duration(seconds: 10));
    final data = jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode != 200) {
      throw ApiException(data['errors']?[0]?['message'] ?? 'Failed to generate payload');
    }
    return data;
  }

  Future<Map<String, dynamic>> proxyInject({
    required String targetIP,
    required Map<String, dynamic> payload,
  }) async {
    final uri = Uri.parse('$baseUrl/api/proxy-inject');

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'targetIP': targetIP, 'payload': payload}),
        )
        .timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data;
  }

  Future<bool> ping() async {
    try {
      final uri = Uri.parse('$baseUrl/api/ping');
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}
