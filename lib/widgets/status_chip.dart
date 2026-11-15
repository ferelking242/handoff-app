import 'package:material_ui/material_ui.dart';

import '../core/icon_fonts/app_icons.dart';
import '../core/theme/app_theme.dart';
import '../models/agent_state.dart';

/// The coloured dot + label that tells the user what the agent is doing.
class StatusChip extends StatelessWidget {
  const StatusChip({
    super.key,
    required this.state,
    this.connected = true,
    this.compact = false,
  });

  final AgentState state;
  final bool connected;
  final bool compact;

  static Color colorFor(AgentState state) {
    switch (state) {
      case AgentState.running:
        return AppColors.accentBright;
      case AgentState.awaitingUserInput:
      case AgentState.awaitingConfirmation:
        return AppColors.warning;
      case AgentState.finished:
        return AppColors.success;
      case AgentState.error:
        return AppColors.danger;
      case AgentState.stuck:
        return AppColors.danger;
      case AgentState.stopped:
      case AgentState.idle:
      case AgentState.unknown:
        return AppColors.textTertiary;
    }
  }

  static IconData iconFor(AgentState state) {
    switch (state) {
      case AgentState.running:
        return AppIcons.flash;
      case AgentState.awaitingUserInput:
      case AgentState.awaitingConfirmation:
        return AppIcons.messageText;
      case AgentState.finished:
        return AppIcons.tickCircle;
      case AgentState.error:
      case AgentState.stuck:
        return AppIcons.danger;
      case AgentState.stopped:
        return AppIcons.stopCircle;
      case AgentState.idle:
      case AgentState.unknown:
        return AppIcons.clock;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = colorFor(state);
    final label = connected ? state.label : 'Reconnecting';
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconFor(state), size: compact ? 11 : 13, color: color),
          SizedBox(width: compact ? 4 : 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: compact ? 11 : 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}
