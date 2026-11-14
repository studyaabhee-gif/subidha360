import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/tr.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/extensions/date_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui.dart';
import '../../auth/providers/auth_controller.dart';
import '../data/job_repository.dart';
import '../domain/chat_message.dart';
import '../providers/job_providers.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({required this.jobId, super.key});

  static const refreshEvery = Duration(seconds: 5);

  final String jobId;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  Timer? _timer;
  var _sending = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      ChatScreen.refreshEvery,
      (_) => ref.invalidate(jobMessagesProvider(widget.jobId)),
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
      await ref.read(jobRepositoryProvider).sendMessage(widget.jobId, body);
      _input.clear();
      ref.invalidate(jobMessagesProvider(widget.jobId));
    } catch (error) {
      if (mounted) context.showError(error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(jobMessagesProvider(widget.jobId));
    final job = ref.watch(jobDetailProvider(widget.jobId)).value;
    final me = ref.watch(authControllerProvider).value?.id;
    final open = job?.status.chatOpen ?? false;
    final rows = messages.value ?? <ChatMessage>[];

    return Scaffold(
      appBar: AppBar(title: Text(tr('Messages'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              Expanded(
                child: rows.isEmpty
                    ? Center(
                        child: EmptyState(
                          icon: Icons.chat_bubble_outline_rounded,
                          title: tr('No messages yet'),
                          message: tr(
                            'Share gate codes, directions or arrival times.',
                          ),
                        ),
                      )
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(AppTheme.gapLg),
                        itemCount: rows.length,
                        itemBuilder: (context, i) {
                          final message = rows[rows.length - 1 - i];
                          return _Bubble(
                            message: message,
                            mine: message.senderId == me,
                          );
                        },
                      ),
              ),
              if (open)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    border: Border(
                      top: BorderSide(color: context.palette.line),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.gapSm),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _input,
                              minLines: 1,
                              maxLines: 4,
                              textCapitalization: TextCapitalization.sentences,
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
                )
              else
                Padding(
                  padding: const EdgeInsets.all(AppTheme.gapLg),
                  child: Text(
                    tr('This job has finished, so messaging is closed.'),
                    style: context.text.bodySmall!.copyWith(
                      color: context.palette.muted,
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

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.mine});

  final ChatMessage message;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final foreground = mine ? colors.onPrimary : colors.onSurface;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.75,
        ),
        margin: const EdgeInsets.only(bottom: AppTheme.gapSm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.gapMd + 2,
          vertical: AppTheme.gapSm + 2,
        ),
        decoration: BoxDecoration(
          color: mine ? colors.primary : colors.surface,
          border: mine ? null : Border.all(color: context.palette.line),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.body,
              style: context.text.bodyMedium!.copyWith(color: foreground),
            ),
            const SizedBox(height: 2),
            Text(
              message.createdAt.timeAgo(),
              style: context.text.labelSmall!.copyWith(
                color: foreground.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
