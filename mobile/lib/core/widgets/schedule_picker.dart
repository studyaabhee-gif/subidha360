import 'package:flutter/material.dart';

import '../../core/l10n/tr.dart';
import '../../features/jobs/domain/job.dart';
import '../extensions/context_extensions.dart';
import '../theme/app_theme.dart';

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// YYYY-MM-DD, the format the API stores.
String isoDate(DateTime day) =>
    '${day.year}-${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// "Today", or "Sat 7 Nov", for a stored date.
String friendlyDate(String iso, [DateTime? now]) {
  final day = DateTime.tryParse(iso);
  if (day == null) return iso;
  final today = now ?? DateTime.now();
  if (isoDate(today) == iso) return tr('Today');
  if (isoDate(today.add(const Duration(days: 1))) == iso) return tr('Tomorrow');
  return '${tr(_weekdays[day.weekday - 1])} ${day.day} ${tr(_months[day.month - 1])}';
}

/// One line describing when a job is wanted.
String scheduleLabel(String? date, String? slot) {
  if (date == null || date.isEmpty) return tr('As soon as possible');
  return '${friendlyDate(date)}, ${tr(timeSlots[slot] ?? '')}'.trim();
}

/// A date strip and arrival windows. A null date means as soon as possible.
class SchedulePicker extends StatelessWidget {
  const SchedulePicker({
    required this.date,
    required this.slot,
    required this.onChanged,
    super.key,
  });

  final String? date;
  final String? slot;
  final void Function(String? date, String? slot) onChanged;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final days = [for (var i = 0; i < 8; i++) today.add(Duration(days: i))];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 66 * MediaQuery.textScalerOf(context).scale(1).clamp(1, 1.5),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _DayTile(
                top: tr('As soon'),
                bottom: tr('as possible'),
                selected: date == null,
                onTap: () => onChanged(null, null),
              ),
              for (final day in days)
                _DayTile(
                  top: tr(_weekdays[day.weekday - 1]),
                  bottom: '${day.day} ${tr(_months[day.month - 1])}',
                  selected: date == isoDate(day),
                  onTap: () =>
                      onChanged(isoDate(day), slot ?? timeSlots.keys.first),
                ),
            ],
          ),
        ),
        if (date != null) ...[
          const SizedBox(height: AppTheme.gapMd),
          Wrap(
            spacing: AppTheme.gapSm,
            runSpacing: AppTheme.gapSm,
            children: [
              for (final MapEntry(key: key, value: label) in timeSlots.entries)
                ChoiceChip(
                  label: Text(label),
                  selected: slot == key,
                  showCheckmark: false,
                  selectedColor: context.colors.primaryContainer,
                  backgroundColor: context.colors.surface,
                  side: BorderSide(color: context.palette.line),
                  onSelected: (_) => onChanged(date, key),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.top,
    required this.bottom,
    required this.selected,
    required this.onTap,
  });

  final String top;
  final String bottom;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = selected ? colors.onPrimaryContainer : colors.onSurface;
    return Padding(
      padding: const EdgeInsets.only(right: AppTheme.gapSm),
      child: Semantics(
        button: true,
        selected: selected,
        child: Material(
          color: selected ? colors.primaryContainer : colors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
            side: BorderSide(
              color: selected ? colors.primary : context.palette.line,
              width: selected ? 1.6 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Container(
              width: 84,
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    top,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelMedium!.copyWith(
                      color: foreground,
                    ),
                  ),
                  Text(
                    bottom,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelSmall!.copyWith(
                      color: foreground,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
