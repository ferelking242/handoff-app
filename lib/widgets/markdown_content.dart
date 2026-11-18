import 'package:flutter/material.dart' as flutter;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/theme/app_theme.dart';

/// Accessible GitHub-flavoured Markdown for agent replies.
class MarkdownContent extends StatelessWidget {
  const MarkdownContent({super.key, required this.data});

  final String data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final base = MarkdownStyleSheet.fromTheme(
      flutter.ThemeData(
        brightness: theme.brightness,
        textTheme: const flutter.TextTheme(
          bodyMedium: flutter.TextStyle(fontSize: 14),
        ),
        useMaterial3: true,
      ),
    );

    return MarkdownBody(
      data: data,
      selectable: true,
      styleSheet: base.copyWith(
        p: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
        h1: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          height: 1.25,
        ),
        h2: theme.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
        h3: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
        code: theme.textTheme.bodyMedium?.copyWith(
          fontFamily: 'monospace',
          fontSize: 13,
          color: AppColors.accentBright,
          backgroundColor: AppColors.surfaceHigh,
        ),
        codeblockPadding: const EdgeInsets.all(12),
        codeblockDecoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: colors.outlineVariant),
        ),
        blockquote: theme.textTheme.bodyMedium?.copyWith(
          color: colors.onSurfaceVariant,
          height: 1.5,
        ),
        blockquotePadding: const EdgeInsets.fromLTRB(12, 4, 0, 4),
        blockquoteDecoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: colors.primary.withValues(alpha: 0.72),
              width: 3,
            ),
          ),
        ),
        a: TextStyle(
          color: colors.primary,
          decoration: TextDecoration.underline,
          decorationColor: colors.primary.withValues(alpha: 0.65),
        ),
      ),
      onTapLink: (text, href, title) async {
        final uri = Uri.tryParse(href ?? '');
        if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
          return;
        }
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      },
    );
  }
}
