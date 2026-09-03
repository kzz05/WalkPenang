import 'package:flutter/material.dart';

import 'package:walkpenang/theme/app_theme.dart';

/// The one heart control, used on every card that can be favourited — the
/// Discovery grid tile, the Home map carousel card, and the place detail
/// screen — so the icon and its colours can't drift between screens.
///
/// - not favourited: outline heart, neutral colour
/// - favourited: filled heart, [AppColors.danger] (red)
///
/// [onImage] switches the neutral state to white with a soft shadow, for the
/// hearts that sit on top of a place photo rather than on a light surface.
class FavoriteHeartButton extends StatelessWidget {
  const FavoriteHeartButton({
    super.key,
    required this.isFavorite,
    required this.onToggle,
    this.size = 20,
    this.neutralColor = AppColors.muted,
    this.onImage = false,
    this.dense = false,
  });

  final bool isFavorite;
  final VoidCallback onToggle;
  final double size;
  final Color neutralColor;
  final bool onImage;

  /// Drops the button's padding and 48px min tap target, for cramped rows like
  /// the map carousel card header.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onToggle,
      iconSize: size,
      visualDensity: VisualDensity.compact,
      padding: dense ? EdgeInsets.zero : null,
      constraints: dense
          ? BoxConstraints.tightFor(width: size + 10, height: size + 10)
          : null,
      tooltip: isFavorite ? 'Remove from favourites' : 'Save to favourites',
      icon: Icon(
        isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: isFavorite
            ? AppColors.danger
            : (onImage ? AppColors.card : neutralColor),
        shadows: onImage
            ? const <Shadow>[Shadow(blurRadius: 4, color: AppColors.scrim)]
            : null,
      ),
    );
  }
}
