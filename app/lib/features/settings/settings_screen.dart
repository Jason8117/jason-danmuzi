import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kolbi_core/kolbi_core.dart';
import 'package:kolbi_ui/kolbi_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/config/app_settings.dart';
import '../../core/widgets/trust_notice.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final AppSettings _initial = ref.read(settingsProvider);
  late final _name = TextEditingController(text: _initial.requesterName);
  late final _callback = TextEditingController(text: _initial.callbackNumber);
  late final _server = TextEditingController(text: _initial.serverUrl);
  late final _token = TextEditingController(text: _initial.apiToken);
  bool _obscureToken = true;
  bool _testing = false;
  String? _testResult;
  bool _testOk = false;

  @override
  void dispose() {
    for (final c in [_name, _callback, _server, _token]) {
      c.dispose();
    }
    super.dispose();
  }

  AppSettings get _draft => AppSettings(
        serverUrl: _server.text.trim().replaceAll(RegExp(r'/+$'), ''),
        apiToken: _token.text.trim(),
        requesterName: _name.text.trim(),
        callbackNumber: _callback.text.trim(),
      );

  Future<void> _testConnection() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final draft = _draft;
    final client = ApiClient(baseUrl: draft.serverUrl, token: draft.apiToken);
    try {
      final info = ServerInfo.fromJson(await client.get('/v1/config') as Map<String, dynamic>);
      _testOk = true;
      _testResult = info.realCalls
          ? '연결됨 · 실제 전화 모드 (${info.brain == 'openai' ? 'AI 계획' : '기본 계획'})'
          : '연결됨 · 시뮬레이션 모드 (실제 전화는 걸리지 않아요)';
    } catch (error) {
      _testOk = false;
      _testResult = describeError(error);
    } finally {
      client.close();
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(settingsProvider.notifier).save(_draft);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장했어요.')));
    if (context.canPop()) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ResponsiveBody(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.sm, AppSpace.xl, AppSpace.xxxl),
            children: [
              SectionCard(
                title: '내 정보',
                icon: Icons.person_outline,
                child: Column(
                  children: [
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: '이름', hintText: '예: 김민수', helperText: 'AI 비서가 "○○님을 대신해" 전화한다고 소개해요.'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? '이름을 입력해 주세요.' : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _callback,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: '회신 받을 번호 (선택)', hintText: '010-0000-0000', helperText: '상대가 다시 연락할 번호를 물으면 알려줘요.'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              SectionCard(
                title: '서버',
                icon: Icons.dns_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _server,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(labelText: '서버 주소', hintText: 'https://callmate.example.com'),
                      validator: (v) {
                        final uri = Uri.tryParse(v?.trim() ?? '');
                        return (uri == null || !uri.hasScheme || uri.host.isEmpty) ? 'http(s)://로 시작하는 주소를 입력해 주세요.' : null;
                      },
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _token,
                      obscureText: _obscureToken,
                      decoration: InputDecoration(
                        labelText: 'API 토큰',
                        helperText: '서버의 API_TOKEN 값. 로컬 시뮬레이션 서버는 비워둬도 돼요.',
                        suffixIcon: IconButton(
                          tooltip: _obscureToken ? '토큰 보기' : '토큰 숨기기',
                          icon: Icon(_obscureToken ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscureToken = !_obscureToken),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _testing ? null : _testConnection,
                      icon: _testing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.wifi_tethering),
                      label: const Text('연결 테스트'),
                    ),
                    if (_testResult != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        _testResult!,
                        style: theme.textTheme.bodyMedium?.copyWith(color: _testOk ? theme.colorScheme.primary : theme.colorScheme.error),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // SPEC-FOLLOWUP-001 REQ-015: always visible, not only before the first call.
              const SectionCard(
                title: 'AI 비서와 기록',
                icon: Icons.shield_outlined,
                child: TrustStatementList(),
              ),
              const SizedBox(height: 24),
              FilledButton(onPressed: _save, child: const Text('저장')),
            ],
          ),
        ),
      ),
    );
  }
}
