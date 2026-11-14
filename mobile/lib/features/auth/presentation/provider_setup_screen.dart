import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/providers/role_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/photo.dart';
import '../../../core/widgets/ui.dart';
import '../../jobs/domain/categories.dart';
import '../../jobs/presentation/location_fields.dart';
import '../data/auth_repository.dart';
import '../providers/auth_controller.dart';

class ProviderSetupScreen extends ConsumerStatefulWidget {
  const ProviderSetupScreen({super.key});

  @override
  ConsumerState<ProviderSetupScreen> createState() =>
      _ProviderSetupScreenState();
}

class _ProviderSetupScreenState extends ConsumerState<ProviderSetupScreen> {
  final _form = GlobalKey<FormState>();
  final _location = LocationChoice();
  final _categories = <int>{};
  late final _name = TextEditingController(
    text: ref.read(authControllerProvider).value?.displayName ?? '',
  );
  final _bio = TextEditingController();
  var _radiusKm = 5.0;
  var _years = 0.0;
  var _categoryMissing = false;
  var _locationMissing = false;
  var _busy = false;

  @override
  void dispose() {
    _location.dispose();
    _name.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _categoryMissing = _categories.isEmpty;
      _locationMissing = !_location.hasValue;
    });
    final valid = _form.currentState!.validate();
    if (!valid || _categories.isEmpty || !_location.hasValue) return;

    setState(() => _busy = true);
    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.updateName(_name.text.trim());
      final user = await repository.saveProviderProfile(
        categoryIds: _categories.toList(),
        lat: _location.lat,
        lng: _location.lng,
        radiusMeters: _radiusKm * 1000,
        bio: _bio.text.trim(),
        yearsExperience: _years.round(),
      );
      ref.read(authControllerProvider.notifier).setUser(user);
      await ref.read(activeRoleProvider.notifier).set(UiRole.provider);
      if (mounted) context.go('/home');
    } catch (error) {
      if (mounted) {
        context.showError(error);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('Become a provider')),
        leading: BackButton(
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      bottomNavigationBar: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: BottomActionBar(
            children: [
              FilledButton(
                onPressed: _busy ? null : _save,
                child: Text(_busy ? tr('Saving...') : tr('Start finding work')),
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
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  child: const SizedBox(
                    height: 170,
                    child: AppPhoto(
                      Photos.providerTools,
                      alignment: Alignment(0.45, 0),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.gapLg),
                Text(
                  tr('Get job alerts near you'),
                  style: context.text.headlineSmall,
                ),
                const SizedBox(height: AppTheme.gapXs),
                Text(
                  tr(
                    "We'll only send you jobs that match your services and area.",
                  ),
                  style: context.text.bodyMedium!.copyWith(
                    color: context.palette.muted,
                  ),
                ),
                const SizedBox(height: AppTheme.gapXl),
                SectionTitle(tr('About you')),
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: tr('Your name or business name'),
                  ),
                  validator: (value) => (value ?? '').trim().length < 2
                      ? tr('Add your name so customers know who is bidding')
                      : null,
                ),
                const SizedBox(height: AppTheme.gapSm),
                TextFormField(
                  controller: _bio,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 400,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: tr('What are you best at? (optional)'),
                  ),
                ),
                const SizedBox(height: AppTheme.gapMd),
                SectionTitle(
                  tr('Years of experience'),
                  trailing: _years.round() == 0
                      ? tr('Under 1')
                      : '${_years.round()}',
                ),
                AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.gapXs,
                    vertical: AppTheme.gapSm,
                  ),
                  child: Slider(
                    value: _years,
                    max: 30,
                    divisions: 30,
                    label: '${_years.round()}',
                    onChanged: (value) => setState(() => _years = value),
                  ),
                ),
                const SizedBox(height: AppTheme.gapXl),
                SectionTitle(tr('What do you offer?')),
                Wrap(
                  spacing: AppTheme.gapSm,
                  runSpacing: AppTheme.gapSm,
                  children: [
                    for (final category in serviceCategories)
                      FilterChip(
                        avatar: Icon(category.icon, size: 18),
                        label: Text(category.name),
                        showCheckmark: false,
                        selected: _categories.contains(category.id),
                        selectedColor: context.colors.primaryContainer,
                        backgroundColor: context.colors.surface,
                        side: BorderSide(color: context.palette.line),
                        onSelected: (selected) => setState(() {
                          selected
                              ? _categories.add(category.id)
                              : _categories.remove(category.id);
                          _categoryMissing = false;
                        }),
                      ),
                  ],
                ),
                if (_categoryMissing)
                  Padding(
                    padding: const EdgeInsets.only(top: AppTheme.gapSm),
                    child: Text(
                      tr('Choose at least one service'),
                      style: context.text.bodySmall!.copyWith(
                        color: context.colors.error,
                      ),
                    ),
                  ),
                const SizedBox(height: AppTheme.gapXl),
                SectionTitle(tr('Where are you based?')),
                LocationPicker(
                  choice: _location,
                  missing: _locationMissing && !_location.hasValue,
                ),
                const SizedBox(height: AppTheme.gapMd),
                SectionTitle(
                  tr('How far will you travel?'),
                  trailing: tr('{0} km', [_radiusKm.round()]),
                ),
                AppCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.gapXs,
                    vertical: AppTheme.gapSm,
                  ),
                  child: Slider(
                    value: _radiusKm,
                    min: 1,
                    max: 50,
                    divisions: 49,
                    label: tr('{0} km', [_radiusKm.round()]),
                    onChanged: (value) => setState(() => _radiusKm = value),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
