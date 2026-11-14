import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/layout_extensions.dart';
import '../../../core/extensions/money_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/photo.dart';
import '../../../core/widgets/schedule_picker.dart';
import '../../../core/widgets/site_scaffold.dart';
import '../../../core/widgets/ui.dart';
import '../../jobs/domain/categories.dart';
import '../data/catalog_repository.dart';
import '../domain/catalog.dart';
import 'catalog_widgets.dart';

class ServiceDetailPage extends ConsumerStatefulWidget {
  const ServiceDetailPage({required this.serviceId, super.key});

  final String serviceId;

  @override
  ConsumerState<ServiceDetailPage> createState() => _ServiceDetailPageState();
}

class _ServiceDetailPageState extends ConsumerState<ServiceDetailPage> {
  String? _date;
  String? _slot;

  void _book(CatalogService service) {
    context.push(
      Uri(
        path: '/jobs/new',
        queryParameters: {
          'service': service.id,
          'date': ?_date,
          'slot': ?_slot,
        },
      ).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalog = ref.watch(catalogProvider).value;
    final service = catalog?.serviceById(widget.serviceId);
    if (catalog == null) {
      return const SiteScaffold(
        children: [
          SizedBox(height: AppTheme.gapXl),
          PageWidth(child: SkeletonCards()),
        ],
      );
    }
    if (service == null) {
      return SiteScaffold(
        children: [
          EmptyState(
            icon: Icons.search_off_rounded,
            title: tr('Service not found'),
            message: tr('It may have moved. Browse all our services instead.'),
            action: FilledButton(
              onPressed: () => context.go('/services'),
              child: Text(tr('See all services')),
            ),
          ),
        ],
      );
    }

    final details = _Details(service: service);
    final booking = _BookingCard(
      service: service,
      date: _date,
      slot: _slot,
      onSchedule: (date, slot) => setState(() {
        _date = date;
        _slot = slot;
      }),
      onBook: () => _book(service),
    );
    final related = catalog
        .where((category) => category.id == service.categoryId)
        .expand((category) => category.services)
        .where((other) => other.id != service.id)
        .take(3)
        .toList();

    return SiteScaffold(
      children: [
        _Header(service: service),
        const SizedBox(height: AppTheme.gapXl),
        PageWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (context.isWide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: details),
                    const SizedBox(width: AppTheme.gapXxl),
                    Expanded(flex: 4, child: booking),
                  ],
                )
              else ...[
                booking,
                const SizedBox(height: AppTheme.gapXl),
                details,
              ],
              if (related.isNotEmpty) ...[
                const SizedBox(height: AppTheme.gapXxl + 8),
                SectionTitle(tr('Related services')),
                CardGrid(
                  minCardWidth: 340,
                  children: [
                    for (final item in related)
                      CompactServiceCard(service: item),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.service});

  final CatalogService service;

  @override
  Widget build(BuildContext context) {
    final category = categoryOf(service.categoryId);
    return PhotoBanner(
      photo: category.banner,
      minHeight: 300,
      child: Padding(
        padding: PhotoBanner.insets(context),
        child: PageWidth(
          child: PhotoPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextButton.icon(
                  style: TextButton.styleFrom(padding: EdgeInsets.zero),
                  onPressed: () => context.go('/services/${category.slug}'),
                  icon: Icon(category.icon, size: 18),
                  label: Text(category.name),
                ),
                Text(service.displayName, style: context.text.headlineLarge),
                const SizedBox(height: AppTheme.gapSm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Text(
                    service.displaySummary,
                    style: context.text.bodyLarge!.copyWith(
                      color: context.palette.muted,
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.gapMd),
                Wrap(
                  spacing: AppTheme.gapSm,
                  runSpacing: AppTheme.gapSm,
                  children: [
                    Pill(
                      label: tr('30-day guarantee'),
                      tone: Tone.success,
                      icon: Icons.verified_user_outlined,
                    ),
                    Pill(
                      label: tr('Payment on hold'),
                      tone: Tone.warning,
                      icon: Icons.lock_outline_rounded,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.service});

  final CatalogService service;

  @override
  Widget build(BuildContext context) {
    final muted = context.text.bodyMedium!.copyWith(
      color: context.palette.muted,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(tr('Is this your problem?')),
        Wrap(
          spacing: AppTheme.gapSm,
          runSpacing: AppTheme.gapSm,
          children: [
            for (final symptom in service.symptoms)
              Pill(label: tr(symptom), tone: Tone.neutral),
          ],
        ),
        const SizedBox(height: AppTheme.gapXl),
        SectionTitle(tr('What the work usually covers')),
        for (final item in service.includes)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.gapSm),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: context.colors.primary,
                ),
                const SizedBox(width: AppTheme.gapSm),
                Expanded(child: Text(tr(item), style: context.text.bodyMedium)),
              ],
            ),
          ),
        const SizedBox(height: AppTheme.gapLg),
        SectionTitle(tr('How pricing works')),
        Text(
          tr(
            'You choose the price by choosing a bid. Each bid says whether parts '
            'are included, so you can compare fairly. The guide price is only '
            'there to help you judge what is reasonable.',
          ),
          style: muted,
        ),
      ],
    );
  }
}

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.service,
    required this.date,
    required this.slot,
    required this.onSchedule,
    required this.onBook,
  });

  final CatalogService service;
  final String? date;
  final String? slot;
  final void Function(String? date, String? slot) onSchedule;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppTheme.gapLg + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('Guide price'),
            style: context.text.labelMedium!.copyWith(
              color: context.palette.muted,
            ),
          ),
          Text(
            tr('{0} to {1}', [
              service.guideFromPaisa.asRupeesShort,
              service.guideToPaisa.asRupeesShort,
            ]),
            style: context.text.headlineSmall,
          ),
          const SizedBox(height: AppTheme.gapLg),
          Text(tr('When do you need it?'), style: context.text.titleSmall),
          const SizedBox(height: AppTheme.gapSm),
          SchedulePicker(date: date, slot: slot, onChanged: onSchedule),
          const SizedBox(height: AppTheme.gapLg),
          FilledButton(onPressed: onBook, child: Text(tr('Get bids'))),
          const SizedBox(height: AppTheme.gapSm),
          Text(
            tr("It's free to ask. You only pay if you accept a bid."),
            textAlign: TextAlign.center,
            style: context.text.bodySmall!.copyWith(
              color: context.palette.muted,
            ),
          ),
        ],
      ),
    );
  }
}
