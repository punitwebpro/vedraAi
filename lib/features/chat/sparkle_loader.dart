import 'dart:math' as math;
import 'package:flutter/material.dart';

class SparkleLoader extends StatefulWidget {
  const SparkleLoader({super.key});

  @override
  State<SparkleLoader> createState() => _SparkleLoaderState();
}

class _SparkleLoaderState extends State<SparkleLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final wave = 0.5 + 0.5 * math.sin(_c.value * 2 * math.pi);
        return Opacity(
          opacity: 0.45 + 0.55 * wave,
          child: Transform.scale(
            scale: 0.85 + 0.3 * wave,
            child: Icon(Icons.auto_awesome, size: 30, color: color),
          ),
        );
      },
    );
  }
}
