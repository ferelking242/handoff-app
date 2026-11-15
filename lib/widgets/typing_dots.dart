import 'package:flutter_animate/flutter_animate.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme/app_theme.dart';

/// Three dots that rise in sequence: the "agent is thinking" indicator.
class TypingDots extends StatelessWidget {
  const TypingDots({super.key, this.color = AppColors.accentBright});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2.5),
          child:
              Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                  )
                  .animate(onPlay: (controller) => controller.repeat())
                  .moveY(
                    begin: 0,
                    end: -4,
                    duration: 420.ms,
                    delay: (index * 140).ms,
                    curve: Curves.easeOut,
                  )
                  .then()
                  .moveY(
                    begin: -4,
                    end: 0,
                    duration: 420.ms,
                    curve: Curves.easeIn,
                  ),
        );
      }),
    );
  }
}
