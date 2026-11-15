import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/agent_state.dart';
import '../models/conversation.dart';
import '../providers/app_providers.dart';
import '../services/session_service.dart';
import '../widgets/event_bubble.dart';

/// A live conversation. Crucially, opening this screen starts a *global*
/// session; the socket is owned by [SessionService], not by this widget, so
/// leaving the screen (or backgrounding the app) never stops the agent.
class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key, required this.conversation});

  final CloudConversation conversation;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _loadingOlder = false;
  int _lastEventCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = ref.read(sessionServiceProvider);
      service.open(widget.conversation);
      service.markRead(widget.conversation.id);
    });
  }

  @override
  void dispose() {
    // The session is intentionally NOT closed here: the agent keeps running and
    // the socket keeps streaming while the user is elsewhere in the app.
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottomIfNeeded(int count) {
    if (count == _lastEventCount) return;
    _lastEventCount = count;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _loadOlder() async {
    if (_loadingOlder) return;
    setState(() => _loadingOlder = true);
    try {
      await ref.read(sessionServiceProvider).loadOlder(widget.conversation.id);
    } finally {
      if (mounted) setState(() => _loadingOlder = false);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    try {
      await ref.read(sessionServiceProvider).sendMessage(
        widget.conversation.id,
        text,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not send: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(sessionStateProvider(widget.conversation.id));
    final state = sessionState.value ??
        ref
            .read(sessionServiceProvider)
            .stateOf(widget.conversation.id);
    _scrollToBottomIfNeeded(state.events.length);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(state.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              '${state.agentState.label}${state.connected ? '' : ' · offline'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          if (state.agentState == AgentState.running)
            IconButton(
              tooltip: 'Stop',
              onPressed: () =>
                  ref.read(sessionServiceProvider).interrupt(widget.conversation.id),
              icon: const Icon(Icons.stop_circle_outlined),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: state.loadingHistory && state.events.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : NotificationListener<ScrollNotification>(
                    onNotification: (notification) {
                      if (notification.metrics.pixels <= 80) _loadOlder();
                      return false;
                    },
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: state.events.length + (_loadingOlder ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (_loadingOlder && index == 0) {
                          return const Padding(
                            padding: EdgeInsets.all(8),
                            child: Center(child: CircularProgressIndicator()),
                          );
                        }
                        final event =
                            state.events[index - (_loadingOlder ? 1 : 0)];
                        return EventBubble(event: event);
                      },
                    ),
                  ),
          ),
          if (state.error != null)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.errorContainer,
              padding: const EdgeInsets.all(10),
              child: Text(
                state.error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                ),
              ),
            ),
          _Composer(
            controller: _controller,
            onSend: _send,
            enabled: true,
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.onSend,
    required this.enabled,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: 'Message the agent…',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: onSend,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
