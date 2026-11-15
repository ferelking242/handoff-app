import 'dart:async';

import '../models/agent_state.dart';
import '../models/conversation.dart';
import '../models/conversation_event.dart';
import 'agent_server_client.dart';
import 'event_cache.dart';
import 'notification_service.dart';

/// The live state of one conversation, shared by every screen that shows it.
class SessionState {
  const SessionState({
    required this.conversationId,
    this.title = 'Conversation',
    this.events = const [],
    this.agentState = AgentState.unknown,
    this.connected = false,
    this.loadingHistory = true,
    this.error,
    this.unreadCount = 0,
  });

  final String conversationId;
  final String title;
  final List<ConversationEvent> events;
  final AgentState agentState;
  final bool connected;
  final bool loadingHistory;
  final String? error;
  final int unreadCount;

  SessionState copyWith({
    String? title,
    List<ConversationEvent>? events,
    AgentState? agentState,
    bool? connected,
    bool? loadingHistory,
    String? error,
    bool clearError = false,
    int? unreadCount,
  }) {
    return SessionState(
      conversationId: conversationId,
      title: title ?? this.title,
      events: events ?? this.events,
      agentState: agentState ?? this.agentState,
      connected: connected ?? this.connected,
      loadingHistory: loadingHistory ?? this.loadingHistory,
      error: clearError ? null : (error ?? this.error),
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

/// Owns every live conversation session for the whole app lifetime.
///
/// This is the central fix. In the Canvas the WebSocket is tied to the
/// conversation screen, so leaving the screen (or backgrounding the tab)
/// drops the connection and the agent appears to "stop". Here sessions live in
/// a long-lived service that no screen owns: navigating away, or putting the
/// app in the background, leaves the socket connected and events flowing.
class SessionService {
  SessionService({
    EventCache? cache,
    NotificationService? notifications,
  }) : _cache = cache ?? EventCache(),
       _notifications = notifications ?? NotificationService.instance;

  final EventCache _cache;
  final NotificationService _notifications;

  final _controllers = <String, StreamController<SessionState>>{};
  final _clients = <String, AgentServerClient>{};
  final _states = <String, SessionState>{};
  final _reconnectTimers = <String, Timer>{};
  bool _appInForeground = true;

  /// Current state of every known session.
  Map<String, SessionState> get states => Map.unmodifiable(_states);

  Stream<SessionState> watch(String conversationId) {
    final controller = _controller(conversationId);
    return controller.stream;
  }

  SessionState stateOf(String conversationId) =>
      _states[conversationId] ??
      SessionState(conversationId: conversationId);

  StreamController<SessionState> _controller(String conversationId) {
    return _controllers.putIfAbsent(conversationId, () {
      late final StreamController<SessionState> controller;
      controller = StreamController<SessionState>.broadcast(
        onListen: () {
          final current = _states[conversationId];
          if (current != null) controller.add(current);
        },
      );
      return controller;
    });
  }

  void _emit(SessionState state) {
    _states[state.conversationId] = state;
    _controllers[state.conversationId]?.add(state);
  }

  /// Called by the app lifecycle observer. When the app goes to the
  /// background the sockets stay up on purpose: that is what makes the
  /// "agent keeps working" and "notify me when done" behaviour possible.
  void setForeground(bool foreground) {
    _appInForeground = foreground;
  }

  /// Opens (or reuses) the session for [conversation]: loads the cached
  /// history immediately, then reconciles with the server and connects the
  /// socket. Idempotent, so any screen can call it freely.
  Future<void> open(CloudConversation conversation) async {
    final id = conversation.id;
    _emit(
      stateOf(id).copyWith(
        title: conversation.title,
        loadingHistory: true,
        clearError: true,
      ),
    );

    final cached = await _cache.load(id);
    if (cached.isNotEmpty) {
      _emit(stateOf(id).copyWith(events: cached, loadingHistory: false));
    }

    final baseUrl = conversation.agentServerBaseUrl;
    final key = conversation.sessionApiKey;
    if (baseUrl == null || key == null || key.isEmpty) {
      _emit(
        stateOf(id).copyWith(
          loadingHistory: false,
          error: 'This conversation has no reachable sandbox yet.',
        ),
      );
      return;
    }

    var client = _clients[id];
    if (client == null ||
        client.baseUrl != baseUrl ||
        client.sessionApiKey != key) {
      await client?.dispose();
      final created = AgentServerClient(
        baseUrl: baseUrl,
        sessionApiKey: key,
        conversationId: id,
      );
      _clients[id] = created;
      created.events.listen((event) => _onEvent(id, event));
      created.connectionState.listen((connected) {
        _emit(stateOf(id).copyWith(connected: connected));
        if (connected) {
          _reconnectTimers.remove(id)?.cancel();
        } else {
          _scheduleReconnect(id, created);
        }
      });
      client = created;
    }
    final activeClient = client;

    try {
      final page = await activeClient.fetchHistory();
      _emit(
        stateOf(id).copyWith(
          events: page.events,
          loadingHistory: false,
          clearError: true,
        ),
      );
      await _cache.save(id, page.events);
    } catch (error) {
      if (cached.isEmpty) {
        _emit(stateOf(id).copyWith(loadingHistory: false, error: '$error'));
      }
    }

    await activeClient.connect();
    await _refreshAgentState(id, activeClient);
  }

  /// Reopens a dropped socket with a bounded backoff. The cursor is the last
  /// durable seq we saw, so the server replays exactly what we missed and the
  /// UI never has to reload the whole history.
  void _scheduleReconnect(String conversationId, AgentServerClient client) {
    if (_reconnectTimers.containsKey(conversationId)) return;
    var attempt = 0;
    void schedule() {
      attempt++;
      final delay = Duration(
        seconds: (2 * attempt).clamp(2, 30),
      );
      _reconnectTimers[conversationId] = Timer(delay, () async {
        _reconnectTimers.remove(conversationId);
        if (!_clients.containsKey(conversationId)) return;
        try {
          await client.connect(afterSeq: client.lastSeq);
        } catch (_) {
          if (attempt < 10) schedule();
        }
      });
    }
    schedule();
  }

  void _onEvent(String conversationId, ConversationEvent event) {
    final current = stateOf(conversationId);
    final events = [...current.events, event];
    final nextState = _stateFromEvent(current, event);
    final unread = _appInForeground ? current.unreadCount : current.unreadCount + 1;
    _emit(nextState.copyWith(events: events, unreadCount: unread));
    unawaited(_cache.save(conversationId, events));
    _maybeNotify(conversationId, current.agentState, nextState.agentState);
  }

  /// Derives the agent state from an event, covering both the explicit
  /// state-update event and the implicit "agent produced output" signal.
  SessionState _stateFromEvent(SessionState current, ConversationEvent event) {
    if (event.isStateUpdate) {
      final key = event.raw['key'] as String?;
      final value = event.raw['value'];
      if (key == 'execution_status' && value is String) {
        return current.copyWith(agentState: AgentState.fromStatus(value));
      }
    }
    if (event.isError) {
      return current.copyWith(agentState: AgentState.error);
    }
    if (event.isAssistantMessage || event.isAction || event.isObservation) {
      return current.copyWith(agentState: AgentState.running);
    }
    return current;
  }

  Future<void> _refreshAgentState(
    String conversationId,
    AgentServerClient client,
  ) async {
    try {
      final record = await client.fetchConversation();
      final status = record['execution_status'] as String?;
      _emit(
        stateOf(conversationId).copyWith(agentState: AgentState.fromStatus(status)),
      );
    } catch (_) {
      // Non-fatal: the socket will keep the state fresh.
    }
  }

  void _maybeNotify(
    String conversationId,
    AgentState previous,
    AgentState next,
  ) {
    if (previous == next) return;
    if (!next.needsAttention) return;
    // Only notify when the app is not in front of the user, so we never buzz
    // while they are already reading the conversation.
    if (_appInForeground) return;
    final title = stateOf(conversationId).title;
    final body = switch (next) {
      AgentState.awaitingUserInput => 'The agent is waiting for your reply.',
      AgentState.awaitingConfirmation => 'The agent needs your confirmation.',
      AgentState.finished => 'The agent finished the task.',
      AgentState.error => 'The agent hit an error.',
      _ => next.label,
    };
    unawaited(
      _notifications.showAgentState(
        conversationId: conversationId,
        title: title,
        body: body,
      ),
    );
  }

  Future<void> sendMessage(String conversationId, String text) async {
    final client = _clients[conversationId];
    if (client == null) throw StateError('Session is not open.');
    _emit(stateOf(conversationId).copyWith(agentState: AgentState.running));
    await client.sendMessage(text);
  }

  Future<void> interrupt(String conversationId) async {
    await _clients[conversationId]?.interrupt();
  }

  Future<HistoryPage> loadOlder(String conversationId) async {
    final client = _clients[conversationId];
    final current = stateOf(conversationId);
    if (client == null || current.events.isEmpty) {
      return const HistoryPage(events: [], hasMore: false);
    }
    final oldest = current.events.first.timestamp?.toIso8601String();
    if (oldest == null) return const HistoryPage(events: [], hasMore: false);
    final page = await client.fetchOlder(beforeTimestamp: oldest);
    if (page.events.isNotEmpty) {
      _emit(current.copyWith(events: [...page.events, ...current.events]));
    }
    return page;
  }

  void markRead(String conversationId) {
    _emit(stateOf(conversationId).copyWith(unreadCount: 0));
  }

  Future<void> close(String conversationId) async {
    _reconnectTimers.remove(conversationId)?.cancel();
    await _clients.remove(conversationId)?.dispose();
    await _controllers.remove(conversationId)?.close();
    _states.remove(conversationId);
  }

  Future<void> disposeAll() async {
    for (final timer in _reconnectTimers.values) {
      timer.cancel();
    }
    _reconnectTimers.clear();
    for (final client in _clients.values) {
      await client.dispose();
    }
    _clients.clear();
    for (final controller in _controllers.values) {
      await controller.close();
    }
    _controllers.clear();
    _states.clear();
  }
}
