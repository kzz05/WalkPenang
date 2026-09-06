import 'package:flutter/material.dart';

import '../../constants/validation_messages.dart';
import '../../models/password_strength.dart';
import '../../theme/app_theme.dart';

/// Shared building blocks for every screen — the "WalkPenang design system".
/// Screens compose these instead of hand-rolling Material widgets, so a
/// token change in [AppColors]/[AppType]/[AppRadius] updates the whole app.

/// Full-screen wrapper: cream background, safe area, scrollable padding.
/// Used by screens that are one long vertical form (edit profile, settings,
/// OTP) instead of a custom `Scaffold`.
class WpScreen extends StatelessWidget {
  final List<Widget> children;

  const WpScreen({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// The app's one back control: a plain outlined circle with a back arrow.
///
/// Extracted from [WpBackBar] so a screen whose header puts something else
/// beside the button — a title, a status pill — can still use the same
/// treatment instead of hand-rolling its own. Every screen that navigates
/// back should render this or [WpBackBar]; nothing should draw a third
/// variant.
class WpBackButton extends StatelessWidget {
  final VoidCallback? onBack;

  const WpBackButton({super.key, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onBack,
      customBorder: const CircleBorder(),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.outline),
        ),
        child: const Icon(
          Icons.arrow_back,
          size: 18,
          color: AppColors.onPrimary,
        ),
      ),
    );
  }
}

/// Circular back button, with an optional right-aligned text action
/// (e.g. "save") next to it.
class WpBackBar extends StatelessWidget {
  final VoidCallback onBack;
  final String? actionLabel;
  final VoidCallback? onAction;

  const WpBackBar({
    super.key,
    required this.onBack,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        WpBackButton(onBack: onBack),
        if (actionLabel != null)
          TextButton(
            onPressed: onAction,
            child: WpMonoLabel(actionLabel!, color: AppColors.onPrimary),
          )
        else
          const SizedBox(width: 40),
      ],
    );
  }
}

/// The small uppercase IBM Plex Mono label used throughout the app — status
/// tags, captions, section headers.
class WpMonoLabel extends StatelessWidget {
  final String text;
  final double size;
  final Color color;
  final TextAlign align;

  /// Null (the default) keeps the label wrapping freely, as every existing
  /// caller expects. Set it where an unbounded wrap would stretch a card.
  final int? maxLines;

  const WpMonoLabel(
    this.text, {
    super.key,
    this.size = 10,
    this.color = AppColors.muted,
    this.align = TextAlign.left,
    this.maxLines,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      textAlign: align,
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: AppType.mono.copyWith(fontSize: size, color: color),
    );
  }
}

/// Circular profile photo with a placeholder icon when there's no image,
/// and an optional pencil badge to trigger picking a new one.
class WpAvatar extends StatelessWidget {
  final double radius;
  final ImageProvider? image;
  final Color? background;
  final VoidCallback? onEdit;

  const WpAvatar({
    super.key,
    required this.radius,
    this.image,
    this.background,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: background ?? AppColors.placeholder,
            backgroundImage: image,
            child: image == null
                ? Icon(Icons.person, size: radius, color: AppColors.muted)
                : null,
          ),
          if (onEdit != null)
            Positioned(
              right: 0,
              bottom: 0,
              child: InkWell(
                onTap: onEdit,
                customBorder: const CircleBorder(),
                child: Container(
                  width: radius * 0.6,
                  height: radius * 0.6,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                  ),
                  child: Icon(
                    Icons.edit,
                    size: radius * 0.32,
                    color: AppColors.onPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Labeled text field: a [WpMonoLabel] caption above a white bordered box.
class WpField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;

  const WpField({
    super.key,
    required this.label,
    required this.controller,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WpMonoLabel(label),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          obscureText: obscureText,
          style: AppType.body,
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.card,
            suffixIcon: suffixIcon,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: const OutlineInputBorder(
              borderRadius: AppRadius.smAll,
              borderSide: BorderSide(color: AppColors.outline),
            ),
            enabledBorder: const OutlineInputBorder(
              borderRadius: AppRadius.smAll,
              borderSide: BorderSide(color: AppColors.outline),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: AppRadius.smAll,
              borderSide: BorderSide(color: AppColors.primary, width: 1.6),
            ),
            errorBorder: const OutlineInputBorder(
              borderRadius: AppRadius.smAll,
              borderSide: BorderSide(color: AppColors.danger),
            ),
          ),
        ),
      ],
    );
  }
}

/// Four-segment strength meter with a requirement checklist, shown directly
/// under the password field while the user types.
///
/// Purely presentational — the grading lives in [PasswordStrength] so it can
/// be unit-tested without a widget binding.
class WpPasswordStrengthMeter extends StatelessWidget {
  final PasswordStrength strength;

