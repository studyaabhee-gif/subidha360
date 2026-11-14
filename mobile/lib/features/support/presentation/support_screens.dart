import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/date_extensions.dart';
import '../../../core/l10n/tr.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui.dart';
import '../data/support_api.dart';

/// Help: the helpline, and conversations with the team. Opened from a job, it
/// starts a new conversation about that job.
class HelpScreen extends ConsumerWidget {
  const HelpScreen({this.jobId, super.key});

  final String? jobId;

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final view = await showModalBottomSheet<SupportView>(
      context: context,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => _NewThreadSheet(jobId: jobId),
    );
    if (view == null || !context.mounted) return;
    ref.invalidate(supportThreadsProvider);
    context.push('/help/${view.thread.id}');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threads = ref.watch(supportThreadsProvider);
    final helpline = ref.watch(helplineProvider).value;
    final muted = context.text.bodySmall!.copyWith(
      color: context.palette.muted,
    );
    return Scaffold(
      appBar: AppBar(title: Text(tr('Help and support'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _start(context, ref),
        icon: const Icon(Icons.chat_outlined),
        label: Text(tr('Write to us')),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: RefreshIndicator(
            onRefresh: () => ref.refresh(supportThreadsProvider.future),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppTheme.gapLg,
                AppTheme.gapSm,
                AppTheme.gapLg,
                96,
              ),
              children: [
                if (helpline != null && helpline.phone.isNotEmpty) ...[
                  AppCard(
                    onTap: () => launchUrl(
                      Uri(
                        scheme: 'tel',
                        path: helpline.phone.replaceAll(' ', ''),
                      ),
                    ),
                    child: Row(
                      children: [
                        const IconTile(
                          icon: Icons.call_outlined,
                          tone: Tone.success,
                        ),
                        const SizedBox(width: AppTheme.gapMd),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tr('Call our helpline'),
                                style: context.text.titleSmall,
                              ),
                              Text(
                                helpline.phone,
                                style: context.text.titleMedium,
                              ),
                              if (helpline.hours.isNotEmpty)
                                Text(helpline.hours, style: muted),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: context.palette.muted,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.gapLg),
                ],
                InfoBanner(
                  icon: Icons.shield_outlined,
                  title: tr('In danger right now?'),
                  message: tr('Call the police on 100 first, then tell us.'),
                  tone: Tone.warning,
                ),
                const SizedBox(height: AppTheme.gapXl),
                SectionTitle(tr('Your conversations')),
                switch (threads) {
                  AsyncData(:final value) when value.isEmpty => Text(
                    tr(
                      'Questions about a job, a payment or your account? Write to us and we usually reply within a few hours.',
                    ),
                    style: muted,
                  ),
                  AsyncData(:final value) => Column(
                    children: [
                      for (final t in value)
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppTheme.gapSm,
                          ),
                          child: AppCard(
                            onTap: () => context.push('/help/${t.id}'),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        t.subject,
                                        style: context.text.titleSmall,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        '${tr(supportTopics[t.topic] ?? t.topic)} · ${t.lastMessageAt.timeAgo()}',
                                        style: muted,
                                      ),
                                    ],
                                  ),
                                ),
                                if (t.unreadByUser)
                                  Pill(label: tr('New reply'), tone: Tone.brand)
                                else if (!t.isOpen)
                                  Pill(label: tr('Closed'), tone: Tone.neutral),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  AsyncError(:final error) => Text(
                    ApiException.from(error).message,
                  ),
                  _ => const SkeletonCards(count: 2),
                },
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NewThreadSheet extends ConsumerStatefulWidget {
  const _NewThreadSheet({this.jobId});

  final String? jobId;

  @override
  ConsumerState<_NewThreadSheet> createState() => _NewThreadSheetState();
}

class _NewThreadSheetState extends ConsumerState<_NewThreadSheet> {
  final _form = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _body = TextEditingController();
  late var _topic = widget.jobId == null ? 'other' : 'job';
  var _busy = false;

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final view = await ref
          .read(supportApiProvider)
          .open(
            topic: _topic,
            subject: _subject.text.trim(),
            body: _body.text.trim(),
            jobId: widget.jobId,
          );
      if (mounted) Navigator.pop(context, view);
    } catch (error) {
      if (mounted) context.showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppTheme.gapXl,
        AppTheme.gapXl,
        AppTheme.gapXl,
        AppTheme.gapXl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tr('Write to us'), style: context.text.titleLarge),
              if (widget.jobId != null)
                Text(
                  tr('About this job. Our team can see its details.'),
                  style: context.text.bodySmall!.copyWith(
                    color: context.palette.muted,
                  ),
                ),
              const SizedBox(height: AppTheme.gapLg),
              Wrap(
                spacing: AppTheme.gapSm,
                runSpacing: AppTheme.gapSm,
                children: [
                  for (final e in supportTopics.entries)
                    ChoiceChip(
                      label: Text(tr(e.value)),
                      selected: _topic == e.key,
                      onSelected: (_) => setState(() => _topic = e.key),
                    ),
                ],
              ),
              const SizedBox(height: AppTheme.gapLg),
              TextFormField(
                controller: _subject,
                maxLength: 80,
                decoration: InputDecoration(labelText: tr('Subject')),
                validator: (t) => (t ?? '').trim().length < 3
                    ? tr('Write a few words')
                    : null,
              ),
              const SizedBox(height: AppTheme.gapSm),
              TextFormField(
                controller: _body,
                minLines: 4,
                maxLines: 8,
                maxLength: 2000,
                decoration: InputDecoration(
                  labelText: tr('What happened?'),
                  alignLabelWithHint: true,
                ),
                validator: (t) =>
                    (t ?? '').trim().isEmpty ? tr('Required') : null,
              ),
              const SizedBox(height: AppTheme.gapLg),
              FilledButton(
                onPressed: _busy ? null : _send,
                child: Text(tr('Send')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One conversation with the team. Checks for replies every 15 seconds.
class SupportThreadScreen extends ConsumerStatefulWidget {
  const SupportThreadScreen({required this.id, super.key});

  final String id;

  @override
  ConsumerState<SupportThreadScreen> createState() =>
      _SupportThreadScreenState();
}

class _SupportThreadScreenState extends ConsumerState<SupportThreadScreen> {
  final _input = TextEditingController();
  Timer? _timer;
  var _sending = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => ref.invalidate(supportThreadProvider(widget.id)),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _input.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(supportApiProvider).reply(widget.id, body);
      _input.clear();
      ref.invalidate(supportThreadProvider(widget.id));
      ref.invalidate(supportThreadsProvider);
    } catch (error) {
      if (mounted) context.showError(error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = ref.watch(supportThreadProvider(widget.id));
    final muted = context.text.bodySmall!.copyWith(
      color: context.palette.muted,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(value.value?.thread.subject ?? tr('Help and support')),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              Expanded(
                child: switch (value) {
                  AsyncData(value: (:final thread, :final messages)) =>
                    ListView(
                      padding: const EdgeInsets.all(AppTheme.gapLg),
                      children: [
                        for (final m in messages)
                          Align(
                            alignment: m.fromStaff
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 480),
                              child: Container(
                                margin: const EdgeInsets.only(
                                  bottom: AppTheme.gapSm,
                                ),
                                padding: const EdgeInsets.all(AppTheme.gapMd),
                                decoration: BoxDecoration(
                                  color: m.fromStaff
                                      ? context.colors.surface
                                      : context.colors.primaryContainer,
                                  border: Border.all(
                                    color: context.palette.line,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppTheme.radiusMd,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (m.fromStaff)
                                      Text(
                                        tr('Subidha360 team'),
                                        style: context.text.labelMedium,
                                      ),
                                    Text(m.body),
                                    Text(m.createdAt.timeAgo(), style: muted),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        if (!thread.isOpen)
                          Padding(
                            padding: const EdgeInsets.only(top: AppTheme.gapMd),
                            child: Text(
                              tr(
                                'Our team closed this. Reply if you still need help.',
                              ),
                              style: muted,
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  AsyncError(:final error) => Center(
                    child: Text(ApiException.from(error).message),
                  ),
                  _ => const Center(child: CircularProgressIndicator()),
                },
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.gapMd),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _input,
                          minLines: 1,
                          maxLines: 4,
                          maxLength: 2000,
                          buildCounter: (
                            _, {
                            required currentLength,
                            required isFocused,
                            maxLength,
                          }) => null,
                          decoration: InputDecoration(
                            hintText: tr('Write a message'),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: AppTheme.gapSm),
                      IconButton.filled(
                        tooltip: tr('Send'),
                        onPressed: _sending ? null : _send,
                        icon: const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Lets either side of a job report the other.
Future<void> showReportSheet(BuildContext context, String jobId) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (_) => _ReportSheet(jobId: jobId),
  );
  if (sent == true && context.mounted) {
    context.showMessage(tr('Thank you. Our team will look into it.'));
  }
}

class _ReportSheet extends ConsumerStatefulWidget {
  const _ReportSheet({required this.jobId});

  final String jobId;

  @override
  ConsumerState<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends ConsumerState<_ReportSheet> {
  final _details = TextEditingController();
  String? _reason;
  var _busy = false;

  @override
  void dispose() {
    _details.dispose();
    super.dispose();
  }

  bool get _ready =>
      _reason != null &&
      (_reason != 'other' || _details.text.trim().isNotEmpty);

  Future<void> _send() async {
    setState(() => _busy = true);
    try {
      await ref
          .read(supportApiProvider)
          .report(widget.jobId, _reason!, _details.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) context.showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppTheme.gapXl,
        AppTheme.gapXl,
        AppTheme.gapXl,
        AppTheme.gapXl + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tr('Report a problem'), style: context.text.titleLarge),
            Text(
              tr(
                'Only our team sees this. The other person is not told who reported them.',
              ),
              style: context.text.bodySmall!.copyWith(
                color: context.palette.muted,
              ),
            ),
            const SizedBox(height: AppTheme.gapMd),
            RadioGroup<String>(
              groupValue: _reason,
              onChanged: (v) => setState(() => _reason = v),
              child: Column(
                children: [
                  for (final e in reportReasons.entries)
                    RadioListTile<String>(
                      contentPadding: EdgeInsets.zero,
                      value: e.key,
                      title: Text(tr(e.value)),
                    ),
                ],
              ),
            ),
            TextField(
              controller: _details,
              minLines: 2,
              maxLines: 5,
              maxLength: 500,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: _reason == 'other'
                    ? tr('What happened?')
                    : tr('Anything else? (optional)'),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppTheme.gapLg),
            FilledButton(
              onPressed: _ready && !_busy ? _send : null,
              child: Text(tr('Send report')),
            ),
          ],
        ),
      ),
    );
  }
}
