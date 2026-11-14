import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/photo.dart';
import '../../../core/widgets/site_scaffold.dart';
import '../../../core/widgets/ui.dart';
import '../../jobs/domain/categories.dart';
import '../data/catalog_repository.dart';
import '../domain/catalog.dart';
import 'catalog_widgets.dart';

/// Every service, narrowed by category or by a search in the person's own words.
class ServicesPage extends ConsumerStatefulWidget {
  const ServicesPage({this.slug, this.query, super.key});

  final String? slug;
  final String? query;

  @override
  ConsumerState<ServicesPage> createState() => _ServicesPageState();
}

class _ServicesPageState extends ConsumerState<ServicesPage> {
  late final _search = TextEditingController(text: widget.query ?? '');

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<CatalogService> _visible(List<CatalogCategory> catalog) {
    final query = _search.text.trim();
    if (query.isNotEmpty) return catalog.search(query);
    final category = widget.slug == null
        ? null
        : catalog.categoryBySlug(widget.slug!);
    return category?.services ?? catalog.allServices;
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider);
    final rows = catalog.value ?? const <CatalogCategory>[];
    final category = widget.slug == null
        ? null
        : rows.categoryBySlug(widget.slug!);
    final photo = category == null
        ? Photos.hero
        : categoryOf(category.id).banner;

    return SiteScaffold(
      children: [
        PhotoBanner(
          photo: photo,
          minHeight: 280,
          alignment: const Alignment(0, 0.2),
          child: Padding(
            padding: PhotoBanner.insets(context),
            child: PageWidth(
              child: PhotoPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      category?.displayName ?? tr('All services'),
                      style: context.text.headlineLarge,
                    ),
                    const SizedBox(height: AppTheme.gapXs),
                    Text(
                      category?.displayTagline ??
                          tr('Search by your problem, or browse below.'),
                      style: context.text.bodyLarge!.copyWith(
                        color: context.palette.muted,
                      ),
                    ),
                    const SizedBox(height: AppTheme.gapLg),
                    TextField(
                      controller: _search,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: tr('Try "tap dripping" or "no hot water"'),
                        prefixIcon: Icon(Icons.search_rounded),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.gapLg),
        PageWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _CategoryChip(
                      label: tr('All'),
                      selected: widget.slug == null,
                      onTap: () => context.go('/services'),
                    ),
                    for (final item in serviceCategories)
                      _CategoryChip(
                        label: item.name,
                        selected: widget.slug == item.slug,
                        onTap: () => context.go('/services/${item.slug}'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppTheme.gapLg),
              ...switch (catalog) {
                AsyncData() => _results(_visible(rows)),
                AsyncError(:final error) => [
                  EmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: tr("Couldn't load services"),
                    message: ApiException.from(error).message,
                    action: OutlinedButton(
                      onPressed: () => ref.invalidate(catalogProvider),
                      child: Text(tr('Try again')),
                    ),
                  ),
                ],
                _ => [const SkeletonCards()],
              },
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _results(List<CatalogService> services) {
    if (services.isEmpty) {
      return [
        EmptyState(
          icon: Icons.search_off_rounded,
          title: tr('No exact match'),
          message: tr(
            'Post it anyway. Describe the problem and providers will bid.',
          ),
          action: FilledButton(
            onPressed: () => context.push('/jobs/new'),
            child: Text(tr('Describe your job')),
          ),
        ),
      ];
    }
    return [
      CardGrid(
        minCardWidth: 360,
        children: [
          for (final service in services) CompactServiceCard(service: service),
        ],
      ),
    ];
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppTheme.gapSm),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        selectedColor: context.colors.primaryContainer,
        backgroundColor: context.colors.surface,
        side: BorderSide(color: context.palette.line),
        onSelected: (_) => onTap(),
      ),
    );
  }
}
