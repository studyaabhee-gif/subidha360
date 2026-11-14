import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/phone_extensions.dart';
import '../../../core/l10n/language.dart';
import '../../../core/l10n/tr.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/providers/auth_controller.dart';
import '../../provider/presentation/provider_tools.dart';
import '../data/account_api.dart';
import 'dashboard_widgets.dart';
import 'role_switch.dart';

class ProfileTab extends ConsumerWidget {
  const ProfileTab({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final yes = await context.confirm(
      title: tr('Log out?'),
      message: tr("You'll need a new code to log back in on this device."),
      action: tr('Log out'),
      destructive: true,
    );
    if (yes) await ref.read(authControllerProvider.notifier).logout();
  }

  Future<void> _editName(BuildContext context, WidgetRef ref) async {
    final name = await context.askForText(
      title: tr('Your name'),
      message: tr('This is the name others see on your jobs and bids.'),
      label: tr('Full name'),
      action: tr('Save'),
    );
    if (name == null) return;
    try {
      final user = await ref.read(authRepositoryProvider).updateName(name);
      ref.read(authControllerProvider.notifier).setUser(user);
    } catch (error) {
      if (context.mounted) context.showError(error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final canProvide = user?.hasProviderProfile ?? false;
    final name = user?.displayName ?? '';
    final muted = context.text.bodySmall!.copyWith(
      color: context.palette.muted,
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gapLg,
        AppTheme.gapLg,
        AppTheme.gapLg,
        AppTheme.gapXxl,
      ),
      children: [
        AppCard(
          onTap: () => _editName(context, ref),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: context.colors.primaryContainer,
                foregroundColor: context.colors.onPrimaryContainer,
                child: name.isEmpty
                    ? const Icon(Icons.person_rounded, size: 30)
                    : Text(initials(name), style: context.text.titleLarge),
              ),
              const SizedBox(width: AppTheme.gapLg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty ? tr('Add your name') : name,
                      style: context.text.titleLarge,
                    ),
                    Text(user?.phoneNumber.asDisplayPhone ?? '', style: muted),
                    if (user?.isVerified ?? false) ...[
                      const SizedBox(height: AppTheme.gapXs),
                      Pill(
                        label: tr('Verified'),
                        tone: Tone.success,
                        icon: Icons.verified_rounded,
                      ),
                    ],
                  ],
                ),
              ),
              Icon(Icons.edit_outlined, size: 20, color: context.palette.muted),
            ],
          ),
        ),
        const SizedBox(height: AppTheme.gapXl),
        if (canProvide) ...[
          SectionTitle(tr('Using the app to')),
          const RoleSwitch(),
          const SizedBox(height: AppTheme.gapXl),
          const ProviderTools(),
          const SizedBox(height: AppTheme.gapLg),
        ] else
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.gapXl),
            child: AppCard(
              onTap: () => context.push('/provider-setup'),
              child: Row(
                children: [
                  const IconTile(
                    icon: Icons.handyman_rounded,
                    tone: Tone.warning,
                  ),
                  const SizedBox(width: AppTheme.gapMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('Earn with Subidha360'),
                          style: context.text.titleSmall,
                        ),
                        Text(
                          tr('Become a provider and bid on jobs near you.'),
                          style: muted,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: context.palette.muted,
                  ),
                ],
              ),
            ),
          ),
        _Group(
          title: tr('Settings'),
          rows: [
            _Row(
              icon: Icons.translate_rounded,
              title: tr('Language'),
              trailing: const LanguageSwitch(),
            ),
            _Row(
              icon: Icons.badge_outlined,
              title: tr('Your name'),
              subtitle: name.isEmpty ? tr('Not set') : name,
              onTap: () => _editName(context, ref),
            ),
          ],
        ),
        _Group(
          title: tr('Your activity'),
          rows: [
            _Row(
              icon: Icons.favorite_border_rounded,
              title: tr('Favourite providers'),
              onTap: () => context.push('/favorites'),
            ),
            if (canProvide)
              _Row(
                icon: Icons.payments_outlined,
                title: tr('Earnings'),
                onTap: () => context.push('/provider/earnings'),
              ),
            if (user?.isAdmin ?? false)
              _Row(
                icon: Icons.admin_panel_settings_outlined,
                title: tr('Admin dashboard'),
                onTap: () => context.go('/admin'),
              ),
          ],
        ),
        _Group(
          title: tr('Help and policies'),
          rows: [
            _Row(
              icon: Icons.support_agent_outlined,
              title: tr('Help and support'),
              onTap: () => context.push('/help'),
            ),
            _Row(
              icon: Icons.verified_user_outlined,
              title: tr('Our 30-day guarantee'),
              onTap: () => context.push('/guarantee'),
            ),
            _Row(
              icon: Icons.description_outlined,
              title: tr('Terms of use'),
              onTap: () => context.push('/terms'),
            ),
            _Row(
              icon: Icons.privacy_tip_outlined,
              title: tr('Privacy policy'),
              onTap: () => context.push('/privacy'),
            ),
            _Row(
              icon: Icons.currency_exchange_rounded,
              title: tr('Refunds and cancellations'),
              onTap: () => context.push('/refunds'),
            ),
          ],
        ),
        _Group(
          title: tr('Account'),
          rows: [
            _Row(
              icon: Icons.logout_rounded,
              title: tr('Log out'),
              onTap: () => _logout(context, ref),
            ),
            _Row(
              icon: Icons.delete_outline_rounded,
              title: tr('Delete account'),
              subtitle: tr('Remove your account and personal details'),
              danger: true,
              onTap: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                constraints: const BoxConstraints(maxWidth: 560),
                builder: (_) => const _DeleteSheet(),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.title, required this.rows});

  final String title;
  final List<Widget> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.gapXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(title),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (var i = 0; i < rows.length; i++) ...[
                  if (i > 0) const Divider(height: 1, indent: 64),
                  rows[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? context.colors.error : null;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppTheme.gapLg,
        vertical: 2,
      ),
      onTap: onTap,
      leading: Icon(icon, color: color ?? context.colors.primary),
      title: Text(
        title,
        style: context.text.titleSmall!.copyWith(color: color),
      ),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing:
          trailing ??
          (onTap == null
              ? null
              : Icon(
                  Icons.chevron_right_rounded,
                  color: context.palette.muted,
                )),
    );
  }
}

