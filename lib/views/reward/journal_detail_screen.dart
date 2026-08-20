// journal_detail_screen.dart — Module 5 View
// Full detail of one journal entry. UC520 constraint C1

import 'package:flutter/material.dart';

import '../../models/journal_entry_model.dart';
import '../../models/transport_mode.dart';
import '../../theme/app_theme.dart';
import '../widgets/wp_components.dart';

/// One completed journey in full.
///
/// Every value comes from the [JournalEntryModel] the list already holds, so
/// opening an entry costs no read. Nothing is recalculated here — distance,
/// carbon and calories were produced by Module 4 at check-in, and the points
/// by the award formula; showing a freshly computed figure could disagree with
/// what the tourist was actually given.
class JournalDetailScreen extends StatelessWidget {
  final JournalEntryModel entry;

  const JournalDetailScreen({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final walked = entry.transportMode == TransportMode.walking;

    return WpScreen(
      children: [
        WpBackBar(onBack: () => Navigator.of(context).maybePop()),
        const SizedBox(height: 16),
        Text(entry.displayName, style: AppType.display),
        const SizedBox(height: 6),
        Text(
          entry.relativeDate(DateTime.now()),
          style: AppType.mono.copyWith(fontSize: 11, color: AppColors.muted),
        ),

        if (entry.isIncomplete) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warningTint,
              borderRadius: AppRadius.smAll,
            ),
            // Said plainly rather than hidden: this journey was walked before
            // the app recorded which place it was for, and inventing a name
            // would be worse than admitting the gap.
            child: Text(
              'This journey was recorded before WalkPenang saved destination '
              'names, so its place and points are unknown.',
              style: AppType.body.copyWith(color: AppColors.onPrimary),
            ),
          ),
        ],

        const SizedBox(height: 24),
        WpDetailRow(
          label: 'distance',
          value: '${entry.distanceKm.toStringAsFixed(2)} km',
        ),
        WpDetailRow(label: 'travelled by', value: entry.transportMode.label),
        WpDetailRow(
          label: 'points earned',
          // A walk that earned nothing is a pre-existing record; a drive
          // earned nothing by rule (FR-W01). Different reasons, so they read
          // differently rather than both showing a bare 0.
          value: entry.pointsAwarded > 0
              ? '${entry.pointsAwarded}'
              : walked
                  ? 'not recorded'
                  : 'none — walking only',
        ),
        WpDetailRow(
          label: 'carbon saved',
          value: '${entry.carbonSavedKg.toStringAsFixed(2)} kg',
        ),
        WpDetailRow(
          label: 'calories burned',
          value: '${entry.caloriesBurned.round()} kcal',
        ),
        WpDetailRow(
          label: 'completed',
          value: '${entry.checkInTime.day}/${entry.checkInTime.month}/'
              '${entry.checkInTime.year} at '
              '${entry.checkInTime.hour.toString().padLeft(2, '0')}:'
              '${entry.checkInTime.minute.toString().padLeft(2, '0')}',
        ),
      ],
    );
  }
}
