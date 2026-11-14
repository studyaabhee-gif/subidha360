import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/layout_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/nepal_graphics.dart';
import '../../../core/widgets/photo.dart';
import '../../../core/widgets/site_scaffold.dart';
import '../../../core/widgets/ui.dart';
import '../../jobs/domain/categories.dart';
import '../data/catalog_repository.dart';
import '../domain/catalog.dart';
import 'catalog_widgets.dart';

class LandingPage extends ConsumerWidget {
  const LandingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(catalogProvider).value ?? const [];
    return SiteScaffold(
      flushFooter: true,
      children: [
        _Hero(catalog: catalog),
        const DhakaBand(),
        _Section(
          eyebrow: tr('Services'),
          title: tr('What do you need help with?'),
          child: CardGrid(
            // Wide enough for four across, so eight categories fill two rows.
            minCardWidth: context.isWide ? 240 : 150,
            children: [
              for (final category in serviceCategories)
                CategoryTile(category: category),
            ],
          ),
        ),
        const _HowItWorks(),
        if (catalog.isNotEmpty)
          _Section(
            eyebrow: tr('Popular'),
            title: tr('Jobs people often need done'),
            action: TextButton(
              onPressed: () => context.push('/services'),
              child: Text(tr('See all')),
            ),
            child: CardGrid(
              minCardWidth: 260,
              children: [
                for (final service in catalog.popularVariety.take(4))
                  ServiceCard(service: service),
              ],
            ),
          ),
        const _SafePayment(),
        const _Places(),
        const _ProviderBand(),
        const _Faq(),
        const SizedBox(height: 64),
        const _MountainCta(),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.eyebrow,
    this.action,
  });

  final String title;
  final Widget child;
  final String? eyebrow;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: context.isWide ? 72 : AppTheme.gapXxl + 8),
      child: PageWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (eyebrow != null) _Eyebrow(eyebrow!),
            Row(
              children: [
                Expanded(
                  child: Text(title, style: context.text.headlineMedium),
                ),
                ?action,
              ],
            ),
            const SizedBox(height: AppTheme.gapLg + 4),
            child,
          ],
        ),
      ),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.gapXs),
      child: Text(
        text.toUpperCase(),
        style: context.text.labelMedium!.copyWith(
          color: context.colors.secondary,
          letterSpacing: appLanguage == AppLanguage.english ? 1.2 : 0,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.catalog});

  final List<CatalogCategory> catalog;

  @override
  Widget build(BuildContext context) {
    final wide = context.isWide;
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Pill(label: tr('Built for homes in Nepal'), tone: Tone.warning),
        const SizedBox(height: AppTheme.gapLg + 4),
        Text(
          tr('Fair quotes from local experts.'),
          style:
              (wide ? context.text.displaySmall : context.text.headlineLarge)!
                  .copyWith(fontSize: wide ? 50 : null, height: 1.08),
        ),
        const SizedBox(height: AppTheme.gapMd + 2),
        Text(
          tr(
            'Tell us the problem. Nearby providers compete for the job, and your '
            'payment stays on hold until the work is done.',
          ),
          style: context.text.bodyLarge!.copyWith(
            color: context.palette.muted,
            fontSize: wide ? 18 : null,
          ),
        ),
        const SizedBox(height: AppTheme.gapXl),
        _HeroSearch(catalog: catalog),
      ],
    );

    final photoAlt = tr(
      'A Subidha360 provider welcomed at a carved door in Lalitpur',
    );
    if (wide) {
      // On computers the photo has its own frame, so no card covers the
      // people in it, however wide the window is.
      return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [context.colors.primaryContainer, context.palette.page],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 64),
          child: PageWidth(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(flex: 11, child: copy),
                const SizedBox(width: 56),
                Expanded(
                  flex: 10,
                  child: Padding(
                    // Room for the bids card to hang off the frame's corner.
                    padding: const EdgeInsets.only(bottom: 190),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: AspectRatio(
                            aspectRatio: 1.4,
                            child: AppPhoto(
                              Photos.homeVisit,
                              alt: photoAlt,
                              // Keeps both the customer and the provider.
                              alignment: const Alignment(-0.1, -0.2),
                            ),
                          ),
                        ),
                        const Positioned(
                          left: -40,
                          bottom: -190,
                          width: 330,
                          child: _BidPreview(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 520),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            // On phones the photo is its own block, so the panel below
            // doesn't hide the people in it.
            height: 300,
            child: AppPhoto(
              Photos.homeVisit,
              alt: photoAlt,
              alignment: const Alignment(0.2, -0.3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 244, bottom: AppTheme.gapLg),
            child: PageWidth(child: PhotoPanel(child: copy)),
          ),
        ],
      ),
    );
  }
}

