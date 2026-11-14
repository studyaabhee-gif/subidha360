import 'package:flutter/material.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/schedule_picker.dart';

/// A chosen time. A null date means as soon as possible.
typedef NewTime = ({String? date, String? slot});

/// Picks a new time for a job, returning it when saved.
class RescheduleSheet extends StatefulWidget {
  const RescheduleSheet({
    required this.date,
    required this.slot,
    required this.assigned,
    super.key,
  });

  final String? date;
  final String? slot;

  /// Whether a provider has already committed to the current time.
  final bool assigned;

  @override
  State<RescheduleSheet> createState() => _RescheduleSheetState();
}

class _RescheduleSheetState extends State<RescheduleSheet> {
  late String? _date = widget.date;
  late String? _slot = widget.slot;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.gapXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('Change the time'), style: context.text.titleLarge),
            const SizedBox(height: AppTheme.gapXs),
            Text(
              widget.assigned
                  ? tr(
                      'We will tell your provider straight away. If the new time '
                      "doesn't suit them, message them to agree another.",
                    )
                  : tr('Providers will see the new time on your job.'),
              style: context.text.bodyMedium!.copyWith(
                color: context.palette.muted,
              ),
            ),
            const SizedBox(height: AppTheme.gapLg),
            SchedulePicker(
              date: _date,
              slot: _slot,
              onChanged: (date, slot) => setState(() {
                _date = date;
                _slot = slot;
              }),
            ),
            const SizedBox(height: AppTheme.gapLg),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context)
                      .pop<NewTime>((date: _date, slot: _slot)),
              child: Text(tr('Save new time')),
            ),
          ],
        ),
      ),
    );
  }
}
