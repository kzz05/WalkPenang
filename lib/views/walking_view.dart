import 'package:flutter/material.dart';

import '../controllers/walking_controller.dart';
import '../models/transport_mode.dart';
import '../theme/app_theme.dart';

class WalkingView extends StatefulWidget {
  const WalkingView({super.key});

  @override
  State<WalkingView> createState() => _WalkingViewState();
}

class _WalkingViewState extends State<WalkingView> {
  final WalkingController _controller = WalkingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Walking & Carbon'),
        backgroundColor: AppColors.background,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                const Text(
                  'Select Transport Mode',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Walking benefits and rewards are enabled only when '
                      'Walking is selected.',
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),

                for (final mode in TransportMode.values) ...[
                  _TransportModeCard(
                    mode: mode,
                    selected: _controller.selectedMode == mode,
                    onTap: () => _controller.selectMode(mode),
                  ),
                  const SizedBox(height: 12),
                ],

                const SizedBox(height: 20),
                _buildFeatureStatus(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildFeatureStatus() {
    if (!_controller.hasSelectedMode) {
      return const _StatusCard(
        icon: Icons.info_outline,
        title: 'No mode selected',
        message: 'Please select a transport mode to continue.',
      );
    }

    if (_controller.walkingFeaturesEnabled) {
      return const _StatusCard(
        icon: Icons.directions_walk,
        title: 'Walking features enabled',
        message:
        'Carbon savings, calories, journey completion and rewards '
            'are available.',
      );
    }

    return const _StatusCard(
      icon: Icons.block,
      title: 'Walking features disabled',
      message:
      'Carbon savings, calories, journey completion and rewards '
          'are only available for Walking mode.',
    );
  }
}

class _TransportModeCard extends StatelessWidget {
  final TransportMode mode;
  final bool selected;
  final VoidCallback onTap;

  const _TransportModeCard({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  IconData get icon {
    return switch (mode) {
      TransportMode.walking => Icons.directions_walk,
      TransportMode.driving => Icons.directions_car,
      TransportMode.publicTransport => Icons.directions_bus,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? Colors.black : Colors.black26,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  mode.label,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _StatusCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white70,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}