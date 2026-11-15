import 'dart:async';

import '../config/app_config.dart';
import '../models/agent_state.dart';
import '../models/conversation.dart';
import '../models/conversation_event.dart';
import 'agent_server_client.dart';
import 'event_cache.dart';
import 'notification_service.dart';

/// A message the user sent that has not been accepted by the server yet.
///
/// It is shown immediately as a queued bubble so the composer never blocks and
/// a flaky connection never loses what was typed.
class PendingMessage {
  const PendingMessage({
    required this.id,
    required this.text,
    this.status = PendingStatus.queued,
  });

  final String id;
  final String text;
  final PendingStatus status;

  PendingMessage copyWith({PendingStatus? status}) =>
      PendingMessage(id: id, text: text, status: status ?? this.status);
}

enum PendingStatus { queued, sending, failed }

/// The live state of one conversation, shared by every screen that shows it.
class SessionState {
  const SessionState({
    required this.conversationId,
    this.title = 'Conversation',
    this.events = const [],
    this.pending = const [],
    this.agentState = AgentState.unknown,
    this.connected = false,
    this.loadingHistory = true,
    this.hasOlderHistory = true,
    this.error,
    this.unreadCount = 0,
  });

  final String conversationId;
  final String title;
  final List<ConversationEvent> events;

  /// Messages typed locally and not yet acknowledged by the server.
  final List<PendingMessage> pending;

  final AgentState agentState;
  final bool connected;
  final bool loadingHistory;

  /// Whether the server is believed to hold events older than [events].
  final bool hasOlderHistory;

  final String? error;
  final int unreadCount;

  bool get isBusy =>
      agentState == AgentState.running ||
      pending.any((m) => m.status != PendingStatus.failed);

  SessionState copyWith({
    String? title,
    List<ConversationEvent>? events,
    List<PendingMessage>? pending,
    AgentState? agentState,
    bool? connected,
    bool? loadingHistory,
    bool? hasOlderHistory,
    String? error,
    bool clearError = false,
    int? unreadCount,
  }) {
    return SessionState(
      conversationId: conversationId,
      title: title ?? this.title,
      events: events ?? this.events,
      pending: pending ?? this.pending,
      agentState: agentState ?? this.agentState,
      connected: connected ?? this.connected,
      loadingHistory: loadingHistory ?? this.loadingHistory,
      hasOlderHistory: hasOlderHistory ?? this.hasOlderHistory,
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
  SessionService({EventCache? cache, AgentNotifier? notifications})
    : _cache = cache ?? EventCache(),
      _notifications = notifications ?? NotificationService.instance;

  final EventCache _cache;
  final AgentNotifier _notifications;

  final _controllers = <String, StreamController<SessionState>>{};
  final _clients = <String, AgentServerClient>{};
  final _states = <String, SessionState>{};
  final _reconnectTimers = <String, Timer>{};
  final _cacheTimers = <String, Timer>{};

  /// Conversations whose transcript is already known locally, so the history
  /// endpoint must never be called for them again.
  final _historyKnown = <String>{};

  bool _appInForeground = true;

  /// Current state of every known session.
  Map<String, SessionState> get states => Map.unmodifiable(_states);

  Stream<SessionState> watch(String conversationId) =>
      _controller(conversationId).stream;

  SessionState stateOf(String conversationId) =>
      _states[conversationId] ?? SessionState(conversationId: conversationId);

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

  /// Opens (or reuses) the session for [conversation].
  ///
  /// The transcript is read from disk first and painted immediately. The
  /// history endpoint is only ever called when there is no local copy: once a
  /// conversation has been fetched (in this run or a previous one) its history
  /// is never requested again, and the socket is resumed from the last known
  /// sequence number instead.
  Future<void> open(CloudConversation conversation) async {
    final id = conversation.id;
    _emit(
      stateOf(id).copyWith(
        title: conversation.title,
        loadingHistory: !_historyKnown.contains(id),
        clearError: true,
      ),
    );

    final cached = await _cache.load(id);
    if (cached.isNotEmpty) {
      _emit(
        stateOf(id).copyWith(
          events: cached,
          loadingHistory: false,
          hasOlderHistory: cached.length >= AppConfig.historyPageSize,
        ),
      );
      // A local transcript is authoritative: never ask the server for it.
      _historyKnown.add(id);
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
          unawaited(_flushPending(id, created));
        } else {
          _scheduleReconnect(id, created);
        }
      });
      client = created;
    }
    final activeClient = client;

