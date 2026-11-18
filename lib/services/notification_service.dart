import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Posts user-visible alerts. The seam exists so the session logic can be
/// exercised in tests without the native notifications plugin.
abstract class AgentNotifier {
  Future<void> showAgentState({
    required String conversationId,
    required String title,
    required String body,
  });
}

/// Native notifications for agent state changes.
///
/// The Canvas only plays a sound, and only when the user enabled it, so a
/// backgrounded agent finishing is silent. This posts a real system
/// notification the OS shows even when the app is not in the foreground.
class NotificationService implements AgentNotifier {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  static const _channelId = 'agent_activity';
  static const _channelName = 'Agent activity';
  static const _channelDescription =
      'Alerts when an agent needs your input or finishes.';

  Future<void> init() async {
    if (_initialized) return;
    if (kIsWeb) {
      _initialized = true;
      return;
    }
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings: settings);
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    _initialized = true;
  }

  /// Posts (or updates) the notification for one conversation. The id is
  /// derived from the conversation id so a new state replaces the old one
  /// instead of stacking duplicates.
  @override
  Future<void> showAgentState({
    required String conversationId,
    required String title,
    required String body,
  }) async {
    if (kIsWeb) return;
    await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.high,
        priority: Priority.high,
        styleInformation: BigTextStyleInformation(''),
        category: AndroidNotificationCategory.status,
      ),
    );
    await _plugin.show(
      id: conversationId.hashCode & 0x7fffffff,
      title: title,
      body: body,
      notificationDetails: details,
      payload: conversationId,
    );
  }

  Future<void> cancelFor(String conversationId) async {
    if (kIsWeb) return;
    await _plugin.cancel(id: conversationId.hashCode & 0x7fffffff);
  }
}
