import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import '../models/openhands_models.dart';
import '../services/openhands_api.dart';
import '../services/openhands_store.dart';

enum OpenHandsAuthStatus { loading, signedOut, signingIn, signedIn, error }

/// Owns the OpenHands session, the conversation list and the open timeline.
class OpenHandsProvider extends ChangeNotifier {
  OpenHandsProvider({OpenHandsStore? store, OpenHandsApi? api})
      : _store = store ?? OpenHandsStore(),
        _api = api ?? OpenHandsApi();

  final OpenHandsStore _store;
  final OpenHandsApi _api;

  OpenHandsAuthStatus _authStatus = OpenHandsAuthStatus.loading;
  OpenHandsAuthStatus get authStatus => _authStatus;

  OpenHandsUser? _user;
  OpenHandsUser? get user => _user;

  String? _error;
  String? get error => _error;

  String? _deviceNotice;
  String? get deviceNotice => _deviceNotice;

  String get baseUrl => _api.baseUrl;

  String get apiKeysUrl => '$baseUrl/settings/api-keys';

  List<OpenHandsConversation> _conversations = const [];
  List<OpenHandsConversation> get conversations => _conversations;

  bool _conversationsLoading = false;
  bool get conversationsLoading => _conversationsLoading;

  String? _conversationsError;
  String? get conversationsError => _conversationsError;

  String? _nextPageId;
  bool get hasMoreConversations => _nextPageId != null;

  OpenHandsConversation? _active;
  OpenHandsConversation? get active => _active;

  List<HandoffTimelineItem> _timeline = const [];
  List<HandoffTimelineItem> get timeline => _timeline;

  bool _timelineLoading = false;
  bool get timelineLoading => _timelineLoading;

  String? _timelineError;
  String? get timelineError => _timelineError;

  bool _sending = false;
  bool get sending => _sending;

  bool _creating = false;
  bool get creating => _creating;

  DeviceCode? _deviceCode;
  DeviceCode? get deviceCode => _deviceCode;

  bool _devicePolling = false;
  bool get devicePolling => _devicePolling;

  GuardConfig _guard = const GuardConfig();
  GuardConfig get guard => _guard;

  GuardStatus? _guardStatus;
  GuardStatus? get guardStatus => _guardStatus;

  bool _guardTesting = false;
  bool get guardTesting => _guardTesting;

  Timer? _pollTimer;
  Timer? _deviceTimer;
  bool _polling = false;
  int _pollGeneration = 0;
  int _deviceGeneration = 0;

  bool get isSignedIn => _authStatus == OpenHandsAuthStatus.signedIn;

  bool get agentRunning => _active?.isRunning ?? false;

  String? get activeModel =>
      _active?.llmModel ?? _user?.llmModel;

