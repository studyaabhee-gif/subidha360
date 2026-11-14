import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/language.dart';
import '../../core/l10n/tr.dart';
import '../../features/auth/providers/auth_controller.dart';
import '../../features/jobs/domain/categories.dart';
import '../../features/legal/legal_pages.dart';
import '../extensions/context_extensions.dart';
import '../extensions/layout_extensions.dart';
import '../theme/app_theme.dart';
import 'nepal_graphics.dart';
import 'ui.dart';

const maxPageWidth = 1160.0;

/// Centres content at a comfortable reading width with page margins.
class PageWidth extends StatelessWidget {
  const PageWidth({
    required this.child,
    this.maxWidth = maxPageWidth,
    super.key,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final gutter = context.isWide ? AppTheme.gapXl : AppTheme.gapLg;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth + gutter * 2),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: gutter),
          // Fills the column, so content starts at the page margin.
          child: SizedBox(width: double.infinity, child: child),
        ),
      ),
    );
  }
}

/// The public website frame: header, scrolling page and footer.
class SiteScaffold extends StatelessWidget {
  const SiteScaffold({
    required this.children,
    this.flushFooter = false,
    super.key,
  });

  final List<Widget> children;

  /// Set when the page ends in a full-width photo that meets the footer.
  final bool flushFooter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const _SiteHeader(),
      endDrawer: context.isWide ? null : const _SiteDrawer(),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          ...children,
          _SiteFooter(flush: flushFooter),
        ],
      ),
    );
  }
}

class _SiteHeader extends ConsumerWidget implements PreferredSizeWidget {
  const _SiteHeader();

  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final signedIn = ref.watch(authControllerProvider).value != null;
    return Material(
      color: context.colors.surface,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: context.palette.line)),
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 67,
            child: PageWidth(
              child: Row(
                children: [
                  // Shrinks rather than overflowing on small phones with
                  // large text.
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Semantics(
                        button: true,
                        label: tr('Subidha360 home'),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusSm,
                          ),
                          onTap: () => context.go('/'),
                          child: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                BrandMark(size: 36),
                                SizedBox(width: AppTheme.gapSm + 2),
                                Wordmark(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (context.isWide) ...[
                    _HeaderLink(tr('Services'), () => context.go('/services')),
                    _HeaderLink(
                      tr('Our guarantee'),
                      () => context.go('/guarantee'),
                    ),
                    _HeaderLink(
                      tr('Become a provider'),
                      () => context.go('/become-provider'),
                    ),
                    const LanguageSwitch(),
                    const SizedBox(width: AppTheme.gapMd),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(110, 44),
                      ),
                      onPressed: () =>
                          context.go(signedIn ? '/home' : '/login'),
                      child: Text(signedIn ? tr('My account') : tr('Log in')),
                    ),
                  ] else ...[
                    const LanguageSwitch(compact: true),
                    TextButton(
                      onPressed: () =>
                          context.go(signedIn ? '/home' : '/login'),
                      child: Text(signedIn ? tr('Account') : tr('Log in')),
                    ),
                    Builder(
                      builder: (context) => IconButton(
                        tooltip: tr('Menu'),
                        icon: const Icon(Icons.menu_rounded),
                        onPressed: () => Scaffold.of(context).openEndDrawer(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderLink extends StatelessWidget {
  const _HeaderLink(this.label, this.onTap);

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(foregroundColor: context.colors.onSurface),
      onPressed: onTap,
      child: Text(label, style: context.text.titleSmall),
    );
  }
}

class _SiteDrawer extends StatelessWidget {
  const _SiteDrawer();

  @override
  Widget build(BuildContext context) {
    Widget link(String label, IconData icon, String path) => ListTile(
      leading: Icon(icon),
      title: Text(label, style: context.text.titleSmall),
      onTap: () {
        Navigator.pop(context);
        context.go(path);
      },
    );
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.gapLg),
          children: [
            link(tr('Home'), Icons.home_outlined, '/'),
            link(tr('Services'), Icons.grid_view_rounded, '/services'),
            link(
              tr('Our guarantee'),
              Icons.verified_user_outlined,
              '/guarantee',
            ),
            link(
              tr('Become a provider'),
              Icons.handyman_outlined,
              '/become-provider',
            ),
          ],
        ),
      ),
    );
  }
}

class _SiteFooter extends StatelessWidget {
  const _SiteFooter({required this.flush});

  /// True when the page ends in a full-width photo, so no gap or skyline.
  final bool flush;

  @override
  Widget build(BuildContext context) {
    final muted = context.text.bodySmall!.copyWith(
      color: context.palette.muted,
    );
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.gapSm),
      child: Text(text, style: context.text.titleSmall),
    );
    Widget link(String label, String path) => InkWell(
      onTap: () => context.go(path),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Text(label, style: muted),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(top: flush ? 0 : AppTheme.gapXxl + 16),
      child: Column(
        children: [
          if (!flush)
            HimalayaSkyline(
              color: context.colors.surface,
              farColor: context.palette.line,
              height: 90,
            ),
          const DhakaBand(height: 12),
          Container(
            color: context.colors.surface,
            padding: const EdgeInsets.symmetric(vertical: AppTheme.gapXxl + 8),
            child: PageWidth(
              child: Wrap(
                // Full width, so the columns start at the page margin.
                alignment: WrapAlignment.spaceBetween,
                spacing: 56,
                runSpacing: AppTheme.gapXl,
                children: [
                  SizedBox(
                    width: 300,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Wordmark(),
                        const SizedBox(height: AppTheme.gapSm),
                        Text(
                          tr(
                            'Home services in Nepal, with fair competing prices and '
                            'payment held safely until the work is done.',
                          ),
                          style: muted,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      heading(tr('Services')),
                      for (final category in serviceCategories.take(5))
                        link(category.name, '/services/${category.slug}'),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      heading(tr('Subidha360')),
                      link(tr('All services'), '/services'),
                      link(tr('Our guarantee'), '/guarantee'),
                      link(tr('Become a provider'), '/become-provider'),
                      link(tr('Photo credits'), '/photo-credits'),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      heading(tr('Legal')),
                      link(tr('Terms of use'), '/terms'),
                      link(tr('Privacy policy'), '/privacy'),
                      link(tr('Refunds and cancellations'), '/refunds'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const _CompanyLine(),
        ],
      ),
    );
  }
}

/// The registered company details Nepal requires businesses to show. Hidden
/// until an admin enters them.
class _CompanyLine extends ConsumerWidget {
  const _CompanyLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final company = ref.watch(companyProvider).value;
    if (company == null || !company.isSet) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      color: context.colors.surface,
      padding: const EdgeInsets.only(bottom: AppTheme.gapXl),
      child: PageWidth(
        child: Text(
          '© ${DateTime.now().year} ${companyLine(company)}',
          style: context.text.bodySmall!.copyWith(color: context.palette.muted),
        ),
      ),
    );
  }
}
