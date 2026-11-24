import 'package:flutter/material.dart';

import '../../../icons/broken_icons.dart';

/// The Handoff mark used across the OpenHands surfaces.
class HandoffLogo extends StatelessWidget {
  const HandoffLogo({super.key, this.size = 72, this.radius = 22});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: scheme.surface,
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset(
        'assets/app_icon.png',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Icon(
          Broken.home_2,
          size: size * 0.55,
          color: scheme.primary,
        ),
      ),
    );
  }
}
