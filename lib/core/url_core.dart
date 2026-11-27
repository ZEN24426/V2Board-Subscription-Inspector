const String defaultReadmeInput = 'https://github.com/feiniaoyun/feiniaoyun';

const List<String> _githubRawMirrors = <String>[
  'gcore.jsdelivr.net',
  'fastly.jsdelivr.net',
  'cdn.jsdelivr.net'
];

const List<String> _defaultBranches = <String>['main', 'master'];

const List<String> _excludedHosts = <String>[
  'github.com',
  'www.github.com',
  'raw.githubusercontent.com',
  'gitee.com',
  'www.gitee.com',
  'jsdelivr.net',
  't.me',
  'telegram.me',
  'hutaosubconverter.com',
  'www.hutaosubconverter.com'
];

List<String> readmeFetchCandidates(String input) {
  final String extracted = normalizeSubscriptionInput(input);
  if (!extracted.startsWith('https://')) {
    return const <String>[];
  }
  final ParsedHttpsUrl? parsed = _parseHttpsUrl(extracted);
  if (parsed == null) {
    return const <String>[];
  }
  final String host = parsed.host;
  final List<String> segments = parsed.path == '/'
      ? const <String>[]
      : parsed.path.split('/').where((String segment) => segment.isNotEmpty).toList();

  if (host == 'github.com' || host == 'www.github.com') {
    if (segments.length < 2) {
      return const <String>[];
    }
    String branch = '';
    if (segments.length >= 4 &&
        (segments[2] == 'blob' || segments[2] == 'raw' || segments[2] == 'tree')) {
      branch = segments[3];
    }
    final String file = segments.length >= 5 ? segments.sublist(4).join('/') : 'README.md';
    return _githubReadmeUrls(_repoName(segments[0]), _repoName(segments[1]), branch, file);
  }

  if (host == 'raw.githubusercontent.com') {
    if (segments.length < 2) {
      return const <String>[];
    }
    if (segments.length >= 4) {
      return _githubReadmeUrls(
          _repoName(segments[0]), _repoName(segments[1]), segments[2], segments.sublist(3).join('/'));
    }
    final String file = segments.length == 3 ? segments[2] : 'README.md';
    return _githubReadmeUrls(_repoName(segments[0]), _repoName(segments[1]), '', file);
  }

  if (host == 'gitee.com' || host == 'www.gitee.com') {
    if (segments.length < 2) {
      return const <String>[];
    }
    String branch = '';
    if (segments.length >= 4 &&
        (segments[2] == 'blob' || segments[2] == 'raw' || segments[2] == 'tree')) {
      branch = segments[3];
    }
    final String file = segments.length >= 5 ? segments.sublist(4).join('/') : 'README.md';
    return _giteeReadmeUrls(_repoName(segments[0]), _repoName(segments[1]), branch, file);
  }

  if (host == 'jsdelivr.net' || host.endsWith('.jsdelivr.net')) {
    if (segments.length >= 4 && segments[0] == 'gh') {
      final List<String> repoBranch = segments[2].split('@');
      final List<String> urls = _githubReadmeUrls(segments[1], _repoName(repoBranch[0]),
          repoBranch.length > 1 ? repoBranch[1] : '', segments.sublist(3).join('/'));
      urls.insert(0, extracted);
      return urls;
    }
    return <String>[extracted];
  }

  return <String>[extracted];
}

List<String> _githubReadmeUrls(String owner, String repo, String branch, String file) {
  final List<String> branches = branch.isEmpty ? _defaultBranches : <String>[branch];
  final List<String> urls = <String>[];
  for (final String item in branches) {
    for (final String mirror in _githubRawMirrors) {
      urls.add('https://$mirror/gh/$owner/$repo@$item/$file');
    }
    urls.add('https://raw.githubusercontent.com/$owner/$repo/$item/$file');
  }
  return urls;
}

List<String> _giteeReadmeUrls(String owner, String repo, String branch, String file) {
  final List<String> branches = branch.isEmpty ? _defaultBranches : <String>[branch];
  final List<String> urls = <String>[];
  for (final String item in branches) {
    urls.add('https://gitee.com/$owner/$repo/raw/$item/$file');
  }
  return urls;
}

String _repoName(String value) {
  return value.replaceAll(RegExp(r'\.git$'), '');
}

List<String> discoverEntryLinks(String readme) {
  final RegExp pattern = RegExp('https://[^\\s<>"\'`]+', caseSensitive: false);
  final List<String> result = <String>[];
  final Set<String> seen = <String>{};

  for (final RegExpMatch match in pattern.allMatches(readme)) {
    final String candidate = _trimMarkdownPunctuation(match.group(0)!);
    final ParsedHttpsUrl? parsed = _parseHttpsUrl(candidate);
    if (parsed == null || _isExcludedHost(parsed.host)) {
      continue;
    }
    if (parsed.path != '/' || parsed.query.isNotEmpty || parsed.fragment.isNotEmpty) {
      continue;
    }
    final String normalized = 'https://${parsed.host}/';
    if (!seen.contains(normalized)) {
      seen.add(normalized);
      result.add(normalized);
    }
  }
  return result;
}

bool validateSubscriptionUrl(String input) {
  final ParsedHttpsUrl? parsed = _parseHttpsUrl(input.trim());
  if (parsed == null) {
    return false;
  }
  if (parsed.host.contains('@')) {
    return false;
  }
  return parsed.path != '/' || parsed.query.isNotEmpty;
}

