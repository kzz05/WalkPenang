// ---------------------------------------------------------------------------
// journal_entry_tile.dart
// Module 5 — Reward & Achievement
// Use Case : UC520 View walking journal
// FR       : FR-R03 Walking Journal
// ---------------------------------------------------------------------------
//
// One completed journey, as a row in the walking journal.
//
// Like the rest of Module 5's widgets this calculates nothing — distance,
// carbon, calories and points are produced per check-in by Module 4 and the
// award formula, and this only formats what it is handed.

import 'package:flutter/material.dart';

import '../../models/journal_entry_model.dart';
import '../../models/transport_mode.dart';
import '../../theme/app_theme.dart';
import '../../views/widgets/wp_components.dart';

class JournalEntryTile extends StatelessWidget {
  final JournalEntryModel entry;
  final VoidCallback? onTap;

  /// Injected so a widget test can pin "Today" without waiting for midnight.
  final DateTime? now;

  const JournalEntryTile({
    super.key,
    required this.entry,
    this.onTap,
    this.now,
  });

  @override
  Widget build(BuildContext context) {
    final today = now ?? DateTime.now();

    return Material(
      color: AppColors.card,
      borderRadius: AppRadius.smAll,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.smAll,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.displayName,
                      style: AppType.body.copyWith(
                        fontWeight: FontWeight.w600,
                        // A journey whose place was never recorded is greyed
                        // rather than hidden — the tourist did walk it.
                        color: entry.isIncomplete
                            ? AppColors.muted
                            : AppColors.onPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${entry.relativeDate(today)} · '
                      '${entry.distanceKm.toStringAsFixed(1)} km',
                      style: AppType.mono.copyWith(fontSize: 11, color: AppColors.muted),
                    ),
                    // Only ever shown for a journey that was not walked, so a
                    // zero-point walk is never mislabelled as a drive.
                    if (entry.transportMode != TransportMode.walking) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${entry.transportMode.label} · no points',
                        style: AppType.mono
                            .copyWith(fontSize: 11, color: AppColors.subtle),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (entry.pointsAwarded > 0)
                WpMonoLabel(
                  '+${entry.pointsAwarded} pts',
                  color: AppColors.onPrimary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
