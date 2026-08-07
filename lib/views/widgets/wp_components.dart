import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// 🧱 The shared vocabulary of the WalkPenang UI kit.
///
/// Every screen is assembled from these pieces so that a change to a corner
/// radius or a button height happens once, here, instead of eight times.

// ── Layout ────────────────────────────────────────────────────────────────

/// Cream page with the standard 24pt gutters and a scrollable body.
class WpScreen extends StatelessWidget {
  final List<Widget> children;
  final EdgeInsets padding;
  final Widget? bottomBar;

  const WpScreen({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(24, 8, 24, 32),
    this.bottomBar,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(padding: padding, children: children),
            ),
            if (bottomBar != null) bottomBar!,
          ],
        ),
      ),
    );
  }
}

// ── Type helpers ──────────────────────────────────────────────────────────

/// The uppercase IBM Plex Mono micro-label used all over the design.
class WpMonoLabel extends StatelessWidget {
  final String text;
  final Color? color;
  final double? size;
  final TextAlign? align;

  const WpMonoLabel(
      this.text, {
        super.key,
        this.color,
        this.size,
        this.align,
      });

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      textAlign: align,
      style: AppType.mono.copyWith(color: color, fontSize: size),
    );
  }
}

/// Page title + mono strapline, the header on every full-page screen.
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
          const SizedBox(height: 6),
          WpMonoLabel(caption!),
        ],
      ],
    );
  }
}

/// "< BACK" on the left with an optional mono action on the right.
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
        GestureDetector(
          onTap: onBack,
          behavior: HitTestBehavior.opaque,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: WpMonoLabel('< back', size: 11),
          ),
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: WpMonoLabel(
                actionLabel!,
                size: 11,
                color: AppColors.onPrimary,
              ),
            ),
          ),
      ],
    );
  }
}

// ── Buttons ───────────────────────────────────────────────────────────────

/// Filled sand-coloured pill — the primary action on every screen.
class WpPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const WpPrimaryButton({super.key, required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.45),
          disabledForegroundColor: AppColors.onPrimary.withValues(alpha: 0.45),
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        ),
        child: Text(label.toUpperCase(), style: AppType.button),
      ),
    );
  }
}

/// Black-outlined pill — the secondary action (Google, log out, cancel).
class WpOutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;

  const WpOutlineButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final text = Text(label.toUpperCase(), style: AppType.button);

    return SizedBox(
      height: 58,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.onPrimary,
          side: const BorderSide(color: AppColors.onPrimary, width: 1.6),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        ),
        child: icon == null
            ? text
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [icon!, const SizedBox(width: 10), text],
        ),
      ),
    );
  }
}

/// The "———— OR ————" rule between the two sign-in methods.
class WpOrDivider extends StatelessWidget {
  const WpOrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: AppColors.outline, thickness: 1)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: WpMonoLabel('or', size: 11),
        ),
        Expanded(child: Divider(color: AppColors.outline, thickness: 1)),
      ],
    );
  }
}

// ── Inputs ────────────────────────────────────────────────────────────────

/// Shared decoration so every input — plain, dropdown or OTP — matches.
InputDecoration wpInputDecoration({String? hint, Widget? suffixIcon}) {
  OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
    borderRadius: AppRadius.smAll,
    borderSide: BorderSide(color: color, width: width),
  );

  return InputDecoration(
    hintText: hint,
    hintStyle: AppType.body.copyWith(color: AppColors.muted),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: AppColors.border,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
    border: border(AppColors.outline, 1),
    enabledBorder: border(AppColors.outline, 1),
    focusedBorder: border(AppColors.primary, 1.8),
    errorBorder: border(AppColors.onPrimary, 1.4),
    focusedErrorBorder: border(AppColors.onPrimary, 1.8),
    errorStyle: AppType.mono.copyWith(color: AppColors.onPrimary),
  );
}

