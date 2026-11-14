import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../provider/data/provider_api.dart';
import '../../provider/domain/provider_models.dart';
import '../../provider/presentation/availability_screen.dart';
import '../../provider/presentation/gallery_screen.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/date_extensions.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui.dart';
import '../domain/provider_profile.dart';
import '../providers/job_providers.dart';
import 'favorites_screen.dart';

/// "New" rather than a low score, because no rating isn't a bad rating.
class RatingLabel extends StatelessWidget {
  const RatingLabel({required this.profile, super.key});

  final PublicProfile profile;

  @override
  Widget build(BuildContext context) {
    final muted = context.text.bodySmall!.copyWith(
      color: context.palette.muted,
    );
    if (!profile.hasRating) return Text(tr('New on Subidha360'), style: muted);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, size: 16, color: context.colors.secondary),
        const SizedBox(width: 2),
        Text(
          profile.rating.toStringAsFixed(1),
          style: context.text.labelMedium,
        ),
        const SizedBox(width: AppTheme.gapXs),
        Flexible(
          child: Text(
            tr('({0}) · {1} jobs', [
              profile.reviewCount,
              profile.jobsCompleted,
            ]),
            overflow: TextOverflow.ellipsis,
            style: muted,
          ),
        ),
      ],
    );
  }
}

class VerifiedBadge extends StatelessWidget {
  const VerifiedBadge({super.key});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tr('Identity checked by Subidha360'),
    child: Icon(
      Icons.verified_rounded,
      size: 18,
      color: context.colors.primary,
      semanticLabel: tr('Verified'),
    ),
  );
}

/// Opens a provider's profile and recent reviews.
void showProviderSheet(BuildContext context, String providerId) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => _ProviderSheet(providerId: providerId),
  );
}

class _ProviderSheet extends ConsumerWidget {
  const _ProviderSheet({required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(providerDetailProvider(providerId));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      builder: (context, controller) => switch (detail) {
        AsyncData(value: (final profile, final reviews)) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(
            AppTheme.gapXl,
            0,
            AppTheme.gapXl,
            AppTheme.gapXl,
          ),
          children: [
            Row(
              children: [
                const IconTile(icon: Icons.person_rounded, size: 54),
                const SizedBox(width: AppTheme.gapMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              profile.name,
                              style: context.text.titleLarge,
                            ),
                          ),
                          if (profile.verified) ...const [
                            SizedBox(width: AppTheme.gapXs),
                            VerifiedBadge(),
                          ],
                        ],
                      ),
                      RatingLabel(profile: profile),
                    ],
                  ),
                ),
                FavoriteButton(providerId: providerId),
              ],
            ),
            if (profile.yearsExperience > 0) ...[
              const SizedBox(height: AppTheme.gapMd),
              Text(tr('{0} years of experience', [profile.yearsExperience])),
            ],
            if (profile.bio.isNotEmpty) ...[
              const SizedBox(height: AppTheme.gapSm),
              Text(profile.bio, style: context.text.bodyMedium),
            ],
            const SizedBox(height: AppTheme.gapMd),
            Row(
              children: [
                Icon(
                  Icons.event_available_outlined,
                  size: 18,
                  color: context.palette.muted,
                ),
                const SizedBox(width: AppTheme.gapSm),
                Expanded(
                  child: Text(
                    availabilitySummary(
                      profile.availability == null
                          ? null
                          : Availability.fromJson(profile.availability!),
                    ),
                    style: context.text.bodySmall,
                  ),
                ),
              ],
            ),
            _PastWork(providerId: providerId),
            const SizedBox(height: AppTheme.gapXl),
            SectionTitle(tr('Reviews'), trailing: '${profile.reviewCount}'),
            if (reviews.isEmpty)
              Text(
                tr('No reviews yet.'),
                style: context.text.bodyMedium!.copyWith(
                  color: context.palette.muted,
                ),
              ),
            for (final review in reviews) _ReviewTile(review: review),
          ],
        ),
        AsyncError(:final error) => Padding(
          padding: const EdgeInsets.all(AppTheme.gapXl),
          child: Text(ApiException.from(error).message),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _ReviewTile extends StatelessWidget {
  const _ReviewTile({required this.review});

  final Review review;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.gapLg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < 5; i++)
                Icon(
                  i < review.rating
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  size: 16,
                  color: context.colors.secondary,
                ),
              const SizedBox(width: AppTheme.gapSm),
              Text(
                review.createdAt.timeAgo(),
                style: context.text.bodySmall!.copyWith(
                  color: context.palette.muted,
                ),
              ),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: AppTheme.gapXs),
            Text(review.comment, style: context.text.bodyMedium),
          ],
          if (review.tags.isNotEmpty) ...[
            const SizedBox(height: AppTheme.gapXs),
            Wrap(
              spacing: AppTheme.gapXs,
              runSpacing: AppTheme.gapXs,
              children: [
                for (final tag in review.tags)
                  Pill(label: tr(tag), tone: Tone.neutral),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Up to six photos of the provider's past work, when they have any.
class _PastWork extends ConsumerWidget {
  const _PastWork({required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photos = ref.watch(galleryProvider(providerId)).value ?? const [];
    if (photos.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: AppTheme.gapXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(tr('Past work'), trailing: '${photos.length}'),
          GalleryGrid(providerId: providerId, photos: photos.take(6).toList()),
        ],
      ),
    );
  }
}
