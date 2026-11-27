import 'dart:convert';

import 'models.dart';
import 'url_core.dart';

class AccountRepository {
  final SecretStore _secrets;

  static const String _emailId = 'account_email';
  static const String _passwordId = 'account_password';

  AccountRepository(this._secrets);

  Future<AccountCredentials?> loadCredentials() async {
    final String? email = await _secrets.load(_emailId);
    final String? password = await _secrets.load(_passwordId);
    if (email == null || password == null || email.isEmpty || password.isEmpty) {
      return null;
    }
    return AccountCredentials(email: email, password: password);
  }

  Future<void> saveCredentials(String email, String password) async {
    await _secrets.save(_emailId, email);
    await _secrets.save(_passwordId, password);
  }

  Future<void> clearCredentials() async {
    await _secrets.remove(_emailId);
    await _secrets.remove(_passwordId);
  }
}

class ReadmeRepository {
  final SecretStore _secrets;

  static const String _id = 'readme_url';

  ReadmeRepository(this._secrets);

  Future<String?> load() {
    return _secrets.load(_id);
  }

  Future<void> save(String url) {
    return _secrets.save(_id, url);
  }
}

class SubscriptionRepository {
  final SecretStore _secrets;

  static const String _recordPrefix = 'record_';
  static const String _secretPrefix = 'subscription_';
  static const int _maxRecords = 20;

  SubscriptionRepository(this._secrets);

  Future<List<SubscriptionRecord>> list() async {
    final List<SubscriptionRecord> records = await _loadAllRecords();
    return records.sublist(0, records.length > _maxRecords ? _maxRecords : records.length);
  }

  Future<List<SubscriptionRecord>> _loadAllRecords() async {
    final List<String> ids = await _secrets.listIds();
    final List<SubscriptionRecord> records = <SubscriptionRecord>[];

    for (final String storageId in ids) {
      if (!storageId.startsWith(_recordPrefix)) {
        continue;
      }
      final String id = storageId.substring(_recordPrefix.length);
      final String? raw = await _secrets.load(storageId);
      final String? secret = await _secrets.load('$_secretPrefix$id');
      if (raw == null || secret == null || !validateSubscriptionUrl(secret)) {
        continue;
      }
      try {
        final dynamic parsed = jsonDecode(raw);
        if (parsed is Map &&
            parsed['id'] is String &&
            parsed['displayUrl'] is String &&
            parsed['host'] is String &&
            parsed['createdAt'] is int &&
            parsed['id'] == id) {
          records.add(SubscriptionRecord.fromJson(parsed));
        }
      } on FormatException {
        continue;
      }
    }

    records.sort((SubscriptionRecord a, SubscriptionRecord b) => b.createdAt.compareTo(a.createdAt));
    return records;
  }

  Future<SubscriptionRecord> save(String rawUrl) async {
    final String normalized = normalizeSubscriptionInput(rawUrl);
    if (!validateSubscriptionUrl(normalized)) {
      throw AppException('请输入有效的 HTTPS 订阅链接');
    }

    final String id = subscriptionFingerprint(normalized);
    final SubscriptionRecord record = SubscriptionRecord(
      id: id,
      displayUrl: redactSubscriptionUrl(normalized),
      host: extractHost(normalized),
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    await _secrets.save('$_secretPrefix$id', normalized);
    await _secrets.save('$_recordPrefix$id', jsonEncode(record.toJson()));
    await _trimRecords();
    return record;
  }

  Future<String> reveal(String id) async {
    final String? secret = await _secrets.load('$_secretPrefix$id');
    if (secret == null || !validateSubscriptionUrl(secret)) {
      throw AppException('订阅已失效，请重新导入');
    }
    return secret;
  }

  Future<void> remove(String id) async {
    await _secrets.remove('$_secretPrefix$id');
    await _secrets.remove('$_recordPrefix$id');
  }

  Future<void> _trimRecords() async {
    final List<SubscriptionRecord> records = await _loadAllRecords();
    for (final SubscriptionRecord record in records.length > _maxRecords
        ? records.sublist(_maxRecords)
        : <SubscriptionRecord>[]) {
      await remove(record.id);
    }
  }
}
