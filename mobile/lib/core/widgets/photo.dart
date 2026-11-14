import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../extensions/context_extensions.dart';
import '../extensions/layout_extensions.dart';
import '../theme/app_theme.dart';

/// Bundled photographs. Credits are in features/info/domain/photo_credits.dart.
abstract final class Photos {
  static const _base = 'assets/photos';
  static const hero = '$_base/hero_patan.jpg';

  /// Illustrations of Subidha360 providers in uniform, made for this site.
  /// They show the service, and must never stand for a named provider.
  static const homeVisit = '$_base/hero_home.jpg';
  static const team = '$_base/band_team.jpg';
  static const providerPhone = '$_base/auth_provider.jpg';
  static const providerTools = '$_base/provider_tools.jpg';
  static const himalaya = '$_base/band_himalaya.jpg';
  static const kathmandu = '$_base/city_kathmandu.jpg';
  static const lalitpur = '$_base/city_lalitpur.jpg';
  static const bhaktapur = '$_base/city_bhaktapur.jpg';
  static const pokhara = '$_base/city_pokhara.jpg';
  static const plumbing = '$_base/cat_plumbing.jpg';
  static const electrical = '$_base/cat_electrical.jpg';
  static const cleaning = '$_base/cat_cleaning.jpg';
  static const carpentry = '$_base/cat_carpentry.jpg';
  static const painting = '$_base/cat_painting.jpg';
  static const appliances = '$_base/cat_appliances.jpg';
  static const computer = '$_base/cat_computer.jpg';
  static const pest = '$_base/cat_pest.jpg';
}

/// A photo that fades in over a tinted placeholder, so slow connections show a
/// calm block of colour rather than a pop-in.
class AppPhoto extends StatelessWidget {
  const AppPhoto(
    this.asset, {
    this.alt,
    this.alignment = Alignment.center,
    this.cacheWidth,
    super.key,
  });

  final String asset;

  /// Read by screen readers. Leave null for purely decorative photos.
  final String? alt;
  final Alignment alignment;

  /// Decodes small thumbnails at a small size to save memory.
  final int? cacheWidth;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      asset,
      fit: BoxFit.cover,
      alignment: alignment,
      width: double.infinity,
      height: double.infinity,
      cacheWidth: cacheWidth,
      semanticLabel: alt,
      excludeFromSemantics: alt == null,
      frameBuilder: (context, child, frame, wasSynchronous) {
        if (wasSynchronous) return child;
        return AnimatedOpacity(
          opacity: frame == null ? 0 : 1,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOut,
          child: child,
        );
      },
      errorBuilder: (context, _, _) => const SizedBox.expand(),
    );
    return ColoredBox(color: context.palette.skeleton, child: image);
  }
}

/// Lifts a card slightly under a mouse. Touch screens simply never trigger it.
class HoverLift extends StatefulWidget {
  const HoverLift({required this.child, this.radius, super.key});

  final Widget child;
  final double? radius;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  var _hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _hovering ? -4 : 0, 0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(
            widget.radius ?? AppTheme.radiusLg,
          ),
          boxShadow: [
            if (_hovering)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
          ],
        ),
        child: widget.child,
      ),
    );
  }
}

/// A photo at full colour with its title on a white strip.
class PhotoTile extends StatelessWidget {
  const PhotoTile({
    required this.photo,
    required this.title,
    this.subtitle,
    this.onTap,
    this.aspectRatio = 4 / 3,
    this.alignment = Alignment.center,
    this.icon,
    this.oneLineTitle = false,
    super.key,
  });

  final String photo;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final double aspectRatio;
  final Alignment alignment;
  final IconData? icon;

  /// Shrinks a long title to one line, so tiles in a grid keep equal photos.
  final bool oneLineTitle;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTheme.radiusLg);
    return HoverLift(
      child: Semantics(
        button: onTap != null,
        label: subtitle == null ? title : '$title, $subtitle',
        excludeSemantics: true,
        child: ClipRRect(
          borderRadius: radius,
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // The label sits below the photo, not over it, so no sliver of
                // photo can show around the rounded corners.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: AppPhoto(
                        photo,
                        alignment: alignment,
                        cacheWidth: 800,
                      ),
                    ),
                    ColoredBox(
                      color: context.colors.surface,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.gapMd,
                          vertical: AppTheme.gapSm,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (icon != null) ...[
                                  Icon(
                                    icon,
                                    size: 18,
                                    color: context.colors.primary,
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Flexible(
                                  child: oneLineTitle
                                      ? FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            title,
                                            maxLines: 1,
                                            style: context.text.titleSmall,
                                          ),
                                        )
                                      : Text(
                                          title,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: context.text.titleSmall,
                                        ),
                                ),
                              ],
                            ),
                            if (subtitle != null)
                              Text(
                                subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: context.text.bodySmall!.copyWith(
                                  color: context.palette.muted,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (onTap != null)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(onTap: onTap),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A rounded photo that identifies a job or service at a glance.
class PhotoThumb extends StatelessWidget {
  const PhotoThumb(
    this.photo, {
    this.size = 56,
    this.alignment = Alignment.center,
    super.key,
  });

  final String photo;
  final double size;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.26),
      child: SizedBox.square(
        dimension: size,
        child: AppPhoto(photo, alignment: alignment, cacheWidth: 400),
      ),
    );
  }
}

/// A full-width page header: a photo at full colour with content on top. Put
/// any text inside a [PhotoPanel] so it stays readable on every photo.
class PhotoBanner extends StatelessWidget {
  const PhotoBanner({
    required this.photo,
    required this.child,
    this.alignment = Alignment.center,
    this.minHeight = 260,
    super.key,
  });

  final String photo;
  final Widget child;
  final Alignment alignment;
  final double minHeight;

  /// Leaves the photo showing above the panel on phones.
  static EdgeInsets insets(BuildContext context) => context.isWide
      ? const EdgeInsets.symmetric(vertical: 56)
      : const EdgeInsets.only(top: 132, bottom: AppTheme.gapLg);

  @override
  Widget build(BuildContext context) {
    // Grows with the window, so a very wide screen never crops the photo to
    // a thin strip that cuts off heads.
    final height = math.max(
      minHeight,
      math.min(context.screenWidth / 3.4, 600.0),
    );
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: height),
      child: Stack(
        children: [
          Positioned.fill(child: AppPhoto(photo, alignment: alignment)),
          child,
        ],
      ),
    );
  }
}

/// A bright white card for text that sits on a photo.
class PhotoPanel extends StatelessWidget {
  const PhotoPanel({
    required this.child,
    this.maxWidth = 620,
    this.alignment = Alignment.centerLeft,
    super.key,
  });

  final Widget child;
  final double maxWidth;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.14),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(
              context.isWide ? AppTheme.gapXxl : AppTheme.gapLg + 4,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
