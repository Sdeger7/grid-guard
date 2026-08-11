import 'package:flutter/material.dart';

import '../theme.dart';

/// Three-star display. [filled] of [total] stars are lit.
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.filled, this.total = 3, this.size = 18});

  final int filled;
  final int total;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (i) {
        final lit = i < filled;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 1),
          child: Icon(
            lit ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: lit ? GGColors.star : GGColors.panelBorder,
          ),
        );
      }),
    );
  }
}
