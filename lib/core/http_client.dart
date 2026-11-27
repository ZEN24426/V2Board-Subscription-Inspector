import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'models.dart';

class AppHttpClient {
  final HttpClient _client = HttpClient();

  AppHttpClient() {
    _client.connectionTimeout = const Duration(seconds: 15);
    _client.badCertificateCallback = null;
  }

  Future<String> getText(String url) async {
    final WebResponse response = await send(WebRequest('GET', url, const <String, String>{}, '', followRedirects: true));
    if (response.status != 200) {
      throw AppException('HTTP ${response.status}');
    }
    return response.body;
  }

  Future<WebResponse> send(WebRequest request) async {
    Uri uri;
    try {
      uri = Uri.parse(request.url);
    } on FormatException {
      throw AppException('链接格式无效');
    }

    HttpClientRequest req;
    try {
      req = await _client.openUrl(request.method, uri).timeout(const Duration(seconds: 15));
    } on SocketException catch (error) {
      throw AppException('网络请求失败：${error.message}');
    } on TimeoutException {
      throw AppException('网络请求超时');
    }

    request.headers.forEach(req.headers.set);
    req.followRedirects = request.followRedirects;
    if (request.body.isNotEmpty) {
      req.add(utf8.encode(request.body));
    }

    HttpClientResponse res;
    try {
      res = await req.close().timeout(const Duration(seconds: 25));
    } on SocketException catch (error) {
      throw AppException('网络请求失败：${error.message}');
    } on TimeoutException {
      throw AppException('网络请求超时');
    } on HandshakeException catch (error) {
      throw AppException('网络请求失败：${error.message}');
    }

    final List<String>? setCookies = res.headers[HttpHeaders.setCookieHeader];
    String body;
    try {
      body = await const Utf8Decoder(allowMalformed: true)
          .bind(res)
          .join()
          .timeout(const Duration(seconds: 25));
    } on TimeoutException {
      throw AppException('网络请求超时');
    }
    return WebResponse(res.statusCode, body, setCookies ?? <String>[]);
  }

  Future<bool> probe(String url, {Duration timeout = const Duration(seconds: 6)}) async {
    try {
      final Uri uri = Uri.parse(url);
      final HttpClientRequest req = await _client.openUrl('GET', uri).timeout(timeout);
      final HttpClientResponse res = await req.close().timeout(timeout);
      final bool reachable = res.statusCode > 0;
      unawaited(res.drain<void>().catchError((Object _) {}));
      return reachable;
    } catch (_) {
      return false;
    }
  }

  void close() {
    _client.close();
  }
}