  const WpPasswordStrengthMeter({super.key, required this.strength});

  static const _segments = 4;

  Color get _color => switch (strength.level) {
        PasswordStrengthLevel.empty => AppColors.placeholder,
        PasswordStrengthLevel.weak => AppColors.danger,
        PasswordStrengthLevel.fair => AppColors.warning,
        PasswordStrengthLevel.good ||
        PasswordStrengthLevel.strong =>
          AppColors.success,
      };

  @override
  Widget build(BuildContext context) {
    // 0.25 → 1 segment, 1.0 → 4 segments.
    final filled = (strength.fraction * _segments).round();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (var i = 0; i < _segments; i++) ...[
              if (i > 0) const SizedBox(width: 6),
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 4,
                  decoration: BoxDecoration(
                    color: i < filled ? _color : AppColors.placeholder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // The "12+ characters recommended" nudge retires once earned.
            if (strength.level != PasswordStrengthLevel.strong)
              const Flexible(child: WpMonoLabel(ValidationMessages.strengthHint))
            else
              const SizedBox.shrink(),
            if (strength.label.isNotEmpty)
              WpMonoLabel(strength.label, color: _color),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 14,
          runSpacing: 6,
          children: [
            for (final requirement in strength.requirements)
              _RequirementPip(requirement: requirement),
          ],
        ),
      ],
    );
  }
}

/// One tick/dot + label pair in the password checklist.
class _RequirementPip extends StatelessWidget {
  final PasswordRequirement requirement;

  const _RequirementPip({required this.requirement});

  @override
  Widget build(BuildContext context) {
    final met = requirement.met;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          met ? Icons.check_circle : Icons.circle_outlined,
          size: 13,
          color: met ? AppColors.success : AppColors.muted,
        ),
        const SizedBox(width: 5),
        WpMonoLabel(
          requirement.label,
          color: met ? AppColors.success : AppColors.muted,
        ),
      ],
    );
  }
}

/// Labeled dropdown, styled the same as [WpField].
class WpDropdownField extends StatelessWidget {
  final String label;
  final String value;
  final Map<String, String> options;
  final ValueChanged<String?> onChanged;

  const WpDropdownField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        WpMonoLabel(label),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: AppRadius.smAll,
            border: Border.all(color: AppColors.outline),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              style: AppType.body,
              icon: const Icon(
                Icons.keyboard_arrow_down,
                color: AppColors.onPrimary,
              ),
              items: [
                for (final entry in options.entries)
                  DropdownMenuItem(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}

/// Full-width filled pill button — the app's primary call to action.
class WpPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const WpPrimaryButton({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
          elevation: 0,
        ),
        child: Text(label.toUpperCase(), style: AppType.button),
      ),
    );
  }
}

/// Full-width outlined pill button — the secondary action.
class WpOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const WpOutlineButton({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.onPrimary,
          side: const BorderSide(color: AppColors.outline),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        ),
        child: Text(label.toUpperCase(), style: AppType.button),
      ),
    );
  }
}

/// White card in a list — title, subtitle, chevron. Used for the home
/// screen's module list and the account menu sheet.
class WpModuleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const WpModuleCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.card,
        borderRadius: AppRadius.smAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.smAll,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppType.heading.copyWith(fontSize: 16)),
                      const SizedBox(height: 4),
                      WpMonoLabel(subtitle),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One of the three stat cards on the home screen (distance / co2 / points).
class WpStatTile extends StatelessWidget {
  final String label;
  final String value;