/// Search that takes the person's own words, not a category name.
class _HeroSearch extends StatefulWidget {
  const _HeroSearch({required this.catalog});

  final List<CatalogCategory> catalog;

  @override
  State<_HeroSearch> createState() => _HeroSearchState();
}

class _HeroSearchState extends State<_HeroSearch> {
  static const _examples = [
    'Leaking tap',
    'Power keeps tripping',
    'Deep clean',
    'AC not cooling',
    'Slow laptop',
  ];

  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _search(String text) {
    final query = text.trim();
    if (query.isEmpty) return;
    context.push(
      Uri(path: '/services', queryParameters: {'q': query}).toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final matches = widget.catalog.search(_query.text).take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Material(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          child: TextField(
            controller: _query,
            textInputAction: TextInputAction.search,
            style: context.text.bodyLarge,
            decoration: InputDecoration(
              hintText: tr('What needs fixing?'),
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: Padding(
                padding: const EdgeInsets.all(6),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(88, 44),
                  ),
                  onPressed: () => _search(_query.text),
                  child: Text(tr('Search')),
                ),
              ),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: _search,
          ),
        ),
        if (matches.isNotEmpty) ...[
          const SizedBox(height: AppTheme.gapSm),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                for (final service in matches)
                  ListTile(
                    leading: PhotoThumb(
                      categoryOf(service.categoryId).photo,
                      size: 40,
                    ),
                    title: Text(
                      service.displayName,
                      style: context.text.titleSmall,
                    ),
                    onTap: () => context.push('/service/${service.id}'),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppTheme.gapMd),
        Wrap(
          spacing: AppTheme.gapSm,
          runSpacing: AppTheme.gapSm,
          children: [
            for (final example in _examples)
              Material(
                color: context.colors.primaryContainer,
                borderRadius: BorderRadius.circular(999),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _search(example),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.gapMd + 2,
                      vertical: AppTheme.gapSm,
                    ),
                    child: Text(
                      tr(example),
                      style: context.text.labelMedium!.copyWith(
                        color: context.colors.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Shows what comparing bids looks like. Labelled as an example because these
/// are not real providers.
class _BidPreview extends StatelessWidget {
  const _BidPreview();

  @override
  Widget build(BuildContext context) {
    Widget row(String who, String price, String detail, bool parts) => Padding(
      padding: const EdgeInsets.only(top: AppTheme.gapSm),
      child: Container(
        padding: const EdgeInsets.all(AppTheme.gapMd),
        decoration: BoxDecoration(
          border: Border.all(color: context.palette.line),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(price, style: context.text.titleMedium),
                  Text(
                    '$who · $detail',
                    style: context.text.bodySmall!.copyWith(
                      color: context.palette.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (parts) Pill(label: tr('Parts included'), tone: Tone.success),
          ],
        ),
      ),
    );

    return ExcludeSemantics(
      child: Material(
        elevation: 10,
        shadowColor: Colors.black38,
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.gapLg + 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const PhotoThumb(Photos.plumbing, size: 44),
                  const SizedBox(width: AppTheme.gapMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('Leaking kitchen tap'),
                          style: context.text.titleMedium,
                        ),
                        Text(
                          tr('Three bids to compare'),
                          style: context.text.bodySmall!.copyWith(
                            color: context.palette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Pill(label: tr('Example'), tone: Tone.neutral),
                ],
              ),
              const SizedBox(height: AppTheme.gapXs),
              row(tr('Provider A'), tr('Rs 650'), tr('can come today'), true),
              row(
                tr('Provider B'),
                tr('Rs 800'),
                tr('can come tomorrow'),
                true,
              ),
              row(tr('Provider C'), tr('Rs 500'), tr('parts extra'), false),
            ],
          ),
        ),
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  static const _steps = [
    (
      Icons.edit_note_rounded,
      'Describe the job',
      'Pick a service, choose a time, and tell us where.',
    ),
    (
      Icons.sell_rounded,
      'Compare bids',
      'Nearby providers send prices. See ratings and what is included.',
    ),
    (
      Icons.lock_rounded,
      'Pay safely',
      'Accept one bid. Your payment stays on hold, not with the provider.',
    ),
    (
      Icons.task_alt_rounded,
      'Confirm and rate',
      'Once you confirm the work is done, the payment is released.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = context.isWide;
    final steps = [
      for (var i = 0; i < _steps.length; i++)
        _Step(
          number: i + 1,
          icon: _steps[i].$1,
          title: tr(_steps[i].$2),
          body: tr(_steps[i].$3),
          last: i == _steps.length - 1,
          horizontal: wide,
        ),
    ];
    return Container(
      margin: EdgeInsets.only(top: wide ? 72 : AppTheme.gapXxl + 8),
      padding: EdgeInsets.symmetric(vertical: wide ? 64 : AppTheme.gapXxl + 8),
      color: context.colors.surface,
      child: PageWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Eyebrow(tr('How it works')),
            Text(tr('Four simple steps'), style: context.text.headlineMedium),
            const SizedBox(height: AppTheme.gapXl),
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [for (final step in steps) Expanded(child: step)],
              )
            else
              ...steps,
          ],
        ),
      ),
    );
  }
}

/// One numbered stop on the line that joins the steps together.
class _Step extends StatelessWidget {
  const _Step({
    required this.number,
    required this.icon,
    required this.title,
    required this.body,
    required this.last,
    required this.horizontal,
  });

  final int number;
  final IconData icon;
  final String title;
  final String body;
  final bool last;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final badge = Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(color: colors.primary, shape: BoxShape.circle),
      child: Icon(icon, color: colors.onPrimary, size: 24),
    );
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$number. $title', style: context.text.titleMedium),
        const SizedBox(height: AppTheme.gapXs),
        Text(
          body,
          style: context.text.bodySmall!.copyWith(color: context.palette.muted),
        ),
      ],
    );
    if (horizontal) {
      return Padding(
        padding: const EdgeInsets.only(right: AppTheme.gapLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                badge,
                if (!last)
                  Expanded(
                    child: Container(
                      height: 2,
                      margin: const EdgeInsets.only(left: AppTheme.gapSm),
                      color: context.palette.line,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppTheme.gapMd),
            text,
          ],
        ),
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              badge,
              if (!last)
                Expanded(
                  child: Container(width: 2, color: context.palette.line),
                ),
            ],
          ),
          const SizedBox(width: AppTheme.gapMd),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.gapLg),
              child: text,
            ),
          ),
        ],
      ),
    );
  }
}