    if (!_historyKnown.contains(id)) {
      try {
        final page = await activeClient.fetchHistory();
        _emit(
          stateOf(id).copyWith(
            events: page.events,
            loadingHistory: false,
            hasOlderHistory: page.hasMore,
            clearError: true,
          ),
        );
        await _cache.save(id, page.events);
        _historyKnown.add(id);
      } catch (error) {
        if (cached.isEmpty) {
          _emit(stateOf(id).copyWith(loadingHistory: false, error: '$error'));
        }
      }
    }

    try {
      await activeClient.connect();
    } catch (error) {
      _emit(stateOf(id).copyWith(error: 'Could not reach the sandbox: $error'));
    }
    await _refreshAgentState(id, activeClient);
    unawaited(_flushPending(id, activeClient));
  }

  /// Reopens a dropped socket with a bounded backoff. The cursor is the last
  /// durable seq we saw, so the server replays exactly what we missed and the
  /// UI never has to reload the whole history.
  void _scheduleReconnect(String conversationId, AgentServerClient client) {
    if (_reconnectTimers.containsKey(conversationId)) return;
    var attempt = 0;
    void schedule() {
      attempt++;
      final delay = Duration(seconds: (2 * attempt).clamp(2, 30));
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
    // A reconnect can replay the tail we already have; drop anything we have
    // already shown so the transcript never doubles up.
    if (current.events.any((existing) => existing.id == event.id)) return;
    final events = [...current.events, event];
    final nextState = _stateFromEvent(current, event);
    // A real event from the user means the queued copy was accepted.
    final pending = event.isUserMessage
        ? current.pending.where((m) => m.text != event.text).toList()
        : current.pending;
    final unread = _appInForeground
        ? current.unreadCount
        : current.unreadCount + 1;
    _emit(
      nextState.copyWith(events: events, pending: pending, unreadCount: unread),
    );
    _persist(conversationId, events);
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
        stateOf(
          conversationId,
        ).copyWith(agentState: AgentState.fromStatus(status)),
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

  /// Queues [text] and sends it. The bubble appears instantly; if the socket
  /// is down the message stays queued and goes out as soon as it is back.
  Future<void> sendMessage(String conversationId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final current = stateOf(conversationId);
    final message = PendingMessage(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      text: trimmed,
    );
    _emit(
      current.copyWith(
        pending: [...current.pending, message],
        agentState: AgentState.running,
        clearError: true,
      ),
    );
    final client = _clients[conversationId];
    if (client != null) await _flushPending(conversationId, client);
  }

  /// Retries everything still queued, used by the "Retry" affordance on a
  /// failed bubble.
  Future<void> retryPending(String conversationId) async {
    final client = _clients[conversationId];
    if (client == null) return;
    final state = stateOf(conversationId);
    _emit(
      state.copyWith(
        pending: state.pending
            .map((m) => m.copyWith(status: PendingStatus.queued))
            .toList(),
      ),
    );
    await _flushPending(conversationId, client);
  }

  Future<void> _flushPending(
    String conversationId,
    AgentServerClient client,
  ) async {
    var state = stateOf(conversationId);
    final outstanding = state.pending
        .where((m) => m.status != PendingStatus.sending)
        .toList();
    for (final message in outstanding) {
      state = stateOf(conversationId);
      final index = state.pending.indexWhere((m) => m.id == message.id);
      if (index < 0) continue;
      final sending = [...state.pending];
      sending[index] = message.copyWith(status: PendingStatus.sending);
      _emit(state.copyWith(pending: sending));
      try {
        await client.sendMessage(message.text);
        final after = stateOf(conversationId);
        _emit(
          after.copyWith(
            pending: after.pending.where((m) => m.id != message.id).toList(),
          ),
        );
      } catch (error) {
        final after = stateOf(conversationId);
        _emit(
          after.copyWith(
            pending: after.pending
                .map(
                  (m) => m.id == message.id
                      ? m.copyWith(status: PendingStatus.failed)
                      : m,
                )
                .toList(),
            error: 'Could not send: $error',
          ),
        );
        return;
      }
    }
  }

  Future<void> interrupt(String conversationId) async {
    await _clients[conversationId]?.interrupt();
  }

  /// Fetches the page before the oldest known event. Only ever called because
  /// the user explicitly scrolled up.
  Future<HistoryPage> loadOlder(String conversationId) async {
    final client = _clients[conversationId];
    final current = stateOf(conversationId);
    if (client == null || current.events.isEmpty) {
      return const HistoryPage(events: [], hasMore: false);
    }
    if (!current.hasOlderHistory) {
      return const HistoryPage(events: [], hasMore: false);
    }
    final oldest = current.events.first.timestamp?.toIso8601String();
    if (oldest == null) return const HistoryPage(events: [], hasMore: false);
    final page = await client.fetchOlder(beforeTimestamp: oldest);
    if (page.events.isNotEmpty) {
      final merged = _dedupe([...page.events, ...current.events]);
      _emit(
        stateOf(conversationId).copyWith(
          events: merged,
          hasOlderHistory: page.hasMore,
        ),
      );
      _persist(conversationId, merged);
    } else {
      _emit(stateOf(conversationId).copyWith(hasOlderHistory: false));
    }
    return page;
  }

  List<ConversationEvent> _dedupe(List<ConversationEvent> events) {
    final seen = <String>{};
    final result = <ConversationEvent>[];
    for (final event in events) {
      if (seen.add(event.id)) result.add(event);
    }
    return result;
  }

  /// Writes the transcript to disk, coalescing bursts of events into one write
  /// so a fast-streaming agent does not hammer the filesystem.
  void _persist(String conversationId, List<ConversationEvent> events) {
    _cacheTimers[conversationId]?.cancel();
    _cacheTimers[conversationId] = Timer(const Duration(milliseconds: 400), () {
      _cacheTimers.remove(conversationId);
      unawaited(_cache.save(conversationId, events));
    });
  }

  void markRead(String conversationId) {
    _emit(stateOf(conversationId).copyWith(unreadCount: 0));
  }

  /// Forgets a conversation: drops the socket, the in-memory state and, when
  /// [forget] is set, the on-disk transcript.
  Future<void> close(String conversationId, {bool forget = false}) async {
    _reconnectTimers.remove(conversationId)?.cancel();
    _cacheTimers.remove(conversationId)?.cancel();
    await _clients.remove(conversationId)?.dispose();
    await _controllers.remove(conversationId)?.close();
    _states.remove(conversationId);
    _historyKnown.remove(conversationId);
    if (forget) await _cache.clear(conversationId);
  }

  Future<void> disposeAll() async {
    for (final timer in _reconnectTimers.values) {
      timer.cancel();
    }
    _reconnectTimers.clear();
    // Flush any pending transcript write before tearing down.
    for (final entry in _cacheTimers.entries) {
      entry.value.cancel();
      final events = _states[entry.key]?.events;
      if (events != null) await _cache.save(entry.key, events);
    }
    _cacheTimers.clear();
    for (final client in _clients.values) {
      await client.dispose();
    }
    _clients.clear();
    for (final controller in _controllers.values) {
      await controller.close();
    }
    _controllers.clear();
    _states.clear();
    _historyKnown.clear();
  }
}
