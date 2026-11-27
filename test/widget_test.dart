import 'package:flutter_test/flutter_test.dart';

import 'package:feiniao_portable/core/http_client.dart';
import 'package:feiniao_portable/core/models.dart';
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
  test('secure storage limit is measured in UTF-8 bytes', () {
    expect(isSecretWithinStorageLimit('a' * 1024), true);
    expect(isSecretWithinStorageLimit('a' * 1025), false);
    expect(isSecretWithinStorageLimit('汉' * 341), true);
    expect(isSecretWithinStorageLimit('汉' * 342), false);
  });

  test('memory secret store rejects values above the platform limit', () async {
    final MemorySecretStore store = MemorySecretStore();
    await expectLater(
      store.save('too_long', 'x' * 1025),
      throwsA(isA<AppException>()),
    );
  });

  test('subscription URL validation rejects local and credentialed authorities', () {
    expect(validateSubscriptionUrl('https://127.0.0.1/link'), false);
    expect(validateSubscriptionUrl('https://192.168.1.10/subscription'), false);
    expect(validateSubscriptionUrl('https://localhost/subscription'), false);
    expect(validateSubscriptionUrl('https://user:pass@example.com/link'), false);
  });

  test('credential-bearing HTTP requests do not follow redirects by default', () {
    final WebRequest panelRequest =
        WebRequest('GET', 'https://panel.example.com/api/subscribe', const <String, String>{'Authorization': 'token'}, '');
    expect(panelRequest.followRedirects, false);

    final WebRequest readmeRequest =
        WebRequest('GET', 'https://cdn.example.com/README.md', const <String, String>{}, '', followRedirects: true);
    expect(readmeRequest.followRedirects, true);
  });

}
