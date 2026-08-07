import 'package:flutter/material.dart';

import 'package:walkpenang/theme/discovery_colors.dart';

/// Read-only star row. [rating] may be fractional — halves are rendered.
class StarRating extends StatelessWidget {
  const StarRating({
    super.key,
    required this.rating,
    this.size = 14,
    this.color = DiscoveryColors.star,
  });

  final double rating;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(5, (int index) {
        final double diff = rating - index;
        final IconData icon = diff >= 1
            ? Icons.star_rounded
            : diff >= 0.5
            ? Icons.star_half_rounded
            : Icons.star_outline_rounded;
        return Icon(icon, size: size, color: color);
      }),
    );
  }
}

/// Tappable star picker for the review form (screen 05).
class StarRatingInput extends StatelessWidget {
  const StarRatingInput({
    super.key,
    required this.rating,
    required this.onChanged,
    this.size = 40,
  });

  final int rating;
  final ValueChanged<int> onChanged;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(5, (int index) {
        final int value = index + 1;
        final bool filled = value <= rating;
        return Semantics(
          button: true,
          label: '$value star${value == 1 ? '' : 's'}',
          selected: filled,
          child: IconButton(
            onPressed: () => onChanged(value),
            padding: const EdgeInsets.symmetric(horizontal: 2),
            constraints: const BoxConstraints(),
            icon: Icon(
              filled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: filled ? DiscoveryColors.star : DiscoveryColors.inkMuted,
            ),
          ),
        );
      }),
    );
  }
}
