import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/money_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/photo.dart';
import '../../../core/widgets/schedule_picker.dart';
import '../../../core/widgets/ui.dart';
import '../../catalog/data/catalog_repository.dart';
import '../../catalog/domain/catalog.dart';
import '../data/job_repository.dart';
import '../domain/categories.dart';
import '../providers/job_providers.dart';
import 'location_fields.dart';
import 'problem_photos.dart';
import 'provider_summary.dart';

class CreateJobScreen extends ConsumerStatefulWidget {
  const CreateJobScreen({
    this.initialCategory,
    this.serviceId,
    this.date,
    this.slot,
    this.repeatJobId,
    this.providerId,
    super.key,
  });

  final int? initialCategory;
  final String? serviceId;
  final String? date;
  final String? slot;

  /// An earlier job to copy, so a repeat booking takes a few taps.
  final String? repeatJobId;

  /// A provider to ask directly, such as a favourite.
  final String? providerId;

  @override
  ConsumerState<CreateJobScreen> createState() => _CreateJobScreenState();
}

class _CreateJobScreenState extends ConsumerState<CreateJobScreen> {
  final _form = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _address = TextEditingController();
  final _location = LocationChoice();
  late int? _category = widget.initialCategory;
  late String? _date = widget.date;
  late String? _slot = widget.slot;
  late String? _serviceId = widget.serviceId;
  late String? _providerId = widget.providerId;
  var _photos = <Uint8List>[];
  var _categoryMissing = false;
  var _locationMissing = false;
  var _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.repeatJobId != null) _copyJob(widget.repeatJobId!);
  }

  Future<void> _copyJob(String id) async {
    try {
      final job = await ref.read(jobRepositoryProvider).job(id);
      if (!mounted) return;
      final place = job.jobLocation;
      if (place != null) _location.choosePrevious(place.lat, place.lng);
      setState(() {
        _category = job.categoryId;
        _serviceId ??= job.serviceId;
        _description.text = job.description;
        _address.text = job.address;
      });
    } catch (error) {
      if (mounted) context.showError(error);
    }
  }

  /// Photos upload after posting. A failed one shouldn't lose the job.
  Future<void> _uploadPhotos(String jobId) async {
    if (_photos.isEmpty) return;
    try {
      final jobs = ref.read(jobRepositoryProvider);
      for (final photo in _photos) {
        await jobs.uploadPhoto(jobId, photo);
      }
    } catch (_) {
      if (mounted) {
        context.showMessage(
          tr(
            "Your job is posted, but a photo didn't upload. Add it from the job.",
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _description.dispose();
    _address.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _submit(CatalogService? service) async {
    final category = service?.categoryId ?? _category;
    setState(() {
      _categoryMissing = category == null;
      _locationMissing = !_location.hasValue;
    });
    final valid = _form.currentState!.validate();
    if (!valid || category == null || !_location.hasValue) return;

    setState(() => _busy = true);
    try {
      final job = await ref
          .read(jobRepositoryProvider)
          .create(
            categoryId: category,
            serviceId: service?.id,
            description: _description.text.trim(),
            address: _address.text.trim(),
            lat: _location.lat,
            lng: _location.lng,
            preferredDate: _date,
            preferredSlot: _slot,
            preferredProviderId: _providerId,
          );
      await _uploadPhotos(job.id);
      ref.invalidate(myJobsProvider);
      if (mounted) context.pushReplacement('/jobs/${job.id}');
    } catch (error) {
      if (mounted) {
        context.showError(error);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = _serviceId == null
        ? null
        : ref.watch(catalogProvider).value?.serviceById(_serviceId!);
    final asked = _providerId == null
        ? null
        : ref.watch(providerDetailProvider(_providerId!)).value?.$1;
    final categories = asked == null
        ? serviceCategories
        : serviceCategories.where((c) => asked.categoryIds.contains(c.id));

    return Scaffold(
      appBar: AppBar(title: Text(tr('Post a job'))),
      bottomNavigationBar: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: BottomActionBar(
            children: [
              FilledButton(
                onPressed: _busy ? null : () => _submit(service),
                child: Text(
                  _busy ? tr('Posting...') : tr('Post job and get bids'),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Form(
        key: _form,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: FormScroll(
              children: [
                if (asked != null) ...[
                  AppCard(
                    child: Row(
                      children: [
                        const IconTile(icon: Icons.favorite_rounded),
                        const SizedBox(width: AppTheme.gapMd),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('Asking {0}', [asked.name]),
                                style: context.text.titleSmall,
                              ),
                              RatingLabel(profile: asked),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: tr('Ask anyone nearby instead'),
                          onPressed: () => setState(() => _providerId = null),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.gapXl),
                ],
                if (service != null)
                  _ChosenService(service: service)
                else ...[
                  SectionTitle(tr('Which service?')),
                  LayoutBuilder(
                    builder: (context, constraints) => GridView.count(
                      crossAxisCount: constraints.maxWidth > 560 ? 4 : 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: AppTheme.gapSm,
                      crossAxisSpacing: AppTheme.gapSm,
                      childAspectRatio: 1.15,
                      children: [
                        for (final category in categories)
                          _CategoryOption(
                            category: category,
                            selected: _category == category.id,
                            onTap: () => setState(() {
                              _category = category.id;
                              _categoryMissing = false;
                            }),
                          ),
                      ],
                    ),
                  ),
                  if (_categoryMissing)
                    Padding(
                      padding: const EdgeInsets.only(top: AppTheme.gapSm),
                      child: Text(
                        tr('Choose a service'),
                        style: context.text.bodySmall!.copyWith(
                          color: context.colors.error,
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: AppTheme.gapXl),
                SectionTitle(tr('What needs doing?')),
                TextFormField(
                  controller: _description,
                  minLines: 3,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: tr(
                      'For example: kitchen tap is leaking under the sink',
                    ),
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? tr('Describe the job so providers can price it')
                      : null,
                ),
                const SizedBox(height: AppTheme.gapLg),
                Text(
                  tr('Add photos (optional)'),
                  style: context.text.titleSmall,
                ),
                const SizedBox(height: AppTheme.gapXs),
                Text(
                  tr(
                    'Providers price more accurately when they can see the '
                    'problem. Avoid showing people or private documents.',
                  ),
                  style: context.text.bodySmall!.copyWith(
                    color: context.palette.muted,
                  ),
                ),
                const SizedBox(height: AppTheme.gapSm),
                ProblemPhotoPicker(
                  photos: _photos,
                  onChanged: (photos) => setState(() => _photos = photos),
                ),
                const SizedBox(height: AppTheme.gapXl),
                SectionTitle(tr('When?')),
                SchedulePicker(
                  date: _date,
                  slot: _slot,
                  onChanged: (date, slot) => setState(() {
                    _date = date;
                    _slot = slot;
                  }),
                ),
                const SizedBox(height: AppTheme.gapXl),
                SectionTitle(tr('Where?')),
                LocationPicker(
                  choice: _location,
                  missing: _locationMissing && !_location.hasValue,
                ),
                const SizedBox(height: AppTheme.gapSm),
                TextFormField(
                  controller: _address,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: tr('House, street or nearby landmark'),
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? tr('Add the address')
                      : null,
                ),
                const SizedBox(height: AppTheme.gapLg),
                InfoBanner(
                  title: tr('Free to post'),
                  message: tr(
                    "You'll only pay when you accept a bid, and the payment "
                    'stays on hold until the job is done.',
                  ),
                  tone: Tone.brand,
                  icon: Icons.verified_user_outlined,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChosenService extends StatelessWidget {
  const _ChosenService({required this.service});

  final CatalogService service;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          PhotoThumb(categoryOf(service.categoryId).photo),
          const SizedBox(width: AppTheme.gapMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.displayName, style: context.text.titleSmall),
                Text(
                  tr('Usually {0} to {1}', [
                    service.guideFromPaisa.asRupeesShort,
                    service.guideToPaisa.asRupeesShort,
                  ]),
                  style: context.text.bodySmall!.copyWith(
                    color: context.palette.muted,
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

class _CategoryOption extends StatelessWidget {
  const _CategoryOption({
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final ServiceCategory category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppTheme.radiusMd);
    return Semantics(
      selected: selected,
      button: true,
      label: category.name,
      excludeSemantics: true,
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: AppPhoto(category.photo, cacheWidth: 400)),
                ColoredBox(
                  color: selected
                      ? context.colors.primary
                      : context.colors.surface,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.gapSm,
                      vertical: 6,
                    ),
                    child: Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelMedium!.copyWith(
                        color: selected
                            ? context.colors.onPrimary
                            : context.colors.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (selected)
              Positioned(
                top: AppTheme.gapSm,
                right: AppTheme.gapSm,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.check_circle_rounded,
                    color: context.colors.primary,
                  ),
                ),
              ),
            Material(
              color: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: radius,
                side: selected
                    ? BorderSide(color: context.colors.primary, width: 3)
                    : BorderSide.none,
              ),
              child: InkWell(onTap: onTap),
            ),
          ],
        ),
      ),
    );
  }
}
