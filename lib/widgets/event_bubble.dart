import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_ui/material_ui.dart';

import '../core/icon_fonts/app_icons.dart';
import '../core/theme/app_theme.dart';
import '../models/conversation_event.dart';

/// Renders one event of the transcript.
///
/// Assistant prose is rendered as plain text with generous line height (the
/// ChatGPT reading experience); tool calls collapse into a compact card the
/// user can open when they care.
class EventBubble extends StatelessWidget {
  const EventBubble({super.key, required this.event, this.animateIn = true});

  final ConversationEvent event;
  final bool animateIn;

  @override
  Widget build(BuildContext context) {
    final child = _build(context);
    if (child == null) return const SizedBox.shrink();
    final widget = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: child,
    );
    if (!animateIn) return widget;
    return widget
        .animate()
        .fadeIn(duration: 220.ms)
        .slideY(begin: 0.06, end: 0, duration: 220.ms, curve: Curves.easeOut);
  }

  Widget? _build(BuildContext context) {
    if (event.isUserMessage) {
      return _UserBubble(text: event.text);
    }
    if (event.isAssistantMessage) {
      return _AssistantBubble(text: event.text);
    }
    if (event.isAction) {
      return _ToolCard(
        title: event.toolName ?? 'Action',
        subtitle: 'Action',
        body: _pretty(event.action),
        icon: AppIcons.play,
        accent: AppColors.accentBright,
      );
    }
    if (event.isObservation) {
      return _ToolCard(
        title: event.toolName ?? 'Result',
        subtitle: 'Result',
        body: _pretty(event.observation),
        icon: AppIcons.terminal,
        accent: AppColors.success,
      );
    }
    if (event.isError) {
      return _ToolCard(
        title: 'Error',
        subtitle: 'Error',
        body: event.text.isEmpty ? _pretty(event.raw) : event.text,
        icon: AppIcons.danger,
        accent: AppColors.danger,
      );
    }
    if (event.isStateUpdate) return null;
    return null;
  }

  static String _pretty(Map<String, dynamic> value) {
    if (value.isEmpty) return '';
    try {
      return const JsonEncoder.withIndent('  ').convert(value);
    } catch (_) {
      return value.toString();
    }
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: AppColors.accentGradient,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppRadius.lg),
              topRight: Radius.circular(AppRadius.lg),
              bottomLeft: Radius.circular(AppRadius.lg),
              bottomRight: Radius.circular(6),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.accent.withValues(alpha: 0.25),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: SelectableText(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  const _AssistantBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _AgentAvatar(),
            const SizedBox(width: 10),
            Flexible(
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: SelectableText(
                  text,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgentAvatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(9),
      ),
      alignment: Alignment.center,
      child: const Icon(AppIcons.flash, size: 15, color: AppColors.accentBright),
    );
  }
}

/// A collapsible tool call / result card with a copy button.
class _ToolCard extends StatefulWidget {
  const _ToolCard({
    required this.title,
    required this.subtitle,
    required this.body,
    required this.icon,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final String body;
  final IconData icon;
  final Color accent;

  @override
  State<_ToolCard> createState() => _ToolCardState();
}

class _ToolCardState extends State<_ToolCard> {
  bool _expanded = false;
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final border = theme.colorScheme.outlineVariant;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 680),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(
            alpha: 0.5,
          ),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: widget.body.isEmpty
                  ? null
                  : () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: widget.accent.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        widget.icon,
                        size: 14,
                        color: widget.accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                          Text(
                            widget.subtitle,
                            style: theme.textTheme.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    if (widget.body.isNotEmpty)
                      Icon(
                        _expanded ? AppIcons.arrowUp : AppIcons.arrowDown,
                        size: 15,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                  ],
                ),
              ),
            ),
            if (_expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        border: Border.all(color: border),
                      ),
                      child: SelectableText(
                        widget.body,
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 11.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: _copy,
                        icon: Icon(
                          _copied ? AppIcons.copySuccess : AppIcons.copy,
                          size: 14,
                        ),
                        label: Text(_copied ? 'Copied' : 'Copy'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.body));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }
}
