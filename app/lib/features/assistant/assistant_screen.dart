import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kolbi_core/kolbi_core.dart' show placeSearchStartFor;
import 'package:kolbi_ui/kolbi_ui.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/config/app_settings.dart';
import '../../shell/navigation.dart';
import '../../shell/request_intake.dart';
import 'assistant_controller.dart';
import 'mic_consent_sheet.dart';
import 'request_box.dart';
import 'speech/speech_recognizer.dart';

/// SCR-A01, `/assistant` outside the tab shell: always immersive dark (REQ-001). Voice mode listens through
/// the speech port; text mode holds today's request box (REQ-008). Everything it opens is one of its child
/// routes (REQ-009).
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key, this.textMode = false, this.fill});

  /// `/assistant?mode=text`.
  final bool textMode;

  /// A request start for the input ("{이름}에 ", from today's recent places); opens in text mode.
  final String? fill;

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen>
    with WidgetsBindingObserver {
  final _input = TextEditingController();
  late final AssistantController _controller;
  bool _sending = false;

  bool get _canSend => !_sending && _input.text.trim().length >= 2;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AssistantController(
      recognizer: ref.read(speechRecognizerProvider),
      memory: ref.read(assistantMemoryProvider),
      onFinal: _submit,
      needsSpeechServiceNotice: _needsSpeechServiceNotice,
      acknowledgeSpeechServiceNotice: _acknowledgeSpeechServiceNotice,
    )..addListener(_onState);
    if (widget.fill case final fill?) _fill(fill);
    _controller.start(textMode: widget.textMode || widget.fill != null);
  }

  // OD-2 deviation (owner decision 2026-11-28): on Android the plugin may use the network recognizer
  // without telling the app, so the speech-service sentence is shown once, up front.
  bool _needsSpeechServiceNotice() =>
      defaultTargetPlatform == TargetPlatform.android &&
      !(ref
              .read(sharedPreferencesProvider)
              .getBool(androidSpeechServiceNoticeKey) ??
          false);

  void _acknowledgeSpeechServiceNotice() => ref
      .read(sharedPreferencesProvider)
      .setBool(androidSpeechServiceNoticeKey, true);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    _input.dispose();
    super.dispose();
  }

  /// REQ-007: the background (`paused`, `hidden`) ends dictation; `inactive` (the OS permission dialog) does not.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _controller.cancel();
    }
  }

  AssistantPhase? _phase;
  String _announced = const AssistantState(AssistantPhase.idle).statusLabel;

  void _onState() {
    final next = _controller.value;
    _announce(next);
    final entering = next.isText && _phase != AssistantPhase.text;
    _phase = next.phase;
    if (entering && next.words.isNotEmpty) _fill(next.words);
    setState(() {});
  }

  /// REQ-002 / REQ-014: one polite announcement per change of the status chip, never for partial words; the
  /// final sentence is read with the change to processing.
  void _announce(AssistantState state) {
    if (state.isText || state.statusLabel == _announced) return;
    _announced = state.statusLabel;
    final message = state.phase == AssistantPhase.processing
        ? '${state.statusLabel}. ${state.words}'
        : state.statusLabel;
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      TextDirection.ltr,
    );
  }

  /// Replaces the input and puts the cursor at the end, so the user can keep typing.
  void _fill(String text) => setState(() {
    _input.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  });

  /// One path for spoken and typed requests (SPEC-INTAKE-001 REQ-017, REQ-022; REQ-009).
  Future<void> _submit(String text) async {
    final router = GoRouter.of(context);
    final spoken = !_controller.value.isText;
    if (!ref.read(settingsProvider).hasProfile) {
      // The plan card needs the requester's name; the sentence waits in the input meanwhile.
      if (spoken) _controller.keepAsText(text);
      openAssistantSettings(router);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    final result = await requestIntake(ref, messenger, text);
    if (!mounted) return;
    setState(() => _sending = false);
    // Back from the plan card or place selection (or after an error) the sentence is still there to edit.
    if (spoken) _controller.keepAsText(text);
    if (result == null) return;
    // SPEC-PLACE-001 REQ-009: no number and not blocked → choose a place first.
    final start = placeSearchStartFor(text, result);
    if (start != null) {
      openAssistantPlaces(router, start);
    } else {
      openAssistantPlan(router, result.draft);
    }
  }

  void _sendTyped() {
    final text = _input.text.trim();
    if (_canSend) _submit(text);
  }

  void _close() {
    _controller.cancel();
    closeAssistant(GoRouter.of(context));
  }

  @override
  Widget build(BuildContext context) {
    final state = _controller.value;
    return Theme(
      data: KolbiTheme.immersive(),
      child: Builder(
        builder: (context) => Scaffold(
          key: const Key('assistant-screen'),
          appBar: AppBar(
            leading: CloseButton(
              key: const Key('assistant-close'),
              onPressed: _close,
            ),
            title: const Text('AI 비서'),
          ),
          body: SafeArea(
            child: state.isText
                ? _textMode(context, state)
                : _voiceMode(context, state),
          ),
        ),
      ),
    );
  }

  /// The decorative orb (REQ-002); the screen states the same thing in the chip.
  Widget _orb(AssistantState state, double size) => KolbiOrb(
    key: const Key('assistant-orb'),
    size: size,
    state: switch (state.phase) {
      AssistantPhase.listening => KolbiOrbState.listening,
      AssistantPhase.processing => KolbiOrbState.processing,
      _ => KolbiOrbState.idle,
    },
  );

  Widget _textMode(BuildContext context, AssistantState state) {
    final settings = ref.watch(settingsProvider);
    final router = GoRouter.of(context);
    return ResponsiveBody(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.lg,
          AppSpace.sm,
          AppSpace.lg,
          AppSpace.xxl,
        ),
        children: [
          Center(child: _orb(state, 56)),
          if (state.notice case final notice?) ...[
            const SizedBox(height: AppSpace.md),
            Text(notice, textAlign: TextAlign.center),
          ],
          RequestBox(
            input: _input,
            sending: _sending,
            onChanged: () => setState(() {}),
            onSend: _canSend ? _sendTyped : null,
            onManual: () => settings.hasProfile
                ? openAssistantManual(router)
                : openAssistantSettings(router),
            onFill: _fill,
          ),
        ],
      ),
    );
  }

  Widget _voiceMode(BuildContext context, AssistantState state) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final templates = ref.watch(requestTemplatesProvider).take(2);
    final listening = state.phase == AssistantPhase.listening;
    return Column(
      children: [
        Expanded(
          child: ResponsiveBody(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.lg,
                AppSpace.sm,
                AppSpace.lg,
                AppSpace.lg,
              ),
              children: [
                Center(
                  child: Chip(
                    key: const Key('assistant-status-chip'),
                    label: Text(state.statusLabel),
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                Center(
                  // While waiting, tapping the orb listens again; the tap target carries the label, the
                  // orb itself stays out of the semantics tree.
                  child: state.phase == AssistantPhase.idle
                      ? Semantics(
                          button: true,
                          label: '말하기 시작',
                          child: GestureDetector(
                            excludeFromSemantics: true,
                            onTap: _controller.tapOrb,
                            child: _orb(state, 160),
                          ),
                        )
                      : _orb(state, 160),
                ),
                const SizedBox(height: AppSpace.lg),
                Text(
                  '무엇을 도와드릴까요?',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  '말씀해 주시면 제가 대신 처리할게요.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpace.lg),
                if (state.words.isNotEmpty)
                  Text(
                    state.words,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                if (state.notice case final notice?)
                  Text(notice, textAlign: TextAlign.center),
                if (state.phase == AssistantPhase.consent)
                  MicConsentSheet(
                    onContinue: _controller.acceptConsent,
                    withSpeechService: _needsSpeechServiceNotice(),
                  ),
                if (state.phase == AssistantPhase.speechServiceNotice)
                  SpeechServiceNotice(
                    onContinue: _controller.acceptSpeechServiceNotice,
                    onText: _controller.switchToText,
                  ),
                if (state.phase == AssistantPhase.fallbackConsent)
                  GeneralRecognizerNotice(
                    onContinue: _controller.acceptGeneralRecognizer,
                    onText: _controller.switchToText,
                  ),
                if (state.phase == AssistantPhase.settingsNeeded)
                  MicSettingsNotice(onOpenSettings: _controller.openSettings),
                const SizedBox(height: AppSpace.xl),
                Text(
                  '이렇게 부탁해 보세요',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpace.sm),
                Wrap(
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.sm,
                  children: [
                    for (final template in templates)
                      ActionChip(
                        label: Text(template.label),
                        onPressed: () {
                          // REQ-001: an example fills the text input; it is not sent.
                          _controller.switchToText();
                          _fill(template.goal);
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        ResponsiveBody(
          shrinkHeight: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.lg,
              AppSpace.sm,
              AppSpace.lg,
              AppSpace.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _controller.switchToText,
                    child: const Text('글로 입력', semanticsLabel: '글로 입력하기'),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: FilledButton(
                    onPressed: listening ? _controller.finishSpeaking : null,
                    child: const Text('말하기 끝', semanticsLabel: '말하기 끝내고 보내기'),
                  ),
                ),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: TextButton(
                    onPressed: _close,
                    child: const Text('그만하기', semanticsLabel: '그만하기'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
