import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  const ApiException(this.code, this.message, {this.statusCode});

  final String code;
  final String message;
  final int? statusCode;

  bool get isNetwork => code == 'network';

  /// Korean, user-facing text for the error codes the server defines.
  String get userMessage => switch (code) {
        'network' => '서버에 연결할 수 없어요. 설정에서 서버 주소를 확인해 주세요.',
        'unauthorized' => 'API 토큰이 올바르지 않아요. 설정에서 확인해 주세요.',
        'too_many_active_calls' => '이미 진행 중인 통화가 있어요. 끝난 뒤 다시 시도해 주세요.',
        'daily_limit' => '오늘 걸 수 있는 통화 횟수를 모두 사용했어요.',
        'approval_closed' => '이미 처리되었거나 시간이 지난 요청이에요.',
        'invalid_state' => '지금 상태에서는 할 수 없는 작업이에요.',
        _ => message,
      };

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}

class ApiClient {
  ApiClient({required String baseUrl, required this.token, http.Client? client})
      : baseUri = Uri.parse(baseUrl),
        _client = client ?? http.Client();

  final Uri baseUri;
  final String token;
  final http.Client _client;

  static const _timeout = Duration(seconds: 20);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  Uri _uri(String path) => baseUri.replace(path: '${baseUri.path}$path');

  Future<dynamic> get(String path) => _send(() => _client.get(_uri(path), headers: _headers));

  Future<dynamic> post(String path, [Object? body]) => _send(
        () => _client.post(_uri(path), headers: _headers, body: jsonEncode(body ?? const {})),
      );

  Future<dynamic> delete(String path) => _send(() => _client.delete(_uri(path), headers: _headers));

  /// Browsers cannot set WebSocket headers, so the token goes in the query on every platform.
  Uri webSocketUri(String path) {
    final scheme = baseUri.scheme == 'https' ? 'wss' : 'ws';
    return baseUri.replace(
      scheme: scheme,
      path: '${baseUri.path}$path',
      queryParameters: token.isEmpty ? null : {'token': token},
    );
  }

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    final http.Response response;
    try {
      response = await request().timeout(_timeout);
    } on TimeoutException {
      throw const ApiException('network', 'Request timed out');
    } on http.ClientException catch (e) {
      throw ApiException('network', e.message);
    }

    final body = response.body.isEmpty ? null : jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode >= 200 && response.statusCode < 300) return body;

    final map = body is Map<String, dynamic> ? body : const <String, dynamic>{};
    throw ApiException(
      map['error'] as String? ?? 'http_${response.statusCode}',
      map['message'] as String? ?? '요청을 처리하지 못했어요.',
      statusCode: response.statusCode,
    );
  }

  void close() => _client.close();
}
