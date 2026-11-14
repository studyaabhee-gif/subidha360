import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/l10n/tr.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui.dart';

/// The API's size limit for any upload.
const maxUploadBytes = 5 * 1024 * 1024;

/// Opens the photo library for one picture, shrunk enough to upload quickly
/// on mobile data. Null if the person cancels or the photo is too large.
Future<Uint8List?> pickOnePhoto(BuildContext context) async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 2000,
    imageQuality: 85,
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  if (bytes.length > maxUploadBytes) {
    if (context.mounted) {
      context.showMessage(tr('Photos can be up to 5 MB. Try a smaller one.'));
    }
    return null;
  }
  return bytes;
}

/// A centred, width-limited page with an app bar, for the provider tools.
class ToolPage extends StatelessWidget {
  const ToolPage({
    required this.title,
    required this.children,
    this.onRefresh,
    this.bottom,
    super.key,
  });

  final String title;
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    Widget list = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppTheme.gapLg,
        AppTheme.gapSm,
        AppTheme.gapLg,
        AppTheme.gapXxl,
      ),
      children: children,
    );
    if (onRefresh != null) {
      list = RefreshIndicator(onRefresh: onRefresh!, child: list);
    }
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      bottomNavigationBar: bottom,
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: list,
        ),
      ),
    );
  }
}

/// Loading and error states shared by the provider tools.
class ToolAsync<T> extends StatelessWidget {
  const ToolAsync({
    required this.value,
    required this.onRetry,
    required this.builder,
    super.key,
  });

  final AsyncValue<T> value;
  final VoidCallback onRetry;
  final Widget Function(T) builder;

  @override
  Widget build(BuildContext context) {
    return value.when(
      skipLoadingOnRefresh: true,
      skipLoadingOnReload: true,
      data: builder,
      loading: () => const SkeletonCards(count: 2),
      error: (error, _) => EmptyState(
        icon: Icons.cloud_off_rounded,
        title: tr("Couldn't load this"),
        message: ApiException.from(error).message,
        action: OutlinedButton(
          onPressed: onRetry,
          child: Text(tr('Try again')),
        ),
      ),
    );
  }
}

/// Shows bytes from the API as a picture, with a placeholder while loading.
class BytesImage extends StatelessWidget {
  const BytesImage({required this.bytes, this.fit = BoxFit.cover, super.key});

  final AsyncValue<Uint8List> bytes;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return switch (bytes) {
      AsyncData(:final value) => Image.memory(
        value,
        fit: fit,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) =>
            const _Placeholder(Icons.broken_image_outlined),
      ),
      AsyncError() => const _Placeholder(Icons.broken_image_outlined),
      _ => const _Placeholder(Icons.image_outlined),
    };
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder(this.icon);

  final IconData icon;

  @override
  Widget build(BuildContext context) => ColoredBox(
    color: context.palette.skeleton,
    child: Center(child: Icon(icon, color: context.palette.muted)),
  );
}