/// Mono label stacked above a white rounded input.
class WpField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? hint;

  const WpField({
    super.key,
    required this.label,
    required this.controller,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.hint,
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
          cursorColor: AppColors.onPrimary,
          decoration: wpInputDecoration(hint: hint, suffixIcon: suffixIcon),
        ),
      ],
    );
  }
}

/// Mono label stacked above a white rounded dropdown.
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
        DropdownButtonFormField<String>(
          initialValue: value,
          style: AppType.body,
          borderRadius: AppRadius.smAll,
          dropdownColor: AppColors.border,
          icon: const Icon(Icons.expand_more, size: 18, color: AppColors.muted),
          decoration: wpInputDecoration(),
          items: [
            for (final entry in options.entries)
              DropdownMenuItem(value: entry.key, child: Text(entry.value)),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────

/// Circular avatar with the optional sand-coloured edit dot.
class WpAvatar extends StatelessWidget {
  final ImageProvider? image;
  final double radius;
  final Color background;
  final VoidCallback? onEdit;

  const WpAvatar({
    super.key,
    this.image,
    this.radius = 55,
    this.background = AppColors.placeholder,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: radius * 2,
      height: radius * 2,
      child: Stack(
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: background,
            backgroundImage: image,
            child: image == null
                ? Icon(Icons.person, size: radius, color: Colors.white)
                : null,
          ),
          if (onEdit != null)
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: onEdit,
                child: CircleAvatar(
                  radius: radius * 0.22,
                  backgroundColor: AppColors.primary,
                  child: Icon(
                    Icons.camera_alt,
                    size: radius * 0.22,
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

// ── Chips, tiles and cards ────────────────────────────────────────────────

/// Rounded mono chip — used for the email read-out and status flags.
class WpChip extends StatelessWidget {
  final String text;
  final Color background;
  final Color? textColor;
  final bool uppercase;

  const WpChip(
      this.text, {
        super.key,
        this.background = AppColors.outline,
        this.textColor,
        this.uppercase = false,
      });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.mdAll,
      ),
      child: Text(
        uppercase ? text.toUpperCase() : text,
        style: AppType.monoValue.copyWith(
          color: textColor ?? AppColors.onPrimary,
          letterSpacing: uppercase ? 1.4 : 0.6,
        ),
      ),
    );
  }
}

/// One of the three white metric tiles under the home hero.
class WpStatTile extends StatelessWidget {
  final String label;
  final String value;

  const WpStatTile({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppRadius.smAll,
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          WpMonoLabel(label),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: AppType.stat),
          ),
        ],
      ),
    );
  }
}

/// A white module row: title, mono subtitle and a trailing arrow.
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
        color: AppColors.border,
        borderRadius: AppRadius.smAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.smAll,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            decoration: BoxDecoration(
              borderRadius: AppRadius.smAll,
              border: Border.all(color: AppColors.outline),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppType.heading),
                      const SizedBox(height: 4),
                      WpMonoLabel(subtitle),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward,
                    size: 18, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A label/value row with a hairline underneath — the settings read-out.
class WpDetailRow extends StatelessWidget {
  final String label;
  final String value;

  const WpDetailRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Row(
            children: [
              Expanded(child: WpMonoLabel(label)),
              Text(
                value,
                style: AppType.heading,
                textAlign: TextAlign.right,
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1, color: AppColors.outline),
      ],
    );
  }
}

// ── Bottom navigation ─────────────────────────────────────────────────────

/// The black floating pill with the sand-coloured active segment.
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: AppRadius.mdAll,
        ),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: i == currentIndex
                          ? AppColors.primary
                          : Colors.transparent,
                      borderRadius: AppRadius.mdAll,
                    ),
                    child: WpMonoLabel(
                      items[i],
                      size: 11,
                      align: TextAlign.center,
                      color: i == currentIndex
                          ? AppColors.onPrimary
                          : AppColors.onSurfaceMuted,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
