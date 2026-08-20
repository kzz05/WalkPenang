import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// One destination in [WpTabSheet].
class WpTab {
  const WpTab({required this.label, required this.builder});

  final String label;

  /// Built once and kept alive by the sheet's IndexedStack — switching tabs
  /// must not re-run a screen's initState and re-fetch everything.
  final WidgetBuilder builder;
}

/// The panel that slides up over the map, carrying the app's destinations.
///
/// Replaces a permanent bottom navigation bar. The map is the home screen, so
/// there is no "home" tab: closing this sheet *is* going home, which is what
/// gives the close button an unambiguous meaning.
///
/// Height is a fraction of the screen rather than full — leaving the map
/// visible above the sheet is what keeps it feeling like an overlay on the
/// world instead of a separate screen you navigated to.
class WpTabSheet extends StatelessWidget {
  const WpTabSheet({
    super.key,
    required this.tabs,
    required this.currentIndex,
    required this.onTabSelected,
    this.heightFactor = 0.62,
  });

  final List<WpTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onTabSelected;
  final double heightFactor;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * heightFactor,
      decoration: const BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
              color: AppColors.cardShadow, blurRadius: 18, spreadRadius: 2),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _TabPills(
            tabs: tabs,
            currentIndex: currentIndex,
            onTabSelected: onTabSelected,
          ),
          Expanded(
            child: IndexedStack(
              index: currentIndex,
              children: [
                for (final tab in tabs) Builder(builder: tab.builder),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabPills extends StatelessWidget {
  const _TabPills({
    required this.tabs,
    required this.currentIndex,
    required this.onTabSelected,
  });

  final List<WpTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        // Left inset only: the row scrolls, so the last pill should be able to
        // reach the edge rather than sit in dead padding.
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(tabs[i].label),
                  selected: currentIndex == i,
                  onSelected: (_) => onTabSelected(i),
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.card,
                  labelStyle: AppType.monoValue,
                  side: const BorderSide(color: AppColors.outline),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The circular control that opens the sheet and, in the same spot, closes it.
///
/// One widget for both states rather than two swapped in and out, so the hit
/// target and its position cannot drift apart between them — the whole point
/// of the interaction is that the X is exactly where the menu button was.
class WpSheetToggleButton extends StatelessWidget {
  const WpSheetToggleButton({
    super.key,
    required this.isOpen,
    required this.onPressed,
  });

  final bool isOpen;
  final VoidCallback onPressed;

  static const double diameter = 52;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: AppColors.cardShadow,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: diameter,
          height: diameter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            // Rotate rather than cross-fade: the icon turning into an X reads
            // as the same control changing state, where a fade reads as one
            // control being replaced by another.
            transitionBuilder: (child, animation) => RotationTransition(
              turns: Tween<double>(begin: 0.5, end: 1).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Icon(
              isOpen ? Icons.close : Icons.menu,
              key: ValueKey<bool>(isOpen),
              size: 24,
              color: AppColors.onPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