/// A photo beside a diagram of how the money moves.
class _SafePayment extends StatelessWidget {
  const _SafePayment();

  @override
  Widget build(BuildContext context) {
    final wide = context.isWide;
    final photo = ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: AppPhoto(
          Photos.painting,
          alt: tr('A Subidha360 painter rolling paint onto a living room wall'),
        ),
      ),
    );
    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Eyebrow(tr('Peace of mind')),
        Text(
          tr('Pay when the work is done, not before'),
          style: context.text.headlineMedium,
        ),
        const SizedBox(height: AppTheme.gapSm),
        Text(
          tr(
            'Your money never goes straight to the provider. We hold it safely '
            'and release it once you confirm the job is finished.',
          ),
          style: context.text.bodyMedium!.copyWith(
            color: context.palette.muted,
          ),
        ),
        const SizedBox(height: AppTheme.gapLg),
        const _MoneyFlow(),
        const SizedBox(height: AppTheme.gapLg),
        Wrap(
          spacing: AppTheme.gapSm,
          runSpacing: AppTheme.gapSm,
          children: [
            Pill(
              label: tr('Every bid states parts'),
              tone: Tone.brand,
              icon: Icons.inventory_2_outlined,
            ),
            GestureDetector(
              onTap: () => context.push('/guarantee'),
              child: Pill(
                label: tr('30-day guarantee'),
                tone: Tone.success,
                icon: Icons.verified_user_outlined,
              ),
            ),
          ],
        ),
      ],
    );
    return Padding(
      padding: EdgeInsets.only(top: wide ? 72 : AppTheme.gapXxl + 8),
      child: PageWidth(
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: photo),
                  const SizedBox(width: 56),
                  Expanded(child: copy),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  photo,
                  const SizedBox(height: AppTheme.gapLg),
                  copy,
                ],
              ),
      ),
    );
  }
}

class _MoneyFlow extends StatelessWidget {
  const _MoneyFlow();

  @override
  Widget build(BuildContext context) {
    Widget stage(IconData icon, String label, Tone tone) => Expanded(
      child: Column(
        children: [
          IconTile(icon: icon, tone: tone, size: 52),
          const SizedBox(height: AppTheme.gapXs),
          Text(
            label,
            textAlign: TextAlign.center,
            style: context.text.labelMedium,
          ),
        ],
      ),
    );
    final arrow = Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.gapLg),
      child: Icon(
        Icons.arrow_forward_rounded,
        color: context.palette.muted,
        size: 20,
      ),
    );
    return Semantics(
      label: tr('You pay, the money is held safely, then the provider is paid'),
      child: ExcludeSemantics(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            stage(
              Icons.account_balance_wallet_rounded,
              tr('You pay'),
              Tone.neutral,
            ),
            arrow,
            stage(Icons.lock_rounded, tr('Held safely'), Tone.warning),
            arrow,
            stage(Icons.handshake_rounded, tr('Provider paid'), Tone.success),
          ],
        ),
      ),
    );
  }
}

class _Places extends StatelessWidget {
  const _Places();

