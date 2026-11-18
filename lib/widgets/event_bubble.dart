import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme/app_theme.dart';
import '../models/conversation_event.dart';
import 'markdown_content.dart';

/// Renders one event of the transcript.
///
/// Agent prose is rendered as selectable Markdown; tool events remain compact
/// until the user expands their details.
class EventBubble extends StatelessWidget {
  const EventBubble({super.key, required this.event, this.animateIn = true});

  final ConversationEvent event;
  final bool animateIn;

  @override
  Widget build(BuildContext context) {
    final child = _build(context);
    if (child == null) return const SizedBox.shrink();
    final widget = Padding(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
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
      return _UserBubble(event: event);
    }
    if (event.isAssistantMessage) {
      return _AssistantBubble(event: event);
    }
    if (event.isAction) {
      return _ToolCard(
        title: event.toolName ?? 'Action',
        subtitle: 'Action',
        body: _pretty(event.action),
        icon: LucideIcons.play,
        accent: AppColors.accentBright,
      );
    }
    if (event.isObservation) {
      return _ToolCard(
        title: event.toolName ?? 'Result',
        subtitle: 'Result',
        body: _pretty(event.observation),
        icon: LucideIcons.terminal,
        accent: AppColors.success,
      );
    }
    if (event.isError) {
      return _ToolCard(
        title: 'Error',
        subtitle: 'Error',
        body: event.text.isEmpty ? _pretty(event.raw) : event.text,
        icon: LucideIcons.circleAlert,
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
  const _UserBubble({required this.event});

  final ConversationEvent event;

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
            color: AppColors.surfaceHigher,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppRadius.lg),
              topRight: Radius.circular(AppRadius.lg),
              bottomLeft: Radius.circular(AppRadius.lg),
              bottomRight: Radius.circular(AppRadius.md),
            ),
            border: Border.all(
              color: theme.colorScheme.outlineVariant,
              width: 0.8,
            ),
          ),
          child: SelectableText(
            event.text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
              height: 1.4,
            ),
          ),
        ),
      ),
    );
  }
}

class _AssistantBubble extends StatefulWidget {
  const _AssistantBubble({required this.event});

  final ConversationEvent event;

  @override
  State<_AssistantBubble> createState() => _AssistantBubbleState();
}

class _AssistantBubbleState extends State<_AssistantBubble> {
  bool _copied = false;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: widget.event.text));
    if (mounted) setState(() => _copied = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _AgentAvatar(),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'OpenHands',
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (widget.event.timestamp != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          DateFormat(
                            'MMM d · HH:mm',
                          ).format(widget.event.timestamp!.toLocal()),
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 7),
                  MarkdownContent(data: widget.event.text),
                  if (widget.event.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: _copy,
                        tooltip: _copied ? 'Copied' : 'Copy response',
                        visualDensity: VisualDensity.compact,
                        constraints: const BoxConstraints.tightFor(
                          width: 36,
                          height: 36,
                        ),
                        padding: EdgeInsets.zero,
                        icon: Icon(
                          _copied ? LucideIcons.check : LucideIcons.copy,
                          size: 16,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AgentAvatar extends StatelessWidget {
  const _AgentAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.accent.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: const Icon(
        LucideIcons.bot,
        size: 16,
        color: AppColors.accentBright,
      ),
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
          color: theme.colorScheme.surface.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: border.withValues(alpha: 0.9), width: 0.8),
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
                      child: Icon(widget.icon, size: 14, color: widget.accent),
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
                        _expanded
                            ? LucideIcons.chevronUp
                            : LucideIcons.chevronDown,
                        size: 16,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              alignment: Alignment.topCenter,
              child: _expanded
                  ? Padding(
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
                                _copied ? LucideIcons.check : LucideIcons.copy,
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
                    )
                  : const SizedBox.shrink(),
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
