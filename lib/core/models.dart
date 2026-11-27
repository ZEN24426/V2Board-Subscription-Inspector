class AppException implements Exception {
  final String message;
  final bool fromPanel;

  AppException(this.message, {this.fromPanel = false});

  @override
  String toString() => message;
}

class SubscriptionRecord {
  final String id;
  final String displayUrl;
  final String host;
  final int createdAt;

  const SubscriptionRecord({
    required this.id,
    required this.displayUrl,
    required this.host,
    required this.createdAt,
  });

  factory SubscriptionRecord.fromJson(Map<dynamic, dynamic> json) {
    return SubscriptionRecord(
      id: json['id'] as String,
      displayUrl: json['displayUrl'] as String,
      host: json['host'] as String,
      createdAt: json['createdAt'] as int,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'displayUrl': displayUrl,
        'host': host,
        'createdAt': createdAt,
      };
}

class AccountCredentials {
  final String email;
  final String password;

  const AccountCredentials({required this.email, required this.password});
}

class WebRequest {
  final String method;
  final String url;
  final Map<String, String> headers;
  final String body;

  const WebRequest(this.method, this.url, this.headers, this.body);
}

class WebResponse {
  final int status;
  final String body;
  final List<String> setCookies;

  const WebResponse(this.status, this.body, this.setCookies);
}

abstract class SecretStore {
  Future<void> save(String id, String secret);
  Future<String?> load(String id);
  Future<void> remove(String id);
  Future<List<String>> listIds();
}

class MemorySecretStore implements SecretStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<void> save(String id, String secret) async {
    _values[id] = secret;
  }

  @override
  Future<String?> load(String id) async {
    return _values[id];
  }

  @override
  Future<void> remove(String id) async {
    _values.remove(id);
  }

  @override
  Future<List<String>> listIds() async {
    return List<String>.from(_values.keys);
  }
}

class SubscriptionFetchResult {
  final String subscriptionUrl;
  final String panelName;

  const SubscriptionFetchResult({required this.subscriptionUrl, required this.panelName});
}
