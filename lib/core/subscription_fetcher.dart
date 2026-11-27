import 'dart:convert';

import 'http_client.dart';
import 'models.dart';
import 'url_core.dart';

class _SiteProbe {
  final String url;
  final int elapsedMs;

  const _SiteProbe(this.url, this.elapsedMs);
}

Future<SubscriptionFetchResult> fetchSubscriptionUrl(
  AppHttpClient http,
  List<String> sites,
  AccountCredentials credentials,
) async {
  if (sites.isEmpty) {
    throw AppException('没有可用入口，请先读取发布页');
  }
  final List<_SiteProbe> reachable = await _probeSites(http, sites);
  if (reachable.isEmpty) {
    throw AppException('所有入口均不可达，请检查网络后重试');
  }
  final List<String> failures = <String>[];
  String? panelError;
  for (final _SiteProbe probe in reachable) {
    final String base = _normalizeSiteBase(probe.url);
    try {
      final SubscriptionFetchResult? v2BoardResult = await _tryV2Board(http, base, credentials);
      if (v2BoardResult != null) {
        return v2BoardResult;
      }
      final SubscriptionFetchResult? ssPanelResult = await _trySsPanel(http, base, credentials);
      if (ssPanelResult != null) {
        return ssPanelResult;
      }
      failures.add('${hostFromUrl(base)} 不是支持的面板');
    } on AppException catch (error) {
      if (error.fromPanel && panelError == null) {
        panelError = error.message;
      }
      failures.add('${hostFromUrl(base)} ${error.message}');
    }
  }
  throw AppException(panelError ?? '自动登录失败：${failures.take(3).join('；')}');
}

Future<List<_SiteProbe>> _probeSites(AppHttpClient http, List<String> sites) async {
  final List<Future<_SiteProbe>> futures = sites.map((String site) async {
    final Stopwatch watch = Stopwatch()..start();
    final bool ok = await http.probe(site);
    return _SiteProbe(site, ok ? watch.elapsedMilliseconds : -1);
  }).toList();
  final List<_SiteProbe> reachable = (await Future.wait(futures))
      .where((_SiteProbe probe) => probe.elapsedMs >= 0)
      .toList();
  reachable.sort((_SiteProbe a, _SiteProbe b) => a.elapsedMs.compareTo(b.elapsedMs));
  return reachable;
}

String _normalizeSiteBase(String site) {
  final String trimmed = site.trim();
  if (!trimmed.startsWith('https://') || trimmed.length <= 'https://'.length) {
    throw AppException('入口链接无效');
  }
  return trimmed.replaceAll(RegExp(r'/+$'), '');
}

Future<SubscriptionFetchResult?> _tryV2Board(
  AppHttpClient http,
  String base,
  AccountCredentials credentials,
) async {
  final WebResponse loginResponse = await http.send(WebRequest(
    'POST',
    '$base/api/v1/passport/auth/login',
    <String, String>{'Content-Type': 'application/json'},
    jsonEncode(<String, String>{'email': credentials.email, 'password': credentials.password}),
  ));

  final dynamic login = _parseJson(loginResponse.body);
  if (login == null) {
    return null;
  }
  final dynamic loginMessage = login['message'];
  if (loginMessage is String && loginMessage.isNotEmpty) {
    throw AppException(loginMessage, fromPanel: true);
  }

  String token = '';
  String authData = '';
  final dynamic data = login['data'];
  if (data is String) {
    token = data;
  } else if (data is Map) {
    final dynamic dataToken = data['token'];
    if (dataToken is String) {
      token = dataToken;
    }
    final dynamic dataAuth = data['auth_data'];
    if (dataAuth is String) {
      authData = dataAuth;
    }
  }
  if (token.isEmpty && authData.isEmpty) {
    return null;
  }
  final String authorization = authData.isNotEmpty ? authData : token;

  final WebResponse subscribeResponse = await http.send(WebRequest(
    'GET',
    '$base/api/v1/user/getSubscribe',
    <String, String>{'Authorization': authorization},
    '',
  ));

  final dynamic subscribe = _parseJson(subscribeResponse.body);
  if (subscribe == null) {
    return null;
  }
  final dynamic subscribeMessage = subscribe['message'];
  if (subscribeMessage is String && subscribeMessage.isNotEmpty) {
    throw AppException(subscribeMessage, fromPanel: true);
  }

  String url = '';
  final dynamic subscribeData = subscribe['data'];
  if (subscribeData is Map) {
    final dynamic subscribeUrl = subscribeData['subscribe_url'];
    if (subscribeUrl is String) {
      url = subscribeUrl;
    }
  }
  if (!url.startsWith('https://') && token.isNotEmpty) {
    url = '$base/api/v1/client/subscribe?token=$token';
  }
  if (!url.startsWith('https://')) {
    return null;
  }
  return SubscriptionFetchResult(subscriptionUrl: url, panelName: 'V2Board');
}

Future<SubscriptionFetchResult?> _trySsPanel(
  AppHttpClient http,
  String base,
  AccountCredentials credentials,
) async {
  final WebResponse loginResponse = await http.send(WebRequest(
    'POST',
    '$base/auth/login',
    <String, String>{'Content-Type': 'application/x-www-form-urlencoded'},
    'email=${Uri.encodeComponent(credentials.email)}&passwd=${Uri.encodeComponent(credentials.password)}'
        '&remember_me=on',
  ));

  if (loginResponse.status != 200) {
    return null;
  }
  final dynamic login = _parseJson(loginResponse.body);
  if (login == null || login['ret'] is! int) {
    return null;
  }
  if (login['ret'] != 1) {
    final dynamic msg = login['msg'];
    final String message = msg is String && msg.isNotEmpty ? msg : '账号或密码错误';
    throw AppException(message, fromPanel: true);
  }

  final String cookieHeader = _buildCookieHeader(loginResponse.setCookies);
  if (cookieHeader.isEmpty) {
    return null;
  }

  final WebResponse userPage = await http.send(WebRequest(
    'GET',
    '$base/user',
    <String, String>{'Cookie': cookieHeader},
    '',
  ));
  if (userPage.status != 200) {
    return null;
  }
  final RegExpMatch? match = RegExp('/link/([A-Za-z0-9]+)').firstMatch(userPage.body);
  if (match == null) {
    return null;
  }
  return SubscriptionFetchResult(subscriptionUrl: '$base/link/${match.group(1)}', panelName: 'SSPanel');
}

String _buildCookieHeader(List<String> setCookies) {
  final List<String> pairs = <String>[];
  for (final String cookie in setCookies) {
    final String pair = cookie.split(';')[0].trim();
    if (pair.isNotEmpty && pair.contains('=')) {
      pairs.add(pair);
    }
  }
  return pairs.join('; ');
}

dynamic _parseJson(String body) {
  try {
    return jsonDecode(body);
  } on FormatException {
    return null;
  }
}


