import 'package:flutter/material.dart';

import '../../core/l10n/tr.dart';
import '../extensions/context_extensions.dart';
import '../theme/app_theme.dart';

class ConfirmSheet extends StatelessWidget {
  const ConfirmSheet({
    required this.title,
    required this.message,
    required this.action,
    this.destructive = false,
    super.key,
  });

  final String title;
  final String message;
  final String action;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
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
            Text(title, style: context.text.headlineSmall),
            const SizedBox(height: AppTheme.gapSm),
            Text(
              message,
              style: context.text.bodyMedium!.copyWith(
                color: context.palette.muted,
              ),
            ),
            const SizedBox(height: AppTheme.gapXl),
            FilledButton(
              style: destructive
                  ? FilledButton.styleFrom(
                      backgroundColor: context.colors.error,
                      foregroundColor: context.colors.onError,
                    )
                  : null,
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
            const SizedBox(height: AppTheme.gapSm),
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr('Not now')),
            ),
          ],
        ),
      ),
    );
  }
}

class TextSheet extends StatefulWidget {
  const TextSheet({
    required this.title,
    required this.message,
    required this.label,
    required this.action,
    this.destructive = false,
    super.key,
  });

  final String title;
  final String message;
  final String label;
  final String action;
  final bool destructive;

  @override
  State<TextSheet> createState() => _TextSheetState();
}

class _TextSheetState extends State<TextSheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: Padding(
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
              Text(widget.title, style: context.text.headlineSmall),
              const SizedBox(height: AppTheme.gapSm),
              Text(
                widget.message,
                style: context.text.bodyMedium!.copyWith(
                  color: context.palette.muted,
                ),
              ),
              const SizedBox(height: AppTheme.gapLg),
              TextField(
                controller: _controller,
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(hintText: widget.label),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppTheme.gapLg),
              FilledButton(
                style: widget.destructive
                    ? FilledButton.styleFrom(
                        backgroundColor: context.colors.error,
                        foregroundColor: context.colors.onError,
                      )
                    : null,
                onPressed: _controller.text.trim().isEmpty
                    ? null
                    : () => Navigator.pop(context, _controller.text.trim()),
                child: Text(widget.action),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
