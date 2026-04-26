class ApiHttpResponse {
  const ApiHttpResponse({
    required this.statusCode,
    required this.body,
  });

  final int statusCode;
  final String body;
}

abstract class ApiHttpClient {
  Future<ApiHttpResponse> postJson({
    required Uri url,
    required Map<String, String> headers,
    required String body,
  });
}
