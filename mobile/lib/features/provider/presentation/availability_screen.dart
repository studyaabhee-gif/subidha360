import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/l10n/tr.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/schedule_picker.dart';
import '../../../core/widgets/ui.dart';
import '../../jobs/domain/job.dart';
import '../data/provider_api.dart';
import '../domain/provider_models.dart';
import 'provider_widgets.dart';

/// Short slot names for the weekly grid, where space is tight.
const _shortSlots = {
  '08-10': '8–10',
  '10-12': '10–12',
  '12-14': '12–2',
  '14-16': '2–4',
  '16-18': '4–6',
};

class AvailabilityScreen extends ConsumerWidget {
  const AvailabilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(myProviderStateProvider);
    if (state case AsyncData(:final value)) {
      return _Editor(initial: value.availability);
    }
    return ToolPage(
      title: tr('Working hours'),
      children: [
        ToolAsync(
          value: state,
          onRetry: () => ref.invalidate(myProviderStateProvider),
          builder: (_) => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _Editor extends ConsumerStatefulWidget {
  const _Editor({required this.initial});

  final Availability? initial;

  @override
  ConsumerState<_Editor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<_Editor> {
  late var _anyTime = widget.initial == null;
  late final Map<String, Set<String>> _weekly = {
    for (final day in weekdays) day: {...?widget.initial?.weekly[day]},
  };
  late final List<String> _daysOff = [...?widget.initial?.daysOff];
  var _busy = false;

  bool get _hasHours => _weekly.values.any((s) => s.isNotEmpty);

  void _fillWorkingWeek() {
    setState(() {
      for (final day in weekdays) {
        _weekly[day] = day == 'sat' ? {} : timeSlots.keys.toSet();
      }
    });
  }

  Future<void> _addDayOff() async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (day == null) return;
    final iso = isoDate(day);
    if (!_daysOff.contains(iso)) {
      setState(
        () => _daysOff
          ..add(iso)
          ..sort(),
      );
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(providerApiProvider)
          .setAvailability(
            _anyTime ? null : Availability(weekly: _weekly, daysOff: _daysOff),
          );
      ref.invalidate(myProviderStateProvider);
      if (mounted) context.showMessage(tr('Working hours saved'));
    } catch (error) {
      if (mounted) context.showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final muted = context.text.bodySmall!.copyWith(
      color: context.palette.muted,
    );
    return ToolPage(
      title: tr('Working hours'),
      bottom: BottomActionBar(
        children: [
          FilledButton(
            onPressed: _busy || (!_anyTime && !_hasHours) ? null : _save,
            child: Text(tr('Save')),
          ),
        ],
      ),
      children: [
        Text(
          tr(
            'Jobs booked for a set time are only offered to you when you '
            'work then. Urgent jobs reach you any time you are online.',
          ),
          style: muted,
        ),
        const SizedBox(height: AppTheme.gapLg),
        SegmentedButton<bool>(
          segments: [
            ButtonSegment(value: true, label: Text(tr('Any time'))),
            ButtonSegment(value: false, label: Text(tr('Set hours'))),
          ],
          selected: {_anyTime},
          onSelectionChanged: (s) => setState(() {
            _anyTime = s.first;
            if (!_anyTime && !_hasHours) _fillWorkingWeek();
          }),
        ),
        if (!_anyTime) ...[
          const SizedBox(height: AppTheme.gapXl),
          SectionTitle(tr('Each week')),
          for (final day in weekdays)
            Padding(
              padding: const EdgeInsets.only(bottom: AppTheme.gapMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr(weekdayNames[day]!), style: context.text.titleSmall),
                  const SizedBox(height: AppTheme.gapXs),
                  Wrap(
                    spacing: AppTheme.gapXs,
                    runSpacing: AppTheme.gapXs,
                    children: [
                      for (final slot in timeSlots.keys)
                        FilterChip(
                          label: Text(_shortSlots[slot]!),
                          tooltip: tr(timeSlots[slot]!),
                          selected: _weekly[day]!.contains(slot),
                          showCheckmark: false,
                          onSelected: (on) => setState(() {
                            if (on) {
                              _weekly[day]!.add(slot);
                            } else {
                              _weekly[day]!.remove(slot);
                            }
                          }),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          if (!_hasHours)
            Text(
              tr('Choose at least one time you can work.'),
              style: muted.copyWith(color: context.colors.error),
            ),
          const SizedBox(height: AppTheme.gapLg),
          SectionTitle(tr('Days off')),
          if (_daysOff.isEmpty)
            Text(
              tr('Add festivals, trips or any day you are away.'),
              style: muted,
            ),
          Wrap(
            spacing: AppTheme.gapSm,
            runSpacing: AppTheme.gapSm,
            children: [
              for (final d in _daysOff)
                InputChip(
                  label: Text(friendlyDate(d)),
                  onDeleted: () => setState(() => _daysOff.remove(d)),
                  deleteButtonTooltipMessage: tr('Remove'),
                ),
            ],
          ),
          const SizedBox(height: AppTheme.gapSm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _addDayOff,
              icon: const Icon(Icons.event_busy_outlined),
              label: Text(tr('Add a day off')),
            ),
          ),
        ],
      ],
    );
  }
}

/// "Sun to Fri, 8 AM to 6 PM"-style summary for customers. Null means any time.
String availabilitySummary(Availability? a) {
  if (a == null) return tr('Takes jobs any day');
  final days = [
    for (final d in weekdays)
      if ((a.weekly[d] ?? const {}).isNotEmpty) tr(weekdayNames[d]!),
  ];
  return days.isEmpty ? tr('Not taking booked jobs') : days.join(', ');
}
