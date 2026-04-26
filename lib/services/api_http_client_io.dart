import 'dart:convert';
import 'dart:io';

import 'api_http_client_base.dart';

class _IoApiHttpClient implements ApiHttpClient {
  @override
  Future<ApiHttpResponse> postJson({
    required Uri url,
    required Map<String, String> headers,
    required String body,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.postUrl(url);
      headers.forEach(request.headers.set);
      request.add(utf8.encode(body));
      final response = await request.close();
      final responseBody = await response.transform(SystemEncoding().decoder).join();
      return ApiHttpResponse(
        statusCode: response.statusCode,
        body: responseBody,
      );
    } finally {
      client.close(force: true);
    }
  }
}

ApiHttpClient createPlatformApiHttpClient() => _IoApiHttpClient();
