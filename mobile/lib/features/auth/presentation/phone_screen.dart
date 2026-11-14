import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/layout_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui.dart';
import '../data/auth_repository.dart';
import 'auth_frame.dart';

class PhoneScreen extends ConsumerStatefulWidget {
  const PhoneScreen({this.from, super.key});

  /// Where to return after logging in.
  final String? from;

  @override
  ConsumerState<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends ConsumerState<PhoneScreen> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final phone = '+977${_phone.text}';
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).requestOtp(phone);
      if (!mounted) return;
      context.push(
        Uri(
          path: '/otp',
          queryParameters: {'phone': phone, 'from': ?widget.from},
        ).toString(),
      );
    } catch (error) {
      if (mounted) context.showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: AuthFrame(
        child: Align(
          alignment: context.isWide ? Alignment.center : Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Form(
              key: _form,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppTheme.gapXl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const BrandMark(size: 44),
                        const SizedBox(width: AppTheme.gapMd),
                        Wordmark(style: context.text.titleLarge),
                      ],
                    ),
                    const SizedBox(height: AppTheme.gapXxl),
                    Text(
                      tr('Log in or sign up'),
                      style: context.text.headlineLarge,
                    ),
                    const SizedBox(height: AppTheme.gapSm),
                    Text(
                      tr(
                        "Enter your mobile number and we'll text you a code. "
                        'No password needed.',
                      ),
                      style: context.text.bodyLarge!.copyWith(
                        color: context.palette.muted,
                      ),
                    ),
                    const SizedBox(height: AppTheme.gapXl),
                    TextFormField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      autofillHints: const [
                        AutofillHints.telephoneNumberNational,
                      ],
                      style: context.text.titleMedium,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: InputDecoration(
                        labelText: tr('Mobile number'),
                        hintText: '98XXXXXXXX',
                        floatingLabelBehavior: FloatingLabelBehavior.always,
                        // prefixText would hide until the field has focus.
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(
                            left: AppTheme.gapLg,
                            right: AppTheme.gapSm,
                          ),
                          child: Text('+977', style: context.text.titleMedium),
                        ),
                        prefixIconConstraints: const BoxConstraints(),
                      ),
                      validator: (value) =>
                          RegExp(r'^9\d{9}$').hasMatch(value ?? '')
                          ? null
                          : tr('Enter a 10-digit number starting with 9'),
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const SizedBox(height: AppTheme.gapLg),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: Text(_busy ? tr('Sending...') : tr('Send code')),
                    ),
                    const SizedBox(height: AppTheme.gapMd),
                    const _Agreement(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Logging in agrees to the terms and privacy policy, so say so plainly and
/// link to both.
class _Agreement extends StatelessWidget {
  const _Agreement();

  @override
  Widget build(BuildContext context) {
    final muted = context.text.bodySmall!.copyWith(
      color: context.palette.muted,
    );
    Widget link(String label, String path) => InkWell(
      onTap: () => context.push(path),
      child: Text(
        label,
        style: muted.copyWith(
          color: context.colors.primary,
          decoration: TextDecoration.underline,
        ),
      ),
    );
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      runSpacing: 2,
      children: [
        Text(tr('By continuing you agree to our'), style: muted),
        link(tr('Terms of use'), '/terms'),
        Text(tr('and'), style: muted),
        link(tr('Privacy policy'), '/privacy'),
      ],
    );
  }
}