String redactSubscriptionUrl(String input) {
  final ParsedHttpsUrl? parsed = _parseHttpsUrl(input.trim());
  if (parsed == null) {
    return '链接格式无效';
  }
  final String suffix = parsed.query.isNotEmpty ? '?••••••' : '/••••••';
  return 'https://${parsed.host}$suffix';
}

String subscriptionFingerprint(String input) {
  final String value = input.trim();
  int first = 0x811c9dc5;
  int second = 5381;
  for (int index = 0; index < value.length; index++) {
    final int code = value.codeUnitAt(index);
    first = ((first ^ code) * 0x01000193) & 0xFFFFFFFF;
    second = ((second << 5) + second + code) & 0xFFFFFFFF;
  }
  return '${_toHex(first)}${_toHex(second)}';
}

class ParsedHttpsUrl {
  final String host;
  final String path;
  final String query;
  final String fragment;

  const ParsedHttpsUrl(this.host, this.path, this.query, this.fragment);
}

ParsedHttpsUrl? _parseHttpsUrl(String input) {
  if (!RegExp(r'^https://', caseSensitive: false).hasMatch(input) || RegExp(r'\s').hasMatch(input)) {
    return null;
  }

  final String rest = input.substring(input.indexOf('://') + 3);
  final int authorityEnd = rest.indexOf(RegExp(r'[/?#]'));
  final String authority = authorityEnd < 0 ? rest : rest.substring(0, authorityEnd);
  final String tail = authorityEnd < 0 ? '' : rest.substring(authorityEnd);

  if (authority.isEmpty || authority.contains('@')) {
    return null;
  }

  final String host = _normalizeHost(authority);
  if (!_isValidHost(host)) {
    return null;
  }

  final RegExpMatch? pathMatch = RegExp(r'^([^?#]*)').firstMatch(tail);
  final String path = pathMatch == null ? '' : pathMatch.group(1)!;
  final RegExpMatch? queryMatch = RegExp(r'\?([^#]*)').firstMatch(tail);
  final RegExpMatch? fragmentMatch = RegExp(r'#([\s\S]*)').firstMatch(tail);
  return ParsedHttpsUrl(
    host,
    path.isEmpty ? '/' : path,
    queryMatch == null ? '' : queryMatch.group(1)!,
    fragmentMatch == null ? '' : fragmentMatch.group(1)!,
  );
}

String _normalizeHost(String authority) {
  String host = authority.toLowerCase();
  if (host.endsWith('.')) {
    host = host.substring(0, host.length - 1);
  }
  if (host.endsWith(':443')) {
    host = host.substring(0, host.length - 4);
  }
  return host;
}

bool _isValidHost(String host) {
  if (host.length > 253 || !host.contains('.')) {
    return false;
  }
  if (host == 'localhost' || host.endsWith('.local') || _isPrivateIpv4(host)) {
    return false;
  }
  if (RegExp(r'^\d+\.\d+\.\d+\.\d+$').hasMatch(host) && !_isValidIpv4(host)) {
    return false;
  }
  final List<String> labels = host.split('.');
  return labels.every((String label) {
    return label.isNotEmpty &&
        label.length <= 63 &&
        RegExp(r'^[a-z0-9](?:[a-z0-9-]*[a-z0-9])?$').hasMatch(label);
  });
}

bool _isPrivateIpv4(String host) {
  if (!_isValidIpv4(host)) {
    return false;
  }
  final List<int> values = host.split('.').map((String part) => int.parse(part)).toList();
  final int first = values[0];
  final int second = values[1];
  return first == 10 ||
      first == 127 ||
      first == 0 ||
      (first == 169 && second == 254) ||
      (first == 172 && second >= 16 && second <= 31) ||
      (first == 192 && second == 168);
}

bool _isValidIpv4(String host) {
  final List<String> parts = host.split('.');
  return parts.length == 4 &&
      parts.every((String part) {
        return RegExp(r'^\d{1,3}$').hasMatch(part) && int.parse(part) <= 255;
      });
}

bool _isExcludedHost(String host) {
  return _excludedHosts.any((String excluded) => host == excluded || host.endsWith('.$excluded'));
}

String _trimMarkdownPunctuation(String value) {
  String result = value;
  const String trailing = '.,;:!?，。；：！、)]}>）】》';
  while (result.isNotEmpty && trailing.contains(result[result.length - 1])) {
    result = result.substring(0, result.length - 1);
  }
  return result;
}

String hostFromUrl(String url) {
  final String rest = url.substring('https://'.length);
  final int end = rest.indexOf(RegExp(r'[/?#]'));
  return end < 0 ? rest : rest.substring(0, end);
}

String _toHex(int value) {
  return value.toRadixString(16).padLeft(8, '0');
}

String normalizeSubscriptionInput(String input) {
  final String trimmed = input.trim();
  if (trimmed.startsWith('https://')) {
    return trimmed;
  }
  final RegExpMatch? match = RegExp(r"""https://[^\s<>'"`]+""", caseSensitive: false).firstMatch(trimmed);
  return match == null ? trimmed : match.group(0)!.replaceAll(RegExp(r'[),;，；。]+$'), '');
}

String extractHost(String url) {
  final String withoutScheme = url.substring('https://'.length);
  final int end = withoutScheme.indexOf(RegExp(r'[/?#]'));
  return end < 0 ? withoutScheme : withoutScheme.substring(0, end);
}
