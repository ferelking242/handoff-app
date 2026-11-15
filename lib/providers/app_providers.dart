import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/conversation.dart';
import '../services/cloud_api_service.dart';
import '../services/device_flow_service.dart';
import '../services/notification_service.dart';
import '../services/session_service.dart';
import '../services/token_store.dart';

/// Long-lived singletons. Nothing here is tied to a screen, so rebuilding the
/// widget tree never disposes the session or the sockets it owns.
final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

final cloudApiProvider = Provider<CloudApiService>((ref) {
  final api = CloudApiService();
  ref.onDispose(() => api.setToken(null));
  return api;
});

final deviceFlowProvider = Provider<DeviceFlowService>(
  (ref) => DeviceFlowService(),
);

final sessionServiceProvider = Provider<SessionService>((ref) {
  final service = SessionService();
  ref.onDispose(service.disposeAll);
  return service;
});

/// The signed-in user's bearer token, or null when signed out.
class AuthNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  Future<void> restore() async {
    final store = ref.read(tokenStoreProvider);
    final token = await store.readToken();
    if (token != null && token.isNotEmpty) {
      ref.read(cloudApiProvider).setToken(token);
      state = token;
    }
  }

  Future<void> signIn(String token) async {
    await ref.read(tokenStoreProvider).writeToken(token);
    ref.read(cloudApiProvider).setToken(token);
    state = token;
  }

  Future<void> signOut() async {
    await ref.read(tokenStoreProvider).clear();
    ref.read(cloudApiProvider).setToken(null);
    state = null;
  }
}

final authProvider = NotifierProvider<AuthNotifier, String?>(AuthNotifier.new);

/// The account's conversations. Refresh is explicit so a screen rebuild never
/// triggers a network storm (one of the Canvas pain points).
class ConversationsNotifier
    extends AsyncNotifier<List<CloudConversation>> {
  @override
  Future<List<CloudConversation>> build() async {
    final token = ref.watch(authProvider);
    if (token == null) return const [];
    return ref.read(cloudApiProvider).searchConversations();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(cloudApiProvider).searchConversations(),
    );
  }
}

final conversationsProvider =
    AsyncNotifierProvider<ConversationsNotifier, List<CloudConversation>>(
      ConversationsNotifier.new,
    );

/// Live session state for one conversation, straight from the global service.
final sessionStateProvider =
    StreamProvider.family<SessionState, String>((ref, conversationId) {
      final service = ref.watch(sessionServiceProvider);
      return service.watch(conversationId);
    });

/// Ensures notifications are ready before the first event can arrive.
final notificationInitProvider = FutureProvider<void>((ref) async {
  await NotificationService.instance.init();
});

/// Dark/light preference, persisted so the choice survives a restart.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _key = 'theme_mode';

  @override
  ThemeMode build() => ThemeMode.dark;

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_key);
    if (stored == 'light') state = ThemeMode.light;
    if (stored == 'dark') state = ThemeMode.dark;
  }

  Future<void> toggle() async {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, state == ThemeMode.dark ? 'dark' : 'light');
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

/// Conversations hidden from the list on this device.
class HiddenConversationsNotifier extends Notifier<Set<String>> {
  static const _key = 'hidden_conversations';

  @override
  Set<String> build() => const {};

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    state = (prefs.getStringList(_key) ?? const []).toSet();
  }

  Future<void> hide(String conversationId) async {
    state = {...state, conversationId};
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, state.toList());
  }
}

final hiddenConversationsProvider =
    NotifierProvider<HiddenConversationsNotifier, Set<String>>(
      HiddenConversationsNotifier.new,
    );

/// The conversation list with locally-hidden entries removed.
final visibleConversationsProvider =
    Provider<AsyncValue<List<CloudConversation>>>((ref) {
      final conversations = ref.watch(conversationsProvider);
      final hidden = ref.watch(hiddenConversationsProvider);
      if (hidden.isEmpty) return conversations;
      return conversations.whenData(
        (items) => items.where((c) => !hidden.contains(c.id)).toList(),
      );
    });

/// Free-text filter over the conversation list.
final conversationQueryProvider = NotifierProvider<ConversationQueryNotifier, String>(
  ConversationQueryNotifier.new,
);

class ConversationQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String value) => state = value;
}