  const WpStatTile({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadius.smAll,
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(value, style: AppType.stat),
          const SizedBox(height: 4),
          WpMonoLabel(label),
        ],
      ),
    );
  }
}

/// The bottom navigation bar — home / map / explore / walk / rewards.
///
/// A Material 3 [NavigationBar], the same component and styling the Discovery
/// module's Discover/Favorites bar uses. Everything visual comes from
/// `navigationBarTheme` in [buildAppTheme], so the two bars cannot drift:
/// a white bar, a cream pill behind the selected item, and its icon switching
/// from outline to filled.
class WpBottomNav extends StatelessWidget {
  final int currentIndex;
  final List<String> items;
  final ValueChanged<int> onTap;

  const WpBottomNav({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  /// Outline icon for the resting state, filled for the selected one.
  static const _icons = <String, (IconData, IconData)>{
    'home': (Icons.home_outlined, Icons.home),
    'map': (Icons.map_outlined, Icons.map),
    'explore': (Icons.explore_outlined, Icons.explore),
    'walk': (Icons.directions_walk_outlined, Icons.directions_walk),
    'rewards': (Icons.emoji_events_outlined, Icons.emoji_events),
  };

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      destinations: [
        for (final item in items)
          NavigationDestination(
            icon: Icon((_icons[item] ?? _fallback).$1),
            selectedIcon: Icon((_icons[item] ?? _fallback).$2),
            // Title case: "Explore", not "EXPLORE" — the mono uppercase
            // treatment is for micro-labels, not navigation.
            label: '${item[0].toUpperCase()}${item.substring(1)}',
          ),
      ],
    );
  }

  static const _fallback = (Icons.circle_outlined, Icons.circle);
}

/// Small pill of text — a category tag or an inline detail like an email.
class WpChip extends StatelessWidget {
  final String label;
  final Color? background;
  final bool uppercase;

  const WpChip(this.label, {super.key, this.background, this.uppercase = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: background ?? AppColors.card,
        borderRadius: AppRadius.mdAll,
        border: background == null ? Border.all(color: AppColors.outline) : null,
      ),
      child: Text(
        uppercase ? label.toUpperCase() : label,
        style: AppType.monoValue,
      ),
    );
  }
}

/// Page heading with an optional mono caption underneath — sign in / setup.
class WpPageTitle extends StatelessWidget {
  final String title;
  final String? caption;

  const WpPageTitle(this.title, {super.key, this.caption});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppType.display),
        if (caption != null) ...[
          const SizedBox(height: 8),
          WpMonoLabel(caption!),
        ],
      ],
    );
  }
}

/// "── or ──" divider between sign-in options.
class WpOrDivider extends StatelessWidget {
  const WpOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: AppColors.outline, thickness: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: WpMonoLabel('or'),
        ),
        Expanded(child: Divider(color: AppColors.outline, thickness: 1)),
      ],
    );
  }
}

/// One label/value row in a read-only summary list (Settings), with a
/// hairline underneath separating it from the next row.
class WpDetailRow extends StatelessWidget {
  final String label;
  final String value;

  /// Null (the default) keeps the row label-first, as every existing caller
  /// expects. Set it to give the row a small leading glyph, sized and
  /// coloured like the stat cards on the reward dashboard.
  ///
  /// The icon is decorative — it restates the label beside it — so it is left
  /// without a `semanticLabel`, which keeps [Icon] from emitting a semantics
  /// node and a screen reader from announcing the row twice.
  final IconData? icon;

  const WpDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.outline)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Grouped rather than laid out as siblings: `spaceBetween` divides
          // the free space between every child, so a loose icon would drift
          // away from the label it belongs to as the value shortens.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                // A fixed box rather than the bare glyph: Material icons do
                // not all draw to the same width, and a column of labels
                // that shifts by a pixel or two per row reads as sloppy.
                SizedBox(
                  width: 18,
                  child: Icon(icon, size: 18, color: AppColors.muted),
                ),
                const SizedBox(width: 10),
              ],
              WpMonoLabel(label),
            ],
          ),
          Flexible(
            child: Text(value, textAlign: TextAlign.right, style: AppType.body),
          ),
        ],
      ),
    );
  }
}
