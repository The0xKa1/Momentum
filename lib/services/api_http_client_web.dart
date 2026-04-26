import 'dart:html' as html;

import 'api_http_client_base.dart';

class _WebApiHttpClient implements ApiHttpClient {
  @override
  Future<ApiHttpResponse> postJson({
    required Uri url,
    required Map<String, String> headers,
    required String body,
  }) async {
    try {
      final response = await html.HttpRequest.request(
        url.toString(),
        method: 'POST',
        requestHeaders: headers,
        sendData: body,
      );

      return ApiHttpResponse(
        statusCode: response.status ?? 0,
        body: response.responseText ?? '',
      );
    } catch (error) {
      throw Exception('Web request failed: $error');
    }
  }
}

ApiHttpClient createPlatformApiHttpClient() => _WebApiHttpClient();
