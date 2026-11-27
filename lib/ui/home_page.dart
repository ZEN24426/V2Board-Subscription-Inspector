import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/http_client.dart';
import '../core/models.dart';
import '../core/platform_services.dart';
import '../core/repositories.dart';
import '../core/subscription_fetcher.dart';
import '../core/url_core.dart';
import 'theme.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final AppHttpClient _http = AppHttpClient();
  final SecretStore _secrets = ChannelSecretStore();
  late final ReadmeRepository _readmeRepository = ReadmeRepository(_secrets);
  late final AccountRepository _accountRepository = AccountRepository(_secrets);
  late final SubscriptionRepository _repository = SubscriptionRepository(_secrets);

  final TextEditingController _readmeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  List<String> _entries = <String>[];
  bool _loadingEntries = false;
  bool _fetching = false;
  bool _hasSavedAccount = false;
  String _savedEmailHint = '';
  List<SubscriptionRecord> _subscriptions = <SubscriptionRecord>[];
  String _resultUrl = '';
  String _resultPanel = '';

  String _message = '';
  bool _messageIsError = false;
  Timer? _messageTimer;

  @override
  void initState() {
    super.initState();
    _initAsync();
  }

  Future<void> _initAsync() async {
    final String? saved = await _readmeRepository.load();
    if (!mounted) {
      return;
    }
    _readmeController.text = saved == null || saved.isEmpty ? defaultReadmeInput : saved;
    await Future.wait(<Future<void>>[
      _refreshAccountState(),
      _loadSubscriptions(),
    ]);
    await _refreshEntries();
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _readmeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _http.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Column(
              children: <Widget>[
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _buildReadmeCard(),
                          const SizedBox(height: 14),
                          _buildAccountCard(),
                          if (_resultUrl.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 14),
                            _buildResultCard(),
                          ],
                          const SizedBox(height: 18),
                          Row(
                            children: <Widget>[
                              const Expanded(
                                child: Text(
                                  '已保存的订阅',
                                  style: TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text),
                                ),
                              ),
                              Text(
                                '${_subscriptions.length} 条',
                                style: const TextStyle(fontSize: 12, color: AppColors.muted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (_subscriptions.isEmpty)
                            _buildEmptyCard('还没有订阅', '登录成功后会自动保存在这里，可随时复制。')
                          else
                            for (final SubscriptionRecord item in _subscriptions) ...<Widget>[
                              _buildSubscriptionRow(item),
                              const SizedBox(height: 10),
                            ],
                        ],
                      ),
                    ),
                  ),
                ),
                _buildFooter(),
              ],
            ),
            if (_message.isNotEmpty) _buildMessageBanner(),
          ],
        ),
      ),
    );
  }

  Widget _buildReadmeCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text('发布页链接', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
          const SizedBox(height: 6),
          const Text(
            '输入机场官方 GitHub / Gitee 发布页或 README 链接，自动提取可用入口。',
            style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _readmeController,
            maxLength: 1024,
            keyboardType: TextInputType.url,
            style: const TextStyle(fontSize: 13, color: AppColors.text),
            decoration: _inputDecoration('https://github.com/用户名/仓库名'),
            onChanged: (String value) {
              setState(() {});
            },
          ),
          const SizedBox(height: 8),
          _buildEntryStatus(),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: TextButton(
              onPressed: (_loadingEntries || _readmeController.text.trim().isEmpty) ? null : _refreshEntries,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: AppColors.card,
                disabledBackgroundColor: AppColors.neutralTint,
                disabledForegroundColor: AppColors.muted,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
              ),
              child: Text(
                _loadingEntries ? '正在读取…' : '读取入口',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryStatus() {
    if (_loadingEntries) {
      return Row(
        children: const <Widget>[
          SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.blue),
          ),
          SizedBox(width: 8),
          Text('正在读取发布页…', style: TextStyle(fontSize: 12, color: AppColors.muted)),
        ],
      );
    }
    if (_entries.isNotEmpty) {
      return Row(
        children: <Widget>[
          const Text('✓', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.success)),
          const SizedBox(width: 7),
          Text(
            '已发现 ${_entries.length} 个入口，登录时将自动依次尝试',
            style: const TextStyle(fontSize: 12, color: AppColors.success),
          ),
        ],
      );
    }
    return const Text('尚未发现入口，点击下方按钮读取', style: TextStyle(fontSize: 12, color: AppColors.muted));
  }

  Widget _buildAccountCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x12000000), blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text('一键获取订阅', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.text)),
          const SizedBox(height: 6),
          const Text('输入机场账号密码，自动登录并获取订阅链接（支持 V2Board / SSPanel 面板）。',
              style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5)),
          const SizedBox(height: 10),
          SizedBox(
            height: 46,
            child: TextField(
              controller: _emailController,
              maxLength: 128,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(fontSize: 14, color: AppColors.text),
              decoration: _inputDecoration('邮箱'),
              onChanged: (String value) {
                setState(() {});
              },
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 46,
            child: TextField(
              controller: _passwordController,
              maxLength: 128,
              obscureText: true,
              style: const TextStyle(fontSize: 14, color: AppColors.text),
              decoration: _inputDecoration('密码'),
              onChanged: (String value) {
                setState(() {});
              },
            ),
          ),
          if (_hasSavedAccount) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              '已记住账号：$_savedEmailHint',
              style: const TextStyle(fontSize: 11, color: AppColors.success),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextButton(
                    onPressed: (_fetching ||
                            _emailController.text.trim().isEmpty ||
                            _passwordController.text.isEmpty)
                        ? null
                        : _saveAccount,
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.blueTint,
                      foregroundColor: AppColors.blue,
                      disabledBackgroundColor: AppColors.neutralTint,
                      disabledForegroundColor: AppColors.muted,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
                    ),
                    child: const Text('保存账号', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 40,
                  child: TextButton(
                    onPressed: (_hasSavedAccount && !_fetching) ? _clearAccount : null,
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.dangerTint,
                      foregroundColor: AppColors.danger,
                      disabledBackgroundColor: AppColors.neutralTint,
                      disabledForegroundColor: AppColors.muted,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
                    ),
                    child: const Text('清除账号', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: TextButton(
              onPressed: (_fetching ||
                      _entries.isEmpty ||
                      !(_hasSavedAccount ||
                          (_emailController.text.trim().isNotEmpty && _passwordController.text.isNotEmpty)))
                  ? null
                  : _fetchSubscription,
              style: TextButton.styleFrom(
                backgroundColor: AppColors.blue,
                foregroundColor: AppColors.card,
                disabledBackgroundColor: AppColors.neutralTint,
                disabledForegroundColor: AppColors.muted,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.control)),
              ),
              child: Text(
                _fetching ? '正在登录并获取…' : '登录并获取订阅',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: const Color(0xFFB7E4D1)),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Text('✓',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.success)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '订阅获取成功（$_resultPanel）',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.text),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.inputFill,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _resultUrl,
              style: const TextStyle(fontSize: 12, color: AppColors.text, height: 1.4),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextButton(
                    onPressed: () => _copyText(_resultUrl),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      foregroundColor: AppColors.card,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
                    ),
                    child: const Text('复制链接', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextButton(
                    onPressed: _openResultInBrowser,
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.blueTint,
                      foregroundColor: AppColors.blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(19)),
                    ),
                    child: const Text('浏览器打开', style: TextStyle(fontSize: 13)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionRow(SubscriptionRecord item) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.blueTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('订',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.blue)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      item.host,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.text),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.displayUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              Text(
                _formatDate(item.createdAt),
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: TextButton(
                    onPressed: () => _copyRecord(item.id),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.blue,
                      foregroundColor: AppColors.card,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('复制链接', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: TextButton(
                    onPressed: () => _confirmDelete(item.id),
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.dangerTint,
                      foregroundColor: AppColors.danger,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('删除', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(String title, String description) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: <Widget>[
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.text)),
          const SizedBox(height: 8),
          Text(
            description,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.muted, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Text(
        '仅用于发布页读取与订阅链接获取，不提供代理或 VPN 连接',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 10, color: Color(0xFF829AB1)),
      ),
    );
  }

  Widget _buildMessageBanner() {
    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Container(
        padding: const EdgeInsets.fromLTRB(13, 9, 8, 9),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _messageIsError ? const Color(0xFFF5B7B1) : const Color(0xFFB7E4D1),
          ),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Color(0x22000000), blurRadius: 12, offset: Offset(0, 5)),
          ],
        ),
        child: Row(
          children: <Widget>[
            Text(
              _messageIsError ? '!' : '✓',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _messageIsError ? AppColors.danger : AppColors.success,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _message,
                style: TextStyle(fontSize: 12, color: _messageIsError ? AppColors.danger : AppColors.text),
              ),
            ),
            SizedBox(
              height: 30,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    _message = '';
                  });
                },
                child: const Text('关闭', style: TextStyle(fontSize: 11, color: AppColors.muted)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      counterText: '',
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF829AB1)),
      filled: true,
      fillColor: AppColors.inputFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: const BorderSide(color: AppColors.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: const BorderSide(color: AppColors.blue),
      ),
    );
  }

  Future<void> _refreshEntries() async {
    if (_loadingEntries) {
      return;
    }
    final String input = _readmeController.text.trim();
    if (input.isEmpty) {
      _showMessage('请输入发布页链接', true);
      return;
    }
    setState(() {
      _loadingEntries = true;
    });
    try {
      final String readme = await _fetchReadme(input);
      final List<String> urls = discoverEntryLinks(readme);
      if (urls.isEmpty) {
        throw AppException('发布页中没有找到可用入口');
      }
      await _readmeRepository.save(input);
      if (!mounted) {
        return;
      }
      setState(() {
        _entries = urls;
      });
      _showMessage('已发现 ${urls.length} 个入口', false);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _entries = <String>[];
      });
      _showMessage(_errorMessage(error, '读取发布页失败，请检查链接或网络'), true);
    } finally {
      if (mounted) {
        setState(() {
          _loadingEntries = false;
        });
      }
    }
  }

  Future<String> _fetchReadme(String input) async {
    final List<String> candidates = readmeFetchCandidates(input);
    if (candidates.isEmpty) {
      throw AppException('请输入有效的 HTTPS 发布页链接');
    }
    final Completer<String> completer = Completer<String>();
    int pending = candidates.length;
    for (final String source in candidates) {
      unawaited(_http.getText(source).then<void>((String content) {
        if (content.trim().isNotEmpty) {
          if (!completer.isCompleted) {
            completer.complete(content);
          }
          return;
        }
        pending -= 1;
        if (pending == 0 && !completer.isCompleted) {
          completer.completeError(AppException('发布页读取失败：所有源均返回空内容'));
        }
      }).catchError((Object error) {
        pending -= 1;
        if (pending == 0 && !completer.isCompleted) {
          completer.completeError(AppException('发布页读取失败：请检查链接或网络'));
        }
      }));
    }
    return completer.future;
  }

  Future<void> _loadSubscriptions() async {
    try {
      final List<SubscriptionRecord> subscriptions = await _repository.list();
      if (mounted) {
        setState(() {
          _subscriptions = subscriptions;
        });
      }
    } catch (_) {
      // 列表读取失败时静默，下次操作会重试
    }
  }

  Future<void> _refreshAccountState() async {
    try {
      final AccountCredentials? credentials = await _accountRepository.loadCredentials();
      if (mounted) {
        setState(() {
          _hasSavedAccount = credentials != null;
          _savedEmailHint = credentials == null ? '' : _maskEmail(credentials.email);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _hasSavedAccount = false;
          _savedEmailHint = '';
        });
      }
    }
  }

  Future<void> _saveAccount() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      _showMessage('请填写邮箱和密码', true);
      return;
    }
    try {
      await _accountRepository.saveCredentials(email, password);
      _emailController.clear();
      _passwordController.clear();
      await _refreshAccountState();
      _showMessage('账号已安全保存', false);
    } catch (error) {
      _showMessage(_errorMessage(error, '保存账号失败'), true);
    }
  }

  Future<void> _clearAccount() async {
    try {
      await _accountRepository.clearCredentials();
      await _refreshAccountState();
      _showMessage('已清除记住的账号', false);
    } catch (error) {
      _showMessage(_errorMessage(error, '清除账号失败'), true);
    }
  }

  Future<List<String>?> _confirmTrustedEntries(List<String> entries) {
    final Set<String> selected = <String>{};
    return showDialog<List<String>>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: const Text('确认可信入口'),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        '登录时，你的账号和密码会发送给勾选的站点。请先通过服务提供方的官方渠道核实域名。HTTPS 不代表站点本身可信。',
                      ),
                      const SizedBox(height: 12),
                      ...entries.map((String entry) {
                        final Uri? uri = Uri.tryParse(entry);
                        final String host = uri?.host ?? entry;
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          value: selected.contains(entry),
                          title: Text(host, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: Text(entry, maxLines: 2, overflow: TextOverflow.ellipsis),
                          onChanged: (bool? checked) {
                            setDialogState(() {
                              if (checked == true) {
                                selected.add(entry);
                              } else {
                                selected.remove(entry);
                              }
                            });
                          },
                        );
                      }),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: selected.isEmpty
                      ? null
                      : () => Navigator.of(dialogContext).pop(
                            entries.where(selected.contains).toList(),
                          ),
                  child: const Text('信任所选入口并继续'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _fetchSubscription() async {
    if (_fetching) {
      return;
    }
    if (_entries.isEmpty) {
      _showMessage('请先读取发布页获取入口', true);
      return;
    }
    setState(() {
      _fetching = true;
    });
    try {
      final String email = _emailController.text.trim();
      final String password = _passwordController.text;
      final bool hasNewCredentials = email.isNotEmpty && password.isNotEmpty;
      AccountCredentials? credentials;
      if (hasNewCredentials) {
        credentials = AccountCredentials(email: email, password: password);
      } else {
        credentials = await _accountRepository.loadCredentials();
      }
      if (credentials == null) {
        _showMessage('请先填写机场账号密码', true);
        return;
      }

      final List<String>? trustedEntries = await _confirmTrustedEntries(_entries);
      if (!mounted || trustedEntries == null || trustedEntries.isEmpty) {
        return;
      }

      if (hasNewCredentials) {
        await _accountRepository.saveCredentials(email, password);
        _emailController.clear();
        _passwordController.clear();
        await _refreshAccountState();
      }

      final SubscriptionFetchResult result =
          await fetchSubscriptionUrl(_http, trustedEntries, credentials);
      await _repository.save(result.subscriptionUrl);
      await _loadSubscriptions();
      if (!mounted) {
        return;
      }
      setState(() {
        _resultUrl = result.subscriptionUrl;
        _resultPanel = result.panelName;
      });
      _showMessage('已获取订阅（${result.panelName}）', false);
    } catch (error) {
      _showMessage(_errorMessage(error, '自动获取订阅失败'), true);
    } finally {
      if (mounted) {
        setState(() {
          _fetching = false;
        });
      }
    }
  }

  Future<void> _copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    _showMessage('已复制，使用后建议清空剪贴板', false);
  }

  Future<void> _copyRecord(String id) async {
    try {
      final String secret = await _repository.reveal(id);
      await _copyText(secret);
    } catch (error) {
      _showMessage(_errorMessage(error, '无法读取订阅'), true);
    }
  }

  Future<void> _openResultInBrowser() async {
    try {
      await PlatformServices.openUrl(_resultUrl);
    } catch (error) {
      _showMessage(_errorMessage(error, '操作失败'), true);
    }
  }

  Future<void> _confirmDelete(String id) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('删除这条订阅？', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: const Text(
            '删除后无法恢复，需要重新登录获取。',
            style: TextStyle(fontSize: 13, color: AppColors.muted, height: 1.5),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              style: TextButton.styleFrom(foregroundColor: AppColors.muted),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              child: const Text('确认删除'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      try {
        await _repository.remove(id);
        await _loadSubscriptions();
        _showMessage('订阅已删除', false);
      } catch (error) {
        _showMessage(_errorMessage(error, '操作失败'), true);
      }
    }
  }

  void _showMessage(String text, bool isError) {
    if (!mounted) {
      return;
    }
    _messageTimer?.cancel();
    setState(() {
      _message = text;
      _messageIsError = isError;
    });
    _messageTimer = Timer(const Duration(milliseconds: 4200), () {
      if (mounted) {
        setState(() {
          _message = '';
        });
      }
    });
  }

  String _formatDate(int timestamp) {
    final DateTime date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '$month-$day';
  }

  String _maskEmail(String email) {
    final int at = email.indexOf('@');
    if (at <= 1) {
      return email;
    }
    final String prefix = email.substring(0, at < 2 ? at : 2);
    return '$prefix***${email.substring(at)}';
  }

  String _errorMessage(Object error, String fallback) {
    if (error is AppException && error.message.isNotEmpty) {
      return error.message;
    }
    if (error is Exception) {
      final String text = error.toString();
      if (text.startsWith('Exception: ') && text.length > 11) {
        return text.substring(11);
      }
    }
    return fallback;
  }
}
