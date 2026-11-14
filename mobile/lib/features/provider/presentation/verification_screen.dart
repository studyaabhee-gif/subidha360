import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/date_extensions.dart';
import '../../../core/l10n/tr.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui.dart';
import '../../auth/providers/auth_controller.dart';
import '../data/provider_api.dart';
import '../domain/provider_models.dart';
import 'provider_widgets.dart';

/// Lets a provider send their citizenship card, and any certificates, for an
/// identity check. Passing it earns the Verified badge.
class VerificationScreen extends ConsumerStatefulWidget {
  const VerificationScreen({super.key});

  @override
  ConsumerState<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends ConsumerState<VerificationScreen> {
  var _busy = false;

  void _refresh() {
    ref.invalidate(myProviderStateProvider);
    ref.invalidate(myDocumentsProvider);
  }

  Future<void> _run(Future<void> Function() action, [String? done]) async {
    setState(() => _busy = true);
    try {
      await action();
      _refresh();
      if (done != null && mounted) context.showMessage(done);
    } catch (error) {
      if (mounted) context.showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addCard(String kind) async {
    final bytes = await pickOnePhoto(context);
    if (bytes == null) return;
    await _run(() => ref.read(providerApiProvider).addDocument(kind, bytes));
  }

  Future<void> _addCertificate() async {
    final bytes = await pickOnePhoto(context);
    if (bytes == null || !mounted) return;
    final label = await context.askForText(
      title: tr('Name this certificate'),
      message: tr('For example: CTEVT plumbing level 1.'),
      label: tr('Certificate name'),
      action: tr('Add'),
    );
    if (label == null) return;
    await _run(
      () => ref
          .read(providerApiProvider)
          .addDocument(DocumentKind.certificate, bytes, label: label),
    );
  }

  Future<void> _delete(ProviderDocument doc) async {
    final yes = await context.confirm(
      title: tr('Remove this document?'),
      message: doc.kind == DocumentKind.certificate
          ? tr('It will no longer be shown to our team.')
          : tr(
              'If you were verified, the badge is removed until a new check passes.',
            ),
      action: tr('Remove'),
      destructive: true,
    );
    if (!yes) return;
    await _run(() => ref.read(providerApiProvider).deleteDocument(doc.id));
  }

  Future<void> _submit() async {
    await _run(
      () => ref.read(providerApiProvider).submitCheck(),
      tr('Sent. We usually check documents within one working day.'),
    );
    // The profile shows the badge state, so refresh the signed-in user too.
    ref.invalidate(authControllerProvider);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(myProviderStateProvider);
    final docs = ref.watch(myDocumentsProvider);
    return ToolPage(
      title: tr('Identity check'),
      onRefresh: () async => _refresh(),
      children: [
        ToolAsync(
          value: state,
          onRetry: _refresh,
          builder: (s) => _StatusBanner(state: s),
        ),
        const SizedBox(height: AppTheme.gapLg),
        ToolAsync(
          value: docs,
          onRetry: _refresh,
          builder: (rows) {
            final status = state.value?.checkStatus ?? '';
            final locked = status == CheckStatus.pending;
            ProviderDocument? find(String kind) =>
                rows.where((d) => d.kind == kind).firstOrNull;
            final front = find(DocumentKind.front);
            final back = find(DocumentKind.back);
            final certificates = rows
                .where((d) => d.kind == DocumentKind.certificate)
                .toList();
            final canSubmit =
                !locked &&
                status != CheckStatus.approved &&
                front != null &&
                back != null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionTitle(tr('Citizenship card')),
                Text(
                  tr(
                    'Take clear photos of both sides, with all four corners '
                    'showing and nothing covered.',
                  ),
                  style: context.text.bodySmall!.copyWith(
                    color: context.palette.muted,
                  ),
                ),
                const SizedBox(height: AppTheme.gapMd),
                Row(
                  children: [
                    Expanded(
                      child: _CardSlot(
                        label: tr('Front'),
                        doc: front,
                        onAdd: locked || _busy
                            ? null
                            : () => _addCard(DocumentKind.front),
                      ),
                    ),
                    const SizedBox(width: AppTheme.gapMd),
                    Expanded(
                      child: _CardSlot(
                        label: tr('Back'),
                        doc: back,
                        onAdd: locked || _busy
                            ? null
                            : () => _addCard(DocumentKind.back),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.gapXl),
                SectionTitle(
                  tr('Skill certificates (optional)'),
                  trailing: '${certificates.length}/5',
                ),
                for (final c in certificates)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.gapSm),
                    child: AppCard(
                      padding: const EdgeInsets.all(AppTheme.gapMd),
                      child: Row(
                        children: [
                          SizedBox.square(
                            dimension: 52,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                AppTheme.radiusSm,
                              ),
                              child: c.isImage
                                  ? BytesImage(
                                      bytes: ref.watch(
                                        documentBytesProvider(c.id),
                                      ),
                                    )
                                  : const IconTile(
                                      icon: Icons.picture_as_pdf_outlined,
                                    ),
                            ),
                          ),
                          const SizedBox(width: AppTheme.gapMd),
                          Expanded(
                            child: Text(
                              c.label.isEmpty ? tr('Certificate') : c.label,
                              style: context.text.titleSmall,
                            ),
                          ),
                          if (!locked)
                            IconButton(
                              tooltip: tr('Remove'),
                              onPressed: _busy ? null : () => _delete(c),
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                        ],
                      ),
                    ),
                  ),
                if (certificates.length < 5 && !locked)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _busy ? null : _addCertificate,
                      icon: const Icon(Icons.add_rounded),
                      label: Text(tr('Add a certificate')),
                    ),
                  ),
                const SizedBox(height: AppTheme.gapXl),
                InfoBanner(
                  icon: Icons.lock_outline_rounded,
                  title: tr('Who sees these'),
                  message: tr(
                    'Only Subidha360 staff, to check who you are. Customers '
                    'only see the Verified badge, never your documents.',
                  ),
                ),
                const SizedBox(height: AppTheme.gapXl),
                if (status != CheckStatus.approved)
                  FilledButton(
                    onPressed: canSubmit && !_busy ? _submit : null,
                    child: Text(
                      locked
                          ? tr('Waiting for our check')
                          : tr('Send for checking'),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.state});

  final MyProviderState state;

  @override
  Widget build(BuildContext context) {
    return switch (state.checkStatus) {
      CheckStatus.pending => InfoBanner(
        tone: Tone.warning,
        icon: Icons.hourglass_top_rounded,
        title: tr('Being checked'),
        message: tr(
          'We usually check documents within one working day. You can keep '
          'bidding meanwhile.',
        ),
      ),
      CheckStatus.approved => InfoBanner(
        tone: Tone.success,
        icon: Icons.verified_rounded,
        title: tr('You are verified'),
        message: tr(
          'Customers see a Verified badge on your bids, and you can withdraw '
          'your earnings.',
        ),
      ),
      CheckStatus.rejected => InfoBanner(
        tone: Tone.danger,
        icon: Icons.error_outline_rounded,
        title: tr('Not passed yet'),
        message: '${tr(state.checkReason)} ${tr('Fix this, then send again.')}',
      ),
      _ when state.verified => InfoBanner(
        tone: Tone.success,
        icon: Icons.verified_rounded,
        title: tr('You are verified'),
        message: tr('Our team checked your identity in person.'),
      ),
      _ => InfoBanner(
        icon: Icons.badge_outlined,
        title: tr('Get the Verified badge'),
        message: tr(
          'Customers choose verified providers more often, and you need it '
          'to withdraw your earnings.',
        ),
      ),
    };
  }
}

class _CardSlot extends ConsumerWidget {
  const _CardSlot({
    required this.label,
    required this.doc,
    required this.onAdd,
  });

  final String label;
  final ProviderDocument? doc;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final d = doc;
    return Semantics(
      button: onAdd != null,
      label: d == null ? tr('Add the {0} photo', [label]) : label,
      child: Material(
        color: context.colors.primaryContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onAdd,
          child: AspectRatio(
            aspectRatio: 1.58,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (d != null)
                  BytesImage(bytes: ref.watch(documentBytesProvider(d.id)))
                else
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        color: context.colors.onPrimaryContainer,
                      ),
                      const SizedBox(height: AppTheme.gapXs),
                      Text(
                        label,
                        style: context.text.labelMedium!.copyWith(
                          color: context.colors.onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                if (d != null)
                  Positioned(
                    left: 6,
                    bottom: 6,
                    child: Pill(
                      label: '$label · ${d.createdAt.shortDate}',
                      tone: Tone.neutral,
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
