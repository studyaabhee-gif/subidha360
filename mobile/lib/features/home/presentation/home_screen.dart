import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/layout_extensions.dart';
import '../../../core/extensions/phone_extensions.dart';
import '../../../core/l10n/tr.dart';
import '../../../core/providers/role_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui.dart';
import '../../auth/providers/auth_controller.dart';
import '../../jobs/presentation/my_jobs_tab.dart';
import '../../notifications/data/notification_repository.dart';
import '../../notifications/presentation/inbox_tab.dart';
import '../../wallet/presentation/wallet_tab.dart';
import '../data/account_api.dart';
import 'dashboard_widgets.dart';
import 'profile_tab.dart';
import 'provider_dashboard.dart';
import 'role_switch.dart';
import 'seeker_dashboard.dart';

/// One place in the signed-in app.
typedef _Destination = ({
  IconData icon,
  IconData selected,
  String label,
  String title,
});

const _seekerTabs = <_Destination>[
  (
    icon: Icons.home_outlined,
    selected: Icons.home_rounded,
    label: 'Home',
    title: 'Home',
  ),
  (
    icon: Icons.work_outline_rounded,
    selected: Icons.work_rounded,
    label: 'My jobs',
    title: 'My jobs',
  ),
  (
    icon: Icons.account_balance_wallet_outlined,
    selected: Icons.account_balance_wallet_rounded,
    label: 'Wallet',
    title: 'Wallet',
  ),
  (
    icon: Icons.notifications_none_rounded,
    selected: Icons.notifications_rounded,
    label: 'Inbox',
    title: 'Notifications',
  ),
  (
    icon: Icons.person_outline_rounded,
    selected: Icons.person_rounded,
    label: 'Profile',
    title: 'Profile',
  ),
];

const _providerTabs = <_Destination>[
  (
    icon: Icons.home_outlined,
    selected: Icons.home_rounded,
    label: 'Home',
    title: 'Home',
  ),
  (
    icon: Icons.travel_explore_outlined,
    selected: Icons.travel_explore_rounded,
    label: 'Find work',
    title: 'Open jobs near you',
  ),
  (
    icon: Icons.handyman_outlined,
    selected: Icons.handyman_rounded,
    label: 'My work',
    title: 'My work',
  ),
  (
    icon: Icons.notifications_none_rounded,
    selected: Icons.notifications_rounded,
    label: 'Inbox',
    title: 'Notifications',
  ),
  (
    icon: Icons.person_outline_rounded,
    selected: Icons.person_rounded,
    label: 'Profile',
    title: 'Profile',
  ),
];

/// The inbox sits at the same place for both roles.
const _inboxTab = 3;

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({this.initialTab = 0, super.key});

  final int initialTab;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late var _tab = widget.initialTab;

  Future<void> _select(int index) async {
    setState(() => _tab = index);
    if (index == _inboxTab) {
      // Opening the inbox counts as reading it. The list loads first, so the
      // new ones still show as new during this visit.
      try {
        ref.invalidate(inboxProvider);
        await ref.read(inboxProvider.future);
        await ref.read(accountApiProvider).markRead();
      } catch (_) {
        // The badge simply stays until next time.
      }
      ref.invalidate(unreadCountProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authControllerProvider).value;
    final canProvide = user?.hasProviderProfile ?? false;
    // A saved Provider role means nothing without a provider profile.
    final isProvider =
        canProvide && ref.watch(activeRoleProvider) == UiRole.provider;
    // Switching role starts on Home, since the tabs differ.
    ref.listen(activeRoleProvider, (_, _) => setState(() => _tab = 0));
    final unread = ref.watch(unreadCountProvider).value ?? 0;
    final tabs = isProvider ? _providerTabs : _seekerTabs;
    final wide = context.isWide;

    final pages = isProvider
        ? [
            ProviderDashboard(onOpenTab: _select),
            const _Narrow(child: JobFeedTab(only: ProviderView.open)),
            const _Narrow(child: JobFeedTab(only: ProviderView.mine)),
            const _Narrow(child: InboxTab()),
            const _Narrow(child: ProfileTab()),
          ]
        : [
            SeekerDashboard(onOpenTab: _select),
            const _Narrow(child: MyJobsTab()),
            const _Narrow(child: WalletTab()),
            const _Narrow(child: InboxTab()),
            const _Narrow(child: ProfileTab()),
          ];
    final body = IndexedStack(index: _tab, children: pages);

    Widget icon(_Destination d, int i, {required bool selected}) {
      final glyph = Icon(selected ? d.selected : d.icon);
      if (i != _inboxTab || unread == 0) return glyph;
      return Badge.count(count: unread, child: glyph);
    }

    if (wide) {
      return Scaffold(
        backgroundColor: context.palette.page,
        body: Row(
          children: [
            _Sidebar(
              tabs: tabs,
              current: _tab,
              onSelect: _select,
              iconFor: icon,
              canProvide: canProvide,
              isProvider: isProvider,
            ),
            VerticalDivider(width: 1, color: context.palette.line),
            Expanded(
              child: Column(
                children: [
                  _TopBar(title: tr(tabs[_tab].title)),
                  Expanded(child: body),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: context.palette.page,
      appBar: AppBar(
        toolbarHeight: 60,
        titleSpacing: AppTheme.gapLg,
        title: _tab == 0
            ? const Row(
                children: [
                  BrandMark(size: 32),
                  SizedBox(width: AppTheme.gapSm),
                  Flexible(
                    child: FittedBox(fit: BoxFit.scaleDown, child: Wordmark()),
                  ),
                ],
              )
            : Text(tr(tabs[_tab].title)),
        actions: [
          IconButton(
            tooltip: tr('Services'),
            onPressed: () => context.push('/services'),
            icon: const Icon(Icons.grid_view_rounded),
          ),
          IconButton(
            tooltip: tr('Help and support'),
            onPressed: () => context.push('/help'),
            icon: const Icon(Icons.support_agent_outlined),
          ),
          const SizedBox(width: AppTheme.gapXs),
        ],
        bottom: _tab == 0 && canProvide
            ? const PreferredSize(
                preferredSize: Size.fromHeight(60),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    AppTheme.gapLg,
                    0,
                    AppTheme.gapLg,
                    AppTheme.gapMd,
                  ),
                  child: RoleSwitch(),
                ),
              )
            : null,
      ),
      body: body,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.palette.line)),
        ),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: _select,
          destinations: [
            for (var i = 0; i < tabs.length; i++)
              NavigationDestination(
                icon: icon(tabs[i], i, selected: false),
                selectedIcon: icon(tabs[i], i, selected: true),
                label: tr(tabs[i].label),
              ),
          ],
        ),
      ),
    );
  }
}

