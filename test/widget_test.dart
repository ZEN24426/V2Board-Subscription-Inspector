import 'package:flutter_test/flutter_test.dart';

import 'package:feiniao_portable/core/url_core.dart';

void main() {
  test('discoverEntryLinks extracts root https hosts in order', () {
    final List<String> links = discoverEntryLinks(
        '入口 https://aaa.example.com/ 和 https://bbb.example.com/，详见 https://github.com/owner/repo');
    expect(links, <String>['https://aaa.example.com/', 'https://bbb.example.com/']);
  });

  test('readmeFetchCandidates expands github repo to mirrors', () {
    final List<String> urls = readmeFetchCandidates('https://github.com/feiniaoyun/feiniaoyun');
    expect(urls.length, 8);
    expect(urls[0], 'https://gcore.jsdelivr.net/gh/feiniaoyun/feiniaoyun@main/README.md');
    expect(urls.last, 'https://raw.githubusercontent.com/feiniaoyun/feiniaoyun/master/README.md');
  });

  test('readmeFetchCandidates keeps custom branch and file', () {
    final List<String> urls =
        readmeFetchCandidates('https://github.com/owner/repo/blob/dev/docs/list.md');
    expect(urls.length, 4);
    expect(urls[0], 'https://gcore.jsdelivr.net/gh/owner/repo@dev/docs/list.md');
  });

  test('readmeFetchCandidates passes through unknown urls', () {
    final List<String> urls = readmeFetchCandidates('https://example.com/entries.txt');
    expect(urls, <String>['https://example.com/entries.txt']);
  });

  test('validateSubscriptionUrl accepts https with path or query', () {
    expect(validateSubscriptionUrl('https://example.com/link/abc123'), true);
    expect(validateSubscriptionUrl('https://example.com/?token=x'), true);
    expect(validateSubscriptionUrl('https://example.com/'), false);
    expect(validateSubscriptionUrl('http://example.com/link'), false);
  });

  test('subscriptionFingerprint is stable', () {
    final String first = subscriptionFingerprint('https://example.com/api/v1/client/subscribe?token=abc');
    final String second = subscriptionFingerprint('https://example.com/api/v1/client/subscribe?token=abc');
    expect(first, second);
    expect(first.length, 16);
  });

  test('redactSubscriptionUrl hides secret part', () {
    expect(redactSubscriptionUrl('https://example.com/link?token=secret'), 'https://example.com?••••••');
  });
}