  @override
  Widget build(BuildContext context) {
    final places = [
      (Photos.kathmandu, tr('Kathmandu'), tr('Boudhanath')),
      (Photos.lalitpur, tr('Lalitpur'), tr('Patan Durbar Square')),
      (Photos.bhaktapur, tr('Bhaktapur'), tr('Nyatapola Temple')),
      (Photos.pokhara, tr('Pokhara'), tr('Phewa Lake')),
    ];
    return _Section(
      eyebrow: tr('Close to home'),
      title: tr('Help from your own neighbourhood'),
      child: CardGrid(
        minCardWidth: context.isWide ? 250 : 150,
        children: [
          for (final (photo, name, landmark) in places)
            PhotoTile(
              photo: photo,
              title: name,
              subtitle: landmark,
              aspectRatio: 0.82,
              onTap: () => context.push('/services'),
            ),
        ],
      ),
    );
  }
}

class _ProviderBand extends StatelessWidget {
  const _ProviderBand();

  @override
  Widget build(BuildContext context) {
    final wide = context.isWide;
    return Padding(
      padding: EdgeInsets.only(top: wide ? 72 : AppTheme.gapXxl + 8),
      child: PageWidth(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          child: Stack(
            children: [
              Positioned.fill(
                child: AppPhoto(
                  Photos.carpentry,
                  alt: tr('A Subidha360 carpenter fixing a wardrobe door'),
                ),
              ),
              Padding(
                padding: EdgeInsets.all(wide ? 48 : AppTheme.gapLg),
                child: PhotoPanel(
                  maxWidth: 520,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('Skilled with your hands?'),
                        style: context.text.headlineLarge,
                      ),
                      const SizedBox(height: AppTheme.gapSm),
                      Text(
                        tr(
                          'Choose the jobs you want, set your own price, and '
                          'get paid safely. Free to join, and you keep 90% '
                          'of every job.',
                        ),
                        style: context.text.bodyLarge!.copyWith(
                          color: context.palette.muted,
                        ),
                      ),
                      const SizedBox(height: AppTheme.gapLg + 4),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.marigold,
                          foregroundColor: AppTheme.onMarigold,
                          minimumSize: const Size(220, 54),
                        ),
                        onPressed: () => context.push('/become-provider'),
                        child: Text(tr('Become a provider')),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Faq extends StatelessWidget {
  const _Faq();

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        tr('Does it cost anything to post a job?'),
        tr('No. Posting is free, and you only pay when you accept a bid.'),
      ),
      (
        tr('When is the provider paid?'),
        tr(
          'Your payment stays on hold after you accept a bid. It is released '
          'when you both confirm the job is finished. If only the provider '
          'confirms, it releases after 3 days unless you raise a dispute.',
        ),
      ),
      (
        tr('What if I change my mind?'),
        tr(
          'Before work starts you can cancel for a full refund. If you cancel '
          'after work has started, the payment is held for review and may be '
          'split with the provider.',
        ),
      ),
      (
        tr('What do the guide prices mean?'),
        tr(
          'They show what jobs like this usually cost, to help you judge bids. '
          'The real price is the bid you accept.',
        ),
      ),
    ];
    return _Section(
      eyebrow: tr('Questions'),
      title: tr('Good to know'),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const Divider(),
                ExpansionTile(
                  title: Text(items[i].$1, style: context.text.titleSmall),
                  childrenPadding: const EdgeInsets.fromLTRB(
                    AppTheme.gapLg,
                    0,
                    AppTheme.gapLg,
                    AppTheme.gapLg,
                  ),
                  expandedAlignment: Alignment.centerLeft,
                  children: [
                    Text(
                      items[i].$2,
                      style: context.text.bodyMedium!.copyWith(
                        color: context.palette.muted,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The closing call to action, set against the Annapurna range.
class _MountainCta extends StatelessWidget {
  const _MountainCta();

  @override
  Widget build(BuildContext context) {
    return PhotoBanner(
      photo: Photos.himalaya,
      minHeight: 340,
      alignment: const Alignment(0.3, 0.2),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: 72,
          horizontal: AppTheme.gapLg,
        ),
        child: PhotoPanel(
          maxWidth: 520,
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr('Got a job that needs doing?'),
                textAlign: TextAlign.center,
                style: context.text.headlineLarge,
              ),
              const SizedBox(height: AppTheme.gapSm),
              Text(
                tr("It's free to post, and bids come to you."),
                textAlign: TextAlign.center,
                style: context.text.bodyLarge!.copyWith(
                  color: context.palette.muted,
                ),
              ),
              const SizedBox(height: AppTheme.gapLg + 4),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.marigold,
                  foregroundColor: AppTheme.onMarigold,
                  minimumSize: const Size(200, 54),
                ),
                onPressed: () => context.push('/jobs/new'),
                child: Text(tr('Post a job')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
