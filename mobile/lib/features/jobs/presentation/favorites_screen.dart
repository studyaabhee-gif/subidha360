import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui.dart';
import '../data/job_repository.dart';
import '../domain/provider_profile.dart';
import '../providers/job_providers.dart';
import 'provider_summary.dart';

/// Saves or forgets a provider.
class FavoriteButton extends ConsumerStatefulWidget {
  const FavoriteButton({required this.providerId, super.key});

  final String providerId;

  @override
  ConsumerState<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends ConsumerState<FavoriteButton> {
  var _busy = false;

  Future<void> _toggle(bool saved) async {
    setState(() => _busy = true);
    final jobs = ref.read(jobRepositoryProvider);
    try {
      if (saved) {
        await jobs.removeFavorite(widget.providerId);
      } else {
        await jobs.addFavorite(widget.providerId);
      }
      ref.invalidate(favoritesProvider);
    } catch (error) {
      if (mounted) context.showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(favoritesProvider).value ?? const <PublicProfile>[];
    final saved = rows.any((row) => row.id == widget.providerId);
    return IconButton(
      tooltip: saved ? tr('Remove from favourites') : tr('Add to favourites'),
      onPressed: _busy ? null : () => _toggle(saved),
      icon: Icon(
        saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: saved ? context.colors.secondary : context.palette.muted,
      ),
    );
  }
}

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Favourite providers'))),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: switch (favorites) {
            AsyncData(:final value) when value.isEmpty => EmptyState(
              icon: Icons.favorite_border_rounded,
              title: tr('No favourites yet'),
              message: tr(
                'Tap the heart on a provider you liked, and you can ask them '
                'directly next time.',
              ),
            ),
            AsyncData(:final value) => ListView.separated(
              padding: const EdgeInsets.all(AppTheme.gapLg),
              itemCount: value.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppTheme.gapSm),
              itemBuilder: (_, i) => _FavoriteRow(profile: value[i]),
            ),
            AsyncError() => EmptyState(
              icon: Icons.cloud_off_rounded,
              title: tr("Couldn't load your favourites"),
              message: tr('Check your connection and try again.'),
              action: OutlinedButton(
                onPressed: () => ref.invalidate(favoritesProvider),
                child: Text(tr('Try again')),
              ),
            ),
            _ => const Padding(
              padding: EdgeInsets.all(AppTheme.gapLg),
              child: SkeletonCards(count: 2),
            ),
          },
        ),
      ),
    );
  }
}

class _FavoriteRow extends StatelessWidget {
  const _FavoriteRow({required this.profile});

  final PublicProfile profile;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => showProviderSheet(context, profile.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const IconTile(icon: Icons.person_rounded),
              const SizedBox(width: AppTheme.gapMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall,
                    ),
                    RatingLabel(profile: profile),
                  ],
                ),
              ),
              FavoriteButton(providerId: profile.id),
            ],
          ),
          const SizedBox(height: AppTheme.gapSm),
          FilledButton(
            onPressed: () => context.push('/jobs/new?provider=${profile.id}'),
            child: Text(tr('Ask for a quote')),
          ),
        ],
      ),
    );
  }
}
