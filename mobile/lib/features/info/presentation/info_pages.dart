import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/layout_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/photo.dart';
import '../../../core/widgets/site_scaffold.dart';
import '../../../core/widgets/ui.dart';
import '../../catalog/presentation/catalog_widgets.dart';
import '../domain/photo_credits.dart';

class _Article extends StatelessWidget {
  const _Article({
    required this.title,
    required this.intro,
    required this.photo,
    required this.children,
    this.alignment = Alignment.center,
    this.panelLow = false,
  });

  static const maxWidth = 820.0;

  final String title;
  final String intro;
  final String photo;
  final List<Widget> children;
  final Alignment alignment;

  /// Sets the panel low on wide screens, for photos whose people are near
  /// the top, so their faces stay in view.
  final bool panelLow;

  @override
  Widget build(BuildContext context) {
    final low = panelLow && context.isWide;
    return SiteScaffold(
      children: [
        PhotoBanner(
          photo: photo,
          minHeight: low ? 460 : 300,
          alignment: alignment,
          child: Padding(
            padding: low
                ? const EdgeInsets.only(top: 250, bottom: 40)
                : PhotoBanner.insets(context),
            child: PageWidth(
              maxWidth: maxWidth,
              child: PhotoPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: context.text.headlineLarge),
                    const SizedBox(height: AppTheme.gapSm),
                    Text(
                      intro,
                      style: context.text.bodyLarge!.copyWith(
                        color: context.palette.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppTheme.gapXl),
        PageWidth(
          maxWidth: maxWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }
}

class _Point extends StatelessWidget {
  const _Point(this.text, {this.included = true});

  final String text;
  final bool included;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.gapSm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            included ? Icons.check_circle_rounded : Icons.cancel_outlined,
            size: 20,
            color: included ? context.colors.primary : context.palette.muted,
          ),
          const SizedBox(width: AppTheme.gapSm),
          Expanded(child: Text(text, style: context.text.bodyMedium)),
        ],
      ),
    );
  }
}

/// The written guarantee. Clear terms are the point: a badge with no rules
/// behind it earns no trust.
class GuaranteePage extends StatelessWidget {
  const GuaranteePage({super.key});

  @override
  Widget build(BuildContext context) {
    return _Article(
      title: tr('Our 30-day service guarantee'),
      intro: tr(
        'If work booked through Subidha360 fails within 30 days, tell us and '
        "we'll help put it right.",
      ),
      photo: Photos.himalaya,
      alignment: const Alignment(0.3, 0.2),
      children: [
        SectionTitle(tr('What is covered')),
        _Point(tr('The same fault returning after the job was completed')),
        _Point(tr('Workmanship that was not done properly')),
        const SizedBox(height: AppTheme.gapLg),
        SectionTitle(tr('What is not covered')),
        _Point(tr('New or unrelated faults'), included: false),
        _Point(
          tr('Damage from misuse, or from work by someone else afterwards'),
          included: false,
        ),
        _Point(
          tr('Parts you supplied yourself, or normal wear'),
          included: false,
        ),
        const SizedBox(height: AppTheme.gapLg),
        SectionTitle(tr('How to claim')),
        _Point(tr('Open the finished job in your account')),
        _Point(tr('Choose "Report a problem" and tell us what happened')),
        _Point(tr('Our team reviews it and arranges the next step')),
        const SizedBox(height: AppTheme.gapLg),
        InfoBanner(
          title: tr('Need to claim?'),
          message: tr('You can claim up to 30 days after a job is completed.'),
          tone: Tone.brand,
          icon: Icons.schedule_rounded,
        ),
        const SizedBox(height: AppTheme.gapLg),
        FilledButton(
          onPressed: () => context.push('/home'),
          child: Text(tr('Go to my jobs')),
        ),
      ],
    );
  }
}

class BecomeProviderPage extends StatelessWidget {
  const BecomeProviderPage({super.key});

  @override
  Widget build(BuildContext context) {
    final benefits = [
      (
        Icons.tune_rounded,
        tr('You set the price'),
        tr('Bid what your work is worth, on the jobs you want.'),
      ),
      (
        Icons.lock_rounded,
        tr('Payment is secured first'),
        tr(
          'The money is on hold before you start, so you know you will be paid.',
        ),
      ),
      (
        Icons.percent_rounded,
        tr('Keep 90%'),
        tr('It is free to join. We only take 10% when you are paid.'),
      ),
      (
        Icons.star_rounded,
        tr('Build a reputation'),
        tr('Good reviews and a verified badge help you win more work.'),
      ),
    ];
    return _Article(
      title: tr('Grow your business with Subidha360'),
      intro: tr(
        'Get job requests from customers near you. No fees to join and no '
        'obligation to bid.',
      ),
      photo: Photos.team,
      alignment: const Alignment(0, -0.6),
      panelLow: true,
      children: [
        CardGrid(
          minCardWidth: 300,
          children: [
            for (final (icon, title, body) in benefits)
              AppCard(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconTile(icon: icon),
                    const SizedBox(width: AppTheme.gapMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: context.text.titleSmall),
                          const SizedBox(height: 2),
                          SizedBox(
                            height:
                                38 * MediaQuery.textScalerOf(context).scale(1),
                            child: Text(
                              body,
                              style: context.text.bodySmall!.copyWith(
                                color: context.palette.muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: AppTheme.gapXl),
        SectionTitle(tr('How to start')),
        _Point(tr('Log in with your mobile number')),
        _Point(tr('Add your name, services and how far you travel')),
        _Point(tr('Bid on jobs that suit you')),
        const SizedBox(height: AppTheme.gapLg),
        FilledButton(
          onPressed: () => context.push('/provider-setup'),
          child: Text(tr('Get started')),
        ),
      ],
    );
  }
}

/// Credits required by the photos' open licences.
class PhotoCreditsPage extends StatelessWidget {
  const PhotoCreditsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _Article(
      title: tr('Photo credits'),
      intro: tr(
        'Our thanks to the photographers who share their work under open '
        'licences.',
      ),
      photo: Photos.pokhara,
      alignment: const Alignment(0, -0.2),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.gapLg),
          child: InfoBanner(
            icon: Icons.image_outlined,
            title: tr('Photos of people in Subidha360 shirts'),
            message: tr(
              'These are illustrations made for this site. They show how our '
              'service works; they are not photos of real providers or '
              'customers.',
            ),
          ),
        ),
        for (final credit in photoCredits)
          Padding(
            padding: const EdgeInsets.only(bottom: AppTheme.gapSm),
            child: AppCard(
              onTap: () => launchUrl(Uri.parse(credit.source)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(credit.description, style: context.text.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    tr('{0} · {1} · Cropped and resized', [
                      credit.author,
                      credit.license,
                    ]),
                    style: context.text.bodySmall!.copyWith(
                      color: context.palette.muted,
                    ),
                  ),
                  Text(
                    tr('View original'),
                    style: context.text.labelMedium!.copyWith(
                      color: context.colors.primary,
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
