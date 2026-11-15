import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../models/conversation_event.dart';

/// Renders one conversation event in the transcript.
class EventBubble extends StatelessWidget {
  const EventBubble({super.key, required this.event});

  final ConversationEvent event;

  @override
  Widget build(BuildContext context) {
    if (event.isUserMessage) {
      return _Bubble(
        alignment: Alignment.centerRight,
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Text(event.text),
      );
    }
    if (event.isAssistantMessage) {
      return _Bubble(
        alignment: Alignment.centerLeft,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Text(event.text),
      );
    }
    if (event.isAction) {
      return _ToolCard(
        title: 'Action · ${event.toolName ?? 'tool'}',
        body: _pretty(event.action),
        icon: Icons.play_circle_outline,
      );
    }
    if (event.isObservation) {
      return _ToolCard(
        title: 'Result · ${event.toolName ?? 'tool'}',
        body: _pretty(event.observation),
        icon: Icons.terminal,
      );
    }
    if (event.isError) {
      return _ToolCard(
        title: 'Error',
        body: event.text.isEmpty ? _pretty(event.raw) : event.text,
        icon: Icons.error_outline,
        isError: true,
      );
    }
    if (event.isStateUpdate) {
      return const SizedBox.shrink();
    }
    return const SizedBox.shrink();
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

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.alignment,
    required this.color,
    required this.child,
  });

  final Alignment alignment;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: DefaultTextStyle.merge(
          style: Theme.of(context).textTheme.bodyMedium ?? const TextStyle(),
          child: child,
        ),
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.title,
    required this.body,
    required this.icon,
    this.isError = false,
  });

  final String title;
  final String body;
  final IconData icon;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: isError ? theme.colorScheme.errorContainer : null,
      child: Theme(
        data: theme.copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Icon(icon),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                body,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