/// Lists and forms read best at a comfortable width.
class _Narrow extends StatelessWidget {
  const _Narrow({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820),
        child: child,
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.gapXl),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(bottom: BorderSide(color: context.palette.line)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(title, style: context.text.titleLarge)),
          TextButton.icon(
            onPressed: () => context.push('/services'),
            icon: const Icon(Icons.grid_view_rounded, size: 18),
            label: Text(tr('Services')),
          ),
          const SizedBox(width: AppTheme.gapSm),
          TextButton.icon(
            onPressed: () => context.push('/help'),
            icon: const Icon(Icons.support_agent_outlined, size: 18),
            label: Text(tr('Help')),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends ConsumerWidget {
  const _Sidebar({
    required this.tabs,
    required this.current,
    required this.onSelect,
    required this.iconFor,
    required this.canProvide,
    required this.isProvider,
  });

  final List<_Destination> tabs;
  final int current;
  final ValueChanged<int> onSelect;
  final Widget Function(_Destination, int, {required bool selected}) iconFor;
  final bool canProvide;
  final bool isProvider;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).value;
    final name = user?.displayName ?? '';
    final muted = context.text.bodySmall!.copyWith(
      color: context.palette.muted,
    );
    return SizedBox(
      width: 252,
      child: Material(
        color: context.colors.surface,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: () => context.go('/'),
                child: const Padding(
                  padding: EdgeInsets.fromLTRB(20, 14, 20, 14),
                  child: Row(
                    children: [
                      BrandMark(size: 36),
                      SizedBox(width: AppTheme.gapSm),
                      Wordmark(),
                    ],
                  ),
                ),
              ),
              if (canProvide)
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
                  child: RoleSwitch(),
                ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (var i = 0; i < tabs.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: ListTile(
                          selected: i == current,
                          selectedTileColor: context.colors.primaryContainer,
                          selectedColor: context.colors.onPrimaryContainer,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusMd,
                            ),
                          ),
                          leading: iconFor(tabs[i], i, selected: i == current),
                          title: Text(
                            tr(tabs[i].label),
                            style: context.text.titleSmall,
                          ),
                          onTap: () => onSelect(i),
                        ),
                      ),
                    const SizedBox(height: AppTheme.gapMd),
                    if (!isProvider)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: FilledButton.icon(
                          onPressed: () => context.push('/jobs/new'),
                          icon: const Icon(Icons.add_rounded),
                          label: Text(tr('Post a job')),
                        ),
                      ),
                  ],
                ),
              ),
              Divider(height: 1, color: context.palette.line),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                onTap: () => onSelect(tabs.length - 1),
                leading: CircleAvatar(
                  backgroundColor: context.colors.primaryContainer,
                  foregroundColor: context.colors.onPrimaryContainer,
                  child: name.isEmpty
                      ? const Icon(Icons.person_rounded)
                      : Text(initials(name)),
                ),
                title: Text(
                  name.isEmpty ? tr('Add your name') : name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall,
                ),
                subtitle: Text(
                  user?.phoneNumber.asDisplayPhone ?? '',
                  style: muted,
                ),
              ),
              const SizedBox(height: AppTheme.gapSm),
            ],
          ),
        ),
      ),
    );
  }
}
