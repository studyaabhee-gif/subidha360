import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/phone_extensions.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../data/auth_repository.dart';
import '../providers/auth_controller.dart';
import 'auth_frame.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({required this.phone, super.key});

  static const codeLength = 6;
  static const resendWait = 60;

  final String phone;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  var _secondsLeft = OtpScreen.resendWait;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = OtpScreen.resendWait);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsLeft <= 1) timer.cancel();
      setState(() => _secondsLeft--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // On success the router moves on by itself.
      await ref
          .read(authControllerProvider.notifier)
          .verifyOtp(widget.phone, _code.text);
    } on ApiException catch (error) {
      if (!mounted) return;
      _code.clear();
      setState(() {
        _busy = false;
        _error = error.message;
      });
      _focus.requestFocus();
    }
  }

  Future<void> _resend() async {
    try {
      await ref.read(authRepositoryProvider).requestOtp(widget.phone);
      if (!mounted) return;
      _code.clear();
      setState(() => _error = null);
      _startTimer();
      context.showMessage(tr('New code sent'));
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = context.text.bodyMedium!.copyWith(
      color: context.palette.muted,
    );
    return Scaffold(
      appBar: AppBar(),
      body: AuthFrame(
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.gapXl),
          children: [
            Text(tr('Enter your code'), style: context.text.headlineMedium),
            const SizedBox(height: AppTheme.gapSm),
            Text(
              tr('We sent a 6-digit code to {0}.', [
                widget.phone.asDisplayPhone,
              ]),
              style: muted,
            ),
            const SizedBox(height: AppTheme.gapXxl),
            _CodeBoxes(
              controller: _code,
              focusNode: _focus,
              hasError: _error != null,
              enabled: !_busy,
              onComplete: _verify,
            ),
            const SizedBox(height: AppTheme.gapMd),
            if (_error != null)
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: context.text.bodySmall!.copyWith(
                  color: context.colors.error,
                ),
              ),
            if (_busy)
              const Center(
                child: SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.6),
                ),
              ),
            const SizedBox(height: AppTheme.gapLg),
            Center(
              child: _secondsLeft > 0
                  ? Text(
                      tr('Resend code in {0}s', [_secondsLeft]),
                      style: muted,
                    )
                  : TextButton(
                      onPressed: _resend,
                      child: Text(tr('Resend code')),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Six boxes over one real text field, so paste, SMS autofill and the keyboard
/// all behave normally. The code submits itself when complete.
class _CodeBoxes extends StatelessWidget {
  const _CodeBoxes({
    required this.controller,
    required this.focusNode,
    required this.hasError,
    required this.enabled,
    required this.onComplete,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasError;
  final bool enabled;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ListenableBuilder(
          listenable: Listenable.merge([controller, focusNode]),
          builder: (context, _) => Row(
            children: [
              for (var i = 0; i < OtpScreen.codeLength; i++) ...[
                if (i > 0) const SizedBox(width: AppTheme.gapSm),
                Expanded(child: _box(context, i)),
              ],
            ],
          ),
        ),
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              key: const Key('otp-field'),
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              enabled: enabled,
              showCursor: false,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(OtpScreen.codeLength),
              ],
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
              ),
              onChanged: (value) {
                if (value.length == OtpScreen.codeLength) onComplete();
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _box(BuildContext context, int index) {
    final code = controller.text;
    final current = focusNode.hasFocus && index == code.length;
    final color = hasError
        ? context.colors.error
        : current
        ? context.colors.primary
        : context.palette.line;
    return AspectRatio(
      aspectRatio: 0.86,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.colors.surface,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: color, width: current ? 1.8 : 1.2),
        ),
        child: Text(
          index < code.length ? code[index] : '',
          style: context.text.headlineSmall,
        ),
      ),
    );
  }
}
