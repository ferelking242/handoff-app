import 'package:material_ui/material_ui.dart';

import '../core/icon_fonts/app_icons.dart';
import '../core/theme/app_theme.dart';

/// The slim, chrome-free header every pane draws over its content.
///
/// Modelled on Kelivo's mobile app bar: transparent, no elevation, no divider.
/// Content scrolls *under* it and fades out, so the header reads as part of the
/// canvas instead of a grey bar bolted on top. It is a plain widget rather than
/// an [AppBar] so the shell can own a single [Scaffold] (and therefore a single
/// drawer) on phones, while wide layouts keep the sidebar visible.
class PaneHeader extends StatelessWidget {
  const PaneHeader({
    super.key,
    this.title,
    this.subtitle,
    this.avatar,
    this.onMenu,
    this.leading,
    this.actions = const [],
  });

  /// Height of the bar itself, excluding the status-bar inset.
  static const double barHeight = 56;

  final Widget? title;
  final Widget? subtitle;

  /// A small round mark drawn before the title, the way Kelivo's header shows
  /// the current assistant. It is what makes the bar read as "this
  /// conversation" rather than a generic toolbar.
  final Widget? avatar;
  final VoidCallback? onMenu;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final topInset = MediaQuery.paddingOf(context).top;

    return SizedBox(
      height: barHeight + topInset,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned.fill(child: _HeaderWash(theme: theme)),
          Padding(
            padding: EdgeInsets.only(top: topInset),
            child: Row(
              children: [
                if (onMenu != null)
                  _HeaderIconButton(
                    icon: AppIcons.menu,
                    tooltip: 'Conversations',
                    onTap: onMenu,
                  )
                else if (leading != null)
                  leading!,
                const SizedBox(width: 2),
                if (avatar != null) ...[
                  avatar!,
                  const SizedBox(width: AppSpacing.xs + 2),
                ],
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (title != null)
                        DefaultTextStyle.merge(
                          style: theme.textTheme.titleMedium!.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          child: title!,
                        ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        subtitle!,
                      ],
                    ],
                  ),
                ),
                ...actions,
                const SizedBox(width: AppSpacing.xs),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The soft scrim behind the header: a vertical gradient from the canvas colour
/// to fully transparent. This is what lets content scroll underneath without
/// colliding with the title.
class _HeaderWash extends StatelessWidget {
  const _HeaderWash({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final canvas = theme.scaffoldBackgroundColor;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [canvas, canvas, canvas.withValues(alpha: 0)],
          stops: const [0, 0.7, 1],
        ),
      ),
    );
  }
}

/// A borderless, circular tap target. Kelivo's header buttons carry no ripple
/// box; they shrink slightly on press instead.
class _HeaderIconButton extends StatefulWidget {
  const _HeaderIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  State<_HeaderIconButton> createState() => _HeaderIconButtonState();
}

class _HeaderIconButtonState extends State<_HeaderIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final button = AnimatedScale(
      scale: _pressed ? 0.9 : 1,
      duration: const Duration(milliseconds: 120),
      child: InkResponse(
        onTap: widget.onTap,
        onTapDown: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        radius: 22,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(widget.icon, size: 21),
        ),
      ),
    );
    if (widget.tooltip == null) return button;
    return Tooltip(message: widget.tooltip!, child: button);
  }
}
