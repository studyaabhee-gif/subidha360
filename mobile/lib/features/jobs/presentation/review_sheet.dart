import 'package:flutter/material.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/provider_profile.dart';

class ReviewDraft {
  const ReviewDraft(this.rating, this.tags, this.comment);

  final int rating;
  final List<String> tags;
  final String comment;
}

class ReviewSheet extends StatefulWidget {
  const ReviewSheet({super.key});

  @override
  State<ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends State<ReviewSheet> {
  final _comment = TextEditingController();
  final _tags = <String>{};
  var _rating = 0;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.gapXl,
            0,
            AppTheme.gapXl,
            AppTheme.gapLg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tr('How did it go?'), style: context.text.headlineSmall),
              const SizedBox(height: AppTheme.gapXs),
              Text(
                tr('Your review helps others choose well.'),
                style: context.text.bodyMedium!.copyWith(
                  color: context.palette.muted,
                ),
              ),
              const SizedBox(height: AppTheme.gapLg),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 1; i <= 5; i++)
                    IconButton(
                      tooltip: tr('{0} out of 5', [i]),
                      iconSize: 38,
                      onPressed: () => setState(() => _rating = i),
                      icon: Icon(
                        i <= _rating
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        color: context.colors.secondary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppTheme.gapSm),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: AppTheme.gapSm,
                runSpacing: AppTheme.gapSm,
                children: [
                  for (final tag in reviewTags)
                    FilterChip(
                      label: Text(tr(tag)),
                      showCheckmark: false,
                      selected: _tags.contains(tag),
                      selectedColor: context.colors.primaryContainer,
                      backgroundColor: context.colors.surface,
                      side: BorderSide(color: context.palette.line),
                      onSelected: (on) => setState(
                        () => on ? _tags.add(tag) : _tags.remove(tag),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppTheme.gapLg),
              TextField(
                controller: _comment,
                minLines: 2,
                maxLines: 4,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: tr('Anything else? (optional)'),
                ),
              ),
              const SizedBox(height: AppTheme.gapSm),
              FilledButton(
                onPressed: _rating == 0
                    ? null
                    : () => Navigator.pop(
                        context,
                        ReviewDraft(
                          _rating,
                          _tags.toList(),
                          _comment.text.trim(),
                        ),
                      ),
                child: Text(tr('Post review')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
