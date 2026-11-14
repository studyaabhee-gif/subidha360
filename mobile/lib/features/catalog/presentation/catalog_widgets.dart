import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/money_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/photo.dart';
import '../../../core/widgets/ui.dart';
import '../../jobs/domain/categories.dart';
import '../domain/catalog.dart';

/// Lays out equal-width cards that wrap to fit the available space.
class CardGrid extends StatelessWidget {
  const CardGrid({
    required this.children,
    required this.minCardWidth,
    this.gap = AppTheme.gapMd,
    super.key,
  });

  final List<Widget> children;
  final double minCardWidth;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = ((constraints.maxWidth + gap) / (minCardWidth + gap))
            .floor()
            .clamp(1, 6);
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final child in children) SizedBox(width: width, child: child),
          ],
        );
      },
    );
  }
}

/// A service with its category photo across the top.
class ServiceCard extends StatelessWidget {
  const ServiceCard({required this.service, super.key});

  final CatalogService service;

  @override
  Widget build(BuildContext context) {
    final category = categoryOf(service.categoryId);
    return HoverLift(
      child: AppCard(
        padding: EdgeInsets.zero,
        onTap: () => context.push('/service/${service.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: AppPhoto(category.photo, cacheWidth: 640),
            ),
            Padding(
              padding: const EdgeInsets.all(AppTheme.gapMd + 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name.toUpperCase(),
                    style: context.text.labelSmall!.copyWith(
                      color: context.colors.primary,
                      letterSpacing: appLanguage == AppLanguage.english
                          ? 0.6
                          : 0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    service.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleMedium,
                  ),
                  const SizedBox(height: AppTheme.gapXs),
                  SizedBox(
                    height: 38 * MediaQuery.textScalerOf(context).scale(1),
                    child: Text(
                      service.displaySummary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall!.copyWith(
                        color: context.palette.muted,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.gapXs),
                  GuidePrice(service: service),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A service in a list, with a small photo so a page of similar services
/// doesn't repeat one large image.
class CompactServiceCard extends StatelessWidget {
  const CompactServiceCard({required this.service, super.key});

  final CatalogService service;

  @override
  Widget build(BuildContext context) {
    final category = categoryOf(service.categoryId);
    return HoverLift(
      child: AppCard(
        padding: const EdgeInsets.all(AppTheme.gapMd),
        onTap: () => context.push('/service/${service.id}'),
        child: Row(
          children: [
            PhotoThumb(
              category.photo,
              size: 84,
              alignment: _thumbCrop(service.id),
            ),
            const SizedBox(width: AppTheme.gapMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall!.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    service.displaySummary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall!.copyWith(
                      color: context.palette.muted,
                    ),
                  ),
                  const SizedBox(height: AppTheme.gapXs),
                  GuidePrice(service: service),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GuidePrice extends StatelessWidget {
  const GuidePrice({required this.service, super.key});

  final CatalogService service;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        style: context.text.bodySmall!.copyWith(color: context.palette.muted),
        children: [
          TextSpan(text: tr('Usually ')),
          TextSpan(
            text: tr('{0} to {1}', [
              service.guideFromPaisa.asRupeesShort,
              service.guideToPaisa.asRupeesShort,
            ]),
            style: context.text.labelMedium,
          ),
        ],
      ),
    );
  }
}

class CategoryTile extends StatelessWidget {
  const CategoryTile({required this.category, super.key});

  final ServiceCategory category;

  @override
  Widget build(BuildContext context) {
    return PhotoTile(
      photo: category.photo,
      title: category.name,
      icon: category.icon,
      onTap: () => context.push('/services/${category.slug}'),
    );
  }
}

/// Each category has one photo, so services in a list show different parts of
/// it. Summing the id keeps a service's crop the same on every visit.
Alignment _thumbCrop(String serviceId) {
  const crops = [Alignment.centerLeft, Alignment.center, Alignment.centerRight];
  return crops[serviceId.codeUnits.fold(0, (sum, unit) => sum + unit) % 3];
}
