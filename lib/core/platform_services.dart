import 'package:flutter/services.dart';

import 'models.dart';

class PlatformServices {
  static const MethodChannel _channel = MethodChannel('feiniao/portable');

  static Future<void> openUrl(String url) async {
    await _channel.invokeMethod<void>('openUrl', <String, String>{'url': url});
  }

  static Future<void> logToPlatform(String message) async {
    try {
      await _channel.invokeMethod<void>('log', <String, String>{'message': message});
    } catch (_) {
      // 日志失败时静默忽略，避免影响主流程
    }
  }
}

class ChannelSecretStore implements SecretStore {
  static const MethodChannel _channel = MethodChannel('feiniao/portable');

  @override
  Future<void> save(String id, String secret) async {
    if (!isSecretWithinStorageLimit(secret)) {
      throw AppException('保存内容超过系统安全存储的 1024 字节限制');
    }
    await _channel.invokeMethod<void>('storeSave', <String, String>{'id': id, 'secret': secret});
  }

  @override
  Future<String?> load(String id) async {
    return _channel.invokeMethod<String>('storeLoad', <String, String>{'id': id});
  }

  @override
  Future<void> remove(String id) async {
    await _channel.invokeMethod<void>('storeRemove', <String, String>{'id': id});
  }

  @override
  Future<List<String>> listIds() async {
    try {
      final List<Object?>? result =
          await _channel.invokeMethod<List<Object?>>('storeListIds', <String, String>{});
      if (result == null) {
        return <String>[];
      }
      return result.whereType<String>().toList();
    } on MissingPluginException {
      return <String>[];
    }
  }
}
