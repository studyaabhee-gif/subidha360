import 'package:flutter/material.dart';

import '../../core/l10n/tr.dart';
import '../extensions/context_extensions.dart';
import '../theme/app_theme.dart';

/// The app's mark: a home inside a "360" ring. The master artwork is
/// assets/brand/logo.svg; the app icons are made from it too.
class BrandMark extends StatelessWidget {
  const BrandMark({this.size = 56, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/brand/logo.png',
      width: size,
      height: size,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Subidha360',
    );
  }
}

class Wordmark extends StatelessWidget {
  const Wordmark({this.style, super.key});

  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ?? context.text.titleLarge!;
    return Text.rich(
      TextSpan(
        style: base.copyWith(fontWeight: FontWeight.w800),
        children: [
          TextSpan(text: tr('Subidha')),
          TextSpan(
            text: '360',
            style: TextStyle(color: context.colors.secondary),
          ),
        ],
      ),
    );
  }
}

/// A scrolling form body. Unlike a ListView this keeps every field built, which
/// matters because a Form cannot validate a field that is scrolled off screen.
class FormScroll extends StatelessWidget {
  const FormScroll({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.gapLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppTheme.gapLg),
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTheme.radiusLg);
    return Material(
      color: context.colors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: context.palette.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill({required this.label, required this.tone, this.icon, super.key});

  final String label;
  final Tone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.palette.tone(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: colors.foreground),
            const SizedBox(width: AppTheme.gapXs),
          ],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium!.copyWith(
                color: colors.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class IconTile extends StatelessWidget {
  const IconTile({
    required this.icon,
    this.tone = Tone.brand,
    this.size = 46,
    super.key,
  });

  final IconData icon;
  final Tone tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = context.palette.tone(tone);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: colors.foreground, size: size * 0.5),
    );
  }
}

class InfoBanner extends StatelessWidget {
  const InfoBanner({
    required this.title,
    required this.message,
    this.tone = Tone.info,
    this.icon = Icons.info_outline_rounded,
    super.key,
  });

  final String title;
  final String message;
  final Tone tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.palette.tone(tone);
    return Container(
      padding: const EdgeInsets.all(AppTheme.gapLg),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: colors.foreground),
          const SizedBox(width: AppTheme.gapMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.text.titleSmall!.copyWith(
                    color: colors.foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: context.text.bodySmall!.copyWith(
                    color: colors.foreground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {this.trailing, super.key});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.gapMd),
      child: Row(
        children: [
          Expanded(child: Text(title, style: context.text.titleMedium)),
          if (trailing != null)
            Text(
              trailing!,
              style: context.text.labelMedium!.copyWith(
                color: context.palette.muted,
              ),
            ),
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppTheme.gapXl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconTile(icon: icon, tone: Tone.neutral, size: 64),
          const SizedBox(height: AppTheme.gapLg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.text.titleMedium,
          ),
          const SizedBox(height: AppTheme.gapXs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium!.copyWith(
              color: context.palette.muted,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: AppTheme.gapLg),
            action!,
          ],
        ],
      ),
    );
  }
}

class SkeletonBox extends StatelessWidget {
  const SkeletonBox({this.width, this.height = 14, super.key});

  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: context.palette.skeleton,
        borderRadius: BorderRadius.circular(AppTheme.radiusSm),
      ),
    );
  }
}

/// Placeholder cards, so loading keeps the shape of the page it will become.
class SkeletonCards extends StatelessWidget {
  const SkeletonCards({this.count = 3, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < count; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.gapMd),
            child: AppCard(
              child: Row(
                children: [
                  const SkeletonBox(width: 46, height: 46),
                  const SizedBox(width: AppTheme.gapMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        SkeletonBox(),
                        SizedBox(height: AppTheme.gapSm),
                        SkeletonBox(width: 120, height: 11),
                      ],
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

/// A fixed area for a page's main action, always within thumb reach.
class BottomActionBar extends StatelessWidget {
  const BottomActionBar({required this.children, super.key});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(top: BorderSide(color: context.palette.line)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.gapLg,
            AppTheme.gapMd,
            AppTheme.gapLg,
            AppTheme.gapMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < children.length; i++) ...[
                if (i > 0) const SizedBox(height: AppTheme.gapSm),
                children[i],
              ],
            ],
          ),
        ),
      ),
    );
  }
}
