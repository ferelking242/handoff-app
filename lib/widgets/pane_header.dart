import 'package:material_ui/material_ui.dart';

import '../core/icon_fonts/app_icons.dart';

/// The slim header every pane draws at the top of the body.
///
/// It is a plain widget rather than an [AppBar] so the shell can own a single
/// [Scaffold] (and therefore a single drawer) on phones, while wide layouts
/// keep the sidebar permanently visible.
class PaneHeader extends StatelessWidget {
  const PaneHeader({
    super.key,
    this.title,
    this.subtitle,
    this.onMenu,
    this.leading,
    this.actions = const [],
  });

  final Widget? title;
  final Widget? subtitle;
  final VoidCallback? onMenu;
  final Widget? leading;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 8, 8, 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          if (onMenu != null)
            IconButton(
              onPressed: onMenu,
              icon: const Icon(AppIcons.menu),
              tooltip: 'Conversations',
            )
          else if (leading != null)
            leading!,
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null)
                  DefaultTextStyle.merge(
                    style: theme.textTheme.titleMedium!,
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
        ],
      ),
    );
  }
}
