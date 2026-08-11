import 'package:flutter/material.dart';

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
        InkWell(
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
        ),
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

  const WpMonoLabel(
    this.text, {
    super.key,
    this.size = 10,
    this.color = AppColors.muted,
    this.align = TextAlign.left,
  });

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      textAlign: align,
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
                ? Icon(Icons.person, size: radius, color: Colors.white)
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
            fillColor: Colors.white,
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
              borderSide: BorderSide(color: Colors.redAccent),
            ),
          ),
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
            color: Colors.white,
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
        color: Colors.white,
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
        color: Colors.white,
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

/// The bottom navigation bar — home / map / walk / rewards.
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

  static const _icons = {
    'home': Icons.home_outlined,
    'map': Icons.map_outlined,
    'walk': Icons.directions_walk,
    'rewards': Icons.emoji_events_outlined,
  };

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < items.length; i++)
                _NavItem(
                  label: items[i],
                  icon: _icons[items[i]] ?? Icons.circle,
                  selected: i == currentIndex,
                  onTap: () => onTap(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.primary : AppColors.onSurfaceMuted;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 4),
            Text(label.toUpperCase(), style: AppType.mono.copyWith(color: color)),
          ],
        ),
      ),
    );
  }
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
        color: background ?? Colors.white,
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

  const WpDetailRow({super.key, required this.label, required this.value});

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
          WpMonoLabel(label),
          Flexible(
            child: Text(value, textAlign: TextAlign.right, style: AppType.body),
          ),
        ],
      ),
    );
  }
}
