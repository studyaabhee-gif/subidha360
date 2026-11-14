import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui.dart';
import '../data/admin_api.dart';
import '../domain/admin_models.dart';
import 'admin_widgets.dart';
import 'withdrawals_page.dart';

/// A provider's identity documents, with approve and reject while a check
/// waits.
class IdentityPanel extends ConsumerWidget {
  const IdentityPanel({required this.detail, super.key});

  final UserDetail detail;

  Future<void> _decide(
    BuildContext context,
    WidgetRef ref,
    bool approve,
  ) async {
    final u = detail.user;
    String reason = '';
    if (approve) {
      final yes = await context.confirm(
        title: 'Approve ${u.label}?',
        message:
            'Only if the card is genuine, readable, and its name matches '
            'the account. They get the Verified badge and can withdraw money.',
        action: 'Approve',
      );
      if (!yes) return;
    } else {
      final text = await context.askForText(
        title: 'Reject this check?',
        message:
            'They see your reason and can send new documents. Be specific, '
            'for example "The back of the card is cut off."',
        label: 'Reason',
        action: 'Reject',
        destructive: true,
      );
      if (text == null) return;
      reason = text;
    }
    if (!context.mounted) return;
    try {
      await ref
          .read(adminApiProvider)
          .decideCheck(u.id, approve: approve, reason: reason);
      ref.invalidate(adminUserProvider(u.id));
      ref.invalidate(overviewProvider);
      if (context.mounted) {
        context.showMessage(approve ? 'Approved and verified' : 'Rejected');
      }
    } catch (error) {
      if (context.mounted) context.showError(error);
    }
  }

  void _open(BuildContext context, AdminDocument d) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppTheme.gapLg),
              child: Text(d.title, style: context.text.titleMedium),
            ),
            Flexible(
              child: InteractiveViewer(
                maxScale: 5,
                child: _DocImage(id: d.id, fit: BoxFit.contain),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final u = detail.user;
    final muted = context.text.bodySmall!.copyWith(
      color: context.palette.muted,
    );
    final (status, tone) = switch (u.check) {
      'PENDING' => ('Waiting for your check', Tone.warning),
      'APPROVED' => ('Approved', Tone.success),
      'REJECTED' => ('Rejected', Tone.danger),
      _ when u.isVerified => ('Verified by hand, no documents', Tone.success),
      _ => ('Not sent yet', Tone.neutral),
    };
    return Panel(
      title: 'Identity check',
      trailing: Pill(label: status, tone: tone),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (detail.checkSubmittedAt != null)
            Text('Sent ${dateTime(detail.checkSubmittedAt!)}', style: muted),
          if (detail.checkReason.isNotEmpty)
            Text('Reason given: ${detail.checkReason}', style: muted),
          const SizedBox(height: AppTheme.gapMd),
          if (detail.documents.isEmpty)
            Text('No documents uploaded.', style: muted)
          else
            Wrap(
              spacing: AppTheme.gapMd,
              runSpacing: AppTheme.gapMd,
              children: [
                for (final d in detail.documents)
                  SizedBox(
                    width: 220,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Material(
                          clipBehavior: Clip.antiAlias,
                          borderRadius: BorderRadius.circular(
                            AppTheme.radiusMd,
                          ),
                          child: InkWell(
                            onTap: d.isImage ? () => _open(context, d) : null,
                            child: AspectRatio(
                              aspectRatio: 1.58,
                              child: d.isImage
                                  ? _DocImage(id: d.id)
                                  : const IconTile(
                                      icon: Icons.picture_as_pdf_outlined,
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppTheme.gapXs),
                        Text(d.title, style: context.text.labelMedium),
                        Text(dateTime(d.createdAt), style: muted),
                      ],
                    ),
                  ),
              ],
            ),
          if (u.check == 'PENDING') ...[
            const SizedBox(height: AppTheme.gapLg),
            Wrap(
              spacing: AppTheme.gapSm,
              runSpacing: AppTheme.gapSm,
              children: [
                FilledButton.icon(
                  onPressed: () => _decide(context, ref, true),
                  icon: const Icon(Icons.verified_rounded),
                  label: const Text('Approve'),
                ),
                OutlinedButton(
                  onPressed: () => _decide(context, ref, false),
                  child: const Text('Reject'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DocImage extends ConsumerWidget {
  const _DocImage({required this.id, this.fit = BoxFit.cover});

  final String id;
  final BoxFit fit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(adminDocumentProvider(id))) {
      AsyncData(:final value) => Image.memory(value, fit: fit),
      AsyncError() => const Center(child: Icon(Icons.broken_image_outlined)),
      _ => ColoredBox(color: context.palette.skeleton),
    };
  }
}

/// A person's withdrawals, newest first.
class WithdrawalsPanel extends StatelessWidget {
  const WithdrawalsPanel({required this.rows, super.key});

  final List<WithdrawalRow> rows;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Withdrawals'),
        for (final w in rows) WithdrawalCard(w: w, showPerson: false),
      ],
    );
  }
}
