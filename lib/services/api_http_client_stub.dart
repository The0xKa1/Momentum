import 'api_http_client_base.dart';

class _UnsupportedApiHttpClient implements ApiHttpClient {
  @override
  Future<ApiHttpResponse> postJson({
    required Uri url,
    required Map<String, String> headers,
    required String body,
  }) {
    throw UnsupportedError('Network requests are not supported on this platform.');
  }
}

ApiHttpClient createPlatformApiHttpClient() => _UnsupportedApiHttpClient();
