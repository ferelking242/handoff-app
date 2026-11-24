import 'dart:convert';

/// A signed-in OpenHands account as returned by `GET /api/v1/users/me`.
class OpenHandsUser {
  const OpenHandsUser({
    required this.id,
    required this.email,
    required this.orgName,
    required this.role,
    required this.permissions,
    this.llmModel,
    this.llmBaseUrl,
  });

  final String id;
  final String email;
  final String orgName;
  final String role;
  final List<String> permissions;
  final String? llmModel;
  final String? llmBaseUrl;

  String get displayName {
    final local = email.split('@').first.trim();
    if (local.isEmpty) return 'OpenHands';
    return local
        .split(RegExp(r'[._-]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
  }

  String get initial {
    final name = displayName.trim();
    return name.isEmpty ? 'O' : name[0].toUpperCase();
  }

  factory OpenHandsUser.fromJson(Map<String, dynamic> json) {
    return OpenHandsUser(
      id: (json['id'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      orgName: (json['org_name'] ?? '').toString(),
      role: (json['role'] ?? '').toString(),
      permissions: (json['permissions'] as List?)
              ?.map((e) => e.toString())
              .toList(growable: false) ??
          const <String>[],
      llmModel: json['llm_model']?.toString(),
      llmBaseUrl: json['llm_base_url']?.toString(),
    );
  }
}

/// One OpenHands app conversation (`/api/v1/app-conversations`).
class OpenHandsConversation {
  const OpenHandsConversation({
    required this.id,
    required this.title,
    this.llmModel,
    this.repository,
    this.branch,
    this.sandboxStatus,
    this.executionStatus,
    this.conversationUrl,
    this.sessionApiKey,
    this.uiUrl,
    this.createdAt,
    this.updatedAt,
    this.accumulatedCost,
  });

  final String id;
  final String title;
  final String? llmModel;
  final String? repository;
  final String? branch;
  final String? sandboxStatus;
  final String? executionStatus;
  final String? conversationUrl;
  final String? sessionApiKey;
  final String? uiUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final double? accumulatedCost;

  bool get isRunning => (executionStatus ?? '').toLowerCase() == 'running';
  bool get isPaused => (sandboxStatus ?? '').toUpperCase() == 'PAUSED';
  bool get canStream => conversationUrl != null && conversationUrl!.isNotEmpty;

  String get displayTitle {
    final value = title.trim();
    return value.isEmpty ? 'Untitled conversation' : value;
  }

  String get subtitle {
    final parts = <String>[];
    if (repository != null && repository!.isNotEmpty) parts.add(repository!);
    if (llmModel != null && llmModel!.isNotEmpty) {
      parts.add(llmModel!.split('/').last);
    }
    return parts.join(' · ');
  }

  OpenHandsConversation copyWith({
    String? title,
    String? sandboxStatus,
    String? executionStatus,
    String? conversationUrl,
    String? sessionApiKey,
  }) {
    return OpenHandsConversation(
      id: id,
      title: title ?? this.title,
      llmModel: llmModel,
      repository: repository,
      branch: branch,
      sandboxStatus: sandboxStatus ?? this.sandboxStatus,
      executionStatus: executionStatus ?? this.executionStatus,
      conversationUrl: conversationUrl ?? this.conversationUrl,
      sessionApiKey: sessionApiKey ?? this.sessionApiKey,
      uiUrl: uiUrl,
      createdAt: createdAt,
      updatedAt: updatedAt,
      accumulatedCost: accumulatedCost,
    );
  }

  factory OpenHandsConversation.fromJson(Map<String, dynamic> json) {
    final metrics = json['metrics'];
    double? cost;
    if (metrics is Map) {
      final raw = metrics['accumulated_cost'];
      if (raw is num) cost = raw.toDouble();
    }
    return OpenHandsConversation(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      llmModel: json['llm_model']?.toString(),
      repository: json['selected_repository']?.toString(),
      branch: json['selected_branch']?.toString(),
      sandboxStatus: json['sandbox_status']?.toString(),
      executionStatus: json['execution_status']?.toString(),
      conversationUrl: json['conversation_url']?.toString(),
      sessionApiKey: json['session_api_key']?.toString(),
      uiUrl: json['conversation_ui_url']?.toString(),
      createdAt: _parseDate(json['created_at']),
      updatedAt: _parseDate(json['updated_at']),
      accumulatedCost: cost,
    );
  }
}

/// A raw event from the OpenHands agent server.
class OpenHandsEvent {
  const OpenHandsEvent({
    required this.id,
    required this.kind,
    required this.source,
    required this.raw,
    this.timestamp,
  });

  final String id;
  final String kind;
  final String source;
  final Map<String, dynamic> raw;
  final DateTime? timestamp;

  String get toolName => (raw['tool_name'] ?? '').toString();
  String get toolCallId => (raw['tool_call_id'] ?? '').toString();
  String get actionId => (raw['action_id'] ?? '').toString();

  factory OpenHandsEvent.fromJson(Map<String, dynamic> json) {
    return OpenHandsEvent(
      id: (json['id'] ?? '').toString(),
      kind: (json['kind'] ?? '').toString(),
      source: (json['source'] ?? '').toString(),
      raw: json,
      timestamp: _parseDate(json['timestamp']),
    );
  }
}

/// The kind of row rendered in a conversation timeline.
enum HandoffItemKind { user, assistant, action, error, notice }

/// A display row derived from one or more OpenHands events.
class HandoffTimelineItem {
  HandoffTimelineItem({
    required this.id,
    required this.kind,
    this.text = '',
    this.title,
    this.toolName,
    this.running = false,
    this.at,
    this.actionId,
  });

  final String id;
  final HandoffItemKind kind;
  String text;
  String? title;
  String? toolName;
  bool running;
  DateTime? at;
  String? actionId;

  bool get isTool => kind == HandoffItemKind.action;
}

class DeviceCode {
  const DeviceCode({
    required this.deviceCode,
    required this.userCode,
    required this.verificationUri,
    required this.verificationUriComplete,
    required this.expiresIn,
    required this.interval,
  });

  final String deviceCode;
  final String userCode;
  final String verificationUri;
  final String verificationUriComplete;
  final int expiresIn;
  final int interval;

  factory DeviceCode.fromJson(Map<String, dynamic> json) {
    final uri = (json['verification_uri'] ?? '').toString();
    final code = (json['user_code'] ?? '').toString();
    return DeviceCode(
      deviceCode: (json['device_code'] ?? '').toString(),
      userCode: code,
      verificationUri: uri,
      verificationUriComplete:
          (json['verification_uri_complete'] ?? '$uri?user_code=$code')
              .toString(),
      expiresIn: (json['expires_in'] as num?)?.toInt() ?? 600,
      interval: (json['interval'] as num?)?.toInt() ?? 5,
    );
  }
}

class GuardConfig {
  const GuardConfig({this.url = '', this.key = ''});

  final String url;
  final String key;

  bool get isConfigured => url.trim().isNotEmpty;

  GuardConfig copyWith({String? url, String? key}) =>
      GuardConfig(url: url ?? this.url, key: key ?? this.key);
}

class GuardStatus {
  const GuardStatus({
    required this.reachable,
    required this.message,
    this.latency,
    this.detail,
  });

  final bool reachable;
  final String message;
  final Duration? latency;
  final String? detail;
}

DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  final text = value.toString();
  if (text.isEmpty) return null;
  return DateTime.tryParse(text);
}

/// Extracts readable text from an OpenHands message/observation content list.
String contentToText(Object? content) {
  if (content == null) return '';
  if (content is String) return content;
  if (content is List) {
    final buffer = StringBuffer();
    for (final part in content) {
      if (part is String) {
        buffer.write(part);
        continue;
      }
      if (part is Map) {
        final type = part['type']?.toString();
        if (type == 'text') {
          buffer.write(part['text'] ?? '');
        } else if (type == 'image') {
          final name = part['image_url'] ?? part['name'] ?? 'image';
          buffer.write('\n[image: $name]\n');
        } else if (part['text'] != null) {
          buffer.write(part['text']);
        }
      }
    }
    return buffer.toString().trim();
  }
  if (content is Map) {
    if (content['text'] != null) return content['text'].toString();
    return contentToText(content['content']);
  }
  return content.toString();
}

/// Short, human-readable description of an ActionEvent.
String describeAction(Map<String, dynamic> action) {
  final command = action['command'];
  final path = action['path'];
  final url = action['url'];
  final thought = action['thought'];
  final taskList = action['task_list'];

  if (command is String && command.trim().isNotEmpty) {
    if (path is String && path.trim().isNotEmpty) {
      return '$command  $path';
    }
    return command.trim();
  }
  if (path is String && path.trim().isNotEmpty) return path;
  if (url is String && url.trim().isNotEmpty) return url;
  if (thought is String && thought.trim().isNotEmpty) return thought.trim();
  if (taskList is List && taskList.isNotEmpty) {
    final done = taskList.where((e) => e is Map && e['status'] == 'done').length;
    return 'Plan updated · $done/${taskList.length} done';
  }

  final cleaned = Map<String, dynamic>.from(action)
    ..remove('kind')
    ..remove('security_risk');
  if (cleaned.isEmpty) return '';
  try {
    return const JsonEncoder.withIndent('  ').convert(cleaned);
  } catch (_) {
    return cleaned.toString();
  }
}

/// Short, human-readable description of an ObservationEvent.
String describeObservation(Map<String, dynamic> observation) {
  final content = observation['content'];
  final text = contentToText(content);
  if (text.isNotEmpty) return text;

  final buffer = StringBuffer();
  final stdout = observation['stdout'];
  final stderr = observation['stderr'];
  if (stdout is String && stdout.isNotEmpty) buffer.write(stdout);
  if (stderr is String && stderr.isNotEmpty) {
    if (buffer.isNotEmpty) buffer.write('\n');
    buffer.write(stderr);
  }
  final exitCode = observation['exit_code'];
  if (buffer.isEmpty && exitCode != null) buffer.write('exit $exitCode');
  if (buffer.isEmpty) {
    final error = observation['error'] ?? observation['output'];
    if (error != null) buffer.write(error.toString());
  }
  return buffer.toString().trim();
}