  Future<void> initialize() async {
    final savedBaseUrl = await _store.readBaseUrl();
    _api.updateBaseUrl(savedBaseUrl);
    _guard = await _store.readGuardConfig();

    final token = await _store.readToken();
    if (token == null || token.isEmpty) {
      _authStatus = OpenHandsAuthStatus.signedOut;
      notifyListeners();
      return;
    }

    _api.token = token;
    try {
      _user = await _api.me();
      _authStatus = OpenHandsAuthStatus.signedIn;
      notifyListeners();
      unawaited(refreshConversations());
    } on OpenHandsApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _store.clearToken();
        _api.token = null;
        _authStatus = OpenHandsAuthStatus.signedOut;
      } else {
        _authStatus = OpenHandsAuthStatus.error;
        _error = error.message;
      }
      notifyListeners();
    } catch (error) {
      _authStatus = OpenHandsAuthStatus.error;
      _error = 'Could not reach OpenHands: $error';
      notifyListeners();
    }
  }

  Future<void> retry() async {
    _error = null;
    _authStatus = OpenHandsAuthStatus.loading;
    notifyListeners();
    await initialize();
  }

  // ---------------------------------------------------------------------
  // Sign-in
  // ---------------------------------------------------------------------

  Future<void> startDeviceSignIn() async {
    final generation = ++_deviceGeneration;
    _deviceTimer?.cancel();
    _error = null;
    _deviceNotice = null;
    _deviceCode = null;
    _devicePolling = true;
    _authStatus = OpenHandsAuthStatus.signingIn;
    notifyListeners();

    try {
      final code = await _api.startDeviceFlow();
      if (generation != _deviceGeneration) return;
      _deviceCode = code;
      notifyListeners();
      await _openExternal(code.verificationUriComplete);
      unawaited(_pollDeviceToken(code, generation));
    } catch (error) {
      if (generation != _deviceGeneration) return;
      _devicePolling = false;
      _authStatus = OpenHandsAuthStatus.signedOut;
      _error = error.toString();
      notifyListeners();
    }
  }

  Future<void> _pollDeviceToken(DeviceCode code, int generation) async {
    var interval = code.interval.clamp(1, 30);
    final deadline = DateTime.now().add(Duration(seconds: code.expiresIn));
    while (generation == _deviceGeneration &&
        DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(Duration(seconds: interval));
      if (generation != _deviceGeneration) return;
      try {
        final token = await _api.pollDeviceToken(code.deviceCode);
        if (generation != _deviceGeneration) return;
        await _completeSignIn(token);
        return;
      } on DeviceFlowPending {
        continue;
      } on DeviceFlowSlowDown catch (slowDown) {
        interval = (slowDown.interval ?? (interval + 5)).clamp(1, 30);
      } on TimeoutException {
        _deviceNotice = 'The network is slow. Still waiting for approval…';
        notifyListeners();
        continue;
      } on http.ClientException {
        _deviceNotice = 'Connection interrupted. Still waiting for approval…';
        notifyListeners();
        continue;
      } catch (error) {
        if (generation != _deviceGeneration) return;
        _devicePolling = false;
        _deviceCode = null;
        _deviceNotice = null;
        _authStatus = OpenHandsAuthStatus.signedOut;
        _error = error.toString();
        notifyListeners();
        return;
      }
    }
    if (generation != _deviceGeneration) return;
    _devicePolling = false;
    _deviceCode = null;
    _deviceNotice = null;
    _authStatus = OpenHandsAuthStatus.signedOut;
    _error = 'The sign-in code expired. Start again.';
    notifyListeners();
  }

  Future<void> cancelDeviceSignIn() async {
    _deviceGeneration++;
    _deviceTimer?.cancel();
    _devicePolling = false;
    _deviceCode = null;
    _deviceNotice = null;
    _authStatus = OpenHandsAuthStatus.signedOut;
    _error = null;
    notifyListeners();
  }

  Future<void> openVerificationPage() async {
    final code = _deviceCode;
    if (code == null) return;
    await _openExternal(code.verificationUriComplete);
  }

  Future<void> signInWithApiKey(String apiKey) async {
    final key = apiKey.trim();
    if (key.isEmpty) return;
    _error = null;
    _deviceNotice = null;
    _authStatus = OpenHandsAuthStatus.signingIn;
    notifyListeners();
    _api.token = key;
    try {
      _user = await _api.me();
      await _store.writeToken(key);
      _authStatus = OpenHandsAuthStatus.signedIn;
      notifyListeners();
      await refreshConversations();
    } catch (error) {
      _api.token = null;
      _authStatus = OpenHandsAuthStatus.signedOut;
      _error = error.toString();
      notifyListeners();
    }
  }

  Future<void> _completeSignIn(String token) async {
    _api.token = token;
    try {
      _user = await _api.me();
      await _store.writeToken(token);
      _devicePolling = false;
      _deviceCode = null;
      _deviceNotice = null;
      _authStatus = OpenHandsAuthStatus.signedIn;
      _error = null;
      notifyListeners();
      await refreshConversations();
    } catch (error) {
      _api.token = null;
      _devicePolling = false;
      _deviceCode = null;
      _deviceNotice = null;
      _authStatus = OpenHandsAuthStatus.signedOut;
      _error = 'Signed in, but the profile could not be loaded: $error';
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    _pollGeneration++;
    _pollTimer?.cancel();
    _pollTimer = null;
    _deviceGeneration++;
    _deviceTimer?.cancel();
    await _store.clearToken();
    _api.token = null;
    _user = null;
    _conversations = const [];
    _nextPageId = null;
    _active = null;
    _timeline = const [];
    _deviceNotice = null;
    _authStatus = OpenHandsAuthStatus.signedOut;
    _error = null;
    notifyListeners();
  }

  Future<void> setBaseUrl(String value) async {
    final normalized = OpenHandsApi.normalizeBaseUrl(value);
    if (normalized == _api.baseUrl) return;
    _api.updateBaseUrl(normalized);
    await _store.writeBaseUrl(normalized);
    if (_authStatus == OpenHandsAuthStatus.signedIn) {
      await signOut();
    } else {
      _error = null;
      notifyListeners();
    }
  }

  Future<void> _openExternal(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      // The user can still copy the code and open the URL manually.
    }
  }

  // ---------------------------------------------------------------------
  // Conversation list
  // ---------------------------------------------------------------------

  Future<void> refreshConversations() async {
    if (!isSignedIn) return;
    _conversationsLoading = true;
    _conversationsError = null;
    notifyListeners();
    try {
      final page = await _api.searchConversations(limit: 50);
      _conversations = page.items;
      _nextPageId = page.nextPageId;
    } catch (error) {
      _conversationsError = error.toString();
    } finally {
      _conversationsLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadMoreConversations() async {
    if (!isSignedIn || _conversationsLoading) return;
    final pageId = _nextPageId;
    if (pageId == null) return;
    _conversationsLoading = true;
    notifyListeners();
    try {
      final page = await _api.searchConversations(limit: 50, pageId: pageId);
      _conversations = [..._conversations, ...page.items];
      _nextPageId = page.nextPageId;
    } catch (error) {
      _conversationsError = error.toString();
    } finally {
      _conversationsLoading = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------
  // Open conversation
  // ---------------------------------------------------------------------

  Future<void> openConversation(OpenHandsConversation conversation) async {
    _pollGeneration++;
    _pollTimer?.cancel();
    _active = conversation;
    _timeline = const [];
    _timelineError = null;
    _timelineLoading = true;
    notifyListeners();

    final generation = _pollGeneration;
    try {
      final fresh = await _api.getConversation(conversation.id);
      if (generation != _pollGeneration) return;
      _active = fresh;
      _replaceInList(fresh);
      await _loadEvents(generation, initial: true);
      _startPolling(generation);
    } catch (error) {
      if (generation != _pollGeneration) return;
      _timelineError = error.toString();
    } finally {
      if (generation == _pollGeneration) {
        _timelineLoading = false;
        notifyListeners();
      }
    }
  }

  void closeConversation() {
    _pollGeneration++;
    _pollTimer?.cancel();
    _pollTimer = null;
    _active = null;
    _timeline = const [];
    _timelineError = null;
    _timelineLoading = false;
    notifyListeners();
  }

  void _startPolling(int generation) {
    _pollTimer?.cancel();
    var tick = 0;
    _pollTimer = Timer.periodic(const Duration(milliseconds: 2500), (_) async {
      if (generation != _pollGeneration) return;
      tick++;
      if (tick % 2 == 0) {
        await _refreshActiveConversation(generation);
      }
      await _loadEvents(generation);
    });
  }

  Future<void> _refreshActiveConversation(int generation) async {
    final current = _active;
    if (current == null) return;
    try {
      final fresh = await _api.getConversation(current.id);
      if (generation != _pollGeneration) return;
      final statusChanged =
          fresh.executionStatus != current.executionStatus;
      _active = fresh;
      _replaceInList(fresh);
      if (statusChanged) notifyListeners();
    } catch (_) {
      // Status refreshes are best effort; event polling still runs.
    }
  }

  Future<void> _loadEvents(int generation, {bool initial = false}) async {
    final current = _active;
    if (current == null || !current.canStream) {
      if (initial && current != null && !current.canStream) {
        _timelineError =
            'This conversation has no live sandbox. Wake it in OpenHands first.';
      }
      return;
    }
    if (_polling && !initial) return;
    _polling = true;
    try {
      final page = await _api.searchEvents(
        current,
        limit: 100,
        sortOrder: 'TIMESTAMP_DESC',
      );
      if (generation != _pollGeneration) return;

      String? eventStatus;
      for (final event in page.items) {
        if (event.kind == 'ConversationStateUpdateEvent' &&
            event.raw['key'] == 'execution_status') {
          eventStatus = event.raw['value']?.toString();
          break;
        }
      }

      final ordered = page.items.reversed.toList(growable: false);
      final mapped = _mapEvents(ordered);
      var changed = !_sameTimeline(_timeline, mapped);
      if (eventStatus != null &&
          eventStatus.isNotEmpty &&
          _active != null &&
          _active!.executionStatus != eventStatus) {
        _active = _active!.copyWith(executionStatus: eventStatus);
        changed = true;
      }
      _timeline = mapped;
      _timelineError = null;
      if (changed) notifyListeners();
    } catch (error) {
      if (generation != _pollGeneration) return;
      if (initial) {
        _timelineError = error.toString();
        notifyListeners();
      }
    } finally {
      _polling = false;
    }
  }

  Future<void> refreshTimeline() async {
    final generation = _pollGeneration;
    await _loadEvents(generation, initial: true);
    notifyListeners();
  }

  void _replaceInList(OpenHandsConversation conversation) {
    final index =
        _conversations.indexWhere((item) => item.id == conversation.id);
    if (index == -1) {
      _conversations = [conversation, ..._conversations];
    } else {
      final copy = [..._conversations];
      copy[index] = conversation;
      _conversations = copy;
    }
  }

  // ---------------------------------------------------------------------
  // Sending
  // ---------------------------------------------------------------------

  Future<bool> sendMessage(String text) async {
    final current = _active;
    final trimmed = text.trim();
    if (current == null || trimmed.isEmpty || _sending) return false;

    _sending = true;
    final optimistic = HandoffTimelineItem(
      id: 'local-${DateTime.now().microsecondsSinceEpoch}',
      kind: HandoffItemKind.user,
      text: trimmed,
      at: DateTime.now(),
    );
    _timeline = [..._timeline, optimistic];
    notifyListeners();

    try {
      await _api.sendMessage(current, trimmed);
      _active = _active?.copyWith(executionStatus: 'running');
      final generation = _pollGeneration;
      await _loadEvents(generation, initial: true);
      _sending = false;
      notifyListeners();
      return true;
    } catch (error) {
      _timeline =
          _timeline.where((item) => item.id != optimistic.id).toList();
      _timelineError = error.toString();
      _sending = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> stopAgent() async {
    final current = _active;
    if (current == null) return;
    try {
      await _api.interruptConversation(current);
      await _refreshActiveConversation(_pollGeneration);
      await _loadEvents(_pollGeneration, initial: true);
    } catch (error) {
      _timelineError = error.toString();
      notifyListeners();
    }
  }

  Future<OpenHandsConversation?> createConversation(
    String message, {
    String? repository,
    String? branch,
  }) async {
    if (_creating) return null;
    final trimmed = message.trim();
    if (trimmed.isEmpty) return null;
    _creating = true;
    _error = null;
    notifyListeners();
    try {
      final conversation = await _api.createConversation(
        message: trimmed,
        repository: repository,
        branch: branch,
      );
      _conversations = [
        conversation,
        ..._conversations.where((item) => item.id != conversation.id),
      ];
      _creating = false;
      notifyListeners();
      await openConversation(conversation);
      return conversation;
    } catch (error) {
      _error = error.toString();
      _creating = false;
      notifyListeners();
      return null;
    }
  }

  // ---------------------------------------------------------------------
  // Guard
  // ---------------------------------------------------------------------

  Future<void> saveGuardConfig(GuardConfig config) async {
    _guard = config.copyWith(
      url: _normalizeGuardUrl(config.url),
      key: config.key.trim(),
    );
    await _store.writeGuardConfig(_guard);
    notifyListeners();
  }

  Future<GuardStatus> testGuard() async {
    _guardTesting = true;
    _guardStatus = null;
    notifyListeners();

    final base = _normalizeGuardUrl(_guard.url);
    if (base.isEmpty) {
      final status = const GuardStatus(
        reachable: false,
        message: 'No Guard address configured.',
      );
      _guardStatus = status;
      _guardTesting = false;
      notifyListeners();
      return status;
    }

    final headers = <String, String>{
      if (_guard.key.isNotEmpty) 'Authorization': 'Bearer ${_guard.key}',
      if (_guard.key.isNotEmpty) 'X-Guard-Key': _guard.key,
      if (_guard.key.isNotEmpty) 'X-API-Key': _guard.key,
    };

    final candidates = <String>[
      '$base/health',
      '$base/healthz',
      '$base/api/health',
      '$base/api/status',
      '$base/status',
      base,
    ];

    GuardStatus? lastStatus;
    for (final candidate in candidates) {
      final watch = Stopwatch()..start();
      try {
        final response = await http
            .get(Uri.parse(candidate), headers: headers)
            .timeout(const Duration(seconds: 8));
        watch.stop();
        if (response.statusCode >= 200 && response.statusCode < 400) {
          final status = GuardStatus(
            reachable: true,
            message: response.statusCode == 200
                ? 'Guard is online'
                : 'Guard answered (HTTP ${response.statusCode})',
            latency: watch.elapsed,
            detail: _shorten(response.body),
          );
          _guardStatus = status;
          _guardTesting = false;
          notifyListeners();
          return status;
        }
        lastStatus = GuardStatus(
          reachable: false,
          message: 'Guard answered with HTTP ${response.statusCode}',
          latency: watch.elapsed,
          detail: _shorten(response.body),
        );
      } catch (error) {
        watch.stop();
        lastStatus = GuardStatus(
          reachable: false,
          message: 'Could not reach the Guard',
          latency: watch.elapsed,
          detail: error.toString(),
        );
      }
    }

    final status = lastStatus ??
        const GuardStatus(reachable: false, message: 'Could not reach Guard');
    _guardStatus = status;
    _guardTesting = false;
    notifyListeners();
    return status;
  }

  String _normalizeGuardUrl(String value) {
    var text = value.trim();
    if (text.isEmpty) return '';
    if (!text.startsWith('http://') && !text.startsWith('https://')) {
      text = 'https://$text';
    }
    while (text.endsWith('/')) {
      text = text.substring(0, text.length - 1);
    }
    return text;
  }

  String? _shorten(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return trimmed.length <= 400 ? trimmed : '${trimmed.substring(0, 400)}…';
  }

  // ---------------------------------------------------------------------
  // Event mapping
  // ---------------------------------------------------------------------

  List<HandoffTimelineItem> _mapEvents(List<OpenHandsEvent> events) {
    final items = <HandoffTimelineItem>[];
    final actionIndex = <String, int>{};

    for (final event in events) {
      switch (event.kind) {
        case 'MessageEvent':
          final message = event.raw['llm_message'] ?? event.raw['message'];
          final role = message is Map
              ? (message['role'] ?? event.source).toString()
              : event.source;
          final text = contentToText(
            message is Map ? message['content'] : message,
          );
          if (text.trim().isEmpty) continue;
          items.add(
            HandoffTimelineItem(
              id: event.id,
              kind: role == 'user'
                  ? HandoffItemKind.user
                  : HandoffItemKind.assistant,
              text: text.trim(),
              at: event.timestamp,
            ),
          );
        case 'ActionEvent':
          final rawAction = event.raw['action'];
          final action = rawAction is Map
              ? rawAction.cast<String, dynamic>()
              : <String, dynamic>{};
          final detail = describeAction(action);
          final tool = event.toolName;
          final item = HandoffTimelineItem(
            id: event.id,
            kind: HandoffItemKind.action,
            title: _toolLabel(tool),
            toolName: tool,
            text: detail,
            running: !_instantTool(tool),
            at: event.timestamp,
            actionId: event.id,
          );
          actionIndex[event.id] = items.length;
          if (event.toolCallId.isNotEmpty) {
            actionIndex[event.toolCallId] = items.length;
          }
          items.add(item);
        case 'ObservationEvent':
          final rawObservation = event.raw['observation'];
          final text = rawObservation is Map
              ? describeObservation(rawObservation.cast<String, dynamic>())
              : contentToText(rawObservation);
          final key =
              event.actionId.isNotEmpty ? event.actionId : event.toolCallId;
          final index = actionIndex[key];
          if (index != null && index < items.length) {
            final item = items[index];
            item.running = false;
            if (text.trim().isNotEmpty) {
              item.text = item.text.trim().isEmpty
                  ? text.trim()
                  : '${item.text}\n\n${text.trim()}';
            }
          } else if (text.trim().isNotEmpty) {
            items.add(
              HandoffTimelineItem(
                id: event.id,
                kind: HandoffItemKind.action,
                title: _toolLabel(event.toolName),
                toolName: event.toolName,
                text: text.trim(),
                at: event.timestamp,
              ),
            );
          }
        case 'AgentErrorEvent':
        case 'ErrorEvent':
        case 'ConversationErrorEvent':
          final detail = event.raw['error'] ??
              event.raw['detail'] ??
              event.raw['message'] ??
              'The agent hit an error.';
          items.add(
            HandoffTimelineItem(
              id: event.id,
              kind: HandoffItemKind.error,
              text: detail.toString(),
              at: event.timestamp,
            ),
          );
        case 'PauseEvent':
          items.add(
            HandoffTimelineItem(
              id: event.id,
              kind: HandoffItemKind.notice,
              text: 'Agent paused',
              at: event.timestamp,
            ),
          );
        case 'CondensationEvent':
          items.add(
            HandoffTimelineItem(
              id: event.id,
              kind: HandoffItemKind.notice,
              text: 'Context condensed',
              at: event.timestamp,
            ),
          );
        default:
          break;
      }
    }
    return items;
  }

  bool _instantTool(String tool) {
    final name = tool.toLowerCase();
    return name == 'think' || name == 'finish' || name == 'task_tracker';
  }

  String _toolLabel(String tool) {
    switch (tool.toLowerCase()) {
      case 'terminal':
        return 'Terminal';
      case 'file_editor':
        return 'File editor';
      case 'browse':
      case 'browser':
        return 'Browser';
      case 'task_tracker':
        return 'Task plan';
      case 'think':
        return 'Thinking';
      case 'finish':
        return 'Finished';
      case 'delegate':
        return 'Delegated task';
      default:
        if (tool.isEmpty) return 'Tool';
        final cleaned = tool.replaceAll('_', ' ');
        return cleaned[0].toUpperCase() + cleaned.substring(1);
    }
  }

  bool _sameTimeline(
    List<HandoffTimelineItem> a,
    List<HandoffTimelineItem> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].text != b[i].text ||
          a[i].running != b[i].running ||
          a[i].kind != b[i].kind) {
        return false;
      }
    }
    return true;
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _deviceTimer?.cancel();
    _api.close();
    super.dispose();
  }
}