/// Explains what deletion removes, shows anything that blocks it, and asks
/// the person to type DELETE.
class _DeleteSheet extends ConsumerStatefulWidget {
  const _DeleteSheet();

  @override
  ConsumerState<_DeleteSheet> createState() => _DeleteSheetState();
}

class _DeleteSheetState extends ConsumerState<_DeleteSheet> {
  late final Future<List<DeletionBlocker>> _blockers = ref
      .read(accountApiProvider)
      .deletionBlockers();
  final _confirm = TextEditingController();
  var _busy = false;

  @override
  void dispose() {
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    try {
      await ref.read(accountApiProvider).deleteAccount();
      if (!mounted) return;
      Navigator.pop(context);
      // The server has ended the session; clear it here too.
      await ref.read(authControllerProvider.notifier).logout();
    } catch (error) {
      if (mounted) context.showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = context.text.bodySmall!.copyWith(
      color: context.palette.muted,
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppTheme.gapXl,
        AppTheme.gapXl,
        AppTheme.gapXl,
        AppTheme.gapXl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: FutureBuilder<List<DeletionBlocker>>(
        future: _blockers,
        builder: (context, snap) {
          final blockers = snap.data ?? const [];
          final ready = snap.hasData && blockers.isEmpty;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tr('Delete your account?'), style: context.text.titleLarge),
              const SizedBox(height: AppTheme.gapSm),
              Text(
                tr(
                  'We remove your name, phone number, provider profile, '
                  'documents, photos, favourites and support messages. Past jobs '
                  'and payments stay on record without your details, as the law '
                  'requires. This cannot be undone.',
                ),
                style: muted,
              ),
              const SizedBox(height: AppTheme.gapLg),
              if (!snap.hasData && !snap.hasError)
                const Center(child: CircularProgressIndicator())
              else if (snap.hasError)
                Text(tr('Something went wrong. Please try again.'))
              else if (blockers.isNotEmpty) ...[
                InfoBanner(
                  tone: Tone.warning,
                  icon: Icons.info_outline_rounded,
                  title: tr('Not yet'),
                  message: blockers.map(_blockerText).join('\n'),
                ),
              ] else ...[
                TextField(
                  controller: _confirm,
                  decoration: InputDecoration(
                    labelText: tr('Type DELETE to confirm'),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppTheme.gapLg),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: context.colors.error,
                  ),
                  onPressed: ready && _confirm.text.trim() == 'DELETE' && !_busy
                      ? _delete
                      : null,
                  child: Text(tr('Delete my account')),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// The app's own wording for each reason, so it can be translated. The
/// server's message is the fallback for reasons this version doesn't know.
String _blockerText(DeletionBlocker b) => switch (b.code) {
  'admin' => tr('Admin accounts must have admin access removed first.'),
  'active_jobs' => tr(
    'You still have jobs open or in progress. Finish or cancel them first.',
  ),
  'wallet_balance' => tr(
    'Your wallet still has money in it. Withdraw it, or write to us through '
    'Help and we will return it.',
  ),
  'withdrawal_waiting' => tr('Wait until your withdrawal has been sent.'),
  _ => b.message,
};
