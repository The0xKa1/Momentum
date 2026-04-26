import 'api_http_client_base.dart';
import 'api_http_client_stub.dart'
    if (dart.library.html) 'api_http_client_web.dart'
    if (dart.library.io) 'api_http_client_io.dart';

export 'api_http_client_base.dart';

ApiHttpClient createApiHttpClient() => createPlatformApiHttpClient();
