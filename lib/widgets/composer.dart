import 'package:material_ui/material_ui.dart';

import '../core/icon_fonts/app_icons.dart';
import '../core/theme/app_theme.dart';

/// The message box.
///
/// Grows with the text, sends on Enter/tap, and shows a "stop" button while
/// the agent is running so the user can interrupt without hunting for a menu.
class Composer extends StatefulWidget {
  const Composer({
    super.key,
    required this.onSend,
    required this.onStop,
    this.busy = false,
    this.enabled = true,
    this.hintText = 'Message the agent…',
    this.autofocus = false,
  });

  final void Function(String text) onSend;
  final VoidCallback onStop;
  final bool busy;
  final bool enabled;
  final String hintText;
  final bool autofocus;

  @override
  State<Composer> createState() => _ComposerState();
}

class _ComposerState extends State<Composer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  void _onChanged() {
    final hasText = _controller.text.trim().isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    widget.onSend(text);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canSend = _hasText && widget.enabled;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  focusNode: _focus,
                  autofocus: widget.autofocus,
                  enabled: widget.enabled,
                  minLines: 1,
                  maxLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.newline,
                  style: theme.textTheme.bodyMedium,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _ActionButton(
                busy: widget.busy,
                canSend: canSend,
                onSend: _submit,
                onStop: widget.onStop,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.busy,
    required this.canSend,
    required this.onSend,
    required this.onStop,
  });

  final bool busy;
  final bool canSend;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final showStop = busy && !canSend;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      transitionBuilder: (child, animation) =>
          ScaleTransition(scale: animation, child: child),
      child: showStop
          ? _RoundButton(
              key: const ValueKey('stop'),
              icon: AppIcons.stop,
              onTap: onStop,
              background: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.surfaceHigher
                  : AppColors.lightSurfaceHigh,
              foreground: Theme.of(context).colorScheme.onSurface,
            )
          : _RoundButton(
              key: const ValueKey('send'),
              icon: AppIcons.send,
              onTap: canSend ? onSend : null,
              background: canSend
                  ? AppColors.accent
                  : Theme.of(context).colorScheme.surfaceContainerHighest,
              foreground: canSend
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurfaceVariant,
            ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.background,
    required this.foreground,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(icon, size: 19, color: foreground),
        ),
      ),
    );
  }
}
