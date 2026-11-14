import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/money_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../domain/bid.dart';

/// The platform's share, shown so providers can price with their eyes open. The
/// server applies its own COMMISSION_BPS, so keep the two in step.
const commissionPercent = 10;

int providerTakeHome(int paisa) => paisa - paisa * commissionPercent ~/ 100;

/// Returns a [BidDraft], or null if dismissed.
class BidSheet extends StatefulWidget {
  const BidSheet({super.key});

  @override
  State<BidSheet> createState() => _BidSheetState();
}

class _BidSheetState extends State<BidSheet> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  var _partsIncluded = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paisa = _amount.text.toPaisa;
    final valid = paisa != null && paisa > 0;
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
              Text(tr('Your price'), style: context.text.headlineSmall),
              const SizedBox(height: AppTheme.gapXs),
              Text(
                tr('You can bid once, so include everything the job needs.'),
                style: context.text.bodyMedium!.copyWith(
                  color: context.palette.muted,
                ),
              ),
              const SizedBox(height: AppTheme.gapLg),
              TextField(
                controller: _amount,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                style: context.text.headlineSmall,
                decoration: InputDecoration(
                  prefixText: tr('Rs  '),
                  hintText: '0',
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppTheme.gapSm),
              Text(
                valid
                    ? tr('You receive {0} after the {1}% platform fee.', [
                        providerTakeHome(paisa).asRupees,
                        commissionPercent,
                      ])
                    : tr('A {0}% platform fee applies when you are paid.', [
                        commissionPercent,
                      ]),
                style: context.text.bodySmall!.copyWith(
                  color: context.palette.muted,
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  tr('Parts are included'),
                  style: context.text.titleSmall,
                ),
                subtitle: Text(
                  tr('Seekers trust an all-in price more.'),
                  style: context.text.bodySmall,
                ),
                value: _partsIncluded,
                onChanged: (on) => setState(() => _partsIncluded = on),
              ),
              TextField(
                controller: _note,
                minLines: 1,
                maxLines: 3,
                maxLength: 300,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: tr(
                    'Add a note, such as when you can come (optional)',
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.gapSm),
              FilledButton(
                onPressed: valid
                    ? () => Navigator.pop(
                        context,
                        BidDraft(
                          amountPaisa: paisa,
                          partsIncluded: _partsIncluded,
                          note: _note.text.trim(),
                        ),
                      )
                    : null,
                child: Text(tr('Send bid')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
